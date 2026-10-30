import UniformTypeIdentifiers
import XCTest

/// Claim 6 with the app as a user leaves it: a copied phrase is gone from the pasteboard once its
/// lifetime is up, while Keyper sits in the background or after it was terminated. iOS removes it
/// (the copy's expiration date); Keyper runs no timer of its own.
///
/// The test runner must not read the pasteboard (that raises a paste prompt), so the app reports
/// what it holds through a Debug-only element, `pasteboard_state`: whether it has strings and its
/// change count, never its contents. `-KeyperClipboardSeconds` shortens the lifetime in Debug
/// builds; copyPhrase passes it to the same setItems call as the real 60 seconds. Simulator only,
/// where the offline state is simulated.
@MainActor
final class ClipboardUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil, "the offline state is simulated")
        // A known state: nothing on the pasteboard. The runner may write it without a prompt.
        UIPasteboard.general.items = []
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        UIPasteboard.general.items = []
        try await super.tearDown()
    }

    private func launch(clipboardSeconds: Int?) {
        app.launchArguments = ["-KeyperAllowScreenshots", "-KeyperSimulateOffline", "-AppleLanguages", "(en)"]
        if let clipboardSeconds { app.launchArguments += ["-KeyperClipboardSeconds", String(clipboardSeconds)] }
        app.launch()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 10))
    }

    // MARK: The pasteboard, as the app sees it

    /// What the pasteboard holds. The change count is recorded but never compared: on iOS 26 it moves
    /// when a text field takes the focus, with nothing copied.
    private struct State: CustomStringConvertible {
        var hasStrings: Bool
        var changeCount: Int
        /// Keyper's copy, by the marker type it carries.
        var keyperCopy = false
        /// What the runner copied as another app (copyAsAnotherApp's marker).
        var otherApp = false
        var content: String { "strings=\(hasStrings) keyper=\(keyperCopy) other=\(otherApp)" }
        var description: String { content + " count=\(changeCount)" }
    }

    /// The runner copies text as another app would, with a marker type the app's probe can see.
    private func copyAsAnotherApp() {
        UIPasteboard.general.items = [[UTType.utf8PlainText.identifier: "copied in another app", "app.getkeyper.debug.other-app": Data([1])]]
    }

    private var state: State {
        let probe = app.descendants(matching: .any)["pasteboard_state"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "no pasteboard_state element (a Debug build is needed)")
        let value = probe.value as? String ?? ""
        let fields = Dictionary(uniqueKeysWithValues: value.split(separator: " ").compactMap { pair -> (String, String)? in
            let parts = pair.split(separator: "=", maxSplits: 1)
            return parts.count == 2 ? (String(parts[0]), String(parts[1])) : nil
        })
        guard let has = fields["hasStrings"], let count = fields["changeCount"].flatMap({ Int($0) }) else {
            XCTFail("unreadable pasteboard_state: \(value)")
            return State(hasStrings: false, changeCount: -1)
        }
        return State(hasStrings: has == "true", changeCount: count, keyperCopy: fields["keyperCopy"] == "true", otherApp: fields["otherApp"] == "true")
    }

    private func note(_ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "pasteboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Typing and generating

    /// Waits until Keyper's keyboard is open and has stopped moving.
    private func waitForKeyboard() {
        let key = app.keys["q"]
        XCTAssertTrue(key.waitForExistence(timeout: 5), "Keyper's keyboard opens")
        var frame = key.frame
        for _ in 0..<20 {
            usleep(150_000)
            if key.frame == frame { return }
            frame = key.frame
        }
        XCTFail("Keyper's keyboard keeps moving")
    }

    private func type(_ text: String) {
        for c in text {
            if c == " " {
                app.keys["space"].tap()
            } else if c.isLetter && c.isUppercase {
                app.keys["Shift"].tap()
                app.keys[String(c)].tap()
            } else if c.isLetter || ((c == "@" || c == ".") && app.keys["@"].exists && app.keys["123"].exists) {
                app.keys[String(c)].tap()
            } else {
                app.keys["123"].tap()
                app.keys[String(c)].tap()
                app.keys["ABC"].tap()
            }
        }
    }

    /// Types the inputs, generates (the real derivation) and waits for the phrase.
    private func generate() {
        app.textFields["email"].tap()
        waitForKeyboard()
        type("alice@example.com")
        app.keys["Next"].tap()
        type("In 2009 Grandma Li and I picked 7 green dates")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["words"].waitForExistence(timeout: 600), "the phrase appears")
        waitUntilStill(app.buttons["Copy"])
    }

    /// The page scrolls to the phrase as it appears: a tap before it stops lands elsewhere.
    private func waitUntilStill(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        var frame = element.frame
        for _ in 0..<20 {
            usleep(200_000)
            if element.frame == frame { return }
            frame = element.frame
        }
        XCTFail("\(element) keeps moving")
    }

    private var copyWarning: XCUIElement { app.descendants(matching: .any)["copy_warning"] }

    /// Taps Copy; on the first copy of a launch, the warning comes first and must not have written
    /// anything, and its "Copy" copies. Checks that the pasteboard then holds a string Keyper wrote,
    /// and returns the time of the copy.
    @discardableResult
    private func tapCopy(warning: Bool = true) -> Date {
        let before = state
        app.buttons["Copy"].tap()
        if warning {
            XCTAssertTrue(copyWarning.waitForExistence(timeout: 5), "no warning before the first copy")
            let shown = state
            XCTAssertEqual(shown.content, before.content, "the warning wrote the pasteboard")
            XCTAssertFalse(shown.keyperCopy, "the warning wrote the pasteboard")
            copyWarning.buttons["Copy"].tap()
            XCTAssertTrue(copyWarning.waitForNonExistence(timeout: 5))
        } else {
            XCTAssertFalse(copyWarning.exists, "warned again in the same session")
        }
        let copied = Date()
        let after = state
        XCTAssertTrue(after.hasStrings && after.keyperCopy, "Copy put nothing on the pasteboard")
        XCTAssertGreaterThan(after.changeCount, before.changeCount)
        return copied
    }

    private func wait(until deadline: Date) {
        let seconds = deadline.timeIntervalSinceNow
        if seconds > 0 { usleep(UInt32(seconds * 1_000_000)) }
    }

    /// Brings Keyper back to the foreground and waits for its screen.
    private func activate() {
        app.activate()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 10), "Keyper came back")
    }

    // MARK: Expiry, case by case

    private enum Away: String { case front, background, terminated, forceQuit }

    /// Copies with a short lifetime, then leaves Keyper `away` while the deadline passes. Checked twice
    /// through Keyper's eyes: before the deadline (the copy must still be there, so the check can see
    /// it at all) and after. With `otherAppCopies`, the runner, as another app, copies something
    /// itself right after Keyper's copy; that newer content must survive Keyper's deadline.
    private func expiry(_ away: Away, otherAppCopies: Bool, lifetime: Double = 30) {
        launch(clipboardSeconds: Int(lifetime))
        generate()
        let copied = tapCopy()
        var expected = state
        if otherAppCopies {
            copyAsAnotherApp()
            expected = state
            XCTAssertTrue(expected.otherApp, "the app cannot see the runner's copy")
        }

        // Change counts are only recorded: a relaunched Keyper saw a different one from the process
        // that copied (16 against 24, after a force-quit), and a field's focus moves it too.
        var runnerCounts = ["copy \(UIPasteboard.general.changeCount)"]
        func early() {
            let now = state
            runnerCounts.append("early \(UIPasteboard.general.changeCount)")
            XCTAssertLessThan(Date().timeIntervalSince(copied), lifetime - 2, "checked too late to see the copy before its deadline")
            XCTAssertEqual(now.content, expected.content, "the pasteboard changed before the deadline")
        }
        var stateAtDeadline = ""
        switch away {
        case .front:
            sleep(3)
            early()
            wait(until: copied.addingTimeInterval(lifetime + 5))
            XCTAssertEqual(app.state, .runningForeground)
        case .background:
            // Keyper's own scene phase is the evidence that it went to the background: leaving forgets
            // the phrase. (XCUIApplication.state is recorded too, but on the iOS 26 simulator it can
            // still read "foreground" seconds after Home.)
            XCUIDevice.shared.press(.home)
            sleep(3)
            stateAtDeadline = " (app state \(app.state.rawValue) 3 s after Home"
            activate()
            XCTAssertFalse(app.descendants(matching: .any)["words"].exists, "Keyper never went to the background (the phrase is still there)")
            early()
            XCUIDevice.shared.press(.home)
            wait(until: copied.addingTimeInterval(lifetime + 5))
            stateAtDeadline += ", \(app.state.rawValue) at the deadline; 4 = foreground)"
            XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.springboard").wait(for: .runningForeground, timeout: 1), "the home screen is not in front")
            activate()
        case .terminated:
            app.terminate()
            launch(clipboardSeconds: Int(lifetime))
            early()
            app.terminate()
            XCTAssertEqual(app.state, .notRunning)
            wait(until: copied.addingTimeInterval(lifetime + 5))
            launch(clipboardSeconds: Int(lifetime))
        case .forceQuit:
            forceQuitFromTheAppSwitcher()
            launch(clipboardSeconds: Int(lifetime))
            early()
            forceQuitFromTheAppSwitcher()
            wait(until: copied.addingTimeInterval(lifetime + 5))
            launch(clipboardSeconds: Int(lifetime))
        }
        let late = state
        runnerCounts.append("late \(UIPasteboard.general.changeCount)")
        note("\(away.rawValue)\(otherAppCopies ? " + another app's copy" : ""): \(expected) before the deadline\(stateAtDeadline), \(late) \(Int(Date().timeIntervalSince(copied))) s after the copy; runner's change count: \(runnerCounts.joined(separator: ", "))")
        if otherAppCopies {
            XCTAssertTrue(late.hasStrings && late.otherApp, "another app's newer content did not survive Keyper's deadline")
            XCTAssertFalse(late.keyperCopy)
        } else {
            XCTAssertFalse(late.hasStrings, "the copy outlived its lifetime (\(away.rawValue))")
            XCTAssertFalse(late.keyperCopy, "the copy outlived its lifetime (\(away.rawValue))")
        }
    }

    /// As a user force-quits: the app switcher (a slow swipe up from the bottom edge, held), then the
    /// app's card flung upwards. Checked by the app's state afterwards.
    private func forceQuitFromTheAppSwitcher() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.999))
        let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        bottom.press(forDuration: 0.05, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 1.0)
        sleep(1)
        let card = springboard.descendants(matching: .any).matching(identifier: "Keyper").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the app switcher did not show Keyper's card")
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -600)), withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Keyper is still running after its card was swiped away")
        XCUIDevice.shared.press(.home)
    }

    // (a) In front.
    func testCopyExpiresWithKeyperInFront() { expiry(.front, otherAppCopies: false) }
    func testAnotherAppsNewerCopySurvivesWithKeyperInFront() { expiry(.front, otherAppCopies: true) }

    // (b) In the background, suspended while the deadline passes.
    func testCopyExpiresWithKeyperInTheBackground() { expiry(.background, otherAppCopies: false) }
    func testAnotherAppsNewerCopySurvivesWithKeyperInTheBackground() { expiry(.background, otherAppCopies: true) }

    // (c) Terminated (app.terminate(), as the system would end it), no process while the deadline passes.
    func testCopyExpiresAfterKeyperIsTerminated() { expiry(.terminated, otherAppCopies: false) }
    func testAnotherAppsNewerCopySurvivesAfterKeyperIsTerminated() { expiry(.terminated, otherAppCopies: true) }

    // (d) Force-quit by the user from the app switcher.
    func testCopyExpiresAfterKeyperIsForceQuit() { expiry(.forceQuit, otherAppCopies: false) }
    func testAnotherAppsNewerCopySurvivesAfterKeyperIsForceQuit() { expiry(.forceQuit, otherAppCopies: true) }

    /// The real constant, in the background: there at 50 seconds, gone at 70.
    func testRealSixtySecondCopyExpiresInTheBackground() {
        launch(clipboardSeconds: nil)
        generate()
        let copied = tapCopy()
        XCUIDevice.shared.press(.home)
        wait(until: copied.addingTimeInterval(50))
        activate()
        let early = state
        let earlyAt = Date().timeIntervalSince(copied)
        XCTAssertLessThan(earlyAt, 58, "came back too late to check the copy before its minute was up")
        XCTAssertTrue(early.hasStrings, "the copy was gone after \(Int(earlyAt)) s, before its minute was up")
        XCUIDevice.shared.press(.home)
        wait(until: copied.addingTimeInterval(70))
        activate()
        let late = state
        note("real 60 s: \(early) at \(Int(earlyAt)) s → \(late) at \(Int(Date().timeIntervalSince(copied))) s")
        XCTAssertFalse(late.hasStrings, "the copy outlived its 60 seconds while Keyper was in the background")
    }

    // MARK: The warning before the first copy

    /// The first Copy of a launch warns; "Show QR code" shows the QR screen and writes nothing (and
    /// the next Copy warns again); the warning's "Copy" copies; later taps copy at once; a new launch
    /// warns again.
    func testCopyWarnsOnTheFirstCopyOfALaunchOnly() {
        launch(clipboardSeconds: nil)
        generate()
        let before = state
        XCTAssertFalse(before.hasStrings)
        app.buttons["Copy"].tap()
        XCTAssertTrue(copyWarning.waitForExistence(timeout: 5), "no warning before the first copy")
        XCTAssertTrue(copyWarning.staticTexts["Copy to the clipboard?"].exists)
        XCTAssertTrue(copyWarning.staticTexts["Keyboards and clipboard history may keep their own copy, which Keyper cannot erase. The QR code avoids the clipboard."].exists)
        XCTAssertEqual(state.content, before.content, "the warning wrote the pasteboard")
        copyWarning.buttons["Show QR code"].tap()
        let qr = app.descendants(matching: .any)["qr_screen"]
        XCTAssertTrue(qr.waitForExistence(timeout: 5), "Show QR code did not show the QR code")
        XCTAssertEqual(state.content, before.content, "choosing the QR code wrote the pasteboard")
        XCTAssertFalse(state.keyperCopy)
        qr.tap()
        XCTAssertTrue(qr.waitForNonExistence(timeout: 5))

        tapCopy(warning: true) // nothing copied yet: the warning again, then the copy
        UIPasteboard.general.items = [] // as if it had expired, so tapCopy starts from empty again
        tapCopy(warning: false)
        tapCopy(warning: false)

        app.terminate()
        UIPasteboard.general.items = []
        launch(clipboardSeconds: nil)
        generate()
        app.buttons["Copy"].tap()
        XCTAssertTrue(copyWarning.waitForExistence(timeout: 5), "a new launch did not warn again")
        copyWarning.buttons["Show QR code"].tap()
    }

    /// The QR code is the primary action, above Copy.
    func testQrCodeIsThePrimaryAction() {
        launch(clipboardSeconds: nil)
        generate()
        let qr = app.buttons["QR code"], copy = app.buttons["Copy"]
        XCTAssertTrue(qr.exists && copy.exists)
        XCTAssertLessThan(qr.frame.maxY, copy.frame.minY + 1, "the QR code is not above Copy")
        XCTAssertGreaterThan(qr.frame.width, copy.frame.width, "the QR code is not the wide primary button")
    }

    // MARK: Going online and discarding

    /// Controls for the next test: going online, and discarding the phrase, do clear Keyper's own copy.
    /// This caught a bug: tapping a field moved the change count Keyper compared before clearing.
    func testGoingOnlineAndDiscardingClearKeypersOwnCopy() {
        launch(clipboardSeconds: nil)
        generate()
        tapCopy()
        app.textFields["email"].tap() // editing the email discards the phrase, and its copy
        waitForKeyboard()
        type("x")
        XCTAssertFalse(app.descendants(matching: .any)["words"].exists)
        let discarded = state
        XCTAssertFalse(discarded.hasStrings || discarded.keyperCopy, "discarding the phrase left its copy")

        app.keys["Delete"].tap()
        XCTAssertEqual(app.textFields["email"].value as? String, "alice@example.com")
        app.keys["Next"].tap()
        app.keys["Done"].tap() // the sentence is still there: discarding keeps the inputs
        app.buttons["generate"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["words"].waitForExistence(timeout: 600), "the phrase appears again")
        waitUntilStill(app.buttons["Copy"])
        tapCopy(warning: false)
        simulateWifi(on: true)
        XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForExistence(timeout: 5), "Keyper saw the network come back")
        let online = state
        XCTAssertFalse(online.hasStrings || online.keyperCopy, "going online left Keyper's copy")
    }

    /// "Clear all" abandons everything: both inputs, the phrase, and Keyper's copy on the pasteboard.
    func testClearAllWipesTheInputsThePhraseAndKeypersCopy() {
        launch(clipboardSeconds: nil)
        generate()
        tapCopy()
        let clear = app.buttons["clear"]
        XCTAssertEqual(clear.label, "Clear all")
        clear.tap()
        XCTAssertTrue(app.descendants(matching: .any)["words"].waitForNonExistence(timeout: 5), "Clear all left the phrase")
        let email = app.textFields["email"]
        XCTAssertTrue([nil, "", email.placeholderValue].contains(email.value as? String), "Clear all left the email: \(String(describing: email.value))")
        XCTAssertFalse(app.staticTexts["strength"].exists, "Clear all left the sentence")
        XCTAssertFalse(app.buttons["First time? Do a recovery drill  ›"].exists)
        let after = state
        XCTAssertFalse(after.hasStrings || after.keyperCopy, "Clear all left Keyper's copy")
        XCTAssertFalse(app.debugDescription.contains("alice@example.com"), "the email is still in the accessibility tree")
    }

    /// Whatever is copied after Keyper's copy is someone else's: neither discarding the phrase nor
    /// going online may clear it.
    func testDiscardingOrGoingOnlineLeavesAnotherAppsNewerCopy() {
        launch(clipboardSeconds: nil)
        generate()
        tapCopy()
        copyAsAnotherApp() // the runner is another app
        let theirs = state
        XCTAssertTrue(theirs.hasStrings && theirs.otherApp && !theirs.keyperCopy)

        app.textFields["email"].tap() // discards the phrase
        waitForKeyboard()
        type("x")
        XCTAssertFalse(app.descendants(matching: .any)["words"].exists)
        XCTAssertEqual(state.content, theirs.content, "discarding the phrase cleared another app's content")

        simulateWifi(on: true)
        XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForExistence(timeout: 5), "Keyper saw the network come back")
        XCTAssertEqual(state.content, theirs.content, "going online cleared another app's content")
    }


    /// Debug builds with -KeyperSimulateOffline listen for these (OfflineMonitor).
    private func simulateWifi(on: Bool) {
        let name = on ? "app.getkeyper.debug.wifi-on" : "app.getkeyper.debug.wifi-off"
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}
