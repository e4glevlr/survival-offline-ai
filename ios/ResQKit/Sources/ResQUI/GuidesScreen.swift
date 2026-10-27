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
                Text("Cẩm nang").font(.rq(size: 28, weight: .semibold)).tracking(-0.8).foregroundStyle(p.text)
                Text(GuideLibrary.summary).font(.rq(size: 14)).foregroundStyle(p.text3)
                    .padding(.top, 6).padding(.bottom, 16)
                search
                results

                SectionHeader(title: "Khẩn cấp", trailing: "không cần AI")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(GuideLibrary.cards) { c in
                            EmergencyTile(card: c, width: 132, height: 96) { onCard(c) }
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
            .padding(.horizontal, 18).padding(.top, 66).padding(.bottom, 40)
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
        }
        .padding(.horizontal, 14).frame(height: 44)
        .background(p.surface1, in: Capsule())
        .overlay(Capsule().strokeBorder(p.hair))
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
            Text(title).font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text2)
            Spacer()
            if let trailing { Text(trailing).font(.rq(size: 13)).foregroundStyle(p.text3) }
        }
        .padding(.top, 30).padding(.bottom, 10)
    }
}

/// Emergency card tile: red symbol, title, step count. Used in Guides and SOS.
struct EmergencyTile: View {
    let card: EmergencyCard
    var width: CGFloat? = nil
    var height: CGFloat = 112
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: GuideLibrary.icon(for: card)).font(.rq(size: 18)).foregroundStyle(p.red)
                Spacer(minLength: 0)
                Text(card.title).font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Text("\(card.steps.count) bước").font(.rq(size: 12.5)).foregroundStyle(p.text3)
            }
            .padding(14)
            .frame(width: width, height: height, alignment: .leading)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .surface(p, radius: 18)
        }
        .pressable()
    }
}

struct PillarTile: View {
    let pillar: GuideLibrary.Pillar
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: pillar.icon).font(.rq(size: 18)).foregroundStyle(p.text2)
                Spacer(minLength: 0)
                Text(pillar.title).font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text)
                    .multilineTextAlignment(.leading).lineLimit(2)
                Text(pillar.countLabel).font(.rq(size: 12.5)).foregroundStyle(p.text3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
            .surface(p, radius: 18)
        }
        .pressable()
    }
}

// MARK: - Article sheet

/// One guide article: picture (with numbered pins when it has a figure), steps as a checklist, then warnings.
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
                if article.hasFigure {
                    GuideFigureView(articleId: article.id, imageRadius: 20)
                        .padding(.top, 4).padding(.bottom, 12)
                } else if article.hasCover {
                    CoverImage(articleId: article.id, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true)
                        .padding(.top, 4).padding(.bottom, 10)
                }
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
                    .padding(.top, 12).padding(.bottom, 12)

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
