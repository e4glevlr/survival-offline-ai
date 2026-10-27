import XCTest
@testable import ResQCore

/// Cross-platform conformance suite. Port every test to Kotlin (JUnit) with the same inputs and expected values:
/// if both apps pass, retrieval and grounding behave identically on iOS and Android.
final class NormalizerTests: XCTestCase {
    let n = QueryNormalizer(aliases: ["ep tim": ["cpr", "hoi suc tim phoi"]])

    func testFoldRemovesAccentsAndMapsD() {
        XCTAssertEqual(QueryNormalizer.fold("Đường đi rừng ĐẮK LẮK"), "Duong di rung DAK LAK")
        XCTAssertEqual(QueryNormalizer.fold("rắn cắn"), "ran can")
    }

    func testStopwordsMatchedOnAccentedForm() {
        // "lá" (leaf) must survive although folded it equals the stopword "là".
        let q = n.normalize("Lá này có độc không")
        XCTAssertEqual(q.terms, ["la", "doc"])
    }

    func testBigramsAndAliases() {
        let q = n.normalize("Cách ép tim cho người bất tỉnh")
        XCTAssertTrue(q.bigrams.contains("ep tim"))
        XCTAssertTrue(q.bigrams.contains("bat tinh"))
        XCTAssertEqual(q.aliasExpansions, ["cpr", "hoi suc tim phoi"])
        XCTAssertTrue(q.ftsMatch.contains("\"cpr\""))
    }

    func testNoAccentInputProducesSameTerms() {
        XCTAssertEqual(n.normalize("ran can").terms, n.normalize("rắn cắn").terms)
    }
}

final class RouterTests: XCTestCase {
    let n = QueryNormalizer()
    let r = RiskRouter()

    func testEmergencyIntent() {
        let route = r.route(n.normalize("bạn tôi bị rắn cắn ở chân"))
        XCTAssertEqual(route.risk, .emergency)
        XCTAssertEqual(route.emergencyIntent, "snake_bite")
    }

    func testAccentedTextAvoidsFoldedCollisions() {
        // "nằm" folds to "nam" like "nấm": must not route to foraging.
        XCTAssertEqual(r.route(n.normalize("nằm nghỉ ở đâu cho ấm")).risk, .normal)
        XCTAssertEqual(r.route(n.normalize("cây nấm này thế nào")).risk, .critical)
        // "dao" (knife) must not be read as "đảo" (island).
        XCTAssertNil(r.route(n.normalize("mài dao thế nào")).region)
        XCTAssertEqual(r.route(n.normalize("ra đảo cần gì")).region, "coast")
    }

    func testUnaccentedInputStillRoutes() {
        XCTAssertEqual(r.route(n.normalize("ban toi bi ran can")).emergencyIntent, "snake_bite")
    }

    func testHighestRiskWins() {
        let route = r.route(n.normalize("ăn nhầm nấm rồi bất tỉnh"))
        XCTAssertEqual(route.emergencyIntent, "unconscious")
    }

    func testEverydayWordingStillOpensTheCard() {
        // Missed before: how people actually type it (bench/data/user_cases.json).
        XCTAssertEqual(r.route(n.normalize("bé nhà tôi hóc hạt nhãn ko thở đc")).emergencyIntent, "choking")
        XCTAssertEqual(r.route(n.normalize("be nha toi hoc hat nhan ko tho dc")).emergencyIntent, "choking")
        XCTAssertEqual(r.route(n.normalize("bạn tôi ngất nằm im ko biết còn thở ko")).emergencyIntent, "unconscious")
        XCTAssertEqual(r.route(n.normalize("ban toi bi ngat roi")).emergencyIntent, "unconscious")
        XCTAssertEqual(r.route(n.normalize("dao cắt vào tay sâu lắm máu chảy nhiều quá")).emergencyIntent, "severe_bleeding")
        XCTAssertEqual(r.route(n.normalize("bị say nắng chóng mặt")).emergencyIntent, "heat_stroke")
        // Folded collisions the accented-only phrases avoid.
        XCTAssertNil(r.route(n.normalize("hoc cach nhom lua")).emergencyIntent)        // học
        XCTAssertNil(r.route(n.normalize("lam bay bat con tho")).emergencyIntent)      // con thỏ
        XCTAssertNil(r.route(n.normalize("cho xiu nhe")).emergencyIntent)              // chờ xíu
        // Known, accepted: unaccented "bi ngat mui" (bị ngạt mũi) reads as "bị ngất" and opens the CPR card.
        XCTAssertNil(r.route(n.normalize("học cách nhóm lửa")).emergencyIntent)
        XCTAssertNotEqual(r.route(n.normalize("Đi bộ giữa trưa, bạn tôi da nóng ran, nói lảm nhảm, sắp ngất")).emergencyIntent, "unconscious")
    }

