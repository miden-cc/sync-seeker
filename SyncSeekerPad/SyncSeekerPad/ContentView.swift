import SwiftUI
import Combine
import Network
import SyncSeeker

// MARK: - ReceivedFile

struct ReceivedFile: Identifiable, Hashable {
    let id: UUID
    let relativePath: String
    let url: URL
    let size: Int64
    let modifiedDate: Date

    var name: String { url.lastPathComponent }

    var asDocument: Document {
        let ext = url.pathExtension.lowercased()
        let fileType: FileType
        switch ext {
        case "pdf":              fileType = .pdf
        case "md", "markdown":   fileType = .markdown
        case "txt", "text":      fileType = .plainText
        case "rtf", "rtfd":      fileType = .richText
        default:                 fileType = .unknown
        }
        var tags: [String] = []
        let xattrs = XattrIO.readAll(at: url)
        if let data = xattrs["com.apple.metadata:_kMDItemUserTags"],
           let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] {
            tags = parsed
        }
        return Document(id: id, name: name, path: url,
                        size: size, modifiedDate: modifiedDate,
                        fileType: fileType, tags: tags)
    }
}

// MARK: - SyncListener

@MainActor
final class SyncListener: ObservableObject {
    @Published var isListening = false
    @Published var statusText = "受信待機中..."
    @Published var receivedFiles: [ReceivedFile] = []

    private var listener: NWListener?
    private let port: NWEndpoint.Port = 2345
    let syncDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        syncDirectory = docs.appendingPathComponent("SyncSeeker_Received")
        if !FileManager.default.fileExists(atPath: syncDirectory.path) {
            try? FileManager.default.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        }
        scanDirectory()
    }

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
            listener?.stateUpdateHandler = { state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isListening = true
                        self.statusText = "ポート \(self.port.rawValue) で待機中..."
                    case .failed(let error):
                        self.statusText = "エラー: \(error.localizedDescription)"
                        self.stop()
                    case .cancelled:
                        self.isListening = false
                        self.statusText = "停止しました"
                    default:
                        break
                    }
                }
            }
            listener?.newConnectionHandler = { connection in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handleNewConnection(connection)
                }
            }
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            statusText = "起動失敗: \(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    func scanDirectory() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: syncDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { receivedFiles = []; return }

        var files: [ReceivedFile] = []
        while let url = enumerator.nextObject() as? URL {
            guard let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  v.isDirectory != true else { continue }
            files.append(ReceivedFile(
                id: UUID(),
                relativePath: String(url.path.dropFirst(syncDirectory.path.count + 1)),
                url: url,
                size: Int64(v.fileSize ?? 0),
                modifiedDate: v.contentModificationDate ?? Date()
            ))
        }
        receivedFiles = files.sorted { $0.relativePath < $1.relativePath }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        statusText = "Mac から受信中..."
        receiveNextChunk(on: connection, accumulatedData: Data())
    }

    private func receiveNextChunk(on connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            var newData = accumulatedData
            if let content { newData.append(content) }
            if isComplete || error != nil {
                let dataToProcess = newData
                Task { @MainActor in self.processReceivedData(dataToProcess) }
                connection.cancel()
            } else {
                let dataForNextChunk = newData
                Task { @MainActor in self.receiveNextChunk(on: connection, accumulatedData: dataForNextChunk) }
            }
        }
    }

    private func processReceivedData(_ data: Data) {
        Task { @MainActor in
            guard !data.isEmpty else { return }
            do {
                let stream = try SyncFrameDecoder.decodeStream(data)
                let fm = FileManager.default

                for fileFrame in stream.files {
                    let fileURL = syncDirectory.appendingPathComponent(fileFrame.relativePath)
                    let dir = fileURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: dir.path) {
                        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                    }
                    try fileFrame.fileData.write(to: fileURL)
                    if !fileFrame.xattrs.isEmpty {
                        XattrIO.writeAll(fileFrame.xattrs, to: fileURL)
                    }
                }
                for path in stream.deletions {
                    try? fm.removeItem(at: syncDirectory.appendingPathComponent(path))
                }

                scanDirectory()
                let a = stream.files.count, d = stream.deletions.count
                statusText = a + d > 0 ? "+\(a) / -\(d) 件を同期しました" : "変更なし"
            } catch {
                statusText = "受信エラー: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - State adapter

@Observable @MainActor
final class PadState {
    var selectedDocument: Document?
    var searchText: String = ""
    var selectedFolderPath: URL?
    let listener = SyncListener()

    init() { listener.start() }

    var allDocuments: [Document] { listener.receivedFiles.map(\.asDocument) }

    var folders: [Folder] {
        let dirs = Set(listener.receivedFiles.compactMap { f -> String? in
            let parts = f.relativePath.components(separatedBy: "/")
            return parts.count > 1 ? parts[0] : nil
        })
        return dirs.sorted().map { name in
            Folder(id: UUID(), name: name,
                   path: listener.syncDirectory.appendingPathComponent(name),
                   children: [], documents: [])
        }
    }

    var displayedDocuments: [Document] {
        var docs = allDocuments
        if let folder = selectedFolderPath {
            docs = docs.filter { $0.path.path.hasPrefix(folder.path + "/") }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            docs = docs.filter {
                $0.name.lowercased().contains(q) ||
                $0.tags.contains { $0.lowercased().contains(q) }
            }
        }
        return docs
    }

    // MARK: - File Actions

    func renameFile(_ document: Document, to newName: String) throws {
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
                self.listener.scanDirectory()
            }
        }
    }

    func trashFile(_ document: Document) throws {
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
                    self.listener.scanDirectory()
                }
            } catch {
                print("Failed to move to trash: \(error)")
            }
        }
    }

    func moveFile(_ document: Document, to destinationFolder: URL) async throws {
        let sourceURL = document.path
        let destinationURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)
        try await Task.detached {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
        }.value
        listener.scanDirectory()
    }

    func duplicateFile(_ document: Document) async throws {
        let sourceURL = document.path
        let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let newName = ext.isEmpty ? "\(nameWithoutExt) copy" : "\(nameWithoutExt) copy.\(ext)"
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
        try await Task.detached {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }.value
        listener.scanDirectory()
    }

    // MARK: - Folder Creation

    func createFolder(named name: String, inside parent: URL? = nil) throws {
        var baseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseName.isEmpty { baseName = "New Folder" }

        let parentURL = parent ?? listener.syncDirectory
        var targetURL = parentURL.appendingPathComponent(baseName)

        let fm = FileManager.default
        var counter = 2
        while fm.fileExists(atPath: targetURL.path) {
            targetURL = parentURL.appendingPathComponent("\(baseName) \(counter)")
            counter += 1
        }

        try fm.createDirectory(at: targetURL, withIntermediateDirectories: true)
        listener.scanDirectory()
    }
}

