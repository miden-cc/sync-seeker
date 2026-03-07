import Foundation
@testable import SyncSeeker

/// テスト用モックソケット。送信データを記録し、事前設定した返答を返す。
final class MockUsbmuxdSocket: UsbmuxdSocketProtocol {

    // MARK: - State tracking

    var connectCalled = false
    var disconnectCalled = false
    var connectedPath: String?
    var sentData: [Data] = []

    // MARK: - Response queue

    /// receive() が呼ばれるたびに先頭から返す。空なら空 Data を返す。
    var receiveQueue: [Data] = []

    var connectError: Error?
    var sendError: Error?
    var receiveError: Error?

    // MARK: - UsbmuxdSocketProtocol

    var isConnected: Bool = false

    func connect(to path: String) throws {
        connectCalled = true
        connectedPath = path
        if let error = connectError { throw error }
        isConnected = true
    }

    func send(_ data: Data) throws {
        if let error = sendError { throw error }
        sentData.append(data)
    }

    func receive(length: Int) throws -> Data {
        // キューにデータがある間はそちらを優先する。
        // 空になったらエラーまたはゼロ埋め（監視ループ停止用）。
        guard !receiveQueue.isEmpty else {
            if let error = receiveError { throw error }
            return Data(count: length)
        }
        return receiveQueue.removeFirst()
    }

    func disconnect() {
        disconnectCalled = true
        isConnected = false
    }

    // MARK: - Helpers

    /// usbmuxd の Result(0) パケットをキューに積む。
    func enqueueResultSuccess() throws {
        let body = try PropertyListSerialization.data(
            fromPropertyList: ["MessageType": "Result", "Number": 0],
            format: .xml, options: 0
        )
        receiveQueue.append(makeHeader(type: 1, bodyLength: body.count))
        receiveQueue.append(body)
    }

    /// DeviceAttached パケットをキューに積む。
    func enqueueDeviceAttached(id: Int, serial: String, connectionType: String = "USB") throws {
        let plist: [String: Any] = [
            "MessageType": "Attached",
            "DeviceID": id,
            "Properties": [
                "ConnectionType": connectionType,
                "DeviceID": id,
                "ProductID": 0x12A8,
                "SerialNumber": serial
            ] as [String: Any]
        ]
        let body = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        receiveQueue.append(makeHeader(type: 8, bodyLength: body.count))
        receiveQueue.append(body)
    }

    /// DeviceDetached パケットをキューに積む。
    func enqueueDeviceDetached(id: Int) throws {
        let plist: [String: Any] = ["MessageType": "Detached", "DeviceID": id]
        let body = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        receiveQueue.append(makeHeader(type: 9, bodyLength: body.count))
        receiveQueue.append(body)
    }

    private func makeHeader(type: UInt32, bodyLength: Int) -> Data {
        let total = UInt32(16 + bodyLength)
        var header = Data(count: 16)
        header.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: total.littleEndian,     toByteOffset:  0, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian, toByteOffset:  4, as: UInt32.self)
            ptr.storeBytes(of: type.littleEndian,      toByteOffset:  8, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian, toByteOffset: 12, as: UInt32.self)
        }
        return header
    }
}
