import Foundation
@testable import SyncSeeker

/// テスト用データチャネル。送信データを記録し、接続・切断を追跡する。
final class MockDataChannel: DataChannelProtocol, @unchecked Sendable {

    var connectCalled = false
    var closeCalled = false
    var connectError: Error?
    var sendError: Error?

    /// send() で渡されたデータの累積ストリーム
    private(set) var receivedData = Data()
    /// send() が呼ばれた回数
    private(set) var sendCallCount = 0

    func connect() throws {
        connectCalled = true
        if let error = connectError { throw error }
    }

    func send(_ data: Data) throws {
        if let error = sendError { throw error }
        receivedData += data
        sendCallCount += 1
    }

    func close() {
        closeCalled = true
    }

    // MARK: - Parse helpers (テスト検証用)

    /// 受信ストリームの先頭4バイトが magic と一致するか
    func hasSyncMagic() -> Bool {
        guard receivedData.count >= 4 else { return false }
        return receivedData.prefix(4) == "SYNC".data(using: .utf8)!
    }

    /// 受信ストリームの末尾4バイトが DONE か
    func hasDoneSentinel() -> Bool {
        guard receivedData.count >= 4 else { return false }
        return receivedData.suffix(4) == "DONE".data(using: .utf8)!
    }

    /// ヘッダーに含まれる file_count を返す
    func declaredFileCount() -> Int? {
        guard receivedData.count >= 8 else { return nil }
        return Int(receivedData.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian })
    }
}
