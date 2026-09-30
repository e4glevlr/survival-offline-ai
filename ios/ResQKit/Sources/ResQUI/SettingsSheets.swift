import SwiftUI
import ResQCore
#if canImport(Speech)
import Speech
#endif

/// UI labels for the installed model. One model per device; `.searchOnly` turns the LLM off.
extension ModelTier {
    var statusName: String { switch self { case .large: "Gemma 4 E4B"; case .standard: "Gemma 4 E2B"; case .searchOnly: "Chỉ tra cứu" } }
    var chipName: String { switch self { case .large: "E4B"; case .standard: "E2B"; case .searchOnly: "Tra cứu" } }
    var detail: String {
        switch self {
        case .large: "Mặc định · 3,7 GB"
        case .standard: "Nhẹ · 2,6 GB · chưa đạt kiểm định"
        case .searchOnly: "Không AI · cẩm nang, tìm kiếm, SOS vẫn đủ"
        }
    }
}

// MARK: - Grouped list (iOS Settings style)

struct ResQGroup<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.palette) private var p
    var body: some View {
        VStack(spacing: 0) { content }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .surface(p, radius: 20)
    }
}

struct RowDivider: View {
    @Environment(\.palette) private var p
    var body: some View { Rectangle().fill(p.hair).frame(height: 1).padding(.leading, 58) }
}

struct ResQRow<Trailing: View>: View {
    let icon: String?
    var tint: Color? = nil
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                let bg = p.glows || p.scheme == .light ? (tint ?? p.surface3) : p.surface3
                Image(systemName: icon).font(.rq(size: 16, weight: .medium))
                    .foregroundStyle(tint == nil ? p.text : (p.glows || p.scheme == .light ? .white : p.accent))
                    .frame(width: 32, height: 32)
                    .background(bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.rq(size: 15.5, weight: .medium)).foregroundStyle(p.text)
                Text(subtitle).font(.rq(size: 12.5)).foregroundStyle(p.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

extension ResQRow where Trailing == EmptyView {
    init(icon: String?, tint: Color? = nil, title: String, subtitle: String) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct GroupLabel: View {
    let text: Text
    @Environment(\.palette) private var p
    init(_ s: String) { text = Text(s) }
    init(_ t: Text) { text = t }
    var body: some View {
        text.font(.rq(size: 12, weight: .semibold)).tracking(1.2).textCase(.uppercase).foregroundStyle(p.text3)
            .padding(.horizontal, 4).padding(.top, 22).padding(.bottom, 8)
    }
}

struct SheetTitle: View {
    let title: String
    let sub: String
    @Environment(\.palette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.rq(size: 24, weight: .bold)).tracking(-0.8).foregroundStyle(p.text)
            Text(sub).font(.rq(size: 14)).foregroundStyle(p.text3).lineSpacing(3)
        }
        .padding(.bottom, 0)
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    let onToast: (String, String) -> Void
    @AppStorage(ResQSettings.theme) private var theme: ResQTheme = .dark
    @AppStorage(ResQSettings.model) private var modelChoice: ModelTier = .large
    @AppStorage(ResQSettings.largeText) private var largeText = false
    @AppStorage(ResQSettings.batterySaver) private var batterySaver = true
    @AppStorage(ResQSettings.readAloud) private var readAloud = true
    @AppStorage(ResQSettings.haptics) private var haptics = true
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle(title: "Cài đặt", sub: "Mỗi máy chỉ cài một mô hình. Chế độ tiết kiệm rút ngắn câu trả lời chứ không đổi mô hình.")

                GroupLabel("Giao diện")
                HStack(spacing: 10) {
                    ForEach(ResQTheme.allCases, id: \.self) { t in themeButton(t) }
                }

                GroupLabel("Mô hình AI")
                ResQGroup {
                    ForEach(Array(ModelTier.allCases.enumerated()), id: \.element) { i, m in
                        if i > 0 { RowDivider() }
                        Button {
                            modelChoice = m
                            if m == .standard { onToast("E2B chưa đạt kiểm định: câu trả lời kém tin cậy hơn E4B", "exclamationmark.triangle.fill") }
                        } label: {
                            HStack(spacing: 0) {
                                radio(m == modelChoice).padding(.leading, 14)
                                ResQRow(icon: nil, title: m.statusName, subtitle: m.detail)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .haptic(.selection, trigger: modelChoice)

                GroupLabel(Text("Dung lượng · \(Text("2,95 GB").font(ResQFont.number(12)))"))
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { g in
                        let parts: [(CGFloat, Color)] = [(2.6, p.accent), (0.23, p.blue), (0.12, p.green), (1.1, p.surface3)]
                        let total = parts.map(\.0).reduce(0, +)
                        HStack(spacing: 2) {
                            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                                Rectangle().fill(part.1).frame(width: max(2, (g.size.width - 6) * part.0 / total))
                            }
                        }
                    }
                    .frame(height: 10).clipShape(RoundedRectangle(cornerRadius: 5))
                    HStack(spacing: 14) {
                        legend("Mô hình 2,6 GB", p.accent); legend("Cẩm nang 0,23 GB", p.blue); legend("Tìm kiếm 0,12 GB", p.green)
                    }
                }
                .padding(14).surface(p, radius: 20)

                GroupLabel("Năng lượng và trợ năng")
                ResQGroup {
                    toggleRow("battery.25percent", Color(hex: 0x30B94D), "Tiết kiệm pin", "Tự rút ngắn câu trả lời khi pin dưới 20%, máy nóng hoặc bật Nguồn điện thấp", $batterySaver)
                    RowDivider()
                    toggleRow("textformat.size", Color(hex: 0x0A84FF), "Chữ lớn", "Dễ đọc dưới nắng, khi mệt", $largeText)
                    RowDivider()
                    toggleRow("speaker.wave.2.fill", Color(hex: 0xFF9F0A), "Tự đọc to thẻ khẩn cấp", "Rảnh tay khi sơ cứu", $readAloud)
                    RowDivider()
                    toggleRow("iphone.radiowaves.left.and.right", Color(hex: 0xBF5AF2), "Rung phản hồi", "Xác nhận thao tác khi đeo găng", $haptics)
                }

                Text("\(GuideLibrary.summary)\nKhông có dữ liệu nào rời khỏi máy.")
                    .font(.rq(size: 12.5)).foregroundStyle(p.text3).lineSpacing(4).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.top, 22)
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private func themeButton(_ t: ResQTheme) -> some View {
        // Preview swatches from the prototype: background, header bar, cards, SOS.
        let (bg, head, card, sos): (UInt32, UInt32, UInt32, UInt32) = switch t {
        case .dark: (0x0E0E11, 0x2A2A30, 0x1C1C21, 0xFF453A)
        case .sun: (0xF3F3F5, 0xD4D4DA, 0xFFFFFF, 0xD70015)
        case .night: (0x000000, 0x3A0805, 0x1A0202, 0xFF4D40)
        }
        let on = t == theme
        return Button { withAnimation(ResQMotion.ease) { theme = t } } label: {
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    bar(Color(hex: head), 0.6)
                    bar(Color(hex: card), 1)
                    bar(Color(hex: card), 0.8)
                    Spacer(minLength: 0)
                    bar(Color(hex: sos), 0.4)
                }
                .padding(.vertical, 10).padding(.horizontal, 8)
                .frame(maxWidth: .infinity).aspectRatio(0.8, contentMode: .fit)
                .background(Color(hex: bg), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? p.accent : p.hair2, lineWidth: on ? 2 : 1))
                Text(t.rawValue).font(.rq(size: 13, weight: .medium)).foregroundStyle(on ? p.text : p.text2)
            }
        }
        .buttonStyle(.plain)
        .haptic(.selection, trigger: theme)
    }

