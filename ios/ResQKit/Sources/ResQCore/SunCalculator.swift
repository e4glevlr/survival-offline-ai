import Foundation

/// Sunrise / sunset for the "daylight left" tile. Offline, no data files.
/// Algorithm: SunCalc (V. Agafonkin), sun altitude -0.833°. Accurate to about a minute below the polar circles.
/// Same code in the prototype (JS) and Kotlin; the tests pin identical outputs.
public enum SunCalculator {
    public struct Times: Sendable, Equatable {
        public let sunrise: Date
        public let sunset: Date
    }

    public static func times(on date: Date, latitude: Double, longitude: Double) -> Times? {
        let rad = Double.pi / 180, dayS = 86_400.0, j1970 = 2_440_588.0, j2000 = 2_451_545.0, e = rad * 23.4397
        let d = date.timeIntervalSince1970 / dayS - 0.5 + j1970 - j2000
        let lw = rad * -longitude, phi = rad * latitude
        let n = (d - 0.0009 - lw / (2 * .pi)).rounded()
        let ds = 0.0009 + lw / (2 * .pi) + n
        let m = rad * (357.5291 + 0.98560028 * ds)
        let c = rad * (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m))
        let l = m + c + rad * 102.9372 + .pi
        let dec = asin(sin(e) * sin(l))
        let jNoon = j2000 + ds + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
        let cosW = (sin(rad * -0.833) - sin(phi) * sin(dec)) / (cos(phi) * cos(dec))
        guard (-1...1).contains(cosW) else { return nil }   // polar day / night
        let w = acos(cosW)
        let jSet = j2000 + 0.0009 + (w + lw) / (2 * .pi) + n + 0.0053 * sin(m) - 0.0069 * sin(2 * l)
        func toDate(_ j: Double) -> Date { Date(timeIntervalSince1970: (j + 0.5 - j1970) * dayS) }
        return Times(sunrise: toDate(jNoon - (jSet - jNoon)), sunset: toDate(jSet))
    }

    public enum Daylight: Sendable, Equatable {
        case untilSunset(TimeInterval, sunset: Date)
        case untilSunrise(TimeInterval, sunrise: Date)
    }

    /// What the dashboard tile shows: time of light left, or time until it gets light again.
    public static func daylight(now: Date, latitude: Double, longitude: Double) -> Daylight? {
        guard let t = times(on: now, latitude: latitude, longitude: longitude) else { return nil }
        if now >= t.sunrise && now < t.sunset { return .untilSunset(t.sunset.timeIntervalSince(now), sunset: t.sunset) }
        let next = now < t.sunrise ? t.sunrise
            : times(on: now.addingTimeInterval(86_400), latitude: latitude, longitude: longitude)?.sunrise
        return next.map { .untilSunrise($0.timeIntervalSince(now), sunrise: $0) }
    }
}
