import SwiftUI
import ResQCore

/// Static guide content shown without the model: emergency cards, skill pillars, articles.
/// Articles load from Resources/guides.json (draft, unreviewed); production reads the knowledge pack.
public enum GuideLibrary {
    static func card(_ id: String, _ title: String, _ steps: [String], _ doNot: [String]) -> EmergencyCard {
        EmergencyCard(id: id, intent: id, title: title, steps: steps, doNot: doNot,
                      hotline: "115", sourceLabel: "Nội dung mẫu", reviewedAt: "chờ duyệt")
    }

    public static let cards: [EmergencyCard] = [
        card("ec-bleed", "Chảy máu nặng",
             ["Ép chặt trực tiếp lên vết thương bằng vải sạch.", "Giữ lực ép liên tục, không mở ra kiểm tra.",
              "Thấm qua thì đắp thêm vải lên trên, tiếp tục ép.", "Gọi cứu hộ, giữ ấm nạn nhân."],
             ["rút dị vật đang cắm sâu ra khỏi vết thương"]),
        card("ec-cpr", "Bất tỉnh, ép tim",
             ["Kiểm tra an toàn xung quanh, gọi to, lay vai.", "Không thở hoặc thở ngáp: gọi cứu hộ, bắt đầu ép tim.",
              "Ép giữa ngực, sâu 5–6 cm, 100–120 lần mỗi phút.", "Không dừng đến khi có người thay hoặc nạn nhân tỉnh."],
             ["ngừng ép tim để bắt mạch liên tục"]),
        DemoResponder.card,
        card("ec-cold", "Hạ thân nhiệt",
             ["Đưa vào chỗ khuất gió, cách ly khỏi nền đất lạnh.", "Thay đồ ướt, quấn chăn hoặc túi ngủ, che đầu cổ.",
              "Còn tỉnh và nuốt được thì cho uống nước ấm có đường.", "Ủ ấm phần thân trước, không chà xát tay chân."],
             ["cho uống rượu", "xoa bóp mạnh chân tay"]),
        card("ec-heat", "Sốc nhiệt",
             ["Đưa vào bóng râm, nới lỏng quần áo.", "Làm mát nhanh: dội nước, quạt, chườm nách, bẹn, cổ.",
              "Còn tỉnh thì cho uống từng ngụm nước.", "Lú lẫn hoặc co giật: cấp cứu ngay."],
             ["cho uống nước khi nạn nhân lơ mơ, không nuốt được"]),
        card("ec-drown", "Đuối nước",
             ["Không nhảy xuống nếu không được huấn luyện. Ném phao, dây, cành cây.", "Đưa lên bờ, kiểm tra thở.",
              "Không thở: thổi 5 hơi rồi ép tim.", "Giữ ấm, theo dõi đến khi có cứu hộ."],
             ["dốc ngược nạn nhân để \"xóc nước\""]),
        card("ec-burn", "Bỏng",
             ["Tách khỏi nguồn nhiệt, dập lửa trên quần áo.", "Xả nước mát sạch lên vết bỏng ít nhất 20 phút.",
              "Tháo nhẫn, đồng hồ, đồ chật trước khi sưng.", "Che lỏng bằng màng bọc thực phẩm hoặc gạc sạch. Bỏng rộng, bỏng mặt: đi viện."],
             ["chườm đá", "bôi kem đánh răng, nước mắm, mỡ", "chọc vỡ bóng nước"]),
        card("ec-choke", "Hóc dị vật",
             ["Còn ho được: động viên ho thật mạnh.", "Không ho, không nói được: vỗ mạnh 5 cái giữa hai bả vai.",
              "Chưa ra: đứng sau, ôm bụng, giật mạnh 5 lần vào trong và lên trên.", "Luân phiên 5 vỗ lưng, 5 ép bụng. Bất tỉnh: ép tim."],
             ["móc họng khi không nhìn thấy dị vật", "ép bụng trẻ dưới 1 tuổi"]),
        card("ec-fracture", "Gãy xương",
             ["Giữ nguyên tư thế, không cố nắn.", "Nẹp cố định cả khớp trên và khớp dưới chỗ gãy.",
              "Gãy hở: che vết thương bằng gạc sạch, ép cầm máu quanh xương.", "Kiểm tra ngón tay, chân còn hồng, ấm; tê lạnh thì nới nẹp."],
             ["kéo nắn chỗ gãy", "ấn đầu xương lòi ra vào trong", "di chuyển người nghi gãy cột sống khi không bắt buộc"]),
    ]

