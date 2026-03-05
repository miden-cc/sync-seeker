import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(USBDeviceInfo)
    case error(String)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting): return true
        case (.connected(let a), .connected(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
