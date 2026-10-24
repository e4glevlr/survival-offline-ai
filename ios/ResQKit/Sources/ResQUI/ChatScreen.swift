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
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: drawerOpen ? 0 : -geo.size.width * 0.2)
                    .allowsHitTesting(drawerOpen)
                    // Sits under the shell when closed; keep VoiceOver from reaching it.
                    .accessibilityHidden(!drawerOpen)
                // The shell slides aside and dims; tapping it closes the drawer.
                shell
                    .overlay {
                        Color.black.opacity(drawerOpen ? 0.45 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(drawerOpen)
                            .onTapGesture { withAnimation(ResQMotion.ease) { drawerOpen = false } }
                    }
                    .overlay(alignment: .leading) { if drawerOpen { Rectangle().fill(p.hair).frame(width: 1).ignoresSafeArea() } }
                    .offset(x: drawerOpen ? geo.size.width * 0.8 : 0)
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
        return HStack {
            Button { withAnimation(ResQMotion.ease) { drawerOpen = true } } label: {
                Image(systemName: "line.3.horizontal").font(.rq(size: 18, weight: .regular))
                    .frame(width: ResQRadius.tap, height: ResQRadius.tap)
                    .contentShape(Rectangle())
            }
            .pressable()
            .accessibilityLabel("Mở menu")
            Spacer()
            segmented
            Spacer()
            SOSButton { showSOS = true }
        }
        .foregroundStyle(p.text)
        .padding(.leading, 6).padding(.trailing, 14).padding(.bottom, 6)
        .background {
            p.bg.overlay(alignment: .bottom) { Rectangle().fill(p.hair).frame(height: 1).opacity(scrolled ? 1 : 0) }.ignoresSafeArea()
        }
        .animation(ResQMotion.ease, value: scrolled)
    }

    private var segmented: some View {
        let p = theme.palette
        // Plain text tabs; the active one is brighter, with a short underline that slides between them.
        return HStack(spacing: 22) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(ResQMotion.spring) { tab = t; scrolled = false } } label: {
                    Text(t.rawValue).font(.rq(size: 16, weight: tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? p.text : p.text3)
                        .frame(height: ResQRadius.tap)
                        .overlay(alignment: .bottom) {
                            if tab == t {
                                Capsule().fill(p.text).frame(width: 16, height: 2).offset(y: -6)
                                    .matchedGeometryEffect(id: "pill", in: seg)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
                .padding(.horizontal, 18).padding(.top, 66)
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

struct SOSButton: View {
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            Text("SOS")
                .font(.rq(size: 14, weight: .bold)).tracking(1)
                .foregroundStyle(p.glows || p.scheme == .light ? .white : .black)
                .padding(.horizontal, 15).frame(height: 34)
                .background(p.redDeep, in: Capsule())
                .frame(height: ResQRadius.tap).contentShape(Rectangle())
        }
        .pressable()
        .accessibilityLabel("Mở màn hình SOS khẩn cấp")
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
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(p.scheme == .light ? Color(hex: 0xEDEDF0) : p.surface2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 56)
    }
}

let quickPrompts: [(icon: String, text: String, danger: Bool)] = [
    ("cross.case", "Bạn tôi bị rắn cắn", true), ("backpack", "Chỉ có dao, dây dù, chai nhựa. Bắt cá?", false),
    ("drop", "Lọc nước suối", false), ("flame", "Nhóm lửa khi củi ướt", false),
]

/// Empty state: one headline, three readings between hairlines, quick starts as a plain list.
struct HomeDashboard: View {
    let sensors: FieldSensors
    let batterySaver: Bool
    var onPhoto: () -> Void = {}
    let onPick: (String) -> Void
    @Environment(\.palette) private var p

    private var location: LocationFix? { sensors.location }

    private var eyebrow: String {
        let alt = location?.altitudeMeters.map(Self.meters)
        switch (sensors.place, alt) {
        case let (place?, alt?): return "\(place) · \(alt)"
        case let (place?, nil): return place
        case let (nil, alt?): return "Độ cao \(alt)"
        case (nil, nil): return sensors.locationAllowed ? "Đang xác định vị trí…" : "Chưa có quyền vị trí"
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
            Text(eyebrow).font(.rq(size: 13)).foregroundStyle(p.text3)
            Text(sensors.online ? "Đang có sóng.\n\(Text("ResQ vẫn chạy trên máy.").foregroundStyle(p.text3))"
                                : "Không có sóng.\n\(Text("Mọi thứ vẫn chạy.").foregroundStyle(p.text3))")
                .font(.rq(size: 28, weight: .semibold)).tracking(-0.8).foregroundStyle(p.text)
                .padding(.top, 8).padding(.bottom, 30)

            readings

            Text("Bắt đầu nhanh").font(.rq(size: 13)).foregroundStyle(p.text3)
                .padding(.top, 36).padding(.bottom, 2)
            VStack(spacing: 0) {
                row("camera", "Chụp ảnh để tra cứu", sub: "Cây, nấm, vết thương, côn trùng", action: onPhoto)
                ForEach(quickPrompts, id: \.text) { q in
                    Rectangle().fill(p.hair).frame(height: 1).padding(.leading, 38)
                    row(q.icon, q.text, tint: q.danger ? p.red : nil) { onPick(q.text) }
                }
            }
        }
    }

    private var readings: some View {
        HStack(alignment: .top, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                switch location.flatMap({ SunCalculator.daylight(now: ctx.date, latitude: $0.latitude, longitude: $0.longitude) }) {
                case .untilSunset(let left, let set)?: reading("Còn sáng", Self.hm(left), foot: "Lặn \(Self.clock(set))")
                case .untilSunrise(let left, let rise)?: reading("Còn tối", Self.hm(left), foot: "Mọc \(Self.clock(rise))")
                case nil: reading("Ánh sáng", "--:--", foot: "Cần vị trí")
                }
            }
            reading(sensors.charging ? "Pin · sạc" : "Pin", sensors.battery.map { "\($0)%" } ?? "--",
                    foot: sensors.battery == nil ? "Không rõ" : batterySaver || sensors.lowPowerMode ? "Tiết kiệm" : "Bình thường",
                    alert: (sensors.battery ?? 100) < 20)
            VStack(alignment: .leading, spacing: 6) {
                Text(location.map { "Vị trí ±\(Int($0.accuracyMeters)) m" } ?? "Vị trí").font(.rq(size: 12)).foregroundStyle(p.text3)
                if let l = location {
                    Text(String(format: "%.4f\n%.4f", l.latitude, l.longitude)).font(ResQFont.number(15)).foregroundStyle(p.text)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                } else if sensors.locationAllowed {
                    Text("Đang lấy GPS…").font(.rq(size: 14)).foregroundStyle(p.text2)
                } else {
                    Button("Cho phép") { sensors.requestLocationPermission() }
                        .font(.rq(size: 14, weight: .medium)).foregroundStyle(p.accent).buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(p.hair).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(p.hair).frame(height: 1) }
    }

    private func reading(_ key: String, _ value: String, foot: String, alert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(key).font(.rq(size: 12)).foregroundStyle(p.text3)
            Text(value).font(ResQFont.number(24, .medium)).tracking(-0.5).foregroundStyle(alert ? p.red : p.text)
            Text(foot).font(.rq(size: 12)).foregroundStyle(p.text3).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ icon: String, _ title: String, sub: String? = nil, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.rq(size: 17)).foregroundStyle(tint ?? p.text2).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.rq(size: 16)).foregroundStyle(p.text).multilineTextAlignment(.leading)
                    if let sub { Text(sub).font(.rq(size: 13)).foregroundStyle(p.text3) }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Remaining time as "H:MM".
    static func hm(_ t: TimeInterval) -> String { "\(Int(t) / 3600):\(String(format: "%02d", Int(t) % 3600 / 60))" }

    static func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
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
                                .background(p.surface2, in: Circle())
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
        .background(p.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(p.hair2))
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
                HStack(spacing: 2) {
                    Button { withAnimation(ResQMotion.spring) { attachOpen.toggle() } } label: {
                        Image(systemName: "plus").font(.rq(size: 18)).foregroundStyle(p.text2)
                            .rotationEffect(.degrees(attachOpen ? 45 : 0))
                            .frame(width: 36, height: 36).overlay(Circle().strokeBorder(p.hair2))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Đính kèm")
                    Button(action: onModel) {
                        HStack(spacing: 4) {
                            Text(modelLabel).font(.rq(size: 13.5, weight: .medium))
                            Image(systemName: "chevron.down").font(.rq(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(p.text3).padding(.horizontal, 10).frame(height: 36)
                        .contentShape(Rectangle())
                    }
                    .pressable()
                    .accessibilityLabel("Mô hình \(modelLabel), \(memoryGB) GB")
                    Spacer()
                    ZStack(alignment: .trailing) {
                        if model.isBusy {
                            circleButton("stop.fill", label: "Dừng") { model.cancel() }
                        } else if hasText {
                            circleButton("arrow.up", label: "Gửi") { send() }
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else {
                            circleButton("waveform", label: "Nói") { startListening() }
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .animation(ResQMotion.spring, value: hasText)
                    .animation(ResQMotion.spring, value: model.isBusy)
                }
            }
        }
        .foregroundStyle(p.text)
        .padding(.leading, 14).padding(.trailing, 8).padding(.top, 10).padding(.bottom, 8)
        .background(p.surface1, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(focused ? p.hair2 : p.hair))
        .animation(ResQMotion.ease, value: focused)
        // Solid fade behind the box so messages don't show through below it.
        .background(alignment: .bottom) {
            LinearGradient(colors: [p.bg.opacity(0), p.bg], startPoint: .top, endPoint: .center)
                .padding(.horizontal, -12).padding(.top, -24).padding(.bottom, -60)
                .allowsHitTesting(false)
        }
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
            Image(systemName: icon).font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.onSolid)
                .frame(width: 36, height: 36).background(p.solid, in: Circle())
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