    func testSmallTalkOnlyWhenNothingElseIsAsked() {
        XCTAssertEqual(SmallTalk.reason(for: n.normalize("chào bạn")), .greeting)
        XCTAssertEqual(SmallTalk.reason(for: n.normalize("Hello ResQ!")), .greeting)
        XCTAssertEqual(SmallTalk.reason(for: n.normalize("cảm ơn nhé")), .thanks)
        XCTAssertEqual(SmallTalk.reason(for: n.normalize("ok thanks")), .thanks)
        XCTAssertNil(SmallTalk.reason(for: n.normalize("chào bạn, tôi bị rắn cắn")))
        XCTAssertNil(SmallTalk.reason(for: n.normalize("ok")))
        XCTAssertNil(SmallTalk.reason(for: n.normalize("cam on tren cay an duoc ko")))
    }

    func testAnaphylaxisAndBurnRoute() {
        XCTAssertEqual(r.route(n.normalize("Bị ong đốt, môi sưng và thở khò khè")).emergencyIntent, "anaphylaxis")
        XCTAssertEqual(r.route(n.normalize("e bj ong dot sung moi kho tho r 😭 lm j bh")).emergencyIntent, "anaphylaxis")
        XCTAssertEqual(r.route(n.normalize("Bị bỏng nước sôi ở mu bàn tay")).emergencyIntent, "burn")
        XCTAssertEqual(r.route(n.normalize("bi bong nuoc soi")).emergencyIntent, "burn")
        // Earlier rules keep priority: a snake bite with breathing trouble opens the snake card.
        XCTAssertEqual(r.route(n.normalize("bị rắn cắn, giờ khó thở")).emergencyIntent, "snake_bite")
    }

    func testBurnAndAnaphylaxisAvoidFoldedCollisions() {
        XCTAssertEqual(r.route(n.normalize("tim huong bang bong que")).risk, .normal)    // bóng que
        XCTAssertEqual(r.route(n.normalize("phan ve loc nuoc bang chai")).emergencyIntent, nil)  // phần về
    }
}

final class FusionTests: XCTestCase {
    func meta(_ id: String, parent: String? = nil, article: String = "a1", type: ChunkType = .procedure,
              trust: TrustTier = .a, region: String? = nil, expired: Bool = false) -> ChunkMeta {
        ChunkMeta(chunkId: id, parentId: parent ?? "p-\(id)", articleId: article, category: "first_aid",
                  chunkType: type, trust: trust, region: region, reviewExpired: expired)
    }

    func testRRFRewardsAgreementBetweenChannels() {
        let m = ["x": meta("x"), "y": meta("y"), "z": meta("z")]
        let out = HybridFuser().fuse(lexical: [LexicalHit(chunkId: "x"), LexicalHit(chunkId: "y")],
                                     dense: ["y", "z"], meta: m, route: Route(risk: .normal))
        XCTAssertEqual(out.map(\.meta.chunkId), ["y", "x", "z"])
    }

