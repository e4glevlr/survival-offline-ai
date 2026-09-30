import Foundation

/// One model installed per device (never 4B + 2B side by side: storage, and swapping costs a reload).
public enum ModelTier: String, Sendable, Codable, CaseIterable {
    case large      // Gemma 4 E4B on LiteRT-LM. Default: won the bake-off (bench/, docs/03).
    case standard   // Gemma 4 E2B. Not recommended until an E2B build passes the bench gate (≥ 80% pass).
    case searchOnly // no LLM: Search + Emergency Cards + Guides still fully work
}

public enum ThermalLevel: Int, Sendable, Comparable {
    case nominal, fair, serious, critical
    public static func < (a: ThermalLevel, b: ThermalLevel) -> Bool { a.rawValue < b.rawValue }
}

/// Filled by the platform layer (ProcessInfo / UIDevice on iOS, ActivityManager / PowerManager on Android).
public struct DeviceSnapshot: Sendable, Equatable {
    public var physicalMemoryBytes: UInt64
    public var thermal: ThermalLevel
    public var batteryLevel: Double   // 0…1
    public var isCharging: Bool
    public var lowPowerMode: Bool

    public init(physicalMemoryBytes: UInt64, thermal: ThermalLevel = .nominal, batteryLevel: Double = 1,
                isCharging: Bool = false, lowPowerMode: Bool = false) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.thermal = thermal
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.lowPowerMode = lowPowerMode
    }
}

/// Measured on the phone right after the model file is downloaded: a short prefill + decode run (~10 s).
/// RAM says whether the model fits; only a measurement says whether it answers in time.
/// Example (bench, docs/03 §10): OPPO CPH2637 (Dimensity 6300, 8 GB) runs E4B at 20 / 2.9 tok/s.
public struct ModelSpeed: Sendable, Equatable {
    public var prefillTokensPerSecond: Double
    public var decodeTokensPerSecond: Double

    public init(prefillTokensPerSecond: Double, decodeTokensPerSecond: Double) {
        self.prefillTokensPerSecond = prefillTokensPerSecond
        self.decodeTokensPerSecond = decodeTokensPerSecond
    }

    /// Typical prompt (system contract + ~1.1K evidence budget, bench median 749 tokens).
    static let promptTokens = 750.0
    /// RG-13: first token p95 ≤ 3 s. The first action line (~40 tokens later) should follow within ~5 s.
    static let maxFirstTokenSeconds = 3.0
    static let minDecodeTokensPerSecond = 8.0

    public var meetsLatencyBudget: Bool {
        Self.promptTokens / prefillTokensPerSecond <= Self.maxFirstTokenSeconds
            && decodeTokensPerSecond >= Self.minDecodeTokensPerSecond
    }
}

public struct GenerationPlan: Sendable, Equatable {
    public var llmEnabled: Bool
    public var maxOutputTokens: Int
    public var budget: ContextBudget
    /// Shown to the user when the plan is degraded, e.g. "Pin yếu: chỉ hiển thị thẻ và cẩm nang".
    public var notice: String?
}

public struct DevicePolicy: Sendable {
    public init() {}

    static let gib: UInt64 = 1 << 30

    /// Decided once, at model download time. The OS reports less than the marketed RAM
    /// (an "8 GB" phone reports ~7–7.5 GiB), so the threshold sits below the class boundary.
    /// E2B scored 33–59% on the bench and put dangerous advice in LAM_NGAY on a real phone,
    /// so there is no E2B tier: a phone that cannot run E4B in time gets search + Emergency Cards.
    /// `measured` is nil only until the post-download calibration has run.
    public func recommendedTier(for d: DeviceSnapshot, measured: ModelSpeed? = nil) -> ModelTier {
        guard d.physicalMemoryBytes >= 6 * Self.gib + Self.gib / 2 else { return .searchOnly }
        guard let measured else { return .large }
        return measured.meetsLatencyBudget ? .large : .searchOnly
    }

    /// Decided per request. Energy saving = less work per answer, not a model swap.
    public func plan(installed: ModelTier, device d: DeviceSnapshot, route: Route) -> GenerationPlan {
        var budget = ContextBudget.default(for: route)
        let output = route.isCritical ? 450 : 600

        if installed == .searchOnly {
            return GenerationPlan(llmEnabled: false, maxOutputTokens: 0, budget: budget, notice: nil)
        }
        if d.thermal == .critical || (d.batteryLevel < 0.10 && !d.isCharging) {
            return GenerationPlan(llmEnabled: false, maxOutputTokens: 0, budget: budget,
                                  notice: "Tiết kiệm pin tối đa: chỉ hiển thị thẻ khẩn cấp và cẩm nang.")
        }
        if d.thermal >= .serious || d.lowPowerMode || (d.batteryLevel < 0.20 && !d.isCharging) {
            budget.evidenceTokens = budget.evidenceTokens * 7 / 10
            budget.maxBlocks = 3
            return GenerationPlan(llmEnabled: true, maxOutputTokens: 250, budget: budget,
                                  notice: "Chế độ tiết kiệm: câu trả lời ngắn hơn.")
        }
        return GenerationPlan(llmEnabled: true, maxOutputTokens: output, budget: budget, notice: nil)
    }
}
