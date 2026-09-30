import SwiftUI
import Observation

/// Design tokens. Same names as the CSS variables in design/resq_prototype.html
/// and as `ResQColors` in the Compose port.
public struct ResQPalette: Equatable, Sendable {
    public var bg, surface1, surface2, surface3: Color
    public var hair, hair2, highlight: Color
    public var text, text2, text3: Color
    public var accent, accentSoft: Color
    public var red, redDeep, redSoft: Color
    public var green, greenSoft, amber, amberSoft, blue, blueSoft: Color
    public var solid, onSolid: Color
    /// Emergency pass gradient (top → bottom) and its outline.
    public var passTop, passBottom, passLine: Color
    /// Night-vision: no glows, no colored shadows.
    public var glows: Bool
    public var scheme: ColorScheme

    public static let dark = ResQPalette(
        bg: Color(hex: 0x09090B), surface1: Color(hex: 0x111114), surface2: Color(hex: 0x17171B), surface3: Color(hex: 0x202026),
        hair: .white.opacity(0.07), hair2: .white.opacity(0.12), highlight: .white.opacity(0.06),
        text: Color(hex: 0xF5F5F7), text2: Color(hex: 0xA9A9B4), text3: Color(hex: 0x6F6F7B),
        accent: Color(hex: 0xFF7A2F), accentSoft: Color(hex: 0xFF7A2F).opacity(0.14),
        red: Color(hex: 0xFF453A), redDeep: Color(hex: 0xE0241A), redSoft: Color(hex: 0xFF453A).opacity(0.12),
        green: Color(hex: 0x32D74B), greenSoft: Color(hex: 0x32D74B).opacity(0.12),
        amber: Color(hex: 0xFFD60A), amberSoft: Color(hex: 0xFFD60A).opacity(0.10),
        blue: Color(hex: 0x64D2FF), blueSoft: Color(hex: 0x64D2FF).opacity(0.12),
        solid: Color(hex: 0xF5F5F7), onSolid: Color(hex: 0x09090B),
        passTop: Color(hex: 0x3A0F0C), passBottom: Color(hex: 0x160606), passLine: Color(hex: 0xFF453A).opacity(0.34),
        glows: true, scheme: .dark)

    /// "Nắng": high contrast for direct sunlight.
    public static let sun = ResQPalette(
        bg: Color(hex: 0xF3F3F5), surface1: .white, surface2: .white, surface3: Color(hex: 0xEBEBEF),
        hair: .black.opacity(0.08), hair2: .black.opacity(0.14), highlight: .white.opacity(0.9),
        text: Color(hex: 0x0A0A0C), text2: Color(hex: 0x3B3B44), text3: Color(hex: 0x6E6E78),
        accent: Color(hex: 0xD9530B), accentSoft: Color(hex: 0xD9530B).opacity(0.10),
        red: Color(hex: 0xD70015), redDeep: Color(hex: 0xC20012), redSoft: Color(hex: 0xD70015).opacity(0.07),
        green: Color(hex: 0x158A35), greenSoft: Color(hex: 0x158A35).opacity(0.10),
        amber: Color(hex: 0x9A6400), amberSoft: Color(hex: 0xFFBE00).opacity(0.16),
        blue: Color(hex: 0x006FA6), blueSoft: Color(hex: 0x006FA6).opacity(0.09),
        solid: Color(hex: 0x0A0A0C), onSolid: .white,
        passTop: Color(hex: 0xFFF4F3), passBottom: Color(hex: 0xFFE7E4), passLine: Color(hex: 0xD70015).opacity(0.28),
        glows: false, scheme: .light)

