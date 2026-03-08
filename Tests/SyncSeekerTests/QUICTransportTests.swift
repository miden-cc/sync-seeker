import Foundation
import Testing
@testable import SyncSeeker

@Suite("QUICTransport")
struct QUICTransportTests {

    // MARK: - Helpers

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("quic-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeFile(at dir: URL, path: String, content: Data) throws -> ManifestEntry {
        let fileURL = dir.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: fileURL)
        return ManifestEntry(
            relativePath: path,
            size: Int64(content.count),
            modifiedDate: Date(),
            sha256: "test",
            hasXattr: false
        )
    }

    private func makeTransport(channel: MockDataChannel) -> QUICTransport {
        QUICTransport(channelFactory: { _, _ in channel })
    }

    // MARK: - Channel lifecycle

    @Test("transferFiles connects the channel")
    func connectsChannel() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "a.txt", content: Data("hello".utf8))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.connectCalled)
    }

    @Test("transferFiles closes channel after completion")
    func closesChannel() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "a.txt", content: Data("hi".utf8))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.closeCalled)
    }

    // MARK: - Wire protocol correctness

    @Test("Sent stream starts with SYNC magic")
    func streamHasSyncMagic() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "f.txt", content: Data([1]))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.hasSyncMagic())
    }

    @Test("Sent stream ends with DONE sentinel")
    func streamHasDoneSentinel() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "f.txt", content: Data([1]))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.hasDoneSentinel())
    }

    @Test("Header declares correct file count")
    func headerDeclaredCount() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let e1 = try writeFile(at: dir, path: "a.txt", content: Data("a".utf8))
        let e2 = try writeFile(at: dir, path: "b.txt", content: Data("b".utf8))
        let e3 = try writeFile(at: dir, path: "c.txt", content: Data("c".utf8))

        try transport.transferFiles([e1, e2, e3], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.declaredFileCount() == 3)
    }

    // MARK: - Delegate: progress

    @Test("Delegate receives progress update for each file")
    func progressPerFile() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let e1 = try writeFile(at: dir, path: "a.txt", content: Data("aa".utf8))
        let e2 = try writeFile(at: dir, path: "b.txt", content: Data("bb".utf8))

        try transport.transferFiles([e1, e2], from: dir)
        Thread.sleep(forTimeInterval: 0.15)

        #expect(spy.progressUpdates.count == 2)
        #expect(spy.progressUpdates.last?.sent == 2)
        #expect(spy.progressUpdates.last?.total == 2)
    }

    @Test("Delegate progress filenames match entries")
    func progressFilenames() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "docs/readme.md", content: Data("read".utf8))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(spy.progressUpdates.first?.file == "docs/readme.md")
    }

    // MARK: - Delegate: completion

    @Test("Delegate receives completion with correct file count")
    func completionFileCount() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let e1 = try writeFile(at: dir, path: "a.txt", content: Data("hello".utf8))
        let e2 = try writeFile(at: dir, path: "b.txt", content: Data("world".utf8))

        try transport.transferFiles([e1, e2], from: dir)
        Thread.sleep(forTimeInterval: 0.15)

        #expect(spy.completedFileCount == 2)
    }

    @Test("Delegate receives completion with correct total bytes")
    func completionTotalBytes() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let e1 = try writeFile(at: dir, path: "a.txt", content: Data(count: 100))
        let e2 = try writeFile(at: dir, path: "b.txt", content: Data(count: 200))

        try transport.transferFiles([e1, e2], from: dir)
        Thread.sleep(forTimeInterval: 0.15)

        #expect(spy.completedTotalBytes == 300)
    }

    // MARK: - Error handling

    @Test("Channel connect error reports failure to delegate")
    func connectError() throws {
        let channel = MockDataChannel()
        channel.connectError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "refused"])
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "a.txt", content: Data([1]))

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(spy.failureMessage != nil)
        #expect(spy.failureMessage?.contains("refused") == true)
    }

    @Test("Missing source file reports failure to delegate")
    func missingFile() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        let entry = ManifestEntry(
            relativePath: "ghost.txt",
            size: 10,
            modifiedDate: Date(),
            sha256: "abc",
            hasXattr: false
        )

        try transport.transferFiles([entry], from: dir)
        Thread.sleep(forTimeInterval: 0.1)

        #expect(spy.failureMessage != nil)
    }

    // MARK: - Cancel

    @Test("Cancel closes the channel")
    func cancelClosesChannel() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let dir = try makeTempDir()
        let entry = try writeFile(at: dir, path: "a.txt", content: Data([1]))

        try transport.transferFiles([entry], from: dir)
        transport.cancel()
        Thread.sleep(forTimeInterval: 0.1)

        #expect(channel.closeCalled)
    }

    @Test("Cancel prevents completion callback")
    func cancelPreventsCompletion() throws {
        let channel = MockDataChannel()
        let transport = makeTransport(channel: channel)
        let spy = SpyTransportDelegate()
        transport.delegate = spy

        let dir = try makeTempDir()
        // Large enough that cancel might arrive before completion
        let bigData = Data(count: 1024 * 1024)
        let entry = try writeFile(at: dir, path: "big.bin", content: bigData)

        try transport.transferFiles([entry], from: dir)
        transport.cancel()
        Thread.sleep(forTimeInterval: 0.1)

        #expect(spy.completedFileCount == nil)
    }
}

// MARK: - SpyTransportDelegate

private final class SpyTransportDelegate: TransportDelegate {
    struct ProgressEvent {
        let sent: Int
        let total: Int
        let file: String
    }

    var progressUpdates: [ProgressEvent] = []
    var completedFileCount: Int?
    var completedTotalBytes: Int64?
    var failureMessage: String?

    func transportDidUpdateProgress(sent: Int, total: Int, currentFile: String) {
        progressUpdates.append(ProgressEvent(sent: sent, total: total, file: currentFile))
    }
    func transportDidComplete(fileCount: Int, totalBytes: Int64) {
        completedFileCount = fileCount
        completedTotalBytes = totalBytes
    }
    func transportDidFail(error: String) {
        failureMessage = error
    }
}
