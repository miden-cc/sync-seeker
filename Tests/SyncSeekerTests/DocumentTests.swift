import Foundation
import Testing
@testable import SyncSeeker

@Suite("Document Model")
struct DocumentTests {

    @Test("Document creation with all fields")
    func creation() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let doc = Document(
            id: UUID(),
            name: "test.pdf",
            path: url,
            size: 1024,
            modifiedDate: Date(),
            fileType: .pdf,
            tags: ["contract", "important"],
            summary: nil
        )

        #expect(doc.name == "test.pdf")
        #expect(doc.size == 1024)
        #expect(doc.fileType == .pdf)
        #expect(doc.tags == ["contract", "important"])
        #expect(doc.summary == nil)
    }

    @Test("Document equality by all fields")
    func equality() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let date = Date()

        let doc1 = Document(id: id, name: "test.pdf", path: url, size: 1024, modifiedDate: date, fileType: .pdf, tags: [], summary: nil)
        let doc2 = Document(id: id, name: "test.pdf", path: url, size: 1024, modifiedDate: date, fileType: .pdf, tags: [], summary: nil)

        #expect(doc1 == doc2)
    }

    @Test("Mutable tags and summary")
    func mutableFields() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        var doc = Document(id: UUID(), name: "test.md", path: url, size: 512, modifiedDate: Date(), fileType: .markdown, tags: [])

        doc.tags.append("AI-tagged")
        doc.summary = "This is a summary"

        #expect(doc.tags == ["AI-tagged"])
        #expect(doc.summary == "This is a summary")
    }
}
