import Foundation
import Testing
@testable import SyncSeeker

@Suite("WidgetDataProvider")
struct WidgetDataProviderTests {

    // MARK: - RecentDocuments

    @Test("Recent documents from empty list returns empty")
    func recentEmpty() {
        let provider = WidgetDataProvider()
        let entries = provider.recentDocuments(from: [], limit: 5)
        #expect(entries.isEmpty)
    }

    @Test("Recent documents sorts by modifiedDate descending")
    func recentSorted() {
        let old = makeDoc(name: "old.pdf", modified: Date(timeIntervalSince1970: 1000))
        let mid = makeDoc(name: "mid.pdf", modified: Date(timeIntervalSince1970: 2000))
        let new = makeDoc(name: "new.pdf", modified: Date(timeIntervalSince1970: 3000))

        let provider = WidgetDataProvider()
        let entries = provider.recentDocuments(from: [old, mid, new], limit: 10)

        #expect(entries[0].name == "new.pdf")
        #expect(entries[1].name == "mid.pdf")
        #expect(entries[2].name == "old.pdf")
    }

    @Test("Recent documents respects limit")
    func recentLimited() {
        let docs = (0..<10).map {
            makeDoc(name: "doc\($0).pdf", modified: Date(timeIntervalSince1970: Double($0)))
        }
        let provider = WidgetDataProvider()
        let entries = provider.recentDocuments(from: docs, limit: 3)

        #expect(entries.count == 3)
    }

    // MARK: - WidgetEntry

    @Test("Widget entry contains document name, date, and file type")
    func widgetEntryFields() {
        let doc = makeDoc(name: "invoice.pdf", modified: Date(), fileType: .pdf, summary: "Invoice summary")
        let provider = WidgetDataProvider()
        let entries = provider.recentDocuments(from: [doc], limit: 1)

        let entry = entries.first!
        #expect(entry.name == "invoice.pdf")
        #expect(entry.fileType == .pdf)
        #expect(entry.summary == "Invoice summary")
    }

    @Test("Widget entry for document without summary has nil summary")
    func widgetEntryNoSummary() {
        let doc = makeDoc(name: "raw.txt", modified: Date(), fileType: .plainText)
        let provider = WidgetDataProvider()
        let entries = provider.recentDocuments(from: [doc], limit: 1)

        #expect(entries.first?.summary == nil)
    }

    // MARK: - SyncStatusEntry

    @Test("Sync status entry from disconnected state")
    func syncStatusDisconnected() {
        let provider = WidgetDataProvider()
        let entry = provider.syncStatusEntry(state: .disconnected, lastSyncDate: nil)

        #expect(entry.isConnected == false)
        #expect(entry.deviceName == nil)
        #expect(entry.lastSyncFormatted == nil)
    }

    @Test("Sync status entry from connected state includes device name")
    func syncStatusConnected() {
        let device = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad Pro", connectionType: .usb)
        let provider = WidgetDataProvider()
        let entry = provider.syncStatusEntry(state: .connected(device), lastSyncDate: Date())

        #expect(entry.isConnected == true)
        #expect(entry.deviceName == "iPad Pro")
        #expect(entry.lastSyncFormatted != nil)
    }

    @Test("Sync status formats last sync as relative time")
    func syncStatusRelativeTime() {
        let fiveMinAgo = Date().addingTimeInterval(-300)
        let provider = WidgetDataProvider()
        let entry = provider.syncStatusEntry(state: .disconnected, lastSyncDate: fiveMinAgo)

        #expect(entry.lastSyncFormatted != nil)
        // RelativeDateTimeFormatter outputs localized strings; just check it's non-empty
        #expect(!entry.lastSyncFormatted!.isEmpty)
    }

    // MARK: - Helper

    private func makeDoc(
        name: String,
        modified: Date,
        fileType: FileType = .pdf,
        summary: String? = nil
    ) -> Document {
        Document(
            id: UUID(), name: name,
            path: URL(fileURLWithPath: "/tmp/\(name)"),
            size: 1024, modifiedDate: modified,
            fileType: fileType, tags: [], summary: summary
        )
    }
}
