import Foundation

final class IntelligenceViewModel: @unchecked Sendable {
    private let intelligence: IntelligenceServiceProtocol
    private let annotationService: AnnotationServiceProtocol

    private(set) var lastSummary: DocumentSummary?
    private(set) var lastSearchQuery: SearchQuery?
    private(set) var lastError: IntelligenceError?
    private(set) var isProcessing: Bool = false

    init(intelligence: IntelligenceServiceProtocol, annotationService: AnnotationServiceProtocol) {
        self.intelligence = intelligence
        self.annotationService = annotationService
    }

    func summarizeDocument(_ document: Document, text: String) async {
        guard !text.isEmpty else {
            lastError = .emptyInput
            return
        }

        isProcessing = true
        lastError = nil

        do {
            let summary = try await intelligence.summarize(text: text, maxLength: 200)
            let keywords = try await intelligence.extractKeywords(from: text, maxCount: 5)
            let tags = try await intelligence.suggestTags(for: text)

            lastSummary = DocumentSummary(
                documentId: document.id,
                shortSummary: summary,
                extractedKeywords: keywords,
                suggestedTags: tags
            )

            // ネイティブ注釈に書き込み
            try annotationService.writeFinderComment(summary, to: document.path)
            try annotationService.writeTags(tags, to: document.path)
        } catch let error as IntelligenceError {
            lastError = error
        } catch {
            lastError = .generationFailed(error.localizedDescription)
        }

        isProcessing = false
    }

    func search(naturalLanguage query: String) async {
        guard !query.isEmpty else {
            lastError = .emptyInput
            return
        }

        isProcessing = true
        lastError = nil

        do {
            lastSearchQuery = try await intelligence.translateQuery(query)
        } catch let error as IntelligenceError {
            lastError = error
        } catch {
            lastError = .generationFailed(error.localizedDescription)
        }

        isProcessing = false
    }
}
