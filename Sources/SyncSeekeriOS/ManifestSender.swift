import Foundation
import Network
import SyncSeeker

/// iPad から Mac のポート 2347 に FileManifest を JSON で送信する。
public final class ManifestSender: @unchecked Sendable {

    public init() {}

    /// iPad のマニフェストを Mac へ送信する。
    /// - Parameters:
    ///   - syncDirectory: iPad のマニフェストを生成する対象ディレクトリ
    ///   - macHost: Mac のホスト名/IP アドレス
    ///   - port: Mac の受信ポート（デフォルト 2347）
    public func send(syncDirectory: URL, to macHost: NWEndpoint.Host, port: UInt16 = 2347) throws {
        // iPad のマニフェストを構築
        let manifest = try ManifestBuilder().buildManifest(at: syncDirectory)

        // JSON 化
        let data = try JSONEncoder().encode(manifest)

        // Mac へ接続して送信
        let connection = NWConnection(to: NWEndpoint.hostPort(host: macHost, port: NWEndpoint.Port(rawValue: port)!), using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("ManifestSender connection failed: \(error)")
            default:
                break
            }
        }

        let sendSemaphore = DispatchSemaphore(value: 0)
        var sendError: Error?

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                sendError = error
                print("ManifestSender send error: \(error)")
            }
            connection.cancel()
            sendSemaphore.signal()
        })

        connection.start(queue: .global(qos: .userInitiated))

        // 送信完了を待機（タイムアウト 30 秒）
        let waitResult = sendSemaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            throw NSError(domain: "ManifestSender", code: -1, userInfo: [NSLocalizedDescriptionKey: "Send timeout"])
        }
        if let error = sendError {
            throw error
        }
    }
}
