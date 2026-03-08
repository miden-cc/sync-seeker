import Foundation
import Network

/// Mac 側で iPad からのファイル転送を受け付ける NWListener。
/// ポート 2346 で待機し、SyncFrame 形式で送られてきたファイルを受信する。
public final class FileReceiver: @unchecked Sendable {

    public var onCompleted: (([String]) -> Void)?

    private var listener: NWListener?
    private let port: NWEndpoint.Port
    private var receivedFiles: [String] = []
    private var isRunning = false

    public init(port: UInt16 = 2346) {
        self.port = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 2346)!
    }

    public func start(destination: URL) {
        guard !isRunning else { return }
        isRunning = true
        receivedFiles = []

        do {
            listener = try NWListener(using: .tcp, on: port)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    break  // listening
                case .failed, .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection, destination: destination)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            isRunning = false
            print("FileReceiver failed to start: \(error)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    /// 受信完了を待機する（タイムアウト付き）
    public func waitForCompletion(timeout: TimeInterval) async throws {
        let start = Date()
        while isRunning && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms ポーリング
        }
        stop()
    }

    // MARK: - Private

    private func handleConnection(_ connection: NWConnection, destination: URL) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveNextChunk(on: connection, destination: destination, accumulatedData: Data())
    }

    private func receiveNextChunk(on connection: NWConnection, destination: URL, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            var newData = accumulatedData
            if let content { newData.append(content) }

            if isComplete || error != nil {
                self.processReceivedData(newData, destination: destination)
                connection.cancel()
            } else {
                self.receiveNextChunk(on: connection, destination: destination, accumulatedData: newData)
            }
        }
    }

    private func processReceivedData(_ data: Data, destination: URL) {
        do {
            if data.isEmpty { return }

            let stream = try SyncFrameDecoder.decodeStream(data)
            let fm = FileManager.default

            for fileFrame in stream.files {
                let fileURL = destination.appendingPathComponent(fileFrame.relativePath)
                let dir = fileURL.deletingLastPathComponent()
                if !fm.fileExists(atPath: dir.path) {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                }
                try fileFrame.fileData.write(to: fileURL)
                if !fileFrame.xattrs.isEmpty {
                    XattrIO.writeAll(fileFrame.xattrs, to: fileURL)
                }
                receivedFiles.append(fileFrame.relativePath)
            }

            for path in stream.deletions {
                let fileURL = destination.appendingPathComponent(path)
                try? fm.removeItem(at: fileURL)
            }
        } catch {
            print("FileReceiver.processReceivedData error: \(error)")
        }
    }
}
