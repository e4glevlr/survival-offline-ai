import Foundation

public struct NormalizedQuery: Sendable, Equatable {
    /// NFC text as typed. Used for display and for the LLM prompt.
    public let display: String
    /// Lowercased, accents kept. Matches the accent-preserving FTS column.
    public let lower: String
    /// Lowercased, accents removed, đ → d. Matches the folded FTS column (users often type without accents).
    public let folded: String
    /// Folded syllables with (accented) stopwords removed.
    public let terms: [String]
    /// Folded syllable bigrams ("ran can"). Vietnamese words are often 2 syllables; bigrams restore precision.
    public let bigrams: [String]
    /// Canonical terms from the reviewed alias map ("ep tim" → "cpr").
    public let aliasExpansions: [String]

    /// FTS5 MATCH expression for the folded columns.
    public var ftsMatch: String {
        let quoted = (bigrams + terms + aliasExpansions).map { "\"\($0)\"" }
        return quoted.joined(separator: " OR ")
    }
}

/// Deterministic Vietnamese normalizer. Must behave identically on iOS and Android:
/// Kotlin port = java.text.Normalizer NFD + drop \p{Mn} + replace đ/Đ.
public struct QueryNormalizer: Sendable {
    public let aliases: [String: [String]]   // folded phrase → canonical folded terms
    public let stopwords: Set<String>

    public init(aliases: [String: [String]] = [:], stopwords: Set<String> = QueryNormalizer.defaultStopwords) {
        self.aliases = aliases
        self.stopwords = stopwords
    }

    public func normalize(_ raw: String) -> NormalizedQuery {
        let display = raw.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = display.lowercased()
        let folded = Self.fold(lower)
        // Stopwords are matched on the accented form: folding first would make "lá" (leaf) collide with "là".
        let syllables = Self.tokenize(lower)
        let isStop = syllables.map { stopwords.contains($0) }
        let foldedSyllables = syllables.map(Self.fold)
        let terms = foldedSyllables.indices.filter { !isStop[$0] }.map { foldedSyllables[$0] }
        let bigrams = foldedSyllables.indices.dropLast()
            .filter { !(isStop[$0] && isStop[$0 + 1]) }
            .map { "\(foldedSyllables[$0]) \(foldedSyllables[$0 + 1])" }

        var expansions: [String] = []
        let padded = " " + foldedSyllables.joined(separator: " ") + " "
        for (phrase, canon) in aliases.sorted(by: { $0.key < $1.key }) where padded.contains(" \(phrase) ") {
            for term in canon where !expansions.contains(term) { expansions.append(term) }
        }

        return NormalizedQuery(display: display, lower: lower, folded: folded,
                               terms: Self.unique(terms), bigrams: Self.unique(bigrams),
                               aliasExpansions: expansions)
    }

    /// Removes combining marks and maps đ/Đ → d/D.
    /// Note: SQLite `unicode61 remove_diacritics 2` does NOT fold "đ" (it has no decomposition),
    /// so the pack builder must write the folded column with this same function.
    public static func fold(_ text: String) -> String {
        let scalars = text.decomposedStringWithCanonicalMapping.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            switch scalar.value {
            case 0x0300...0x036F: return nil
            case 0x0111: return "d"   // đ
            case 0x0110: return "D"   // Đ
            default: return scalar
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
    }

    static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    /// Accented, lowercase. Kept short on purpose: removing content words hurts recall more than noise does.
    public static let defaultStopwords: Set<String> = [
        "là", "thì", "mà", "và", "của", "có", "không", "được", "như", "thế", "nào", "làm", "sao",
        "gì", "tôi", "mình", "bạn", "này", "đó", "ở", "khi", "nếu", "để", "cho", "với", "một", "các", "những",
        "à", "ạ", "ơi", "nhé", "vậy", "rồi", "đang", "bị",
    ]
}
