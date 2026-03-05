import Foundation
import Testing
@testable import SyncSeeker

@Suite("ConnectionState")
struct ConnectionStateTests {

    static let device = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad", connectionType: .usb)

    @Test("Disconnected states are equal")
    func disconnectedEquality() {
        #expect(ConnectionState.disconnected == ConnectionState.disconnected)
    }

    @Test("Connecting states are equal")
    func connectingEquality() {
        #expect(ConnectionState.connecting == ConnectionState.connecting)
    }

    @Test("Connected states with same device are equal")
    func connectedEquality() {
        #expect(ConnectionState.connected(Self.device) == ConnectionState.connected(Self.device))
    }

    @Test("Error states with same message are equal")
    func errorEquality() {
        #expect(ConnectionState.error("fail") == ConnectionState.error("fail"))
    }

    @Test("Different states are not equal")
    func differentStates() {
        #expect(ConnectionState.disconnected != ConnectionState.connecting)
        #expect(ConnectionState.connecting != ConnectionState.connected(Self.device))
        #expect(ConnectionState.error("a") != ConnectionState.error("b"))
    }
}
