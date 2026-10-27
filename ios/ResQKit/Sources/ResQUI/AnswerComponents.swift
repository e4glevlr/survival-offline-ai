import SwiftUI
import ResQCore

// MARK: - Tag

public struct Tag: View {
    public enum Tone { case ok, warn, danger, muted }
    let text: String
    let icon: String
    let tone: Tone
    @Environment(\.palette) private var p

    public init(_ text: String, icon: String, tone: Tone) {
        self.text = text
        self.icon = icon
        self.tone = tone
    }

    public var body: some View {
        // Plain inline label: only the icon carries the tone, the text stays quiet.
        let fg: Color = switch tone {
        case .ok: p.green
        case .warn: p.amber
        case .danger: p.red
        case .muted: p.text3
        }
        HStack(spacing: 5) {
            Image(systemName: icon).font(.rq(size: 12, weight: .medium)).foregroundStyle(fg)
            Text(text).font(.rq(size: 13, weight: .medium)).foregroundStyle(tone == .muted ? p.text3 : p.text2)
        }
        .frame(height: 22)
        .fixedSize()
    }
}

extension AnswerStatus {
    @MainActor var tag: Tag {
        switch self {
        case .supported: Tag("Có căn cứ", icon: "checkmark.seal", tone: .ok)
        case .insufficientEvidence: Tag("Không đủ căn cứ", icon: "questionmark.circle", tone: .warn)
        case .conflict: Tag("Nguồn mâu thuẫn", icon: "exclamationmark.triangle", tone: .warn)
        }
    }
}

// MARK: - Emergency pass (reviewed, deterministic, shown before the model)

public struct EmergencyPassView: View {
    let card: EmergencyCard
    @State private var done: Set<Int> = []
    @Environment(\.palette) private var p

