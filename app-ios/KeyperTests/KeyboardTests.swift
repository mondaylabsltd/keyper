import Testing
import UIKit
@testable import Keyper

/// The keyboard's touch rules with several fingers, which UI tests cannot play: the same cases as
/// the Android app's multi-pointer check.
@MainActor
struct KeyboardTests {
    private let keyboard = KeyperKeyboardView()
    private var typed = Typed()

    final class Typed { var text = "" }

    init() {
        keyboard.frame = CGRect(x: 0, y: 0, width: 393, height: KeyperKeyboardView.height)
        keyboard.layoutIfNeeded()
        let typed = typed
        keyboard.onKey = { typed.text.append($0) }
        keyboard.onDelete = { if !typed.text.isEmpty { typed.text.removeLast() } }
    }

    private func at(_ label: String) -> CGPoint { keyboard.center(of: label)! }

    @Test func typesOnLiftNotOnTouch() {
        keyboard.fingerDown(1, at: at("h"))
        #expect(typed.text == "")
        keyboard.fingerUp(1)
        #expect(typed.text == "h")
    }

    @Test func aSecondFingerTypesTheFirstKeyAtOnce() {
        keyboard.fingerDown(1, at: at("h"))
        keyboard.fingerDown(2, at: at("i"))
        #expect(typed.text == "h")
        keyboard.fingerUp(1)
        #expect(typed.text == "h")
        keyboard.fingerUp(2)
        #expect(typed.text == "hi")
        // The second finger lifting first changes nothing either.
        keyboard.fingerDown(1, at: at("o"))
        keyboard.fingerDown(2, at: at("k"))
        keyboard.fingerUp(2)
        #expect(typed.text == "hiok")
        keyboard.fingerUp(1)
        #expect(typed.text == "hiok")
    }

    @Test func aFingerSlidesToTheRightKey() {
        keyboard.fingerDown(1, at: at("q"))
        keyboard.fingerMoved(1, to: at("w"))
        keyboard.fingerMoved(1, to: at("e"))
        keyboard.fingerUp(1)
        #expect(typed.text == "e")
    }

    @Test func gapsAndEdgesBelongToTheNearestKey() {
        let q = at("q"), w = at("w"), a = at("a")
        keyboard.fingerDown(1, at: CGPoint(x: (q.x + w.x) / 2 - 3, y: q.y)) // just left of the middle: q
        keyboard.fingerUp(1)
        keyboard.fingerDown(1, at: CGPoint(x: (q.x + w.x) / 2 + 3, y: q.y)) // just right: w
        keyboard.fingerUp(1)
        keyboard.fingerDown(1, at: CGPoint(x: 1, y: a.y)) // the left edge of the second row: a
        keyboard.fingerUp(1)
        keyboard.fingerDown(1, at: CGPoint(x: w.x, y: (w.y + a.y) / 2 - 2)) // between the rows, nearer the top one
        keyboard.fingerUp(1)
        #expect(typed.text == "qwaw")
    }

    @Test func cancellingTypesNothing() {
        keyboard.fingerDown(1, at: at("z"))
        keyboard.cancelAll()
        #expect(typed.text == "")
    }

    @Test func deleteActsOnTouchAndOtherFingersStillType() {
        typed.text = "ab"
        keyboard.fingerDown(1, at: at("Delete"))
        #expect(typed.text == "a")
        keyboard.fingerDown(2, at: at("x"))
        keyboard.fingerUp(2)
        #expect(typed.text == "ax")
        keyboard.fingerUp(1)
        #expect(typed.text == "ax")
    }

    @Test func shiftOnceThenLock() {
        keyboard.fingerDown(1, at: at("Shift"))
        keyboard.fingerUp(1)
        keyboard.fingerDown(1, at: at("A"))
        keyboard.fingerUp(1)
        keyboard.fingerDown(1, at: at("b"))
        keyboard.fingerUp(1)
        #expect(typed.text == "Ab")
    }

    @Test func symbolsLayer() {
        keyboard.fingerDown(1, at: at("123"))
        keyboard.fingerUp(1)
        for c in "!@#$%^&*().,?-_+=/7" {
            keyboard.fingerDown(1, at: at(String(c)))
            keyboard.fingerUp(1)
        }
        #expect(typed.text == "!@#$%^&*().,?-_+=/7")
    }
}
