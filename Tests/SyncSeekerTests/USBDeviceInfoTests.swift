import Foundation
import Testing
@testable import SyncSeeker

@Suite("USBDeviceInfo")
struct USBDeviceInfoTests {

    @Test("Device creation")
    func creation() {
        let device = USBDeviceInfo(id: 1, serialNumber: "ABC123", productName: "iPad Pro", connectionType: .usb)

        #expect(device.id == 1)
        #expect(device.serialNumber == "ABC123")
        #expect(device.productName == "iPad Pro")
        #expect(device.connectionType == .usb)
    }

    @Test("Device equality by all fields")
    func equality() {
        let a = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad", connectionType: .usb)
        let b = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad", connectionType: .usb)

        #expect(a == b)
    }

    @Test("Devices with different IDs are not equal")
    func inequality() {
        let a = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad", connectionType: .usb)
        let b = USBDeviceInfo(id: 2, serialNumber: "ABC", productName: "iPad", connectionType: .usb)

        #expect(a != b)
    }

    @Test("Network connection type")
    func networkType() {
        let device = USBDeviceInfo(id: 1, serialNumber: "X", productName: "iPad", connectionType: .network)
        #expect(device.connectionType == .network)
    }
}
