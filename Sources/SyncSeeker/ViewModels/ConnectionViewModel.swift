import Foundation

final class ConnectionViewModel: USBConnectionDelegate, @unchecked Sendable {
    private var connection: USBConnectionProtocol

    private(set) var state: ConnectionState = .disconnected
    private(set) var detectedDevices: [USBDeviceInfo] = []
    private(set) var stateHistory: [ConnectionState] = []

    init(connection: USBConnectionProtocol) {
        self.connection = connection
        self.connection.delegate = self
    }

    func startMonitoring() {
        state = .connecting
        stateHistory.append(.connecting)
        connection.startMonitoring()
    }

    func stopMonitoring() {
        connection.stopMonitoring()
        state = .disconnected
        stateHistory.append(.disconnected)
        detectedDevices.removeAll()
    }

    func connectToDevice(_ device: USBDeviceInfo, port: UInt16 = 2345) {
        do {
            try connection.connectToDevice(device, port: port)
        } catch {
            state = .error(error.localizedDescription)
            stateHistory.append(state)
        }
    }

    func disconnect() {
        connection.disconnect()
    }

    // MARK: - USBConnectionDelegate

    func connectionDidChangeState(_ newState: ConnectionState) {
        state = newState
        stateHistory.append(newState)
    }

    func connectionDidDetectDevice(_ device: USBDeviceInfo) {
        if !detectedDevices.contains(device) {
            detectedDevices.append(device)
        }
    }

    func connectionDidLoseDevice(_ device: USBDeviceInfo) {
        detectedDevices.removeAll { $0 == device }
        if case .connected(let current) = state, current == device {
            state = .disconnected
            stateHistory.append(.disconnected)
        }
    }
}