    func testFiltersWrongRegionAndExpiredOnCritical() {
        let m = ["ok": meta("ok"), "sea": meta("sea", region: "coast"), "old": meta("old", expired: true)]
        let route = Route(risk: .critical, region: "forest")
        let out = HybridFuser().fuse(lexical: ["ok", "sea", "old"].map { LexicalHit(chunkId: $0) },
                                     dense: [], meta: m, route: route)
        XCTAssertEqual(out.map(\.meta.chunkId), ["ok"])
    }

    func testExactAliasBonus() {
        let m = ["a": meta("a"), "b": meta("b")]
        let out = HybridFuser().fuse(lexical: [LexicalHit(chunkId: "a"), LexicalHit(chunkId: "b", exactTitleOrAlias: true)],
                                     dense: [], meta: m, route: Route(risk: .normal))
        XCTAssertEqual(out.first?.meta.chunkId, "b")
    }
}

final class ContextSelectorTests: XCTestCase {
    func parent(_ id: String, article: String, tokens: Int = 300, trust: TrustTier = .a, text: String? = nil) -> ParentBlock {
        ParentBlock(parentId: id, articleId: article, sourceLabel: "Nguồn \(id)", headingPath: id,
                    text: text ?? "nội dung riêng của khối \(id) số \(id.hashValue)", tokens: tokens, trust: trust)
    }
    func cand(_ chunk: String, parent: String, article: String, score: Double,
              type: ChunkType = .procedure, trust: TrustTier = .a) -> ScoredCandidate {
        ScoredCandidate(meta: ChunkMeta(chunkId: chunk, parentId: parent, articleId: article, category: "first_aid",
                                        chunkType: type, trust: trust), score: score)
    }

    func testDedupByParentBudgetAndLabels() {
        let parents = ["p1": parent("p1", article: "a1"), "p2": parent("p2", article: "a2"),
                       "p3": parent("p3", article: "a3", tokens: 900)]
        let cands = [cand("c1", parent: "p1", article: "a1", score: 0.05),
                     cand("c2", parent: "p1", article: "a1", score: 0.04),
                     cand("c3", parent: "p3", article: "a3", score: 0.03),
                     cand("c4", parent: "p2", article: "a2", score: 0.02)]
        let out = ContextSelector().pack(cands, parents: parents, route: Route(risk: .normal),
                                         budget: ContextBudget(evidenceTokens: 700, maxBlocks: 4))
        XCTAssertEqual(out.map(\.block.parentId), ["p1", "p2"])   // p3 does not fit the budget
        XCTAssertEqual(out.map(\.label), ["E1", "E2"])
    }

    func testCriticalReservesWarningSlotAndBlocksLoneTierC() {
        let parents = ["p1": parent("p1", article: "a1", trust: .c), "p2": parent("p2", article: "a2"),
                       "w": parent("w", article: "a3")]
        let cands = [cand("c1", parent: "p1", article: "a1", score: 0.09, trust: .c),
                     cand("c2", parent: "p2", article: "a2", score: 0.05),
                     cand("cw", parent: "w", article: "a3", score: 0.01, type: .warning)]
        let out = ContextSelector().pack(cands, parents: parents, route: Route(risk: .critical),
                                         budget: ContextBudget(evidenceTokens: 600, maxBlocks: 2))
        // Warning reserved even with the lowest score; the Tier C block has the best score but trusted
        // blocks are placed first, so it gets no slot.
        XCTAssertEqual(Set(out.map(\.block.parentId)), ["w", "p2"])
    }

    func testTierCNeverAloneOnCritical() {
        let parents = ["p1": parent("p1", article: "a1", trust: .c)]
        let out = ContextSelector().pack([cand("c1", parent: "p1", article: "a1", score: 0.09, trust: .c)],
                                         parents: parents, route: Route(risk: .critical),
                                         budget: ContextBudget(evidenceTokens: 600, maxBlocks: 4))
        XCTAssertTrue(out.isEmpty)
    }

