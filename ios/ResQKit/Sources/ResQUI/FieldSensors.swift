import Foundation
import Observation
import CoreLocation
import Network
import ResQCore
#if canImport(UIKit)
import UIKit
#endif

/// Live device state for the dashboard, SOS and DevicePolicy: GPS, battery, thermal, RAM.
/// GPS works with no cellular signal; the place name only resolves when a network happens to be available.
@MainActor
@Observable
public final class FieldSensors {
    public private(set) var location: LocationFix?
    public private(set) var place: String?
    public private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// 0…100, nil when the OS does not report it (Simulator).
    public private(set) var battery: Int?
    public private(set) var charging = false
    public private(set) var lowPowerMode = false
    public private(set) var thermal: ThermalLevel = .nominal
    /// Any network path (cellular or Wi-Fi). ResQ never needs it; the dashboard just says so.
    public private(set) var online = false
    public let memoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory

    public var memoryGB: Int { Int((Double(memoryBytes) / 1_073_741_824).rounded()) }
    public var locationAllowed: Bool {
        #if os(iOS)
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
        #else
        authorization == .authorizedAlways
        #endif
    }

    @ObservationIgnored private var bridge: LocationBridge?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var geocodedAt: CLLocation?
    @ObservationIgnored private let path = NWPathMonitor()
    @ObservationIgnored private let isPreview: Bool

    public init() { isPreview = false }

    /// Fixed values for previews and UI tests.
    public init(preview location: LocationFix?, place: String?, battery: Int?) {
        isPreview = true
        self.location = location
        self.place = place
        self.battery = battery
        authorization = .authorizedAlways
    }

    public func start() {
        guard !isPreview, bridge == nil else { return }
        let b = LocationBridge { [weak self] event in self?.handle(event) }
        bridge = b
        authorization = b.manager.authorizationStatus
        if authorization == .notDetermined { b.manager.requestWhenInUseAuthorization() }
        b.manager.startUpdatingLocation()

        let nc = NotificationCenter.default
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        readBattery()
        observers.append(nc.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readBattery() }
        })
        observers.append(nc.addObserver(forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readBattery() }
        })
        #endif
        Self.watch(path) { [weak self] up in Task { @MainActor in self?.online = up } }
        readProcess()
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.readProcess() }
            })
        }
    }

    /// Nonisolated so the handler is not bound to the main actor (NWPathMonitor calls it on its own queue).
    nonisolated private static func watch(_ monitor: NWPathMonitor, _ update: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { update($0.status == .satisfied) }
        monitor.start(queue: .global(qos: .utility))
    }

    public func requestLocationPermission() {
        #if canImport(UIKit)
        if authorization == .denied || authorization == .restricted {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            return
        }
        #endif
        bridge?.manager.requestWhenInUseAuthorization()
    }

    /// Snapshot for DevicePolicy. "Tiết kiệm pin" on = automatic saving (low battery, heat, Low Power Mode).
    /// Off = only the hard cut-offs stay (battery under 10 %, critical heat): those protect the SOS features.
    public func snapshot(batterySaver: Bool) -> DeviceSnapshot {
        let level = Double(battery ?? 100) / 100
        return DeviceSnapshot(physicalMemoryBytes: memoryBytes,
                              thermal: batterySaver || thermal == .critical ? thermal : .nominal,
                              batteryLevel: batterySaver || level < 0.10 ? level : max(level, 0.20),
                              isCharging: charging,
                              lowPowerMode: batterySaver && lowPowerMode)
    }

    private func handle(_ event: LocationBridge.Event) {
        switch event {
        case .authorization(let status):
            authorization = status
            if locationAllowed { bridge?.manager.startUpdatingLocation() }
        case .fix(let lat, let lon, let acc, let alt, let time):
            location = LocationFix(latitude: lat, longitude: lon, accuracyMeters: acc, altitudeMeters: alt,
                                   time: RelativeDay.time(time))
            geocodeIfNeeded(CLLocation(latitude: lat, longitude: lon))
        }
    }

    private func geocodeIfNeeded(_ loc: CLLocation) {
        if let last = geocodedAt, last.distance(from: loc) < 1_000, place != nil { return }
        geocodedAt = loc
        CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "vi_VN")) { [weak self] marks, _ in
            let name = marks?.first.flatMap { $0.subLocality ?? $0.locality ?? $0.administrativeArea ?? $0.name }
            Task { @MainActor in if let name { self?.place = name } }
        }
    }

    #if canImport(UIKit)
    private func readBattery() {
        let level = UIDevice.current.batteryLevel
        battery = level < 0 ? nil : Int((level * 100).rounded())
        let state = UIDevice.current.batteryState
        charging = state == .charging || state == .full
    }
    #endif

    private func readProcess() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        thermal = switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
    }
}

/// CLLocationManager delegate kept off the main-actor class so callbacks can be nonisolated.
private final class LocationBridge: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    enum Event: Sendable {
        case authorization(CLAuthorizationStatus)
        case fix(lat: Double, lon: Double, acc: Double, alt: Double?, time: Date)
    }

    let manager = CLLocationManager()
    private let onEvent: @MainActor (Event) -> Void

    init(onEvent: @escaping @MainActor (Event) -> Void) {
        self.onEvent = onEvent
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in onEvent(.authorization(status)) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0 else { return }
        let e = Event.fix(lat: l.coordinate.latitude, lon: l.coordinate.longitude, acc: l.horizontalAccuracy,
                          alt: l.verticalAccuracy >= 0 ? l.altitude : nil, time: l.timestamp)
        Task { @MainActor in onEvent(e) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
