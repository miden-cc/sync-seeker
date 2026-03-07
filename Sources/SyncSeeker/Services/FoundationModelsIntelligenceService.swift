import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// `IntelligenceServiceProtocol` の実体実装。
/// Apple Intelligence（オンデバイス LLM）を使用する。
/// macOS 26 / iOS 26 以降が必要。FoundationModels が存在しない環境では下部の stub を使用。
final class FoundationModelsIntelligenceService: IntelligenceServiceProtocol {

    // MARK: - Availability

    static var isAppleIntelligenceAvailable: Bool {
        if #available(macOS 26, iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    private let availabilityOverride: Bool?
    private var isAvailable: Bool { availabilityOverride ?? Self.isAppleIntelligenceAvailable }

    init(availabilityOverride: Bool? = nil) {
        self.availabilityOverride = availabilityOverride
    }

    // MARK: - IntelligenceServiceProtocol

    func summarize(text: String, maxLength: Int) async throws -> String {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.modelUnavailable }
        if #available(macOS 26, iOS 26, *) {
            return try await _summarize(text: text, maxLength: maxLength)
        }
        throw IntelligenceError.modelUnavailable
    }

    func extractKeywords(from text: String, maxCount: Int) async throws -> [String] {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.modelUnavailable }
        if #available(macOS 26, iOS 26, *) {
            return try await _extractKeywords(from: text, maxCount: maxCount)
        }
        throw IntelligenceError.modelUnavailable
    }

    func suggestTags(for text: String) async throws -> [String] {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.modelUnavailable }
        if #available(macOS 26, iOS 26, *) {
            return try await _suggestTags(for: text)
        }
        throw IntelligenceError.modelUnavailable
    }

    func translateQuery(_ naturalLanguage: String) async throws -> SearchQuery {
        guard !naturalLanguage.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.modelUnavailable }
        if #available(macOS 26, iOS 26, *) {
            return try await _translateQuery(naturalLanguage)
        }
        throw IntelligenceError.modelUnavailable
    }

    // MARK: - macOS 26+ implementations

    @available(macOS 26, iOS 26, *)
    private func _summarize(text: String, maxLength: Int) async throws -> String {
        let session = LanguageModelSession(instructions: "You are a concise document summarizer.")
        let prompt = """
        Summarize the following document in \(maxLength) characters or less.
        Return ONLY the summary text.

        Document:
        \(text)
        """
        do {
            let response = try await session.respond(to: prompt)
            return IntelligenceResponseParser.truncate(response.content, to: maxLength)
        } catch {
            throw mapError(error)
        }
    }

    @available(macOS 26, iOS 26, *)
    private func _extractKeywords(from text: String, maxCount: Int) async throws -> [String] {
        let session = LanguageModelSession(instructions: "You extract keywords from documents.")
        let prompt = """
        Extract the \(maxCount) most important keywords from this text.
        Return ONLY a comma-separated list of keywords, nothing else.
        Example: contract, legal, NDA

        Text:
        \(text.prefix(3000))
        """
        do {
            let response = try await session.respond(to: prompt)
            return IntelligenceResponseParser.parseKeywords(response.content, max: maxCount)
        } catch {
            throw mapError(error)
        }
    }

    @available(macOS 26, iOS 26, *)
    private func _suggestTags(for text: String) async throws -> [String] {
        let session = LanguageModelSession(instructions: "You suggest short document tags.")
        let prompt = """
        Suggest 3-5 short tags for categorizing this document.
        Return ONLY a comma-separated list of lowercase tags, nothing else.
        Example: legal, finance, important

        Document:
        \(text.prefix(2000))
        """
        do {
            let response = try await session.respond(to: prompt)
            return IntelligenceResponseParser.parseKeywords(response.content, max: 5)
        } catch {
            throw mapError(error)
        }
    }

    @available(macOS 26, iOS 26, *)
    private func _translateQuery(_ naturalLanguage: String) async throws -> SearchQuery {
        let session = LanguageModelSession(instructions: """
            You are a strict JSON generator. You ONLY output valid JSON objects, never explanations.
            Output exactly this format: {"keywords":["..."],"fileTypes":["..."],"tags":["..."],"dateFrom":null,"dateTo":null}
            Valid fileTypes: pdf, markdown, plainText, richText, unknown
            Respond with ONLY the JSON object. No markdown, no explanation, no text before or after.
            """)
        let prompt = """
            Convert this search query into a JSON object: "\(naturalLanguage)"
            Remember: output ONLY the JSON object.
            """
        // On-device model may occasionally fail to produce clean JSON; retry once.
        for attempt in 0..<2 {
            do {
                let response = try await session.respond(to: prompt)
                return try IntelligenceResponseParser.parseSearchQuery(fromJSON: response.content)
            } catch is IntelligenceError where attempt == 0 {
                // First attempt failed; retry
                continue
            } catch let error as IntelligenceError {
                throw error
            } catch {
                throw mapError(error)
            }
        }
        throw IntelligenceError.generationFailed("Failed to parse query after retries")
    }

    // MARK: - Private

    private func mapError(_ error: Error) -> IntelligenceError {
        if let ie = error as? IntelligenceError { return ie }
        let desc = error.localizedDescription
        if desc.lowercased().contains("unavailable") || desc.lowercased().contains("not available") {
            return .modelUnavailable
        }
        return .generationFailed(desc)
    }
}

#else

// MARK: - Stub (FoundationModels 非対応環境)

final class FoundationModelsIntelligenceService: IntelligenceServiceProtocol {
    static var isAppleIntelligenceAvailable: Bool { false }

    init(availabilityOverride: Bool? = nil) {}

    func summarize(text: String, maxLength: Int) async throws -> String {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        throw IntelligenceError.modelUnavailable
    }
    func extractKeywords(from text: String, maxCount: Int) async throws -> [String] {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        throw IntelligenceError.modelUnavailable
    }
    func suggestTags(for text: String) async throws -> [String] {
        guard !text.isEmpty else { throw IntelligenceError.emptyInput }
        throw IntelligenceError.modelUnavailable
    }
    func translateQuery(_ naturalLanguage: String) async throws -> SearchQuery {
        guard !naturalLanguage.isEmpty else { throw IntelligenceError.emptyInput }
        throw IntelligenceError.modelUnavailable
    }
}

#endif
