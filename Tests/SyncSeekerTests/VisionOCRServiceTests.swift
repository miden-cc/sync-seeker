import Foundation
import Testing
import PDFKit
import CoreGraphics
@testable import SyncSeeker

@Suite("VisionOCRService")
struct VisionOCRServiceTests {

    let service = VisionOCRService()

    // MARK: - Test PDF helpers

    /// テキストを含む 1 ページの PDF を一時ファイルに作成する。
    func makePDF(text: String, fontSize: CGFloat = 36) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ocr-test-\(UUID().uuidString).pdf")
        var rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &rect, nil) else {
            throw OCRError.renderFailed
        }
        ctx.beginPDFPage(nil)
        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(origin: .zero, size: rect.size))

        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attrStr = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.setFillColor(CGColor.black)
        ctx.textPosition = CGPoint(x: 50, y: 700)
        CTLineDraw(line, ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    /// 2 ページ PDF（各ページに異なるテキスト）を作成する。
    func makeTwoPagePDF(text1: String, text2: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ocr-2page-\(UUID().uuidString).pdf")
        var rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &rect, nil) else {
            throw OCRError.renderFailed
        }
        let font = CTFontCreateWithName("Helvetica" as CFString, 36, nil)

        for text in [text1, text2] {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(CGColor.white)
            ctx.fill(CGRect(origin: .zero, size: rect.size))
            ctx.setFillColor(CGColor.black)
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: text, attributes: [.font: font])
            )
            ctx.textPosition = CGPoint(x: 50, y: 700)
            CTLineDraw(line, ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    // MARK: - extractText(from:)

    @Test("Extract text from single-page PDF containing known text")
    func extractTextSinglePage() async throws {
        let url = try makePDF(text: "Invoice 2025")
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await service.extractText(from: url)

        #expect(text.contains("Invoice"))
        #expect(text.contains("2025"))
    }

    @Test("Extract text from multi-page PDF combines all pages")
    func extractTextMultiPage() async throws {
        let url = try makeTwoPagePDF(text1: "Page One Contract", text2: "Page Two Invoice")
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await service.extractText(from: url)

        #expect(text.contains("Contract") || text.contains("Page One"))
        #expect(text.contains("Invoice") || text.contains("Page Two"))
    }

    @Test("Extract text from non-existent file throws")
    func extractTextMissingFile() async {
        let url = URL(fileURLWithPath: "/tmp/ghost-\(UUID().uuidString).pdf")
        await #expect(throws: OCRError.self) {
            _ = try await service.extractText(from: url)
        }
    }

    @Test("Extract text from non-PDF file throws")
    func extractTextNonPDF() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-pdf-\(UUID().uuidString).pdf")
        try "not a pdf".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: OCRError.self) {
            _ = try await service.extractText(from: url)
        }
    }

    // MARK: - extractText(from page:)

    @Test("Extract text from specific PDF page")
    func extractTextFromPage() async throws {
        let url = try makeTwoPagePDF(text1: "FirstPage Alpha", text2: "SecondPage Beta")
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try #require(PDFDocument(url: url))
        let page = try #require(doc.page(at: 0))

        let text = try await service.extractText(from: page)
        #expect(text.contains("Alpha") || text.contains("First"))
    }

    @Test("Extract text from blank page returns empty or short string")
    func extractTextBlankPage() async throws {
        // Create a PDF with no drawn text
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blank-\(UUID().uuidString).pdf")
        var rect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let ctx = CGContext(url as CFURL, mediaBox: &rect, nil)!
        ctx.beginPDFPage(nil)
        ctx.setFillColor(CGColor.white)
        ctx.fill(CGRect(origin: .zero, size: rect.size))
        ctx.endPDFPage()
        ctx.closePDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let doc = try #require(PDFDocument(url: url))
        let page = try #require(doc.page(at: 0))

        let text = try await service.extractText(from: page)
        #expect(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
    }

    // MARK: - renderScale

    @Test("Custom render scale is applied")
    func customRenderScale() async throws {
        let highDPI = VisionOCRService(renderScale: 3.0)
        let url = try makePDF(text: "Scale Test")
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await highDPI.extractText(from: url)
        #expect(text.contains("Scale") || text.contains("Test"))
    }
}