    static func icon(for card: EmergencyCard) -> String {
        switch card.id {
        case "ec-bleed": "drop.fill"
        case "ec-cpr": "bolt.heart.fill"
        case "ec-snake": "lizard.fill"
        case "ec-cold": "snowflake"
        case "ec-heat": "thermometer.sun.fill"
        case "ec-drown": "figure.pool.swim"
        case "ec-burn": "flame.fill"
        case "ec-choke": "lungs.fill"
        case "ec-fracture": "bandage.fill"
        default: "cross.case.fill"
        }
    }

    struct Pillar: Identifiable {
        let icon: String, title: String, tint: Color
        var id: String { title }
        /// What this build actually ships for the pillar (the full knowledge pack is not bundled yet).
        var articles: [Article] { GuideLibrary.articles.filter { $0.pillar == title } }
        var cards: [EmergencyCard] { title == "Sơ cứu dã ngoại" ? GuideLibrary.cards : [] }
        var countLabel: String {
            let n = articles.count + cards.count
            return n == 0 ? "Chưa có bài" : "\(n) bài"
        }
    }

    static let pillars: [Pillar] = [
        Pillar(icon: "flame.fill", title: "Lửa và giữ nhiệt", tint: Color(hex: 0xFF7A2F)),
        Pillar(icon: "drop.fill", title: "Nước sạch", tint: Color(hex: 0x64D2FF)),
        Pillar(icon: "fish.fill", title: "Kiếm ăn và bẫy", tint: Color(hex: 0xFFD60A)),
        Pillar(icon: "tent.fill", title: "Trú ẩn, nút dây", tint: Color(hex: 0x32D74B)),
        Pillar(icon: "safari.fill", title: "Định hướng", tint: Color(hex: 0xBF5AF2)),
        Pillar(icon: "cross.case.fill", title: "Sơ cứu dã ngoại", tint: Color(hex: 0xFF453A)),
    ]

    struct Article: Identifiable, Decodable {
        let id: String, pillar: String, icon: String, title: String, minutes: Int
        let source: String, trust: String, license: String, summary: String
        /// Steps may bold a lead phrase with **…**.
        let steps: [String], warnings: [String]
        var tint: Color { GuideLibrary.pillars.first { $0.title == pillar }?.tint ?? .gray }
        var meta: String { "\(pillar) · \(minutes) phút" }
    }

    static let articles: [Article] = {
        struct Pack: Decodable { let articles: [Article] }
        let url = Bundle.module.url(forResource: "guides", withExtension: "json")!
        return try! JSONDecoder().decode(Pack.self, from: Data(contentsOf: url)).articles
    }()
    static var summary: String { "Nội dung mẫu · \(cards.count) thẻ khẩn cấp · \(articles.count) bài" }

    enum Hit: Identifiable {
        case card(EmergencyCard), article(Article), pillar(Pillar)
        var id: String {
            switch self { case .card(let c): c.id; case .article(let a): "a-" + a.id; case .pillar(let p): "p-" + p.id }
        }
    }

    /// Accent- and case-insensitive match ("ran can" finds "Rắn cắn").
    static func search(_ query: String) -> [Hit] {
        let q = fold(query)
        guard !q.isEmpty else { return [] }
        let all: [(String, Hit)] = cards.map { ($0.title + " " + $0.steps.joined(separator: " "), .card($0)) }
            + articles.map { (([$0.title, $0.meta, $0.summary] + $0.steps).joined(separator: " ").replacingOccurrences(of: "**", with: ""), .article($0)) }
            + pillars.map { ($0.title, .pillar($0)) }
        return all.filter { fold($0.0).contains(q) }.map(\.1)
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "đ", with: "d")
            .trimmingCharacters(in: .whitespaces)
    }
}