// MARK: - Root View

struct ContentView: View {
    @State private var state = PadState()
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = "New Folder"

    var body: some View {
        NavigationSplitView {
            PadSidebarView(state: state)
        } content: {
            FileListView(
                documents: state.displayedDocuments,
                selection: Bindable(state).selectedDocument,
                onTrash: { doc in
                    try? state.trashFile(doc)
                },
                onRename: { doc, newName in
                    try? state.renameFile(doc, to: newName)
                },
                folders: state.folders,
                onDuplicate: { doc in
                    Task { try? await state.duplicateFile(doc) }
                },
                onMove: { doc, destination in
                    Task { try? await state.moveFile(doc, to: destination) }
                }
            )
            .navigationTitle(sectionTitle)
            .searchable(text: Bindable(state).searchText, prompt: "ファイル名・タグで検索...")
        } detail: {
            if let doc = state.selectedDocument {
                DocumentPreviewView(document: doc)
            } else {
                ContentUnavailableView(
                    "ドキュメントを選択",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("左のリストからドキュメントを選んでください")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newFolderName = "New Folder"
                    showingNewFolderAlert = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("n", modifiers: [.shift, .command])
            }
        }
        .alert("New Folder", isPresented: $showingNewFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                try? state.createFolder(named: newFolderName, inside: state.selectedFolderPath)
            }
        }
    }

    private var sectionTitle: String {
        if !state.searchText.isEmpty { return "検索: \(state.searchText)" }
        if let f = state.selectedFolderPath { return f.lastPathComponent }
        return "すべて"
    }
}

// MARK: - Sidebar

struct PadSidebarView: View {
    var state: PadState

    var body: some View {
        List {
            Section("ライブラリ") {
                Button { state.selectedFolderPath = nil } label: {
                    Label("すべて", systemImage: "folder")
                        .badge(state.allDocuments.count)
                }
                .buttonStyle(.plain)
                .fontWeight(state.selectedFolderPath == nil ? .semibold : .regular)
            }

            if !state.folders.isEmpty {
                Section("フォルダ") {
                    ForEach(state.folders) { folder in
                        Button { state.selectedFolderPath = folder.path } label: {
                            Label(folder.name, systemImage: "folder.fill")
                        }
                        .buttonStyle(.plain)
                        .fontWeight(state.selectedFolderPath == folder.path ? .semibold : .regular)
                    }
                }
            }

            Section("受信") {
                HStack {
                    Image(systemName: state.listener.isListening
                          ? "antenna.radiowaves.left.and.right"
                          : "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(state.listener.isListening ? .green : .secondary)
                    Text(state.listener.statusText)
                        .font(.caption)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SyncSeeker")
    }
}
