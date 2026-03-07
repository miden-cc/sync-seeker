import Foundation
import Testing
@testable import SyncSeeker

@Suite("MenuBarState")
struct MenuBarStateTests {

    // MARK: - Icon

    @Test("Disconnected state shows disconnected icon")
    func iconDisconnected() {
        let state = MenuBarState(connection: .disconnected, transfer: .idle, lastSyncDate: nil)
        #expect(state.iconName == "arrow.triangle.2.circlepath")
    }

    @Test("Connecting state shows connecting icon")
    func iconConnecting() {
        let state = MenuBarState(connection: .connecting, transfer: .idle, lastSyncDate: nil)
        #expect(state.iconName == "arrow.triangle.2.circlepath.circle")
    }

    @Test("Connected state shows connected icon")
    func iconConnected() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(connection: .connected(device), transfer: .idle, lastSyncDate: nil)
        #expect(state.iconName == "checkmark.circle.fill")
    }

    @Test("Error state shows error icon")
    func iconError() {
        let state = MenuBarState(connection: .error("fail"), transfer: .idle, lastSyncDate: nil)
        #expect(state.iconName == "exclamationmark.triangle")
    }

    @Test("Transferring state shows transfer icon regardless of connection")
    func iconTransferring() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(
            connection: .connected(device),
            transfer: .transferring(progress: 0.5, currentFile: "test.pdf"),
            lastSyncDate: nil
        )
        #expect(state.iconName == "arrow.up.arrow.down.circle.fill")
    }

    // MARK: - Status text

    @Test("Status text for disconnected")
    func statusDisconnected() {
        let state = MenuBarState(connection: .disconnected, transfer: .idle, lastSyncDate: nil)
        #expect(state.statusText.contains("No device"))
    }

    @Test("Status text for connected shows device name")
    func statusConnected() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad Pro", connectionType: .usb)
        let state = MenuBarState(connection: .connected(device), transfer: .idle, lastSyncDate: nil)
        #expect(state.statusText.contains("iPad Pro"))
    }

    @Test("Status text for transferring shows progress")
    func statusTransferring() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(
            connection: .connected(device),
            transfer: .transferring(progress: 0.75, currentFile: "report.pdf"),
            lastSyncDate: nil
        )
        #expect(state.statusText.contains("75%") || state.statusText.contains("report.pdf"))
    }

    @Test("Status text for completed transfer shows count")
    func statusCompleted() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(
            connection: .connected(device),
            transfer: .completed(fileCount: 12, totalBytes: 5_000_000),
            lastSyncDate: Date()
        )
        #expect(state.statusText.contains("12"))
    }

    // MARK: - Menu items

    @Test("Menu items include Sync Now when connected and idle")
    func menuItemsSyncWhenIdle() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(connection: .connected(device), transfer: .idle, lastSyncDate: nil)
        #expect(state.availableActions.contains(.syncNow))
    }

    @Test("Menu items include Cancel when transferring")
    func menuItemsCancelWhenTransferring() {
        let device = USBDeviceInfo(id: 1, serialNumber: "A", productName: "iPad", connectionType: .usb)
        let state = MenuBarState(
            connection: .connected(device),
            transfer: .transferring(progress: 0.5, currentFile: "x.pdf"),
            lastSyncDate: nil
        )
        #expect(state.availableActions.contains(.cancelSync))
        #expect(!state.availableActions.contains(.syncNow))
    }

    @Test("Menu items when disconnected only show openApp and quit")
    func menuItemsDisconnected() {
        let state = MenuBarState(connection: .disconnected, transfer: .idle, lastSyncDate: nil)
        #expect(!state.availableActions.contains(.syncNow))
        #expect(!state.availableActions.contains(.cancelSync))
        #expect(state.availableActions.contains(.openApp))
        #expect(state.availableActions.contains(.quit))
    }

    // MARK: - Last sync

    @Test("Last sync date formats to relative string")
    func lastSyncFormatted() {
        let fiveMinAgo = Date().addingTimeInterval(-300)
        let state = MenuBarState(connection: .disconnected, transfer: .idle, lastSyncDate: fiveMinAgo)
        #expect(state.lastSyncFormatted != nil)
        #expect(!state.lastSyncFormatted!.isEmpty)
    }

    @Test("No last sync returns nil")
    func noLastSync() {
        let state = MenuBarState(connection: .disconnected, transfer: .idle, lastSyncDate: nil)
        #expect(state.lastSyncFormatted == nil)
    }
}
