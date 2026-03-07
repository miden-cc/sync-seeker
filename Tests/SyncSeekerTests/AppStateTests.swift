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
        let document = Document(id: UUID(), name: testFileURL.lastPathComponent, path: testFileURL,
                                size: 4, modifiedDate: Date(), fileType: .plainText, tags: [])
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
        let expectedURL = appState.syncFolderPath.appendingPathComponent(newFolderName)
        #expect(FileManager.default.fileExists(atPath: expectedURL.path) == true)
        try? FileManager.default.removeItem(at: expectedURL)
    }

    @Test("Create folder handles duplicates by auto-incrementing")
    func testCreateFolderDuplicate() async throws {
        let appState = AppState()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let newFolderName = "DuplicateTest \(UUID().uuidString)"
        try appState.createFolder(named: newFolderName)
        try appState.createFolder(named: newFolderName)
        let first = appState.syncFolderPath.appendingPathComponent(newFolderName)
        let second = appState.syncFolderPath.appendingPathComponent("\(newFolderName) 2")
        #expect(FileManager.default.fileExists(atPath: first.path) == true)
        #expect(FileManager.default.fileExists(atPath: second.path) == true)
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.removeItem(at: second)
    }

    @Test("Create folder defaults to New Folder for empty name")
    func testCreateFolderEmptyName() async throws {
        let appState = AppState()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let baseURL = appState.syncFolderPath.appendingPathComponent("New Folder")
        let initialExists = FileManager.default.fileExists(atPath: baseURL.path)
        try appState.createFolder(named: "   ")
        if !initialExists {
            #expect(FileManager.default.fileExists(atPath: baseURL.path) == true)
            try? FileManager.default.removeItem(at: baseURL)
        }
    }

    @Test("Duplicate file creates a copy with 'copy' suffix")
    func testDuplicateFile() async throws {
        let appState = AppState()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("test.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        let doc = Document(id: UUID(), name: "test.txt", path: fileURL,
                           size: 5, modifiedDate: Date(), fileType: .plainText, tags: [])
        try await appState.duplicateFile(doc)
        let duplicateURL = tempDir.appendingPathComponent("test copy.txt")
        #expect(FileManager.default.fileExists(atPath: duplicateURL.path))
    }

    @Test("Move file relocates it to destination folder")
    func testMoveFile() async throws {
        let appState = AppState()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let fileURL = tempDir.appendingPathComponent("test2.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        let folderURL = tempDir.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let doc = Document(id: UUID(), name: "test2.txt", path: fileURL,
                           size: 5, modifiedDate: Date(), fileType: .plainText, tags: [])
        try await appState.moveFile(doc, to: folderURL)
        #expect(FileManager.default.fileExists(atPath: folderURL.appendingPathComponent("test2.txt").path))
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
