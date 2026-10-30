import XCTest

/// Drives the app through its own keyboard, as a user would. On the simulator the offline gate is
/// simulated; screenshots need the screen shield off. Both switches exist only in Debug builds.
@MainActor
final class KeyperUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        simulateOffline = isSimulator || ProcessInfo.processInfo.environment["KEYPER_SIMULATE_OFFLINE"] != nil
        app.launchArguments = ["-KeyperAllowScreenshots"] + (simulateOffline ? ["-KeyperSimulateOffline"] : [])
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()
    }

    /// The app was launched with the offline state simulated, so the test can also go online.
    private var simulateOffline = false

    private var isSimulator: Bool { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits until Keyper's keyboard is open and has stopped moving: a key tapped while it still slides
    /// in, or while the page scrolls the field above it, lands on the row below.
    private func waitForKeyboard(file: StaticString = #filePath, line: UInt = #line) {
        let key = app.keys["q"]
        XCTAssertTrue(key.waitForExistence(timeout: 5), "Keyper's keyboard opens", file: file, line: line)
        var frame = key.frame
        for _ in 0..<20 {
            usleep(150_000)
            if key.frame == frame { return }
            frame = key.frame
        }
        XCTFail("Keyper's keyboard keeps moving", file: file, line: line)
    }

    /// Types text key by key on Keyper's keyboard, switching layers and shift as needed.
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

    func testTypeGenerateAndMatchTheReference() {
        let email = app.textFields["email"]
        email.tap()
        waitForKeyboard()
        type("alice@example.com")
        XCTAssertEqual(email.value as? String, "alice@example.com")
        app.keys["Next"].tap()
        type("In 2009 Grandma Li and I picked 7 green dates")
        app.buttons["reveal"].tap()
        let secret = app.textViews["secret"]
        XCTAssertEqual(secret.value as? String, "In 2009 Grandma Li and I picked 7 green dates")
        XCTAssertEqual(app.staticTexts["strength"].label, "Good · 45 characters")
        shot("typed")
        let start = Date()
        app.buttons["generate"].tap()
        let words = app.descendants(matching: .any)["words"]
        XCTAssertTrue(words.waitForExistence(timeout: 600), "the phrase appears")
        let seconds = Date().timeIntervalSince(start)
        let timing = XCTAttachment(string: String(format: "derivation %.1f s", seconds))
        timing.name = "timing"
        timing.lifetime = .keepAlways
        add(timing)
        shot("result")
        // The same phrase as the Android app and reference/keyper.py with this domain constant.
        XCTAssertTrue(words.label.contains("image"), words.label)
        let expected = "image ripple naive snake outside leave crunch quality patrol smile goose climb".split(separator: " ")
        let label = words.label
        for (i, word) in expected.enumerated() {
            XCTAssertTrue(label.contains(String(format: "%02d", i + 1) + "\u{00A0}\u{00A0}" + word), "word \(i + 1): \(word) in \(label)")
        }
    }

    /// On a phone, screenshots must not show the screen: the shield leaves it out of every capture.
    func testScreenShieldHidesTheScreen() throws {
        try XCTSkipIf(isSimulator, "the simulator's screenshots ignore the shield")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 5))
        // No system alert may sit over the screen: its dimming would hide the logo by itself.
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists, "a system alert is showing")
        let screenshot = XCUIScreen.main.screenshot()
        shot("shielded")
        let image = screenshot.image.cgImage!
        let scale = CGFloat(image.width) / screenshot.image.size.width
        let logo = CGRect(x: 20 * scale, y: 60 * scale, width: 60 * scale, height: 120 * scale)
        XCTAssertFalse(containsGold(image, in: logo), "the logo shows in a screenshot")
        // Below the status bar the picture is the page colour and nothing else.
        let page = CGRect(x: 0, y: 70 * scale, width: CGFloat(image.width), height: CGFloat(image.height) - 120 * scale)
        XCTAssertLessThan(varied(image, in: page), 0.01, "the screen shows in a screenshot")
    }

    /// The share of pixels in `rect` that differ from its first pixel.
    private func varied(_ image: CGImage, in rect: CGRect) -> Double {
        let (pixels, _, _) = rgba(image, in: rect)
        var differ = 0
        // One typed term per channel: as a single expression it is too much for the type checker on CI.
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let red: Int = abs(Int(pixels[i]) - Int(pixels[0]))
            let green: Int = abs(Int(pixels[i + 1]) - Int(pixels[1]))
            let blue: Int = abs(Int(pixels[i + 2]) - Int(pixels[2]))
            if red + green + blue > 24 { differ += 1 }
        }
        return Double(differ) / Double(pixels.count / 4)
    }

    private func rgba(_ image: CGImage, in rect: CGRect) -> ([UInt8], Int, Int) {
        guard let crop = image.cropping(to: rect) else { return ([], 0, 0) }
        let width = crop.width, height = crop.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height)
    }

    private func containsGold(_ image: CGImage, in rect: CGRect) -> Bool {
        let (pixels, _, _) = rgba(image, in: rect)
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i] > 230 && pixels[i + 1] > 140 && pixels[i + 1] < 215 && pixels[i + 2] < 90 {
            return true
        }
        return false
    }

    private func typeInputs(_ email: String, _ secret: String) {
        app.textFields["email"].tap()
        waitForKeyboard()
        type(email)
        app.keys["Next"].tap()
        type(secret)
    }

    /// Types the standard inputs, generates (the real derivation) and waits for the phrase to stop
    /// moving; returns the phrase's label.
    @discardableResult
    private func generatePhrase() -> String {
        typeInputs("alice@example.com", "In 2009 Grandma Li and I picked 7 green dates")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        let words = app.descendants(matching: .any)["words"]
        XCTAssertTrue(words.waitForExistence(timeout: 600), "the phrase appears")
        waitUntilStill(app.buttons["First time? Do a recovery drill  ›"])
        return words.label
    }

    /// The page scrolls to the phrase as it appears, and the drill page slides: a tap before either
    /// stops lands elsewhere.
    private func waitUntilStill(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) appears", file: file, line: line)
        var frame = element.frame
        for _ in 0..<20 {
            usleep(200_000)
            if element.frame == frame { return }
            frame = element.frame
        }
        XCTFail("\(element) keeps moving", file: file, line: line)
    }

    private var drillTitle: XCUIElement { app.staticTexts["drill_title"] }

    /// The whole accessibility tree, labels and values (hidden elements are not in it), holds none
    /// of the phrase, the sentence or what the drill page took: nothing to reach by navigation.
    private func assertNothingSensitiveInTheTree(_ when: String, file: StaticString = #filePath, line: UInt = #line) {
        let tree = app.debugDescription
        XCTAssertFalse(app.descendants(matching: .any)["words"].exists, "\(when): the phrase", file: file, line: line)
        for needle in ["ripple", "naive", "crunch", "patrol", "goose", "Grandma", "In 2009", "characters, hidden", "\u{4E2A}\u{5B57}\u{7B26}\u{FF0C}\u{5DF2}\u{9690}\u{85CF}", "drill_"] {
            XCTAssertFalse(tree.contains(needle), "\(when): the accessibility tree holds \(needle)", file: file, line: line)
        }
    }

    /// Opens the drill from the phrase and checks that it is a page of its own: its title bar, its
    /// one line, two empty fields and Check; none of the first entry's page.
    private func openDrill(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["First time? Do a recovery drill  ›"].tap()
        XCTAssertTrue(drillTitle.waitForExistence(timeout: 5), "the drill page opens", file: file, line: line)
        waitUntilStill(app.buttons["drill_back"], file: file, line: line)
        XCTAssertEqual(drillTitle.label, "Recovery drill", file: file, line: line)
        XCTAssertEqual(app.buttons["drill_back"].label, "Back", file: file, line: line)
        XCTAssertTrue(app.staticTexts["Type both again from memory."].exists, file: file, line: line)
        XCTAssertTrue(app.buttons["drill_check"].exists && app.buttons["drill_check"].label == "Check", file: file, line: line)
        // Not the first entry's page: no phrase, no strength meter, no 12 / 24 switch, no language
        // pill, no Generate, none of its fields.
        XCTAssertFalse(app.descendants(matching: .any)["words"].exists, "the phrase shows on the drill page", file: file, line: line)
        XCTAssertFalse(app.staticTexts["strength"].exists, "a strength meter on the drill page", file: file, line: line)
        XCTAssertFalse(app.staticTexts["crack_time"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["12 words"].exists || app.buttons["24 words"].exists, "a word-count switch on the drill page", file: file, line: line)
        XCTAssertFalse(app.buttons["language"].exists, "a language switch on the drill page", file: file, line: line)
        XCTAssertFalse(app.buttons["generate"].exists, file: file, line: line)
        XCTAssertFalse(app.textFields["email"].exists || app.textViews["secret"].exists, "the first entry's fields on the drill page", file: file, line: line)
        // Both fields start empty: an empty field reports its placeholder, or nothing.
        let email = app.textFields["drill_email"], secret = app.textViews["drill_secret"]
        XCTAssertTrue(email.exists && secret.exists, file: file, line: line)
        XCTAssertTrue([nil, "", email.placeholderValue].contains(email.value as? String), "the drill's email is prefilled: \(String(describing: email.value))", file: file, line: line)
        XCTAssertTrue([nil, ""].contains(secret.value as? String), "the drill's sentence is prefilled", file: file, line: line)
    }

    /// After a phrase: the QR code, the recovery drill on its own page (wrong, then right, then back
    /// to the same phrase), switching language in place, and leaving the app, which forgets everything.
    func testQrDrillLanguageAndLeaving() {
        let phrase = generatePhrase()
        let words = app.descendants(matching: .any)["words"]

        app.buttons["QR code"].tap()
        let qr = app.descendants(matching: .any)["qr_screen"]
        XCTAssertTrue(qr.waitForExistence(timeout: 5))
        shot("qr")
        qr.tap()
        XCTAssertTrue(qr.waitForNonExistence(timeout: 5))

        let computing = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Computing'")).firstMatch
        let mismatch = app.staticTexts["These don’t match what you entered first."]
        openDrill()
        shot("drill")
        waitForKeyboard() // the drill opens it on its email
        type("alice@example.com")
        app.keys["Next"].tap()
        type("In 2009 Grandma Li and I picked 7 green date")
        // Shown, so that a mistyped key fails here, by name, rather than as a drill that never matches.
        app.buttons["drill_reveal"].tap()
        XCTAssertEqual(app.buttons["drill_reveal"].label, "Hide")
        let secret = app.textViews["drill_secret"]
        XCTAssertEqual(secret.value as? String, "In 2009 Grandma Li and I picked 7 green date")
        XCTAssertEqual(app.textFields["drill_email"].value as? String, "alice@example.com")
        app.keys["Done"].tap()
        app.buttons["drill_check"].tap()
        XCTAssertTrue(mismatch.waitForExistence(timeout: 5), "a different input reports a mismatch")
        XCTAssertTrue(drillTitle.exists, "a mismatch stays on the drill page")
        XCTAssertFalse(words.exists, "a mismatch keeps the phrase hidden")
        XCTAssertFalse(computing.exists, "a mismatch starts no derivation")
        XCTAssertFalse(app.staticTexts["drill_passed"].exists)
        shot("drill_mismatch")
        // A tap puts the native cursor where it lands: tap after the end of the text to append.
        secret.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.9)).tap()
        waitForKeyboard()
        type("s")
        XCTAssertEqual(secret.value as? String, "In 2009 Grandma Li and I picked 7 green dates")
        XCTAssertFalse(mismatch.exists, "the mismatch line outlived the edit")
        app.keys["Done"].tap()
        app.buttons["drill_check"].tap()
        // A derivation takes far longer than 5 s on any device, and would show its progress first.
        let passed = app.staticTexts["drill_passed"]
        XCTAssertTrue(passed.waitForExistence(timeout: 5), "a match shows the passed state")
        XCTAssertEqual(passed.label, "Verification passed. Your inputs match.")
        XCTAssertFalse(computing.exists, "a matching drill started a second derivation")
        XCTAssertTrue(drillTitle.exists, "the passed state is on the drill page")
        XCTAssertFalse(words.exists, "the phrase shows before Back to the phrase")
        XCTAssertFalse(mismatch.exists)
        XCTAssertFalse(app.textFields["drill_email"].exists, "the fields stay under the passed state")
        shot("drill_passed")
        app.buttons["Back to the phrase"].tap()
        XCTAssertTrue(words.waitForExistence(timeout: 5), "Back to the phrase shows the phrase again")
        XCTAssertTrue(drillTitle.waitForNonExistence(timeout: 5), "the drill page closes")
        XCTAssertEqual(words.label, phrase, "not the same phrase")
        XCTAssertFalse(computing.exists, "a matching drill started a second derivation")
        XCTAssertEqual(app.textFields["email"].value as? String, "alice@example.com", "the first entry changed")
        XCTAssertEqual(app.staticTexts["strength"].label, "Good · 45 characters", "the first entry's sentence changed")

        app.buttons["language"].tap()
        XCTAssertTrue(app.staticTexts["\u{8F83}\u{5F3A} · 45 \u{4E2A}\u{5B57}\u{7B26}"].waitForExistence(timeout: 5), "Chinese, in place")
        XCTAssertTrue(words.exists, "switching language keeps the phrase")
        XCTAssertEqual(app.textFields["email"].value as? String, "alice@example.com")
        shot("chinese")
        // The drill page in Chinese, then leaving the app from it.
        app.buttons["\u{9996}\u{6B21}\u{4F7F}\u{7528}\u{FF1F}\u{505A}\u{4E00}\u{6B21}\u{6062}\u{590D}\u{6F14}\u{7EC3}  \u{203A}"].tap() // 首次使用？做一次恢复演练  ›
        XCTAssertTrue(drillTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(drillTitle.label, "\u{6062}\u{590D}\u{6F14}\u{7EC3}") // 恢复演练
        XCTAssertEqual(app.buttons["drill_back"].label, "\u{8FD4}\u{56DE}") // 返回
        XCTAssertTrue(app.staticTexts["\u{51ED}\u{8BB0}\u{5FC6}\u{518D}\u{8F93}\u{4E00}\u{904D}\u{3002}"].exists) // 凭记忆再输一遍。
        XCTAssertEqual(app.buttons["drill_check"].label, "\u{6838}\u{5BF9}") // 核对
        waitForKeyboard()
        type("alice")
        shot("drill_chinese")

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 5))
        XCTAssertFalse(drillTitle.exists, "leaving the app left the drill page open")
        XCTAssertFalse(words.exists, "leaving the app forgets the phrase")
        XCTAssertEqual(app.staticTexts["strength"].exists, false, "and the secret")
        assertNothingSensitiveInTheTree("after leaving from the drill page")
        app.buttons["language"].tap()
    }

    /// Back leaves the drill without a Check and shows the phrase as it was; the next drill starts
    /// empty again; going online on the drill page wipes it and leaves it, with the phrase.
    func testDrillBackAndGoingOnline() throws {
        try XCTSkipUnless(simulateOffline, "going online is simulated (simulator, or KEYPER_SIMULATE_OFFLINE)")
        let phrase = generatePhrase()
        let words = app.descendants(matching: .any)["words"]
        openDrill()
        waitForKeyboard()
        type("alice@example.com")
        app.buttons["drill_back"].tap()
        XCTAssertTrue(drillTitle.waitForNonExistence(timeout: 5), "Back closes the drill page")
        XCTAssertTrue(words.waitForExistence(timeout: 5))
        XCTAssertEqual(words.label, phrase)
        XCTAssertTrue(app.keys["q"].waitForNonExistence(timeout: 5), "the keyboard stayed open")

        waitUntilStill(app.buttons["First time? Do a recovery drill  ›"])
        openDrill() // checks that what was typed last time is gone
        waitForKeyboard()
        type("alice@example.com")
        app.keys["Next"].tap()
        type("In 2009")
        simulateWifi(on: true)
        XCTAssertTrue(drillTitle.waitForNonExistence(timeout: 5), "going online left the drill page open")
        XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForExistence(timeout: 5), "the first page, with the gate")
        XCTAssertFalse(words.exists, "going online kept the phrase")
        XCTAssertFalse(app.staticTexts["strength"].exists, "going online kept the sentence")
        XCTAssertFalse(app.buttons["First time? Do a recovery drill  ›"].exists)
        XCTAssertFalse(app.keys["q"].exists, "the keyboard stayed open")
        assertNothingSensitiveInTheTree("after going online on the drill page")
        simulateWifi(on: false)
        XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(words.exists || drillTitle.exists, "back offline, something came back")
        assertNothingSensitiveInTheTree("back offline")
    }

    /// Debug builds with -KeyperSimulateOffline listen for these (OfflineMonitor).
    private func simulateWifi(on: Bool) {
        let name = on ? "app.getkeyper.debug.wifi-on" : "app.getkeyper.debug.wifi-off"
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }

    func testWeakSentenceWarns() {
        typeInputs("alice@example.com", "my cat is called mimi")
        XCTAssertEqual(app.staticTexts["strength"].label, "Very weak · 21 characters")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        // Drawn inside the screen shield, so not one of the app's alerts.
        let dialog = app.descendants(matching: .any)["weak_dialog"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        XCTAssertTrue(dialog.staticTexts["Easy to crack"].exists)
        shot("weak")
        dialog.buttons["Edit"].tap()
        XCTAssertTrue(dialog.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["words"].exists)
    }

    func testTooShortInputsAreRefused() {
        typeInputs("alice@example", "short one")
        XCTAssertEqual(app.staticTexts["strength"].label, "9 characters; at least 12 needed")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        XCTAssertTrue(app.staticTexts["Not a valid email address"].waitForExistence(timeout: 5), "one label is not a domain")
        XCTAssertTrue(app.staticTexts["Must be a valid address. Capitals don’t matter; every other character does."].exists)
    }

    /// Online, the gate explains what to switch off and the secret cannot be typed.
    func testOfflineGateBlocksTheSecretWhileOnline() throws {
        try XCTSkipUnless(isSimulator, "a phone may well be offline")
        app.terminate()
        app.launchArguments = ["-KeyperAllowScreenshots", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["generate"].isEnabled)
        app.textViews["secret"].tap()
        XCTAssertFalse(app.keys["q"].waitForExistence(timeout: 2), "no keyboard for the secret while online")
        shot("online")
        // The email can be typed online; "Next" then closes the keyboard instead of moving to the secret.
        app.textFields["email"].tap()
        waitForKeyboard()
        type("ab")
        app.keys["Next"].tap()
        XCTAssertTrue(app.keys["q"].waitForNonExistence(timeout: 3), "Next opened the secret while online")
        XCTAssertFalse(app.staticTexts["strength"].exists, "the secret took keys while online")
    }

    /// The shielded screen must survive the app going to the background and coming back.
    func testShieldedScreenSurvivesBackground() {
        app.terminate()
        app.launchArguments = ["-KeyperSimulateOffline", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 5))
        for _ in 0..<3 {
            XCUIDevice.shared.press(.home)
            sleep(2)
            app.activate()
            XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 10), "the app came back")
        }
        XCTAssertEqual(app.state, .runningForeground)
        // Touches reach the screen through the shield, and Keyper's keyboard opens and types.
        app.textFields["email"].tap()
        waitForKeyboard()
        type("abc")
        XCTAssertEqual(app.textFields["email"].value as? String, "abc")
    }

    /// Claim 1 end to end: focusing either field opens Keyper's keyboard and never a system one. The
    /// control, an ordinary search field in Settings, shows that this check does see the system
    /// keyboard when one comes up (it cannot if the simulator has a hardware keyboard attached).
    func testSystemKeyboardNeverAppears() {
        app.textFields["email"].tap()
        waitForKeyboard()
        XCTAssertEqual(app.keyboards.count, 0, "a system keyboard came up for the email")
        app.keys["Next"].tap()
        waitForKeyboard()
        XCTAssertTrue(app.keys["Done"].exists, "the sentence has the focus")
        XCTAssertEqual(app.keyboards.count, 0, "a system keyboard came up for the sentence")
        app.textFields["email"].tap()
        waitForKeyboard()
        sleep(1)
        XCTAssertEqual(app.keyboards.count, 0, "a system keyboard came up for the email")

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let search = settings.searchFields.firstMatch
        if !search.waitForExistence(timeout: 5) { settings.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5), "control: no search field in Settings")
        search.tap()
        XCTAssertTrue(settings.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "control: no system keyboard for an ordinary field, so this test cannot see one (is a hardware keyboard attached?)")
        settings.terminate()
    }

    /// Keys from a hardware keyboard reach the field through UIKit, whose changes the field refuses.
    /// typeText sends key events to the focused field; the control at the end shows the same call
    /// typing into an ordinary field.
    func testHardwareKeysTypeNothing() throws {
        // On a phone XCTest only types into a field that holds keyboard focus, which Keyper's sentence
        // field never gives the system keyboard, so typeText cannot even be attempted there.
        try XCTSkipUnless(isSimulator, "XCTest cannot deliver hardware keys to a field without system keyboard focus on a phone")
        let email = app.textFields["email"]
        email.tap()
        waitForKeyboard()
        type("ab")
        email.typeText("xyz")
        XCTAssertEqual(email.value as? String, "ab", "a hardware keyboard typed into the email")
        app.keys["Next"].tap()
        waitForKeyboard()
        app.textViews["secret"].typeText("xyz")
        XCTAssertNil(app.staticTexts["strength"].exists ? app.staticTexts["strength"].label : nil, "a hardware keyboard typed into the sentence")

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let search = settings.searchFields.firstMatch
        if !search.waitForExistence(timeout: 5) { settings.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5), "control: no search field in Settings")
        search.tap()
        search.typeText("xyz")
        XCTAssertEqual(search.value as? String, "xyz", "control: typeText typed nothing into an ordinary field, so this test proves nothing")
        settings.terminate()
    }

    /// App Store screenshots, by hand only: KEYPER_STORE_SHOTS=offline takes the sentence typed and
    /// the phrase, =online the offline gate, each in English and Chinese, as attachments named
    /// store-<language>-<number>-<screen> for xcresulttool to export.
    func testStoreScreenshots() throws {
        guard let part = ProcessInfo.processInfo.environment["KEYPER_STORE_SHOTS"] else { throw XCTSkip("set KEYPER_STORE_SHOTS to offline or online") }
        try XCTSkipUnless(isSimulator, "the offline state is simulated")
        func store(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let language = app.buttons["language"]
        if part == "online" {
            app.terminate()
            app.launchArguments = ["-KeyperAllowScreenshots", "-AppleLanguages", "(en)"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["offline_card"].waitForExistence(timeout: 5))
            store("store-en-03-offline-gate")
            language.tap()
            XCTAssertTrue(app.staticTexts["\u{8BF7}\u{5148}\u{65AD}\u{7F51}"].waitForExistence(timeout: 5)) // 请先断网
            store("store-zh-03-offline-gate")
            return
        }
        typeInputs("alice@example.com", "In 2009 Grandma Li and I picked 7 green dates")
        app.keys["Done"].tap()
        app.buttons["reveal"].tap()
        XCTAssertTrue(app.keys["q"].waitForNonExistence(timeout: 5))
        store("store-en-01-input")
        language.tap()
        XCTAssertTrue(app.staticTexts["\u{8F83}\u{5F3A} · 45 \u{4E2A}\u{5B57}\u{7B26}"].waitForExistence(timeout: 5))
        store("store-zh-01-input")
        language.tap()
        app.buttons["generate"].tap()
        let words = app.descendants(matching: .any)["words"]
        XCTAssertTrue(words.waitForExistence(timeout: 600))
        // The page's end in both languages: the phrase whole, with its buttons.
        app.swipeUp()
        sleep(3) // the scroll indicator fades
        store("store-en-02-phrase")
        language.tap()
        XCTAssertTrue(app.staticTexts["\u{52A9}\u{8BB0}\u{8BCD}"].waitForExistence(timeout: 5)) // 助记词
        app.swipeUp()
        sleep(3)
        store("store-zh-02-phrase")
    }

    /// The real gate on a phone, checked by hand: KEYPER_EXPECT=online or offline says what the
    /// phone's switches are, and the screen must agree.
    func testRealGateOnAPhone() throws {
        guard let expect = ProcessInfo.processInfo.environment["KEYPER_EXPECT"] else { throw XCTSkip("set KEYPER_EXPECT to online or offline") }
        app.terminate()
        app.launchArguments = ["-KeyperAllowScreenshots", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 5))
        let card = app.descendants(matching: .any)["offline_card"]
        if expect == "online" {
            XCTAssertTrue(card.waitForExistence(timeout: 3), "the gate shows")
            XCTAssertTrue(app.staticTexts["Turn off Wi-Fi"].exists)
            XCTAssertFalse(app.buttons["generate"].isEnabled)
        } else {
            sleep(1)
            XCTAssertFalse(card.exists, "the gate opens")
            XCTAssertTrue(app.buttons["generate"].isEnabled)
            app.textViews["secret"].tap()
            XCTAssertTrue(app.keys["q"].waitForExistence(timeout: 3), "the secret can be typed")
        }
        shot("gate_\(expect)")
    }
}
