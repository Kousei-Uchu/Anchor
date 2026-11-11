import XCTest

/// Records the real app, screen by screen, for the website demo (Patch 55b).
///
/// For every line in `screens` it starts the app fresh in demo mode (the made-up content, nothing
/// from a real phone), follows the taps listed, then writes two files to SHOT_DIR:
///   <name>.png   the screen
///   <name>.json  where every button is on it (in points), so the website can put a tappable area on top
///
/// scripts/make-demo-capture.sh runs this and scripts/sync-demo-screens.mjs turns the result into the demo.
/// The table is the one place that says which screens are in the demo. The script reads it from here.
///
/// A step is one of:
///   a tab name (Now, Plan, Journal, Bridge, Thread)  taps that tab
///   "@scroll"                                        swipes up once (the screen after the swipe is its own screen)
///   anything else                                    taps the button or row with that label, scrolling to find it
/// A tile that is below the fold needs no "@scroll" in its path. The test scrolls to find it, and the
/// website links it from the scrolled screen of its parent if it is not on the first one.
final class DemoCaptureTests: XCTestCase {

    // BEGIN SCREENS
    static let screens: [(String, [String])] = [
        ("now", []),
        ("now-more", ["@scroll"]),
        ("now-checkin", ["Check in"]),
        ("plan", ["Plan"]),
        ("plan-more", ["Plan", "@scroll"]),
        ("plan-contacts", ["Plan", "Contacts"]),
        ("plan-safety", ["Plan", "Safety plan"]),
        ("plan-grounding", ["Plan", "Grounding tools"]),
        ("plan-tasks", ["Plan", "Tasks"]),
        ("plan-deescalation", ["Plan", "De-escalation"]),
        ("plan-affirmations", ["Plan", "Affirmations"]),
        ("plan-counters", ["Plan", "Counters"]),
        ("journal", ["Journal"]),
        ("journal-more", ["Journal", "@scroll"]),
        ("bridge", ["Bridge"]),
        ("bridge-more", ["Bridge", "@scroll"]),
        ("bridge-prep", ["Bridge", "Session prep"]),
        ("bridge-feedback", ["Bridge", "Feedback loops"]),
        ("bridge-goals", ["Bridge", "Personal goals"]),
        ("thread", ["Thread"]),
        ("thread-more", ["Thread", "@scroll"]),
        ("thread-log", ["Thread", "Message log"]),
        ("thread-calendar", ["Thread", "Support calendar"]),
        ("thread-people", ["Thread", "People"]),
        ("thread-future", ["Thread", "To future me"]),
        ("thread-boundaries", ["Thread", "Boundaries"]),
    ]
    // END SCREENS

    private static let tabs: Set<String> = ["Now", "Plan", "Journal", "Bridge", "Thread"]

    private let env = ProcessInfo.processInfo.environment

    override func setUpWithError() throws {
        // One screen that cannot be reached must not stop the rest. It is listed in failed.txt instead.
        continueAfterFailure = true
    }

    func testCapture() throws {
        guard let outDir = env["SHOT_DIR"] else {
            XCTFail("SHOT_DIR is not set. Run scripts/make-demo-capture.sh.")
            return
        }
        let dir = URL(fileURLWithPath: outDir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let only = (env["DEMO_ONLY"] ?? "").split(separator: ",").map(String.init)
        let failedFile = dir.appendingPathComponent("failed.txt")
        try? FileManager.default.removeItem(at: failedFile)
        var failed: [String] = []

        for (name, path) in Self.screens {
            if !only.isEmpty && !only.contains(name) { continue }
            // Already captured on an earlier run: leave it (REDO=1 in the script clears the folder).
            let png = dir.appendingPathComponent("\(name).png")
            let json = dir.appendingPathComponent("\(name).json")
            if FileManager.default.fileExists(atPath: png.path) && FileManager.default.fileExists(atPath: json.path) { continue }
            if !capture(name: name, path: path, dir: dir) { failed.append("\(name): could not follow \(path.joined(separator: " > "))") }
        }
        if !failed.isEmpty {
            try? failed.joined(separator: "\n").appending("\n").write(to: failedFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: one screen

    private func capture(name: String, path: [String], dir: URL) -> Bool {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AnchorDemo",
            "-anchor.appLockEnabled", "NO",
            "-anchor.hasSeenTour", "YES",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_AU",
        ]
        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for title in ["Allow", "OK", "Allow While Using App"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launch()
        sleep(3)
        defer { app.terminate() }

        for step in path {
            guard follow(step, in: app) else { return false }
        }
        sleep(2)
        dismissSystemAlert()

        let shot = XCUIScreen.main.screenshot()
        let size = app.windows.firstMatch.frame.size
        do {
            try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
            let info: [String: Any] = [
                "name": name,
                "path": path,
                "width": size.width,
                "height": size.height,
                "scale": shot.image.scale,
                "elements": buttons(in: app, screen: size),
            ]
            let data = try JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: dir.appendingPathComponent("\(name).json"))
        } catch {
            return false
        }
        return true
    }

    private func follow(_ step: String, in app: XCUIApplication) -> Bool {
        if step == "@scroll" {
            app.swipeUp()
            sleep(1)
            return true
        }
        if Self.tabs.contains(step) {
            let bar = app.tabBars.buttons[step]
            guard bar.waitForExistence(timeout: 4) else { return false }
            bar.tap()
            sleep(2)
            dismissSystemAlert()
            return true
        }
        guard let element = find(step, in: app) else { return false }
        element.tap()
        sleep(2)
        dismissSystemAlert()
        return true
    }

    /// A button or row with this label, scrolling down up to four times to bring it into view.
    private func find(_ label: String, in app: XCUIApplication) -> XCUIElement? {
        let match = NSPredicate(format: "label == %@ OR label BEGINSWITH %@", label, label + ",")
        for attempt in 0..<5 {
            for query in [app.buttons, app.cells, app.staticTexts] {
                let element = query.matching(match).firstMatch
                if element.exists && element.isHittable { return element }
            }
            if attempt < 4 {
                app.swipeUp()
                sleep(1)
            }
        }
        return nil
    }

    /// Every button that is on the screen right now, with its place in points. The tab bar buttons come with them.
    private func buttons(in app: XCUIApplication, screen: CGSize) -> [[String: Any]] {
        guard let snapshot = try? app.snapshot() else { return [] }
        var found: [[String: Any]] = []
        func walk(_ node: XCUIElementSnapshot) {
            if node.elementType == .button, !node.label.isEmpty {
                let f = node.frame
                let visible = f.width > 1 && f.height > 1 && f.maxX > 0 && f.maxY > 0 && f.minX < screen.width && f.minY < screen.height
                let wholeScreen = f.width > screen.width * 0.95 && f.height > screen.height * 0.5
                if visible && !wholeScreen {
                    // Cut to the screen, so a half-visible row does not reach past the edge.
                    let x = max(0, f.minX), y = max(0, f.minY)
                    let w = min(screen.width, f.maxX) - x, h = min(screen.height, f.maxY) - y
                    found.append(["label": node.label, "x": x, "y": y, "w": w, "h": h])
                }
            }
            for child in node.children { walk(child) }
        }
        walk(snapshot)
        return found
    }

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
}
