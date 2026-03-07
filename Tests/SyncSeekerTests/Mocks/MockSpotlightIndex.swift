import Foundation
import CoreSpotlight
@testable import SyncSeeker

final class MockSpotlightIndex: SpotlightIndexProtocol, @unchecked Sendable {

    private(set) var indexedItems: [CSSearchableItem] = []
    private(set) var deletedIdentifiers: [String] = []
    private(set) var deleteAllCalled = false

    var indexError: Error?
    var deleteError: Error?

    func indexSearchableItems(_ items: [CSSearchableItem]) async throws {
        if let error = indexError { throw error }
        indexedItems.append(contentsOf: items)
    }

    func deleteSearchableItems(withIdentifiers identifiers: [String]) async throws {
        if let error = deleteError { throw error }
        deletedIdentifiers.append(contentsOf: identifiers)
        indexedItems.removeAll { identifiers.contains($0.uniqueIdentifier) }
    }

    func deleteAllSearchableItems() async throws {
        if let error = deleteError { throw error }
        deleteAllCalled = true
        indexedItems.removeAll()
    }
}
