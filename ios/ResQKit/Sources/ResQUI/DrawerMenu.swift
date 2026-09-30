import SwiftUI
import ResQCore

/// Side menu revealed behind the shell (the shell slides right and scales down).
struct DrawerMenu: View {
    enum Action { case newChat, sos, guides, prep, settings, history(String) }

    let modelTier: ModelTier
    let onAction: (Action) -> Void
    @Environment(\.palette) private var p
    @Environment(FieldSensors.self) private var sensors: FieldSensors?
    private var store: UserStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "safari.fill").font(.rq(size: 20)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: [Color(hex: 0xFF9A52), Color(hex: 0xFF5A1F)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: p.glows ? Color(hex: 0xFF5A1F).opacity(0.6) : .clear, radius: 10, y: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ResQ").font(.rq(size: 18, weight: .bold)).tracking(-0.5).foregroundStyle(p.text)
                    HStack(spacing: 6) {
                        Circle().fill(p.green).frame(width: 6, height: 6)
                        Text("Sẵn sàng ngoại tuyến").font(.rq(size: 12)).foregroundStyle(p.text3)
                    }
                }
            }
            .padding(.top, 4).padding(.bottom, 18)

            Button { onAction(.newChat) } label: {
                Label("Cuộc hỏi mới", systemImage: "square.and.pencil")
                    .font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.onSolid)
                    .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .background(p.solid, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .pressable()

            VStack(spacing: 0) {
                navItem("staroflife.fill", "SOS khẩn cấp", iconColor: p.red) { onAction(.sos) }
                navItem("book", "Cẩm nang") { onAction(.guides) }
                navItem("checklist", "Trước chuyến đi") { onAction(.prep) }
                navItem("slider.horizontal.3", "Cài đặt") { onAction(.settings) }
            }
            .padding(.top, 14).padding(.bottom, 6)

            HStack {
                Text("Gần đây").font(.rq(size: 12, weight: .semibold)).tracking(1.2).textCase(.uppercase).foregroundStyle(p.text3)
                Spacer()
                if !store.history.isEmpty {
                    Button("Xoá") { withAnimation(ResQMotion.ease) { store.clearHistory() } }
                        .font(.rq(size: 12, weight: .semibold)).foregroundStyle(p.text3).buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.top, 14).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if store.history.isEmpty {
                        Text("Chưa có câu hỏi nào. Các câu bạn hỏi sẽ hiện ở đây, lưu ngay trên máy.")
                            .font(.rq(size: 13)).foregroundStyle(p.text3).padding(.horizontal, 6).padding(.vertical, 9)
                    }
                    ForEach(store.history) { h in
                        Button { onAction(.history(h.question)) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(h.question).font(.rq(size: 14.5)).foregroundStyle(p.text2).lineLimit(1)
                                Text(RelativeDay.label(h.date) + (h.hasImage ? " · có ảnh" : "")).font(.rq(size: 12)).foregroundStyle(p.text3)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 9)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(Self.deviceName) · \(sensors?.memoryGB ?? 0) GB").font(.rq(size: 14, weight: .semibold)).foregroundStyle(p.text).padding(.bottom, 2)
                meter("Mô hình", value: modelTier == .searchOnly ? 0 : 1, color: p.green, trailing: modelTier.chipName)
                let battery = sensors?.battery
                meter("Pin", value: Double(battery ?? 0) / 100, color: (battery ?? 100) < 20 ? p.red : p.text2,
                      trailing: battery.map { "\($0)%" } ?? "--", mono: true)
                let t = Self.thermal(sensors?.thermal ?? .nominal, p)
                meter("Nhiệt", value: t.value, color: t.color, trailing: t.label)
            }
            .font(.rq(size: 12.5)).foregroundStyle(p.text3)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .surface(p, radius: 18)
        }
        .padding(.leading, 18).padding(.trailing, 14).padding(.top, 14).padding(.bottom, 16)
    }

    static var deviceName: String {
        #if os(iOS)
        UIDevice.current.model
        #else
        "Mac"
        #endif
    }

    static func thermal(_ t: ThermalLevel, _ p: ResQPalette) -> (value: Double, color: Color, label: String) {
        switch t {
        case .nominal: (0.25, p.green, "Ổn")
        case .fair: (0.5, p.green, "Ấm")
        case .serious: (0.75, p.amber, "Nóng")
        case .critical: (1, p.red, "Quá nóng")
        }
    }

    private func navItem(_ icon: String, _ title: String, iconColor: Color? = nil, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.rq(size: 17)).foregroundStyle(iconColor ?? p.text3).frame(width: 24)
                Text(title).font(.rq(size: 15)).foregroundStyle(p.text2)
            }
            .padding(.horizontal, 6).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .pressable()
    }

    private func meter(_ label: String, value: Double, color: Color, trailing: String, mono: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label).frame(width: 54, alignment: .leading)
            Capsule().fill(p.surface3).frame(height: 4)
                .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(color).frame(width: g.size.width * value) } }
            Text(trailing).font(mono ? ResQFont.number(12, .regular) : .rq(size: 12.5))
                .lineLimit(1).fixedSize().frame(minWidth: 30, alignment: .trailing)
        }
    }
}
