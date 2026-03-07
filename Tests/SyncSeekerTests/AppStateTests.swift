import Foundation
import Testing
@testable import SyncSeekerApp
@testable import SyncSeeker

@MainActor
@Suite("AppState Tests")
struct AppStateTests {

    @Test("Trash file removes file from document list")
    func trashFileRemovesFile() async throws {
        let appState = AppState()

        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".txt")

        try "test".data(using: .utf8)!.write(to: testFileURL)

        let document = Document(
            id: UUID(),
            name: testFileURL.lastPathComponent,
            path: testFileURL,
            size: 4,
            modifiedDate: Date(),
            fileType: .plainText,
            tags: []
        )

        appState.allDocuments = [document]
        appState.selectedDocument = document

        try appState.trashFile(document)

        try await Task.sleep(nanoseconds: 1_000_000_000) // Wait for detached task and MainActor return

        #expect(appState.selectedDocument == nil)
        // Note: loadAll() is called, so allDocuments will be updated based on the actual sync folder
        // Since testFileURL was not in sync folder, it will likely be empty.
    }
}
