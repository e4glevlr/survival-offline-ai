import SwiftUI
import ResQCore

import PhotosUI

public struct ChatScreen: View {
    @State private var model: ChatViewModel
    @State private var tab: Tab = .ask
    @State private var showSOS = false
    @State private var scrolled = false
    @State private var drawerOpen = false
    @State private var sheet: Sheet?
    @State private var toast: Toast?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var sensors: FieldSensors
    @AppStorage(ResQSettings.theme) private var theme: ResQTheme = .dark
    @AppStorage(ResQSettings.model) private var modelTier: ModelTier = .large
    @AppStorage(ResQSettings.largeText) private var largeText = false
    @AppStorage(ResQSettings.batterySaver) private var batterySaver = true
    @Namespace private var seg

    enum Tab: String, CaseIterable { case ask = "Hỏi", guides = "Cẩm nang" }

    enum Sheet: Identifiable {
        case settings, prep, article(GuideLibrary.Article), card(EmergencyCard), saved(UserStore.SavedItem), pillar(GuideLibrary.Pillar)
        var id: String {
            switch self {
            case .settings: "settings"; case .prep: "prep"; case .article(let a): "a-" + a.id
            case .card(let c): c.id; case .saved(let i): i.id.uuidString; case .pillar(let pl): pl.id
            }
        }
    }

    struct Toast: Equatable { let text: String; let icon: String; let id = UUID() }

    public init(model: ChatViewModel, sensors: FieldSensors = FieldSensors()) {
        _model = State(initialValue: model)
        _sensors = State(initialValue: sensors)
    }

    private var location: LocationFix? { sensors.location }

