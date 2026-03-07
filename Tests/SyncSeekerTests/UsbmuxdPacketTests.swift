import Foundation
import Testing
@testable import SyncSeeker

@Suite("UsbmuxdPacket")
struct UsbmuxdPacketTests {

    // MARK: - Encode

    @Test("Listen request has valid 16-byte header with correct length")
    func encodeListenHeader() throws {
        let data = try UsbmuxdPacket.encodeListenRequest(tag: 1)

        #expect(data.count >= 16)

        // First 4 bytes = total length (little-endian)
        let declaredLength = data.withUnsafeBytes {
            $0.load(fromByteOffset: 0, as: UInt32.self).littleEndian
        }
        #expect(Int(declaredLength) == data.count)
    }

    @Test("Listen request contains MessageType Listen in plist body")
    func encodeListenBody() throws {
        let data = try UsbmuxdPacket.encodeListenRequest(tag: 1)
        let body = data.dropFirst(16)

        let plist = try #require(
            try PropertyListSerialization.propertyList(from: Data(body), format: nil) as? [String: Any]
        )
        #expect(plist["MessageType"] as? String == "Listen")
    }

    @Test("Connect request contains DeviceID and big-endian PortNumber")
    func encodeConnect() throws {
        let data = try UsbmuxdPacket.encodeConnectRequest(deviceID: 42, port: 2345, tag: 2)
        let body = data.dropFirst(16)

        let plist = try #require(
            try PropertyListSerialization.propertyList(from: Data(body), format: nil) as? [String: Any]
        )
        #expect(plist["MessageType"] as? String == "Connect")
        #expect(plist["DeviceID"] as? Int == 42)

        // Port 2345 in big-endian: 0x0929 → stored as int 0x2909 = 10505
        let expectedNetworkPort = Int(UInt16(2345).bigEndian)
        #expect(plist["PortNumber"] as? Int == expectedNetworkPort)
    }

    // MARK: - Decode Result

    @Test("Decode Result with code 0 (success)")
    func decodeResultSuccess() throws {
        let raw = try makePacket(type: 1, plist: ["MessageType": "Result", "Number": 0])
        let message = try UsbmuxdPacket.decode(raw)

        guard case .result(let code) = message else {
            Issue.record("Expected .result, got \(message)")
            return
        }
        #expect(code == 0)
    }

    @Test("Decode Result with non-zero error code")
    func decodeResultError() throws {
        let raw = try makePacket(type: 1, plist: ["MessageType": "Result", "Number": 3])
        let message = try UsbmuxdPacket.decode(raw)

        guard case .result(let code) = message else {
            Issue.record("Expected .result, got \(message)")
            return
        }
        #expect(code == 3)
    }

    // MARK: - Decode DeviceAttached

    @Test("Decode Attached produces correct USBDeviceInfo")
    func decodeAttached() throws {
        let raw = try makePacket(type: 8, plist: [
            "MessageType": "Attached",
            "DeviceID": 5,
            "Properties": [
                "ConnectionType": "USB",
                "DeviceID": 5,
                "ProductID": 0x12A8,
                "SerialNumber": "ABC123DEF456"
            ] as [String: Any]
        ])

        let message = try UsbmuxdPacket.decode(raw)

        guard case .deviceAttached(let device) = message else {
            Issue.record("Expected .deviceAttached, got \(message)")
            return
        }
        #expect(device.id == 5)
        #expect(device.serialNumber == "ABC123DEF456")
        #expect(device.connectionType == .usb)
    }

    @Test("Decode Attached over network sets connectionType to .network")
    func decodeAttachedNetwork() throws {
        let raw = try makePacket(type: 8, plist: [
            "MessageType": "Attached",
            "DeviceID": 7,
            "Properties": [
                "ConnectionType": "Network",
                "DeviceID": 7,
                "ProductID": 0x12A8,
                "SerialNumber": "NET999"
            ] as [String: Any]
        ])

        let message = try UsbmuxdPacket.decode(raw)

        guard case .deviceAttached(let device) = message else {
            Issue.record("Expected .deviceAttached, got \(message)")
            return
        }
        #expect(device.connectionType == .network)
    }

    @Test("Decode Attached without required fields throws invalidPacket")
    func decodeAttachedMissingFields() throws {
        let raw = try makePacket(type: 8, plist: [
            "MessageType": "Attached",
            "DeviceID": 5
            // Missing Properties
        ])
        #expect(throws: UsbmuxdError.self) {
            try UsbmuxdPacket.decode(raw)
        }
    }

    // MARK: - Decode DeviceDetached

    @Test("Decode Detached returns correct deviceID")
    func decodeDetached() throws {
        let raw = try makePacket(type: 9, plist: ["MessageType": "Detached", "DeviceID": 5])
        let message = try UsbmuxdPacket.decode(raw)

        guard case .deviceDetached(let deviceID) = message else {
            Issue.record("Expected .deviceDetached, got \(message)")
            return
        }
        #expect(deviceID == 5)
    }

    // MARK: - Error cases

    @Test("Decode data shorter than 16 bytes throws invalidPacket")
    func decodeTooShort() {
        #expect(throws: UsbmuxdError.self) {
            try UsbmuxdPacket.decode(Data([0xFF, 0x00]))
        }
    }

    @Test("Decode unknown message type returns .unknown")
    func decodeUnknown() throws {
        let raw = try makePacket(type: 99, plist: ["MessageType": "Future"])
        let message = try UsbmuxdPacket.decode(raw)

        guard case .unknown = message else {
            Issue.record("Expected .unknown, got \(message)")
            return
        }
    }

    // MARK: - Helper

    private func makePacket(type: UInt32, plist: [String: Any]) throws -> Data {
        let body = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let totalLength = UInt32(16 + body.count)

        var header = Data(count: 16)
        header.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: totalLength.littleEndian,   toByteOffset:  0, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian,     toByteOffset:  4, as: UInt32.self)
            ptr.storeBytes(of: type.littleEndian,          toByteOffset:  8, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian,     toByteOffset: 12, as: UInt32.self)
        }
        return header + body
    }
}
