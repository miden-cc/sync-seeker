import Foundation

protocol TransportDelegate: AnyObject {
    func transportDidUpdateProgress(_ progress: Double, currentFile: String)
    func transportDidComplete(fileCount: Int, totalBytes: Int64)
    func transportDidFail(error: String)
}

protocol TransportProtocol {
    var delegate: TransportDelegate? { get set }
    func transferFiles(_ entries: [ManifestEntry], from source: URL) throws
    func cancel()
}
