import SwiftUI
import ResQCore

/// Scripted stand-in for the LLM. Routing, emergency cards and the device policy are the real ResQCore
/// code; only the answer text is canned (sample content from design/resq_prototype.html).
/// Emits the same event sequence and timing as the real pipeline: card → evidence → streamed lines → validated final.
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

    /// Router intent → reviewed card id.
    static let cardForIntent = ["severe_bleeding": "ec-bleed", "unconscious": "ec-cpr", "snake_bite": "ec-snake",
                                "drowning": "ec-drown", "hypothermia": "ec-cold", "heat_stroke": "ec-heat",
                                "choking": "ec-choke", "fracture": "ec-fracture"]

    struct Topic {
        let sources: [(heading: String, org: String, tier: TrustTier, excerpt: String)]
        let script: String
    }

    static func src(_ heading: String, _ org: String, _ tier: TrustTier, _ excerpt: String) -> (String, String, TrustTier, String) {
        (heading, org, tier, excerpt)
    }

    static let snake = Topic(sources: [
        src("Sơ cứu › Rắn cắn › Bất động chi", "Nội dung mẫu", .a, "Vận động làm nọc độc lan nhanh hơn. **Giữ nạn nhân nằm yên và cố định chi bị cắn bằng nẹp**, giống cách cố định khi gãy xương. Chuyển nạn nhân bằng cáng nếu có thể."),
        src("Sơ cứu › Rắn cắn › Dấu hiệu nguy hiểm", "Nội dung mẫu", .a, "Các dấu hiệu nhiễm độc nặng gồm **sụp mi, khó nuốt, khó thở, chảy máu không cầm** và sưng lan nhanh quanh vết cắn."),
        src("Sơ cứu › Những điều không làm", "Nội dung mẫu", .a, "**Không rạch vết cắn, không hút nọc, không garô chặt**, không chườm đá. Các cách này không lấy được nọc ra mà còn gây thêm tổn thương."),
    ], script: """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Giữ nạn nhân nằm yên, bất động chi bị cắn và đưa đi cấp cứu càng sớm càng tốt. [E1]
    LAM_NGAY:
    - Nhớ giờ bị cắn, màu và hình dạng con rắn nếu thấy an toàn, không cố bắt rắn [E1]
    - Giữ chi bị cắn ngang hoặc thấp hơn tim [E1]
    - Phải di chuyển thì cáng nạn nhân, không để tự đi [E1]
    KHONG_DUOC:
    - Rạch, hút nọc hay garô chặt [E3]
    - Đắp thuốc lá, lá cây lên vết cắn [E3]
    CAP_CUU: Cấp cứu ngay nếu sụp mi, khó nuốt, khó thở, chảy máu chân răng hoặc vết cắn sưng lan nhanh [E2]
    """)

    static let fish = Topic(sources: [
        src("Kiếm ăn › Bẫy cá › Bẫy chai một chiều", "FM 21-76", .b, "Cắt đầu chai và lồng ngược vào thân để tạo **phễu một chiều**. Đục lỗ quanh thân để nước và mùi mồi thoát ra. Đặt bẫy nơi nước chảy chậm, miệng phễu hướng về hạ lưu."),
        src("Kiếm ăn › Chế biến an toàn", "FM 21-76", .b, "Cá và động vật nước ngọt có thể mang ký sinh trùng. **Luôn nấu chín kỹ**, không ăn sống."),
        src("An toàn › Vượt suối", "Nội dung mẫu", .a, "Nước ngang đầu gối đã đủ để đẩy ngã người lớn nếu chảy xiết. **Không lội ở chỗ nước xiết** khi không có dây an toàn."),
    ], script: """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Làm bẫy chai một chiều: cá chui vào theo mùi mồi nhưng khó tìm đường ra. [E1]
    LAM_NGAY:
    - Cắt rời một phần ba đầu chai, lật ngược nhét vào thân làm phễu [E1]
    - Dùng mũi dao đục lỗ nhỏ quanh thân chai để nước lưu thông, mùi mồi lan ra [E1]
    - Bỏ mồi như giun, ốc đập dập, buộc dây dù vào cổ chai rồi neo vào gốc cây [E1]
    - Đặt ở chỗ nước chảy chậm, miệng phễu quay về phía hạ lưu, kiểm tra sau vài giờ [E1]
    - Cá bắt được phải nấu chín kỹ [E2]
    KHONG_DUOC:
    - Lội ra chỗ nước xiết hoặc sâu quá đầu gối để đặt bẫy [E3]
    """)

    static let water = Topic(sources: [
        src("Nước › Lọc nước › Bình lọc nhiều tầng", "FM 21-76", .b, "Bình lọc nhiều tầng loại bỏ cặn và làm nước trong. **Lọc không làm nước an toàn để uống**, nước sau lọc vẫn phải khử trùng."),
        src("Nước › Khử trùng › Đun sôi", "Nội dung mẫu", .a, "**Đun sôi sùng sục ít nhất 1 phút.** Ở độ cao trên 2.000 m, đun 3 phút vì nước sôi ở nhiệt độ thấp hơn."),
        src("Nước › Tìm nguồn nước", "FM 21-76", .b, "Lấy nước ở thượng nguồn, **tránh khu vực dưới nơi có người, gia súc hoặc xác động vật**."),
    ], script: """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Bình lọc chai nhựa chỉ làm nước trong hơn, không diệt được vi khuẩn. Lọc xong vẫn phải đun sôi. [E1][E2]
    LAM_NGAY:
    - Cắt đáy chai, úp ngược. Nhét vải chặt vào cổ chai [E1]
    - Xếp lớp: than củi đập nhỏ, cát mịn, sỏi nhỏ, sỏi to [E1]
    - Đổ nước từ từ, bỏ phần nước lọc đầu tiên [E1]
    - Đun sôi sùng sục ít nhất 1 phút, trên 2.000 m thì 3 phút [E2]
    KHONG_DUOC:
    - Uống nước chỉ qua lọc mà chưa đun sôi [E2]
    - Lấy nước ngay dưới khu dân cư, chuồng trại hay xác động vật [E3]
    """)

    static let fire = Topic(sources: [
        src("Lửa › Nhóm lửa khi ẩm ướt", "FM 21-76", .b, "Dựng **sàn bằng cành khô** để cách lửa khỏi nền đất ướt. Chuẩn bị đủ ba cỡ củi trước khi đánh lửa."),
        src("Lửa › Bùi nhùi và mồi lửa", "FM 21-76", .b, "Phần lõi của cành chết thường vẫn khô. **Chẻ đôi cành và vót phoi mỏng** từ phần lõi để làm mồi."),
        src("Lửa › An toàn", "Nội dung mẫu", .a, "**Không chọc thủng hay đốt pin lithium**: pin có thể cháy dữ dội và phát nổ."),
    ], script: """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Củi ướt thường chỉ ướt ở ngoài. Chẻ lấy lõi khô, vót phoi mỏng và nhóm từ nhỏ đến lớn. [E1][E2]
    LAM_NGAY:
    - Kê một lớp cành khô làm sàn, không nhóm trên đất ướt [E1]
    - Chẻ cành to lấy lõi khô, vót phoi mỏng làm mồi [E2]
    - Chuẩn bị đủ củi cỡ que, cỡ ngón tay, cỡ cổ tay trước khi đánh lửa [E1]
    KHONG_DUOC:
    - Dùng pin điện thoại để tạo lửa. Pin dễ cháy nổ, và bạn mất luôn thiết bị liên lạc [E3]
    - Đốt lửa sát gốc cây khô hay trên thảm lá dày [E3]
    """)

    static let mushroom = Topic(sources: [
        src("Hái lượm › Nấm hoang dã › Quy tắc an toàn", "Nội dung mẫu", .a, "Nhiều loài nấm độc chết người có hình dạng rất giống nấm ăn được. **Không có phép thử nào tại thực địa xác định được một cây nấm là an toàn.** Không ăn nấm hoang dã nếu chưa có người có chuyên môn xác định mẫu thật."),
        src("Kiếm ăn › Nguồn đạm dễ nhận biết", "FM 21-76", .b, "Khi thiếu lương thực, **cá, ếch và côn trùng là nguồn đạm dễ nhận biết hơn thực vật**. Mọi loại thịt kiếm được ngoài tự nhiên đều phải nấu chín kỹ để diệt ký sinh trùng."),
        src("Sơ cứu › Ngộ độc › Nấm", "Nội dung mẫu", .a, "Triệu chứng của một số loài nấm rất độc có thể xuất hiện muộn, **sau 6 đến 24 giờ**, khi người bệnh tưởng đã ổn. Giữ lại mẫu nấm và tìm hỗ trợ y tế ngay cả khi đã thấy đỡ."),
    ], script: """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: ResQ không kết luận cây, nấm hay quả ăn được qua ảnh. Nhịn ăn vài ngày ít nguy hiểm hơn ăn nhầm nấm độc. [E1]
    LAM_NGAY:
    - Nếu thiếu thức ăn, ưu tiên nguồn dễ nhận biết như cá suối hay côn trùng nấu chín kỹ [E2]
    - Nếu đã lỡ ăn, giữ lại mẫu và theo dõi ít nhất 24 giờ [E3]
    KHONG_DUOC:
    - Ăn thử một ít để kiểm tra [E1]
    CAP_CUU: Tìm hỗ trợ y tế ngay nếu nôn, đau bụng, tiêu chảy sau khi ăn nấm, kể cả khi đã thấy đỡ [E3]
    """)

    /// Fallback evidence when nothing matches well enough.
    static let nearest = [
        src("Trú ẩn › Chọn chỗ dựng lán", "FM 21-76", .b, "Chọn chỗ cao ráo, tránh lòng suối cạn và **dưới cây chết đứng**."),
        src("Định hướng › Bóng gậy mặt trời", "FM 21-76", .b, "Cắm gậy thẳng, đánh dấu đầu bóng, chờ 15 phút rồi đánh dấu lần hai. **Đường nối hai dấu chạy theo hướng Tây–Đông.**"),
    ]

    /// Emergency with a card but no written script: answer straight from the reviewed card.
    static func topic(from c: EmergencyCard) -> Topic {
        let script = (["TRANG_THAI: CO_CAN_CU", "TOM_TAT: \(c.steps.first ?? c.title) [E1]", "LAM_NGAY:"]
            + c.steps.dropFirst().map { "- \($0) [E1]" }
            + ["KHONG_DUOC:"] + c.doNot.map { "- Không \($0) [E1]" }
            + ["CAP_CUU: Gọi cấp cứu ngay khi có sóng, số gọi có sẵn trên thẻ khẩn cấp [E1]"]).joined(separator: "\n")
        return Topic(sources: [src("Sơ cứu › \(c.title)", "Nội dung mẫu", .a, c.steps.joined(separator: " "))], script: script)
    }

    /// `words` is the folded query as space-padded tokens, e.g. " bat ca suoi ".
    static func pick(words q: String, route: Route, hasImage: Bool, card: EmergencyCard?) -> Topic? {
        if route.emergencyIntent == "snake_bite" { return snake }
        if let card { return topic(from: card) }
        if hasImage || route.category == "foraging" || q.contains(" nam ") { return mushroom }
        if q.contains(" ca ") && [" bat ", " bay ", " cau "].contains(where: q.contains) { return fish }
        if route.category == "water" || q.contains(" nuoc ") { return water }
        if q.contains(" lua ") || q.contains(" cui ") { return fire }
        return nil
    }

    static func evidence(_ t: [(heading: String, org: String, tier: TrustTier, excerpt: String)]) -> [EvidenceBlock] {
        t.enumerated().map { i, e in
            EvidenceBlock(label: "E\(i + 1)",
                          block: ParentBlock(parentId: "p\(i)", articleId: "a\(i)", sourceLabel: e.org,
                                             headingPath: e.heading, text: e.excerpt, tokens: 300, trust: e.tier),
                          score: 0.05 - Double(i) * 0.01)
        }
    }

    public func answer(_ request: AnswerRequest, state: ConversationState) -> AsyncThrowingStream<PipelineEvent, Error> {
        let query = QueryNormalizer().normalize(request.text)
        let route = RiskRouter().route(query)
        let plan = DevicePolicy().plan(installed: request.installed, device: request.device, route: route)
        let card = route.emergencyIntent.flatMap { Self.cardForIntent[$0] }.flatMap { id in GuideLibrary.cards.first { $0.id == id } }
        let words = " " + query.terms.joined(separator: " ") + " "
        let topic = Self.pick(words: words, route: route, hasImage: request.imageJPEG != nil, card: card)
        let evidence = Self.evidence(topic?.sources ?? Self.nearest)

        return AsyncThrowingStream { c in
            let task = Task {
                try? await Task.sleep(for: .milliseconds(120))
                if let card { c.yield(.emergencyCard(card)) }
                try? await Task.sleep(for: .milliseconds(150))
                c.yield(.evidence(evidence))
                if let notice = plan.notice { c.yield(.notice(notice)) }
                guard plan.llmEnabled else { c.yield(.noAnswer(reason: .llmDisabled)); return c.finish() }
                guard let topic else {
                    try? await Task.sleep(for: .milliseconds(400))
                    c.yield(.noAnswer(reason: .insufficientEvidence))
                    return c.finish()
                }
                try? await Task.sleep(for: .milliseconds(request.imageJPEG == nil ? 900 : 1_400))
                // Battery saver: shorter answer (DevicePolicy cut the token budget).
                let lines = topic.script.split(separator: "\n", omittingEmptySubsequences: false)
                let script = plan.maxOutputTokens < 300 ? Self.shorten(lines) : topic.script
                var parser = AnswerParser()
                for word in script.split(separator: " ", omittingEmptySubsequences: false) {
                    if Task.isCancelled { break }
                    c.yield(.partial(parser.feed(word + " ")))
                    try? await Task.sleep(for: .milliseconds(30))
                }
                c.yield(.final(GroundingValidator().validate(parser.finish(), evidence: evidence, route: route)))
                c.finish()
            }
            c.onTermination = { _ in task.cancel() }
        }
    }

    /// Keep at most two items per list section.
    static func shorten(_ lines: [Substring]) -> String {
        var out: [Substring] = []
        var inList = 0
        for l in lines {
            if l.hasPrefix("- ") { inList += 1; if inList > 2 { continue } } else { inList = 0 }
            out.append(l)
        }
        return out.joined(separator: "\n")
    }
}

extension LocationFix {
    static let demo = LocationFix(latitude: 22.30336, longitude: 103.77502, accuracyMeters: 8, altitudeMeters: 2184, time: "14:40")
}

#Preview("Chat") {
    ChatScreen(model: ChatViewModel(responder: DemoResponder()),
               sensors: FieldSensors(preview: .demo, place: "Hoàng Liên Sơn", battery: 64))
}

#Preview("SOS") {
    SOSScreen(location: .demo, cards: GuideLibrary.cards, onClose: {})
}

#Preview("Emergency pass") {
    ScrollView { EmergencyPassView(card: DemoResponder.card).padding(18) }
        .background(ResQPalette.dark.bg)
}
