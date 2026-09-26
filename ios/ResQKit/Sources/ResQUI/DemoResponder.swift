import SwiftUI
import ResQCore

/// Scripted responder for previews and UI tests: emits the same event sequence and timing
/// the real pipeline does (card → evidence → streamed lines → validated final).
public struct DemoResponder: AnswerResponder {
    public init() {}

    static let card = EmergencyCard(
        id: "ec-snake", intent: "snake_bite", title: "Rắn cắn",
        steps: ["Đưa nạn nhân ra xa con rắn, giữ bình tĩnh và nằm yên.",
                "Tháo nhẫn, vòng, giày chật ở chi bị cắn trước khi sưng.",
                "Bất động chi bị cắn bằng nẹp, như khi gãy xương.",
                "Chuyển đến cơ sở y tế sớm nhất; hạn chế để nạn nhân tự đi."],
        doNot: ["rạch vết cắn", "hút nọc", "garô chặt", "chườm đá", "đắp lá hay uống rượu"],
        hotline: "115", sourceLabel: "Nội dung mẫu", reviewedAt: "chờ duyệt")

    static let evidence: [EvidenceBlock] = [
        ("Sơ cứu › Rắn cắn › Bất động chi", TrustTier.a), ("Sơ cứu › Rắn cắn › Dấu hiệu nguy hiểm", .a), ("Sơ cứu › Những điều không làm", .a),
    ].enumerated().map { i, e in
        EvidenceBlock(label: "E\(i + 1)",
                      block: ParentBlock(parentId: "p\(i)", articleId: "a\(i)", sourceLabel: "Nội dung mẫu · chờ duyệt",
                                         headingPath: e.0, text: "", tokens: 300, trust: e.1),
                      score: 0.05 - Double(i) * 0.01)
    }

    static let script = """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Giữ nạn nhân nằm yên, bất động chi bị cắn và đưa đi cấp cứu càng sớm càng tốt. [E1]
    LAM_NGAY:
    - Giữ chi bị cắn ngang hoặc thấp hơn tim [E1]
    - Nếu phải di chuyển, cáng nạn nhân thay vì để tự đi [E1]
    KHONG_DUOC:
    - Không rạch, hút nọc hay garô chặt [E3]
    CAP_CUU: Cấp cứu ngay nếu sụp mi, khó nuốt, khó thở hoặc chảy máu không cầm [E2]
    """

    public func answer(_ text: String, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error> {
        AsyncThrowingStream { c in
            let task = Task {
                try? await Task.sleep(for: .milliseconds(120))
                c.yield(.emergencyCard(Self.card))
                try? await Task.sleep(for: .milliseconds(150))
                c.yield(.evidence(Self.evidence))
                try? await Task.sleep(for: .milliseconds(900))
                var parser = AnswerParser()
                for word in Self.script.split(separator: " ", omittingEmptySubsequences: false) {
                    if Task.isCancelled { break }
                    c.yield(.partial(parser.feed(word + " ")))
                    try? await Task.sleep(for: .milliseconds(30))
                }
                let final = GroundingValidator().validate(parser.finish(), evidence: Self.evidence, route: Route(risk: .emergency))
                c.yield(.final(final))
                c.finish()
            }
            c.onTermination = { _ in task.cancel() }
        }
    }
}

extension LocationFix {
    static let demo = LocationFix(latitude: 22.30336, longitude: 103.77502, accuracyMeters: 8, altitudeMeters: 2184, time: "14:40")
}

#Preview("Chat") {
    ChatScreen(model: ChatViewModel(responder: DemoResponder()),
               status: DeviceStatusLine(model: "Gemma 4 E2B", battery: 64, place: "Hoàng Liên Sơn"),
               location: .demo)
}

#Preview("SOS") {
    SOSScreen(location: .demo, cards: [DemoResponder.card], onClose: {})
}

#Preview("Emergency pass") {
    ScrollView { EmergencyPassView(card: DemoResponder.card).padding(18) }
        .background(ResQPalette.dark.bg)
}
