import Foundation

/// One model installed per device (never 4B + 2B side by side: storage, and swapping costs a reload).
public enum ModelTier: String, Sendable, Codable, CaseIterable {
    case large      // Gemma 4 E4B (or the bake-off winner of the 4B class)
    case standard   // Gemma 4 E2B (or the 2B-class winner). Default.
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

    /// Decided once, at model download time. Thresholds are starting points for the device benchmark.
    /// The OS reports less than the marketed RAM (a "12 GB" Android phone reports ~10.4–11 GiB,
    /// an "8 GB" one ~7–7.5 GiB), so thresholds sit below the class boundaries.
    public func recommendedTier(for d: DeviceSnapshot) -> ModelTier {
        switch d.physicalMemoryBytes {
        case (9 * Self.gib + Self.gib / 2)...: return .large       // 12 GB class
        case (6 * Self.gib + Self.gib / 2)...: return .standard    // 8 GB class (iPhone 15 Pro)
        default: return .searchOnly                                  // 6 GB class: enable E2B only after benchmark
        }
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
