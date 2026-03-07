import Foundation
@preconcurrency import NaturalLanguage

// MARK: - Error

enum EmbeddingError: Error, Equatable {
    case emptyText
    case modelUnavailable
    case embeddingFailed(String)
}

// MARK: - DocumentEmbeddingService

/// `NLContextualEmbedding` を使ってテキストを 512 次元ベクターに変換する。
/// トークンベクターの平均を「文書ベクター」として使用する。
final class DocumentEmbeddingService: @unchecked Sendable {

    private let language: NLLanguage
    private var embedding: NLContextualEmbedding?

    init(language: NLLanguage = .english) {
        self.language = language
    }

    // MARK: - Public

    /// テキストを 512 次元の埋め込みベクターに変換する。
    /// モデルが未ロードの場合は自動ロードする。
    func embed(text: String) async throws -> [Double] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EmbeddingError.emptyText }

        let emb = try loadEmbedding()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try emb.embeddingResult(for: trimmed, language: nil)
                    let vec = self.averageTokenVectors(result: result, text: trimmed, dim: emb.dimension)
                    continuation.resume(returning: vec)
                } catch {
                    continuation.resume(throwing: EmbeddingError.embeddingFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Private

    private func loadEmbedding() throws -> NLContextualEmbedding {
        if let existing = embedding { return existing }

        guard let emb = NLContextualEmbedding(language: language) else {
            throw EmbeddingError.modelUnavailable
        }
        try emb.load()
        self.embedding = emb
        return emb
    }

    /// 全トークンベクターを平均して文書ベクターを生成する。
    private func averageTokenVectors(
        result: NLContextualEmbeddingResult,
        text: String,
        dim: Int
    ) -> [Double] {
        var sum = [Double](repeating: 0, count: dim)
        var count = 0

        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { tokenVec, _ in
            for i in 0..<min(tokenVec.count, dim) {
                sum[i] += tokenVec[i]
            }
            count += 1
            return true
        }

        guard count > 0 else { return sum }
        return sum.map { $0 / Double(count) }
    }
}
