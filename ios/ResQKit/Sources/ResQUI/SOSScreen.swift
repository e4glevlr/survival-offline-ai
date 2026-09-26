import SwiftUI
import ResQCore
#if os(iOS)
import AVFoundation
#endif

/// Filled from CoreLocation (iOS) / FusedLocationProvider or LocationManager GPS_PROVIDER (Android).
/// GPS needs no cellular signal; the first fix is just slower without A-GPS.
public struct LocationFix: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var accuracyMeters: Double
    public var altitudeMeters: Double?
    public var time: String   // "14:40"

    public init(latitude: Double, longitude: Double, accuracyMeters: Double, altitudeMeters: Double? = nil, time: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracyMeters = accuracyMeters
        self.altitudeMeters = altitudeMeters
        self.time = time
    }
}

/// Everything here works with no network and no LLM.
public struct SOSScreen: View {
    let location: LocationFix?
    let cards: [EmergencyCard]
    let onClose: () -> Void
    @State private var strobing = false
    @State private var litIndex: Int? = nil
    @State private var strobeTask: Task<Void, Never>?
    @State private var openCard: EmergencyCard?
    @Environment(\.palette) private var p

    public init(location: LocationFix?, cards: [EmergencyCard] = [], onClose: @escaping () -> Void) {
        self.location = location
        self.cards = cards
        self.onClose = onClose
    }

