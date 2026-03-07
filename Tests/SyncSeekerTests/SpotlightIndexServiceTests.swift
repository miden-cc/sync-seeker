import Foundation
import Testing
import CoreSpotlight
@testable import SyncSeeker

@Suite("SpotlightIndexService")
struct SpotlightIndexServiceTests {

    static let sampleDoc = Document(
        id: UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!,
        name: "contract.pdf",
        path: URL(fileURLWithPath: "/tmp/docs/contract.pdf"),
        size: 204800,
        modifiedDate: Date(timeIntervalSince1970: 1700000000),
        fileType: .pdf,
        tags: ["legal", "NDA"]
    )

    // MARK: - Index document

    @Test("Index document donates item with correct identifier")
    func indexDocumentIdentifier() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])

        #expect(mock.indexedItems.count == 1)
        #expect(mock.indexedItems.first?.uniqueIdentifier == Self.sampleDoc.id.uuidString)
    }

    @Test("Index document sets title to filename")
    func indexDocumentTitle() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])

        #expect(mock.indexedItems.first?.attributeSet.title == "contract.pdf")
    }

    @Test("Index document includes summary in contentDescription")
    func indexDocumentSummary() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: "A non-disclosure agreement between two parties.", tags: [])

        let desc = mock.indexedItems.first?.attributeSet.contentDescription
        #expect(desc?.contains("non-disclosure") == true)
    }

    @Test("Index document includes tags as keywords")
    func indexDocumentTags() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: ["legal", "NDA", "important"])

        let keywords = mock.indexedItems.first?.attributeSet.keywords
        #expect(keywords?.contains("legal") == true)
        #expect(keywords?.contains("NDA") == true)
        #expect(keywords?.contains("important") == true)
    }

    @Test("Index document sets contentType for PDF")
    func indexDocumentContentTypePDF() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])

        #expect(mock.indexedItems.first?.attributeSet.contentType == "com.adobe.pdf")
    }

    @Test("Index markdown document sets contentType for plain text")
    func indexDocumentContentTypeMarkdown() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        let doc = Document(
            id: UUID(),
            name: "notes.md",
            path: URL(fileURLWithPath: "/tmp/notes.md"),
            size: 1024,
            modifiedDate: Date(),
            fileType: .markdown,
            tags: []
        )

        try await service.indexDocument(doc, summary: nil, tags: [])

        #expect(mock.indexedItems.first?.attributeSet.contentType == "net.daringfireball.markdown")
    }

    @Test("Index sets domainIdentifier for app grouping")
    func indexDomainIdentifier() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])

        #expect(mock.indexedItems.first?.domainIdentifier == "com.miden.SyncSeeker")
    }

    @Test("Index propagates error from underlying index")
    func indexError() async throws {
        let mock = MockSpotlightIndex()
        mock.indexError = NSError(domain: "CS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Spotlight unavailable"])
        let service = CoreSpotlightIndexService(index: mock)

        await #expect(throws: Error.self) {
            try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])
        }
    }

    // MARK: - Deindex document

    @Test("Deindex document removes by identifier")
    func deindexDocument() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.indexDocument(Self.sampleDoc, summary: nil, tags: [])
        try await service.deindexDocument(Self.sampleDoc)

        #expect(mock.deletedIdentifiers.contains(Self.sampleDoc.id.uuidString))
        #expect(mock.indexedItems.isEmpty)
    }

    // MARK: - Deindex all

    @Test("Deindex all calls deleteAll on underlying index")
    func deindexAll() async throws {
        let mock = MockSpotlightIndex()
        let service = CoreSpotlightIndexService(index: mock)

        try await service.deindexAll()

        #expect(mock.deleteAllCalled)
    }
}
