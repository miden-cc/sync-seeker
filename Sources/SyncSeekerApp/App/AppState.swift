import Foundation
import SwiftUI
import OSLog
import SyncSeeker
import Network

#if os(macOS)
@Observable @MainActor
final class AppState {
    var allDocuments: [SyncSeeker.Document] = []
    var selectedDocument: SyncSeeker.Document?
    var searchText: String = ""
    var folders: [SyncSeeker.Folder] = []
    var selectedFolderPath: URL?
    let syncFolderPath: URL



    // Connection & transfer state
    var connectionState: ConnectionState = .disconnected
    var transferState: TransferState = .idle
    var lastSyncDate: Date?

    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var menuBarState: MenuBarState {
        MenuBarState(
            connection: connectionState,
            transfer: transferState,
            lastSyncDate: lastSyncDate
        )
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SyncSeeker", category: "AppState")
    private let fileService = LocalFileService()
    private let annotationService = XattrAnnotationService()
    private var fileWatcher: FileWatcherService?
    private var refreshTask: Task<Void, Never>?
    private let usbMonitor = USBDeviceMonitor()
    private var connectedDevice: USBDeviceInfo?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.syncFolderPath = home.appendingPathComponent("SyncSeeker")
        ensureSyncFolder()
        loadAll()
        startFileWatcher()
        startUSBMonitoring()
    }

    // MARK: - File watcher