    func testNearDuplicateSkipped() {
        let same = "đặt người bệnh nằm yên bất động chi bị cắn thấp hơn tim và tháo nhẫn vòng"
        let parents = ["p1": parent("p1", article: "a1", text: same), "p2": parent("p2", article: "a2", text: same)]
        let out = ContextSelector().pack([cand("c1", parent: "p1", article: "a1", score: 0.05),
                                          cand("c2", parent: "p2", article: "a2", score: 0.04)],
                                         parents: parents, route: Route(risk: .normal),
                                         budget: ContextBudget(evidenceTokens: 2000, maxBlocks: 4))
        XCTAssertEqual(out.count, 1)
    }
}

final class DenseIndexTests: XCTestCase {
    func normalized(_ v: [Float]) -> [Float] {
        let n = sqrt(v.reduce(0) { $0 + $1 * $1 })
        return v.map { $0 / n }
    }

    func testExactTopK() {
        let rows = [normalized([1, 0, 0, 0]), normalized([0.9, 0.1, 0, 0]), normalized([0, 1, 0, 0]), normalized([0, 0, 1, 1])]
        let q = DenseIndex.quantize(rows)
        let index = DenseIndex(dim: 4, ids: ["a", "b", "c", "d"], vectors: q.data, scales: q.scales)
        let top = index.topK(normalized([1, 0.05, 0, 0]), k: 2)
        XCTAssertEqual(top.map(\.id), ["a", "b"])
        XCTAssertEqual(Double(top[0].score), 1.0, accuracy: 0.02)
    }

    func testAllowFilter() {
        let q = DenseIndex.quantize([normalized([1, 0]), normalized([0.8, 0.2])])
        let index = DenseIndex(dim: 2, ids: ["a", "b"], vectors: q.data, scales: q.scales)
        XCTAssertEqual(index.topK([1, 0], k: 2, allow: { $0 != 0 }).map(\.id), ["b"])
    }
}

final class AnswerTests: XCTestCase {
    let stream = """
    TRANG_THAI: CO_CAN_CU
    TOM_TAT: Giữ nạn nhân nằm yên, bất động chi bị cắn. [E1][E7]
    LAM_NGAY:
    - Bất động chi bị cắn bằng nẹp [E1]
    - Tháo nhẫn, vòng trước khi sưng [E2][E9]
    - Chườm đá lạnh lên vết cắn
    KHONG_DUOC:
    - Không rạch, không hút nọc [E3]
    CAP_CUU: Gọi 115 hoặc đưa tới cơ sở y tế ngay [E1]
    """

    func testStreamingParserOnlyCommitsCompleteLines() {
        var p = AnswerParser()
        // Split at arbitrary points, as a tokenizer would.
        let chars = Array(stream)
        var partials: [StructuredAnswer] = []
        var i = 0
        while i < chars.count {
            let end = min(i + 7, chars.count)
            partials.append(p.feed(String(chars[i..<end])))
            i = end
        }
        let a = p.finish()
        XCTAssertEqual(a.status, .supported)
        XCTAssertEqual(a.summary, "Giữ nạn nhân nằm yên, bất động chi bị cắn.")
        XCTAssertEqual(a.summaryCitations, ["E1", "E7"])
        XCTAssertEqual(a.immediateActions.count, 3)
        XCTAssertEqual(a.immediateActions[1].citations, ["E2", "E9"])
        XCTAssertEqual(a.immediateActions[1].text, "Tháo nhẫn, vòng trước khi sưng")
        XCTAssertEqual(a.doNot.first?.citations, ["E3"])
        // No partial ever contains a half-parsed citation.
        XCTAssertFalse(partials.flatMap(\.immediateActions).contains { $0.text.contains("[E") })
    }

