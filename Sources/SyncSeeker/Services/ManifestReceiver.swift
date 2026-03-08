import Foundation
import Network

/// Mac 側でポート 2347 を listen し、iPad の JSON マニフェストを受信する。
public final class ManifestReceiver: @unchecked Sendable {

    public var onManifestReceived: ((FileManifest) -> Void)?

    private var listener: NWListener?
    private let port: NWEndpoint.Port
    private var isRunning = false

    public init(port: UInt16 = 2347) {
        self.port = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 2347)!
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

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
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            isRunning = false
            print("ManifestReceiver failed to start: \(error)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    /// マニフェスト受信を待機する（タイムアウト付き）
    public func waitForManifest(timeout: TimeInterval) async throws -> FileManifest {
        return try await withTimeout(timeout) {
            while self.isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms ポーリング
            }
            throw NSError(domain: "ManifestReceiver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for manifest"])
        }
    }

    // MARK: - Private

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveNextChunk(on: connection, accumulatedData: Data())
    }

    private func receiveNextChunk(on connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self else { return }

            var newData = accumulatedData
            if let content { newData.append(content) }

            if isComplete || error != nil {
                self.processReceivedData(newData)
                connection.cancel()
            } else {
                self.receiveNextChunk(on: connection, accumulatedData: newData)
            }
        }
    }

    private func processReceivedData(_ data: Data) {
        do {
            if data.isEmpty { return }
            let manifest = try JSONDecoder().decode(FileManifest.self, from: data)
            onManifestReceived?(manifest)
            isRunning = false
        } catch {
            print("ManifestReceiver.processReceivedData error: \(error)")
            isRunning = false
        }
    }

    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isRunning {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "ManifestReceiver", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
    }
}
