import Foundation
import Testing
import PDFKit
@testable import SyncSeeker

@Suite("PDFHighlightService")
struct PDFHighlightServiceTests {

    let service = PDFKitHighlightService()

    // MARK: - Setup

    /// 1ページの空白 PDF を一時ディレクトリに作成して URL を返す。
    func makeBlankPDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-test-\(UUID().uuidString).pdf")
        var rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &rect, nil) else {
            throw PDFHighlightError.pdfCreationFailed("CGContext init failed")
        }
        ctx.beginPDFPage(nil)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    // MARK: - Add highlight

    @Test("Add highlight to PDF saves annotation")
    func addHighlightSaves() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let h = PDFHighlight(
            page: 0,
            bounds: CGRect(x: 50, y: 700, width: 200, height: 20),
            color: .yellow,
            content: "Important clause"
        )

        try service.addHighlight(h, to: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.count == 1)
    }

    @Test("Add highlight preserves content string")
    func highlightContent() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let h = PDFHighlight(
            page: 0,
            bounds: CGRect(x: 50, y: 700, width: 200, height: 20),
            color: .yellow,
            content: "Key finding: revenue increased 30%"
        )
        try service.addHighlight(h, to: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.first?.content == "Key finding: revenue increased 30%")
    }

    @Test("Add multiple highlights accumulates correctly")
    func addMultipleHighlights() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        try service.addHighlight(PDFHighlight(page: 0, bounds: CGRect(x: 50, y: 700, width: 100, height: 20), color: .yellow, content: "first"), to: url)
        try service.addHighlight(PDFHighlight(page: 0, bounds: CGRect(x: 50, y: 670, width: 100, height: 20), color: .green, content: "second"), to: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.count == 2)
    }

    @Test("Add highlight with green color round-trips")
    func highlightColorGreen() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let h = PDFHighlight(page: 0, bounds: CGRect(x: 50, y: 700, width: 100, height: 20), color: .green, content: "green")
        try service.addHighlight(h, to: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.first?.color == .green)
    }

    @Test("Add highlight with pink color round-trips")
    func highlightColorPink() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let h = PDFHighlight(page: 0, bounds: CGRect(x: 50, y: 700, width: 100, height: 20), color: .pink, content: "pink")
        try service.addHighlight(h, to: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.first?.color == .pink)
    }

    // MARK: - Read

    @Test("Read highlights from unmodified PDF returns empty")
    func readFromCleanPDF() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.isEmpty)
    }

    @Test("Read highlights from non-PDF throws error")
    func readFromNonPDF() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fake-\(UUID().uuidString).pdf")
        try? "not a pdf".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: PDFHighlightError.self) {
            try service.readHighlights(from: url)
        }
    }

    // MARK: - Remove

    @Test("Remove all highlights clears annotations")
    func removeAllHighlights() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        try service.addHighlight(PDFHighlight(page: 0, bounds: CGRect(x: 50, y: 700, width: 100, height: 20), color: .yellow, content: "to be removed"), to: url)
        try service.removeAllHighlights(from: url)

        let highlights = try service.readHighlights(from: url)
        #expect(highlights.isEmpty)
    }

    @Test("Remove highlights from PDF with no annotations is safe")
    func removeFromCleanPDF() throws {
        let url = try makeBlankPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        // Should not throw
        try service.removeAllHighlights(from: url)
        let highlights = try service.readHighlights(from: url)
        #expect(highlights.isEmpty)
    }
}