    public init(card: EmergencyCard) { self.card = card }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: GuideLibrary.icon(for: card))
                    .font(.rq(size: 19, weight: .semibold))
                    .foregroundStyle(p.glows || p.scheme == .light ? .white : p.onSolid)
                    .frame(width: 40, height: 40)
                    .background(p.redDeep, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("THẺ KHẨN CẤP").font(.rq(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(p.red)
                    Text(card.title).font(ResQFont.title).foregroundStyle(p.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Đã làm").font(ResQFont.caption).foregroundStyle(p.text3)
                    Text("\(done.count)/\(card.steps.count)").font(ResQFont.number(15)).foregroundStyle(p.text)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 10)

            // Each step is tappable: people tick them off while doing first aid.
            VStack(spacing: 2) {
                ForEach(Array(card.steps.enumerated()), id: \.offset) { i, step in
                    Button {
                        withAnimation(ResQMotion.spring) { if done.contains(i) { done.remove(i) } else { done.insert(i) } }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            ZStack {
                                Circle().strokeBorder(p.passLine, lineWidth: 1.5).opacity(done.contains(i) ? 0 : 1)
                                Circle().fill(p.green).opacity(done.contains(i) ? 1 : 0)
                                if done.contains(i) {
                                    Image(systemName: "checkmark").font(.rq(size: 13, weight: .bold)).foregroundStyle(.white)
                                } else {
                                    Text("\(i + 1)").font(ResQFont.number(14)).foregroundStyle(p.text)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            Text(step).font(ResQFont.body).foregroundStyle(done.contains(i) ? p.text3 : p.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .haptic(.selection, trigger: done.contains(i))
                }
            }
            .padding(.horizontal, 8)

            if !card.doNot.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "nosign").font(.rq(size: 17, weight: .semibold)).foregroundStyle(p.red)
                    Text("\(Text("Không ").fontWeight(.semibold).foregroundStyle(p.text))\(card.doNot.joined(separator: ", ")).")
                        .font(ResQFont.callout).foregroundStyle(p.text2)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(p.scheme == .light ? p.redSoft : .black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16).padding(.top, 8)
            }

            HStack(spacing: 8) {
                Label("\(card.sourceLabel) · \(card.reviewedAt)", systemImage: "checkmark.seal")
                    .font(ResQFont.caption).foregroundStyle(p.text3)
                Spacer()
                let reading = Speaker.shared.speakingID == card.spokenID
                Button { Speaker.shared.toggle(card.spokenText, id: card.spokenID) } label: {
                    Image(systemName: reading ? "stop.fill" : "speaker.wave.2.fill")
                        .font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.text)
                        .frame(width: 42, height: 42).background(p.text.opacity(0.08), in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain).accessibilityLabel(reading ? "Dừng đọc" : "Đọc to thẻ")
                if let hotline = card.hotline, let url = URL(string: "tel:\(hotline)") {
                    // Hotline comes from structured data, never from the LLM.
                    Link(destination: url) {
                        Label("Gọi \(hotline)", systemImage: "phone.fill")
                            .font(.rq(size: 15, weight: .semibold)).foregroundStyle(p.onSolid)
                            .padding(.horizontal, 18).frame(height: 42)
                            .background(p.solid, in: Capsule())
                    }
                }
            }
            .padding(16)
        }
        .background(LinearGradient(colors: [p.passTop, p.passBottom], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(p.passLine))
        .accessibilityElement(children: .contain)
    }
}

extension EmergencyCard {
    var spokenID: String { "card-" + id }
    /// Hotline is read from structured data, same as the call button.
    var spokenText: String {
        var parts = ["Thẻ khẩn cấp: \(title)."]
        parts += steps.enumerated().map { "Bước \($0.offset + 1). \($0.element)" }
        if !doNot.isEmpty { parts.append("Không \(doNot.joined(separator: ", ")).") }
        if let hotline { parts.append("Gọi \(hotline.map(String.init).joined(separator: " ")) khi có sóng.") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Citations inline

struct ItemText: View {
    let item: AnswerItem
    var font: Font = ResQFont.body
    @Environment(\.palette) private var p

    var body: some View {
        // One Text so citation numbers wrap with the sentence (prototype: inline .c chips).
        item.citations.reduce(Text(item.text).foregroundStyle(p.text)) { acc, label in
            let cite = Text(" \(label.dropFirst())").font(ResQFont.number(12)).foregroundStyle(p.text2)
            return Text("\(acc)\(cite)")
        }
        .font(font)
        .lineSpacing(3)
        .accessibilityLabel("\(item.text). Nguồn \(item.citations.map { String($0.dropFirst()) }.joined(separator: ", "))")
    }
}

// MARK: - Structured answer sections

struct AnswerSectionView: View {
    enum Kind { case doIt, doNot, escalate }
    let kind: Kind
    let items: [AnswerItem]
    @Environment(\.palette) private var p

    var body: some View {
        let (title, tint): (String, Color) = switch kind {
        case .doIt: ("Làm ngay", p.green)
        case .doNot: ("Không được", p.red)
        case .escalate: ("Khi nào cần cấp cứu", p.amber)
        }
        // Reads like a chat answer: a bold heading, then a plain list. Color only marks the heading dot and the ✕.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(title).font(.rq(size: 16, weight: .semibold)).foregroundStyle(p.text)
            }
            if kind == .escalate, let item = items.first {
                ItemText(item: item)
                    .padding(.leading, 14).padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) { Capsule().fill(tint).frame(width: 2) }
                    .padding(.top, 6)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Group {
                                if kind == .doIt {
                                    Text("\(i + 1).").font(ResQFont.number(15, .regular)).foregroundStyle(p.text3)
                                } else {
                                    Image(systemName: "xmark").font(.rq(size: 12, weight: .semibold)).foregroundStyle(p.red)
                                }
                            }
                            .frame(minWidth: 20, alignment: .leading)
                            ItemText(item: item).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    }
                }
            }
        }
    }
}

// MARK: - Sources

struct SourcesStrip: View {
    let evidence: [EvidenceBlock]
    @State private var open: EvidenceBlock?
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                // Compact citation chips: number + section name; tap opens the passage.
                HStack(spacing: 6) {
                    ForEach(evidence) { e in
                        Button { open = e } label: {
                            HStack(spacing: 7) {
                                Text(e.label.dropFirst()).font(ResQFont.number(11, .medium)).foregroundStyle(p.text2)
                                    .frame(width: 18, height: 18).background(p.surface3, in: Circle())
                                Text(e.block.headingPath.components(separatedBy: " › ").last ?? "")
                                    .font(.rq(size: 13)).foregroundStyle(p.text2).lineLimit(1)
                            }
                            .padding(.leading, 6).padding(.trailing, 12).frame(height: 32)
                            .frame(maxWidth: 220, alignment: .leading)
                            .background(p.surface1, in: Capsule())
                            .overlay(Capsule().strokeBorder(p.hair))
                        }
                        .pressable()
                        .accessibilityLabel("Nguồn \(e.label.dropFirst()): \(e.block.headingPath), \(e.block.sourceLabel)")
                    }
                }
                .padding(.horizontal, 18)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -18)
        }
        .sheet(item: $open) { e in
            SourceSheet(evidence: e)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                .presentationBackground(p.surface1)
                .environment(\.palette, p)
        }
    }
}

