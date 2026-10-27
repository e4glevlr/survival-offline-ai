import SwiftUI

/// Guide illustrations. Every article has a painted picture (Resources/cover-<id>.jpg, made by
/// design/gen/art/make_art.sh); technical ones also get numbered pins laid over it. Pin labels are
/// native text so they stay sharp, follow the theme and are read by VoiceOver.
enum GuideFigure {
    /// A labelled part of the picture. Coordinates are unit (0…1 from the top-left): `target` is the
    /// part itself, `tag` is where the numbered dot sits, in clear space, joined to it by a leader line.
    struct Pin: Sendable {
        let label: String
        let target: CGPoint
        let tag: CGPoint
        init(_ label: String, _ tx: CGFloat, _ ty: CGFloat, tag lx: CGFloat, _ ly: CGFloat) {
            self.label = label
            target = CGPoint(x: tx, y: ty)
            tag = CGPoint(x: lx, y: ly)
        }
    }

    struct Spec: Sendable {
        /// What the picture shows, for VoiceOver.
        let alt: String
        let pins: [Pin]
    }

    static func has(_ articleId: String) -> Bool { specs[articleId] != nil && GuideArt.available.contains(articleId) }

    static let specs: [String: Spec] = [
        "water-bottle-filter": Spec(
            alt: "Chai nhựa cắt đáy treo ngược trên cọc. Từ trên xuống: sỏi to, sỏi nhỏ, cát mịn, than củi, nút vải ở cổ chai. Nước đục đổ vào miệng, nước trong nhỏ xuống nồi bên dưới.",
            pins: [
                Pin("Sỏi to", 0.50, 0.30, tag: 0.64, 0.24),
                Pin("Sỏi nhỏ", 0.48, 0.38, tag: 0.30, 0.34),
                Pin("Cát mịn", 0.52, 0.45, tag: 0.64, 0.44),
                Pin("Than củi", 0.48, 0.52, tag: 0.30, 0.56),
                Pin("Vải nhét cổ chai", 0.52, 0.66, tag: 0.64, 0.66),
                Pin("Hứng rồi vẫn phải đun sôi", 0.47, 0.90, tag: 0.33, 0.88),
            ]),
    ]
}

/// Bundled article pictures, decoded on demand and kept in a small cache.
enum GuideArt {
    #if canImport(UIKit)
    typealias PlatformImage = UIImage
    #else
    typealias PlatformImage = NSImage
    #endif

    static let available: Set<String> = Set(
        (Bundle.module.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasPrefix("cover-") }
            .map { String($0.dropFirst(6)) })

    @MainActor private static let cache: NSCache<NSString, PlatformImage> = {
        let c = NSCache<NSString, PlatformImage>()
        c.countLimit = 12
        return c
    }()

    @MainActor static func image(_ articleId: String) -> PlatformImage? {
        if let hit = cache.object(forKey: articleId as NSString) { return hit }
        guard let url = Bundle.module.url(forResource: "cover-\(articleId)", withExtension: "jpg") else { return nil }
        #if canImport(UIKit)
        let img = UIImage(contentsOfFile: url.path)
        #else
        let img = NSImage(contentsOf: url)
        #endif
        if let img { cache.setObject(img, forKey: articleId as NSString) }
        return img
    }
}

/// An article's picture. Night vision turns it monochrome red like the rest of the UI.
struct CoverImage: View {
    let articleId: String
    var contentMode: ContentMode = .fill
    @Environment(\.palette) private var p

    var body: some View {
        if let img = GuideArt.image(articleId) {
            let night = p == .night
            Group {
                #if canImport(UIKit)
                Image(uiImage: img).resizable()
                #else
                Image(nsImage: img).resizable()
                #endif
            }
            .aspectRatio(contentMode: contentMode)
            .grayscale(night ? 1 : 0)
            .colorMultiply(night ? p.red : .white)
        }
    }
}

