import Foundation
import Observation

/// On-device user data: recent questions, saved items, pinned positions. JSON in UserDefaults; nothing leaves the phone.
@MainActor
@Observable
public final class UserStore {
    public static let shared = UserStore()

    public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
        public var id = UUID()
        public var question: String
        public var date: Date
        public var hasImage: Bool
    }

    public struct SavedItem: Codable, Identifiable, Equatable, Sendable {
        public enum Kind: String, Codable, Sendable { case answer, article }
        public var id = UUID()
        public var kind: Kind
        public var title: String
        public var body: String
        public var date: Date
    }

    public struct Pin: Codable, Identifiable, Equatable, Sendable {
        public var id = UUID()
        public var latitude: Double
        public var longitude: Double
        public var accuracyMeters: Double
        public var altitudeMeters: Double?
        public var note: String
        public var date: Date
    }

    public private(set) var history: [HistoryEntry] = []
    public private(set) var saved: [SavedItem] = []
    public private(set) var pins: [Pin] = []

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        history = load("resq.history") ?? []
        saved = load("resq.saved") ?? []
        pins = load("resq.pins") ?? []
    }

    public func record(question: String, hasImage: Bool) {
        history.removeAll { $0.question == question }
        history.insert(HistoryEntry(question: question, date: .now, hasImage: hasImage), at: 0)
        history = Array(history.prefix(30))
        store(history, "resq.history")
    }

    public func clearHistory() {
        history = []
        store(history, "resq.history")
    }

    public func isSaved(title: String) -> Bool { saved.contains { $0.title == title } }

    public func toggleSaved(kind: SavedItem.Kind, title: String, body: String) {
        if let i = saved.firstIndex(where: { $0.title == title }) {
            saved.remove(at: i)
        } else {
            saved.insert(SavedItem(kind: kind, title: title, body: body, date: .now), at: 0)
        }
        store(saved, "resq.saved")
    }

    public func remove(saved item: SavedItem) {
        saved.removeAll { $0.id == item.id }
        store(saved, "resq.saved")
    }

    public func pin(_ fix: LocationFix, note: String) {
        pins.insert(Pin(latitude: fix.latitude, longitude: fix.longitude, accuracyMeters: fix.accuracyMeters,
                        altitudeMeters: fix.altitudeMeters, note: note, date: .now), at: 0)
        store(pins, "resq.pins")
    }

    public func remove(pin: Pin) {
        pins.removeAll { $0.id == pin.id }
        store(pins, "resq.pins")
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private func store<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

enum RelativeDay {
    /// "Hôm nay", "Hôm qua", else "22/09".
    static func label(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Hôm nay" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: y) { return "Hôm qua" }
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        return f.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
