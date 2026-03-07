import Foundation

public enum TransferState: Equatable {
    case idle
    case scanning
    case comparing
    case transferring(progress: Double, currentFile: String)
    case completed(fileCount: Int, totalBytes: Int64)
    case error(String)

    public static func == (lhs: TransferState, rhs: TransferState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.scanning, .scanning): return true
        case (.comparing, .comparing): return true
        case (.transferring(let p1, let f1), .transferring(let p2, let f2)):
            return p1 == p2 && f1 == f2
        case (.completed(let c1, let b1), .completed(let c2, let b2)):
            return c1 == c2 && b1 == b2
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
