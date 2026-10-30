import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 1, "Its own keyboard": the fields never connect to the system keyboard, so no keyboard app
    /// can log or sync input. Both fields are checked as the app builds them.
    @MainActor @Suite
    struct OwnKeyboardTests {
        private let field = KeyperTextField()
        private let view = KeyperTextView()

        private var both: [(name: String, input: UIView & UITextInputTraits)] { [("email", field), ("secret", view)] }

        /// An input view replaces the system keyboard; Keyper's is an empty, zero-sized UIView, so no
        /// keyboard (system or third-party) is ever loaded for these fields.
        @Test func inputViewIsKeypersEmptyView() {
            for (name, input) in [("email", field as UIResponder), ("secret", view as UIResponder)] {
                let inputView = try! #require(input.inputView, "\(name): no input view, so iOS would show the system keyboard")
                #expect(type(of: inputView) == UIView.self, "\(name)")
                #expect(inputView.bounds.size == .zero, "\(name)")
                #expect(inputView.subviews.isEmpty, "\(name)")
                #expect(input.inputAccessoryView == nil, "\(name)")
            }
            // No shortcut bar above the (absent) keyboard either.
            for item in [field.inputAssistantItem, view.inputAssistantItem] {
                #expect(item.leadingBarButtonGroups.isEmpty)
                #expect(item.trailingBarButtonGroups.isEmpty)
            }
        }

        /// Focused in a window, the input view is still Keyper's empty view, and iOS reports no
        /// keyboard frame of any height for it; a plain UITextField in the same window, as a control,
        /// does get the system keyboard (which needs no hardware keyboard attached to the simulator,
        /// as on CI's headless simulators).
        @Test func focusedFieldsGetNoSystemKeyboard() async throws {
            let window = UIWindow(windowScene: hostScene)
            window.frame = hostScene.screen.bounds
            window.rootViewController = UIViewController()
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            var heights = [CGFloat]()
            let observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { note in
                let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
                MainActor.assumeIsolated { heights.append(frame.intersection(window.bounds).height) }
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            for (name, input) in [("email", field as UIView), ("secret", view as UIView)] {
                input.frame = CGRect(x: 20, y: 120, width: 300, height: 60)
                window.rootViewController!.view.addSubview(input)
                heights = []
                #expect(input.becomeFirstResponder(), "\(name)")
                try await spin(1)
                #expect(input.isFirstResponder, "\(name)")
                #expect(type(of: input.inputView!) == UIView.self && input.inputView!.bounds.size == .zero, "\(name)")
                #expect(heights.allSatisfy { $0 == 0 }, "\(name): a keyboard of height \(heights) came up")
                input.resignFirstResponder()
                input.removeFromSuperview()
                try await spin(0.5)
            }

            // The control: the same check sees a system keyboard come up for an ordinary field.
            let plain = UITextField(frame: CGRect(x: 20, y: 120, width: 300, height: 40))
            window.rootViewController!.view.addSubview(plain)
            heights = []
            plain.becomeFirstResponder()
            try await spin(1.5)
            let controlSawKeyboard = heights.contains { $0 > 100 }
            plain.resignFirstResponder()
            try await spin(0.5)
            #expect(controlSawKeyboard, "control: no system keyboard for an ordinary field either (\(heights)), so this check cannot see one; detach the simulator's hardware keyboard")
        }

        /// The edit menu offers nothing: no paste (so no clipboard reads), no cut or copy (so nothing
        /// typed reaches the clipboard), no select, share, look-up, translate, replace, dictation, text
        /// from the camera or Writing Tools.
        @Test func editActionsAreAllRefused() {
            let actions = [
                "cut:", "copy:", "paste:", "pasteAndMatchStyle:", "pasteAndGo:", "pasteAndSearch:", "select:", "selectAll:",
                "delete:", "replace:", "_share:", "_define:", "_lookup:", "_translate:", "_promptForReplace:",
                "_transliterateChinese:", "captureTextFromCamera:", "showWritingTools:", "toggleBoldface:", "toggleItalics:",
                "toggleUnderline:", "makeTextWritingDirectionLeftToRight:", "makeTextWritingDirectionRightToLeft:",
                "_showTextStyleOptions:", "startDictation:", "find:", "findAndReplace:", "useSelectionForFind:",
            ]
            for action in actions.map(NSSelectorFromString) {
                #expect(!field.canPerformAction(action, withSender: nil), "email allows \(action)")
                #expect(!view.canPerformAction(action, withSender: nil), "secret allows \(action)")
            }
            // The secret's edit menu, if UIKit asks for one, is empty.
            let menu = view.textView(view, editMenuForTextIn: NSRange(location: 0, length: 0), suggestedActions: [UIAction(title: "Paste") { _ in }])
            #expect(menu?.children.isEmpty == true)
        }

        /// iOS's own text services are all off: no autocorrection or capitals, no spell checking, no
        /// smart punctuation, no inline prediction, no Writing Tools, no drag, no data detectors.
        @Test func textServicesAreOff() {
            for (name, input) in both {
                #expect(input.autocorrectionType == .no, "\(name)")
                #expect(input.autocapitalizationType == UITextAutocapitalizationType.none, "\(name)")
                #expect(input.spellCheckingType == .no, "\(name)")
                #expect(input.smartQuotesType == .no, "\(name)")
                #expect(input.smartDashesType == .no, "\(name)")
                #expect(input.smartInsertDeleteType == .no, "\(name)")
                #expect(input.inlinePredictionType == .no, "\(name)")
            }
            if #available(iOS 18, *) {
                #expect(field.writingToolsBehavior == UIWritingToolsBehavior.none)
                #expect(view.writingToolsBehavior == UIWritingToolsBehavior.none)
            }
            #expect(field.textDragInteraction?.isEnabled != true)
            #expect(view.textDragInteraction?.isEnabled != true)
            #expect(view.dataDetectorTypes.isEmpty)
        }

        /// Every change UIKit proposes (a hardware keyboard, paste, dictation, a drop) goes through the
        /// delegate, which refuses it; only Keyper's keyboard edits the text.
        @Test func changesFromUIKitAreRefused() {
            let delegate = try! #require(field.delegate)
            #expect(delegate === field)
            for text in ["x", "pasted words", ""] {
                #expect(delegate.textField?(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: text) == false)
                #expect(view.delegate?.textView?(view, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: text) == false)
            }
            // paste: with the action refused, a direct call changes nothing either.
            UIPasteboard.general.string = "pasted"
            field.paste(nil)
            view.paste(nil)
            #expect((field.text ?? "").isEmpty)
            #expect(view.secret.isEmpty)
            UIPasteboard.general.items = []

            // Keyper's keyboard, by contrast, types.
            var reported = [String]()
            field.onChange = { reported.append($0) }
            field.keyperInsert("a")
            field.keyperInsert("b")
            field.keyperDelete()
            #expect(field.text == "a")
            #expect(reported == ["a", "ab", "a"])
        }
    }
}
