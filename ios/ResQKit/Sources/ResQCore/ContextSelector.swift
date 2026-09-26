import Foundation

public struct ContextBudget: Sendable, Equatable {
    public var evidenceTokens: Int
    public var maxBlocks: Int
    public var maxBlocksPerArticle: Int

    public init(evidenceTokens: Int, maxBlocks: Int, maxBlocksPerArticle: Int = 2) {
        self.evidenceTokens = evidenceTokens
        self.maxBlocks = maxBlocks
        self.maxBlocksPerArticle = maxBlocksPerArticle
    }

    /// Smaller than spec v0.2 (1.5–2.4K): prefill time is the dominant part of TTFT on phones.
    public static func `default`(for route: Route) -> ContextBudget {
        route.isCritical ? ContextBudget(evidenceTokens: 1_100, maxBlocks: 4)
                         : ContextBudget(evidenceTokens: 1_300, maxBlocks: 4)
    }
}

/// Turns fused child candidates into a small set of parent blocks for the prompt.
public struct ContextSelector: Sendable {
    public var nearDuplicateThreshold: Double = 0.8

    public init() {}

    public func pack(_ candidates: [ScoredCandidate], parents: [String: ParentBlock],
                     route: Route, budget: ContextBudget) -> [EvidenceBlock] {
        // 1. Best score per parent, keep fused order.
        var seenParents = Set<String>()
        var perParent: [(ParentBlock, ScoredCandidate)] = []
        for c in candidates where seenParents.insert(c.meta.parentId).inserted {
            if let p = parents[c.meta.parentId] { perParent.append((p, c)) }
        }

        var chosen: [(ParentBlock, Double)] = []
        var used = 0
        var perArticle: [String: Int] = [:]

        func fits(_ p: ParentBlock) -> Bool {
            chosen.count < budget.maxBlocks
                && used + p.tokens <= budget.evidenceTokens
                && perArticle[p.articleId, default: 0] < budget.maxBlocksPerArticle
                && !chosen.contains(where: { Self.similarity($0.0.text, p.text) >= nearDuplicateThreshold })
        }
        func take(_ p: ParentBlock, _ score: Double) {
            chosen.append((p, score))
            used += p.tokens
            perArticle[p.articleId, default: 0] += 1
        }

        // 2. Critical: reserve a slot for the best warning/contraindication.
        if route.isCritical, let w = perParent.first(where: { $0.1.meta.chunkType == .warning }), fits(w.0) {
            take(w.0, w.1.score)
        }

        // 3. Fill by score. On critical routes trusted (A/B) blocks go first; Tier C only fills leftover
        //    slots and never stands alone.
        let passes: [(ParentBlock) -> Bool] = route.isCritical
            ? [{ $0.trust.isTrusted }, { !$0.trust.isTrusted }]
            : [{ _ in true }]
        for (pass, accepts) in passes.enumerated() {
            if pass == 1 && !chosen.contains(where: { $0.0.trust.isTrusted }) { break }
            for (p, c) in perParent where accepts(p) && !chosen.contains(where: { $0.0.parentId == p.parentId }) {
                if fits(p) { take(p, c.score) }
            }
        }

        // 4. Present in score order and assign short citation labels E1…En.
        return chosen
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.parentId < $1.0.parentId }
            .enumerated()
            .map { EvidenceBlock(label: "E\($0.offset + 1)", block: $0.element.0, score: $0.element.1) }
    }

    /// Jaccard similarity over folded syllable trigrams. Cheap and identical on both platforms.
    static func similarity(_ a: String, _ b: String) -> Double {
        let sa = shingles(a), sb = shingles(b)
        guard !sa.isEmpty || !sb.isEmpty else { return 1 }
        return Double(sa.intersection(sb).count) / Double(sa.union(sb).count)
    }

    static func shingles(_ text: String) -> Set<String> {
        let t = QueryNormalizer.tokenize(QueryNormalizer.fold(text.lowercased()))
        guard t.count >= 3 else { return Set(t) }
        return Set((0...(t.count - 3)).map { t[$0..<($0 + 3)].joined(separator: " ") })
    }
}
