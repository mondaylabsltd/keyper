import KeyperCore
import Observation
import UIKit
import UniformTypeIdentifiers

/// The pasteboard as the model uses it: UIPasteboard.general in the app; unit tests wrap it to see
/// the options a copy is made with.
@MainActor
protocol PhrasePasteboard: AnyObject {
    var items: [[String: Any]] { get set }
    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any])
    func contains(pasteboardTypes: [String]) -> Bool
}

extension UIPasteboard: PhrasePasteboard {}

/// A field the keyboard types into: it edits at its own cursor, then reports the new text.
@MainActor
protocol TextTarget: AnyObject {
    func keyperInsert(_ c: Character)
    func keyperDelete()
}

/// The screen's state and rules, the same as the Android app's MainActivity: what is typed, the
/// offline gate, the derivation, the phrase and the recovery drill, a page of its own with fields
/// of its own. Nothing is stored: leaving the app or going online forgets the secret, the phrase and
/// whatever the drill holds, and keeps only the email.
@MainActor
@Observable
final class KeyperModel {
    /// The main page's two fields, and the drill page's own two.
    enum Field: Hashable {
        case email, secret, drillEmail, drillSecret
        var isEmail: Bool { self == .email || self == .drillEmail }
    }
    enum ScrollTarget: Hashable { case top, field(Field), result }

    // MARK: Language

    var language = Language.preferred {
        didSet {
            strings = L10n(language)
            language.makePreferred()
        }
    }
    private(set) var strings = L10n(.preferred)

    // MARK: Offline gate

    private(set) var radios = OfflineMonitor.Radios(cellular: true)
    var offline: Bool { radios.offline }
    @ObservationIgnored private let monitor: OfflineMonitor

    // MARK: Inputs

    var email = "" {
        didSet {
            guard email != oldValue else { return }
            emailError = nil
            discardResult()
        }
    }
    var secret = "" {
        didSet {
            guard secret != oldValue else { return }
            secretError = nil
            discardResult()
        }
    }
    var revealed = false
    private(set) var emailError: String?
    private(set) var secretError: String?
    var words = 12

    /// The field the keyboard types into; nil while the keyboard is closed.
    var focus: Field?
    @ObservationIgnored weak var emailTarget: TextTarget?
    @ObservationIgnored weak var secretTarget: TextTarget?
    @ObservationIgnored weak var drillEmailTarget: TextTarget?
    @ObservationIgnored weak var drillSecretTarget: TextTarget?

    // MARK: Derivation and result

    private(set) var busy = false
    private(set) var progress = (done: 0, total: 1, elapsed: TimeInterval(0))
    /// Bumped to discard the result of a derivation that is still running.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var derivation: (any KeyDerivation)?
    @ObservationIgnored private let makeDerivation: () -> any KeyDerivation
    /// The key K derived from the current inputs; both phrase lengths are read from it.
    private var key: [UInt8]?
    /// `Keyper.drillFingerprint` of the inputs that produced `key`, keyed with it and wiped with it.
    @ObservationIgnored private var inputs: [UInt8]?

    // MARK: Recovery drill

    enum DrillResult { case mismatch, passed }
    /// True while the drill page is open; `key` is kept, but the phrase is on the other page.
    private(set) var drilling = false
    /// What the user types on the drill page, from memory. Separate from `email` and `secret`, which
    /// stay as they were; both start empty.
    var drillEmail = "" {
        didSet { if drillEmail != oldValue && drillResult == .mismatch { drillResult = nil } }
    }
    var drillSecret = "" {
        didSet { if drillSecret != oldValue && drillResult == .mismatch { drillResult = nil } }
    }
    var drillRevealed = false
    /// The last Check on the drill page; nil until then, and again after any edit of a mismatch.
    private(set) var drillResult: DrillResult?

    // MARK: Presentation

