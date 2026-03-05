import Foundation

struct USBDeviceInfo: Identifiable, Equatable {
    let id: Int
    let serialNumber: String
    let productName: String
    let connectionType: ConnectionType

    enum ConnectionType: String, Equatable {
        case usb
        case network
    }
}
