import CryptoKit
import KeyperCore
import Observation
import UIKit
import UniformTypeIdentifiers

/// A field the keyboard types into: it edits at its own cursor, then reports the new text.
@MainActor
protocol TextTarget: AnyObject {
    func keyperInsert(_ c: Character)
    func keyperDelete()
}

/// The screen's state and rules, the same as the Android app's MainActivity: what is typed, the
/// offline gate, the derivation, the phrase and the recovery drill. Nothing is stored: leaving the
/// app or going online forgets it all.
@MainActor
@Observable
final class KeyperModel {
    enum Field: Hashable { case email, secret }
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
    @ObservationIgnored private let monitor = OfflineMonitor()

    // MARK: Inputs

    var email = "" {
        didSet {
            guard email != oldValue else { return }
            emailError = nil
            if !drilling { discardResult() }
        }
    }
    var secret = "" {
        didSet {
            guard secret != oldValue else { return }
            secretError = nil
            if !drilling { discardResult() }
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

    // MARK: Derivation and result

    private(set) var busy = false
    private(set) var progress = (done: 0, total: 1, elapsed: TimeInterval(0))
    /// Bumped to discard the result of a derivation that is still running.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var derivation: Derivation?
    /// The key K derived from the current inputs; both phrase lengths are read from it.
    private var key: [UInt8]?
    /// Fingerprint of the normalised inputs that produced `key`, for the recovery drill.
    @ObservationIgnored private var inputs: [UInt8]?
    /// True while the user re-enters the inputs from memory; `key` is kept, but hidden.
    private(set) var drilling = false

    // MARK: Presentation

    var weakWarning: Strength?
    var errorMessage: String?
    var showingQr = false
    private(set) var toast: String?
    @ObservationIgnored private var toastGeneration = 0
    /// Where the screen should scroll next; the view clears it once done.
    var scrollTarget: ScrollTarget?

    let domain = domainHex.unhex
    var domainId: String { Keyper.domainId(domain) }
    /// SPEC.md's test domain constant; a build carrying it gets a warning banner.
    var isTestBuild: Bool { domain == (0..<32).map { UInt8($0) } }

    init() {
        monitor.onChange = { [weak self] radios in self?.radiosChanged(radios) }
        monitor.start()
    }

    // MARK: Typing

    private var target: TextTarget? {
        switch focus {
        case .email: emailTarget
        case .secret: secretTarget
        case nil: nil
        }
    }

    func type(_ c: Character) {
        guard Keyper.isSecretChar(c) || c == " " else { return }
        target?.keyperInsert(c)
    }

    func deleteBackward() { target?.keyperDelete() }

    /// "Next" on the email moves to the secret; "done" on the secret closes the keyboard.
    func done() {
        if focus == .email {
            focus = .secret
            scrollTarget = .field(.secret)
        } else {
            focus = nil
        }
    }

    func focus(_ field: Field) {
        guard field == .email ? !busy : offline && !busy else { return }
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
        guard offline, !busy else { return }
        if drilling {
            if fingerprint(email, secret) == inputs { endDrill(passed: true) } else { secretError = strings["drill_mismatch"] }
            return
        }
        guard Keyper.normalizeEmail(email).count >= Keyper.minEmailLength else {
            emailError = strings.format("error_email_short", Keyper.minEmailLength)
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
        let run = Derivation()
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
        busy = false
        UIApplication.shared.isIdleTimerDisabled = false
        guard id == generation else { return }
        derivation = nil
        switch result {
        case .success(let k):
            key = k
            inputs = fingerprint(email, secret)
            scrollTarget = .result
        case .failure(Derivation.Failure.memory):
            errorMessage = strings["error_memory"]
        case .failure(is Argon2id.Cancelled):
            break
        case .failure(let error):
            errorMessage = strings.format("error_failed", String(describing: error))
        }
    }

    /// Cancel, leaving the app, or going online: discard the result and stop computing.
    func stopDerivation() {
        generation += 1
        derivation?.cancel()
        derivation = nil
    }

    private func discardResult() {
        if key != nil { for i in key!.indices { key![i] = 0 } } // overwritten in place before letting go
        key = nil
        inputs = nil
        drilling = false
        weakWarning = nil
        showingQr = false
    }

    // MARK: Recovery drill

    /// Hide the phrase and clear both fields; the user re-enters them from memory, and the
    /// normalised inputs are compared at once, without a second minute-long derivation.
    func startDrill() {
        drilling = true
        email = ""
        secret = ""
        scrollTarget = .top
        focus(.email)
    }

    func endDrill(passed: Bool) {
        drilling = false
        if passed {
            focus = nil
            scrollTarget = .result
            show(toast: strings["drill_ok"], seconds: 3.5)
        } else {
            discardResult()
        }
    }

    private func fingerprint(_ email: String, _ secret: String) -> [UInt8] {
        let text = Keyper.normalizeEmail(email) + "\n" + Keyper.normalizeSecret(secret)
        return Array(SHA256.hash(data: Array(text.utf8)))
    }

    // MARK: Phrase actions

    /// Copied for 60 seconds and for this device only: iOS clears it, and it never reaches
    /// Universal Clipboard.
    func copyPhrase() {
        guard let phrase else { return }
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: phrase.joined(separator: " ")]],
            options: [.localOnly: true, .expirationDate: Date(timeIntervalSinceNow: 60)]
        )
        show(toast: strings["copied"], seconds: 2)
    }

    func clearSecret() { secret = "" }

    func show(toast text: String, seconds: Double) {
        toastGeneration += 1
        let id = toastGeneration
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.toastGeneration == id { self?.toast = nil }
        }
    }

    // MARK: Lifecycle

    /// Leaving the app forgets the secret and the phrase, and stops any derivation in flight.
    func leave() {
        stopDerivation()
        drilling = false
        focus = nil
        secret = ""
        discardResult()
    }

    /// Going back online forgets the secret and the phrase at once and discards a derivation in flight.
    private func radiosChanged(_ now: OfflineMonitor.Radios) {
        radios = now
        guard !now.offline else { return }
        stopDerivation()
        drilling = false
        focus = nil
        secret = ""
        discardResult()
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