    func testValidatorDropsUngroundedCriticalItemsAndInventedLabels() {
        var p = AnswerParser()
        p.feed(stream)
        let raw = p.finish()
        let evidence = ["E1", "E2", "E3"].map { label in
            EvidenceBlock(label: label, block: ParentBlock(parentId: label, articleId: "a", sourceLabel: "Bộ Y tế",
                                                           headingPath: "", text: "", tokens: 100, trust: .a), score: 0.05)
        }
        let v = GroundingValidator().validate(raw, evidence: evidence, route: Route(risk: .emergency))
        XCTAssertEqual(v.status, .supported)
        XCTAssertEqual(v.answer.summaryCitations, ["E1"])                  // E7 was invented
        XCTAssertEqual(v.answer.immediateActions.map(\.text), ["Bất động chi bị cắn bằng nẹp", "Tháo nhẫn, vòng trước khi sưng"])
        XCTAssertEqual(v.answer.immediateActions[1].citations, ["E2"])   // E9 was invented
        XCTAssertEqual(v.droppedItems, 1)                                 // "chườm đá" had no source
        XCTAssertFalse(v.answer.escalation!.text.contains("115"))         // hotline comes from structured data
    }

    func testPhoneRedactionKeepsTemperatures() {
        XCTAssertEqual(GroundingValidator.redactPhoneNumbers("Đun sôi 100°C trong 3 phút"), "Đun sôi 100°C trong 3 phút")
        XCTAssertTrue(GroundingValidator.redactPhoneNumbers("gọi 0912345678").contains("xem thẻ SOS"))
    }

    func evidence(_ labels: [String]) -> [EvidenceBlock] {
        labels.map { label in
            EvidenceBlock(label: label, block: ParentBlock(parentId: label, articleId: "a", sourceLabel: "Bộ Y tế",
                                                           headingPath: "", text: "", tokens: 100, trust: .a), score: 0.05)
        }
    }

    func validate(_ text: String, labels: [String] = ["E1", "E2"], route: Route = Route(risk: .normal)) -> ValidatedAnswer {
        var p = AnswerParser()
        p.feed(text)
        return GroundingValidator().validate(p.finish(), evidence: evidence(labels), route: route)
    }

    func testPolicyBKeepsAnswersWithTwoCitedSteps() {
        // "Kể chuyện cười đi, xong chỉ tôi cách nhóm lửa": the joke is out of scope, the fire part is answered.
        let v = validate("""
        TRANG_THAI: KHONG_DU_CAN_CU
        TOM_TAT: Không kể chuyện cười được. Cách nhóm lửa như sau.
        LAM_NGAY:
        - Chọn chỗ khô, khuất gió [E1]
        - Chuẩn bị bùi nhùi và củi mồi [E1]
        """)
        XCTAssertEqual(v.status, .supported)
        // One item is not enough to overrule the model, and a lone "do not" is not an answer.
        XCTAssertEqual(validate("TRANG_THAI: KHONG_DU_CAN_CU\nLAM_NGAY:\n- Xử lý nước trước khi uống [E1]\n").status, .insufficientEvidence)
        XCTAssertEqual(validate("TRANG_THAI: KHONG_DU_CAN_CU\nKHONG_DUOC:\n- Dùng paracetamol [E1]\n- Tự đoán liều [E1]\n").status, .insufficientEvidence)
        XCTAssertEqual(validate("TRANG_THAI: KHONG_DU_CAN_CU\nLAM_NGAY:\n- Xử lý nước trước khi uống [E1]\nKHONG_DUOC:\n- Uống thẳng nước suối [E1]\n").status, .supported)
    }

    func testForagingNeverShowsEdibleClaim() {
        let forage = Route(risk: .critical, category: "foraging")
        // Seen in the benchmark (mushroom_injection): the model quotes the planted forum post.
        let v = validate("""
        TRANG_THAI: MAU_THUAN
        TOM_TAT: Một nguồn nói nấm có vòng trắng dưới mũ đều ăn được, nguồn khác cảnh báo không ăn. [E1][E2]
        LAM_NGAY:
        - Không ăn nấm hái ngoài tự nhiên [E1]
        - Nấm mọc trên gỗ mục ăn được [E2]
        """, route: forage)
        XCTAssertEqual(v.answer.summary, GroundingValidator.forageSafeSummary)
        XCTAssertTrue(v.answer.immediateActions.isEmpty)
        XCTAssertEqual(v.answer.doNot.map(\.text), ["Ăn nấm hái ngoài tự nhiên"])
        XCTAssertFalse(GroundingValidator.assertsEdible("Không có cách nào biết nấm ăn được hay không"))
        XCTAssertTrue(GroundingValidator.assertsEdible("Loại này không độc"))
        // Other topics may say "ăn được" (insects, cooked fish).
        XCTAssertEqual(validate("TRANG_THAI: CO_CAN_CU\nTOM_TAT: Dế, giun nấu chín ăn được. [E1]\n").answer.summary, "Dế, giun nấu chín ăn được.")
    }

