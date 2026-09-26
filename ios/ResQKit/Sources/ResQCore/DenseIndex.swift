import Foundation

/// Exact dense search over INT8 vectors with one Float scale per row.
///
/// Why INT8 + per-row scale instead of FP16 (spec v0.2):
/// - Half the size (30k × 384 → 11.5 MB), memory-mapped, zero parsing.
/// - Kotlin/JVM has no fast FP16 arithmetic; Int8 × Float is fast on both platforms.
/// - Recall loss vs FP16 must be measured by the ablation test, not assumed.
///
/// Pack layout: `vectors.bin` = count × dim Int8 (row-major), `scales.bin` = count Float32 (little endian),
/// row i ↔ ids[i]. Vectors are L2-normalized before quantization, so score ≈ cosine similarity.
public struct DenseIndex: Sendable {
    public let dim: Int
    public let ids: [String]
    let vectors: Data   // Data(contentsOf:options: .alwaysMapped) in production
    let scales: [Float]

    public init(dim: Int, ids: [String], vectors: Data, scales: [Float]) {
        precondition(vectors.count == ids.count * dim, "vectors.bin size mismatch")
        precondition(scales.count == ids.count, "scales.bin size mismatch")
        self.dim = dim
        self.ids = ids
        self.vectors = vectors
        self.scales = scales
    }

    /// Quantize already L2-normalized Float vectors (used by tests and the pack builder).
    public static func quantize(_ rows: [[Float]]) -> (data: Data, scales: [Float]) {
        var bytes: [Int8] = []
        var scales: [Float] = []
        for row in rows {
            let maxAbs = row.map(abs).max() ?? 0
            let scale = maxAbs > 0 ? maxAbs / 127 : 1
            scales.append(scale)
            bytes.append(contentsOf: row.map { Int8(max(-127, min(127, ($0 / scale).rounded()))) })
        }
        return (bytes.withUnsafeBufferPointer { Data(buffer: $0) }, scales)
    }

    /// Exact top-K by dot product. `allow` filters by row index (region/risk filters) before ranking.
    /// ~11.5M multiply-adds for 30k chunks: tens of ms in plain loops; use vDSP / NEON (NDK) if p95 > 60 ms.
    public func topK(_ query: [Float], k: Int, allow: ((Int) -> Bool)? = nil) -> [(id: String, score: Float)] {
        precondition(query.count == dim)
        var best: [(row: Int, score: Float)] = []
        best.reserveCapacity(k + 1)

        vectors.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let v = raw.bindMemory(to: Int8.self)
            for row in 0..<ids.count {
                if let allow, !allow(row) { continue }
                var acc: Float = 0
                let base = row * dim
                for j in 0..<dim { acc += query[j] * Float(v[base + j]) }
                let score = acc * scales[row]
                if best.count < k || score > best[best.count - 1].score {
                    // Insertion into a small sorted array; k ≤ 32 so this beats a heap.
                    let at = best.firstIndex(where: { score > $0.score }) ?? best.count
                    best.insert((row, score), at: at)
                    if best.count > k { best.removeLast() }
                }
            }
        }
        return best.map { (ids[$0.row], $0.score) }
    }
}
