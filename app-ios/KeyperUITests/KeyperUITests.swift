import XCTest

/// Drives the app through its own keyboard, as a user would. On the simulator the offline gate is
/// simulated; screenshots need the screen shield off. Both switches exist only in Debug builds.
@MainActor
final class KeyperUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        let simulateOffline = isSimulator || ProcessInfo.processInfo.environment["KEYPER_SIMULATE_OFFLINE"] != nil
        app.launchArguments = ["-KeyperAllowScreenshots"] + (simulateOffline ? ["-KeyperSimulateOffline"] : [])
        app.launchArguments += ["-AppleLanguages", "(en)"]
        app.launch()
    }

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
        XCTAssertTrue(words.label.contains("patch"), words.label)
        let expected = "patch essay tiny fix genre guilt tenant expose ceiling pear group surface".split(separator: " ")
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

    /// After a phrase: the QR code, the recovery drill (wrong, then right), switching language in
    /// place, and leaving the app, which forgets everything.
    func testQrDrillLanguageAndLeaving() {
        typeInputs("alice@example.com", "In 2009 Grandma Li and I picked 7 green dates")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        let words = app.descendants(matching: .any)["words"]
        XCTAssertTrue(words.waitForExistence(timeout: 600))

        app.buttons["QR code"].tap()
        let qr = app.descendants(matching: .any)["qr_screen"]
        XCTAssertTrue(qr.waitForExistence(timeout: 5))
        shot("qr")
        qr.tap()
        XCTAssertTrue(qr.waitForNonExistence(timeout: 5))

        app.buttons["First time? Do a recovery drill  ›"].tap()
        XCTAssertFalse(words.exists, "the phrase hides during the drill")
        waitForKeyboard() // the drill opens it on the email
        type("alice@example.com")
        app.keys["Next"].tap()
        type("In 2009 Grandma Li and I picked 7 green date")
        // Shown, so that a mistyped key fails here, by name, rather than as a drill that never matches.
        app.buttons["reveal"].tap()
        let secret = app.textViews["secret"]
        XCTAssertEqual(secret.value as? String, "In 2009 Grandma Li and I picked 7 green date")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        XCTAssertTrue(app.staticTexts["Not the same as before"].waitForExistence(timeout: 5))
        // A tap puts the native cursor where it lands: tap after the end of the text to append.
        secret.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.9)).tap()
        waitForKeyboard()
        type("s")
        XCTAssertEqual(secret.value as? String, "In 2009 Grandma Li and I picked 7 green dates")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        XCTAssertTrue(words.waitForExistence(timeout: 5), "a matching drill shows the phrase again, without a second derivation")
        XCTAssertTrue(app.staticTexts["They match: this phrase can be recovered"].exists)
        shot("drill_passed")

        app.buttons["language"].tap()
        XCTAssertTrue(app.staticTexts["\u{8F83}\u{5F3A} · 45 \u{4E2A}\u{5B57}\u{7B26}"].waitForExistence(timeout: 5), "Chinese, in place")
        XCTAssertTrue(words.exists, "switching language keeps the phrase")
        XCTAssertEqual(app.textFields["email"].value as? String, "alice@example.com")
        shot("chinese")
        app.buttons["language"].tap()

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["generate"].waitForExistence(timeout: 5))
        XCTAssertFalse(words.exists, "leaving the app forgets the phrase")
        XCTAssertEqual(app.staticTexts["strength"].exists, false, "and the secret")
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
        typeInputs("a@b.c", "short one")
        XCTAssertEqual(app.staticTexts["strength"].label, "9 characters; at least 12 needed")
        app.keys["Done"].tap()
        app.buttons["generate"].tap()
        XCTAssertTrue(app.staticTexts["At least 6 English letters or digits"].waitForExistence(timeout: 5))
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
