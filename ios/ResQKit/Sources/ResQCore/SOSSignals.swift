import Foundation

public struct SignalStep: Sendable, Equatable {
    public let on: Bool
    public let duration: TimeInterval
}

/// Morse timing for the flashlight / screen strobe. Works with no network and no LLM.
public enum MorseSignal {
    static let table: [Character: String] = ["S": "...", "O": "---"]

    /// dot = 1u, dash = 3u, gap inside a letter = 1u, between letters = 3u, after the word = 7u.
    public static func pattern(_ word: String = "SOS", unit: TimeInterval = 0.2) -> [SignalStep] {
        var steps: [SignalStep] = []
        let letters = Array(word.uppercased())
        for (li, letter) in letters.enumerated() {
            guard let code = table[letter] else { continue }
            for (si, symbol) in code.enumerated() {
                steps.append(SignalStep(on: true, duration: unit * (symbol == "." ? 1 : 3)))
                if si < code.count - 1 { steps.append(SignalStep(on: false, duration: unit)) }
            }
            steps.append(SignalStep(on: false, duration: unit * (li < letters.count - 1 ? 3 : 7)))
        }
        return steps
    }
}

/// GPS works without cellular signal; this text is what the user reads out or sends by SMS when any bar appears.
public enum CoordinateFormatter {
    public static func decimal(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.5f, %.5f", lat, lon)
    }

    public static func dms(_ lat: Double, _ lon: Double) -> String {
        "\(dmsPart(lat, pos: "N", neg: "S")) \(dmsPart(lon, pos: "E", neg: "W"))"
    }

    static func dmsPart(_ value: Double, pos: String, neg: String) -> String {
        let a = abs(value)
        var deg = Int(a)
        var minutes = Int((a - Double(deg)) * 60)
        var seconds = ((a - Double(deg)) * 60 - Double(minutes)) * 60
        seconds = (seconds * 10).rounded() / 10
        if seconds >= 60 { seconds = 0; minutes += 1 }
        if minutes >= 60 { minutes = 0; deg += 1 }
        return String(format: "%d°%02d'%04.1f\"%@", deg, minutes, seconds, value >= 0 ? pos : neg)
    }

    public static func sosMessage(lat: Double, lon: Double, accuracyMeters: Double, time: String) -> String {
        "SOS - can cuu ho. Vi tri: \(decimal(lat, lon)) (±\(Int(accuracyMeters.rounded())) m) \(dms(lat, lon)) luc \(time)"
    }
}
