import Foundation
#if os(macOS)
import CoreServices
#endif

/// 指定フォルダ以下の変更をリアルタイムに監視するサービス。
/// macOS では FSEvents を使用し、再帰的・コンテンツ変更も検出する。
public final class FileWatcherService: @unchecked Sendable {

    public let watchPath: URL
    public var onFileChanged: (() -> Void)?

    private let lock = NSLock()

#if os(macOS)
    private var eventStream: FSEventStreamRef?
    private let queue: DispatchQueue

    public init(watchPath: URL) throws {
        guard FileManager.default.fileExists(atPath: watchPath.path) else {
            throw NSError(
                domain: "FileWatcherService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Path does not exist: \(watchPath.path)"]
            )
        }
        self.watchPath = watchPath
        self.queue = DispatchQueue(label: "com.syncseeker.filewatcher", qos: .utility)
        setupFSEvents()
    }

    private func setupFSEvents() {
        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcherService>.fromOpaque(info).takeUnretainedValue()
            watcher.lock.withLock { watcher.onFileChanged?() }
        }

        let paths = [watchPath.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil, callback, &ctx, paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,  // 秒: コールバック遅延（デバウンス）
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    public func stop() {
        lock.withLock {
            guard let stream = eventStream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    deinit { stop() }

#else
    // iOS / その他: kqueue ベースのフォールバック（直接の子のみ監視）
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let fileDescriptor: CInt
    private let queue: DispatchQueue

    public init(watchPath: URL) throws {
        self.watchPath = watchPath
        self.queue = DispatchQueue(label: "com.syncseeker.filewatcher")

        let fd = open(watchPath.path, O_EVTONLY)
        guard fd != -1 else {
            throw NSError(
                domain: "FileWatcherService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open file descriptor"]
            )
        }

        var initSucceeded = false
        defer { if !initSucceeded { close(fd) } }

        self.fileDescriptor = fd
        setupKqueue()
        initSucceeded = true
    }

    private func setupKqueue() {
        let fd = fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.lock.withLock { self?.onFileChanged?() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        dispatchSource = source
    }

    public func stop() {
        lock.withLock {
            dispatchSource?.cancel()
            dispatchSource = nil
        }
    }

    deinit { stop() }
#endif
}
