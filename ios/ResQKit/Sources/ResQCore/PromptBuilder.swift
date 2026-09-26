import Foundation

public struct Prompt: Sendable, Equatable {
    /// Fixed across requests → the runtime can keep its KV cache (prefix caching).
    public let system: String
    public let user: String
}

/// Compact prompt. The model never sees URLs, licenses, internal ids or checksums:
/// only E-labels, a short source label, the heading and the text. UI resolves E-labels to full metadata.
public struct PromptBuilder: Sendable {
    public init() {}

    public static let systemContract = """
    Bạn là ResQ, trợ lý sinh tồn chạy ngoại tuyến. Chỉ dùng thông tin trong các khối BẰNG CHỨNG.
    Quy tắc:
    - Mỗi ý hành động phải kèm nhãn nguồn, ví dụ [E1]. Không có nguồn thì không viết ý đó.
    - Không tự tạo số điện thoại, liều thuốc hay con số không có trong bằng chứng.
    - Nếu bằng chứng không đủ: TRANG_THAI: KHONG_DU_CAN_CU. Nếu các nguồn mâu thuẫn: TRANG_THAI: MAU_THUAN.
    - Không bao giờ khẳng định một loài nấm/cây là ăn được dựa trên mô tả hay ảnh.
    - Tiếng Việt, câu ngắn, mệnh lệnh rõ. Không mở bài, không kết bài.
    Định dạng bắt buộc (giữ nguyên các nhãn viết hoa):
    TRANG_THAI: CO_CAN_CU | KHONG_DU_CAN_CU | MAU_THUAN
    TOM_TAT: <1-2 câu>
    LAM_NGAY:
    - <bước> [E#]
    KHONG_DUOC:
    - <điều cấm> [E#]
    CAP_CUU: <khi nào cần gọi cứu hộ> [E#]
    """

    public func build(query: NormalizedQuery, state: ConversationState, evidence: [EvidenceBlock]) -> Prompt {
        var user = ""
        let stateLine = state.promptLine
        if !stateLine.isEmpty { user += "BỐI CẢNH: \(stateLine)\n" }
        for e in evidence {
            user += "[\(e.label) | \(e.block.sourceLabel) | \(e.block.headingPath)]\n\(e.block.text)\n\n"
        }
        user += "CÂU HỎI: \(query.display)"
        return Prompt(system: Self.systemContract, user: user)
    }
}

/// Small multi-turn state instead of the full chat history (spec §12).
public struct ConversationState: Sendable, Equatable {
    public var subject: String?        // "rắn cắn", "lọc nước"
    public var environment: String?    // stated by the user only
    public var constraints: [String]   // "chỉ có dao và dây dù"
    public var summary: String?        // ≤ 400 tokens, only when really needed

    public init(subject: String? = nil, environment: String? = nil, constraints: [String] = [], summary: String? = nil) {
        self.subject = subject
        self.environment = environment
        self.constraints = constraints
        self.summary = summary
    }

    var promptLine: String {
        var parts: [String] = []
        if let subject { parts.append("chủ đề: \(subject)") }
        if let environment { parts.append("môi trường: \(environment)") }
        if !constraints.isEmpty { parts.append("đồ đang có: \(constraints.joined(separator: ", "))") }
        if let summary { parts.append("tóm tắt trước: \(summary)") }
        return parts.joined(separator: "; ")
    }

    /// Text appended to the retrieval query so "còn nếu trời lạnh thì sao?" still retrieves the subject.
    public var retrievalHint: String { subject ?? "" }
}