    var weakWarning: Strength?
    var errorMessage: String?
    var showingQr = false
    /// The warning before the first copy, shown inside the screen shield.
    private(set) var showingCopyWarning = false
    /// Whether the user has seen the warning and chosen to copy, in this process only: never stored,
    /// so each launch warns again.
    @ObservationIgnored private var copyWarningAccepted = false
    private(set) var toast: String?
    @ObservationIgnored private var toastGeneration = 0
    /// Whether Keyper copied the phrase in this session and has not cleared it since.
    @ObservationIgnored private var copied = false
    /// A type Keyper's copy carries beside the text. While the pasteboard has it, it still holds
    /// Keyper's copy (anything copied since replaces it), and asking for a type reads nothing and
    /// raises no paste prompt. The change count cannot tell: on iOS 26 it moves when a text field
    /// takes the focus, with nothing copied.
    static let copyMarker = "app.getkeyper.copied-phrase"
    @ObservationIgnored private let pasteboard: any PhrasePasteboard
    /// How long a copied phrase stays on the pasteboard before iOS removes it.
    static let clipboardSeconds: TimeInterval = 60
    @ObservationIgnored private let clipboardLifetime: TimeInterval
    /// Where the screen should scroll next; the view clears it once done.
    var scrollTarget: ScrollTarget?

    let domain = domainHex.unhex
    var domainId: String { Keyper.domainId(domain) }
    /// SPEC.md's test domain constant; a build carrying it gets a warning banner.
    var isTestBuild: Bool { domain == (0..<32).map { UInt8($0) } }

    init() {
        monitor = OfflineMonitor()
        makeDerivation = { Derivation() }
        pasteboard = UIPasteboard.general
        clipboardLifetime = Self.launchClipboardLifetime
        monitor.onChange = { [weak self] radios in self?.radiosChanged(radios) }
        monitor.start()
    }