/// The picture with its numbered pins and a matching legend. Pins pop in one after another;
/// when `interactive`, tapping a pin or a legend row highlights that part on the picture.
struct GuideFigureView: View {
    let articleId: String
    var interactive = true
    var imageRadius: CGFloat = 0
    var legendInset: CGFloat = 0
    @State private var appeared = false
    @State private var selected: Int?
    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let spec = GuideFigure.specs[articleId] {
            VStack(alignment: .leading, spacing: 12) {
                CoverImage(articleId: articleId, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: imageRadius, style: .continuous))
                    .overlay { GeometryReader { g in pins(spec, in: g.size) } }
                    .overlay(alignment: .bottomLeading) {
                        if let i = selected {
                            Text("\(i + 1) · \(spec.pins[i].label)")
                                .font(.rq(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 10).frame(height: 28)
                                .background(.black.opacity(0.66), in: Capsule())
                                .padding(10)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .id(i)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(spec.alt)
                    .accessibilityAddTraits(.isImage)
                legend(spec).padding(.horizontal, legendInset)
            }
            .onAppear { appeared = true }
        }
    }

    private func pins(_ spec: GuideFigure.Spec, in size: CGSize) -> some View {
        ForEach(Array(spec.pins.enumerated()), id: \.offset) { i, pin in
            let active = selected == i, dimmed = selected != nil && !active
            let shown = appeared || reduceMotion
            let delay = 0.2 + Double(i) * 0.09
            let target = CGPoint(x: pin.target.x * size.width, y: pin.target.y * size.height)
            let tag = CGPoint(x: pin.tag.x * size.width, y: pin.tag.y * size.height)
            Leader(from: tag, to: target)
                .trim(from: 0, to: shown ? 1 : 0)
                .stroke(active ? p.accent : .white.opacity(0.9), style: StrokeStyle(lineWidth: active ? 1.8 : 1.2, lineCap: .round))
                .shadow(color: .black.opacity(0.6), radius: 1.5)
                .opacity(dimmed ? 0.3 : 1)
                .animation(.easeOut(duration: 0.35).delay(delay + 0.1), value: appeared)
                .allowsHitTesting(false)
            Circle().fill(.white).frame(width: 6, height: 6)
                .overlay(Circle().strokeBorder(active ? p.accent : .black.opacity(0.5), lineWidth: 1.5).padding(-1.5))
                .opacity(shown ? (dimmed ? 0.3 : 1) : 0)
                .animation(.easeOut(duration: 0.2).delay(delay + 0.4), value: appeared)
                .position(target)
                .allowsHitTesting(false)
            PinDot(number: i + 1, active: active, dimmed: dimmed)
                .scaleEffect(shown ? 1 : 0.2)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.62).delay(delay), value: appeared)
                .position(tag)
                .onTapGesture { if interactive { toggle(i) } }
                .allowsHitTesting(interactive)
        }
    }

    private func legend(_ spec: GuideFigure.Spec) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .topLeading),
                            GridItem(.flexible(), spacing: 10, alignment: .topLeading)],
                  alignment: .leading, spacing: 8) {
            ForEach(Array(spec.pins.enumerated()), id: \.offset) { i, pin in
                let active = selected == i
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("\(i + 1)").font(ResQFont.number(11, .bold))
                        .foregroundStyle(active ? p.onSolid : p.accent)
                        .frame(width: 18, height: 18)
                        .background(active ? p.accent : p.accentSoft, in: Circle())
                    Text(pin.label).font(.rq(size: 13)).foregroundStyle(active ? p.text : p.text2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { if interactive { toggle(i) } }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func toggle(_ i: Int) {
        withAnimation(ResQMotion.ease) { selected = selected == i ? nil : i }
    }
}

/// Straight line from a pin's dot to the part it names.
private struct Leader: Shape {
    let from, to: CGPoint
    func path(in _: CGRect) -> Path {
        Path { $0.move(to: from); $0.addLine(to: to) }
    }
}

/// A numbered pin; the highlighted one pulses.
private struct PinDot: View {
    let number: Int
    let active: Bool
    let dimmed: Bool
    @State private var pulse = false
    @Environment(\.palette) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(number)").font(ResQFont.number(11, .bold)).foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(active ? p.accent : .black.opacity(0.62), in: Circle())
            .overlay(Circle().strokeBorder(active ? .white : p.accent, lineWidth: 1.5))
            .background {
                if active && !reduceMotion {
                    Circle().stroke(p.accent, lineWidth: 2)
                        .scaleEffect(pulse ? 2 : 1).opacity(pulse ? 0 : 0.9)
                        .onAppear { withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true } }
                        .onDisappear { pulse = false }
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
            .opacity(dimmed ? 0.45 : 1)
            .frame(width: 36, height: 36)
            .contentShape(Circle())
    }
}
