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
        let (fg, bg): (Color, Color) = switch tone {
        case .ok: (p.green, p.greenSoft)
        case .warn: (p.amber, p.amberSoft)
        case .danger: (p.red, p.redSoft)
        case .muted: (p.text2, p.surface2)
        }
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).symbolVariant(.fill)
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(fg)
        .padding(.leading, 7).padding(.trailing, 9).frame(height: 24)
        .background(bg, in: Capsule())
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

/// Small orange-gradient app mark shown at the head of each answer.
struct BrandMark: View {
    var size: CGFloat = 22
    @Environment(\.palette) private var p

    var body: some View {
        Image(systemName: "safari.fill")
            .font(.system(size: size * 0.62, weight: .semibold))
            .foregroundStyle(p.glows ? .white : p.onSolid)
            .frame(width: size, height: size)
            .background(
                p.glows ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF9A52), Color(hex: 0xFF5A1F)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(p.redDeep),
                in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
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
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(p.glows ? .white : p.onSolid)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient(colors: [Color(hex: 0xFF5B50), Color(hex: 0xD91A10)], startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: p.glows ? Color(hex: 0xFF3B30).opacity(0.55) : .clear, radius: 10, y: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text("THẺ KHẨN CẤP").font(.system(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(p.red)
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
                                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
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
                    .sensoryFeedback(.selection, trigger: done.contains(i))
                }
            }
            .padding(.horizontal, 8)

            if !card.doNot.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "nosign").font(.system(size: 17, weight: .semibold)).foregroundStyle(p.red)
                    Text("\(Text("Không ").fontWeight(.semibold).foregroundStyle(p.text))\(card.doNot.joined(separator: ", ")).")
                        .font(ResQFont.callout).foregroundStyle(p.text2)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(p.scheme == .light ? p.redSoft : .black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16).padding(.top, 8)
            }

            HStack {
                Label("\(card.sourceLabel) · \(card.reviewedAt)", systemImage: "checkmark.seal")
                    .font(ResQFont.caption).foregroundStyle(p.text3)
                Spacer()
                if let hotline = card.hotline, let url = URL(string: "tel:\(hotline)") {
                    // Hotline comes from structured data, never from the LLM.
                    Link(destination: url) {
                        Label("Gọi \(hotline)", systemImage: "phone.fill")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(p.onSolid)
                            .padding(.horizontal, 18).frame(height: 42)
                            .background(p.solid, in: Capsule())
                    }
                }
            }
            .padding(16)
        }
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [p.passTop, p.passBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                if p.glows {
                    RadialGradient(colors: [Color(hex: 0xFF453A).opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 100)
                        .frame(width: 200, height: 200).offset(x: 40, y: -60)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(p.passLine))
        .shadow(color: p.glows ? Color(hex: 0xFF3B30).opacity(0.35) : .clear, radius: 30, y: 18)
        .accessibilityElement(children: .contain)
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
        case .doIt: ("LÀM NGAY", p.green)
        case .doNot: ("KHÔNG ĐƯỢC", p.red)
        case .escalate: ("KHI NÀO CẦN CẤP CỨU", p.amber)
        }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 7, height: 7).shadow(color: p.glows ? tint : .clear, radius: 5)
                Text(title).font(ResQFont.eyebrow).tracking(1.2).foregroundStyle(p.text3)
            }
            if kind == .escalate, let item = items.first {
                ItemText(item: item)
                    .padding(.vertical, 13).padding(.leading, 18).padding(.trailing, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface(p, radius: 16)
                    .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16).fill(tint).frame(width: 3) }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Group {
                                if kind == .doIt {
                                    Text("\(i + 1)").font(ResQFont.number(12)).foregroundStyle(p.green)
                                        .frame(width: 24, height: 24).background(p.greenSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(p.red).frame(width: 24, height: 24)
                                }
                            }
                            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            ItemText(item: item).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { if i < items.count - 1 { Rectangle().fill(p.hair).frame(height: 1) } }
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
    @Environment(\.palette) private var p

    static func monogram(_ label: String) -> String {
        let words = label.split(separator: " ").filter { $0.first?.isLetter == true }
        return words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NGUỒN TRONG CẨM NANG").font(ResQFont.eyebrow).tracking(1.2).foregroundStyle(p.text3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(evidence) { e in
                        HStack(alignment: .top, spacing: 11) {
                            Text(Self.monogram(e.block.sourceLabel))
                                .font(ResQFont.number(11)).foregroundStyle(p.text2)
                                .frame(width: 34, height: 34).background(p.surface3, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(e.block.headingPath.components(separatedBy: " › ").suffix(2).joined(separator: " › "))
                                    .font(.system(size: 13.5, weight: .medium)).foregroundStyle(p.text).lineLimit(2)
                                HStack(spacing: 6) {
                                    let trusted = e.block.trust == .a
                                    Text(e.block.trust.rawValue).font(ResQFont.number(10))
                                        .foregroundStyle(trusted ? p.green : p.blue)
                                        .padding(.horizontal, 5).padding(.vertical, 3)
                                        .background(trusted ? p.greenSoft : p.blueSoft, in: RoundedRectangle(cornerRadius: 5))
                                    Text(e.block.sourceLabel).font(ResQFont.caption).foregroundStyle(p.text3).lineLimit(1)
                                }
                            }
                        }
                        .padding(12).frame(width: 236, alignment: .leading)
                        .surface(p, radius: 18)
                    }
                }
                .padding(.horizontal, 18)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .padding(.horizontal, -18)
        }
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
            ProgressView().controlSize(.small).tint(p.accent)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(p.text3)
                .overlay {
                    LinearGradient(colors: [.clear, p.text, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 80).offset(x: phase * 160)
                        .mask(Text(text).font(.system(size: 14, weight: .medium)))
                }
        }
        .onAppear { withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { phase = 1 } }
    }
}

