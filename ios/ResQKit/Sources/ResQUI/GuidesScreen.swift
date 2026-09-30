import SwiftUI
import ResQCore

/// "Cẩm nang" tab: offline search, emergency cards, skill pillars, saved articles. Works without the model.
struct GuidesView: View {
    let onCard: (EmergencyCard) -> Void
    let onArticle: (GuideLibrary.Article) -> Void
    var onPillar: (GuideLibrary.Pillar) -> Void = { _ in }
    var onSaved: (UserStore.SavedItem) -> Void = { _ in }
    let onScrolled: (Bool) -> Void
    private var store: UserStore { .shared }
    @State private var query = ""
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Cẩm nang").font(.rq(size: 34, weight: .bold)).tracking(-1.2).foregroundStyle(p.text)
                Text(GuideLibrary.summary).font(.rq(size: 14)).foregroundStyle(p.text3)
                    .padding(.top, 6).padding(.bottom, 16)
                search
                results

                SectionHeader(title: "Khẩn cấp", trailing: "không cần AI")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(GuideLibrary.cards) { c in
                            EmergencyTile(card: c, width: 138, height: 142) { onCard(c) }
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 2)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .padding(.horizontal, -18)

                SectionHeader(title: "Kỹ năng", trailing: "6 trụ cột")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(GuideLibrary.pillars) { pl in PillarTile(pillar: pl) { onPillar(pl) } }
                }

                SectionHeader(title: "Đã lưu", trailing: store.saved.isEmpty ? nil : "\(store.saved.count) mục")
                if store.saved.isEmpty {
                    Label("Bấm \(Image(systemName: "bookmark")) dưới câu trả lời hoặc trong bài cẩm nang để lưu lại, xem được cả khi không có sóng.",
                          systemImage: "bookmark")
                        .labelStyle(.titleOnly)
                        .font(.rq(size: 14)).foregroundStyle(p.text3)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .surface(p, radius: 20)
                } else {
                    ResQGroup {
                        ForEach(Array(store.saved.enumerated()), id: \.element.id) { i, item in
                            if i > 0 { RowDivider() }
                            Button {
                                if item.kind == .article, let a = GuideLibrary.articles.first(where: { $0.title == item.title }) { onArticle(a) } else { onSaved(item) }
                            } label: {
                                ResQRow(icon: item.kind == .article ? "book.fill" : "bubble.left.fill",
                                        tint: item.kind == .article ? Color(hex: 0x0A84FF) : Color(hex: 0xFF7A2F),
                                        title: item.title, subtitle: (item.kind == .article ? "Bài cẩm nang · " : "Câu trả lời · ") + RelativeDay.label(item.date)) {
                                    Image(systemName: "chevron.right").font(.rq(size: 14, weight: .semibold)).foregroundStyle(p.text3)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Bỏ lưu", systemImage: "bookmark.slash", role: .destructive) { store.remove(saved: item) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 118).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onScrolledPast(8, onScrolled)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.rq(size: 17)).foregroundStyle(p.text3)
            TextField("", text: $query, prompt: Text("Tìm kỹ năng, gõ không dấu cũng được").foregroundStyle(p.text3))
                .font(.rq(size: 16)).foregroundStyle(p.text)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(p.text3) }
                    .buttonStyle(.plain).accessibilityLabel("Xoá")
            }
            Text("offline").font(ResQFont.number(11, .medium)).foregroundStyle(p.text3)
                .padding(.horizontal, 7).padding(.vertical, 5)
                .background(p.surface3, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.leading, 14).padding(.trailing, 8).frame(height: 46)
        .background(p.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(p.hair))
    }

    @ViewBuilder
    private var results: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let hits = GuideLibrary.search(query)
            Text("\(Text("\(hits.count)").font(ResQFont.number(13, .medium))) kết quả cho “\(query)” · khớp cả không dấu")
                .font(.rq(size: 13)).foregroundStyle(p.text3)
                .padding(.top, 10).padding(.bottom, hits.isEmpty ? 0 : 10)
            if !hits.isEmpty {
                ResQGroup {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { i, hit in
                        if i > 0 { RowDivider() }
                        hitRow(hit)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hitRow(_ hit: GuideLibrary.Hit) -> some View {
        let chevron = Image(systemName: "chevron.right").font(.rq(size: 14, weight: .semibold)).foregroundStyle(p.text3)
        switch hit {
        case .card(let c):
            Button { onCard(c) } label: {
                ResQRow(icon: GuideLibrary.icon(for: c), tint: p.red, title: c.title, subtitle: "Thẻ khẩn cấp · \(c.steps.count) bước") { chevron }
            }
            .buttonStyle(.plain)
        case .article(let a):
            Button { onArticle(a) } label: { ResQRow(icon: a.icon, tint: a.tint, title: a.title, subtitle: a.meta) { chevron } }
                .buttonStyle(.plain)
        case .pillar(let pl):
            Button { onPillar(pl) } label: { ResQRow(icon: pl.icon, tint: pl.tint, title: pl.title, subtitle: pl.countLabel) { chevron } }
                .buttonStyle(.plain)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    @Environment(\.palette) private var p

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.rq(size: 17, weight: .semibold)).foregroundStyle(p.text)
            Spacer()
            if let trailing { Text(trailing).font(.rq(size: 13)).foregroundStyle(p.text3) }
        }
        .padding(.top, 26).padding(.bottom, 12)
    }
}

/// Dark-red "pass" tile that opens an emergency card. Used in Guides and SOS.
struct EmergencyTile: View {
    let card: EmergencyCard
    var width: CGFloat? = nil
    var height: CGFloat = 104
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: GuideLibrary.icon(for: card)).font(.rq(size: 25)).foregroundStyle(p.red)
                Spacer(minLength: 0)
                Text(card.title).font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.text)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Text("\(card.steps.count) bước").font(.rq(size: 12)).foregroundStyle(p.text3)
            }
            .padding(14)
            .frame(width: width, height: height, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .background(LinearGradient(colors: [p.passTop, p.passBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(p.passLine))
        }
        .pressable()
    }
}

struct PillarTile: View {
    let pillar: GuideLibrary.Pillar
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        let tint = p.glows || p.scheme == .light ? pillar.tint : p.accent
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: pillar.icon).font(.rq(size: 18)).foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Spacer(minLength: 0)
                Text(pillar.title).font(.rq(size: 15.5, weight: .semibold)).tracking(-0.3).foregroundStyle(p.text)
                    .multilineTextAlignment(.leading)
                Text(pillar.countLabel).font(.rq(size: 12)).foregroundStyle(p.text3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .leading)
            .background(alignment: .topTrailing) {
                Image(systemName: pillar.icon).font(.rq(size: 80)).foregroundStyle(tint.opacity(0.07)).offset(x: 12, y: -12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .surface(p)
        }
        .pressable()
    }
}

