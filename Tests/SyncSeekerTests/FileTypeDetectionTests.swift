import Foundation
import Testing
@testable import SyncSeeker

@Suite("FileType Detection")
struct FileTypeDetectionTests {

    let service = LocalFileService()

    @Test("Detect PDF")
    func detectPDF() {
        let url = URL(fileURLWithPath: "/tmp/document.pdf")
        #expect(service.detectFileType(at: url) == .pdf)
    }

    @Test("Detect Markdown")
    func detectMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/notes.md")
        #expect(service.detectFileType(at: url) == .markdown)
    }

    @Test("Detect plain text")
    func detectPlainText() {
        let url = URL(fileURLWithPath: "/tmp/readme.txt")
        #expect(service.detectFileType(at: url) == .plainText)
    }

    @Test("Detect rich text")
    func detectRichText() {
        let url = URL(fileURLWithPath: "/tmp/letter.rtf")
        #expect(service.detectFileType(at: url) == .richText)
    }

    @Test("Detect unknown extension")
    func detectUnknown() {
        let url = URL(fileURLWithPath: "/tmp/image.png")
        #expect(service.detectFileType(at: url) == .unknown)
    }

    @Test("Detect uppercase extension")
    func detectUppercase() {
        let url = URL(fileURLWithPath: "/tmp/NOTES.MD")
        #expect(service.detectFileType(at: url) == .markdown)
    }

    @Test("Detect no extension")
    func detectNoExtension() {
        let url = URL(fileURLWithPath: "/tmp/Makefile")
        #expect(service.detectFileType(at: url) == .unknown)
    }
}
