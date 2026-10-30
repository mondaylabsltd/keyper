import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 2, "Offline gate": going online wipes the sentence, the phrase and Keyper's copy on the
    /// pasteboard, and the sentence cannot be typed or used while online. The pasteboard half is in
    /// ClipboardTests (goingOnlineClearsKeypersCopy, anotherAppsLaterContentIsNeverCleared).
    @MainActor @Suite
    struct OfflineGateTests {
        @Test func theGateIsOfflineOnlyWithEveryRadioOff() {
            #expect(OfflineMonitor.Radios().offline)
            #expect(!OfflineMonitor.Radios(cellular: true).offline)
            #expect(!OfflineMonitor.Radios(wifi: true).offline)
            #expect(!OfflineMonitor.Radios(otherNetwork: true).offline)
        }

        @Test func goingOnlineWipesTheSentenceAndThePhrase() {
            let h = Harness()
            let phrase = h.generated()
            #expect(phrase == Harness.phrase)
            h.model.revealed = true
            h.model.focus = .secret

            h.goOnline()

            #expect(!h.model.offline)
            #expect(h.model.secret.isEmpty, "the sentence is wiped")
            #expect(h.model.phrase == nil, "the phrase is wiped")
            #expect(!h.model.showsResult)
            #expect(!h.model.revealed)
            #expect(h.model.focus == nil, "the keyboard closes")
            #expect(h.model.email == Harness.email, "the email is kept")
            // Back offline, nothing comes back.
            h.goOffline()
            #expect(h.model.phrase == nil && h.model.secret.isEmpty)
        }

        /// Going online on the drill page wipes what was typed there, the sentence and the phrase kept
        /// behind it, and leaves the page; offline again, nothing comes back.
        @Test func goingOnlineOnTheDrillPageWipesItAndLeaves() {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            h.type(Harness.email, into: .drillEmail)
            h.type("In 2009 Grandma", into: .drillSecret)
            h.model.drillRevealed = true

            h.goOnline()

            #expect(!h.model.drilling, "still on the drill page")
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty, "the drill's fields are wiped")
            #expect(!h.model.drillRevealed)
            #expect(h.model.drillResult == nil)
            #expect(h.model.focus == nil, "the keyboard closes")
            #expect(h.model.phrase == nil && h.model.secret.isEmpty)
            // Online, the drill cannot open, check or take keys.
            h.model.startDrill()
            #expect(!h.model.drilling)
            h.model.focus = .drillSecret
            for c in "abc" { h.model.type(c) }
            #expect(h.model.drillSecret.isEmpty, "typed into the drill's sentence while online")
            h.model.focus = nil
            h.goOffline()
            #expect(h.model.phrase == nil && !h.model.drilling)
        }

        /// A passed drill does not survive going online either.
        @Test func goingOnlineAfterAPassedDrillLeavesNothing() {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            h.model.drillEmail = Harness.email
            h.model.drillSecret = Harness.sentence
            h.model.checkDrill()
            #expect(h.model.drillResult == .passed)
            h.goOnline()
            #expect(h.model.drillResult == nil && !h.model.drilling && h.model.phrase == nil)
        }

        @Test func goingOnlineDuringADerivationStopsItAndDropsItsResult() {
            let h = Harness()
            h.model.email = Harness.email
            h.model.secret = Harness.sentence
            h.model.generate()
            let run = h.derivations.runs[0]
            #expect(h.model.busy)

            h.goOnline()

            #expect(run.cancelled, "the derivation is cancelled")
            #expect(!h.model.busy)
            run.finish() // a run finishing after the cancel
            #expect(h.model.phrase == nil)
            h.goOffline()
            #expect(h.model.phrase == nil)
        }

        /// The radios came on between two polls, just before the minute was up: the result is looked
        /// at again and never shown.
        @Test func aResultArrivingWhileOnlineIsNeverShown() {
            let h = Harness()
            h.model.email = Harness.email
            h.model.secret = Harness.sentence
            h.model.generate()
            h.radios.now = FakeRadios.online // not yet polled
            h.derivations.runs[0].finish()
            #expect(h.model.phrase == nil)
            #expect(h.model.secret.isEmpty)
        }

        /// While online the sentence cannot be focused, typed (not even through "Next" on the email)
        /// or used; the email can, by design, so it is ready once the phone is offline.
        @Test func theSentenceIsRefusedWhileOnline() {
            let h = Harness(offline: false)
            #expect(!h.model.offline)

            h.model.focus(.secret)
            #expect(h.model.focus == nil, "the sentence cannot be focused")

            h.type("alice@example.com", into: .email)
            #expect(h.model.email == "alice@example.com", "the email can be typed online")
            h.model.done() // "Next" on the email
            #expect(h.model.focus != .secret, "Next does not move to the sentence while online")

            // Even with the focus forced onto it, Keyper's keyboard types nothing into it.
            h.model.focus = .secret
            for c in "In 2009 Grandma" { h.model.type(c) }
            h.model.deleteBackward()
            #expect(h.model.secret.isEmpty, "typed into the sentence while online")
            #expect(h.secretView.secret.isEmpty)

            // And a sentence that is there anyway cannot be used.
            h.model.secret = Harness.sentence
            h.model.generate()
            h.model.generateAnyway()
            #expect(h.derivations.runs.count <= 1)
            #expect(h.model.phrase == nil)
            h.derivations.runs.first?.finish()
            #expect(h.model.phrase == nil, "a phrase was derived while online")
        }

        /// The real monitor polls on its own every half second.
        @Test func theMonitorNoticesWithoutBeingAsked() async throws {
            let radios = FakeRadios()
            let monitor = OfflineMonitor(probe: { radios.now })
            var seen = [OfflineMonitor.Radios]()
            monitor.onChange = { seen.append($0) }
            monitor.start()
            defer { monitor.stop() }
            #expect(seen == [OfflineMonitor.Radios()])
            radios.now = FakeRadios.online
            try await spin(1.2)
            #expect(seen == [OfflineMonitor.Radios(), FakeRadios.online])
        }
    }
}