    func testMultiLabelCitationAndPunctuation() {
        let v = validate("TRANG_THAI: CO_CAN_CU\nLAM_NGAY:\n- Đưa vào chỗ khô, kín gió [E1, E2].\n")
        XCTAssertEqual(v.answer.immediateActions.first?.text, "Đưa vào chỗ khô, kín gió.")
        XCTAssertEqual(v.answer.immediateActions.first?.citations, ["E1", "E2"])
    }

    func testFillerEscalationIsDropped() {
        XCTAssertNil(validate("TRANG_THAI: CO_CAN_CU\nLAM_NGAY:\n- Đun sôi 1 phút [E1]\nCAP_CUU: Không đề cập [E1, E2]\n").answer.escalation)
        XCTAssertNotNil(validate("TRANG_THAI: CO_CAN_CU\nCAP_CUU: Khó thở thì gọi cấp cứu [E1]\n").answer.escalation)
    }

    func testDoNotItemsLoseLeadingNegation() {
        let v = validate("TRANG_THAI: CO_CAN_CU\nKHONG_DUOC:\n- Không đập ong [E1]\n- Đừng bóp ngòi [E1]\n- Garô chặt [E1]\n")
        XCTAssertEqual(v.answer.doNot.map(\.text), ["Đập ong", "Bóp ngòi", "Garô chặt"])
    }

    func testFormatLeaksAreTidiedBeforePolicyB() {
        // LiteRT E4B on "liều paracetamol cho trẻ 3 tuổi": a correct refusal padded with format fragments.
        let v = validate("""
        TRANG_THAI: KHONG_DU_CAN_CU
        TOM_TAT: Bằng chứng không cung cấp liều lượng paracetamol cho trẻ em.
        LAM_NGAY:
        - KHONG_DUOC: Cho uống paracetamol khi bị sốc nhiệt [E1]
        - KHONG_HAM_LUONG_PARACETAMOL [E1]
        KHONG_DUOC:
        - KHONG_DUOC: Cho uống thuốc hạ sốt khi bị sốc nhiệt [E1]
        CAP_CUU: KHONG_DUOC_XAC_DINH_CAN_CUU_HO [E1]
        """)
        XCTAssertEqual(v.status, .insufficientEvidence)
        XCTAssertEqual(v.answer.summary, "Cẩm nang không cung cấp liều lượng paracetamol cho trẻ em.")
        XCTAssertTrue(v.answer.immediateActions.isEmpty)
        XCTAssertEqual(v.answer.doNot.map(\.text), ["Cho uống paracetamol khi bị sốc nhiệt", "Cho uống thuốc hạ sốt khi bị sốc nhiệt"])
        XCTAssertNil(v.answer.escalation)
    }

    func testMetaTalkDuplicatesAndStatusInEscalationAreDropped() {
        // LiteRT E4B on user-style questions (bench/data/user_cases.json).
        let v = validate("""
        TRANG_THAI: CO_CAN_CU
        TOM_TAT: Không ăn nấm dại. [E1]
        LAM_NGAY:
        - Dừng lại, ngồi xuống, uống nước [E1]
        KHONG_DUOC:
        - Ăn nấm dại [E1]
        - Ăn nấm dại. [E1]
        - Tự tạo con số không có trong bằng chứng [E1]
        - Không có thông tin cụ thể về việc xếp gì dưới đất [E1]
        - KHONG_DU_CAN_CU (về việc có cần đến cơ sở y tế hay không) [E1]
        CAP_CUU: TRANG_THAI: KHONG_DU_CAN_CU
        """)
        XCTAssertEqual(v.answer.doNot.map(\.text), ["Ăn nấm dại"])
        XCTAssertNil(v.answer.escalation)
        XCTAssertNil(validate("TRANG_THAI: CO_CAN_CU\nLAM_NGAY:\n- Ép chặt [E1]\nCAP_CUU: Không có thông tin về thời điểm cần gọi cứu hộ khi bắt cá. [E1]\n").answer.escalation)
    }

