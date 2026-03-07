import Foundation
import Accelerate

/// ベクター演算ユーティリティ（Accelerate フレームワーク使用）。
enum VectorMath {

    /// コサイン類似度: 1.0 = 同一方向, 0.0 = 直交, -1.0 = 逆方向
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        vDSP_dotprD(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_dotprD(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotprD(b, 1, b, 1, &normB, vDSP_Length(b.count))
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return min(max(dot / denom, -1.0), 1.0)  // clamp for float precision
    }

    /// コサイン距離: 0 = 同一方向, 2 = 逆方向
    static func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        1.0 - cosineSimilarity(a, b)
    }
}
