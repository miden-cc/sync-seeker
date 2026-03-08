import Foundation
@testable import SyncSeeker

final class MockTransport: TransportProtocol {
    weak var delegate: TransportDelegate?

    var transferCalled = false
    var cancelCalled = false
    var lastEntries: [ManifestEntry]?
    var lastSourceURL: URL?
    var transferError: Error?

    func transferFiles(_ entries: [ManifestEntry], from source: URL) throws {
        transferCalled = true
        lastEntries = entries
        lastSourceURL = source
        if let error = transferError {
            throw error
        }
    }

    func cancel() {
        cancelCalled = true
    }

    // MARK: - Simulation

    func simulateProgress(sent: Int, total: Int, file: String) {
        delegate?.transportDidUpdateProgress(sent: sent, total: total, currentFile: file)
    }

    func simulateComplete(fileCount: Int, totalBytes: Int64) {
        delegate?.transportDidComplete(fileCount: fileCount, totalBytes: totalBytes)
    }

    func simulateError(_ message: String) {
        delegate?.transportDidFail(error: message)
    }
}