/// The passage an answer relied on, with the cited sentence highlighted.
struct SourceSheet: View {
    let evidence: EvidenceBlock
    @Environment(\.palette) private var p

    var body: some View {
        let path = evidence.block.headingPath.components(separatedBy: " › ")
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nguồn \(evidence.label.dropFirst()) · \(path.dropLast().joined(separator: " › "))")
                    .font(.rq(size: 13, weight: .medium)).foregroundStyle(p.text3)
                Text(path.last ?? "").font(.rq(size: 22, weight: .bold)).tracking(-0.6).foregroundStyle(p.text)
                HStack(spacing: 6) {
                    Tag("Nguồn cấp \(evidence.block.trust.rawValue.uppercased())", icon: "checkmark.seal",
                        tone: evidence.block.trust == .a ? .ok : .muted)
                    Tag(evidence.block.sourceLabel, icon: "book.closed", tone: .muted)
                }
                Text(Self.highlighted(evidence.block.text, p))
                    .font(.rq(size: 16)).foregroundStyle(p.text2).lineSpacing(5)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .surface(p, radius: 18, fill: p.surface2)
                    .padding(.top, 4)
                Text("Phần được tô là câu ResQ dựa vào để trả lời.").font(.rq(size: 12.5)).foregroundStyle(p.text3)
            }
            .padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 26)
        }
        .scrollIndicators(.hidden)
    }

    /// `**…**` in the passage marks the cited sentence.
    static func highlighted(_ text: String, _ p: ResQPalette) -> AttributedString {
        var out = AttributedString()
        for (i, part) in text.components(separatedBy: "**").enumerated() {
            var a = AttributedString(part)
            if i % 2 == 1 {
                a.foregroundColor = p.text
                a.backgroundColor = p.accentSoft
            }
            out += a
        }
        return out
    }
}

// MARK: - Guide visuals

/// Opens a guide article sheet; set by the chat screen.
struct OpenArticleAction {
    var run: @MainActor (GuideLibrary.Article) -> Void = { _ in }
    @MainActor func callAsFunction(_ a: GuideLibrary.Article) { run(a) }
}

extension EnvironmentValues {
    @Entry var openArticle = OpenArticleAction()
}

extension GuideLibrary.Article {
    var hasFigure: Bool { GuideFigure.has(id) }
    var hasCover: Bool { GuideArt.available.contains(id) }
}

/// The guide's picture for this answer, inline under the summary. Tapping opens the article.
struct GuideVisual: View {
    let article: GuideLibrary.Article
    @Environment(\.openArticle) private var openArticle
    @Environment(\.palette) private var p

