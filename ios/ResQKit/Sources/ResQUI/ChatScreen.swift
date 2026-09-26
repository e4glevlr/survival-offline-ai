import SwiftUI
import ResQCore

public struct DeviceStatusLine: Sendable {
    public var model: String      // "Gemma 4 E2B"
    public var battery: Int       // 64
    public var place: String      // "Hoàng Liên Sơn"
    public init(model: String, battery: Int, place: String) {
        self.model = model
        self.battery = battery
        self.place = place
    }
}

public struct ChatScreen: View {
    @State private var model: ChatViewModel
    @State private var tab: Tab = .ask
    @State private var showSOS = false
    @State private var theme: ResQTheme = .dark
    @State private var scrolled = false
    @Namespace private var seg
    let status: DeviceStatusLine
    let location: LocationFix?

    enum Tab: String, CaseIterable { case ask = "Hỏi", guides = "Cẩm nang" }

    public init(model: ChatViewModel, status: DeviceStatusLine, location: LocationFix? = nil) {
        _model = State(initialValue: model)
        self.status = status
        self.location = location
    }

    public var body: some View {
        let p = theme.palette
        ZStack(alignment: .top) {
            p.bg.ignoresSafeArea()
            if p.glows {
                RadialGradient(colors: [p.accent.opacity(0.10), .clear], center: .top, startRadius: 0, endRadius: 420).ignoresSafeArea()
            }
            if tab == .ask {
                messages.safeAreaInset(edge: .bottom) { Composer(model: model) }
            } else {
                // Guides screen: see design/resq_prototype.html (Cẩm nang). Search works without the LLM.
                ContentUnavailableView("Cẩm nang", systemImage: "book", description: Text("Xem prototype HTML"))
                    .frame(maxHeight: .infinity)
            }
            header
        }
        .environment(\.palette, p)
        .preferredColorScheme(p.scheme)
        .tint(p.accent)
        .sosPresentation(isPresented: $showSOS) {
            SOSScreen(location: location, onClose: { showSOS = false }).environment(\.palette, p)
        }
    }

    // MARK: Header

