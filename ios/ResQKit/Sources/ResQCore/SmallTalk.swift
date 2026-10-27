import Foundation

/// "chào bạn", "cảm ơn nhé": answered with a short line instead of retrieval and a "not enough evidence"
/// warning. Only when every word is greeting/thanks filler, so "chào bạn, tôi bị rắn cắn" still goes through.
public enum SmallTalk: Sendable {
    static let greetings: Set<String> = ["chao", "hello", "hi", "helo", "alo", "hey"]
    static let thanks: Set<String> = ["thanks", "thank", "tks", "thx"]
    static let filler: Set<String> = ["xin", "ban", "oi", "nhe", "nha", "a", "nhieu", "rat", "minh", "resq", "em", "anh",
                                      "chi", "ad", "you", "ok", "oke", "nghe", "cam", "on", "the"]

    public static func reason(for query: NormalizedQuery) -> NoAnswerReason? {
        let words = query.folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard !words.isEmpty, words.count <= 6,
              words.allSatisfy({ greetings.contains($0) || thanks.contains($0) || filler.contains($0) }) else { return nil }
        let joined = " " + words.joined(separator: " ") + " "
        if joined.contains(" cam on ") || words.contains(where: thanks.contains) { return .thanks }
        if words.contains(where: greetings.contains) { return .greeting }
        return nil
    }
}