    var body: some View {
        Button { openArticle(article) } label: {
            VStack(alignment: .leading, spacing: 0) {
                if article.hasFigure {
                    GuideFigureView(articleId: article.id, interactive: false, legendInset: 14).padding(.bottom, 12)
                } else {
                    CoverImage(articleId: article.id, contentMode: .fit)
                }
                Rectangle().fill(p.hair).frame(height: 1)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(article.hasFigure ? "Hình trong cẩm nang" : "Bài trong cẩm nang").font(.rq(size: 12)).foregroundStyle(p.text3)
                        Text(article.title).font(.rq(size: 15, weight: .medium)).foregroundStyle(p.text).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("\(article.steps.count) bước").font(.rq(size: 13)).foregroundStyle(p.text3)
                    Image(systemName: "chevron.right").font(.rq(size: 13, weight: .semibold)).foregroundStyle(p.text3)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .surface(p, radius: 20)
        }
        .pressable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hình minh hoạ: \(article.title). \(GuideFigure.specs[article.id]?.alt ?? article.summary)")
        .accessibilityHint("Mở bài cẩm nang")
        .accessibilityAddTraits(.isButton)
    }
}

/// Guide articles behind the answer, as tappable cards with their picture or pillar icon.
struct RelatedGuides: View {
    let title: String
    let articles: [GuideLibrary.Article]
    @Environment(\.openArticle) private var openArticle
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.rq(size: 13)).foregroundStyle(p.text3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(articles) { a in
                        Button { openArticle(a) } label: { card(a) }
                            .pressable()
                            .accessibilityLabel("\(a.title), \(a.meta)")
                            .accessibilityHint("Mở bài cẩm nang")
                    }
                }
                .padding(.horizontal, 18)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -18)
        }
    }

    private func card(_ a: GuideLibrary.Article) -> some View {
        HStack(spacing: 10) {
            Group {
                if a.hasCover {
                    CoverImage(articleId: a.id)
                } else {
                    Image(systemName: a.icon).font(.rq(size: 18)).foregroundStyle(a.tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(a.tint.opacity(0.14))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title).font(.rq(size: 14, weight: .medium)).foregroundStyle(p.text).lineLimit(2)
                    .multilineTextAlignment(.leading)
                Label(a.hasFigure ? "\(a.steps.count) bước · có hình" : "\(a.steps.count) bước",
                      systemImage: a.hasFigure ? "photo" : "list.number")
                    .font(.rq(size: 12)).foregroundStyle(p.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8).padding(.trailing, 6)
        .frame(width: 236, alignment: .leading)
        .surface(p, radius: 16)
    }
}

// MARK: - Assistant turn

/// Shimmering "reading" label (CSS .shimmer).
struct ReadingLabel: View {
    let text: String
    @State private var phase: CGFloat = -1
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 10) {
            Text(text).font(.rq(size: 14, weight: .medium)).foregroundStyle(p.text3)
                .overlay {
                    LinearGradient(colors: [.clear, p.text, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 80).offset(x: phase * 160)
                        .mask(Text(text).font(.rq(size: 14, weight: .medium)))
                }
        }
        .onAppear { withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}

public struct AssistantTurnView: View {
    let turn: AssistantTurn
    @AppStorage(ResQSettings.readAloud) private var readAloud = true
    @Environment(\.palette) private var p

    public init(turn: AssistantTurn) { self.turn = turn }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let card = turn.card {
                HStack(spacing: 8) {
                    Tag("Khẩn cấp", icon: "staroflife", tone: .danger)
                    Text("hiện sau 0,1 s, không cần AI").font(ResQFont.caption).foregroundStyle(p.text3)
                }
                EmergencyPassView(card: card).transition(.scale(scale: 0.97).combined(with: .opacity))
            }
            if let notice = turn.notice { Tag(notice, icon: "battery.25percent", tone: .muted) }
            if turn.isStreaming && turn.answer == nil {
                ReadingLabel(text: turn.evidence.isEmpty ? "Đang tìm trong cẩm nang…" : "Đang đọc \(turn.evidence.count) nguồn trong cẩm nang…")
            }
            if let reason = turn.noAnswer, reason == .greeting || reason == .thanks {
                Text(reason == .thanks
                     ? "Không có gì. Cần gì cứ hỏi tiếp, ResQ chạy ngay trên máy, không cần sóng."
                     : "Chào bạn. Mình là ResQ, trả lời về sinh tồn và sơ cứu bằng cẩm nang trên máy. Bạn đang gặp chuyện gì, ở đâu, có những đồ gì?")
                    .font(ResQFont.lead).foregroundStyle(p.text).lineSpacing(4)
            } else if let reason = turn.noAnswer {
                header(Tag(reason == .llmDisabled ? "Chỉ tra cứu" : "Không đủ căn cứ", icon: "questionmark.circle", tone: .warn))
                Text(reason == .llmDisabled
                     ? "AI đang tắt (chế độ chỉ tra cứu hoặc pin quá yếu). Thẻ và các nguồn liên quan ở bên dưới."
                     : "Cẩm nang trên máy chưa có hướng dẫn đủ sát cho câu này, nên ResQ không tự trả lời. Hãy hỏi cụ thể hơn: bạn đang ở đâu, có những đồ gì.")
                    .font(ResQFont.lead).foregroundStyle(p.text).lineSpacing(4)
                if !turn.guideArticles.isEmpty {
                    RelatedGuides(title: "Bài gần nhất trong cẩm nang", articles: turn.guideArticles)
                }
            }
            if let a = turn.answer {
                header(turn.status?.tag ?? (turn.stopped ? Tag("Đã dừng", icon: "stop.circle", tone: .muted)
                                                          : Tag("Đang viết", icon: "ellipsis", tone: .muted)))
                if !a.summary.isEmpty {
                    ItemText(item: AnswerItem(text: a.summary, citations: a.summaryCitations), font: ResQFont.lead)
                }
                if let v = turn.visualArticle {
                    GuideVisual(article: v).transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
                if !a.immediateActions.isEmpty { AnswerSectionView(kind: .doIt, items: a.immediateActions) }
                if !a.doNot.isEmpty { AnswerSectionView(kind: .doNot, items: a.doNot) }
                if let e = a.escalation { AnswerSectionView(kind: .escalate, items: [e]) }
                let more = turn.guideArticles.filter { $0.id != turn.visualArticle?.id }
                if !turn.isStreaming && !more.isEmpty {
                    RelatedGuides(title: "Đọc thêm trong cẩm nang", articles: more)
                }
            }
            if turn.failed {
                Tag("Lỗi khi tạo câu trả lời. Thẻ và nguồn vẫn dùng được", icon: "exclamationmark.triangle", tone: .warn)
            }
            if !turn.evidence.isEmpty { SourcesStrip(evidence: turn.evidence) }
            if !turn.isStreaming && turn.noAnswer != .greeting && turn.noAnswer != .thanks { ActionRow(turn: turn) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(ResQMotion.ease, value: turn)
        .task(id: turn.card?.id) {
            // "Tự đọc to thẻ khẩn cấp": once per turn, hands-free while doing first aid.
            guard let card = turn.card, turn.isStreaming, readAloud else { return }
            Speaker.shared.speakOnce(card.spokenText, id: card.spokenID, key: turn.question)
        }
    }

    private func header(_ tag: Tag) -> some View {
        HStack(spacing: 6) {
            tag
            Text("· \(turn.evidence.count) nguồn").font(.rq(size: 13)).foregroundStyle(p.text3)
        }
    }
}

struct ActionRow: View {
    let turn: AssistantTurn
    @State private var copied = false
    @State private var pinned = false
    @Environment(FieldSensors.self) private var sensors: FieldSensors?
    @Environment(\.palette) private var p
    private var store: UserStore { .shared }

    private var speechID: String { "answer-" + turn.question }
    private var title: String { turn.question }

    var body: some View {
        let speaking = Speaker.shared.speakingID == speechID
        let saved = store.isSaved(title: title)
        let text = turn.plainText
        HStack(spacing: 4) {
            action(speaking ? "waveform" : "speaker.wave.2", on: speaking, label: speaking ? "Dừng đọc" : "Đọc to") {
                Speaker.shared.toggle(text, id: speechID)
            }
            .symbolEffect(.variableColor.iterative, isActive: speaking)
            action(copied ? "checkmark" : "doc.on.doc", on: copied, label: "Sao chép") {
                #if os(iOS)
                UIPasteboard.general.string = text
                #endif
                copied = true
                Task { try? await Task.sleep(for: .seconds(2)); copied = false }
            }
            action(pinned ? "mappin.circle.fill" : "mappin.and.ellipse", on: pinned, label: "Ghim vị trí") {
                guard let fix = sensors?.location else { return }
                store.pin(fix, note: title)
                pinned = true
            }
            .disabled(sensors?.location == nil)
            action(saved ? "bookmark.fill" : "bookmark", on: saved, label: saved ? "Bỏ lưu" : "Lưu") {
                store.toggleSaved(kind: .answer, title: title, body: text)
            }
            if pinned {
                Text("Đã ghim · xem trong SOS").font(ResQFont.caption).foregroundStyle(p.text3).transition(.opacity)
            }
        }
        .padding(.leading, -8)
        .animation(ResQMotion.ease, value: pinned)
    }

    private func action(_ icon: String, on: Bool, label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.rq(size: 17)).foregroundStyle(on ? p.green : p.text3)
                .frame(width: 38, height: 38).contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .haptic(.success, trigger: on)
    }
}

extension AssistantTurn {
    /// Guide articles behind the evidence, most-cited in the answer first, then by retrieval rank.
    var guideArticles: [GuideLibrary.Article] {
        var cites: [String: Int] = [:]
        if let a = answer {
            let items = a.immediateActions + a.doNot + (a.escalation.map { [$0] } ?? [])
            for label in a.summaryCitations + items.flatMap(\.citations) { cites[label, default: 0] += 1 }
        }
        var counts: [String: Int] = [:], order: [String] = []
        for e in evidence where GuideLibrary.article(e.block.articleId) != nil {
            if counts[e.block.articleId] == nil { order.append(e.block.articleId) }
            counts[e.block.articleId, default: 0] += cites[e.label, default: 0]
        }
        return order.enumerated()
            .sorted { (counts[$0.element]!, -$0.offset) > (counts[$1.element]!, -$1.offset) }
            .compactMap { GuideLibrary.article($0.element) }
    }

    /// Article whose picture goes inline under the summary: among those the summary cites, one with a
    /// figure first, else one with a cover. The summary is committed as a whole line, so this never
    /// flips mid-stream.
    var visualArticle: GuideLibrary.Article? {
        guard let a = answer else { return nil }
        let cited = a.summaryCitations.compactMap { label in
            evidence.first { $0.label == label }.flatMap { GuideLibrary.article($0.block.articleId) }
        }
        return cited.first(where: \.hasFigure) ?? cited.first(where: \.hasCover)
    }

    /// Answer as plain text (copy, save, read aloud). Citation labels are dropped.
    var plainText: String {
        var lines: [String] = []
        if let a = answer {
            if !a.summary.isEmpty { lines.append(a.summary) }
            if !a.immediateActions.isEmpty {
                lines.append("Làm ngay:")
                lines += a.immediateActions.enumerated().map { "\($0.offset + 1). \($0.element.text)" }
            }
            if !a.doNot.isEmpty {
                lines.append("Không được:")
                lines += a.doNot.map { "- \($0.text)" }
            }
            if let e = answer?.escalation { lines.append("Khi nào cần cấp cứu: \(e.text)") }
        } else if let card {
            lines.append(card.spokenText)
        }
        return lines.joined(separator: "\n")
    }
}
