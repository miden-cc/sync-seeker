import Foundation
import Testing
@testable import SyncSeeker

@Suite("USBMuxdConnection")
struct USBMuxdConnectionTests {

    // MARK: - Initial state

    @Test("Initial state is disconnected")
    func initialState() {
        let mock = MockUsbmuxdSocket()
        let conn = USBMuxdConnection(socket: mock)

        #expect(conn.currentState == .disconnected)
    }

    // MARK: - startMonitoring

    @Test("startMonitoring connects to /var/run/usbmuxd")
    func startMonitoringConnectsToSocket() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()  // listen response

        let conn = USBMuxdConnection(socket: mock)
        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.05) // allow monitor thread to start

        #expect(mock.connectCalled)
        #expect(mock.connectedPath == "/var/run/usbmuxd")
    }

    @Test("startMonitoring sends Listen request")
    func startMonitoringSendsListenRequest() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()

        let conn = USBMuxdConnection(socket: mock)
        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.05)

        #expect(mock.sentData.isEmpty == false)

        // First sent packet should contain MessageType=Listen
        let firstPacket = mock.sentData[0]
        let body = Data(firstPacket.dropFirst(16))
        let plist = try PropertyListSerialization.propertyList(from: body, format: nil) as? [String: Any]
        #expect(plist?["MessageType"] as? String == "Listen")
    }

    @Test("startMonitoring socket error propagates to delegate")
    func startMonitoringSocketError() throws {
        let mock = MockUsbmuxdSocket()
        mock.connectError = NSError(domain: "POSIX", code: 2, userInfo: [NSLocalizedDescriptionKey: "usbmuxd not found"])

        let delegate = SpyDelegate()
        let conn = USBMuxdConnection(socket: mock)
        conn.delegate = delegate

        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.05)

        #expect(delegate.lastState != nil)
        if case .error = delegate.lastState! {
            // pass
        } else {
            Issue.record("Expected error state, got \(delegate.lastState!)")
        }
    }

    // MARK: - Device attach/detach

    @Test("Attached event notifies delegate with correct device")
    func deviceAttached() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()
        try mock.enqueueDeviceAttached(id: 3, serial: "IPAD0001")
        // sentinel: empty header to stop the loop
        mock.receiveError = NSError(domain: "EOF", code: 0)

        let delegate = SpyDelegate()
        let conn = USBMuxdConnection(socket: mock)
        conn.delegate = delegate

        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.1)

        #expect(delegate.detectedDevices.count == 1)
        #expect(delegate.detectedDevices.first?.id == 3)
        #expect(delegate.detectedDevices.first?.serialNumber == "IPAD0001")
    }

    @Test("Detached event notifies delegate")
    func deviceDetached() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()
        try mock.enqueueDeviceAttached(id: 3, serial: "IPAD0001")
        try mock.enqueueDeviceDetached(id: 3)
        mock.receiveError = NSError(domain: "EOF", code: 0)

        let delegate = SpyDelegate()
        let conn = USBMuxdConnection(socket: mock)
        conn.delegate = delegate

        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.1)

        #expect(delegate.lostDevices.count == 1)
        #expect(delegate.lostDevices.first?.id == 3)
    }

    // MARK: - stopMonitoring

    @Test("stopMonitoring disconnects socket")
    func stopMonitoring() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()

        let conn = USBMuxdConnection(socket: mock)
        conn.startMonitoring()
        Thread.sleep(forTimeInterval: 0.05)

        conn.stopMonitoring()

        #expect(mock.disconnectCalled)
    }

    // MARK: - connectToDevice

    @Test("connectToDevice sends Connect request with network-byte-order port")
    func connectToDevice() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()  // connect response

        let device = USBDeviceInfo(id: 5, serialNumber: "TEST", productName: "iPad", connectionType: .usb)
        let conn = USBMuxdConnection(socket: mock)

        try conn.connectToDevice(device, port: 2345)

        let packet = mock.sentData[0]
        let body = Data(packet.dropFirst(16))
        let plist = try PropertyListSerialization.propertyList(from: body, format: nil) as? [String: Any]

        #expect(plist?["MessageType"] as? String == "Connect")
        #expect(plist?["DeviceID"] as? Int == 5)

        let expectedNetworkPort = Int(UInt16(2345).bigEndian)
        #expect(plist?["PortNumber"] as? Int == expectedNetworkPort)
    }

    @Test("connectToDevice updates state to connected on success")
    func connectToDeviceSuccess() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()

        let device = USBDeviceInfo(id: 5, serialNumber: "TEST", productName: "iPad", connectionType: .usb)
        let delegate = SpyDelegate()
        let conn = USBMuxdConnection(socket: mock)
        conn.delegate = delegate

        try conn.connectToDevice(device, port: 2345)

        #expect(conn.currentState == .connected(device))
        #expect(delegate.lastState == .connected(device))
    }

    @Test("connectToDevice throws on non-zero result code")
    func connectToDeviceFailure() throws {
        let mock = MockUsbmuxdSocket()
        // Enqueue a Result with error code 3
        let body = try PropertyListSerialization.data(
            fromPropertyList: ["MessageType": "Result", "Number": 3],
            format: .xml, options: 0
        )
        let total = UInt32(16 + body.count)
        var header = Data(count: 16)
        header.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: total.littleEndian,     toByteOffset:  0, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian, toByteOffset:  4, as: UInt32.self)
            ptr.storeBytes(of: UInt32(1).littleEndian, toByteOffset:  8, as: UInt32.self)
            ptr.storeBytes(of: UInt32(0).littleEndian, toByteOffset: 12, as: UInt32.self)
        }
        mock.receiveQueue.append(header)
        mock.receiveQueue.append(body)

        let device = USBDeviceInfo(id: 5, serialNumber: "TEST", productName: "iPad", connectionType: .usb)
        let conn = USBMuxdConnection(socket: mock)

        #expect(throws: UsbmuxdError.self) {
            try conn.connectToDevice(device, port: 2345)
        }
    }

    // MARK: - disconnect

    @Test("disconnect resets state and notifies delegate")
    func disconnect() throws {
        let mock = MockUsbmuxdSocket()
        try mock.enqueueResultSuccess()

        let device = USBDeviceInfo(id: 5, serialNumber: "TEST", productName: "iPad", connectionType: .usb)
        let delegate = SpyDelegate()
        let conn = USBMuxdConnection(socket: mock)
        conn.delegate = delegate

        try conn.connectToDevice(device, port: 2345)
        conn.disconnect()

        #expect(conn.currentState == .disconnected)
        #expect(delegate.lastState == .disconnected)
    }
}

// MARK: - SpyDelegate

private final class SpyDelegate: USBConnectionDelegate {
    var lastState: ConnectionState?
    var detectedDevices: [USBDeviceInfo] = []
    var lostDevices: [USBDeviceInfo] = []

    func connectionDidChangeState(_ newState: ConnectionState) {
        lastState = newState
    }
    func connectionDidDetectDevice(_ device: USBDeviceInfo) {
        detectedDevices.append(device)
    }
    func connectionDidLoseDevice(_ device: USBDeviceInfo) {
        lostDevices.append(device)
    }
}