    public var body: some View {
        let p = theme.palette
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                p.bg.ignoresSafeArea()
                DrawerMenu(modelTier: modelTier, onAction: drawerAction)
                    .frame(width: geo.size.width * 0.62)
                    .opacity(drawerOpen ? 1 : 0)
                    .offset(x: drawerOpen ? 0 : -24)
                    .allowsHitTesting(drawerOpen)
                shell
                    .mask { RoundedRectangle(cornerRadius: drawerOpen ? 38 : 0, style: .continuous).ignoresSafeArea() }
                    .overlay {
                        if drawerOpen {
                            RoundedRectangle(cornerRadius: 38, style: .continuous).strokeBorder(p.hair2).ignoresSafeArea()
                                .contentShape(Rectangle())
                                .onTapGesture { withAnimation(ResQMotion.ease) { drawerOpen = false } }
                        }
                    }
                    .shadow(color: .black.opacity(drawerOpen ? 0.35 : 0), radius: 18, x: -10)
                    .scaleEffect(drawerOpen ? 0.92 : 1, anchor: .leading)
                    .offset(x: drawerOpen ? geo.size.width * 0.66 : 0)
            }
        }
        .overlay(alignment: .top) { toastView }
        .environment(\.palette, p)
        .environment(sensors)
        .preferredColorScheme(p.scheme)
        .tint(p.accent)
        .haptic(.impact(weight: .light), trigger: drawerOpen)
        .sheet(item: $sheet) { s in
            sheetContent(s)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(p.surface1)
                .environment(\.palette, p)
                .environment(sensors)
                .preferredColorScheme(p.scheme)
                .overlay(alignment: .top) { toastView }
        }
        .sosPresentation(isPresented: $showSOS) {
            SOSScreen(location: location, cards: GuideLibrary.cards, onClose: { showSOS = false })
                .environment(\.palette, p)
                .environment(sensors)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data { model.attachment = data }
            }
            .ignoresSafeArea()
        }
        #endif
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self), let jpeg = ImageData.jpeg(raw) {
                    model.attachment = jpeg
                }
                libraryItem = nil
            }
        }
        .onAppear { sensors.start() }
        .onChange(of: largeText, initial: true) { _, on in ResQTextScale.shared.factor = on ? ResQTextScale.large : 1 }
        .onChange(of: modelTier, initial: true) { _, t in model.installed = t }
        .onChange(of: sensors.snapshot(batterySaver: batterySaver), initial: true) { _, d in model.device = d }
    }

    private var shell: some View {
        let p = theme.palette
        return ZStack(alignment: .top) {
            p.bg.ignoresSafeArea()
            if p.glows {
                RadialGradient(colors: [p.accent.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 420).ignoresSafeArea()
            }
            if tab == .ask {
                messages.safeAreaInset(edge: .bottom) {
                    Composer(model: model, modelLabel: modelTier.chipName, memoryGB: sensors.memoryGB,
                             onModel: { sheet = .settings }, onAttach: attach, onToast: showToast)
                }
            } else {
                GuidesView(onCard: { sheet = .card($0) }, onArticle: { sheet = .article($0) }, onPillar: { sheet = .pillar($0) }, onSaved: { sheet = .saved($0) },
                           onScrolled: { scrolled = $0 })
            }
            header
        }
        .allowsHitTesting(!drawerOpen)
    }

    @ViewBuilder
    private func sheetContent(_ s: Sheet) -> some View {
        switch s {
        case .settings:
            SettingsSheet(onToast: showToast)
        case .prep:
            PrepSheet(onToast: showToast)
        case .article(let a):
            ArticleSheet(article: a) {
                sheet = nil
                tab = .ask
                model.send(a.title)
            }
        case .card(let c):
            ScrollView { EmergencyPassView(card: c).padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 26) }
                .scrollIndicators(.hidden)
        case .saved(let item):
            SavedAnswerSheet(item: item) { sheet = nil }
        case .pillar(let pl):
            PillarSheet(pillar: pl, onCard: { sheet = .card($0) }, onArticle: { sheet = .article($0) })
        }
    }

    @ViewBuilder
    private var toastView: some View {
        let p = theme.palette
        if let t = toast {
            HStack(spacing: 9) {
                Image(systemName: t.icon).font(.rq(size: 18)).foregroundStyle(p.green)
                Text(t.text).font(.rq(size: 14, weight: .medium)).foregroundStyle(p.text)
            }
            .padding(.leading, 12).padding(.trailing, 16).frame(minHeight: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .background(p.surface2.opacity(0.8), in: Capsule())
            .overlay(Capsule().strokeBorder(p.hair2))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
            .padding(.horizontal, 24).padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .id(t.id)
        }
    }

    private func showToast(_ text: String, _ icon: String) {
        let t = Toast(text: text, icon: icon)
        withAnimation(ResQMotion.spring) { toast = t }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if toast == t { withAnimation(ResQMotion.ease) { toast = nil } }
        }
    }

    private func drawerAction(_ a: DrawerMenu.Action) {
        withAnimation(ResQMotion.ease) { drawerOpen = false }
        switch a {
        case .newChat: withAnimation(ResQMotion.ease) { tab = .ask; model.newConversation() }
        case .sos: showSOS = true
        case .guides: withAnimation(ResQMotion.spring) { tab = .guides }
        case .prep: sheet = .prep
        case .settings: sheet = .settings
        case .history(let q):
            tab = .ask
            model.newConversation()
            model.send(q)
        }
    }

    private func attach(_ kind: Composer.Attach) {
        switch kind {
        case .camera:
            #if os(iOS)
            if CameraPicker.isAvailable { showCamera = true } else {
                showToast("Máy này không có camera, mở thư viện ảnh", "camera.fill")
                showLibrary = true
            }
            #else
            showLibrary = true
            #endif
        case .library: showLibrary = true
        case .guide: withAnimation(ResQMotion.spring) { tab = .guides }
        case .location:
            guard let l = location else { return showToast("Chưa có vị trí GPS", "location.slash") }
            let coord = String(format: "Toạ độ của tôi: %.5f, %.5f (±%d m)", l.latitude, l.longitude, Int(l.accuracyMeters))
            model.draft = model.draft.isEmpty ? coord : model.draft + " " + coord
        }
    }

    // MARK: Header

    private var header: some View {
        let p = theme.palette
        return VStack(spacing: 8) {
            HStack {
                Button { withAnimation(ResQMotion.ease) { drawerOpen = true } } label: {
                    Image(systemName: "line.3.horizontal").font(.rq(size: 17, weight: .medium))
                        .frame(width: ResQRadius.tap, height: ResQRadius.tap)
                        .surface(p, radius: ResQRadius.tap / 2, fill: p.surface2)
                }
                .pressable()
                .accessibilityLabel("Mở menu")
                Spacer()
                segmented
                Spacer()
                SOSButton { showSOS = true }
            }
            HStack(spacing: 7) {
                LiveDot()
                Text("Ngoại tuyến")
                Circle().fill(p.text3).frame(width: 3, height: 3)
                Text(modelTier.statusName)
                if let b = sensors.battery {
                    Circle().fill(p.text3).frame(width: 3, height: 3)
                    Text("\(b)%").font(ResQFont.number(12, .medium))
                }
            }
            .font(.rq(size: 12)).foregroundStyle(p.text2)
            .padding(.horizontal, 11).frame(height: 26)
            .surface(p, radius: 13, fill: p.surface2)
        }
        .foregroundStyle(p.text)
        .padding(.horizontal, 14).padding(.bottom, 10)
        .background {
            if scrolled { Rectangle().fill(.ultraThinMaterial).overlay(alignment: .bottom) { Rectangle().fill(p.hair).frame(height: 1) }.ignoresSafeArea() }
            else { LinearGradient(colors: [p.bg, p.bg.opacity(0)], startPoint: .init(x: 0.5, y: 0.45), endPoint: .bottom).ignoresSafeArea() }
        }
        .animation(ResQMotion.ease, value: scrolled)
    }

    private var segmented: some View {
        let p = theme.palette
        return HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(ResQMotion.spring) { tab = t; scrolled = false } } label: {
                    Text(t.rawValue).font(.rq(size: 14, weight: .semibold))
                        .foregroundStyle(tab == t ? p.text : p.text3)
                        .frame(width: 92, height: 36)
                        .background {
                            if tab == t {
                                Capsule().fill(p.scheme == .light ? Color.white : p.surface3)
                                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: seg)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .surface(p, radius: 21, fill: p.surface2)
        .haptic(.selection, trigger: tab)
    }

    // MARK: Messages

    private var messages: some View {
        let p = theme.palette
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if model.messages.isEmpty {
                        HomeDashboard(sensors: sensors, batterySaver: batterySaver, onPhoto: { attach(.camera) }) { model.send($0) }
                            .transition(.opacity.combined(with: .offset(y: 12)))
                    }
                    ForEach(model.messages) { m in
                        switch m.role {
                        case .user(let text): UserBubble(text: text, image: m.image).transition(.opacity.combined(with: .offset(y: 10)))
                        case .assistant(let turn): AssistantTurnView(turn: turn)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18).padding(.top, 118)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onScrolledPast(8) { scrolled = $0 }
            .onChange(of: model.messages) { withAnimation(ResQMotion.ease) { proxy.scrollTo("bottom", anchor: .bottom) } }
            .background(p.bg.opacity(0.001))
        }
    }
}

