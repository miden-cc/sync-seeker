import Foundation
@testable import SyncSeeker

final class MockUSBConnection: USBConnectionProtocol {
    var currentState: ConnectionState = .disconnected
    weak var delegate: USBConnectionDelegate?

    var startMonitoringCalled = false
    var stopMonitoringCalled = false
    var connectCalled = false
    var disconnectCalled = false
    var lastConnectedDevice: USBDeviceInfo?
    var lastConnectedPort: UInt16?
    var connectError: Error?

    func startMonitoring() {
        startMonitoringCalled = true
    }

    func stopMonitoring() {
        stopMonitoringCalled = true
    }

    func connectToDevice(_ device: USBDeviceInfo, port: UInt16) throws {
        connectCalled = true
        lastConnectedDevice = device
        lastConnectedPort = port
        if let error = connectError {
            throw error
        }
        currentState = .connected(device)
        delegate?.connectionDidChangeState(.connected(device))
    }

    func disconnect() {
        disconnectCalled = true
        currentState = .disconnected
        delegate?.connectionDidChangeState(.disconnected)
    }

    // MARK: - Simulation helpers

    func simulateDeviceDetected(_ device: USBDeviceInfo) {
        delegate?.connectionDidDetectDevice(device)
    }

    func simulateDeviceLost(_ device: USBDeviceInfo) {
        delegate?.connectionDidLoseDevice(device)
    }

    func simulateError(_ message: String) {
        delegate?.connectionDidChangeState(.error(message))
    }
}
