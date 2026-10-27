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
        // Foraging: the model must never say a wild plant or mushroom is edible, not even when quoting a
        // source it disagrees with ("một nguồn nói nấm này ăn được…"). Enforced here, not trusted to the prompt.
        if route.category == "foraging" && Self.assertsEdible(a.summary) {
            a.summary = Self.forageSafeSummary
            a.summaryCitations = []
        }
        a.summaryCitations = raw.summaryCitations.filter(valid.contains)
        a.immediateActions = raw.immediateActions.compactMap(clean)
            .filter { route.category != "foraging" || !Self.assertsEdible($0.text) }
        a.doNot = raw.doNot.compactMap(clean).map(Self.droppingLeadingNegation)
        a.escalation = raw.escalation.flatMap(clean).flatMap { Self.isFiller($0.text) ? nil : $0 }

        var status = raw.status ?? .insufficientEvidence
        // Policy B (docs/03): the model often says KHONG_DU_CAN_CU when only part of the question is out of
        // scope ("tell a joke, then how to light a fire") yet still answers the rest with cited items.
        // Two cited items, at least one of them a step.
        let steps = a.immediateActions.filter { !$0.citations.isEmpty }.count
        let cited = steps + a.doNot.filter { !$0.citations.isEmpty }.count
        if status == .insufficientEvidence && raw.status != nil && steps >= 1 && cited >= 2 { status = .supported }
        if evidence.isEmpty { status = .insufficientEvidence }
        if status == .supported && route.isCritical && a.immediateActions.isEmpty && a.doNot.isEmpty {
            status = .insufficientEvidence
        }
        return ValidatedAnswer(answer: a, status: status, droppedItems: dropped)
    }

    static let forageSafeSummary = "Không ăn nấm, cây hái ngoài tự nhiên khi chưa có người có chuyên môn xác định."
    static let edible = try! NSRegularExpression(pattern: "\\b(an|uong) duoc\\b|\\bkhong doc\\b|\\bvo hai\\b")
    static let negation = try! NSRegularExpression(pattern: "\\b(khong|chua|dung|chang|tranh|cam)\\b")

    /// "ăn được" / "không độc" / "vô hại" not negated earlier in the same clause.
    static func assertsEdible(_ text: String) -> Bool {
        let t = QueryNormalizer.fold(text.lowercased()) as NSString
        for m in edible.matches(in: t as String, range: NSRange(location: 0, length: t.length)) {
            let head = t.substring(to: m.range.location)
            let clauseStart = head.lastIndex(where: { ".,;:!?".contains($0) }).map { head.index(after: $0) } ?? head.startIndex
            let clause = String(head[clauseStart...])
            // "không độc" is itself the claim, so only look before it for "ăn được"-style matches.
            let claim = t.substring(with: m.range)
            if claim == "khong doc" { return true }
            if negation.firstMatch(in: clause, range: NSRange(location: 0, length: (clause as NSString).length)) == nil { return true }
        }
        return false
    }

    /// The UI heads this list "Không được", so "Không đập ong" would read "Không được: Không đập ong".
    static func droppingLeadingNegation(_ item: AnswerItem) -> AnswerItem {
        let lower = item.text.lowercased()
        guard let lead = ["không được ", "không nên ", "tuyệt đối không ", "đừng ", "không "].first(where: lower.hasPrefix)
        else { return item }
        let rest = item.text.dropFirst(lead.count)
        guard let first = rest.first else { return item }
        return AnswerItem(text: first.uppercased() + rest.dropFirst(), citations: item.citations)
    }

    /// "CAP_CUU: Không đề cập [E1]": the model filling a slot it has nothing for.
    static func isFiller(_ text: String) -> Bool {
        let t = QueryNormalizer.fold(text.lowercased()).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return t.isEmpty || ["khong de cap", "khong co", "khong ap dung", "khong", "n/a", "khong co thong tin", "khong can"].contains(t)
            || t.hasPrefix("khong de cap") || t.hasPrefix("bang chung khong de cap")
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
