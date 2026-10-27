import Foundation

/// Stage A routing: rules only, no LLM call. Runs in < 1 ms.
/// Rules ship inside the Knowledge Pack (reviewed with the content), this list is the MVP default.
public struct RiskRouter: Sendable {
    public struct Rule: Sendable {
        public let intent: String
        public let risk: RiskLevel
        public let category: String
        /// Accented, lowercase phrases; any match triggers the rule.
        public let phrases: [String]
        /// Matched only when the user typed accents: folded, "hóc" is "học", "ngất" is "ngạt"/"ngắt",
        /// "còn thở" is "con thỏ", "xỉu" is "xíu".
        public let accentedPhrases: [String]

        public init(intent: String, risk: RiskLevel, category: String, phrases: [String], accentedPhrases: [String] = []) {
            self.intent = intent
            self.risk = risk
            self.category = category
            self.phrases = phrases
            self.accentedPhrases = accentedPhrases
        }
    }

    public let rules: [Rule]
    public let regionPhrases: [String: String]   // accented phrase → region code

    public init(rules: [Rule] = RiskRouter.defaultRules, regionPhrases: [String: String] = RiskRouter.defaultRegions) {
        self.rules = rules
        self.regionPhrases = regionPhrases
    }

    public func route(_ query: NormalizedQuery, statedRegion: String? = nil) -> Route {
        // Typed with accents → match accented (so "nằm" never hits "nấm", "dao" never hits "đảo").
        // Typed without any accent → match folded forms.
        let accented = query.lower != query.folded
        let source = accented ? query.lower : query.folded
        let text = " " + QueryNormalizer.tokenize(source).joined(separator: " ") + " "
        func matches(_ phrase: String) -> Bool {
            text.contains(" \(accented ? phrase : QueryNormalizer.fold(phrase)) ")
        }

        var best: Rule?
        for rule in rules where rule.phrases.contains(where: matches) || (accented && rule.accentedPhrases.contains(where: matches)) {
            // Highest risk wins; ties keep the first rule (rule order = priority).
            if best == nil || rule.risk > best!.risk { best = rule }
        }
        let region = statedRegion ?? regionPhrases
            .sorted(by: { $0.key < $1.key })
            .first(where: { matches($0.key) })?.value

        guard let rule = best else { return Route(risk: .normal, region: region) }
        return Route(risk: rule.risk,
                     emergencyIntent: rule.risk == .emergency ? rule.intent : nil,
                     category: rule.category,
                     region: region)
    }

    public static let defaultRules: [Rule] = [
        Rule(intent: "severe_bleeding", risk: .emergency, category: "first_aid",
             phrases: ["chảy máu nhiều", "máu chảy nhiều", "chảy nhiều máu", "máu chảy không cầm", "máu phun",
                       "vết cắt sâu", "đứt động mạch", "mất nhiều máu"]),
        // Before "unconscious": "bé hóc hạt nhãn không thở được" needs the choking card, not CPR.
        Rule(intent: "choking", risk: .emergency, category: "first_aid",
             phrases: ["hóc dị vật", "nghẹn thở", "mắc nghẹn", "bị nghẹn", "bị hóc", "hóc xương", "hóc hạt", "hóc kẹo"],
             accentedPhrases: ["hóc", "nghẹn"]),
        Rule(intent: "unconscious", risk: .emergency, category: "first_aid",
             phrases: ["bất tỉnh", "ngừng thở", "không thở", "ko thở", "ngất xỉu", "bị ngất", "ngất đi", "bị xỉu",
                       "không tỉnh", "ép tim", "cpr"],
             // Not bare "ngất": "sắp ngất" in heat stroke is not a CPR case.
             accentedPhrases: ["ngất nằm", "ngất rồi", "ngất lịm", "đang ngất", "xỉu", "còn thở"]),
        Rule(intent: "snake_bite", risk: .emergency, category: "first_aid",
             phrases: ["rắn cắn", "rắn độc", "cắn rắn"]),
        Rule(intent: "drowning", risk: .emergency, category: "first_aid",
             phrases: ["đuối nước", "chết đuối", "sặc nước"]),
        // After the rules above so "rắn cắn, khó thở" still opens the snake card.
        Rule(intent: "anaphylaxis", risk: .emergency, category: "first_aid",
             phrases: ["sốc phản vệ", "khó thở", "thở khò khè", "khò khè", "thở rít",
                       "sưng môi", "sưng lưỡi", "sưng họng", "sưng mặt"]),
        // Never bare "bỏng": unaccented "bong" is also "bóng" (shadow, as in "bóng que"). Same for bare
        // "phản vệ" above: unaccented "phan ve" is also "phần về".
        Rule(intent: "burn", risk: .emergency, category: "first_aid",
             phrases: ["bị bỏng", "vết bỏng", "bỏng nước", "bỏng lửa", "bỏng nặng", "bỏng rộng", "bỏng hóa chất", "bỏng điện", "phỏng nước"]),
        Rule(intent: "hypothermia", risk: .emergency, category: "first_aid",
             phrases: ["hạ thân nhiệt", "run cầm cập", "lạnh cóng người"]),
        Rule(intent: "heat_stroke", risk: .emergency, category: "first_aid",
             phrases: ["sốc nhiệt", "say nắng", "cảm nắng", "trúng nắng"]),
        Rule(intent: "poisoning", risk: .critical, category: "foraging",
             phrases: ["ngộ độc", "ăn nhầm", "trúng độc", "nấm độc", "lá độc", "quả độc"]),
        Rule(intent: "fracture", risk: .critical, category: "first_aid",
             phrases: ["gãy xương", "nẹp xương", "trật khớp"]),
        Rule(intent: "edibility", risk: .critical, category: "foraging",
             phrases: ["ăn được", "có độc", "nấm"]),
        Rule(intent: "water_safety", risk: .critical, category: "water",
             phrases: ["uống được", "lọc nước", "nước suối", "nước bẩn"]),
    ]

    public static let defaultRegions: [String: String] = [
        "rừng": "forest", "núi": "mountain", "biển": "coast", "đảo": "coast",
        "hang động": "cave", "suối": "forest", "sa mạc": "desert", "thành phố": "urban",
    ]
}