public struct AssistantTurnView: View {
    let turn: AssistantTurn
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
            if let reason = turn.noAnswer {
                header(Tag(reason == .llmDisabled ? "Chỉ tra cứu" : "Không đủ căn cứ", icon: "questionmark.circle", tone: .warn))
                Text(reason == .llmDisabled
                     ? "AI đang tắt để tiết kiệm pin. Các nguồn liên quan ở bên dưới."
                     : "Cẩm nang trên máy chưa có hướng dẫn đủ sát cho câu này, nên ResQ không tự trả lời. Hãy hỏi cụ thể hơn: bạn đang ở đâu, có những đồ gì.")
                    .font(ResQFont.lead).foregroundStyle(p.text).lineSpacing(4)
            }
            if let a = turn.answer {
                header(turn.status?.tag ?? Tag("Đang viết", icon: "ellipsis", tone: .muted))
                if !a.summary.isEmpty {
                    ItemText(item: AnswerItem(text: a.summary, citations: a.summaryCitations), font: ResQFont.lead)
                }
                if !a.immediateActions.isEmpty { AnswerSectionView(kind: .doIt, items: a.immediateActions) }
                if !a.doNot.isEmpty { AnswerSectionView(kind: .doNot, items: a.doNot) }
                if let e = a.escalation { AnswerSectionView(kind: .escalate, items: [e]) }
            }
            if turn.failed {
                Tag("Lỗi khi tạo câu trả lời. Thẻ và nguồn vẫn dùng được", icon: "exclamationmark.triangle", tone: .warn)
            }
            if !turn.evidence.isEmpty { SourcesStrip(evidence: turn.evidence) }
            if !turn.isStreaming { ActionRow() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(ResQMotion.ease, value: turn)
    }

    private func header(_ tag: Tag) -> some View {
        HStack(spacing: 8) {
            BrandMark()
            tag
            Text("\(turn.evidence.count) nguồn").font(ResQFont.caption).foregroundStyle(p.text3)
        }
    }
}

struct ActionRow: View {
    @State private var speaking = false
    @State private var copied = false
    @State private var pinned = false
    @State private var saved = false
    @Environment(\.palette) private var p

    var body: some View {
        HStack(spacing: 4) {
            action(speaking ? "waveform" : "speaker.wave.2", on: speaking, label: "Đọc to") { speaking.toggle() }
                .symbolEffect(.variableColor.iterative, isActive: speaking)
            action(copied ? "checkmark" : "doc.on.doc", on: copied, label: "Sao chép") { copied = true }
            action("mappin.and.ellipse", on: pinned, label: "Ghim vị trí") { pinned = true }
            action(saved ? "bookmark.fill" : "bookmark", on: saved, label: "Lưu") { saved = true }
        }
        .padding(.leading, -8)
    }

    private func action(_ icon: String, on: Bool, label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(on ? p.green : p.text3)
                .frame(width: 38, height: 38).contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .sensoryFeedback(.success, trigger: on)
    }
}