// MARK: - Pieces

struct LiveDot: View {
    @State private var on = false
    @Environment(\.palette) private var p
    var body: some View {
        Circle().fill(p.green).frame(width: 7, height: 7)
            .background(Circle().fill(p.green.opacity(0.35)).scaleEffect(on ? 2.2 : 1).opacity(on ? 0 : 1))
            .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) { on = true } }
    }
}

struct SOSButton: View {
    let action: () -> Void
    @State private var ring = false
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            Label("SOS", systemImage: "staroflife.fill")
                .font(.rq(size: 15, weight: .bold)).tracking(0.9)
                .foregroundStyle(p.glows ? .white : .black)
                .padding(.leading, 12).padding(.trailing, 16).frame(height: ResQRadius.tap)
                .background(
                    p.glows ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF5B50), Color(hex: 0xE0241A)], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(p.redDeep),
                    in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                .background(Capsule().strokeBorder(p.red.opacity(0.5), lineWidth: 1.5).padding(-4).scaleEffect(ring ? 1.18 : 0.96).opacity(ring ? 0 : 0.9))
                .shadow(color: p.glows ? Color(hex: 0xFF3B30).opacity(0.6) : .clear, radius: 12, y: 8)
        }
        .pressable()
        .accessibilityLabel("Mở màn hình SOS khẩn cấp")
        .onAppear { withAnimation(.easeOut(duration: 2.6).repeatForever(autoreverses: false)) { ring = true } }
    }
}

