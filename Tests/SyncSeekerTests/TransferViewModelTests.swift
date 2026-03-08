import Foundation
import Testing
@testable import SyncSeeker

@Suite("TransferViewModel")
struct TransferViewModelTests {

    @Test("Initial state is idle")
    func initialState() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        #expect(vm.state == .idle)
        #expect(vm.lastDiff == nil)
    }

    @Test("Sync with no changes completes immediately")
    func noChanges() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileA])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        vm.startSync(source: source, destination: dest)

        #expect(vm.state == .completed(fileCount: 0, totalBytes: 0))
        #expect(vm.lastDiff?.isEmpty == true)
        #expect(mock.transferCalled == false)
    }

    @Test("Sync with changes triggers transport")
    func syncWithChanges() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        vm.startSync(source: source, destination: dest)

        #expect(mock.transferCalled)
        #expect(mock.lastEntries?.count == 1)
        #expect(mock.lastEntries?.first?.relativePath == "docs/plan.pdf")
    }

    @Test("Transport error sets error state")
    func transportError() {
        let mock = MockTransport()
        mock.transferError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transfer failed"])
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileC])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileA])

        vm.startSync(source: source, destination: dest)

        #expect(vm.state == .error("Transfer failed"))
    }

    @Test("Progress updates from transport")
    func progressUpdates() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        vm.startSync(source: source, destination: dest)
        mock.simulateProgress(sent: 1, total: 2, file: "docs/plan.pdf")

        #expect(vm.state == .transferring(sent: 1, total: 2, currentFile: "docs/plan.pdf"))
    }

    @Test("Completion from transport")
    func completion() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        vm.startSync(source: source, destination: dest)
        mock.simulateComplete(fileCount: 1, totalBytes: 5000)

        #expect(vm.state == .completed(fileCount: 1, totalBytes: 5000))
    }

    @Test("External error from transport")
    func externalError() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        vm.startSync(source: source, destination: dest)
        mock.simulateError("Connection lost")

        #expect(vm.state == .error("Connection lost"))
    }

    @Test("Cancel resets to idle")
    func cancel() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileB])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [])

        vm.startSync(source: source, destination: dest)
        vm.cancel()

        #expect(vm.state == .idle)
        #expect(mock.cancelCalled)
    }

    @Test("lastDiff is populated after sync")
    func lastDiffPopulated() {
        let mock = MockTransport()
        let vm = TransferViewModel(transport: mock)

        let source = TestFixtures.manifest(entries: [TestFixtures.fileA, TestFixtures.fileBModified])
        let dest = TestFixtures.manifest(root: TestFixtures.destURL, entries: [TestFixtures.fileB])

        vm.startSync(source: source, destination: dest)

        #expect(vm.lastDiff?.added.count == 1)
        #expect(vm.lastDiff?.modified.count == 1)
    }
}
