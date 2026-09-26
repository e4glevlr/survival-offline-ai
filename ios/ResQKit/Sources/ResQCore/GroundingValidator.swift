import Foundation

public struct ValidatedAnswer: Sendable, Equatable {
    public let answer: StructuredAnswer
    public let status: AnswerStatus
    /// Items removed because they had no valid citation (debug / eval only).
    public let droppedItems: Int
}

/// Deterministic grounding checks. No NLI model: the output format + content structure do the heavy lifting.
public struct GroundingValidator: Sendable {
    public init() {}

    public func validate(_ raw: StructuredAnswer, evidence: [EvidenceBlock], route: Route) -> ValidatedAnswer {
        let valid = Set(evidence.map(\.label))
        var dropped = 0

        func clean(_ item: AnswerItem) -> AnswerItem? {
            let cites = item.citations.filter(valid.contains)          // invented labels are removed
            let text = Self.redactPhoneNumbers(item.text)
            if route.isCritical && cites.isEmpty { dropped += 1; return nil }  // no evidence → no critical action
            return AnswerItem(text: text, citations: cites)
        }

        var a = raw
        a.summary = Self.redactPhoneNumbers(a.summary)
        a.summaryCitations = raw.summaryCitations.filter(valid.contains)
        a.immediateActions = raw.immediateActions.compactMap(clean)
        a.doNot = raw.doNot.compactMap(clean)
        a.escalation = raw.escalation.flatMap(clean)

        var status = raw.status ?? .insufficientEvidence
        if evidence.isEmpty { status = .insufficientEvidence }
        if status == .supported && route.isCritical && a.immediateActions.isEmpty && a.doNot.isEmpty {
            status = .insufficientEvidence
        }
        return ValidatedAnswer(answer: a, status: status, droppedItems: dropped)
    }

    /// Hotlines are rendered by the UI from structured data (EmergencyCard.hotline), never from generation.
    static let phonePattern = try! NSRegularExpression(
        pattern: "(?<![\\d.,])(?:\\+?84|0)\\d{8,10}(?!\\d)|(?<![\\d.,])11[2-5](?![\\d.,°])")

    static func redactPhoneNumbers(_ text: String) -> String {
        let ns = text as NSString
        return phonePattern.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: ns.length), withTemplate: "[số khẩn cấp: xem thẻ SOS]")
    }
}

/// Retrieval-side confidence (spec §16). Decides whether the LLM runs at all.
public struct ConfidenceGate: Sendable {
    /// Calibrate on the golden set. RRF scale: one channel at rank 1 ≈ 0.0164.
    public var minTopScore: Double = 0.02

    public init() {}

    public func isSupported(_ evidence: [EvidenceBlock], route: Route) -> Bool {
        guard let top = evidence.first, top.score >= minTopScore else { return false }
        if route.isCritical && !evidence.contains(where: { $0.block.trust.isTrusted }) { return false }
        return true
    }
}
