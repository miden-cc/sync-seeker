import Foundation
import Testing
@testable import SyncSeekerApp
import SyncSeeker

@MainActor
@Suite("AppState Rename")
struct AppStateRenameTests {

    private func setupTestEnv() throws -> (AppState, URL) {
        let appState = AppState()
        let syncFolder = appState.syncFolderPath

        let testFileURL = syncFolder.appendingPathComponent("test_rename_doc.txt")
        let content = "Hello World"
        try content.write(to: testFileURL, atomically: true, encoding: .utf8)

        appState.loadAll()

        return (appState, testFileURL)
    }

    private func cleanupTestEnv(testFileURL: URL, newURL: URL?) {
        let fm = FileManager.default
        try? fm.removeItem(at: testFileURL)
        if let newURL = newURL {
            try? fm.removeItem(at: newURL)
        }
    }

    @Test("renameFile to new name preserves extension when omitted")
    func renamePreservesExtension() async throws {
        let (appState, testFileURL) = try setupTestEnv()

        guard let doc = appState.allDocuments.first(where: { $0.path == testFileURL }) else {
            Issue.record("Document not found in AppState")
            cleanupTestEnv(testFileURL: testFileURL, newURL: nil)
            return
        }

        let newName = "renamed_doc"
        try appState.renameFile(doc, to: newName)

        // Let the detached task finish and MainActor update run
        try await Task.sleep(nanoseconds: 500_000_000)

        let newURL = testFileURL.deletingLastPathComponent().appendingPathComponent("renamed_doc.txt")
        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(!FileManager.default.fileExists(atPath: testFileURL.path))

        #expect(appState.allDocuments.contains(where: { $0.path == newURL }))

        cleanupTestEnv(testFileURL: testFileURL, newURL: newURL)
    }

    @Test("renameFile to new name with new extension changes extension")
    func renameChangesExtension() async throws {
        let (appState, testFileURL) = try setupTestEnv()

        guard let doc = appState.allDocuments.first(where: { $0.path == testFileURL }) else {
            Issue.record("Document not found in AppState")
            cleanupTestEnv(testFileURL: testFileURL, newURL: nil)
            return
        }

        let newName = "renamed_doc.md"
        try appState.renameFile(doc, to: newName)

        // Let the detached task finish and MainActor update run
        try await Task.sleep(nanoseconds: 500_000_000)

        let newURL = testFileURL.deletingLastPathComponent().appendingPathComponent("renamed_doc.md")
        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(!FileManager.default.fileExists(atPath: testFileURL.path))

        #expect(appState.allDocuments.contains(where: { $0.path == newURL }))

        cleanupTestEnv(testFileURL: testFileURL, newURL: newURL)
    }
}
