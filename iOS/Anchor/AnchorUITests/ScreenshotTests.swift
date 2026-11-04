import XCTest

final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private let outDir = ProcessInfo.processInfo.environment["SHOT_DIR"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-AnchorDemo",
            "-anchor.appLockEnabled", "NO",
            "-anchor.hasSeenTour", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_AU"
        ]
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for title in ["Allow", "OK", "Allow While Using App"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launch()
        sleep(2)
    }

    private func shot(_ name: String) {
        if let outDir, FileManager.default.fileExists(atPath: URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png").path) {
            return
        }
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let outDir {
            try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png"))
        }
    }

    /// Dismisses a system permission alert if one is up (backup to the app change).
    private func dismissSystemAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.exists {
            for title in ["Don\u{2019}t Allow", "Don't Allow", "Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                break
            }
        }
    }

    /// Tells make-screenshots.sh when the tour starts, so it can trim the
    /// recording's lead-in (simulator install and launch time).
    private func markTourStart() {
        guard let outDir else { return }
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        try? stamp.write(toFile: URL(fileURLWithPath: outDir).appendingPathComponent("start.txt").path, atomically: true, encoding: .utf8)
    }

    private func tab(_ name: String, settle: UInt32 = 3) {
        let bar = app.tabBars.buttons[name]
        dismissSystemAlert()
        if bar.waitForExistence(timeout: 3) { bar.tap() } else { app.buttons[name].firstMatch.tap() }
        sleep(settle)
        dismissSystemAlert()
    }

    private func scroll(slow: Bool = false) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: slow ? 0.6 : 0.1, thenDragTo: end)
        sleep(2)
    }

    func testScreenshots() {
        shot("1-now")
        scroll()
        shot("2-now-scrolled")
        tab("Plan")
        shot("3-plan")
        tab("Journal")
        shot("4-journal")
        tab("Bridge")
        shot("5-bridge")
        tab("Thread")
        shot("6-thread")
        tab("Now")
        let checkIn = app.buttons["Check in"]
        if checkIn.waitForExistence(timeout: 3) {
            checkIn.tap()
            sleep(1)
            shot("7-checkin")
        }
    }

    func testTour() {
        markTourStart()
        sleep(2)
        scroll(slow: true)
        scroll(slow: true)
        sleep(2)
        for name in ["Plan", "Journal", "Bridge", "Thread", "Now"] {
            tab(name, settle: 1)
            sleep(1)
            scroll(slow: true)
            sleep(1)
        }
        sleep(2)
    }
}