    private func bar(_ c: Color, _ w: CGFloat) -> some View {
        GeometryReader { g in Capsule().fill(c).frame(width: g.size.width * w) }.frame(height: 7)
    }

    private func radio(_ on: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(on ? p.accent : p.hair2, lineWidth: on ? 6.5 : 1.5)
        }
        .frame(width: 22, height: 22)
        .animation(ResQMotion.spring, value: on)
    }

    private func legend(_ s: String, _ c: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 8, height: 8)
            Text(s).font(.rq(size: 12.5)).foregroundStyle(p.text3).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func toggleRow(_ icon: String, _ tint: Color, _ title: String, _ sub: String, _ on: Binding<Bool>) -> some View {
        ResQRow(icon: icon, tint: tint, title: title, subtitle: sub) {
            Toggle(title, isOn: on).labelsHidden().tint(p.green)
        }
    }
}

// MARK: - Before the trip

/// Pre-trip checklist. Every row reads the real device state except the model/knowledge pack (demo build).
struct PrepSheet: View {
    let onToast: (String, String) -> Void
    @AppStorage(ResQSettings.model) private var modelTier: ModelTier = .large
    @Environment(FieldSensors.self) private var sensors: FieldSensors?
    @Environment(\.palette) private var p
    @State private var speechAuthorized = VoiceInput.isAuthorized

    private var battery: Int? { sensors?.battery }
    private var batteryOK: Bool { sensors?.charging == true || (battery ?? 0) >= 80 }
    private var ttsOK: Bool { Speaker.hasVietnameseVoice }
    private var sttOK: Bool { VoiceInput.supportsOffline && speechAuthorized }
    private var locationOK: Bool { sensors?.locationAllowed == true }