    private func startFileWatcher() {
        do {
            fileWatcher = try FileWatcherService(watchPath: syncFolderPath)
            fileWatcher?.onFileChanged = { [weak self] in
                Task { @MainActor in
                    self?.scheduleRefresh()
                }
            }
        } catch {
            logger.error("Failed to start file watcher: \(error)")
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                self.loadAll()
                self.startAutoSync()
            }
        }
    }

    // MARK: - Load

    func loadAll() {
        loadFolders()
        loadDocumentsRecursive(at: syncFolderPath)
    }

    func refresh() { loadAll() }

    // MARK: - USB monitoring

    private func startUSBMonitoring() {
        usbMonitor.onStateChanged = { [weak self] state in
            Task { @MainActor in self?.connectionState = state }
        }
        usbMonitor.onDeviceConnected = { [weak self] device in
            Task { @MainActor in
                self?.connectedDevice = device
                self?.connectionState = .connected(device)
                // usbmuxd がデバイスを認識しきるまで少し待つ
                try? await Task.sleep(for: .seconds(1.5))
                self?.startAutoSync()
            }
        }
        usbMonitor.onDeviceDisconnected = { [weak self] _ in
            Task { @MainActor in
                self?.connectedDevice = nil
                self?.connectionState = .disconnected
            }
        }
        usbMonitor.startMonitoring()
    }

    // MARK: - Sync actions

    func startSync() {
        guard let device = connectedDevice else {
            transferState = .error("デバイスが接続されていません")
            return
        }
        transferState = .scanning

        // MainActor から値をキャプチャ
        let macHost = localUSBNetworkIP()
        let syncPath = syncFolderPath
        let lastSync = lastSyncDate

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                // 1. Receivers 起動
                let fileReceiver = FileReceiver()
                let manifestReceiver = ManifestReceiver()
                fileReceiver.start(destination: syncPath)
                manifestReceiver.start()

                // 2. BSYN シグナル送信
                try FileSender().sendBidirInit(to: device, macHost: macHost)

                // 3. iPad マニフェスト受信待ち (15秒タイムアウト)
                let iPadManifest = try await self.waitForManifest(manifestReceiver, timeout: 15)

                // 4. 差分計算
                let macManifest = try ManifestBuilder().buildManifest(at: syncPath)
                let plan = BidirectionalSyncEngine().computeSyncPlan(mac: macManifest, iPad: iPadManifest, lastSync: lastSync)

                // 5. Mac→iPad 送信
                let sender = FileSender()
                let count = try sender.send(to: device, from: syncPath, plan: plan.toIPad, onProgress: { sent, total, file in
                    Task { @MainActor [weak self] in
                        self?.transferState = .transferring(sent: sent, total: total, currentFile: file)
                    }
                })

                // 6. iPad→Mac 受信完了待ち (60秒タイムアウト)
                try await fileReceiver.waitForCompletion(timeout: 60)

                // 7. 後処理
                await MainActor.run {
                    self.transferState = .completed(fileCount: count, totalBytes: 0)
                    self.lastSyncDate = Date()
                    self.loadAll()
                }
            } catch {
                await MainActor.run {
                    self.transferState = .error(error.localizedDescription)
                }
            }
        }
    }

    /// 双方向同期計画を使用したファイル送信（plan パラメータ版）
    /// - Returns: 送信したファイル数
    private nonisolated func sendWithPlan(to device: USBDeviceInfo, from syncPath: URL, plan: DiffResult, onProgress: ((_ sent: Int, _ total: Int, _ currentFile: String) -> Void)? = nil) throws -> Int {
        let sender = FileSender()
        return try sender.send(to: device, from: syncPath, plan: plan, onProgress: onProgress)
    }

    private nonisolated func waitForManifest(_ receiver: ManifestReceiver, timeout: TimeInterval) async throws -> FileManifest {
        var receivedManifest: FileManifest?
        let semaphore = DispatchSemaphore(value: 0)

        receiver.onManifestReceived = { manifest in
            receivedManifest = manifest
            semaphore.signal()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let manifest = receivedManifest {
                receiver.stop()
                return manifest
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        receiver.stop()
        throw NSError(domain: "AppState", code: -1, userInfo: [NSLocalizedDescriptionKey: "iPad manifest receive timeout"])
    }

    private nonisolated func localUSBNetworkIP() -> String {
        // TODO: getifaddrs() で en/an 系インターフェースの IPv4 を取得
        // 今は fallback で "127.0.0.1" を返す
        return "127.0.0.1"
    }

    func cancelSync() {
        transferState = .idle
    }

    private func startAutoSync() {
        switch transferState {
        case .idle, .completed:
            startSync()
        default:
            break  // scanning / transferring / error 中はスキップ
        }
    }

    // MARK: - File Actions

    func renameFile(_ document: SyncSeeker.Document, to newName: String) throws {
        let originalURL = document.path
        let originalExtension = originalURL.pathExtension
        let newExtension = (newName as NSString).pathExtension

        var finalName = newName
        if newExtension.isEmpty && !originalExtension.isEmpty {
            finalName = (newName as NSString).appendingPathExtension(originalExtension) ?? newName
        }

        let newURL = originalURL.deletingLastPathComponent().appendingPathComponent(finalName)

        guard originalURL != newURL else { return }

        Task.detached {
            try FileManager.default.moveItem(at: originalURL, to: newURL)
            await MainActor.run {
                self.loadAll()
            }
        }
    }

    // MARK: - Folder Creation

    func createFolder(named name: String, inside parent: URL? = nil) throws {
        var baseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseName.isEmpty { baseName = "New Folder" }

        let parentURL = parent ?? syncFolderPath
        var targetURL = parentURL.appendingPathComponent(baseName)

        let fm = FileManager.default
        var counter = 2
        while fm.fileExists(atPath: targetURL.path) {
            targetURL = parentURL.appendingPathComponent("\(baseName) \(counter)")
            counter += 1
        }

        try fm.createDirectory(at: targetURL, withIntermediateDirectories: true)
        loadAll()
    }

    // MARK: - Import (Drop-In)

    func importFiles(urls: [URL], to folder: URL?) {
        let destinationFolder = folder ?? syncFolderPath
        let fm = FileManager.default

        Task.detached { [weak self] in
            var changed = false
            for url in urls {
                // Ignore items already in the target folder
                guard url.deletingLastPathComponent().standardized != destinationFolder.standardized else { continue }
                
                let fileName = url.lastPathComponent
                var targetURL = destinationFolder.appendingPathComponent(fileName)
                
                // Auto-rename if duplicate exists
                var counter = 2
                while fm.fileExists(atPath: targetURL.path) {
                    let ext = url.pathExtension
                    let base = url.deletingPathExtension().lastPathComponent
                    let appended = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
                    targetURL = destinationFolder.appendingPathComponent(appended)
                    counter += 1
                }
                
                do {
                    try fm.copyItem(at: url, to: targetURL)
                    changed = true
                } catch {
                    // Ignore individual copy failures
                }
            }
            if changed {
                Task { @MainActor [weak self] in
                    self?.loadAll()
                }
            }
        }
    }

    // MARK: - Filtering

    var displayedDocuments: [SyncSeeker.Document] {
        var docs = allDocuments

        if let folderPath = selectedFolderPath {
            let prefix = folderPath.path + "/"
            docs = docs.filter { $0.path.path.hasPrefix(prefix) || $0.path.deletingLastPathComponent().path == folderPath.path }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            docs = docs.filter { doc in
                doc.name.lowercased().contains(query) ||
                doc.tags.contains { $0.lowercased().contains(query) }
            }
        }

        return docs
    }

    func selectFolder(_ path: URL?) {
        selectedFolderPath = path
    }

    // MARK: - File Actions

    func trashFile(_ document: SyncSeeker.Document) throws {
        let url = document.path

        Task.detached {
            var resultingURL: NSURL? = nil
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if self.selectedDocument?.id == document.id {
                        self.selectedDocument = nil
                    }
                    self.loadAll()
                }
            } catch {
                print("Failed to move to trash: \(error)")
            }
        }
    }

    func moveFile(_ document: SyncSeeker.Document, to destinationFolder: URL) async throws {
        let sourceURL = document.path
        let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        try await Task.detached {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        }.value
        loadAll()
    }

    func duplicateFile(_ document: SyncSeeker.Document) async throws {
        let sourceURL = document.path
        let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let newName = ext.isEmpty ? "\(nameWithoutExt) copy" : "\(nameWithoutExt) copy.\(ext)"
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
        try await Task.detached {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }.value
        loadAll()
    }

    // MARK: - Private

    private func loadFolders() {
        do { folders = try fileService.listFolders(at: syncFolderPath) }
        catch { folders = [] }
    }

    private func loadDocumentsRecursive(at path: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: path,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            allDocuments = []
            return
        }

        var docs: [SyncSeeker.Document] = []
        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isDirectory != true else { continue }
            let tags = (try? annotationService.readTags(at: url)) ?? []
            docs.append(SyncSeeker.Document(
                name: url.lastPathComponent,
                path: url,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? Date(),
                fileType: fileService.detectFileType(at: url),
                tags: tags
            ))
        }
        allDocuments = docs.sorted { $0.name < $1.name }
    }

    private func ensureSyncFolder() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: syncFolderPath.path) {
            try? fm.createDirectory(at: syncFolderPath, withIntermediateDirectories: true)
        }
    }
}
#endif
