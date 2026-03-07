import Foundation

public struct USBDeviceInfo: Identifiable, Equatable, Sendable {
    public let id: Int
    public let serialNumber: String
    public let productName: String
    public let connectionType: ConnectionType

    public enum ConnectionType: String, Equatable, Sendable {
        case usb
        case network
    }

    public init(id: Int, serialNumber: String, productName: String, connectionType: ConnectionType) {
        self.id = id
        self.serialNumber = serialNumber
        self.productName = productName
        self.connectionType = connectionType
    }
}