// MARK: - Article sheet

/// One guide article: steps as a checklist, then warnings. The water-filter article also gets its diagram.
struct ArticleSheet: View {
    let article: GuideLibrary.Article
    let onAsk: () -> Void
    @State private var done: Set<Int> = []
    @Environment(\.palette) private var p
    private var store: UserStore { .shared }
    private var plainText: String {
        let steps = article.steps.enumerated().map { "\($0.offset + 1). " + $0.element.replacingOccurrences(of: "**", with: "") }
        let warnings = article.warnings.isEmpty ? [] : ["Lưu ý:"] + article.warnings
        return ([article.title] + steps + warnings).joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(article.pillar).font(.rq(size: 13, weight: .medium)).foregroundStyle(p.text3)
                    Spacer()
                    let saved = store.isSaved(title: article.title)
                    Button { store.toggleSaved(kind: .article, title: article.title, body: plainText) } label: {
                        Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.rq(size: 18))
                            .foregroundStyle(saved ? p.accent : p.text2).frame(width: 40, height: 40)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain).accessibilityLabel(saved ? "Bỏ lưu" : "Lưu bài")
                    .haptic(.success, trigger: saved)
                    Button { Speaker.shared.toggle(plainText, id: "article") } label: {
                        Image(systemName: Speaker.shared.speakingID == "article" ? "stop.circle" : "speaker.wave.2").font(.rq(size: 18))
                            .foregroundStyle(p.text2).frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Đọc to")
                }
                .padding(.top, -8)
                Text(article.title).font(.rq(size: 24, weight: .bold)).tracking(-0.8).foregroundStyle(p.text)
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    Tag("\(article.minutes) phút", icon: "clock", tone: .muted)
                    Tag("Nguồn cấp \(article.trust)", icon: "checkmark.seal", tone: article.trust == "C" ? .muted : .ok)
                    Text(article.source).font(.rq(size: 12, weight: .semibold)).foregroundStyle(p.text2)
                        .padding(.horizontal, 9).frame(height: 24).background(p.surface2, in: Capsule())
                }
                .padding(.top, 10)

                Text(article.summary).font(.rq(size: 15)).foregroundStyle(p.text2)
                    .padding(.top, 12).padding(.bottom, article.id == "water-bottle-filter" ? 0 : 12)

                if article.id == "water-bottle-filter" {
                    FilterDiagram()
                        .padding(14)
                        .surface(p, fill: p.surface2)
                        .padding(.top, 14).padding(.bottom, 12)
                }

                HStack(spacing: 10) {
                    Text("Tiến độ").font(.rq(size: 13)).foregroundStyle(p.text3)
                    Capsule().fill(p.surface3).frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { g in Capsule().fill(p.green).frame(width: g.size.width * CGFloat(done.count) / CGFloat(article.steps.count)) }
                        }
                    Text("\(done.count)/\(article.steps.count)").font(ResQFont.number(13, .medium)).foregroundStyle(p.text2)
                }
                .animation(ResQMotion.ease, value: done)

                VStack(spacing: 0) {
                    ForEach(Array(article.steps.enumerated()), id: \.offset) { i, s in
                        let on = done.contains(i)
                        Button {
                            if on { done.remove(i) } else { done.insert(i) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(on ? p.green : .clear)
                                    Circle().strokeBorder(on ? .clear : p.hair2, lineWidth: 1.5)
                                    if on { Image(systemName: "checkmark").font(.rq(size: 12, weight: .bold)).foregroundStyle(p.onSolid) }
                                    else { Text("\(i + 1)").font(ResQFont.number(13)).foregroundStyle(p.text2) }
                                }
                                .frame(width: 26, height: 26)
                                Text(.init(s)).font(.rq(size: 16)).foregroundStyle(on ? p.text3 : p.text)
                                    .strikethrough(on, color: p.text3)
                                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12).padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(p.hair).frame(height: 1)
                    }
                }
                .padding(.top, 6)
                .haptic(.impact(weight: .light), trigger: done)

                if !article.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("LƯU Ý", systemImage: "exclamationmark.triangle.fill")
                            .font(.rq(size: 12, weight: .semibold)).foregroundStyle(p.amber)
                        ForEach(article.warnings, id: \.self) { w in
                            Text(w).font(.rq(size: 15)).foregroundStyle(p.text).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                    .background(p.amberSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 16)
                }

                Button(action: onAsk) {
                    Label("Hỏi ResQ về bài này", systemImage: "bubble.left.and.bubble.right")
                        .font(.rq(size: 16, weight: .semibold)).foregroundStyle(p.onSolid)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(p.solid, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .pressable()
                .padding(.top, 20)
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }
}