    private var header: some View {
        let p = theme.palette
        return VStack(spacing: 8) {
            HStack {
                Menu {
                    Button("Cuộc hỏi mới", systemImage: "square.and.pencil") { withAnimation(ResQMotion.ease) { model.newConversation() } }
                    Picker("Giao diện", selection: $theme) {
                        ForEach(ResQTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal").font(.system(size: 17, weight: .medium))
                        .frame(width: ResQRadius.tap, height: ResQRadius.tap)
                        .surface(p, radius: ResQRadius.tap / 2, fill: p.surface2)
                }
                Spacer()
                segmented
                Spacer()
                SOSButton { showSOS = true }
            }
            HStack(spacing: 7) {
                LiveDot()
                Text("Ngoại tuyến")
                Circle().fill(p.text3).frame(width: 3, height: 3)
                Text(status.model)
                Circle().fill(p.text3).frame(width: 3, height: 3)
                Text("\(status.battery)%").font(ResQFont.number(12, .medium))
            }
            .font(.system(size: 12)).foregroundStyle(p.text2)
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
                Button { withAnimation(ResQMotion.spring) { tab = t } } label: {
                    Text(t.rawValue).font(.system(size: 14, weight: .semibold))
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
        .sensoryFeedback(.selection, trigger: tab)
    }

    // MARK: Messages

    private var messages: some View {
        let p = theme.palette
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if model.messages.isEmpty {
                        HomeDashboard(status: status, location: location) { model.send($0) }
                            .transition(.opacity.combined(with: .offset(y: 12)))
                    }
                    ForEach(model.messages) { m in
                        switch m.role {
                        case .user(let text): UserBubble(text: text).transition(.opacity.combined(with: .offset(y: 10)))
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
                .font(.system(size: 15, weight: .bold)).tracking(0.9)
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
    @Environment(\.palette) private var p

    var body: some View {
        Text(text)
            .font(ResQFont.body).foregroundStyle(p.text).lineSpacing(2)
            .padding(.horizontal, 15).padding(.vertical, 11)
            .background(p.scheme == .light ? Color(hex: 0xE6E6EB) : p.surface3,
                        in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 8, topTrailingRadius: 22, style: .continuous))
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
    let status: DeviceStatusLine
    let location: LocationFix?
    let onPick: (String) -> Void
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("\(status.place) · \(Text(location.flatMap { $0.altitudeMeters }.map { "\(Int($0)) m" } ?? "").font(ResQFont.number(13, .medium)))")
            } icon: { Image(systemName: "mountain.2") }
            .font(.system(size: 13, weight: .medium)).foregroundStyle(p.text3)
            Text("Không có sóng.\n\(Text("Mọi thứ vẫn chạy.").foregroundStyle(p.text3))")
                .font(ResQFont.hero).tracking(-1).foregroundStyle(p.text).lineSpacing(0)
                .padding(.top, 10).padding(.bottom, 22)

            HStack(alignment: .top, spacing: 10) {
                SunTile(location: location)
                VStack(spacing: 10) {
                    tile(icon: "battery.75percent", key: "Pin") {
                        Text("\(status.battery)%").font(ResQFont.number(22))
                        Text("~9 giờ khi tiết kiệm").font(ResQFont.caption).foregroundStyle(p.text3)
                        Capsule().fill(p.surface3).frame(height: 4)
                            .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(p.green).frame(width: g.size.width * CGFloat(status.battery) / 100) } }
                            .padding(.top, 6)
                    }
                    tile(icon: "location", key: "Vị trí · ±\(Int(location?.accuracyMeters ?? 0)) m") {
                        if let l = location {
                            Text(String(format: "%.5f\n%.5f", l.latitude, l.longitude)).font(ResQFont.number(15, .medium))
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
                        } else {
                            Text("Đang lấy GPS…").font(ResQFont.callout).foregroundStyle(p.text2)
                        }
                    }
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Bắt đầu nhanh").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text("hoặc gõ bên dưới").font(.system(size: 13)).foregroundStyle(p.text3)
            }
            .padding(.top, 26).padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(quickPrompts, id: \.text) { q in
                    Button { onPick(q.text) } label: {
                        VStack(alignment: .leading) {
                            Image(systemName: q.icon).font(.system(size: 17))
                                .foregroundStyle(q.danger ? p.red : p.text)
                                .frame(width: 34, height: 34)
                                .background(q.danger ? p.redSoft : p.surface3, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Spacer(minLength: 14)
                            Text(q.text).font(.system(size: 15, weight: .medium)).foregroundStyle(p.text).multilineTextAlignment(.leading)
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
                    return ("Ánh sáng", "sun.horizon", 0, "Chưa có vị trí", nil)
                }
            }()
            VStack(alignment: .leading) {
                Label(key, systemImage: icon).font(ResQFont.caption).foregroundStyle(p.text3)
                SunArc(fraction: frac).frame(height: 62).padding(.vertical, 6)
                Text("\(Text("\(Int(remaining) / 3600)").font(ResQFont.number(28))) giờ \(Text(String(format: "%02d", Int(remaining) % 3600 / 60)).font(ResQFont.number(28))) phút")
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(p.text)
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
        f.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
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
    @Bindable var model: ChatViewModel
    @State private var listening = false
    @State private var attachOpen = false
    @Environment(\.palette) private var p

    var body: some View {
        let hasText = !model.draft.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: 8) {
            if listening {
                HStack(spacing: 12) {
                    Waveform().frame(height: 40)
                    Text("Đang nghe · trên máy").font(.system(size: 13)).foregroundStyle(p.text3).fixedSize()
                    Button { withAnimation(ResQMotion.spring) { listening = false } } label: {
                        Image(systemName: "stop.fill").foregroundStyle(.white).frame(width: 38, height: 38).background(p.red, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Dừng nghe")
                }
                .frame(minHeight: 76)
                .transition(.opacity)
            } else {
                TextField("Hỏi ResQ…", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 16.5)).foregroundStyle(p.text)
                    .onSubmit { model.send() }
                    .padding(.top, 5)
                HStack(spacing: 6) {
                    Button { withAnimation(ResQMotion.spring) { attachOpen.toggle() } } label: {
                        Image(systemName: "plus").font(.system(size: 17, weight: .medium)).rotationEffect(.degrees(attachOpen ? 135 : 0))
                            .frame(width: 38, height: 38).background(p.surface3, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Đính kèm")
                    HStack(spacing: 7) { LiveDot(); Text("E2B").font(.system(size: 13)); Text("8 GB").font(ResQFont.number(12, .regular)).foregroundStyle(p.text3) }
                        .foregroundStyle(p.text2).padding(.horizontal, 11).frame(height: 38)
                        .overlay(Capsule().strokeBorder(p.hair))
                    Spacer()
                    ZStack(alignment: .trailing) {
                        if model.isBusy {
                            circleButton("stop.fill", label: "Dừng") { model.cancel() }
                        } else if hasText {
                            circleButton("arrow.up", label: "Gửi") { model.send() }
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        } else {
                            Button { withAnimation(ResQMotion.spring) { listening = true } } label: {
                                Label("Nói", systemImage: "waveform").font(.system(size: 14, weight: .semibold))
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
        .padding(.horizontal, 12).padding(.bottom, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: listening)
    }

    private func circleButton(_ icon: String, label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(p.onSolid)
                .frame(width: 38, height: 38).background(p.solid, in: Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }
}

/// Live input level bars. Feed real mic levels from the speech recognizer in the app.
struct Waveform: View {
    @Environment(\.palette) private var p
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<30, id: \.self) { i in
                    Capsule().fill(p.text)
                        .frame(width: 3, height: 4 + abs(sin(t * 5.5 + Double(i) * 0.7)) * 26 * (0.45 + 0.55 * abs(sin(Double(i) * 1.3 + t))))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
