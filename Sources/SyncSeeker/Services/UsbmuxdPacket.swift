import Foundation

// MARK: - Message types

enum UsbmuxdMessage {
    case result(code: Int)
    case deviceAttached(USBDeviceInfo)
    case deviceDetached(deviceID: Int)
    case unknown(type: UInt32)
}

enum UsbmuxdError: Error, Equatable {
    case invalidPacket(String)
    case resultError(code: Int)
    case connectionFailed(String)
}

// MARK: - Packet codec

enum UsbmuxdPacket {

    private static let headerSize = 16

    // usbmuxd message type codes (header field)
    private static let typeResult:   UInt32 = 1
    private static let typeConnect:  UInt32 = 3
    private static let typeListen:   UInt32 = 4
    private static let typeAttached: UInt32 = 8
    private static let typeDetached: UInt32 = 9

    // MARK: Encode

    static func encodeListenRequest(tag: UInt32 = 1) throws -> Data {
        let body: [String: Any] = [
            "BundleID":            "com.miden.SyncSeeker",
            "ClientVersionString": "1.0",
            "MessageType":         "Listen",
            "ProgName":            "SyncSeeker"
        ]
        return try encode(type: typeListen, tag: tag, body: body)
    }

    static func encodeConnectRequest(deviceID: Int, port: UInt16, tag: UInt32 = 2) throws -> Data {
        // usbmuxd expects PortNumber in network byte order (big-endian), stored as an integer
        let networkPort = Int(port.bigEndian)
        let body: [String: Any] = [
            "BundleID":            "com.miden.SyncSeeker",
            "ClientVersionString": "1.0",
            "DeviceID":            deviceID,
            "MessageType":         "Connect",
            "PortNumber":          networkPort,
            "ProgName":            "SyncSeeker"
        ]
        return try encode(type: typeConnect, tag: tag, body: body)
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

        switch msgType {
        case typeResult:
            let number = plist["Number"] as? Int ?? -1
            return .result(code: number)

        case typeAttached:
            guard
                let deviceID = plist["DeviceID"] as? Int,
                let props    = plist["Properties"] as? [String: Any],
                let serial   = props["SerialNumber"] as? String
            else {
                throw UsbmuxdError.invalidPacket("Missing required fields in Attached message")
            }
            let connType: USBDeviceInfo.ConnectionType =
                (props["ConnectionType"] as? String) == "Network" ? .network : .usb
            let device = USBDeviceInfo(
                id:             deviceID,
                serialNumber:   serial,
                productName:    props["ProductName"] as? String ?? "Apple Device",
                connectionType: connType
            )
            return .deviceAttached(device)

        case typeDetached:
            guard let deviceID = plist["DeviceID"] as? Int else {
                throw UsbmuxdError.invalidPacket("Missing DeviceID in Detached message")
            }
            return .deviceDetached(deviceID: deviceID)

        default:
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
            ptr.storeBytes(of: UInt32(0).littleEndian,   toByteOffset:  4, as: UInt32.self) // reserved
            ptr.storeBytes(of: type.littleEndian,        toByteOffset:  8, as: UInt32.self)
            ptr.storeBytes(of: tag.littleEndian,         toByteOffset: 12, as: UInt32.self)
        }
        return header + plistData
    }
}