struct UserBubble: View {
    let text: String
    var image: Data? = nil
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let image {
                PhotoView(data: image)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.hair2))
            }
            Text(text)
                .font(ResQFont.body).foregroundStyle(p.text).lineSpacing(2)
                .padding(.horizontal, 15).padding(.vertical, 11)
                .background(p.scheme == .light ? Color(hex: 0xE6E6EB) : p.surface3,
                            in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 8, topTrailingRadius: 22, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 56)
    }
}

let quickPrompts: [(icon: String, text: String, danger: Bool)] = [
    ("cross.case", "Bạn tôi bị rắn cắn", true), ("backpack", "Chỉ có dao, dây dù, chai nhựa. Bắt cá?", false),
    ("drop", "Lọc nước suối", false), ("flame", "Nhóm lửa khi củi ướt", false),
]

/// Empty-state "field dashboard": daylight, battery, position, quick starts.
struct HomeDashboard: View {
    let sensors: FieldSensors
    let batterySaver: Bool
    var onPhoto: () -> Void = {}
    let onPick: (String) -> Void
    @Environment(\.palette) private var p

    private var location: LocationFix? { sensors.location }

    private var eyebrow: Text {
        let alt = location?.altitudeMeters.map { Text(Self.meters($0)).font(ResQFont.number(13, .medium)) }
        switch (sensors.place, alt) {
        case let (place?, alt?): return Text("\(place) · \(alt)")
        case let (place?, nil): return Text(place)
        case let (nil, alt?): return Text("Độ cao \(alt)")
        case (nil, nil): return Text(sensors.locationAllowed ? "Đang xác định vị trí…" : "Chưa có quyền vị trí")
        }
    }

    /// "2.184 m" (Vietnamese thousands separator).
    static func meters(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "\(Int(v))") + " m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label { eyebrow } icon: { Image(systemName: "mountain.2") }
            .font(.rq(size: 13, weight: .medium)).foregroundStyle(p.text3)
            Text(sensors.online ? "Đang có sóng.\n\(Text("ResQ vẫn chạy trên máy.").foregroundStyle(p.text3))"
                                : "Không có sóng.\n\(Text("Mọi thứ vẫn chạy.").foregroundStyle(p.text3))")
                .font(ResQFont.hero).tracking(-1).foregroundStyle(p.text).lineSpacing(0)
                .padding(.top, 10).padding(.bottom, 22)

            HStack(alignment: .top, spacing: 10) {
                SunTile(location: location)
                VStack(spacing: 10) {
                    tile(icon: sensors.charging ? "battery.100percent.bolt" : "battery.75percent", key: "Pin") {
                        let level = sensors.battery
                        Text(level.map { "\($0)%" } ?? "--").font(ResQFont.number(22))
                        Text(sensors.charging ? "Đang sạc" : level == nil ? "Máy không báo mức pin"
                             : batterySaver || sensors.lowPowerMode ? "Đang tiết kiệm pin" : "Tiết kiệm pin đang tắt")
                            .font(ResQFont.caption).foregroundStyle(p.text3)
                        Capsule().fill(p.surface3).frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in
                                    Capsule().fill((level ?? 100) < 20 ? p.red : p.green)
                                        .frame(width: g.size.width * CGFloat(level ?? 0) / 100)
                                }
                            }
                            .padding(.top, 6)
                    }
                    tile(icon: "location", key: "Vị trí · ±\(Int(location?.accuracyMeters ?? 0)) m") {
                        if let l = location {
                            Text(String(format: "%.5f\n%.5f", l.latitude, l.longitude)).font(ResQFont.number(15, .medium))
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                        } else if sensors.locationAllowed {
                            Text("Đang lấy GPS…").font(ResQFont.callout).foregroundStyle(p.text2)
                        } else {
                            Button("Cho phép vị trí") { sensors.requestLocationPermission() }
                                .font(ResQFont.callout.weight(.semibold)).foregroundStyle(p.accent).padding(.top, 4)
                        }
                    }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Bắt đầu nhanh").font(.rq(size: 17, weight: .semibold))
                Spacer()
                Text("hoặc gõ bên dưới").font(.rq(size: 13)).foregroundStyle(p.text3)
            }
            .padding(.top, 26).padding(.bottom, 12)

            Button(action: onPhoto) {
                HStack(spacing: 14) {
                    MushroomThumb().frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hair2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Chụp ảnh để tra cứu").font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text)
                        Text("Cây, nấm, vết thương, côn trùng").font(.rq(size: 12.5)).foregroundStyle(p.text3)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.right").font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text3).padding(12)
                }
                .surface(p)
            }
            .pressable()
            .padding(.bottom, 10)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(quickPrompts, id: \.text) { q in
                    Button { onPick(q.text) } label: {
                        VStack(alignment: .leading) {
                            Image(systemName: q.icon).font(.rq(size: 17))
                                .foregroundStyle(q.danger ? p.red : p.text)
                                .frame(width: 34, height: 34)
                                .background(q.danger ? p.redSoft : p.surface3, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Spacer(minLength: 14)
                            Text(q.text).font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text).multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                        .padding(14)
                        .surface(p)
                    }
                    .pressable()
                }
            }
        }
    }

    private func tile<C: View>(icon: String, key: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(key, systemImage: icon).font(ResQFont.caption).foregroundStyle(p.text3)
            content()
        }
        .foregroundStyle(p.text)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .surface(p)
    }
}

