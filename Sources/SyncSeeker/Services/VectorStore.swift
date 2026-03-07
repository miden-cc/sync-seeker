import Foundation
import SQLite3

// MARK: - Result type

struct SimilarityResult {
    let documentID: UUID
    let score: Double      // cosine similarity: 0 (distant) → 1 (identical)
}

// MARK: - VectorStore

/// ドキュメント埋め込みベクターを SQLite BLOB に保存し、コサイン類似度で検索するストア。
final class VectorStore {

    private var db: OpaquePointer?

    // MARK: - Init

    /// - Parameter path: SQLite ファイルパス。`":memory:"` でインメモリ。
    init(path: String) throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            throw VectorStoreError.openFailed(sqlite3_errmsg(db).map(String.init(cString:)) ?? "unknown")
        }
        try createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - CRUD

    /// ドキュメントのベクターを保存（既存は上書き）。
    func upsert(documentID: UUID, vector: [Double]) throws {
        let blob = vectorToBlob(vector)
        let sql = "INSERT OR REPLACE INTO vectors (document_id, vector_blob) VALUES (?, ?);"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.prepareFailed(lastError())
        }
        sqlite3_bind_text(stmt, 1, documentID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        _ = blob.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, 2, ptr.baseAddress, Int32(blob.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorStoreError.stepFailed(lastError())
        }
    }

    /// 指定 ID のベクターを返す。存在しない場合は `nil`。
    func vector(for documentID: UUID) throws -> [Double]? {
        let sql = "SELECT vector_blob FROM vectors WHERE document_id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.prepareFailed(lastError())
        }
        sqlite3_bind_text(stmt, 1, documentID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return blobToVector(stmt: stmt!, column: 0)
    }

    /// 指定 ID のベクターを削除する。
    func delete(documentID: UUID) throws {
        let sql = "DELETE FROM vectors WHERE document_id = ?;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.prepareFailed(lastError())
        }
        sqlite3_bind_text(stmt, 1, documentID.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw VectorStoreError.stepFailed(lastError())
        }
    }

    /// 保存されているベクターの件数。
    func count() throws -> Int {
        let sql = "SELECT COUNT(*) FROM vectors;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW
        else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // MARK: - Similarity search

    /// クエリベクターに近い上位 `limit` 件を返す（コサイン類似度の高い順）。
    func similarDocuments(to query: [Double], limit: Int) throws -> [SimilarityResult] {
        let sql = "SELECT document_id, vector_blob FROM vectors;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw VectorStoreError.prepareFailed(lastError())
        }

        var results: [SimilarityResult] = []
        while sqlite3_step(stmt!) == SQLITE_ROW {
            guard
                let idCStr = sqlite3_column_text(stmt, 0),
                let id = UUID(uuidString: String(cString: idCStr)),
                let vec = blobToVector(stmt: stmt!, column: 1)
            else { continue }

            let score = VectorMath.cosineSimilarity(query, vec)
            results.append(SimilarityResult(documentID: id, score: score))
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private

    private func createTable() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS vectors (
            document_id TEXT PRIMARY KEY NOT NULL,
            vector_blob BLOB NOT NULL
        );
        """
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw VectorStoreError.stepFailed(lastError())
        }
    }

    private func vectorToBlob(_ vector: [Double]) -> Data {
        vector.withUnsafeBytes { Data($0) }
    }

    private func blobToVector(stmt: OpaquePointer, column: Int32) -> [Double]? {
        guard let ptr = sqlite3_column_blob(stmt, column) else { return nil }
        let byteCount = Int(sqlite3_column_bytes(stmt, column))
        guard byteCount % MemoryLayout<Double>.size == 0 else { return nil }
        let count = byteCount / MemoryLayout<Double>.size
        return Array(UnsafeBufferPointer(
            start: ptr.assumingMemoryBound(to: Double.self),
            count: count
        ))
    }

    private func lastError() -> String {
        sqlite3_errmsg(db).map(String.init(cString:)) ?? "unknown SQLite error"
    }
}

// MARK: - Error

enum VectorStoreError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
}
