import Foundation

public enum AnswerStatus: String, Sendable, Equatable {
    case supported = "CO_CAN_CU"
    case insufficientEvidence = "KHONG_DU_CAN_CU"
    case conflict = "MAU_THUAN"
}

public struct AnswerItem: Sendable, Equatable {
    public var text: String
    public var citations: [String]   // ["E1", "E3"]

    public init(text: String, citations: [String]) {
        self.text = text
        self.citations = citations
    }
}

public struct StructuredAnswer: Sendable, Equatable {
    public var status: AnswerStatus?
    public var summary: String = ""
    public var summaryCitations: [String] = []
    public var immediateActions: [AnswerItem] = []
    public var doNot: [AnswerItem] = []
    public var escalation: AnswerItem?

    public init() {}
}

/// Streaming parser for the line format in `PromptBuilder.systemContract`.
///
/// Why lines instead of JSON (spec v0.2 §11.1): a line format renders progressively while tokens stream,
/// survives a truncated generation, and costs fewer tokens. Only complete lines are committed,
/// so a half-written citation never reaches the UI.
public struct AnswerParser: Sendable {
    enum Section { case none, actions, doNot }

    private var buffer = ""
    private var section = Section.none
    public private(set) var answer = StructuredAnswer()

    public init() {}

    /// Feed a streamed token delta. Returns the answer with all complete lines applied.
    @discardableResult
    public mutating func feed(_ delta: String) -> StructuredAnswer {
        buffer += delta
        while let nl = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<nl])
            buffer.removeSubrange(...nl)
            apply(line)
        }
        return answer
    }

    /// Call once generation ends to flush the last line.
    @discardableResult
    public mutating func finish() -> StructuredAnswer {
        if !buffer.isEmpty { apply(buffer); buffer = "" }
        return answer
    }

    private mutating func apply(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }

        if let v = value(line, "TRANG_THAI") {
            answer.status = AnswerStatus(rawValue: v.split(separator: " ").first.map(String.init) ?? v)
            section = .none
        } else if let v = value(line, "TOM_TAT") {
            let s = Self.item(v)
            answer.summary = s.text
            answer.summaryCitations = s.citations
            section = .none
        } else if line.hasPrefix("LAM_NGAY") {
            section = .actions
        } else if line.hasPrefix("KHONG_DUOC") {
            section = .doNot
        } else if let v = value(line, "CAP_CUU") {
            answer.escalation = Self.item(v)
            section = .none
        } else if line.hasPrefix("-") || line.hasPrefix("•") {
            let item = Self.item(String(line.dropFirst()))
            switch section {
            case .actions: answer.immediateActions.append(item)
            case .doNot: answer.doNot.append(item)
            case .none: break
            }
        }
    }

    private func value(_ line: String, _ key: String) -> String? {
        guard line.hasPrefix(key + ":") else { return nil }
        return line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
    }

    static let citationPattern = try! NSRegularExpression(pattern: "\\[(E\\d+)\\]")

    /// Splits "Bất động chi bị cắn [E1][E3]" → text + ["E1", "E3"].
    static func item(_ raw: String) -> AnswerItem {
        let ns = raw as NSString
        let matches = citationPattern.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        let citations = matches.map { ns.substring(with: $0.range(at: 1)) }
        let text = citationPattern
            .stringByReplacingMatches(in: raw, range: NSRange(location: 0, length: ns.length), withTemplate: "")
            .trimmingCharacters(in: .whitespaces)
        return AnswerItem(text: text, citations: citations)
    }
}
