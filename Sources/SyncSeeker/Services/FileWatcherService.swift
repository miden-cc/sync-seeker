import Foundation

public final class FileWatcherService: @unchecked Sendable {
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let fileDescriptor: CInt
    private let queue: DispatchQueue
    public let watchPath: URL
    private let lock = NSLock()

    public var onFileChanged: (() -> Void)?

    public init(watchPath: URL) throws {
        self.watchPath = watchPath
        self.queue = DispatchQueue(label: "com.syncseeker.filewatcher")

        let fileDescriptor = open(watchPath.path, O_EVTONLY)
        guard fileDescriptor != -1 else {
            throw NSError(domain: "FileWatcherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open file descriptor"])
        }

        self.fileDescriptor = fileDescriptor
        setupWatcher()
    }

    private func setupWatcher() {
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .attrib],
            queue: queue
        )

        dispatchSource.setEventHandler { [weak self] in
            self?.lock.withLock {
                self?.onFileChanged?()
            }
        }

        dispatchSource.setCancelHandler { [weak self] in
            close(self?.fileDescriptor ?? -1)
        }

        dispatchSource.resume()
        self.dispatchSource = dispatchSource
    }

    public func stop() {
        lock.withLock {
            dispatchSource?.cancel()
            dispatchSource = nil
        }
    }

    deinit {
        stop()
    }
}