/// Layered bottle filter diagram (the prototype's inline SVG).
struct FilterDiagram: View {
    @Environment(\.palette) private var p
    static let layers: [(String, Color)] = [
        ("Sỏi to", Color(hex: 0x8A837C)), ("Sỏi nhỏ", Color(hex: 0xA9A29A)), ("Cát mịn", Color(hex: 0xD8C9A2)),
        ("Than củi", Color(hex: 0x3F4148)), ("Vải", Color(hex: 0xC9CED8)),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 4) {
                Text("NƯỚC ĐỤC").font(ResQFont.number(10.5, .medium)).foregroundStyle(p.text2)
                Image(systemName: "arrow.down").font(.rq(size: 13, weight: .bold)).foregroundStyle(p.blue)
                VStack(spacing: 3) {
                    ForEach(Self.layers, id: \.0) { l in
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(l.1).frame(height: 24)
                    }
                }
                .padding(5)
                .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30, style: .continuous).strokeBorder(p.hair2, lineWidth: 1.5))
                Image(systemName: "arrow.down").font(.rq(size: 13, weight: .bold)).foregroundStyle(p.blue)
            }
            .frame(width: 128)
            VStack(alignment: .leading, spacing: 3) {
                Color.clear.frame(height: 36)
                ForEach(Self.layers, id: \.0) { l in
                    Text(l.0).font(.rq(size: 12.5)).foregroundStyle(p.text2).frame(height: 24, alignment: .leading)
                }
                Spacer(minLength: 8)
                Text("Lọc xong vẫn\nphải đun sôi").font(.rq(size: 11.5, weight: .medium)).foregroundStyle(p.amber)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Stylised mushroom photo used for the "Chụp ảnh để tra cứu" card.
struct MushroomThumb: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 100
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0x34502E), Color(hex: 0x142214), Color(hex: 0x050905)]),
                                           center: CGPoint(x: size.width * 0.56, y: size.height * 0.34), startRadius: 0, endRadius: size.width * 0.8))
            ctx.fill(Path(ellipseIn: CGRect(x: -20 * s, y: 86 * s, width: 140 * s, height: 30 * s)), with: .color(Color(hex: 0x1B2D15)))
            var stem = Path()
            stem.move(to: CGPoint(x: 46 * s, y: 40 * s)); stem.addLine(to: CGPoint(x: 43 * s, y: 94 * s))
            stem.addLine(to: CGPoint(x: 57 * s, y: 94 * s)); stem.addLine(to: CGPoint(x: 54 * s, y: 40 * s)); stem.closeSubpath()
            ctx.fill(stem, with: .linearGradient(Gradient(colors: [Color(hex: 0xBFB6A3), Color(hex: 0xFFFAF0), Color(hex: 0xAEA48F)]),
                                                 startPoint: CGPoint(x: 43 * s, y: 0), endPoint: CGPoint(x: 57 * s, y: 0)))
            var veil = Path()
            veil.move(to: CGPoint(x: 42 * s, y: 44 * s))
            veil.addQuadCurve(to: CGPoint(x: 30 * s, y: 88 * s), control: CGPoint(x: 38 * s, y: 70 * s))
            veil.addQuadCurve(to: CGPoint(x: 70 * s, y: 88 * s), control: CGPoint(x: 50 * s, y: 96 * s))
            veil.addQuadCurve(to: CGPoint(x: 58 * s, y: 44 * s), control: CGPoint(x: 62 * s, y: 70 * s))
            ctx.stroke(veil, with: .color(Color(hex: 0xFAF5E8).opacity(0.6)), style: StrokeStyle(lineWidth: 0.8 * s, dash: [1.5 * s, 1.2 * s]))
            var cap = Path()
            cap.move(to: CGPoint(x: 38 * s, y: 46 * s))
            cap.addQuadCurve(to: CGPoint(x: 50 * s, y: 18 * s), control: CGPoint(x: 39 * s, y: 22 * s))
            cap.addQuadCurve(to: CGPoint(x: 62 * s, y: 46 * s), control: CGPoint(x: 61 * s, y: 22 * s))
            cap.addQuadCurve(to: CGPoint(x: 38 * s, y: 46 * s), control: CGPoint(x: 50 * s, y: 51 * s))
            ctx.fill(cap, with: .linearGradient(Gradient(colors: [Color(hex: 0xEFE1B8), Color(hex: 0xB59A63), Color(hex: 0x6D5733)]),
                                                startPoint: CGPoint(x: 0, y: 18 * s), endPoint: CGPoint(x: 0, y: 50 * s)))
        }
    }
}

