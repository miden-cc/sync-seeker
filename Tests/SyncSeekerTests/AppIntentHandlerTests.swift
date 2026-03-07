import Foundation
import Testing
@testable import SyncSeeker

/// App Intents のビジネスロジック層をテストする。
/// 実際の AppIntent プロトコルは Xcode ターゲットで宣言し、
/// このハンドラーに委譲する設計。
@Suite("AppIntentHandler")
struct AppIntentHandlerTests {

    // MARK: - Search Intent

    @Test("Search intent with keywords returns structured result")
    func searchIntentKeywords() {
        let handler = AppIntentHandler()
        let result = handler.handleSearchIntent(query: "contract NDA", fileType: nil)

        #expect(result.keywords.contains("contract"))
        #expect(result.keywords.contains("NDA"))
    }

    @Test("Search intent with file type filter applies filter")
    func searchIntentFileType() {
        let handler = AppIntentHandler()
        let result = handler.handleSearchIntent(query: "invoice", fileType: "pdf")

        #expect(result.fileTypes.contains(.pdf))
    }

    @Test("Search intent with unknown file type defaults to unknown")
    func searchIntentUnknownFileType() {
        let handler = AppIntentHandler()
        let result = handler.handleSearchIntent(query: "data", fileType: "xlsx")

        #expect(result.fileTypes.contains(.unknown))
    }

    @Test("Search intent with empty query returns empty keywords")
    func searchIntentEmpty() {
        let handler = AppIntentHandler()
        let result = handler.handleSearchIntent(query: "", fileType: nil)

        #expect(result.keywords.isEmpty)
    }

    // MARK: - Summarize Intent

    @Test("Summarize intent result has correct document name and summary placeholder")
    func summarizeIntentResult() {
        let handler = AppIntentHandler()
        let result = handler.prepareSummarizeIntent(
            documentName: "report.pdf",
            documentPath: "/Users/test/SyncSeeker/report.pdf"
        )

        #expect(result.documentName == "report.pdf")
        #expect(result.documentPath == "/Users/test/SyncSeeker/report.pdf")
    }

    // MARK: - Sync Status Intent

    @Test("Sync status from disconnected state")
    func syncStatusDisconnected() {
        let handler = AppIntentHandler()
        let status = handler.syncStatus(from: .disconnected)

        #expect(status.isConnected == false)
        #expect(status.deviceName == nil)
        #expect(status.displayText.contains("No device"))
    }

    @Test("Sync status from connected state includes device name")
    func syncStatusConnected() {
        let device = USBDeviceInfo(id: 1, serialNumber: "ABC", productName: "iPad Pro", connectionType: .usb)
        let handler = AppIntentHandler()
        let status = handler.syncStatus(from: .connected(device))

        #expect(status.isConnected == true)
        #expect(status.deviceName == "iPad Pro")
        #expect(status.displayText.contains("iPad Pro"))
    }

    @Test("Sync status from error state shows error message")
    func syncStatusError() {
        let handler = AppIntentHandler()
        let status = handler.syncStatus(from: .error("Cable disconnected"))

        #expect(status.isConnected == false)
        #expect(status.displayText.contains("Cable disconnected"))
    }

    @Test("Sync status from connecting state")
    func syncStatusConnecting() {
        let handler = AppIntentHandler()
        let status = handler.syncStatus(from: .connecting)

        #expect(status.isConnected == false)
        #expect(status.displayText.contains("Connecting") || status.displayText.contains("connecting"))
    }

    // MARK: - Format helpers

    @Test("Format file count for Siri response")
    func formatFileCount() {
        let handler = AppIntentHandler()

        #expect(handler.formatTransferResult(fileCount: 0, totalBytes: 0) == "No files to transfer.")
        #expect(handler.formatTransferResult(fileCount: 1, totalBytes: 1024).contains("1 file"))
        #expect(handler.formatTransferResult(fileCount: 5, totalBytes: 5_000_000).contains("5 files"))
    }

    @Test("Format bytes to human readable")
    func formatBytes() {
        let handler = AppIntentHandler()

        #expect(handler.formatBytes(500) == "500 B")
        #expect(handler.formatBytes(1536) == "1.5 KB")
        #expect(handler.formatBytes(2_500_000) == "2.5 MB")
        #expect(handler.formatBytes(1_500_000_000) == "1.5 GB")
    }
}
