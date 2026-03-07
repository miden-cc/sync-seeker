import Foundation
import Network
import SyncSeeker

// MARK: - Model

public struct ReceivedFile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let relativePath: String
    public let url: URL
    public let size: Int64
    public let modifiedDate: Date

    public var name: String { url.lastPathComponent }
    public var fileExtension: String { url.pathExtension.lowercased() }
}

// MARK: - SyncListener

/// iPad 側で usbmuxd 経由の接続（Macからの同期）を受け付けるリスナー
@MainActor
public final class SyncListener: ObservableObject {
    @Published public var isListening = false
    @Published public var statusText = "Ready to receive sync..."
    @Published public var receivedFiles: [ReceivedFile] = []

    public var receivedFilesCount: Int { receivedFiles.count }

    private var listener: NWListener?
    private let port: NWEndpoint.Port = 2345
    public let syncDirectory: URL

    public init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        syncDirectory = docs.appendingPathComponent("SyncSeeker_Received")

        if !fm.fileExists(atPath: syncDirectory.path) {
            try? fm.createDirectory(at: syncDirectory, withIntermediateDirectories: true)
        }

        scanDirectory()
    }

    // MARK: - Public

    public func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)

            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.statusText = "Listening on port \(self?.port.rawValue ?? 2345)..."
                    case .failed(let error):
                        self?.statusText = "Listener failed: \(error.localizedDescription)"
                        self?.stop()
                    case .cancelled:
                        self?.isListening = false
                        self?.statusText = "Stopped listening."
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            statusText = "Failed to start listener: \(error.localizedDescription)"
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    // MARK: - Directory scan

    /// 起動時・同期後に syncDirectory を走査してファイルリストを更新する
    public func scanDirectory() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: syncDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            receivedFiles = []
            return
        }

        var files: [ReceivedFile] = []
        while let url = enumerator.nextObject() as? URL {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isDirectory != true else { continue }
            files.append(ReceivedFile(
                id: UUID(),
                relativePath: String(url.path.dropFirst(syncDirectory.path.count + 1)),
                url: url,
                size: Int64(values.fileSize ?? 0),
                modifiedDate: values.contentModificationDate ?? Date()
            ))
        }
        receivedFiles = files.sorted { $0.relativePath < $1.relativePath }
    }

    // MARK: - Connection handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        statusText = "Receiving sync data from Mac..."
        receiveNextChunk(on: connection, accumulatedData: Data())
    }

    private func receiveNextChunk(on connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            var newData = accumulatedData
            if let content { newData.append(content) }

            if isComplete || error != nil {
                Task { @MainActor in self.processReceivedData(newData) }
                connection.cancel()
            } else {
                Task { @MainActor in self.receiveNextChunk(on: connection, accumulatedData: newData) }
            }
        }
    }

    private func processReceivedData(_ data: Data) {
        Task { @MainActor in
            do {
                if data.isEmpty { return }

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
                    let fileURL = syncDirectory.appendingPathComponent(path)
                    try? fm.removeItem(at: fileURL)
                }

                scanDirectory()

                let added = stream.files.count
                let deleted = stream.deletions.count
                if added > 0 || deleted > 0 {
                    statusText = "Synced: +\(added) / -\(deleted) files"
                } else {
                    statusText = "Nothing changed."
                }
            } catch {
                statusText = "Sync error: \(error.localizedDescription)"
            }
        }
    }
}
