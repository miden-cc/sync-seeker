import Foundation

// MARK: - Message types

enum UsbmuxdMessage {
    case result(code: Int)
    case deviceAttached(USBDeviceInfo)
    case deviceDetached(deviceID: Int)
    case unknown(type: UInt32)
}

enum UsbmuxdError: Error, Equatable, LocalizedError {
    case invalidPacket(String)
    case resultError(code: Int)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPacket(let msg): return "Invalid packet: \(msg)"
        case .resultError(let code): return "usbmuxd result error (code \(code))"
        case .connectionFailed(let msg): return "usbmuxd connection failed: \(msg)"
        }
    }
}

// MARK: - Packet codec

enum UsbmuxdPacket {

    private static let headerSize = 16

    // macOS 12+ の plist プロトコルでは全メッセージが type 8 (PLIST)
    private static let typePlist:    UInt32 = 8
    private static let typeResult:   UInt32 = 1   // 旧プロトコル互換
    private static let typeAttached: UInt32 = 8
    private static let typeDetached: UInt32 = 9

    // MARK: Encode

    static func encodeListenRequest(tag: UInt32 = 1) throws -> Data {
        let body: [String: Any] = [
            "BundleID":            "com.miden.SyncSeeker",
            "ClientVersionString": "1.0",
            "MessageType":         "Listen",
            "ProgName":            "SyncSeeker",
            "kLibUSBMuxVersion":   3
        ]
        return try encode(type: typePlist, tag: tag, body: body)
    }

    static func encodeConnectRequest(deviceID: Int, port: UInt16, tag: UInt32 = 2) throws -> Data {
        let networkPort = Int(port.bigEndian)
        let body: [String: Any] = [
            "BundleID":            "com.miden.SyncSeeker",
            "ClientVersionString": "1.0",
            "DeviceID":            deviceID,
            "MessageType":         "Connect",
            "PortNumber":          networkPort,
            "ProgName":            "SyncSeeker",
            "kLibUSBMuxVersion":   3
        ]
        return try encode(type: typePlist, tag: tag, body: body)
    }

    // MARK: Decode

    static func decode(_ data: Data) throws -> UsbmuxdMessage {
        guard data.count >= headerSize else {
            throw UsbmuxdError.invalidPacket("Data too short: \(data.count) bytes")
        }

        let msgLength = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian }
        let msgType   = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).littleEndian }

        guard msgLength >= headerSize else {
            throw UsbmuxdError.invalidPacket("Packet length \(msgLength) too small, minimum is \(headerSize)")
        }
        guard Int(msgLength) <= data.count else {
            throw UsbmuxdError.invalidPacket("Declared length \(msgLength) exceeds data size \(data.count)")
        }

        let body = data.subdata(in: headerSize..<Int(msgLength))
        guard let plist = try? PropertyListSerialization.propertyList(from: body, format: nil) as? [String: Any] else {
            throw UsbmuxdError.invalidPacket("Body is not a valid plist dictionary")
        }

        // macOS 26+ では全メッセージが type=8 (plist) で来て MessageType フィールドで種別を判定する
        let messageTypeStr = plist["MessageType"] as? String

        let isResult   = msgType == typeResult   || messageTypeStr == "Result"
        let isAttached = msgType == typeAttached  || messageTypeStr == "Attached"
        let isDetached = msgType == typeDetached  || messageTypeStr == "Detached"

        if isResult {
            let number = plist["Number"] as? Int ?? -1
            return .result(code: number)

        } else if isAttached {
            // DeviceID は Int / UInt32 どちらでも受け付ける
            let deviceID: Int
            if let id = plist["DeviceID"] as? Int {
                deviceID = id
            } else if let id = (plist["DeviceID"] as? UInt32) {
                deviceID = Int(id)
            } else {
                let keys = plist.keys.joined(separator: ", ")
                throw UsbmuxdError.invalidPacket("Missing DeviceID in Attached message (keys: \(keys))")
            }

            let props = plist["Properties"] as? [String: Any] ?? [:]
            let serial = props["SerialNumber"] as? String
                      ?? plist["SerialNumber"] as? String
                      ?? ""
            let connType: USBDeviceInfo.ConnectionType =
                (props["ConnectionType"] as? String) == "Network" ? .network : .usb
            let device = USBDeviceInfo(
                id:             deviceID,
                serialNumber:   serial,
                productName:    props["ProductName"] as? String ?? "Apple Device",
                connectionType: connType
            )
            return .deviceAttached(device)

        } else if isDetached {
            let deviceID = (plist["DeviceID"] as? Int)
                        ?? (plist["DeviceID"] as? UInt32).map { Int($0) }
            guard let id = deviceID else {
                throw UsbmuxdError.invalidPacket("Missing DeviceID in Detached message")
            }
            return .deviceDetached(deviceID: id)

        } else {
            return .unknown(type: msgType)
        }
    }

    // MARK: - Private

    private static func encode(type: UInt32, tag: UInt32, body: [String: Any]) throws -> Data {
        let plistData = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
        let totalLength = UInt32(headerSize + plistData.count)

        var header = Data(count: headerSize)
        header.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: totalLength.littleEndian, toByteOffset:  0, as: UInt32.self)
            ptr.storeBytes(of: UInt32(1).littleEndian,   toByteOffset:  4, as: UInt32.self) // protocol version: 1 = plist
            ptr.storeBytes(of: type.littleEndian,        toByteOffset:  8, as: UInt32.self)
            ptr.storeBytes(of: tag.littleEndian,         toByteOffset: 12, as: UInt32.self)
        }
        return header + plistData
    }
}
