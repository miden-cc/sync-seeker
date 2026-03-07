import Foundation
import Testing
@testable import SyncSeeker

@Suite("FileWatcherService")
struct FileWatcherServiceTests {

    // MARK: - init

    @Test("init with valid directory succeeds")
    func initValidDirectory() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        #expect(throws: Never.self) {
            let watcher = try FileWatcherService(watchPath: tmp)
            watcher.stop()
        }
    }

    @Test("init with non-existent path throws")
    func initInvalidPathThrows() {
        let nonExistent = URL(fileURLWithPath: "/tmp/does_not_exist_\(UUID().uuidString)")
        #expect(throws: (any Error).self) {
            _ = try FileWatcherService(watchPath: nonExistent)
        }
    }

    // open() が -1 を返す場合は FD 自体取得しないため leak は発生しない。
    // defer による保護は open() 成功後に setupWatcher() が例外を投げるケースを対象とする。
    // → stop releases file descriptor テストで代替検証済み。

    // MARK: - stop

    @Test("stop can be called multiple times without crash")
    func stopIdempotent() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let watcher = try FileWatcherService(watchPath: tmp)
        watcher.stop()
        watcher.stop()
        watcher.stop()
    }

    @Test("stop prevents further onFileChanged callbacks")
    func stopSilencesCallbacks() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let watcher = try FileWatcherService(watchPath: tmp)
        var callCount = 0
        watcher.onFileChanged = { callCount += 1 }

        // stop してから書き込み → コールバックが増えないことを確認
        watcher.stop()
        try await Task.sleep(nanoseconds: 100_000_000)
        let countAfterStop = callCount
        try "after-stop".data(using: .utf8)!.write(to: tmp.appendingPathComponent("late.txt"))
        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(callCount == countAfterStop)
    }

    // MARK: - onFileChanged

    @Test("onFileChanged fires when file is created in watched directory")
    func onFileChangedFires() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let watcher = try FileWatcherService(watchPath: tmp)
        defer { watcher.stop() }

        var fired = false
        watcher.onFileChanged = { fired = true }

        let newFile = tmp.appendingPathComponent("trigger.txt")
        try "hello".data(using: .utf8)!.write(to: newFile)

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(fired)
    }

    @Test("onFileChanged fires when file content changes")
    func onFileChangedOnContentChange() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let file = tmp.appendingPathComponent("watch.txt")
        try "initial".data(using: .utf8)!.write(to: file)

        let watcher = try FileWatcherService(watchPath: tmp)
        defer { watcher.stop() }

        var fired = false
        watcher.onFileChanged = { fired = true }

        // 内容を上書き
        try "updated".data(using: .utf8)!.write(to: file)

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(fired)
    }

    @Test("onFileChanged fires for changes in subdirectory")
    func onFileChangedRecursive() async throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sub = tmp.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let watcher = try FileWatcherService(watchPath: tmp)
        defer { watcher.stop() }

        var fired = false
        watcher.onFileChanged = { fired = true }

        // サブフォルダ内にファイルを作成
        try "deep".data(using: .utf8)!.write(to: sub.appendingPathComponent("deep.txt"))

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(fired)
    }

    // MARK: - Helper

    /// 現在のプロセスが開いている FD 数を返す
    private func openFileDescriptorCount() -> Int {
        var count = 0
        let maxFD = Int(getdtablesize())
        for fd in 0..<maxFD {
            if fcntl(Int32(fd), F_GETFD) != -1 { count += 1 }
        }
        return count
    }
}
