import Foundation
import Network
import SyncSeeker

/// iPad から Mac のポート 2346 に全ファイルを SyncFrame 形式で送信する。
/// FileSender (Mac版) と対称実装。差分なしで全ファイル送信（Mac 側が差分計算済み）。
public final class FileSenderToMac: @unchecked Sendable {

    public init() {}

    /// iPad の全ファイルを Mac へ送信する。
    /// - Parameters:
    ///   - syncDirectory: ファイルを読み込む対象ディレクトリ
    ///   - macHost: Mac のホスト名/IP アドレス
    ///   - port: Mac の受信ポート（デフォルト 2346）
    public func send(from syncDirectory: URL, to macHost: NWEndpoint.Host, port: UInt16 = 2346) throws {
        // iPad のマニフェストを構築（全ファイル）
        let manifest = try ManifestBuilder().buildManifest(at: syncDirectory)

        // Mac へ接続
        let connection = NWConnection(to: NWEndpoint.hostPort(host: macHost, port: NWEndpoint.Port(rawValue: port)!), using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                print("FileSenderToMac connection failed: \(error)")
            default:
                break
            }
        }

        let fm = FileManager.default

        // ヘッダー送信（全ファイル、削除なし）
        let header = SyncFrameEncoder.encodeHeader(fileCount: manifest.entries.count, deleteCount: 0)
        try sendData(header, on: connection)

        // 各ファイルを送信
        for entry in manifest.entries {
            let fileURL = syncDirectory.appendingPathComponent(entry.relativePath)
            do {
                let fileData = try Data(contentsOf: fileURL)
                let xattrs = XattrIO.readAll(at: fileURL)
                let frame = try SyncFrameEncoder.encodeFile(entry: entry, fileData: fileData, xattrs: xattrs)
                try sendData(frame, on: connection)
            } catch {
                print("FileSenderToMac: Failed to send \(entry.relativePath): \(error)")
                continue
            }
        }

        // DONE フレーム送信
        let done = SyncFrameEncoder.encodeDone()
        try sendData(done, on: connection)

        connection.cancel()
    }

    // MARK: - Private

    private func sendData(_ data: Data, on connection: NWConnection) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var sendError: Error?

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                sendError = error
            }
            semaphore.signal()
        })

        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            throw NSError(domain: "FileSenderToMac", code: -1, userInfo: [NSLocalizedDescriptionKey: "Send timeout"])
        }
        if let error = sendError {
            throw error
        }
    }
}
