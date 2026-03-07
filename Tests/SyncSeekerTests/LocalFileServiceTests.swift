import Foundation
import Testing
@testable import SyncSeeker

@Suite("LocalFileService")
struct LocalFileServiceTests {

    private let service = LocalFileService()

    // MARK: - readContent: binary types must throw, not crash

    @Test("readContent of PDF throws LocalFileServiceError")
    func readContentPDFThrows() {
        let doc = makeDoc(name: "report.pdf", fileType: .pdf)
        #expect(throws: LocalFileServiceError.self) {
            try service.readContent(of: doc)
        }
    }

    @Test("readContent of richText throws LocalFileServiceError")
    func readContentRichTextThrows() {
        let doc = makeDoc(name: "doc.rtf", fileType: .richText)
        #expect(throws: LocalFileServiceError.self) {
            try service.readContent(of: doc)
        }
    }

    // MARK: - readContent: text types return content

    @Test("readContent of plainText returns file content")
    func readContentPlainText() throws {
        let (tmp, doc) = try makeTempFile(ext: "txt", fileType: .plainText, content: "Hello, World!")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try service.readContent(of: doc)
        #expect(result == "Hello, World!")
    }

    @Test("readContent of markdown returns file content")
    func readContentMarkdown() throws {
        let (tmp, doc) = try makeTempFile(ext: "md", fileType: .markdown, content: "# Title\n\nBody text.")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try service.readContent(of: doc)
        #expect(result == "# Title\n\nBody text.")
    }

    @Test("readContent of unknown text file returns content")
    func readContentUnknownText() throws {
        let (tmp, doc) = try makeTempFile(ext: "log", fileType: .unknown, content: "log line")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try service.readContent(of: doc)
        #expect(result == "log line")
    }

    @Test("readContent of invalid UTF-8 unknown file throws LocalFileServiceError")
    func readContentInvalidUTF8Throws() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid_\(UUID().uuidString).bin")
        // 0xFF 0xFE はバイナリで UTF-8 として不正
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let doc = makeDoc(name: tmp.lastPathComponent, path: tmp, fileType: .unknown)
        #expect(throws: LocalFileServiceError.self) {
            try service.readContent(of: doc)
        }
    }

    // MARK: - detectFileType

    @Test("detectFileType returns correct type for known extensions")
    func detectFileTypes() {
        let cases: [(String, FileType)] = [
            ("doc.pdf",      .pdf),
            ("note.md",      .markdown),
            ("note.markdown",.markdown),
            ("note.txt",     .plainText),
            ("note.text",    .plainText),
            ("doc.rtf",      .richText),
            ("doc.rtfd",     .richText),
            ("file.xyz",     .unknown),
        ]
        for (name, expected) in cases {
            #expect(service.detectFileType(at: URL(fileURLWithPath: name)) == expected)
        }
    }

    @Test("detectFileType is case-insensitive")
    func detectFileTypeCaseInsensitive() {
        #expect(service.detectFileType(at: URL(fileURLWithPath: "DOC.PDF")) == .pdf)
        #expect(service.detectFileType(at: URL(fileURLWithPath: "Note.MD")) == .markdown)
    }

    // MARK: - Helpers

    private func makeDoc(
        name: String,
        path: URL? = nil,
        fileType: FileType
    ) -> Document {
        let url = path ?? URL(fileURLWithPath: "/tmp/\(name)")
        return Document(
            id: UUID(), name: name, path: url,
            size: 0, modifiedDate: Date(), fileType: fileType, tags: []
        )
    }

    private func makeTempFile(
        ext: String,
        fileType: FileType,
        content: String
    ) throws -> (URL, Document) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
        try content.data(using: .utf8)!.write(to: tmp)
        let doc = makeDoc(name: tmp.lastPathComponent, path: tmp, fileType: fileType)
        return (tmp, doc)
    }
}
