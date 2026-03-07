import Foundation
import SwiftUI
import SyncSeeker

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
            print("Failed to start file watcher: \(error)")
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !Task.isCancelled {
                self.loadAll()
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
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let sender = FileSender()
                let count = try sender.send(to: device, from: syncFolderPath)
                await MainActor.run {
                    self.transferState = .completed(fileCount: count, totalBytes: 0)
                    self.lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    self.transferState = .error(error.localizedDescription)
                }
            }
        }
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
