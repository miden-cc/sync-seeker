import Foundation
import Testing
@testable import SyncSeeker

@Suite("DocumentEmbeddingService")
struct DocumentEmbeddingServiceTests {

    // MARK: - テストデータ（ローカル定数）

    private let contractText = """
    This non-disclosure agreement is entered into between Company A and Company B.
    The Receiving Party agrees not to disclose confidential information to third parties.
    All proprietary data shall remain strictly confidential.
    """

    private let weatherText = """
    Today's weather forecast shows sunny skies with temperatures around 22 degrees.
    Light winds expected from the northwest in the afternoon.
    """

    // MARK: - Embed

    @Test("Embed document returns 512-dim vector")
    func embedReturns512Dims() async throws {
        let service = DocumentEmbeddingService()
        let vec = try await service.embed(text: contractText)
        #expect(vec.count == 512)
    }

    @Test("Embed empty text throws emptyInput")
    func embedEmpty() async {
        let service = DocumentEmbeddingService()
        await #expect(throws: EmbeddingError.emptyText) {
            _ = try await service.embed(text: "")
        }
    }

    @Test("Similar texts produce lower cosine distance than dissimilar texts")
    func similarTextsCloser() async throws {
        let service = DocumentEmbeddingService()

        let contractVec = try await service.embed(text: contractText)
        let contractVec2 = try await service.embed(text: """
            The parties agree to keep all business information confidential.
            Neither party shall disclose proprietary information to any third party.
            """)
        let weatherVec = try await service.embed(text: weatherText)

        let sameDist  = VectorMath.cosineDistance(contractVec, contractVec2)
        let crossDist = VectorMath.cosineDistance(contractVec, weatherVec)

        #expect(sameDist < crossDist)
    }

    // MARK: - Index + Search

    @Test("Index and search returns matching document")
    func indexAndSearch() async throws {
        let store = try VectorStore(path: ":memory:")
        let service = DocumentEmbeddingService()

        let id = UUID()
        let vec = try await service.embed(text: contractText)
        try store.upsert(documentID: id, vector: vec)

        let queryVec = try await service.embed(text: "NDA confidential agreement")
        let results = try store.similarDocuments(to: queryVec, limit: 5)

        #expect(results.isEmpty == false)
        #expect(results.first?.documentID == id)
    }

    @Test("Semantically different query does not top-rank unrelated document")
    func differentQueryLowerRank() async throws {
        let store = try VectorStore(path: ":memory:")
        let service = DocumentEmbeddingService()

        let contractID = UUID()
        let contractVec = try await service.embed(text: contractText)
        try store.upsert(documentID: contractID, vector: contractVec)

        let weatherID = UUID()
        let weatherVec2 = try await service.embed(text: weatherText)
        try store.upsert(documentID: weatherID, vector: weatherVec2)

        let queryVec = try await service.embed(text: "sunny forecast temperature degrees")
        let results = try store.similarDocuments(to: queryVec, limit: 2)

        #expect(results.first?.documentID == weatherID)
    }
}