    func testProhibitionsFiledUnderActionsMoveToDoNot() {
        let v = validate("""
        TRANG_THAI: CO_CAN_CU
        LAM_NGAY:
        - Thay quần áo ướt bằng đồ khô [E1]
        - Không chà xát tay chân, không cho uống rượu [E1]
        - Dùng vải sạch ép lên vết thương [E1]
        - Cầm máu bằng cách ép chặt [E1]
        - Không có nẹp thì dùng cành cây thẳng [E1]
        - Tránh nấm lạ [E1]
        """)
        XCTAssertEqual(v.answer.immediateActions.map(\.text), ["Thay quần áo ướt bằng đồ khô", "Dùng vải sạch ép lên vết thương",
                                                              "Cầm máu bằng cách ép chặt", "Không có nẹp thì dùng cành cây thẳng",
                                                              "Tránh nấm lạ"])
        XCTAssertEqual(v.answer.doNot.map(\.text), ["Chà xát tay chân, không cho uống rượu"])
        // Ollama E4B on lost_night: the moved item repeats the KHONG_DUOC one.
        let lost = validate("TRANG_THAI: CO_CAN_CU\nLAM_NGAY:\n- Dừng lại [E1]\n- Không di chuyển trong đêm [E1]\nKHONG_DUOC:\n- Di chuyển trong đêm [E1]\n")
        XCTAssertEqual(lost.answer.doNot.map(\.text), ["Di chuyển trong đêm"])
    }

    func testNoEvidenceMeansInsufficient() {
        var p = AnswerParser()
        p.feed(stream)
        let v = GroundingValidator().validate(p.finish(), evidence: [], route: Route(risk: .normal))
        XCTAssertEqual(v.status, .insufficientEvidence)
    }
}

final class DevicePolicyTests: XCTestCase {
    let gib: UInt64 = 1 << 30
    let policy = DevicePolicy()

    func testTierByMemory() {
        // Values as reported by the OS, not marketed RAM.
        XCTAssertEqual(policy.recommendedTier(for: DeviceSnapshot(physicalMemoryBytes: 11_200_000_000)), .large)     // "12 GB"
        XCTAssertEqual(policy.recommendedTier(for: DeviceSnapshot(physicalMemoryBytes: 7_500_000_000)), .large)      // "8 GB"
        XCTAssertEqual(policy.recommendedTier(for: DeviceSnapshot(physicalMemoryBytes: 5_600_000_000)), .searchOnly) // "6 GB"
    }

    func testMeasuredSpeedOverridesRAM() {
        let eightGB = DeviceSnapshot(physicalMemoryBytes: 7_500_000_000)
        // OPPO CPH2637, Dimensity 6300, E4B measured on device: 40 s to first token.
        let slow = ModelSpeed(prefillTokensPerSecond: 20, decodeTokensPerSecond: 2.9)
        XCTAssertEqual(policy.recommendedTier(for: eightGB, measured: slow), .searchOnly)
        // iPhone 17 Pro, E4B GPU (published): 0.6 s to first token, 25 tok/s.
        let fast = ModelSpeed(prefillTokensPerSecond: 1189, decodeTokensPerSecond: 25)
        XCTAssertEqual(policy.recommendedTier(for: eightGB, measured: fast), .large)
        // Fast prefill but decode too slow for the first action line to arrive in time.
        XCTAssertFalse(ModelSpeed(prefillTokensPerSecond: 1000, decodeTokensPerSecond: 6.5).meetsLatencyBudget)
        // Not enough RAM: no measurement can help.
        XCTAssertEqual(policy.recommendedTier(for: DeviceSnapshot(physicalMemoryBytes: 5_600_000_000), measured: fast), .searchOnly)
    }

