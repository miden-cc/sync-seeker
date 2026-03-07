import Foundation
import Testing
@testable import SyncSeeker

@Suite("VectorStore")
struct VectorStoreTests {

    func makeInMemoryStore() throws -> VectorStore {
        try VectorStore(path: ":memory:")
    }

    // MARK: - Store & Retrieve

    @Test("Store and retrieve vector by document ID")
    func storeAndRetrieve() throws {
        let store = try makeInMemoryStore()
        let id = UUID()
        let vec: [Double] = [0.1, 0.2, 0.3, 0.4]

        try store.upsert(documentID: id, vector: vec)
        let retrieved = try store.vector(for: id)

        #expect(retrieved != nil)
        #expect(retrieved?.count == 4)
        #expect(abs((retrieved?[0] ?? 0) - 0.1) < 1e-6)
    }

    @Test("Upsert overwrites existing vector")
    func upsertOverwrites() throws {
        let store = try makeInMemoryStore()
        let id = UUID()

        try store.upsert(documentID: id, vector: [1.0, 0.0])
        try store.upsert(documentID: id, vector: [0.0, 1.0])

        let vec = try store.vector(for: id)
        #expect(abs((vec?[0] ?? 1) - 0.0) < 1e-6)
        #expect(abs((vec?[1] ?? 0) - 1.0) < 1e-6)
    }

    @Test("Vector for unknown ID returns nil")
    func unknownID() throws {
        let store = try makeInMemoryStore()
        let result = try store.vector(for: UUID())
        #expect(result == nil)
    }

    // MARK: - Delete

    @Test("Delete removes vector")
    func deleteVector() throws {
        let store = try makeInMemoryStore()
        let id = UUID()

        try store.upsert(documentID: id, vector: [1.0, 2.0])
        try store.delete(documentID: id)

        #expect(try store.vector(for: id) == nil)
    }

    @Test("Delete non-existent ID does not throw")
    func deleteNonExistent() throws {
        let store = try makeInMemoryStore()
        try store.delete(documentID: UUID())
    }

    // MARK: - Count

    @Test("Count reflects number of stored vectors")
    func count() throws {
        let store = try makeInMemoryStore()
        #expect(try store.count() == 0)

        try store.upsert(documentID: UUID(), vector: [1.0])
        try store.upsert(documentID: UUID(), vector: [2.0])
        #expect(try store.count() == 2)
    }

    // MARK: - similarDocuments

    @Test("Similar documents returns closest by cosine distance")
    func similarDocuments() throws {
        let store = try makeInMemoryStore()

        // Identical direction vectors → very close
        let idA = UUID()
        try store.upsert(documentID: idA, vector: [1.0, 0.0, 0.0])

        // Perpendicular → distant
        let idB = UUID()
        try store.upsert(documentID: idB, vector: [0.0, 1.0, 0.0])

        // Very similar to query
        let idC = UUID()
        try store.upsert(documentID: idC, vector: [0.99, 0.14, 0.0])

        let results = try store.similarDocuments(to: [1.0, 0.0, 0.0], limit: 3)

        #expect(results.count == 3)
        #expect(results[0].documentID == idA)  // exact match first
    }

    @Test("Similar documents respects limit")
    func similarDocumentsLimit() throws {
        let store = try makeInMemoryStore()
        for _ in 0..<10 {
            try store.upsert(documentID: UUID(), vector: [Double.random(in: 0...1)])
        }
        let results = try store.similarDocuments(to: [0.5], limit: 3)
        #expect(results.count <= 3)
    }

    @Test("Similarity result score is between 0 and 1 for cosine")
    func similarityScoreRange() throws {
        let store = try makeInMemoryStore()
        let id = UUID()
        try store.upsert(documentID: id, vector: [0.6, 0.8])  // unit vector

        let results = try store.similarDocuments(to: [0.6, 0.8], limit: 1)
        #expect(results.first?.score ?? -1 >= 0.0)
        #expect(results.first?.score ?? 2 <= 1.0 + 1e-6)
    }

    @Test("Empty store returns empty results")
    func emptyStoreSearch() throws {
        let store = try makeInMemoryStore()
        let results = try store.similarDocuments(to: [1.0, 0.0], limit: 5)
        #expect(results.isEmpty)
    }

    // MARK: - Persistence

    @Test("Vectors persist across store instances")
    func persistence() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vectest-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let id = UUID()
        do {
            let store = try VectorStore(path: url.path)
            try store.upsert(documentID: id, vector: [0.5, 0.5])
        }
        do {
            let store = try VectorStore(path: url.path)
            let vec = try store.vector(for: id)
            #expect(vec != nil)
        }
    }
}
