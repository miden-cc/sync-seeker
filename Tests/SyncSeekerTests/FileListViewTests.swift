import Testing
import Foundation
import SwiftUI
@testable import SyncSeeker

#if os(macOS)
class MockPasteboard: PasteboardType {
    var clearContentsCalled = 0
    var setStringCalled = 0
    var lastString: String?
    var lastType: NSPasteboard.PasteboardType?

    func clearContents() -> Int {
        clearContentsCalled += 1
        return 0
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        setStringCalled += 1
        lastString = string
        lastType = dataType
        return true
    }
}

@Suite("FileListView Tests")
@MainActor
struct FileListViewTests {
    @Test("Copy Path uses PasteboardType")
    func testCopyPath() async throws {
        let mockPasteboard = MockPasteboard()

        let doc = Document(
            id: UUID(),
            name: "test.md",
            path: URL(fileURLWithPath: "/path/to/test.md"),
            size: 100,
            modifiedDate: Date(),
            fileType: .markdown,
            tags: [],
            summary: nil
        )

        let view = FileListView(documents: [doc], selection: .constant(doc))

        // Let's call the internal method
        view.copyPath(for: doc, pasteboard: mockPasteboard)

        #expect(mockPasteboard.clearContentsCalled == 1)
        #expect(mockPasteboard.setStringCalled == 1)
        #expect(mockPasteboard.lastString == "/path/to/test.md")
        #expect(mockPasteboard.lastType == .string)
    }
}
#endif
