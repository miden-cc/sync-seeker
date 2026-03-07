import Foundation
import Testing
@testable import SyncSeeker

@Suite("QuickLookPreviewGenerator")
struct QuickLookPreviewGeneratorTests {

    let generator = QuickLookPreviewGenerator()

    // MARK: - HTML generation

    @Test("Generate preview with summary produces HTML containing summary text")
    func previewWithSummary() throws {
        let preview = generator.generatePreview(
            fileName: "contract.pdf",
            summary: "An NDA between Company A and Company B.",
            tags: [],
            highlights: [],
            ocrExcerpt: nil
        )
        #expect(preview.contains("An NDA between Company A and Company B."))
        #expect(preview.contains("contract.pdf"))
    }

    @Test("Generate preview with tags lists all tags")
    func previewWithTags() throws {
        let preview = generator.generatePreview(
            fileName: "invoice.pdf",
            summary: nil,
            tags: ["finance", "2025", "important"],
            highlights: [],
            ocrExcerpt: nil
        )
        #expect(preview.contains("finance"))
        #expect(preview.contains("2025"))
        #expect(preview.contains("important"))
    }

    @Test("Generate preview with highlights includes highlight content")
    func previewWithHighlights() throws {
        let preview = generator.generatePreview(
            fileName: "report.pdf",
            summary: nil,
            tags: [],
            highlights: ["Revenue increased 30%", "Q4 target exceeded"],
            ocrExcerpt: nil
        )
        #expect(preview.contains("Revenue increased 30%"))
        #expect(preview.contains("Q4 target exceeded"))
    }

    @Test("Generate preview with OCR excerpt shows extracted text")
    func previewWithOCR() throws {
        let preview = generator.generatePreview(
            fileName: "scan.pdf",
            summary: nil,
            tags: [],
            highlights: [],
            ocrExcerpt: "Scanned text from an old document."
        )
        #expect(preview.contains("Scanned text from an old document."))
    }

    @Test("Generate preview with all fields produces complete HTML")
    func previewComplete() throws {
        let preview = generator.generatePreview(
            fileName: "full.pdf",
            summary: "Complete summary.",
            tags: ["legal", "NDA"],
            highlights: ["Key clause here"],
            ocrExcerpt: "OCR extracted passage."
        )
        #expect(preview.contains("<!DOCTYPE html>") || preview.contains("<html"))
        #expect(preview.contains("Complete summary."))
        #expect(preview.contains("legal"))
        #expect(preview.contains("Key clause here"))
        #expect(preview.contains("OCR extracted passage."))
    }

    @Test("Generate preview with no metadata shows file name only")
    func previewMinimal() throws {
        let preview = generator.generatePreview(
            fileName: "empty.pdf",
            summary: nil,
            tags: [],
            highlights: [],
            ocrExcerpt: nil
        )
        #expect(preview.contains("empty.pdf"))
        // Should still be valid HTML
        #expect(preview.contains("<html") || preview.contains("<!DOCTYPE"))
    }

    @Test("HTML escapes special characters in summary")
    func htmlEscaping() throws {
        let preview = generator.generatePreview(
            fileName: "test.pdf",
            summary: "Value < 100 & status = \"pending\"",
            tags: [],
            highlights: [],
            ocrExcerpt: nil
        )
        // Should not contain raw < or & in HTML context
        #expect(preview.contains("&lt;") || !preview.contains("< 100"))
        #expect(preview.contains("&amp;") || !preview.contains("& status"))
    }

    // MARK: - Data roundtrip with annotation services

    @Test("Generate preview from Document with annotation data")
    func previewFromDocument() throws {
        let doc = Document(
            id: UUID(),
            name: "contract.pdf",
            path: URL(fileURLWithPath: "/tmp/contract.pdf"),
            size: 2048,
            modifiedDate: Date(),
            fileType: .pdf,
            tags: ["legal", "NDA"],
            summary: "Non-disclosure agreement summary."
        )

        let preview = generator.generatePreview(from: doc, highlights: ["Section 3.1"], ocrExcerpt: nil)
        #expect(preview.contains("contract.pdf"))
        #expect(preview.contains("Non-disclosure agreement summary."))
        #expect(preview.contains("legal"))
        #expect(preview.contains("Section 3.1"))
    }
}
