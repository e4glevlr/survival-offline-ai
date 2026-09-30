import XCTest

/// Walks every screen and saves screenshots to $SCREENSHOT_DIR (default /tmp/resq-shots).
/// Tests run in name order and share app data, so later ones see earlier history/saves/pins.
@MainActor
final class ScreenTour: XCTestCase {
    let app = XCUIApplication()
    lazy var dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/resq-shots"

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        app.launch()
    }

    func shot(_ name: String, wait: UInt32 = 1) {
        sleep(wait)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func button(_ label: String) -> XCUIElement? {
        _ = app.buttons[label].firstMatch.waitForExistence(timeout: 5)
        return app.buttons.matching(identifier: label).allElementsBoundByIndex.first { $0.isHittable }
    }

    func tap(_ label: String) {
        let hit = button(label)
        XCTAssertNotNil(hit, "no hittable button \(label)")
        hit?.tap()
    }

    func tapContaining(_ text: String) {
        let e = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 5), "no button containing \(text)")
        e.tap()
    }

    /// Drags the sheet down by its top edge (a swipe in the middle would just scroll it).
    func closeSheet() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        sleep(1)
    }

    func ask(_ text: String) {
        let field = app.textFields["Hỏi ResQ…"].firstMatch.exists ? app.textFields["Hỏi ResQ…"].firstMatch : app.textViews.firstMatch
        field.tap()
        field.typeText(text)
        tap("Gửi")
    }

    func test01Home() {
        shot("01-home", wait: 3)
    }

    func test02FireAnswerSaveAndPin() {
        tapContaining("Nhóm lửa khi củi ướt")
        shot("02-fire-answer", wait: 7)
        tap("Lưu")
        tap("Ghim vị trí")
        shot("03-fire-saved-pinned")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Nhóm lửa khi ẩm ướt'")).firstMatch.tap()
        shot("04-source-sheet")
    }

    func test03EmergencyRouting() {
        ask("ban toi bi chay mau nhieu o chan")
        shot("05-bleeding-card", wait: 4)
    }

    func test04FishTopic() {
        tapContaining("Bắt cá")
        shot("06-fish-answer", wait: 7)
    }

    func test05Drawer() {
        tap("Mở menu")
        shot("07-drawer-history")
    }

    func test06Guides() {
        tap("Cẩm nang")
        app.swipeUp()
        shot("08-guides-saved")
        tapContaining("Lửa và giữ nhiệt")
        shot("09-pillar")
        tapContaining("Giữ ấm khi trời lạnh")
        shot("09b-article")
        app.swipeUp()
        shot("09c-article-warnings")
    }

    func test07Prep() {
        tap("Mở menu")
        tap("Trước chuyến đi")
        shot("10-prep")
    }

    func test08SOS() {
        tap("Mở màn hình SOS khẩn cấp")
        shot("11-sos-top")
        app.swipeUp()
        shot("12-sos-scrolled")
        app.swipeDown()
        app.swipeUp()
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Còi báo'")).firstMatch.press(forDuration: 1.0)
        shot("13-sos-whistle")
    }

    func test09SearchOnly() {
        tap("Mở menu")
        tap("Cài đặt")
        tapContaining("Chỉ tra cứu")
        closeSheet()
        tapContaining("Lọc nước suối")
        shot("14-search-only", wait: 4)
        tap("Mở menu")
        tap("Cài đặt")
        tapContaining("Gemma 4 E4B")
        closeSheet()
    }

    func test10LargeText() {
        tap("Mở menu")
        tap("Cài đặt")
        app.switches["Chữ lớn"].firstMatch.tap()
        shot("15-settings-large")
        closeSheet()
        shot("16-home-large")
        tap("Mở menu")
        tap("Cài đặt")
        app.switches["Chữ lớn"].firstMatch.tap()
    }

    func test11PhotoLibrary() {
        tap("Đính kèm")
        tap("Thư viện")
        sleep(12)
        shot("17-photo-picker")
        // The picker runs out of process: tap the first thumbnail by screen position.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.24)).tap()
        shot("18-photo-picked", wait: 3)
        if let send = button("Gửi") { send.tap() }
        shot("19-photo-answer", wait: 8)
    }

    func test12Voice() {
        addUIInterruptionMonitor(withDescription: "permissions") { alert in
            for label in ["Allow", "OK", "Cho phép"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
        tap("Nói")
        app.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            for label in ["Allow", "OK", "Cho phép"] where springboard.buttons[label].waitForExistence(timeout: 2) {
                springboard.buttons[label].tap()
            }
        }
        shot("20-voice", wait: 2)
    }
}