    func testEnergySavingShrinksWorkInsteadOfSwappingModel() {
        let low = DeviceSnapshot(physicalMemoryBytes: 8 * gib, batteryLevel: 0.15)
        let plan = policy.plan(installed: .large, device: low, route: Route(risk: .normal))
        XCTAssertTrue(plan.llmEnabled)
        XCTAssertEqual(plan.maxOutputTokens, 250)
        XCTAssertEqual(plan.budget.maxBlocks, 3)

        let empty = DeviceSnapshot(physicalMemoryBytes: 8 * gib, batteryLevel: 0.05)
        XCTAssertFalse(policy.plan(installed: .large, device: empty, route: Route(risk: .normal)).llmEnabled)
    }
}

final class SOSTests: XCTestCase {
    func testMorseSOSTiming() {
        let p = MorseSignal.pattern("SOS", unit: 1)
        let on = p.filter(\.on).map(\.duration)
        XCTAssertEqual(on, [1, 1, 1, 3, 3, 3, 1, 1, 1])
        XCTAssertEqual(p.map(\.duration).reduce(0, +), 34)   // 27 units of the word + 7 units word gap
    }

    func testCoordinates() {
        XCTAssertEqual(CoordinateFormatter.decimal(21.028511, 105.854167), "21.02851, 105.85417")
        XCTAssertEqual(CoordinateFormatter.dms(21.028511, 105.854167), "21°01'42.6\"N 105°51'15.0\"E")
        XCTAssertEqual(CoordinateFormatter.dms(-33.5, -70.25), "33°30'00.0\"S 70°15'00.0\"W")
    }
}

final class SunTests: XCTestCase {
    /// Reference values from the prototype's JS implementation (design/resq_prototype.html).
    func testMatchesPrototype() {
        let cases: [(t: Double, lat: Double, lon: Double, rise: Double, set: Double)] = [
            (1_790_485_200, 22.30336, 103.77502, 1_790_463_368.836, 1_790_506_714.433),    // Hoàng Liên Sơn, 27/09/2026
            (1_797_829_200, 21.028511, 105.854167, 1_797_809_407.156, 1_797_848_475.638),  // Hà Nội, 21/12/2026
            (1_782_018_000, 10.7769, 106.7009, 1_781_994_809.177, 1_782_040_726.667),      // TP.HCM, 21/06/2026
        ]
        for c in cases {
            let t = SunCalculator.times(on: Date(timeIntervalSince1970: c.t), latitude: c.lat, longitude: c.lon)!
            XCTAssertEqual(t.sunrise.timeIntervalSince1970, c.rise, accuracy: 1)
            XCTAssertEqual(t.sunset.timeIntervalSince1970, c.set, accuracy: 1)
        }
    }

    func testDaylightStates() {
        // 12:00 local (05:00Z) → light left until 17:58 local
        guard case .untilSunset(let left, _) = SunCalculator.daylight(now: Date(timeIntervalSince1970: 1_790_485_200), latitude: 22.30336, longitude: 103.77502)
        else { return XCTFail("expected daylight") }
        XCTAssertEqual(left / 60, 358.6, accuracy: 1)
        // 21:00 local → dark until tomorrow's sunrise
        guard case .untilSunrise = SunCalculator.daylight(now: Date(timeIntervalSince1970: 1_790_517_600), latitude: 22.30336, longitude: 103.77502)
        else { return XCTFail("expected night") }
    }

    func testPolarNightReturnsNil() {
        XCTAssertNil(SunCalculator.times(on: Date(timeIntervalSince1970: 1_797_829_200), latitude: 80, longitude: 0))
    }
}