// MARK: - Pillar and saved-answer sheets

/// What this build ships for one skill pillar.
struct PillarSheet: View {
    let pillar: GuideLibrary.Pillar
    let onCard: (EmergencyCard) -> Void
    let onArticle: (GuideLibrary.Article) -> Void
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: pillar.icon).font(.rq(size: 20)).foregroundStyle(pillar.tint)
                        .frame(width: 42, height: 42)
                        .background(pillar.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    SheetTitle(title: pillar.title, sub: pillar.countLabel)
                }
                .padding(.bottom, 18)
                if pillar.articles.isEmpty && pillar.cards.isEmpty {
                    Text("Bản này chưa có bài cho mục này. Bài sẽ có khi cài gói tri thức đầy đủ.")
                        .font(.rq(size: 15)).foregroundStyle(p.text2)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .surface(p, radius: 20)
                } else {
                    ResQGroup {
                        ForEach(Array(pillar.articles.enumerated()), id: \.element.id) { i, a in
                            if i > 0 { RowDivider() }
                            Button { onArticle(a) } label: {
                                ResQRow(icon: a.icon, tint: a.tint, title: a.title, subtitle: a.meta) { chevron }
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Array(pillar.cards.enumerated()), id: \.element.id) { i, c in
                            if i > 0 || !pillar.articles.isEmpty { RowDivider() }
                            Button { onCard(c) } label: {
                                ResQRow(icon: GuideLibrary.icon(for: c), tint: p.red, title: c.title, subtitle: "Thẻ khẩn cấp · \(c.steps.count) bước") { chevron }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.rq(size: 14, weight: .semibold)).foregroundStyle(p.text3)
    }
}

/// A saved answer, readable offline.
struct SavedAnswerSheet: View {
    let item: UserStore.SavedItem
    let onRemoved: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Đã lưu · \(RelativeDay.label(item.date)) \(RelativeDay.time(item.date))").font(.rq(size: 13, weight: .medium)).foregroundStyle(p.text3)
                Text(item.title).font(.rq(size: 22, weight: .bold)).tracking(-0.6).foregroundStyle(p.text)
                Text(item.body).font(ResQFont.body).foregroundStyle(p.text).lineSpacing(4).textSelection(.enabled)
                HStack(spacing: 10) {
                    Button { Speaker.shared.toggle(item.body, id: item.id.uuidString) } label: {
                        Label(Speaker.shared.speakingID == item.id.uuidString ? "Dừng đọc" : "Đọc to", systemImage: "speaker.wave.2")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(p.surface2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    Button(role: .destructive) {
                        UserStore.shared.remove(saved: item)
                        onRemoved()
                    } label: {
                        Label("Bỏ lưu", systemImage: "bookmark.slash")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(p.surface2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
                .font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.text)
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }
}