/// Daylight left (or time until sunrise) with a sun arc. Computed on device, see SunCalculator.
struct SunTile: View {
    let location: LocationFix?
    @Environment(\.palette) private var p

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            let state = location.flatMap { SunCalculator.daylight(now: ctx.date, latitude: $0.latitude, longitude: $0.longitude) }
            let (key, icon, remaining, foot, frac): (String, String, TimeInterval, String, Double?) = {
                switch state {
                case .untilSunset(let left, let set)?:
                    let total = 12.0 * 3600
                    return ("Ánh sáng còn lại", "sun.horizon", left, "Mặt trời lặn lúc \(Self.hm(set))", max(0, min(1, 1 - left / total)))
                case .untilSunrise(let left, let rise)?:
                    return ("Còn tối thêm", "moon", left, "Mặt trời mọc lúc \(Self.hm(rise))", nil)
                case nil:
                    return ("Ánh sáng", "sun.horizon", -1, "Cần vị trí để tính", nil)
                }
            }()
            VStack(alignment: .leading) {
                Label(key, systemImage: icon).font(ResQFont.caption).foregroundStyle(p.text3)
                SunArc(fraction: frac).frame(height: 62).padding(.vertical, 6)
                Group {
                    if remaining < 0 {
                        Text("--").font(ResQFont.number(28))
                    } else {
                        Text("\(Text("\(Int(remaining) / 3600)").font(ResQFont.number(28))) giờ \(Text(String(format: "%02d", Int(remaining) % 3600 / 60)).font(ResQFont.number(28))) phút")
                    }
                }
                .font(.rq(size: 18, weight: .medium)).foregroundStyle(p.text)
                .minimumScaleFactor(0.7).lineLimit(1)
                Text(foot).font(ResQFont.caption).foregroundStyle(p.text3)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
            .background(alignment: .bottom) {
                if p.glows { RadialGradient(colors: [p.accent.opacity(0.2), .clear], center: .bottom, startRadius: 0, endRadius: 140) }
            }
            .background(p.surface1)
            .clipShape(RoundedRectangle(cornerRadius: ResQRadius.l, style: .continuous))
            .surface(p, fill: .clear)
        }
    }

    static func hm(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

struct SunArc: View {
    /// nil = night (moon at the top), else 0…1 progress of the day.
    let fraction: Double?
    @Environment(\.palette) private var p

    var body: some View {
        Canvas { ctx, size in
            let r = CGSize(width: size.width / 2 - 8, height: size.height - 8)
            let c = CGPoint(x: size.width / 2, y: size.height - 2)
            func pt(_ t: Double) -> CGPoint {
                let a = Double.pi * (1 - t)
                return CGPoint(x: c.x + r.width * cos(a), y: c.y - r.height * sin(a))
            }
            var arc = Path(); arc.move(to: pt(0))
            for i in 1...60 { arc.addLine(to: pt(Double(i) / 60)) }
            ctx.stroke(arc, with: .color(p.hair2), style: StrokeStyle(lineWidth: 1.5, dash: [2, 4]))
            ctx.stroke(Path { $0.move(to: CGPoint(x: 0, y: c.y)); $0.addLine(to: CGPoint(x: size.width, y: c.y)) }, with: .color(p.hair2))
            if let f = fraction {
                var lit = Path(); lit.move(to: pt(0))
                for i in 1...60 { lit.addLine(to: pt(f * Double(i) / 60)) }
                ctx.stroke(lit, with: .linearGradient(Gradient(colors: [p.accent.opacity(0.15), p.accent]), startPoint: pt(0), endPoint: pt(f)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                let s = pt(f)
                ctx.fill(Path(ellipseIn: CGRect(x: s.x - 10, y: s.y - 10, width: 20, height: 20)), with: .color(p.accent.opacity(0.16)))
                ctx.fill(Path(ellipseIn: CGRect(x: s.x - 4.5, y: s.y - 4.5, width: 9, height: 9)), with: .color(p.accent))
            } else {
                let m = pt(0.5)
                ctx.draw(Text(Image(systemName: "moon.fill")).font(.system(size: 18)).foregroundStyle(p.text2), at: m)
            }
        }
    }
}

// MARK: - Composer

struct Composer: View {
    enum Attach: CaseIterable { case camera, library, guide, location }

    @Bindable var model: ChatViewModel
    var modelLabel = "E4B"
    var memoryGB = 8
    var onModel: () -> Void = {}
    var onAttach: (Attach) -> Void = { _ in }
    var onToast: (String, String) -> Void = { _, _ in }
    @State private var voice = VoiceInput()
    @State private var attachOpen = false
    @FocusState private var focused: Bool
    @Environment(\.palette) private var p

    private var listening: Bool { voice.isListening }

    var body: some View {
        let hasText = !model.draft.trimmingCharacters(in: .whitespaces).isEmpty || model.attachment != nil
        VStack(spacing: 8) {
            if attachOpen { attachPopover.transition(.scale(scale: 0.97, anchor: .bottomLeading).combined(with: .opacity).combined(with: .offset(y: 12))) }
            box(hasText: hasText)
        }
        .padding(.horizontal, 12).padding(.bottom, 8)
        .haptic(.impact(weight: .light), trigger: listening)
        .haptic(.impact(weight: .light), trigger: attachOpen)
    }

    private var attachPopover: some View {
        let items: [(Attach, String, String)] = [(.camera, "camera", "Chụp ảnh"), (.library, "photo.on.rectangle", "Thư viện"),
                                                 (.guide, "book", "Cẩm nang"), (.location, "location", "Vị trí")]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(items, id: \.2) { item in
                    Button {
                        withAnimation(ResQMotion.spring) { attachOpen = false }
                        onAttach(item.0)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.1).font(.rq(size: 20)).foregroundStyle(p.text)
                                .frame(width: 44, height: 44)
                                .background(p.surface3, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(item.2).font(.rq(size: 12)).foregroundStyle(p.text2)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 10)
                        .contentShape(Rectangle())
                    }
                    .pressable()
                }
            }
            Label("Ảnh dùng để mô tả đặc điểm, không để xác nhận ăn được.", systemImage: "info.circle")
                .font(.rq(size: 12)).foregroundStyle(p.text3)
                .padding(.horizontal, 8).padding(.bottom, 4)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(p.surface2.opacity(0.85), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(p.hair2))
        .shadow(color: .black.opacity(p.scheme == .light ? 0.15 : 0.6), radius: 30, y: 16)
    }

    private func box(hasText: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photo = model.attachment {
                ZStack(alignment: .topTrailing) {
                    PhotoView(data: photo).frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hair2))
                    Button { withAnimation(ResQMotion.spring) { model.attachment = nil } } label: {
                        Image(systemName: "xmark").font(.rq(size: 10, weight: .bold)).foregroundStyle(p.onSolid)
                            .frame(width: 22, height: 22).background(p.solid, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Bỏ ảnh").offset(x: 7, y: -7)
                }
                .padding(.top, 8)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if listening {
                HStack(spacing: 12) {
                    Waveform(levels: voice.levels).frame(height: 40)
                    Text(voice.onDevice ? "Đang nghe · trên máy" : "Đang nghe · cần mạng").font(.rq(size: 13)).foregroundStyle(p.text3)
                        .lineLimit(1).minimumScaleFactor(0.8).layoutPriority(1)
                    Button { withAnimation(ResQMotion.spring) { voice.stop() } } label: {
                        Image(systemName: "stop.fill").foregroundStyle(.white).frame(width: 38, height: 38).background(p.red, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Dừng nghe")
                }
                .frame(minHeight: 76)
                .transition(.opacity)
            } else {
                TextField("Hỏi ResQ…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.rq(size: 16.5)).foregroundStyle(p.text)
                    .focused($focused)
                    .onSubmit { send() }
                    .padding(.top, 5)
                HStack(spacing: 6) {
                    Button { withAnimation(ResQMotion.spring) { attachOpen.toggle() } } label: {
                        Image(systemName: "plus").font(.rq(size: 17, weight: .medium)).rotationEffect(.degrees(attachOpen ? 135 : 0))
                            .frame(width: 38, height: 38).background(p.surface3, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Đính kèm")
                    Button(action: onModel) {
                        HStack(spacing: 7) { LiveDot(); Text(modelLabel).font(.rq(size: 13)); Text("\(memoryGB) GB").font(ResQFont.number(12, .regular)).foregroundStyle(p.text3) }
                            .foregroundStyle(p.text2).padding(.horizontal, 11).frame(height: 38)
                            .overlay(Capsule().strokeBorder(p.hair))
                    }
                    .pressable()
                    Spacer()
                    ZStack(alignment: .trailing) {
                        if model.isBusy {
                            circleButton("stop.fill", label: "Dừng") { model.cancel() }
                        } else if hasText {
                            circleButton("arrow.up", label: "Gửi") { send() }
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        } else {
                            Button { startListening() } label: {
                                Label("Nói", systemImage: "waveform").font(.rq(size: 14, weight: .semibold))
                                    .foregroundStyle(p.onSolid).padding(.horizontal, 14).frame(height: 38).background(p.solid, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                    .animation(ResQMotion.spring, value: hasText)
                    .animation(ResQMotion.spring, value: model.isBusy)
                }
            }
        }
        .foregroundStyle(p.text)
        .padding(.leading, 16).padding([.trailing, .vertical], 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: ResQRadius.xl, style: .continuous))
        .background(p.surface2.opacity(0.7), in: RoundedRectangle(cornerRadius: ResQRadius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ResQRadius.xl, style: .continuous).strokeBorder(p.hair2))
        .shadow(color: .black.opacity(p.scheme == .light ? 0.15 : 0.6), radius: 30, y: 16)
    }

    private func send() {
        focused = false
        model.send()
    }

    private func startListening() {
        focused = false
        attachOpen = false
        let base = model.draft.trimmingCharacters(in: .whitespaces)
        Task {
            await voice.start(onText: { text in
                model.draft = base.isEmpty ? text : base + " " + text
            }, onEnd: { failure in
                switch failure {
                case .denied?: onToast("Cần quyền micro và nhận dạng giọng nói trong Cài đặt", "mic.slash")
                case .unavailable?: onToast("Máy chưa có nhận dạng giọng nói tiếng Việt", "mic.slash")
                case .audio?: onToast("Không mở được micro", "mic.slash")
                case nil: break
                }
            })
        }
    }

    private func circleButton(_ icon: String, label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.rq(size: 16, weight: .bold)).foregroundStyle(p.onSolid)
                .frame(width: 38, height: 38).background(p.solid, in: Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// Live microphone level bars (newest on the right). Shows as many recent bars as fit.
struct Waveform: View {
    let levels: [CGFloat]
    @Environment(\.palette) private var p
    var body: some View {
        GeometryReader { g in
            let shown = Array(levels.suffix(max(1, Int((g.size.width + 3) / 6))))
            HStack(spacing: 3) {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, l in
                    Capsule().fill(p.text).frame(width: 3, height: 4 + l * 30)
                }
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .trailing)
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}

extension View {
    /// Header turns into glass once content scrolls under it (iOS 18+; stays transparent on iOS 17).
    @ViewBuilder
    func onScrolledPast(_ y: CGFloat, _ action: @escaping (Bool) -> Void) -> some View {
        if #available(iOS 18, macOS 15, *) {
            onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y > y } action: { _, new in action(new) }
        } else {
            self
        }
    }

    @ViewBuilder
    func sosPresentation<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(isPresented: isPresented, content: content)
        #else
        sheet(isPresented: isPresented, content: content)
        #endif
    }
}