    static let hotlines: [(number: String, label: String)] = [("112", "Cứu nạn"), ("115", "Cấp cứu"), ("114", "Cứu hỏa"), ("113", "Công an")]
    static let morse = MorseSignal.pattern("SOS", unit: 0.2)

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 12) { Beacon(); Text("SOS").font(.system(size: 28, weight: .bold)).tracking(0.6).foregroundStyle(p.red) }
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                            .frame(width: ResQRadius.tap, height: ResQRadius.tap).surface(p, radius: 22, fill: p.surface2)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Đóng")
                }
                .frame(height: 56)

                coordinates

                HStack(spacing: 10) {
                    HoldToArmButton(title: "Đèn SOS", icon: "flashlight.on.fill", idle: "Giữ để bật", active: "Đang nháy · chạm để tắt",
                                    isOn: strobing, onArm: startStrobe, onStop: stopStrobe)
                    // Whistle: bundled recorded whistle asset at max volume (never synthesized).
                    HoldToArmButton(title: "Còi báo", icon: "megaphone.fill", idle: "Giữ để bật", active: "Đang phát · chạm để tắt",
                                    isOn: false, onArm: {}, onStop: {})
                }
                MorseStrip(steps: Self.morse, lit: litIndex).opacity(strobing ? 1 : 0.45)

                sectionTitle("Gọi khẩn cấp", trailing: "khi có sóng")
                HStack(spacing: 8) {
                    ForEach(Self.hotlines, id: \.number) { h in
                        let main = h.number == "112"
                        Link(destination: URL(string: "tel:\(h.number)")!) {
                            VStack(spacing: 3) {
                                Text(h.number).font(ResQFont.number(24))
                                Text(h.label).font(.system(size: 11.5)).opacity(main ? 0.85 : 1).foregroundStyle(main ? .white : p.text3)
                            }
                            .foregroundStyle(main ? .white : p.text)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .background {
                                if main {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(LinearGradient(colors: [Color(hex: 0xFF5B50), Color(hex: 0xD91A10)], startPoint: .top, endPoint: .bottom))
                                        .shadow(color: p.glows ? Color(hex: 0xFF3B30).opacity(0.6) : .clear, radius: 14, y: 10)
                                } else {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous).fill(p.text.opacity(0.05))
                                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.hair2))
                                }
                            }
                        }
                        .pressable()
                    }
                }
                Label("Sóng yếu thì gửi SMS. Tin nhắn thường lọt qua khi cuộc gọi không kết nối được.", systemImage: "cellularbars")
                    .font(.system(size: 13)).foregroundStyle(p.text3)

                if !cards.isEmpty {
                    sectionTitle("Việc cần làm ngay", trailing: nil)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(cards) { c in
                            Button { openCard = c } label: {
                                VStack(alignment: .leading) {
                                    Image(systemName: "cross.case.fill").font(.system(size: 24)).foregroundStyle(p.red)
                                    Spacer()
                                    Text(c.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
                                    Text("\(c.steps.count) bước").font(ResQFont.caption).foregroundStyle(p.text3)
                                }
                                .padding(14).frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                                .background(LinearGradient(colors: [p.passTop, p.passBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(p.passLine))
                            }
                            .pressable()
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
        .background {
            ZStack {
                p.scheme == .light ? Color.white : Color(hex: 0x0B0303)
                if p.glows || p.scheme == .light {
                    RadialGradient(colors: [p.scheme == .light ? Color(hex: 0xFFD9D5) : Color(hex: 0x4A0D0A), .clear],
                                   center: .top, startRadius: 0, endRadius: 520)
                }
            }
            .ignoresSafeArea()
        }
        .overlay { Color.white.opacity(litIndex != nil && strobing ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false) }
        .sheet(item: $openCard) { c in
            ScrollView { EmergencyPassView(card: c).padding(18) }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
                .environment(\.palette, p)
        }
        .onDisappear { stopStrobe() }
    }

    private func sectionTitle(_ t: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(t).font(.system(size: 17, weight: .semibold)).foregroundStyle(p.text)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 13)).foregroundStyle(p.text3) }
        }
        .padding(.top, 14)
    }

    @ViewBuilder private var coordinates: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VỊ TRÍ CỦA BẠN · GPS").font(ResQFont.eyebrow).tracking(1.2).foregroundStyle(p.text3)
            if let l = location {
                Text(String(format: "%.5f° N\n%.5f° E", l.latitude, l.longitude))
                    .font(ResQFont.number(32, .medium)).foregroundStyle(p.text).lineSpacing(0)
                    .minimumScaleFactor(0.6).textSelection(.enabled).padding(.top, 4)
                Text(CoordinateFormatter.dms(l.latitude, l.longitude)).font(ResQFont.number(13, .regular)).foregroundStyle(p.text2)
                Rectangle().fill(p.hair).frame(height: 1).padding(.vertical, 8)
                HStack(spacing: 22) {
                    meta("Độ cao", l.altitudeMeters.map { "\(Int($0)) m" } ?? "–")
                    meta("Sai số", "±\(Int(l.accuracyMeters)) m")
                    meta("Cập nhật", l.time)
                }
                let message = CoordinateFormatter.sosMessage(lat: l.latitude, lon: l.longitude, accuracyMeters: l.accuracyMeters, time: l.time)
                HStack(spacing: 8) {
                    Button { copy(message) } label: { ghost("Sao chép", icon: "doc.on.doc") }.pressable()
                    ShareLink(item: message) { ghost("Gửi SMS", icon: "message") }.pressable()
                }
                .padding(.top, 8)
            } else {
                Text("Đang lấy vị trí… Ra chỗ thoáng, nhìn thấy bầu trời.").font(ResQFont.body).foregroundStyle(p.text2)
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) { Radar().frame(width: 160, height: 160).offset(x: 34, y: -34) }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(p.scheme == .light ? Color.white : p.text.opacity(0.04), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(p.hair2))
    }

    private func meta(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(.system(size: 12)).foregroundStyle(p.text3)
            Text(v).font(ResQFont.number(16, .medium)).foregroundStyle(p.text)
        }
    }

    private func ghost(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(p.text.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func close() { stopStrobe(); onClose() }

    private func startStrobe() {
        stopStrobe()
        strobing = true
        strobeTask = Task { @MainActor in
            while !Task.isCancelled {
                for (i, step) in Self.morse.enumerated() {
                    litIndex = step.on ? i : nil
                    Torch.set(step.on)
                    try? await Task.sleep(for: .seconds(step.duration))
                    if Task.isCancelled { break }
                }
            }
            Torch.set(false)
        }
    }

    private func stopStrobe() {
        strobeTask?.cancel()
        strobeTask = nil
        strobing = false
        litIndex = nil
        Torch.set(false)
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - SOS pieces

/// Long-press 0.65 s to arm: avoids a strobe or whistle going off in a pocket. Tap again to stop.
struct HoldToArmButton: View {
    let title: String
    let icon: String
    let idle: String
    let active: String
    let isOn: Bool
    let onArm: () -> Void
    let onStop: () -> Void
    @State private var progress: CGFloat = 0
    @State private var armedLocal = false
    @Environment(\.palette) private var p

    var body: some View {
        let on = isOn || armedLocal
        VStack(alignment: .leading) {
            Image(systemName: icon).font(.system(size: 26))
            Spacer()
            Text(title).font(.system(size: 17, weight: .semibold))
            Text(on ? active : idle).font(.system(size: 12.5)).opacity(on ? 0.85 : 1).foregroundStyle(on ? .white : p.text3)
        }
        .foregroundStyle(on || progress > 0.35 ? .white : p.text)
        .padding(16).frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(p.scheme == .light ? Color.white : p.text.opacity(0.04))
                GeometryReader { g in Rectangle().fill(p.redDeep).frame(width: g.size.width * (on ? 1 : progress)) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(p.hair2))
        .contentShape(Rectangle())
        .onTapGesture { if on { armedLocal = false; progress = 0; onStop() } }
        .onLongPressGesture(minimumDuration: 0.65) {
            armedLocal = true; onArm()
        } onPressingChanged: { pressing in
            guard !on else { return }
            withAnimation(pressing ? .linear(duration: 0.65) : ResQMotion.ease) { progress = pressing ? 1 : 0 }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: armedLocal)
        .onChange(of: isOn) { _, new in if !new { armedLocal = false; progress = 0 } }
    }
}

/// Dots and dashes of the pattern; the currently lit one glows in sync with the torch.
struct MorseStrip: View {
    let steps: [SignalStep]
    let lit: Int?
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                if s.on {
                    Capsule().fill(lit == i ? (p.glows ? Color.white : p.red) : p.text3)
                        .frame(width: s.duration > 0.3 ? 24 : 8, height: 8)
                        .shadow(color: lit == i ? (p.glows ? .white : p.red) : .clear, radius: 6)
                } else if s.duration > 0.5 {
                    Color.clear.frame(width: 8, height: 8)   // letter / word gap
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(p.scheme == .light ? p.surface3 : .black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.linear(duration: 0.08), value: lit)
    }
}

struct Beacon: View {
    @State private var go = false
    @Environment(\.palette) private var p
    var body: some View {
        Circle().fill(p.red).frame(width: 12, height: 12)
            .background {
                ForEach(0..<2) { i in
                    Circle().strokeBorder(p.red, lineWidth: 2).scaleEffect(go ? 3.2 : 1).opacity(go ? 0 : 0.9)
                        .animation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(Double(i)), value: go)
                }
            }
            .onAppear { go = true }
    }
}

struct Radar: View {
    @Environment(\.palette) private var p
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3) { i in
                    let phase = (t / 3 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle().strokeBorder(p.red.opacity(0.45), lineWidth: 1).scaleEffect(0.15 + 0.85 * phase).opacity(1 - phase)
                }
                Circle().fill(p.red).frame(width: 8, height: 8).shadow(color: p.red, radius: 7)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Android port: CameraManager.setTorchMode(cameraId, on).
enum Torch {
    @MainActor static func set(_ on: Bool) {
        #if os(iOS)
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
        #endif
    }
}
