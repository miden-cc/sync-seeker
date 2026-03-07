import Foundation
import Testing
@testable import SyncSeeker

@Suite("ConnectionViewModel")
struct ConnectionViewModelTests {

    static let sampleDevice = USBDeviceInfo(
        id: 1,
        serialNumber: "ABC123",
        productName: "iPad Pro",
        connectionType: .usb
    )

    static let secondDevice = USBDeviceInfo(
        id: 2,
        serialNumber: "DEF456",
        productName: "iPad mini",
        connectionType: .usb
    )

    // MARK: - Initial State

    @Test("Initial state is disconnected")
    func initialState() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        #expect(vm.state == .disconnected)
        #expect(vm.detectedDevices.isEmpty)
    }

    // MARK: - Start / Stop Monitoring

    @Test("Start monitoring sets state to connecting")
    func startMonitoring() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()

        #expect(vm.state == .connecting)
        #expect(mock.startMonitoringCalled)
    }

    @Test("Stop monitoring resets state and clears devices")
    func stopMonitoring() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        vm.stopMonitoring()

        #expect(vm.state == .disconnected)
        #expect(vm.detectedDevices.isEmpty)
        #expect(mock.stopMonitoringCalled)
    }

    // MARK: - Device Detection

    @Test("Detected device is added to list")
    func deviceDetected() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)

        #expect(vm.detectedDevices.count == 1)
        #expect(vm.detectedDevices.first == Self.sampleDevice)
    }

    @Test("Duplicate device is not added twice")
    func duplicateDevice() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        mock.simulateDeviceDetected(Self.sampleDevice)

        #expect(vm.detectedDevices.count == 1)
    }

    @Test("Multiple different devices are tracked")
    func multipleDevices() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        mock.simulateDeviceDetected(Self.secondDevice)

        #expect(vm.detectedDevices.count == 2)
    }

    // MARK: - Device Lost

    @Test("Lost device is removed from list")
    func deviceLost() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        mock.simulateDeviceLost(Self.sampleDevice)

        #expect(vm.detectedDevices.isEmpty)
    }

    @Test("Losing connected device resets state to disconnected")
    func loseConnectedDevice() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        vm.connectToDevice(Self.sampleDevice)
        mock.simulateDeviceLost(Self.sampleDevice)

        #expect(vm.state == .disconnected)
    }

    @Test("Losing unrelated device keeps connection")
    func loseUnrelatedDevice() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        mock.simulateDeviceDetected(Self.secondDevice)
        vm.connectToDevice(Self.sampleDevice)

        mock.simulateDeviceLost(Self.secondDevice)

        #expect(vm.state == .connected(Self.sampleDevice))
        #expect(vm.detectedDevices.count == 1)
    }

    // MARK: - Connect / Disconnect

    @Test("Connect to device updates state")
    func connectToDevice() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        vm.connectToDevice(Self.sampleDevice)

        #expect(vm.state == .connected(Self.sampleDevice))
        #expect(mock.connectCalled)
        #expect(mock.lastConnectedDevice == Self.sampleDevice)
        #expect(mock.lastConnectedPort == 2345)
    }

    @Test("Connect with custom port")
    func connectCustomPort() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.connectToDevice(Self.sampleDevice, port: 8080)

        #expect(mock.lastConnectedPort == 8080)
    }

    @Test("Connect failure sets error state")
    func connectFailure() {
        let mock = MockUSBConnection()
        mock.connectError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection refused"])
        let vm = ConnectionViewModel(connection: mock)

        vm.connectToDevice(Self.sampleDevice)

        #expect(vm.state == .error("Connection refused"))
        #expect(vm.stateHistory == [.error("Connection refused")])
    }

    @Test("Disconnect resets state")
    func disconnect() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.connectToDevice(Self.sampleDevice)
        vm.disconnect()

        #expect(vm.state == .disconnected)
        #expect(mock.disconnectCalled)
    }

    // MARK: - State History

    @Test("State history tracks all transitions")
    func stateHistory() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateDeviceDetected(Self.sampleDevice)
        vm.connectToDevice(Self.sampleDevice)
        vm.disconnect()

        #expect(vm.stateHistory.count == 3)
        #expect(vm.stateHistory[0] == .connecting)
        #expect(vm.stateHistory[1] == .connected(Self.sampleDevice))
        #expect(vm.stateHistory[2] == .disconnected)
    }

    // MARK: - Error Handling

    @Test("External error propagates to state")
    func externalError() {
        let mock = MockUSBConnection()
        let vm = ConnectionViewModel(connection: mock)

        vm.startMonitoring()
        mock.simulateError("usbmuxd socket not found")

        #expect(vm.state == .error("usbmuxd socket not found"))
        #expect(vm.stateHistory == [.connecting, .error("usbmuxd socket not found")])
    }
}