    var body: some View {
        let checks = [ttsOK, sttOK, locationOK, batteryOK]
        let ready = checks.filter { $0 }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetTitle(title: "Trước chuyến đi", sub: "Làm khi còn Wi-Fi. Sau đó ResQ chạy hoàn toàn ngoại tuyến.")
                    .padding(.bottom, 18)

                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(p.surface3, lineWidth: 6)
                        Circle().trim(from: 0, to: CGFloat(ready) / CGFloat(checks.count))
                            .stroke(p.green, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                    }
                    .frame(width: 58, height: 58).padding(3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(Text("\(ready)/\(checks.count)").font(ResQFont.number(17))) mục trên máy đã sẵn sàng")
                            .font(.rq(size: 17, weight: .semibold)).foregroundStyle(p.text)
                        Text(ready == checks.count ? "Có thể lên đường." : "Xem các mục màu vàng bên dưới.")
                            .font(.rq(size: 13)).foregroundStyle(p.text3)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .surface(p, fill: p.surface2)
                .padding(.bottom, 8)

                ResQGroup {
                    ResQRow(icon: "cpu", tint: Color(hex: 0xFF7A2F), title: "Mô hình AI",
                            subtitle: modelTier == .searchOnly ? "Đã tắt · chỉ tra cứu" : "\(modelTier.statusName) · bản demo, câu trả lời mẫu") {
                        state("info.circle.fill", p.text3)
                    }
                    RowDivider()
                    ResQRow(icon: "book.fill", tint: Color(hex: 0x0A84FF), title: "Cẩm nang", subtitle: "Nội dung mẫu · chờ duyệt y tế") {
                        state("info.circle.fill", p.text3)
                    }
                    RowDivider()
                    ResQRow(icon: "speaker.wave.2.fill", tint: Color(hex: 0xFF9F0A), title: "Giọng đọc tiếng Việt",
                            subtitle: ttsOK ? "Đã có trên máy" : "Chưa có · Cài đặt › Trợ năng › Nội dung được đọc › Giọng nói") {
                        check(ttsOK)
                    }
                    RowDivider()
                    Button(action: requestSpeech) {
                        ResQRow(icon: "mic.fill", tint: Color(hex: 0xBF5AF2), title: "Nhận dạng giọng nói", subtitle: sttSubtitle) {
                            check(sttOK)
                        }
                    }
                    .pressable()
                    RowDivider()
                    Button { sensors?.requestLocationPermission() } label: {
                        ResQRow(icon: "location.fill", tint: Color(hex: 0x30B94D), title: "Quyền vị trí",
                                subtitle: locationOK ? "Khi dùng app" : "Chưa cho phép · bấm để bật") {
                            check(locationOK)
                        }
                    }
                    .pressable()
                    RowDivider()
                    ResQRow(icon: "battery.50percent", tint: Color(hex: 0xFF453A), title: battery.map { "Pin \($0)%" } ?? "Pin",
                            subtitle: sensors?.charging == true ? "Đang sạc" : batteryOK ? "Đủ cho chuyến đi" : "Nên sạc đầy, mang sạc dự phòng") {
                        check(batteryOK)
                    }
                }

                GroupLabel("Nên làm")
                ResQGroup {
                    ShareLink(item: routeMessage) {
                        ResQRow(icon: "mappin.and.ellipse", title: "Báo lộ trình cho người ở nhà", subtitle: "Gửi vị trí xuất phát, ghi thêm giờ về dự kiến") {
                            Image(systemName: "square.and.arrow.up").font(.rq(size: 16)).foregroundStyle(p.text3)
                        }
                    }
                    .pressable()
                    RowDivider()
                    ResQRow(icon: "airplane", title: "Bật chế độ máy bay khi không gọi", subtitle: "Tiết kiệm pin, GPS vẫn chạy")
                }
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private var sttSubtitle: String {
        if !VoiceInput.supportsOffline { return "Máy chưa hỗ trợ nhận dạng tiếng Việt ngoại tuyến" }
        return speechAuthorized ? "Chạy trên máy, không cần mạng" : "Chưa cấp quyền · bấm để bật"
    }

    private var routeMessage: String {
        guard let l = sensors?.location else { return "Mình chuẩn bị đi. Giờ về dự kiến: " }
        return "Mình xuất phát từ \(String(format: "%.5f, %.5f", l.latitude, l.longitude)) lúc \(l.time). Giờ về dự kiến: "
    }

    private func requestSpeech() {
        #if canImport(Speech)
        Task {
            speechAuthorized = await VoiceInput.requestPermissions()
            if !speechAuthorized { onToast("Chưa có quyền micro hoặc nhận dạng giọng nói", "mic.slash") }
        }
        #endif
    }

    private func check(_ ok: Bool) -> some View {
        state(ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill", ok ? p.green : p.amber)
    }
    private func state(_ icon: String, _ c: Color) -> some View {
        Image(systemName: icon).font(.rq(size: 21)).foregroundStyle(c)
    }
}
