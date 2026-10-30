import Testing
import Foundation
import KeyperCore
import UIKit
@testable import Keyper

/// Test doubles for KeyperModel: radios the test switches, a derivation the test finishes, and a
/// pasteboard wrapper that records the options of each copy while writing to the real pasteboard.

/// The radios a fake OfflineMonitor reports.
@MainActor
final class FakeRadios {
    var now = OfflineMonitor.Radios()
    static let online = OfflineMonitor.Radios(wifi: true)
}

/// A derivation that never computes: the test finishes it, at once or later.
final class FakeDerivation: KeyDerivation, @unchecked Sendable {
    private(set) var email: String?
    private(set) var secret: String?
    private(set) var cancelled = false
    private var completion: (@Sendable (Result<[UInt8], Error>) -> Void)?

    func start(
        email: String,
        secret: String,
        domain: [UInt8],
        progress: @escaping @Sendable (Int, Int, TimeInterval) -> Void,
        completion: @escaping @Sendable (Result<[UInt8], Error>) -> Void
    ) {
        self.email = email
        self.secret = secret
        self.completion = completion
    }

    func cancel() { cancelled = true }

    /// Delivers the key as the real derivation does: on the main queue (the test is already on it).
    @MainActor
    func finish(_ key: [UInt8] = FakeDerivation.key) { completion?(.success(key)) }

    static let key = [UInt8](repeating: 0x42, count: 32)
}

/// Every derivation the model has started, in order.
@MainActor
final class Derivations {
    private(set) var runs = [FakeDerivation]()
    func make() -> any KeyDerivation {
        let run = FakeDerivation()
        runs.append(run)
        return run
    }
}

/// UIPasteboard.general, with the options of each setItems call recorded.
@MainActor
final class RecordingPasteboard: PhrasePasteboard {
    private(set) var copies = [[UIPasteboard.OptionsKey: Any]]()
    /// The items of each setItems call (the test runs inside the app, so it may look).
    private(set) var copiedItems = [[[String: Any]]]()
    var items: [[String: Any]] {
        get { UIPasteboard.general.items }
        set { UIPasteboard.general.items = newValue }
    }

    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
        copies.append(options)
        copiedItems.append(items)
        UIPasteboard.general.setItems(items, options: options)
    }

    func contains(pasteboardTypes: [String]) -> Bool { UIPasteboard.general.contains(pasteboardTypes: pasteboardTypes) }
}

/// A KeyperModel wired as the app wires it (its two fields included), with fakes for the radios
/// and the derivation.
@MainActor
final class Harness {
    static let email = "alice@example.com"
    static let sentence = "In 2009 Grandma Li and I picked 7 green dates"

    let radios = FakeRadios()
    let monitor: OfflineMonitor
    let derivations = Derivations()
    let pasteboard = RecordingPasteboard()
    let model: KeyperModel
    let emailField = KeyperTextField()
    let secretView = KeyperTextView()
    let drillEmailField = KeyperTextField()
    let drillSecretView = KeyperTextView()

    init(offline: Bool = true, clipboardLifetime: TimeInterval = KeyperModel.clipboardSeconds) {
        let radios = radios
        if !offline { radios.now = FakeRadios.online }
        monitor = OfflineMonitor(probe: { radios.now })
        let derivations = derivations
        model = KeyperModel(monitor: monitor, derivation: { derivations.make() }, pasteboard: pasteboard, clipboardLifetime: clipboardLifetime)
        // As EmailField and SecretField do.
        let model = model
        emailField.onChange = { model.email = $0 }
        secretView.onChange = { model.secret = $0 }
        drillEmailField.onChange = { model.drillEmail = $0 }
        drillSecretView.onChange = { model.drillSecret = $0 }
        model.emailTarget = emailField
        model.secretTarget = secretView
        model.drillEmailTarget = drillEmailField
        model.drillSecretTarget = drillSecretView
    }

    func goOnline() {
        radios.now = FakeRadios.online
        monitor.check()
    }

    func goOffline() {
        radios.now = OfflineMonitor.Radios()
        monitor.check()
    }

    /// Types on Keyper's keyboard into a field, as KeyboardBar does.
    func type(_ text: String, into field: KeyperModel.Field) {
        model.focus(field)
        for c in text { model.type(c) }
    }

    /// The phrase on screen after one (fake) derivation of the standard inputs.
    @discardableResult
    func generated() -> [String] {
        model.email = Self.email
        model.secret = Self.sentence
        model.generate()
        derivations.runs.last!.finish()
        return model.phrase!
    }

    /// The phrase the fake key gives.
    static var phrase: [String] { Keyper.mnemonic(key: FakeDerivation.key, words: 12) }
}

/// Only the simulator can read the Mac's files (the repository's sources and fixtures); on a phone
/// the tests that need them are skipped.
let canReadTheMacsFiles = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil

/// The app's sources, for checks on what the code may call (the simulator reads the Mac's files).
let appSources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Keyper")

/// The share of pixels that differ visibly from the first one: 0 for a picture of one colour.
func variedShare(_ image: UIImage) -> Double {
    guard let cg = image.cgImage else { return 0 }
    let width = cg.width, height = cg.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    var differ = 0
    for i in stride(from: 0, to: pixels.count, by: 4) {
        let red: Int = abs(Int(pixels[i]) - Int(pixels[0]))
        let green: Int = abs(Int(pixels[i + 1]) - Int(pixels[1]))
        let blue: Int = abs(Int(pixels[i + 2]) - Int(pixels[2]))
        if red + green + blue > 24 { differ += 1 }
    }
    return Double(differ) / Double(width * height)
}

/// The host app's foreground window scene (unit tests run inside the app).
@MainActor
var hostScene: UIWindowScene {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
}

/// Lets the run loop draw, run timers and deliver main-queue blocks.
@MainActor
func spin(_ seconds: Double) async throws {
    try await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
}

/// The website's six claims, one nested suite each. Serialized: several share the pasteboard, the
/// key window or the first responder, which suites running side by side would disturb.
@Suite(.serialized) struct KeyperClaims {}
