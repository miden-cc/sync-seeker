import Foundation

protocol USBConnectionDelegate: AnyObject {
    func connectionDidChangeState(_ newState: ConnectionState)
    func connectionDidDetectDevice(_ device: USBDeviceInfo)
    func connectionDidLoseDevice(_ device: USBDeviceInfo)
}

protocol USBConnectionProtocol {
    var currentState: ConnectionState { get }
    var delegate: USBConnectionDelegate? { get set }

    func startMonitoring()
    func stopMonitoring()
    func connectToDevice(_ device: USBDeviceInfo, port: UInt16) throws
    func disconnect()
}
