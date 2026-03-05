import Foundation
import SwiftUI
import SyncSeeker

@Observable @MainActor
final class AppState {
    var allDocuments: [SyncSeeker.Document] = []
    var selectedDocument: SyncSeeker.Document?
    var searchText: String = ""
    var isConnected: Bool = false
    var folders: [SyncSeeker.Folder] = []
    var selectedFolderPath: URL?
    let syncFolderPath: URL

    private let fileService = LocalFileService()
    private let annotationService = XattrAnnotationService()
    private var fileWatcher: FileWatcherService?
    private var refreshTask: Task<Void, Never>?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.syncFolderPath = home.appendingPathComponent("SyncSeeker")
        ensureSyncFolder()
        loadAll()
        startFileWatcher()
    }

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
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒のデバウンス
            if !Task.isCancelled {
                self.loadAll()
            }
        }
    }

    func loadAll() {
        loadFolders()
        loadDocumentsRecursive(at: syncFolderPath)
    }

    func refresh() {
        loadAll()
    }

    var displayedDocuments: [SyncSeeker.Document] {
        var docs = allDocuments

        // フォルダフィルタ
        if let folderPath = selectedFolderPath {
            let prefix = folderPath.path + "/"
            docs = docs.filter { $0.path.path.hasPrefix(prefix) || $0.path.deletingLastPathComponent().path == folderPath.path }
        }

        // 検索フィルタ
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

    private func loadFolders() {
        do {
            folders = try fileService.listFolders(at: syncFolderPath)
        } catch {
            folders = []
        }
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
