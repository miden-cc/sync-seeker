import Foundation
import CoreSpotlight

// MARK: - Protocol abstraction (testable)

protocol SpotlightIndexProtocol: Sendable {
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws
    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws
    func deleteAllSearchableItems() async throws
}

// MARK: - CSSearchableIndex conformance

extension CSSearchableIndex: SpotlightIndexProtocol {
    func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.indexSearchableItems(items) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteAllSearchableItems() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.deleteAllSearchableItems { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Service protocol

protocol SpotlightIndexServiceProtocol {
    func indexDocument(_ document: Document, summary: String?, tags: [String]) async throws
    func deindexDocument(_ document: Document) async throws
    func deindexAll() async throws
}

// MARK: - Implementation

struct CoreSpotlightIndexService: SpotlightIndexServiceProtocol {

    private let index: SpotlightIndexProtocol
    private let domainIdentifier = "com.miden.SyncSeeker"

    init(index: SpotlightIndexProtocol = CSSearchableIndex.default()) {
        self.index = index
    }

    func indexDocument(_ document: Document, summary: String?, tags: [String]) async throws {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = document.name
        attributeSet.contentDescription = summary
        attributeSet.keywords = tags.isEmpty ? nil : tags
        attributeSet.contentType = contentTypeUTI(for: document.fileType)
        attributeSet.contentURL = document.path
        attributeSet.lastUsedDate = document.modifiedDate

        let item = CSSearchableItem(
            uniqueIdentifier: document.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        try await index.indexSearchableItems([item])
    }

    func deindexDocument(_ document: Document) async throws {
        try await index.deleteSearchableItems(withIdentifiers: [document.id.uuidString])
    }

    func deindexAll() async throws {
        try await index.deleteAllSearchableItems()
    }

    // MARK: - Private

    private func contentTypeUTI(for fileType: FileType) -> String {
        switch fileType {
        case .pdf:       return "com.adobe.pdf"
        case .markdown:  return "net.daringfireball.markdown"
        case .plainText: return "public.plain-text"
        case .richText:  return "public.rtf"
        case .unknown:   return "public.data"
        }
    }
}
