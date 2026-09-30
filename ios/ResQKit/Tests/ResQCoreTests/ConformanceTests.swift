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
