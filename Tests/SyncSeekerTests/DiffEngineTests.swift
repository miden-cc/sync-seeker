import Foundation
import Testing
@testable import SyncSeeker

@Suite("DiffEngine")
struct DiffEngineTests {

    let engine = DiffEngine()

    @Test("Identical manifests produce empty diff")
    func identicalManifests() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA, TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.isEmpty)
        #expect(diff.totalChanges == 0)
    }

    @Test("New file in source is detected as added")
    func addedFiles() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB, TestFixtures.fileC])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.added.count == 2)
        #expect(diff.added.map(\.relativePath).contains("docs/plan.pdf"))
        #expect(diff.added.map(\.relativePath).contains("notes/todo.txt"))
        #expect(diff.modified.isEmpty)
        #expect(diff.deleted.isEmpty)
    }

    @Test("File missing from source is detected as deleted")
    func deletedFiles() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA, TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.deleted.count == 1)
        #expect(diff.deleted.first?.relativePath == "docs/plan.pdf")
        #expect(diff.added.isEmpty)
        #expect(diff.modified.isEmpty)
    }

    @Test("Changed hash is detected as modified")
    func modifiedFiles() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileBModified])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA, TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.modified.count == 1)
        #expect(diff.modified.first?.relativePath == "docs/plan.pdf")
        #expect(diff.modified.first?.sha256 == "bbb999")
        #expect(diff.added.isEmpty)
        #expect(diff.deleted.isEmpty)
    }

    @Test("Mixed changes: add + modify + delete")
    func mixedChanges() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileBModified, TestFixtures.fileC])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA, TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.added.count == 1)
        #expect(diff.added.first?.relativePath == "notes/todo.txt")
        #expect(diff.modified.count == 1)
        #expect(diff.modified.first?.relativePath == "docs/plan.pdf")
        #expect(diff.deleted.isEmpty)
        #expect(diff.totalChanges == 2)
    }

    @Test("Empty source against populated destination = all deleted")
    func emptySource() {
        let source = TestFixtures.manifest(entries: [])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA, TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.deleted.count == 2)
        #expect(diff.added.isEmpty)
    }

    @Test("Both empty = no diff")
    func bothEmpty() {
        let source = TestFixtures.manifest(entries: [])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        let diff = engine.computeDiff(source: source, destination: dest)

        #expect(diff.isEmpty)
    }

    @Test("totalTransferSize sums added and modified")
    func transferSize() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileBModified, TestFixtures.fileC])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileB])

        let diff = engine.computeDiff(source: source, destination: dest)

        // fileC (50) added + fileBModified (5200) modified
        #expect(diff.totalTransferSize == 5250)
    }

    @Test("Results are sorted by relativePath")
    func sortedResults() {
        let source = TestFixtures.manifest(entries: [TestFixtures.fileC, TestFixtures.fileB, TestFixtures.fileA])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        let diff = engine.computeDiff(source: source, destination: dest)

        let paths = diff.added.map(\.relativePath)
        #expect(paths == paths.sorted())
    }
}
