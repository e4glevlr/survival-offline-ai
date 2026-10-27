import XCTest

/// A first-time user poking around the way people do: small talk, typos, long rants, stopping an answer,
/// leaving the app mid-answer, rotating the phone, relaunching. Screenshots go to $SCREENSHOT_DIR
/// (default /tmp/resq-journey). Run on a fresh install; tests share app data in name order.
@MainActor
final class UserJourney: XCTestCase {
    let app = XCUIApplication()
    lazy var dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/resq-journey"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = .portrait
        app.launch()
    }

    func shot(_ name: String, wait: UInt32 = 1) {
        sleep(wait)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func tap(_ label: String) {
        _ = app.buttons[label].firstMatch.waitForExistence(timeout: 5)
        let hit = app.buttons.matching(identifier: label).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(hit, "no hittable button \(label)")
        hit?.tap()
    }

    var field: XCUIElement { app.textFields["Hỏi ResQ…"].firstMatch.exists ? app.textFields["Hỏi ResQ…"].firstMatch : app.textViews.firstMatch }

    func type(_ text: String) {
        field.tap()
        field.typeText(text)
    }

    func ask(_ text: String) {
        type(text)
        tap("Gửi")
    }

    func sees(_ text: String, timeout: TimeInterval = 8) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.waitForExistence(timeout: timeout)
    }

    func newChat() {
        tap("Mở menu")
        tap("Cuộc hỏi mới")
    }

    func test01FreshInstallEmptySend() {
        shot("01-first-launch", wait: 3)
        // Only spaces: no send button should appear, the mic stays.
        type("   ")
        XCTAssertFalse(app.buttons["Gửi"].exists, "send shown for a blank message")
        shot("02-blank-draft")
    }

    func test02SmallTalk() {
        ask("chào bạn")
        XCTAssertTrue(sees("Mình là ResQ"), "no greeting reply")
        XCTAssertFalse(app.staticTexts["Không đủ căn cứ"].exists, "greeting answered with a warning")
        shot("03-hello", wait: 2)
        ask("cảm ơn nhé")
        XCTAssertTrue(sees("Không có gì"), "no thanks reply")
        shot("04-thanks", wait: 2)
    }

    func test03NoDiacriticsTypo() {
        ask("lam sao loc nuoc suoi cho sach dc ko")
        shot("05-typo-water", wait: 7)
    }

    func test04LongRant() {
        ask("trời ơi tôi đi phượt một mình bị lạc từ chiều 😭😭 điện thoại còn 15% pin, trời bắt đầu tối và mưa lâm thâm, tôi có một chai nước nửa lít với gói mì, chân hơi đau vì trượt ngã lúc nãy, giờ nên làm gì trước???")
        XCTAssertTrue(sees("Dừng lại"), "lost-person rant not answered from the 'Khi bị lạc' guide")
        shot("06-long-rant", wait: 5)
        app.swipeUp()
        shot("07-long-rant-scrolled")
    }

    func test05StopMidAnswerThenAskAgain() {
        ask("nhóm lửa khi củi ướt")
        sleep(1)
        tap("Dừng")
        XCTAssertTrue(sees("Đã dừng", timeout: 3), "stopped answer has no stopped state")
        XCTAssertFalse(app.staticTexts["Đang viết"].exists, "stopped answer still says it is writing")
        shot("08-stopped", wait: 1)
        ask("vậy còn bắt cá ở suối")
        shot("09-after-stop", wait: 7)
    }

    func test06LeaveAppMidAnswer() {
        ask("ban toi bi ran can o chan")
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        shot("10-back-from-home", wait: 6)
    }

    func test07HistoryReopen() {
        tap("Mở menu")
        shot("11-drawer-history")
        let item = app.buttons.matching(NSPredicate(format: "label CONTAINS 'loc nuoc suoi'")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "typo question missing from history")
        item.tap()
        shot("12-history-reopened", wait: 7)
    }

    func test08GuideSearchLikePeopleType() {
        tap("Cẩm nang")
        for (i, q) in ["bong gan", "treo chan", "ran can", "asdfgh"].enumerated() {
            let search = app.textFields.firstMatch
            search.tap()
            if let old = search.value as? String, !old.isEmpty, !old.hasPrefix("Tìm") {
                search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            }
            search.typeText(q)
            if q == "treo chan" { XCTAssertTrue(sees("Bong gân", timeout: 3), "'treo chan' does not find the sprain guide") }
            shot("13-search-\(i)-\(q.replacingOccurrences(of: " ", with: "-"))")
        }
    }

    func test09AskFromArticle() {
        tap("Cẩm nang")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sơ cứu dã ngoại'")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Vắt'")).firstMatch.tap()
        shot("14-leech-article", wait: 2)
        app.swipeUp(); app.swipeUp()
        let ask = app.buttons["Hỏi ResQ về bài này"].firstMatch
        if ask.waitForExistence(timeout: 3) { ask.tap() }
        XCTAssertTrue(sees("Có căn cứ"), "asking about a guide article gets no grounded answer")
        shot("15-ask-from-article", wait: 5)
    }

    func test10Landscape() {
        ask("cách lọc nước")
        sleep(6)
        XCUIDevice.shared.orientation = .landscapeLeft
        shot("16-landscape-answer", wait: 2)
        tap("Cẩm nang")
        shot("17-landscape-guides", wait: 2)
        XCUIDevice.shared.orientation = .portrait
    }

    func test11NightThemeAnswer() {
        tap("Mở menu")
        tap("Cài đặt")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Nhìn đêm'")).firstMatch.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        newChat()
        ask("lọc nước suối")
        shot("18-night-answer", wait: 7)
        tap("Mở menu")
        tap("Cài đặt")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Tối'")).firstMatch.tap()
    }

    func test12RelaunchKeepsHistory() {
        app.terminate()
        app.launch()
        tap("Mở menu")
        shot("19-relaunch-drawer", wait: 2)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'chào bạn'")).firstMatch.exists,
                      "history lost after relaunch")
    }
}
