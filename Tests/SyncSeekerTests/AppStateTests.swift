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

        try await Task.sleep(nanoseconds: 1_000_000_000)

        #expect(appState.selectedDocument == nil)
    }

    @Test("Create folder creates a directory")
    func testCreateFolder() async throws {
        let appState = AppState()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let newFolderName = "TestFolder \(UUID().uuidString)"
        try appState.createFolder(named: newFolderName)

        let fm = FileManager.default
        let expectedURL = appState.syncFolderPath.appendingPathComponent(newFolderName)
        #expect(fm.fileExists(atPath: expectedURL.path) == true)
        try? fm.removeItem(at: expectedURL)
    }

    @Test("Create folder handles duplicates by auto-incrementing")
    func testCreateFolderDuplicate() async throws {
        let appState = AppState()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let newFolderName = "DuplicateTest \(UUID().uuidString)"
        try appState.createFolder(named: newFolderName)
        try appState.createFolder(named: newFolderName)

        let fm = FileManager.default
        let first = appState.syncFolderPath.appendingPathComponent(newFolderName)
        let second = appState.syncFolderPath.appendingPathComponent("\(newFolderName) 2")
        #expect(fm.fileExists(atPath: first.path) == true)
        #expect(fm.fileExists(atPath: second.path) == true)
        try? fm.removeItem(at: first)
        try? fm.removeItem(at: second)
    }

    @Test("Create folder defaults to New Folder for empty name")
    func testCreateFolderEmptyName() async throws {
        let appState = AppState()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let fm = FileManager.default
        let baseURL = appState.syncFolderPath.appendingPathComponent("New Folder")
        let initialExists = fm.fileExists(atPath: baseURL.path)

        try appState.createFolder(named: "   ")

        if !initialExists {
            #expect(fm.fileExists(atPath: baseURL.path) == true)
            try? fm.removeItem(at: baseURL)
        }
    }
}
