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

        // Small models leak the format into items ("- KHONG_DUOC: Cho uống…", "- KHONG_HAM_LUONG_X"), echo the
        // prompt's rules ("- Tự tạo con số không có trong bằng chứng"), repeat items and file prohibitions under
        // LAM_NGAY ("- Không chà xát tay chân"). Tidy before anything is counted.
        var actions: [AnswerItem] = [], doNot: [AnswerItem] = [], seen: Set<String> = []
        for (item, fromDoNot) in raw.immediateActions.map({ ($0, false) }) + raw.doNot.map({ ($0, true) }) {
            let (label, text) = Self.splittingSectionLabel(item.text)
            if Self.isFormatToken(text) || Self.isMeta(text) { dropped += 1; continue }
            let tidy = AnswerItem(text: text, citations: item.citations)
            let isDoNot = fromDoNot || label == "KHONG_DUOC" || Self.isProhibition(text)
            // Compared as shown: "Không di chuyển trong đêm" moved from LAM_NGAY repeats KHONG_DUOC's "Di chuyển trong đêm".
            let shown = isDoNot ? Self.droppingLeadingNegation(tidy).text : text
            let key = (isDoNot ? "x " : "o ") + QueryNormalizer.fold(shown.lowercased())
                .trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            if !seen.insert(key).inserted { dropped += 1; continue }
            if isDoNot { doNot.append(tidy) } else { actions.append(tidy) }
        }

        var a = raw
        // The prompt calls the sources "bằng chứng"; the user knows them as the guide.
        a.summary = Self.redactPhoneNumbers(a.summary)
            .replacingOccurrences(of: "Bằng chứng", with: "Cẩm nang").replacingOccurrences(of: "bằng chứng", with: "cẩm nang")
        // Foraging: the model must never say a wild plant or mushroom is edible, not even when quoting a
        // source it disagrees with ("một nguồn nói nấm này ăn được…"). Enforced here, not trusted to the prompt.
        if route.category == "foraging" && Self.assertsEdible(a.summary) {
            a.summary = Self.forageSafeSummary
            a.summaryCitations = []
        }
        a.summaryCitations = raw.summaryCitations.filter(valid.contains)
        a.immediateActions = actions.compactMap(clean)
            .filter { route.category != "foraging" || !Self.assertsEdible($0.text) }
        a.doNot = doNot.compactMap(clean).map(Self.droppingLeadingNegation)
        // "CAP_CUU: TRANG_THAI: KHONG_DU_CAN_CU": nothing to say, so the model wrote a status.
        a.escalation = raw.escalation.flatMap(clean).flatMap {
            let text = Self.splittingSectionLabel($0.text).1
            return Self.isFiller(text) || Self.isFormatToken(text) || Self.isMeta(text) ? nil : $0
        }

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

    /// "KHONG_DUOC: Cho uống…" → ("KHONG_DUOC", "Cho uống…").
    static func splittingSectionLabel(_ text: String) -> (String?, String) {
        for label in ["TRANG_THAI", "TOM_TAT", "LAM_NGAY", "KHONG_DUOC", "CAP_CUU"] where text.hasPrefix(label + ":") {
            return (label, text.dropFirst(label.count + 1).trimmingCharacters(in: .whitespaces))
        }
        return (nil, text)
    }

    /// "KHONG_HAM_LUONG_PARACETAMOL", "KHONG_DU_CAN_CU (về việc…)": an identifier or a status, not a sentence.
    static func isFormatToken(_ text: String) -> Bool {
        (text.contains("_") && !text.contains(" ")) || ["CO_CAN_CU", "KHONG_DU_CAN_CU", "MAU_THUAN"].contains(where: text.hasPrefix)
    }

    /// An item that tells the user what not to do. "Không có nẹp thì…" is a condition, not a prohibition.
    /// Only the leads `droppingLeadingNegation` strips: "Tránh nấm" moved under "Không được" would mean the opposite.
    /// Matched with diacritics: folded, "dùng" would read as "đừng".
    static func isProhibition(_ text: String) -> Bool {
        let t = text.lowercased()
        guard ["không ", "đừng ", "tuyệt đối không "].contains(where: t.hasPrefix) else { return false }
        return !["không có ", "không thể ", "không còn ", "không thấy ", "không tìm "].contains(where: t.hasPrefix)
            && !t.contains(" thì ")
    }

    /// Talk about the evidence or the prompt, not advice: "Không có thông tin về thời điểm cần gọi cứu hộ",
    /// "Tự tạo con số không có trong bằng chứng [Quy tắc]".
    static func isMeta(_ text: String) -> Bool {
        let t = QueryNormalizer.fold(text.lowercased())
        return ["bang chung", "quy tac", "khong co thong tin", "co thong tin cu the", "khong de cap"].contains(where: t.contains)
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