    #if DEBUG
    /// UI tests: `-KeyperClipboardSeconds 5` shortens a copy's lifetime. copyPhrase uses it exactly as
    /// it uses the real 60 seconds, as the expiration date of the same setItems call.
    private static var launchClipboardLifetime: TimeInterval {
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: "-KeyperClipboardSeconds"), i + 1 < arguments.count,
              let seconds = TimeInterval(arguments[i + 1]), seconds > 0 else { return clipboardSeconds }
        return seconds
    }

    /// Unit tests only: a monitor fed by a fake probe (checked now, then only when the test asks), a
    /// fake derivation, a wrapped pasteboard and a shorter clipboard lifetime.
    init(
        monitor: OfflineMonitor,
        derivation: @escaping () -> any KeyDerivation = { Derivation() },
        pasteboard: any PhrasePasteboard = UIPasteboard.general,
        clipboardLifetime: TimeInterval = KeyperModel.clipboardSeconds
    ) {
        self.monitor = monitor
        makeDerivation = derivation
        self.pasteboard = pasteboard
        self.clipboardLifetime = clipboardLifetime
        monitor.onChange = { [weak self] radios in self?.radiosChanged(radios) }
        monitor.check()
    }
    #else
    private static var launchClipboardLifetime: TimeInterval { clipboardSeconds }
    #endif

    // MARK: Typing

    /// The sentence takes no keys while online, whatever holds the focus.
    private var target: TextTarget? {
        switch focus {
        case .email: emailTarget
        case .secret: offline ? secretTarget : nil
        case .drillEmail: drillEmailTarget
        case .drillSecret: offline ? drillSecretTarget : nil
        case nil: nil
        }
    }

    func type(_ c: Character) {
        guard Keyper.isSecretChar(c) || c == " " else { return }
        target?.keyperInsert(c)
    }

    func deleteBackward() { target?.keyperDelete() }

    /// "Next" on the email moves to the secret, if it may be typed; "done" on the secret closes the
    /// keyboard, as does "Next" while online.
    func done() {
        if focus?.isEmail == true && offline && !busy {
            let next: Field = focus == .email ? .secret : .drillSecret
            focus = next
            scrollTarget = .field(next)
        } else {
            focus = nil
        }
    }

    func focus(_ field: Field) {
        guard field.isEmail ? !busy : offline && !busy else { return }
        focus = field
        scrollTarget = .field(field)
    }

    // MARK: Strength

    var secretLength: Int { Keyper.normalizeSecret(secret).unicodeScalars.count }
    var strength: Strength? { secretLength == 0 ? nil : Strength.of(secret) }

    // MARK: Generating

    var phrase: [String]? { key.map { Keyper.mnemonic(key: $0, words: words) } }
    var showsResult: Bool { phrase != nil && !drilling }

    func generate() {
        guard offline, !busy, !drilling else { return }
        guard Keyper.isValidEmail(Keyper.normalizeEmail(email)) else {
            emailError = strings["error_email_invalid"]
            return
        }
        guard secretLength >= Keyper.minSecretLength else {
            secretError = strings.format("secret_too_short", secretLength, Keyper.minSecretLength)
            return
        }
        let estimate = Strength.of(secret)
        if estimate.level >= .good {
            derive()
        } else {
            // Below US$100 million of attack: a warning, never a refusal, so that a stricter
            // estimator in some later release can never lock anyone out of an existing phrase.
            weakWarning = estimate
        }
    }

    func generateAnyway() {
        weakWarning = nil
        derive()
    }

    private func derive() {
        generation += 1
        let id = generation
        let (email, secret) = (self.email, self.secret)
        busy = true
        focus = nil
        progress = (0, 1, 0)
        UIApplication.shared.isIdleTimerDisabled = true // a minute of work must outlast the screen timeout
        let run = makeDerivation()
        derivation = run
        run.start(
            email: email, secret: secret, domain: domain,
            progress: { [weak self] done, total, elapsed in
                MainActor.assumeIsolated {
                    guard let self, id == self.generation else { return }
                    self.progress = (done, total, elapsed)
                }
            },
            completion: { [weak self] result in
                MainActor.assumeIsolated { self?.finish(id, result, email, secret) }
            }
        )
    }

    private func finish(_ id: Int, _ result: Result<[UInt8], Error>, _ email: String, _ secret: String) {
        // A stopped run can finish after a newer one has started: it must leave that one's state alone.
        guard id == generation else { return }
        busy = false
        UIApplication.shared.isIdleTimerDisabled = false
        derivation = nil
        // The radios may have come on since the last poll: look again before showing a phrase. Going
        // online now discards everything, as it would a phrase already on screen.
        monitor.check()
        guard offline else { return }
        switch result {
        case .success(let k):
            key = k
            inputs = Keyper.drillFingerprint(key: k, email: email, secret: secret)
            scrollTarget = .result
        case .failure(Derivation.Failure.memory):
            errorMessage = strings["error_memory"]
        case .failure(is Argon2id.Cancelled):
            break
        case .failure(let error):
            errorMessage = strings.format("error_failed", String(describing: error))
        }
    }

    /// Cancel, leaving the app, or going online: discard the result and stop computing. The stopped
    /// run's completion is ignored, so the screen is released here rather than there.
    func stopDerivation() {
        generation += 1
        derivation?.cancel()
        derivation = nil
        busy = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Forgets the phrase; one that was copied leaves the pasteboard with it, unless `keepClipboard`.
    private func discardResult(keepClipboard: Bool = false) {
        if key != nil && !keepClipboard { clearCopiedPhrase() }
        if key != nil { SecureZero.array(&key!) } // overwritten in place before letting go
        key = nil
        if inputs != nil { SecureZero.array(&inputs!) } // keyed with K and wiped with it
        inputs = nil
        closeDrill() // the drill checks against this phrase's inputs: no result of it may outlive them
        weakWarning = nil
        showingQr = false
        showingCopyWarning = false
    }

    // MARK: Recovery drill

    /// Opens the drill page with both of its fields empty; the user types the email and the sentence
    /// again from memory. The phrase stays behind on the main page, with the inputs that made it.
    func startDrill() {
        guard phrase != nil, offline, !busy, !drilling else { return }
        showingQr = false
        showingCopyWarning = false
        resetDrill()
        drilling = true
        focus(.drillEmail)
    }

    /// Check: the normalised inputs are compared with the fingerprint of those that made the phrase,
    /// at once, without a second minute-long derivation. A match forgets what was typed here.
    func checkDrill() {
        guard drilling, offline, !busy else { return }
        guard let k = key, let first = inputs else { return }
        var typed = Keyper.drillFingerprint(key: k, email: drillEmail, secret: drillSecret)
        let match = typed.count == first.count && zip(typed, first).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0 // constant time
        SecureZero.array(&typed)
        if match {
            focus = nil
            drillEmail = ""
            drillSecret = ""
            drillRevealed = false
            drillResult = .passed
        } else {
            drillResult = .mismatch
        }
    }

    /// Back, or "Back to the phrase": the main page again, with the phrase as it was (the key is
    /// kept; nothing is derived again). The drill page's fields and result are forgotten.
    func closeDrill() {
        guard drilling else { return }
        resetDrill()
        if focus == .drillEmail || focus == .drillSecret { focus = nil }
        drilling = false
        if key != nil { scrollTarget = .result }
    }

    private func resetDrill() {
        drillEmail = ""
        drillSecret = ""
        drillRevealed = false
        drillResult = nil
    }

    // MARK: Phrase actions

    /// The Copy button: the first time in this session, a warning that offers the QR code instead;
    /// after the user has chosen to copy once, a copy at once.
    func requestCopy() {
        guard phrase != nil else { return }
        if copyWarningAccepted { copyPhrase() } else { showingCopyWarning = true }
    }

    /// The warning's "Copy": later copies in this session skip the warning.
    func acceptCopyWarning() {
        showingCopyWarning = false
        copyWarningAccepted = true
        copyPhrase()
    }

    /// The warning's "Show QR code": the phrase never touches the pasteboard.
    func chooseQrInstead() {
        showingCopyWarning = false
        showingQr = true
    }

    func dismissCopyWarning() { showingCopyWarning = false }

    /// Copied for 60 seconds and for this device only: iOS clears it, and it never reaches
    /// Universal Clipboard.
    func copyPhrase() {
        guard let phrase else { return }
        pasteboard.setItems(
            [[UTType.utf8PlainText.identifier: phrase.joined(separator: " "), Self.copyMarker: Data([1])]],
            options: [.localOnly: true, .expirationDate: Date(timeIntervalSinceNow: clipboardLifetime)]
        )
        copied = true
        show(toast: strings["copied"], seconds: 2)
    }

    /// "Clear all": abandons everything at once. The phrase and its key, the drill and its result,
    /// both inputs (the email too, unlike leaving or going online), and Keyper's copy on the
    /// pasteboard while the marker shows it is still Keyper's.
    func clearAll() {
        focus = nil
        discardResult() // with the key still there: takes Keyper's copy with it
        clearCopiedPhrase() // and a copy whose phrase was already gone
        email = ""
        secret = ""
        revealed = false
        emailError = nil
        secretError = nil
        scrollTarget = .top
    }

    /// Clears the pasteboard only while it still holds Keyper's copy: anything copied since is not ours.
    private func clearCopiedPhrase() {
        guard copied else { return }
        copied = false
        if pasteboard.contains(pasteboardTypes: [Self.copyMarker]) { pasteboard.items = [] }
    }

    func show(toast text: String, seconds: Double) {
        toastGeneration += 1
        let id = toastGeneration
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.toastGeneration == id { self?.toast = nil }
        }
    }

    // MARK: Lifecycle

    /// Leaving the app forgets the secret and the phrase, and stops any derivation in flight. A copied
    /// phrase stays on the pasteboard until its minute is up: the wallet is where it goes. Discarded
    /// before the secret is cleared, whose own discard would otherwise take the pasteboard with it.
    func leave() {
        stopDerivation()
        focus = nil
        discardResult(keepClipboard: true)
        secret = ""
        revealed = false
    }

    /// Going back online forgets the secret, the phrase and a copy of it at once, and discards a
    /// derivation in flight.
    private func radiosChanged(_ now: OfflineMonitor.Radios) {
        radios = now
        guard !now.offline else { return }
        stopDerivation()
        focus = nil
        secret = ""
        revealed = false
        discardResult()
        clearCopiedPhrase() // even if the phrase on screen was already discarded
    }
}

extension String {
    var unhex: [UInt8] {
        var out = [UInt8]()
        var i = startIndex
        while i < endIndex {
            let j = index(i, offsetBy: 2)
            out.append(UInt8(self[i..<j], radix: 16)!)
            i = j
        }
        return out
    }
}
