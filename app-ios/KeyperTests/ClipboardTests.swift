import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 6, "Clipboard cleared": a copied phrase stays on this device only and iOS removes it
    /// after 60 seconds; going online clears it; leaving the app does not; and whatever is copied
    /// after it (another app's content) is never cleared. These read the real pasteboard, which an
    /// app-hosted test may do without a prompt because the host app wrote it.
    @MainActor @Suite
    struct ClipboardTests {
        private let pasteboard = UIPasteboard.general

        init() { UIPasteboard.general.items = [] }

        @Test func aCopyLastsSixtySeconds() throws {
            #expect(KeyperModel.clipboardSeconds == 60)
            let h = Harness()
            h.generated()
            let before = Date()
            h.model.copyPhrase()
            let options = try #require(h.pasteboard.copies.last)
            let expiry = try #require(options[.expirationDate] as? Date)
            #expect(abs(expiry.timeIntervalSince(before) - 60) < 2, "expires \(expiry.timeIntervalSince(before)) s after the copy")
            #expect(pasteboard.string == Harness.phrase.joined(separator: " "))
            pasteboard.items = []
        }

        @Test func aCopyIsLocalOnly() throws {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            let options = try #require(h.pasteboard.copies.last)
            #expect(options[.localOnly] as? Bool == true, "the copy may reach Universal Clipboard")
            #expect(h.pasteboard.copies.count == 1)
            // iOS expires the copy; Keyper does not clear it itself, and says so.
            #expect(h.model.toast == h.model.strings["copied"])
            #expect(L10n(.en)["copied"] == "Copied. It expires in 60 seconds.")
            #expect(L10n(.zh)["copied"] == "已复制，60 秒后失效。")
            pasteboard.items = []
        }

        /// With the lifetime shortened (a test-only initialiser), iOS itself empties the pasteboard
        /// once it is up; Keyper runs no timer of its own for it.
        @Test func aCopyIsGoneOnceItExpires() async throws {
            let h = Harness(clipboardLifetime: 1.5)
            h.generated()
            h.model.copyPhrase()
            #expect(pasteboard.string == Harness.phrase.joined(separator: " "))
            try await spin(3)
            #expect(!pasteboard.hasStrings, "still on the pasteboard after its lifetime")
            #expect(pasteboard.items.isEmpty)
        }

        /// "Clear all" abandons everything: both inputs, the phrase, the drill and its result, and
        /// Keyper's copy on the pasteboard.
        @Test(arguments: [false, true])
        func clearAllWipesEverythingAndKeypersCopy(fromAPassedDrill: Bool) {
            let h = Harness()
            h.generated()
            h.model.revealed = true
            h.model.copyPhrase()
            #expect(pasteboard.contains(pasteboardTypes: [KeyperModel.copyMarker]))
            if fromAPassedDrill {
                h.model.startDrill()
                h.model.drillEmail = Harness.email
                h.model.drillSecret = Harness.sentence
                h.model.checkDrill()
                #expect(h.model.drillResult == .passed)
                h.model.closeDrill()
            }

            h.model.clearAll()

            #expect(h.model.email.isEmpty, "the email survived Clear all")
            #expect(h.model.secret.isEmpty, "the sentence survived Clear all")
            #expect(h.model.phrase == nil && !h.model.showsResult)
            #expect(!h.model.revealed)
            #expect(h.model.drillResult == nil && !h.model.drilling)
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty)
            #expect(h.model.focus == nil)
            #expect(!pasteboard.hasStrings && pasteboard.items.isEmpty, "Keyper's copy survived Clear all")
            h.model.startDrill()
            #expect(!h.model.drilling, "a drill without a phrase")
            #expect(h.derivations.runs.count == 1)
        }

        /// What another app copied after Keyper's copy is not Keyper's to clear.
        @Test func clearAllLeavesAnotherAppsLaterCopy() {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            pasteboard.string = "copied in another app"
            h.model.clearAll()
            #expect(pasteboard.string == "copied in another app", "Clear all cleared another app's content")
            #expect(h.model.email.isEmpty && h.model.secret.isEmpty && h.model.phrase == nil)
            pasteboard.items = []
        }

        @Test func clearAllIsLabelledSo() {
            #expect(L10n(.en)["clear"] == "Clear all")
            #expect(L10n(.zh)["clear"] == "全部清除")
        }

        @Test func goingOnlineClearsKeypersCopy() {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            h.goOnline()
            #expect(!pasteboard.hasStrings, "the copy survived going online")
            #expect(pasteboard.items.isEmpty)
        }

        /// The wallet is where the phrase goes, so leaving the app keeps the copy for its minute; the
        /// phone going online afterwards still clears it.
        @Test func leavingTheAppKeepsTheCopy() {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            h.model.leave()
            #expect(h.model.phrase == nil)
            #expect(pasteboard.string == Harness.phrase.joined(separator: " "), "leaving cleared the copy")
            h.goOnline()
            #expect(!pasteboard.hasStrings, "going online after leaving left the copy")
        }

        /// Anything copied after Keyper's copy replaces its items, marker included: that content is
        /// someone else's, and neither going online nor discarding the phrase touches it.
        @Test func anotherAppsLaterContentIsNeverCleared() {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            pasteboard.string = "copied in another app"
            h.goOnline()
            #expect(pasteboard.string == "copied in another app")

            let h2 = Harness()
            h2.generated()
            h2.model.copyPhrase()
            pasteboard.string = "copied in another app"
            h2.model.email = "bob@example.com" // discards the phrase
            #expect(h2.model.phrase == nil)
            #expect(pasteboard.string == "copied in another app")
            h2.model.leave()
            h2.goOnline()
            #expect(pasteboard.string == "copied in another app")
            pasteboard.items = []
        }

        /// The Copy button warns first, once per session: the warning writes nothing, "Show QR code"
        /// writes nothing either and warns again next time, "Copy" makes the same 60-second local copy,
        /// and later taps copy at once. A new model (a new launch) warns again: nothing is stored.
        @Test func theFirstCopyOfASessionWarnsFirst() throws {
            let h = Harness()
            h.generated()
            let count = pasteboard.changeCount
            h.model.requestCopy()
            #expect(h.model.showingCopyWarning)
            #expect(h.pasteboard.copies.isEmpty && pasteboard.changeCount == count, "the warning wrote the pasteboard")

            h.model.chooseQrInstead()
            #expect(!h.model.showingCopyWarning)
            #expect(h.model.showingQr)
            #expect(h.pasteboard.copies.isEmpty && pasteboard.changeCount == count, "choosing the QR code wrote the pasteboard")
            #expect(!pasteboard.hasStrings)
            h.model.showingQr = false

            h.model.requestCopy()
            #expect(h.model.showingCopyWarning, "no copy yet, so the warning shows again")
            let before = Date()
            h.model.acceptCopyWarning()
            #expect(!h.model.showingCopyWarning)
            let options = try #require(h.pasteboard.copies.last)
            #expect(h.pasteboard.copies.count == 1)
            #expect(options[.localOnly] as? Bool == true)
            let expiry = try #require(options[.expirationDate] as? Date)
            #expect(abs(expiry.timeIntervalSince(before) - 60) < 2)
            #expect(pasteboard.string == Harness.phrase.joined(separator: " "))

            h.model.requestCopy()
            #expect(!h.model.showingCopyWarning, "warned twice in one session")
            #expect(h.pasteboard.copies.count == 2)
            pasteboard.items = []

            let next = Harness()
            next.generated()
            next.model.requestCopy()
            #expect(next.model.showingCopyWarning, "a new session must warn again")
            #expect(next.pasteboard.copies.isEmpty)
        }

        /// Leaving or discarding the phrase takes the warning with it.
        @Test func theWarningGoesWithThePhrase() {
            let h = Harness()
            h.generated()
            h.model.requestCopy()
            h.model.leave()
            #expect(!h.model.showingCopyWarning)
            h.model.requestCopy() // no phrase, nothing to copy
            #expect(!h.model.showingCopyWarning)
            #expect(h.pasteboard.copies.isEmpty)
        }

        @Test func theWarningsWording() {
            let en = L10n(.en), zh = L10n(.zh)
            #expect(en["copy_warning_title"] == "Copy to the clipboard?")
            #expect(en["copy_warning_message"] == "Keyboards and clipboard history may keep their own copy, which Keyper cannot erase. The QR code avoids the clipboard.")
            #expect(en["copy_warning_copy"] == "Copy" && en["copy_warning_qr"] == "Show QR code")
            #expect(zh["copy_warning_title"] == "复制到剪贴板？")
            #expect(zh["copy_warning_message"] == "输入法和剪贴板历史可能另存一份，Keyper 无法清除。用二维码可以完全不经过剪贴板。")
            #expect(zh["copy_warning_copy"] == "复制" && zh["copy_warning_qr"] == "显示二维码")
        }

        /// The copy is the phrase as text plus Keyper's marker type, nothing else.
        @Test func aCopyIsTheTextAndTheMarker() throws {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            let items = try #require(h.pasteboard.copiedItems.last)
            #expect(items.count == 1)
            #expect(Set(items[0].keys) == ["public.utf8-plain-text", KeyperModel.copyMarker])
            #expect(pasteboard.contains(pasteboardTypes: [KeyperModel.copyMarker]))
            pasteboard.items = []
        }

        /// Regression: a text field taking the focus moves the pasteboard's change count on iOS 26 with
        /// nothing copied (seen in the UI tests: +4 on tapping the email). Keyper's clear once compared
        /// change counts, so after any tap on a field, discarding the phrase or going online left the
        /// copy behind.
        @Test func focusingAFieldDoesNotStopTheClear() async throws {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            let window = UIWindow(windowScene: hostScene)
            window.frame = hostScene.screen.bounds
            window.rootViewController = UIViewController()
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let field = UITextField(frame: CGRect(x: 20, y: 100, width: 200, height: 40))
            window.rootViewController!.view.addSubview(field)
            let before = pasteboard.changeCount
            field.becomeFirstResponder()
            try await spin(1)
            field.resignFirstResponder()
            print("KEYPER-PASTEBOARD change count \(before) → \(pasteboard.changeCount) across a field's focus")
            #expect(pasteboard.hasStrings)
            h.model.secret = Harness.sentence + "!" // discards the phrase, and its copy
            #expect(!pasteboard.hasStrings, "a field's focus stopped Keyper clearing its own copy")

            let h2 = Harness()
            h2.generated()
            h2.model.copyPhrase()
            field.becomeFirstResponder()
            try await spin(1)
            field.resignFirstResponder()
            h2.goOnline()
            #expect(!pasteboard.hasStrings, "a field's focus stopped going online from clearing Keyper's copy")
        }

        /// Editing the inputs discards the phrase, and a copy of it that is still Keyper's.
        @Test func discardingThePhraseClearsKeypersCopy() {
            let h = Harness()
            h.generated()
            h.model.copyPhrase()
            h.model.secret = Harness.sentence + "!"
            #expect(h.model.phrase == nil)
            #expect(!pasteboard.hasStrings)
        }
    }
}
