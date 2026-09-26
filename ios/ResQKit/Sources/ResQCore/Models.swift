import Foundation

// MARK: - Knowledge metadata

public enum RiskLevel: Int, Sendable, Comparable, Codable {
    case normal = 0
    case critical = 1   // medical / poisoning / hypothermia...: strict grounding
    case emergency = 2  // life-threatening now: Emergency Card is shown before the LLM runs

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum TrustTier: String, Sendable, Codable {
    case a = "A"  // government / health authority / official standard
    case b = "B"  // major professional body, edited training material
    case c = "C"  // supplementary; never stands alone in a critical answer

    public var isTrusted: Bool { self != .c }
}

public enum ChunkType: String, Sendable, Codable {
    case procedure, immediateAction, warning, decisionRule, fact, checklist, reference
}

/// Metadata of a child chunk, as stored in the Knowledge Pack.
public struct ChunkMeta: Sendable, Equatable, Codable {
    public let chunkId: String
    public let parentId: String
    public let articleId: String
    public let category: String
    public let chunkType: ChunkType
    public let trust: TrustTier
    /// nil = applies everywhere.
    public let region: String?
    public let reviewExpired: Bool

    public init(chunkId: String, parentId: String, articleId: String, category: String,
                chunkType: ChunkType, trust: TrustTier, region: String? = nil, reviewExpired: Bool = false) {
        self.chunkId = chunkId
        self.parentId = parentId
        self.articleId = articleId
        self.category = category
        self.chunkType = chunkType
        self.trust = trust
        self.region = region
        self.reviewExpired = reviewExpired
    }
}

/// Parent context block: what actually goes into the prompt (retrieve child, inject parent).
public struct ParentBlock: Sendable, Equatable, Codable {
    public let parentId: String
    public let articleId: String
    public let sourceLabel: String   // short label shown in prompt and UI, e.g. "Bộ Y tế"
    public let headingPath: String   // "Sơ cứu › Rắn cắn › Bất động chi"
    public let text: String
    public let tokens: Int
    public let trust: TrustTier

    public init(parentId: String, articleId: String, sourceLabel: String, headingPath: String,
                text: String, tokens: Int, trust: TrustTier) {
        self.parentId = parentId
        self.articleId = articleId
        self.sourceLabel = sourceLabel
        self.headingPath = headingPath
        self.text = text
        self.tokens = tokens
        self.trust = trust
    }
}

/// Reviewed, static checklist. Rendered without the LLM.
public struct EmergencyCard: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let intent: String
    public let title: String
    public let steps: [String]
    public let doNot: [String]
    public let hotline: String?      // rendered from structured data, never generated
    public let sourceLabel: String
    public let reviewedAt: String

    public init(id: String, intent: String, title: String, steps: [String], doNot: [String],
                hotline: String?, sourceLabel: String, reviewedAt: String) {
        self.id = id
        self.intent = intent
        self.title = title
        self.steps = steps
        self.doNot = doNot
        self.hotline = hotline
        self.sourceLabel = sourceLabel
        self.reviewedAt = reviewedAt
    }
}

// MARK: - Routing

public struct Route: Sendable, Equatable {
    public var risk: RiskLevel
    public var emergencyIntent: String?
    public var category: String?
    /// Region stated by the user ("rừng", "biển", ...). Never inferred silently.
    public var region: String?

    public init(risk: RiskLevel, emergencyIntent: String? = nil, category: String? = nil, region: String? = nil) {
        self.risk = risk
        self.emergencyIntent = emergencyIntent
        self.category = category
        self.region = region
    }

    public var isCritical: Bool { risk >= .critical }
    public var topK: Int { isCritical ? 32 : 24 }
}

// MARK: - Retrieval results

public struct LexicalHit: Sendable, Equatable {
    public let chunkId: String
    /// Query matched a title or reviewed alias exactly (deterministic bonus after fusion).
    public let exactTitleOrAlias: Bool

    public init(chunkId: String, exactTitleOrAlias: Bool = false) {
        self.chunkId = chunkId
        self.exactTitleOrAlias = exactTitleOrAlias
    }
}

public struct ScoredCandidate: Sendable, Equatable {
    public let meta: ChunkMeta
    public let score: Double

    public init(meta: ChunkMeta, score: Double) {
        self.meta = meta
        self.score = score
    }
}

/// A parent block selected for the prompt. `label` is the short citation id the model sees ("E1").
public struct EvidenceBlock: Sendable, Equatable, Identifiable {
    public let label: String
    public let block: ParentBlock
    public let score: Double

    public init(label: String, block: ParentBlock, score: Double) {
        self.label = label
        self.block = block
        self.score = score
    }

    public var id: String { label }
}
