import Foundation

/// All weights are starting points; tune them with the golden query set, never with demo queries.
public struct FusionConfig: Sendable {
    public var rrfK: Double = 60
    public var lexicalWeight: Double = 1.0
    public var denseWeight: Double = 1.0
    /// ≈ one extra rank-1 channel (1/61 ≈ 0.0164).
    public var exactTitleAliasBonus: Double = 0.015
    public var sameCategoryBonus: Double = 0.002
    public var regionMatchBonus: Double = 0.004
    public var trustedOnCriticalBonus: Double = 0.004
    public var warningOnCriticalBonus: Double = 0.003

    public init() {}
}

/// Reciprocal Rank Fusion of the lexical (FTS5/BM25) and dense (embedding) channels
/// + deterministic metadata boosts + policy filters. No neural reranker.
public struct HybridFuser: Sendable {
    public let config: FusionConfig

    public init(config: FusionConfig = FusionConfig()) {
        self.config = config
    }

    /// - Parameters:
    ///   - lexical: FTS5 hits in rank order (best first).
    ///   - dense: chunk ids in rank order (best first).
    ///   - meta: metadata for every id that appears in either list.
    public func fuse(lexical: [LexicalHit], dense: [String], meta: [String: ChunkMeta], route: Route) -> [ScoredCandidate] {
        var score: [String: Double] = [:]
        var exact = Set<String>()

        for (i, hit) in lexical.enumerated() {
            score[hit.chunkId, default: 0] += config.lexicalWeight / (config.rrfK + Double(i + 1))
            if hit.exactTitleOrAlias { exact.insert(hit.chunkId) }
        }
        for (i, id) in dense.enumerated() {
            score[id, default: 0] += config.denseWeight / (config.rrfK + Double(i + 1))
        }

        var out: [ScoredCandidate] = []
        for (id, base) in score {
            guard let m = meta[id], allowed(m, route: route) else { continue }
            var s = base
            if exact.contains(id) { s += config.exactTitleAliasBonus }
            if let c = route.category, c == m.category { s += config.sameCategoryBonus }
            if let r = route.region, r == m.region { s += config.regionMatchBonus }
            if route.isCritical && m.trust.isTrusted { s += config.trustedOnCriticalBonus }
            if route.isCritical && m.chunkType == .warning { s += config.warningOnCriticalBonus }
            out.append(ScoredCandidate(meta: m, score: s))
        }
        // Tie-break on id so iOS and Android return the exact same order.
        return out.sorted { (a: ScoredCandidate, b: ScoredCandidate) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.meta.chunkId < b.meta.chunkId
        }
    }

    func allowed(_ m: ChunkMeta, route: Route) -> Bool {
        // Region-specific content for another region never enters the context.
        if let region = m.region, let wanted = route.region, region != wanted { return false }
        // Expired review: fine for general reading, never for a critical answer.
        if route.isCritical && m.reviewExpired { return false }
        return true
    }
}
