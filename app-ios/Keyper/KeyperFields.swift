import SwiftUI
import UIKit

// Both fields are typed only on KeyperKeyboard. An empty input view keeps every system and
// third-party keyboard away, so none can read, learn or upload what is typed. Every change that
// does not come from Keyper's keyboard (a hardware keyboard, paste, dictation, a drop) is refused
// by the delegate, and the edit menu is empty. Moving the cursor, the loupe and selection stay
// native.


/// 16-point monospace that follows the system text size, as the Android fields' sp do.
private var fieldFont: UIFont { UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 16, weight: .regular)) }

/// The email: one line, monospace.
final class KeyperTextField: UITextField, UITextFieldDelegate, TextTarget {
    var onChange: ((String) -> Void)?
    var onFocus: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        autocorrectionType = .no
        autocapitalizationType = UITextAutocapitalizationType.none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        inlinePredictionType = .no
        if #available(iOS 18, *) { writingToolsBehavior = UIWritingToolsBehavior.none }
        inputView = UIView(frame: .zero)
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        delegate = self
        textDragInteraction?.isEnabled = false
        font = fieldFont
        adjustsFontForContentSizeCategory = true
        textColor = Palette.text
        tintColor = Palette.accent
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setPlaceholder(_ text: String) {
        attributedPlaceholder = NSAttributedString(string: text, attributes: [.foregroundColor: Palette.textTertiary, .font: font!])
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { false }
    func textFieldDidBeginEditing(_ textField: UITextField) { onFocus?(true) }
    func textFieldDidEndEditing(_ textField: UITextField) { onFocus?(false) }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    override func buildMenu(with builder: any UIMenuBuilder) { builder.remove(menu: .standardEdit) }

    func keyperInsert(_ c: Character) { replaceSelection(with: String(c)) }

    func keyperDelete() {
        guard let range = selectedNSRange else { return }
        if range.length > 0 { replaceSelection(with: "") } else if range.location > 0 { replace(NSRange(location: range.location - 1, length: 1), with: "") }
    }

    private var selectedNSRange: NSRange? {
        selectedTextRange.map { NSRange(location: offset(from: beginningOfDocument, to: $0.start), length: offset(from: $0.start, to: $0.end)) }
    }

    private func replaceSelection(with s: String) {
        replace(selectedNSRange ?? NSRange(location: (text ?? "").utf16.count, length: 0), with: s)
    }

    private func replace(_ range: NSRange, with s: String) {
        let new = ((text ?? "") as NSString).replacingCharacters(in: range, with: s)
        text = new
        if let p = position(from: beginningOfDocument, offset: range.location + s.utf16.count) { selectedTextRange = textRange(from: p, to: p) }
        onChange?(new)
    }
}

/// The secret: several lines, monospace, masked with bullets while hidden. The view holds bullets
/// then, never the secret, so the loupe and accessibility see bullets too.
final class KeyperTextView: UITextView, UITextViewDelegate, TextTarget {
    var onChange: ((String) -> Void)?
    var onFocus: ((Bool) -> Void)?
    private(set) var secret = ""
    /// What VoiceOver says for the hidden secret instead of reading out bullets.
    var hiddenValue: (Int) -> String = { "\($0)" }
    var masked = true {
        didSet { if masked != oldValue { refresh(selection: NSRange(location: secret.utf16.count, length: 0)) } }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        autocorrectionType = .no
        autocapitalizationType = UITextAutocapitalizationType.none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        inlinePredictionType = .no
        if #available(iOS 18, *) { writingToolsBehavior = UIWritingToolsBehavior.none }
        inputView = UIView(frame: .zero)
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        delegate = self
        textDragInteraction?.isEnabled = false
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        dataDetectorTypes = []
        font = fieldFont
        adjustsFontForContentSizeCategory = true
        textColor = Palette.text
        tintColor = Palette.accent
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setSecret(_ s: String) {
        guard s != secret else { return }
        secret = s
        refresh(selection: NSRange(location: min(selectedRange.location, s.utf16.count), length: 0))
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { false }
    func textViewDidBeginEditing(_ textView: UITextView) { onFocus?(true) }
    func textViewDidEndEditing(_ textView: UITextView) { onFocus?(false) }
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? { UIMenu(children: []) }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    override func buildMenu(with builder: any UIMenuBuilder) { builder.remove(menu: .standardEdit) }

    // Every character is ASCII or a bullet, one UTF-16 unit each, so the view's offsets are the secret's.
    func keyperInsert(_ c: Character) { replace(selectedRange, with: String(c)) }

    func keyperDelete() {
        let range = selectedRange
        if range.length > 0 { replace(range, with: "") } else if range.location > 0 { replace(NSRange(location: range.location - 1, length: 1), with: "") }
    }

    private func replace(_ range: NSRange, with s: String) {
        secret = (secret as NSString).replacingCharacters(in: range, with: s)
        refresh(selection: NSRange(location: range.location + s.utf16.count, length: 0))
        onChange?(secret)
    }

    private func refresh(selection: NSRange) {
        text = masked ? String(repeating: "\u{2022}", count: secret.utf16.count) : secret
        selectedRange = selection
        accessibilityValue = masked && !secret.isEmpty ? hiddenValue(secret.utf16.count) : nil
    }
}

/// The field chrome of the Android app: a tinted box that turns white with a gold border on focus.
private struct FieldBox: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(focused ? Palette.surface : Palette.surfaceVariant)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(focused ? Palette.accent : Palette.surfaceVariant), lineWidth: focused ? 2 : 1))
    }
}