    /// "Nhìn đêm": red only, preserves dark adaptation.
    public static let night: ResQPalette = {
        let red = Color(hex: 0xFF4D40)
        return ResQPalette(
            bg: .black, surface1: Color(hex: 0x0B0000), surface2: Color(hex: 0x110101), surface3: Color(hex: 0x1A0202),
            hair: red.opacity(0.14), hair2: red.opacity(0.26), highlight: red.opacity(0.08),
            text: red, text2: Color(hex: 0xCC3A30), text3: Color(hex: 0x8A2820),
            accent: red, accentSoft: red.opacity(0.12), red: red, redDeep: Color(hex: 0xA8120A), redSoft: red.opacity(0.10),
            green: red, greenSoft: red.opacity(0.08), amber: Color(hex: 0xFF6A55), amberSoft: red.opacity(0.08),
            blue: Color(hex: 0xFF6A55), blueSoft: red.opacity(0.10), solid: red, onSolid: .black,
            passTop: Color(hex: 0x1C0000), passBottom: Color(hex: 0x0B0000), passLine: red.opacity(0.35),
            glows: false, scheme: .dark)
    }()
}

public enum ResQTheme: String, CaseIterable, Sendable {
    case dark = "Tối", sun = "Nắng", night = "Nhìn đêm"
    public var palette: ResQPalette {
        switch self { case .dark: .dark; case .sun: .sun; case .night: .night }
    }
}

public enum ResQRadius {
    public static let s: CGFloat = 12, m: CGFloat = 16, l: CGFloat = 22, xl: CGFloat = 28
    /// Minimum tap target; glove-friendly.
    public static let tap: CGFloat = 44
}

/// SF Pro on iOS, Roboto/Google Sans on Android: full Vietnamese coverage.
/// Numbers (coordinates, counts, timers) use the monospaced design with tabular digits.
/// Every size goes through `Font.rq`, so the "Chữ lớn" setting scales the whole UI.
@MainActor
public enum ResQFont {
    public static var largeTitle: Font { .rq(size: 34, weight: .bold).width(.standard) }
    public static var hero: Font { .rq(size: 32, weight: .semibold) }
    public static var title: Font { .rq(size: 21, weight: .semibold) }
    public static var lead: Font { .rq(size: 17) }
    public static var body: Font { .rq(size: 16) }
    public static var callout: Font { .rq(size: 14.5) }
    public static var caption: Font { .rq(size: 12, weight: .medium) }
    public static var eyebrow: Font { .rq(size: 12, weight: .semibold) }
    public static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .rq(size: size, weight: weight, design: .monospaced).monospacedDigit()
    }
}

/// Global text scale ("Chữ lớn"). Observable, so every body that builds a font re-renders on change.
@MainActor
@Observable
public final class ResQTextScale {
    public static let shared = ResQTextScale()
    public static let large: CGFloat = 1.15
    public var factor: CGFloat = 1
}

public extension Font {
    @MainActor
    static func rq(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * ResQTextScale.shared.factor, weight: weight, design: design)
    }
}

/// UserDefaults keys for persisted settings.
public enum ResQSettings {
    public static let theme = "resq.theme"
    public static let model = "resq.model"
    public static let largeText = "resq.largeText"
    public static let batterySaver = "resq.batterySaver"
    public static let readAloud = "resq.readAloud"
    public static let haptics = "resq.haptics"
}

public enum ResQMotion {
    /// Matches CSS --spring cubic-bezier(.34,1.56,.64,1)
    public static let spring = Animation.spring(response: 0.42, dampingFraction: 0.72)
    /// Matches CSS --ease cubic-bezier(.22,1,.36,1)
    public static let ease = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.5)
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = ResQPalette.dark
}

public extension EnvironmentValues {
    var palette: ResQPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

// MARK: - Shared surface styles

extension View {
    /// Card surface: fill + 1px top highlight + hairline outline (CSS: var(--hi), 0 0 0 1px var(--hair)).
    func surface(_ p: ResQPalette, radius: CGFloat = ResQRadius.l, fill: Color? = nil) -> some View {
        background(fill ?? p.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [p.highlight.opacity(1.6), p.hair], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
    }

    /// `sensoryFeedback` that respects the "Rung phản hồi" setting.
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger))
    }

    /// Scale-down press feedback used by every tappable card.
    func pressable() -> some View { buttonStyle(PressStyle()) }
}

struct HapticModifier<T: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: T
    @AppStorage(ResQSettings.haptics) private var enabled = true

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(ResQMotion.ease, value: configuration.isPressed)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
