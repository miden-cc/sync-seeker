import Foundation
import Network

/// ネットワーク I/O を抽象化するチャネル。テスト時はモックに差し替え可能。
protocol DataChannelProtocol: AnyObject, Sendable {
    /// サーバーに接続する（同期ブロッキング）。
    func connect() throws
    /// データを送信する。
    func send(_ data: Data) throws
    /// チャネルを閉じる。
    func close()
}

// MARK: - TCP implementation (USB tunnel 経由)

/// Network.framework の NWConnection を使った TCP チャネル。
/// USB トンネル経由でデバイスに接続する。
final class TCPDataChannel: DataChannelProtocol, @unchecked Sendable {

    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.miden.tcp-channel")

    init(host: NWEndpoint.Host, port: NWEndpoint.Port) {
        self.host = host
        self.port = port
    }

    static func make(host: NWEndpoint.Host, port: NWEndpoint.Port) -> DataChannelProtocol {
        TCPDataChannel(host: host, port: port)
    }

    func connect() throws {
        let conn = NWConnection(host: host, port: port, using: .tcp)
        self.connection = conn

        let semaphore = DispatchSemaphore(value: 0)
        let errorBox = ErrorBox()

        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            case .failed(let error):
                errorBox.error = error
                semaphore.signal()
            case .cancelled:
                semaphore.signal()
            default:
                break
            }
        }

        conn.start(queue: queue)

        let timeout = DispatchTime.now() + .seconds(10)
        if semaphore.wait(timeout: timeout) == .timedOut {
            conn.cancel()
            throw DataChannelError.timeout
        }
        if let error = errorBox.error {
            throw error
        }
    }

    func send(_ data: Data) throws {
        guard let conn = connection else {
            throw DataChannelError.notConnected
        }

        let semaphore = DispatchSemaphore(value: 0)
        let errorBox = ErrorBox()

        conn.send(content: data, completion: .contentProcessed { error in
            errorBox.error = error
            semaphore.signal()
        })

        semaphore.wait()
        if let error = errorBox.error {
            throw error
        }
    }

    func close() {
        connection?.cancel()
        connection = nil
    }
}

enum DataChannelError: Error {
    case notConnected
    case timeout
}

/// @Sendable クロージャからエラーを伝達するためのスレッドセーフなラッパー。
private final class ErrorBox: @unchecked Sendable {
    var error: Error?
}