struct EmailField: UIViewRepresentable {
    @Bindable var model: KeyperModel

    func makeUIView(context: Context) -> KeyperTextField {
        let field = KeyperTextField()
        field.accessibilityIdentifier = "email"
        field.onChange = { model.email = $0 }
        field.onFocus = { [weak field] focused in
            if focused { model.focus(.email) } else { releaseFocus(field, .email, model) }
        }
        model.emailTarget = field
        return field
    }

    func updateUIView(_ field: KeyperTextField, context: Context) {
        if field.text != model.email { field.text = model.email }
        field.setPlaceholder(model.strings["email_hint"])
        field.isEnabled = !model.busy
        syncFocus(field) { model.focus == .email }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyperTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 200, height: uiView.intrinsicContentSize.height)
    }
}

struct SecretField: UIViewRepresentable {
    @Bindable var model: KeyperModel

    func makeUIView(context: Context) -> KeyperTextView {
        let view = KeyperTextView()
        view.accessibilityIdentifier = "secret"
        view.onChange = { model.secret = $0 }
        view.onFocus = { [weak view] focused in
            if focused { model.focus(.secret) } else { releaseFocus(view, .secret, model) }
        }
        model.secretTarget = view
        return view
    }

    func updateUIView(_ view: KeyperTextView, context: Context) {
        let strings = model.strings
        view.hiddenValue = { strings.format("secret_hidden_value", $0) }
        view.setSecret(model.secret)
        view.masked = !model.revealed
        let enabled = model.offline && !model.busy
        view.isEditable = enabled
        view.isSelectable = enabled
        syncFocus(view) { model.focus == .secret }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyperTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 300
        let lines = uiView.font!.lineHeight * 3 // at least three lines, as on Android
        return CGSize(width: width, height: max(lines, uiView.sizeThatFits(CGSize(width: width, height: .infinity)).height))
    }
}

/// The model's focus drives the first responder; a tap on a field reports back through onFocus.
/// Checked again when it runs, since a tap may have moved the focus in between.
@MainActor
private func syncFocus(_ view: UIView, _ wanted: @escaping @MainActor () -> Bool) {
    guard wanted() != view.isFirstResponder else { return }
    DispatchQueue.main.async {
        let focused = wanted()
        if focused && !view.isFirstResponder { view.becomeFirstResponder() } else if !focused && view.isFirstResponder { view.resignFirstResponder() }
    }
}

/// A field losing focus to the other one must not close the keyboard in between: UIKit ends the
/// old field's editing before it begins the new one's.
@MainActor
private func releaseFocus(_ view: UIView?, _ field: KeyperModel.Field, _ model: KeyperModel) {
    DispatchQueue.main.async {
        if view?.isFirstResponder != true && model.focus == field { model.focus = nil }
    }
}

extension View {
    func fieldBox(focused: Bool) -> some View { modifier(FieldBox(focused: focused)) }
}
