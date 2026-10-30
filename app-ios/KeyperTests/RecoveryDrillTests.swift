import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 5, "Recovery drill": a page of its own whose two fields start empty. Matching inputs
    /// pass, and "Back to the phrase" shows the same phrase without a second derivation; different
    /// inputs report a mismatch and stay on the page, the phrase hidden. No passed state outlives an
    /// edit of the inputs that made the phrase.
    @MainActor @Suite
    struct RecoveryDrillTests {
        /// The standard inputs typed on the drill page, on Keyper's keyboard, then Check.
        private func pass(_ h: Harness) {
            h.type(Harness.email, into: .drillEmail)
            h.type(Harness.sentence, into: .drillSecret)
            h.model.checkDrill()
        }

        @Test func theDrillOpensItsOwnPageWithEmptyFields() {
            let h = Harness()
            let phrase = h.generated()
            h.model.revealed = true
            h.model.startDrill()
            #expect(h.model.drilling)
            #expect(!h.model.showsResult, "the phrase is not on the drill page")
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty, "the drill's fields start empty")
            #expect(!h.model.drillRevealed, "the drill's sentence starts hidden")
            #expect(h.model.drillResult == nil)
            #expect(h.drillEmailField.text?.isEmpty ?? true && h.drillSecretView.secret.isEmpty)
            #expect(h.model.focus == .drillEmail, "the keyboard opens on the drill's email")
            // The first entry stays as it was, behind the drill page, and the phrase is kept.
            #expect(h.model.email == Harness.email && h.model.secret == Harness.sentence)
            #expect(h.model.phrase == phrase)
        }

        @Test func typingOnTheDrillPageLeavesTheFirstEntryAlone() {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            h.type("bob@example.com", into: .drillEmail)
            h.model.done() // "Next" moves to the drill's sentence
            #expect(h.model.focus == .drillSecret)
            for c in "something else" { h.model.type(c) }
            #expect(h.model.drillEmail == "bob@example.com" && h.model.drillSecret == "something else")
            #expect(h.model.email == Harness.email && h.model.secret == Harness.sentence)
            #expect(h.emailField.text?.isEmpty ?? true, "typed into the first entry's email")
            #expect(h.secretView.secret.isEmpty, "typed into the first entry's sentence")
            #expect(h.model.phrase != nil, "the phrase was discarded")
        }

        @Test func matchingInputsPassAndBackToThePhraseShowsItWithoutASecondDerivation() {
            let h = Harness()
            let phrase = h.generated()
            #expect(h.derivations.runs.count == 1)
            h.model.startDrill()
            pass(h)

            #expect(h.model.drillResult == .passed, "a match shows the passed state")
            #expect(h.model.drilling, "the passed state is on the drill page")
            #expect(!h.model.showsResult)
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty, "a match forgets what was typed for it")
            #expect(h.model.focus == nil, "the keyboard closes")
            #expect(h.derivations.runs.count == 1, "the drill derived again")
            #expect(!h.model.busy)

            h.model.closeDrill() // "Back to the phrase"

            #expect(!h.model.drilling)
            #expect(h.model.showsResult, "the phrase shows again")
            #expect(h.model.phrase == phrase, "the same phrase")
            #expect(h.derivations.runs.count == 1, "the phrase was derived again")
            #expect(!h.model.busy)
            #expect(h.model.drillResult == nil)
        }

        @Test(arguments: [
            ("alice@example.com", "In 2009 Grandma Li and I picked 7 green date"), // one letter short
            ("alice@example.com", "in 2009 Grandma Li and I picked 7 green dates"), // capitals count
            ("alice@example.org", "In 2009 Grandma Li and I picked 7 green dates"), // another email
            ("", ""), // nothing typed
        ])
        func differentInputsReportAMismatchAndStayOnTheDrillPage(email: String, sentence: String) {
            let h = Harness()
            let phrase = h.generated()
            h.model.startDrill()
            h.model.drillEmail = email
            h.model.drillSecret = sentence

            h.model.checkDrill()

            #expect(h.model.drillResult == .mismatch, "a mismatch is reported")
            #expect(h.model.drilling, "still on the drill page")
            #expect(!h.model.showsResult, "the phrase stays hidden")
            #expect(h.model.drillEmail == email && h.model.drillSecret == sentence, "what was typed stays, to be corrected")
            #expect(h.derivations.runs.count == 1, "no second derivation")
            #expect(h.model.secretError == nil && h.model.emailError == nil, "the first entry shows no error")
            // An edit takes the mismatch line away; corrected, the drill passes.
            h.model.drillSecret += "x"
            #expect(h.model.drillResult == nil, "the mismatch line outlived an edit")
            h.model.checkDrill()
            #expect(h.model.drillResult == .mismatch)
            h.model.drillEmail += "x"
            #expect(h.model.drillResult == nil, "the mismatch line outlived an edit")
            h.model.drillEmail = Harness.email
            h.model.drillSecret = Harness.sentence
            h.model.checkDrill()
            #expect(h.model.drillResult == .passed)
            h.model.closeDrill()
            #expect(h.model.showsResult && h.model.phrase == phrase)
            #expect(h.derivations.runs.count == 1)
        }

        /// Back without a Check: the phrase as it was; the drill's fields are forgotten, and the
        /// next drill starts empty again.
        @Test func backReturnsToThePhraseAndForgetsTheDrillsFields() {
            let h = Harness()
            let phrase = h.generated()
            h.model.startDrill()
            h.type(Harness.email, into: .drillEmail)
            h.model.drillRevealed = true
            h.model.closeDrill()
            #expect(!h.model.drilling)
            #expect(h.model.showsResult && h.model.phrase == phrase)
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty && !h.model.drillRevealed)
            #expect(h.model.focus == nil)
            h.model.startDrill()
            #expect(h.model.drillEmail.isEmpty && h.model.drillResult == nil)
        }

        /// No "passed" survives an edit of the first entry: not on the drill page, not after going
        /// back, not in the next drill.
        @Test(arguments: [false, true])
        func editingTheFirstEntryAfterPassingRemovesThePassedState(wentBack: Bool) {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            pass(h)
            #expect(h.model.drillResult == .passed)
            if wentBack { h.model.closeDrill() }

            h.model.secret = Harness.sentence + "!" // as editing the first entry does

            #expect(h.model.drillResult == nil, "a passed result outlived an edit of the inputs")
            #expect(!h.model.drilling)
            #expect(h.model.phrase == nil, "the phrase outlived its inputs")
            h.model.startDrill()
            #expect(!h.model.drilling, "a drill without a phrase")
            #expect(h.model.drillResult == nil)

            // The same through the email, after a fresh phrase and a pass.
            h.model.secret = Harness.sentence
            h.model.generate()
            h.derivations.runs.last!.finish()
            h.model.startDrill()
            pass(h)
            h.model.email = "alice@example.co"
            #expect(h.model.drillResult == nil && !h.model.drilling && h.model.phrase == nil)
        }

        /// Re-entering after Back always starts fresh, whatever the last visit ended with: empty
        /// fields, the sentence hidden, no passed state, no mismatch line.
        @Test(arguments: ["passed", "mismatch", "typed"])
        func reenteringAfterBackAlwaysStartsFresh(lastVisit: String) {
            let h = Harness()
            let phrase = h.generated()
            h.model.startDrill()
            switch lastVisit {
            case "passed": pass(h)
            case "mismatch":
                h.type("bob@example.com", into: .drillEmail)
                h.model.checkDrill()
                #expect(h.model.drillResult == .mismatch)
            default:
                h.type(Harness.email, into: .drillEmail)
                h.type("In 2009", into: .drillSecret)
            }
            h.model.drillRevealed = true
            h.model.closeDrill()
            #expect(h.model.showsResult && h.model.phrase == phrase, "Back keeps the phrase")

            h.model.startDrill()

            #expect(h.model.drilling)
            #expect(h.model.drillResult == nil, "the last visit's \(lastVisit) state came back")
            #expect(h.model.drillEmail.isEmpty && h.model.drillSecret.isEmpty, "the last visit's typing came back")
            #expect(!h.model.drillRevealed)
        }

        /// A pass is never reused: after any edit of the first entry, even one undone at once to the
        /// same inputs, the phrase is gone and a new phrase needs a new drill from scratch.
        @Test(arguments: [KeyperModel.Field.email, .secret])
        func aPassIsNeverReusedAfterAnEditEvenAnUndoneOne(edited: KeyperModel.Field) {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            pass(h)
            h.model.closeDrill()
            if edited == .email {
                h.model.email += "x"
                h.model.email = Harness.email
            } else {
                h.model.secret += "x"
                h.model.secret = Harness.sentence
            }
            #expect(h.model.phrase == nil, "the phrase outlived an edit of its inputs")
            #expect(h.model.drillResult == nil)
            h.model.generate()
            h.derivations.runs.last!.finish()
            #expect(h.derivations.runs.count == 2, "a new phrase is a new derivation")
            h.model.startDrill()
            #expect(h.model.drillResult == nil, "the old pass was reused for the new phrase")
            h.model.checkDrill() // nothing typed
            #expect(h.model.drillResult == .mismatch)
        }

        /// The drill never derives: Generate does nothing while the drill page is open.
        @Test func generateIsInertOnTheDrillPage() {
            let h = Harness()
            h.generated()
            h.model.startDrill()
            h.model.generate()
            #expect(h.derivations.runs.count == 1)
            #expect(!h.model.busy)
        }
    }
}
