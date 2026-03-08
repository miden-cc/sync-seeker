import Foundation

final class TransferViewModel: TransportDelegate, @unchecked Sendable {
    private let diffEngine: DiffEngine
    private let manifestBuilder: ManifestBuilder
    private var transport: TransportProtocol

    private(set) var state: TransferState = .idle
    private(set) var lastDiff: DiffResult?

    init(transport: TransportProtocol, diffEngine: DiffEngine = DiffEngine(), manifestBuilder: ManifestBuilder = ManifestBuilder()) {
        self.transport = transport
        self.diffEngine = diffEngine
        self.manifestBuilder = manifestBuilder
        self.transport.delegate = self
    }

    func startSync(source: FileManifest, destination: FileManifest) {
        state = .comparing
        let diff = diffEngine.computeDiff(source: source, destination: destination)
        lastDiff = diff

        if diff.isEmpty {
            state = .completed(fileCount: 0, totalBytes: 0)
            return
        }

        let toTransfer = diff.added + diff.modified
        state = .transferring(sent: 0, total: toTransfer.count, currentFile: toTransfer.first?.relativePath ?? "")

        do {
            try transport.transferFiles(toTransfer, from: source.rootPath)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func cancel() {
        transport.cancel()
        state = .idle
    }

    // MARK: - TransportDelegate

    func transportDidUpdateProgress(sent: Int, total: Int, currentFile: String) {
        state = .transferring(sent: sent, total: total, currentFile: currentFile)
    }

    func transportDidComplete(fileCount: Int, totalBytes: Int64) {
        state = .completed(fileCount: fileCount, totalBytes: totalBytes)
    }

    func transportDidFail(error: String) {
        state = .error(error)
    }
}
