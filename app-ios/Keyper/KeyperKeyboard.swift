import KeyperCore
import SwiftUI
import UIKit

/// Keyper's own keyboard, for the email and the secret alike, so that no system keyboard ever sees
/// either. It offers exactly the protocol's characters (`Keyper.isSecretChar`) and a space, in a
/// fixed QWERTY layout with fixed sizes and a monospace face: it looks the same on every phone, and
/// `0`/`O` or `1`/`l`/`I` cannot be confused. The same keyboard as the Android app's.
///
/// Touch works as on the iPhone: every point of the keyboard belongs to its nearest key, so a tap
/// between keys still types one; the key under the finger shows magnified above it, and types when
/// the finger lifts, so a finger that landed wrong can slide to the right key first. A second
/// finger landing types the first one's key at once, so fast two-thumb typing keeps its order.
final class KeyperKeyboardView: UIView {
    /// The email gets `@` and `.` on the letter layer and a "next" key; the keys are otherwise the same.
    enum Mode { case secret, email }

    struct Labels: Equatable {
        var space = "space", done = "Done", next = "Next", shift = "Shift", delete = "Delete"
    }

    var onKey: (Character) -> Void = { _ in }
    var onDelete: () -> Void = {}
    var onDone: () -> Void = {}

    var mode = Mode.secret {
        didSet {
            guard mode != oldValue else { return }
            applyLabels()
            setNeedsLayout()
        }
    }

    var labels = Labels() {
        didSet { if labels != oldValue { applyLabels() } }
    }

    static let height = padding.top * 2 + 4 * (keyHeight + 2 * margin.height)

    private enum Shift { case off, once, locked }

    /// Character keys, space and done type on lift and follow a sliding finger (`slides`); shift,
    /// delete and the layer switch act the moment they go down, and `up` only ends a hold.
    private final class Key {
        let cap: KeyCap
        let slides: Bool
        let bubble: Bool
        var down: () -> Void = {}
        var up: () -> Void = {}

        init(_ cap: KeyCap, slides: Bool, bubble: Bool) {
            self.cap = cap
            self.slides = slides
            self.bubble = bubble
        }
    }

    private enum Item {
        case key(Key, CGFloat)
        case spacer(CGFloat)
    }

    private var keys: [Key] = []
    private var letterRows: [[Item]] = []
    private var symbolRows: [[Item]] = []
    private var bottomRow: [Item] = []
    private var letterKeys: [(Key, Character)] = []
    private var emailKeys: [Key] = []
    private var symbolsShown = false
    private var shift = Shift.off
    private var lastShiftTap: CFTimeInterval = 0
    private var pressed: [AnyHashable: Key] = [:]
    private var repeatTimer: Timer?
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let bubble = Bubble()
    private var bubbleKey: Key?

    private var shiftKey: Key!
    private var layerKey: Key!
    private var spaceKey: Key!
    private var doneKey: Key!
    private var deleteKeys: [Key] = []

    init() {
        super.init(frame: .zero)
        backgroundColor = Palette.surfaceVariant
        isMultipleTouchEnabled = true
        clipsToBounds = false // the magnified key rises above the keyboard
        letterRows = [
            "qwertyuiop".map { .key(letterKey($0), 1) },
            [.spacer(0.5)] + "asdfghjkl".map { .key(letterKey($0), 1) } + [.spacer(0.5)],
            [.key(makeShiftKey(), 1.5)] + "zxcvbnm".map { .key(letterKey($0), 1) } + [.key(makeDeleteKey(), 1.5)],
        ]
        symbolRows = [
            KeyperKeyboardView.digits.map { .key(charKey($0), 1) },
            KeyperKeyboardView.symbols1.map { .key(charKey($0), 1) },
            KeyperKeyboardView.symbols2.map { .key(charKey($0), 1) } + [.key(makeDeleteKey(), 2)],
        ]
        bottomRow = [.key(makeLayerKey(), 1.5), .key(emailKey("@"), 1), .key(makeSpaceKey(), 6), .key(emailKey("."), 1), .key(makeDoneKey(), 2.5)]
        precondition(Set(KeyperKeyboardView.digits + KeyperKeyboardView.symbols1 + KeyperKeyboardView.symbols2).subtracting("0123456789") == Set(Keyper.secretSymbols))
        layer.addSublayer(bubble)
        applyLabels()
        refreshShift()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: CGSize { CGSize(width: UIView.noIntrinsicMetric, height: KeyperKeyboardView.height) }

    /// Back to lowercase letters, as when the keyboard first opens on a field.
    func reset() {
        shift = .off
        showSymbols(false)
        refreshShift()
    }

    // MARK: Keys

    private func add(_ cap: KeyCap, slides: Bool, bubble: Bool) -> Key {
        let key = Key(cap, slides: slides, bubble: bubble)
        keys.append(key)
        addSubview(cap)
        return key
    }

    /// Types on lift. VoiceOver activates keys through `activate` instead of touches.
    private func typesOnLift(_ key: Key, _ action: @escaping () -> Void) -> Key {
        key.up = action
        key.cap.activate = action
        return key
    }

    private func actsOnDown(_ key: Key, _ action: @escaping () -> Void, release: @escaping () -> Void = {}) -> Key {
        key.down = action
        key.up = release
        key.cap.activate = {
            action()
            release()
        }
        return key
    }

    private func letterKey(_ c: Character) -> Key {
        let key = add(KeyCap(text: String(c), style: .normal, mono: true), slides: true, bubble: true)
        letterKeys.append((key, c))
        return typesOnLift(key) { [unowned self] in
            onKey(shift == .off ? c : Character(c.uppercased()))
            if shift == .once {
                shift = .off
                refreshShift()
            }
        }
    }

    private func charKey(_ c: Character) -> Key {
        typesOnLift(add(KeyCap(text: String(c), style: .normal, mono: true), slides: true, bubble: true)) { [unowned self] in onKey(c) }
    }

    private func emailKey(_ c: Character) -> Key {
        let key = charKey(c)
        emailKeys.append(key)
        return key
    }

    private func makeShiftKey() -> Key {
        shiftKey = actsOnDown(add(KeyCap(symbol: "shift", style: .special), slides: false, bubble: false), { [unowned self] in
            let now = CACurrentMediaTime()
            if shift == .once && now - lastShiftTap < KeyperKeyboardView.doubleTap {
                shift = .locked
            } else {
                shift = shift == .off ? .once : .off
            }
            lastShiftTap = now
            refreshShift()
        })
        return shiftKey
    }

    /// Holding the key keeps deleting.
    private func makeDeleteKey() -> Key {
        let key = actsOnDown(add(KeyCap(symbol: "delete.left", style: .special), slides: false, bubble: false), { [unowned self] in
            onDelete()
            repeatTimer?.invalidate()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyperKeyboardView.repeatDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.onDelete()
                    self.repeatTimer = Timer.scheduledTimer(withTimeInterval: KeyperKeyboardView.repeatInterval, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated { self?.onDelete() }
                    }
                }
            }
        }, release: { [unowned self] in
            repeatTimer?.invalidate()
            repeatTimer = nil
        })
        deleteKeys.append(key)
        return key
    }

    private func makeSpaceKey() -> Key {
        spaceKey = typesOnLift(add(KeyCap(text: "space", style: .normal, mono: false), slides: true, bubble: false)) { [unowned self] in onKey(" ") }
        spaceKey.cap.muted = true
        return spaceKey
    }

    private func makeLayerKey() -> Key {
        layerKey = actsOnDown(add(KeyCap(text: "123", style: .special, mono: false), slides: false, bubble: false), { [unowned self] in
            showSymbols(!symbolsShown)
        })
        return layerKey
    }

    private func makeDoneKey() -> Key {
        doneKey = typesOnLift(add(KeyCap(text: "Done", style: .active, mono: false), slides: true, bubble: false)) { [unowned self] in onDone() }
        return doneKey
    }

    private func showSymbols(_ show: Bool) {
        symbolsShown = show
        layerKey.cap.label.text = show ? "ABC" : "123"
        layerKey.cap.accessibilityLabel = layerKey.cap.label.text
        setNeedsLayout()
    }

    private func refreshShift() {
        for (key, c) in letterKeys {
            key.cap.label.text = shift == .off ? String(c) : c.uppercased()
            key.cap.accessibilityLabel = key.cap.label.text // VoiceOver reads the letter the key types
        }
        shiftKey.cap.setSymbol(shift == .off ? "shift" : shift == .once ? "shift.fill" : "capslock.fill")
        shiftKey.cap.style = shift == .off ? .special : .active
    }

    private func applyLabels() {
        spaceKey.cap.label.text = labels.space
        spaceKey.cap.accessibilityLabel = labels.space
        doneKey.cap.label.text = mode == .email ? labels.next : labels.done
        doneKey.cap.accessibilityLabel = doneKey.cap.label.text
        shiftKey.cap.accessibilityLabel = labels.shift
        for key in deleteKeys { key.cap.accessibilityLabel = labels.delete }
    }

    // MARK: Layout

    private var visibleRows: [[Item]] { (symbolsShown ? symbolRows : letterRows) + [bottomRow] }

    override func layoutSubviews() {
        super.layoutSubviews()
        for key in keys { key.cap.isHidden = true }
        let width = bounds.width - 2 * KeyperKeyboardView.padding.left
        var y = KeyperKeyboardView.padding.top
        for row in visibleRows {
            let items = row.filter {
                if case .key(let key, _) = $0, emailKeys.contains(where: { $0 === key }) { return mode == .email }
                return true
            }
            let total = items.reduce(CGFloat(0)) { sum, item in
                switch item {
                case .key(let key, let weight): sum + (key === spaceKey && mode == .email ? 4 : weight)
                case .spacer(let weight): sum + weight
                }
            }
            var x = KeyperKeyboardView.padding.left
            for item in items {
                switch item {
                case .key(let key, let weight):
                    let w = width * (key === spaceKey && mode == .email ? 4 : weight) / total
                    key.cap.frame = CGRect(x: x, y: y, width: w, height: KeyperKeyboardView.keyHeight + 2 * KeyperKeyboardView.margin.height)
                        .insetBy(dx: KeyperKeyboardView.margin.width, dy: KeyperKeyboardView.margin.height)
                    key.cap.isHidden = false
                    x += w
                case .spacer(let weight):
                    x += width * weight / total
                }
            }
            y += KeyperKeyboardView.keyHeight + 2 * KeyperKeyboardView.margin.height
        }
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { fingerDown(ObjectIdentifier(touch), at: touch.location(in: self)) }
        haptic.prepare()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { fingerMoved(ObjectIdentifier(touch), to: touch.location(in: self)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { fingerUp(ObjectIdentifier(touch)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { cancelAll() }

    // The touch rules, apart from UITouch so that tests can play several fingers.

    func fingerDown(_ finger: AnyHashable, at point: CGPoint) {
        typePending()
        guard let key = keyAt(point, slidingOnly: false) else { return }
        pressed[finger] = key
        haptic.impactOccurred()
        show(key)
        key.down()
    }

    func fingerMoved(_ finger: AnyHashable, to point: CGPoint) {
        guard let from = pressed[finger], from.slides, let to = keyAt(point, slidingOnly: true), to !== from else { return }
        hide(from)
        pressed[finger] = to
        show(to)
    }

    func fingerUp(_ finger: AnyHashable) {
        guard let key = pressed.removeValue(forKey: finger) else { return }
        hide(key)
        key.up()
    }

    /// The centre of the visible key labelled `label`, for tests.
    func center(of label: String) -> CGPoint? {
        layoutIfNeeded() // a layer switch lays the keys out on the next pass
        return keys.first { !$0.cap.isHidden && $0.cap.accessibilityLabel == label }.map { CGPoint(x: $0.cap.frame.midX, y: $0.cap.frame.midY) }
    }

    /// The nearest key: the gaps between keys and the keyboard's edges belong to keys too.
    private func keyAt(_ p: CGPoint, slidingOnly: Bool) -> Key? {
        keys.filter { !$0.cap.isHidden && ($0.slides || !slidingOnly) }.min { distance(p, $0.cap.frame) < distance(p, $1.cap.frame) }
    }

    private func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }

    /// A finger landing types the key another finger still holds, as if that one had lifted.
    private func typePending() {
        let pending = pressed.filter { $0.value.slides }
        for id in pending.keys { pressed.removeValue(forKey: id) }
        for key in pending.values {
            hide(key)
            key.up()
        }
    }

    func cancelAll() {
        let held = Array(pressed.values)
        pressed.removeAll()
        for key in held {
            hide(key)
            if !key.slides { key.up() }
        }
    }

    private func show(_ key: Key) {
        key.cap.isPressed = true
        if key.bubble {
            bubbleKey = key
            bubble.show(over: key.cap.frame, label: key.cap.label.text ?? "", within: bounds.width, traits: traitCollection)
        }
    }

    private func hide(_ key: Key) {
        key.cap.isPressed = false
        if bubbleKey === key {
            bubbleKey = nil
            bubble.hide()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelAll()
            repeatTimer?.invalidate()
        }
    }

    // MARK: Constants

    private static let digits = Array("1234567890")
    private static let symbols1 = Array("!@#$%^&*()")
    private static let symbols2 = Array(".,?-_+=/")
    static let keyHeight: CGFloat = 46
    static let margin = CGSize(width: 3, height: 4)
    static let padding = UIEdgeInsets(top: 6, left: 3, bottom: 6, right: 3)
    private static let doubleTap: CFTimeInterval = 0.4
    private static let repeatDelay: TimeInterval = 0.4
    private static let repeatInterval: TimeInterval = 0.06
}

/// One key: a rounded cap with a label or an SF Symbol. It changes colour the instant it goes down.
final class KeyCap: UIView {
    enum Style { case normal, special, active }

    let label = UILabel()
    private let icon = UIImageView()
    private let gradient = CAGradientLayer()
    var activate: () -> Void = {}

    var style: Style { didSet { refreshColors() } }
    var isPressed = false { didSet { if isPressed != oldValue { refreshColors() } } }
    /// The space bar's quiet label.
    var muted = false { didSet { refreshColors() } }

    init(text: String, style: Style, mono: Bool) {
        self.style = style
        super.init(frame: .zero)
        setUp()
        label.text = text
        // Fixed sizes, not Dynamic Type: the keyboard must not change with the system text size.
        label.font = mono ? .monospacedSystemFont(ofSize: 22, weight: .regular) : .systemFont(ofSize: 15, weight: .medium)
        accessibilityLabel = text
    }

    init(symbol: String, style: Style) {
        self.style = style
        super.init(frame: .zero)
        setUp()
        setSymbol(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setUp() {
        isUserInteractionEnabled = false // the keyboard tracks every touch itself
        layer.cornerRadius = 8
        layer.masksToBounds = true
        gradient.colors = [Palette.goldStart.cgColor, Palette.goldEnd.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        label.textAlignment = .center
        label.textColor = Palette.text
        addSubview(label)
        icon.contentMode = .center
        icon.tintColor = Palette.text
        addSubview(icon)
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        refreshColors()
    }

    func setSymbol(_ name: String) {
        icon.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        label.frame = bounds
        icon.frame = bounds
    }

    private func refreshColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true) // no fade: the pressed colour appears at once
        switch style {
        case .normal:
            backgroundColor = isPressed ? Palette.outline : Palette.surface
            gradient.isHidden = true
        case .special:
            backgroundColor = isPressed ? Palette.textTertiary : Palette.outline
            gradient.isHidden = true
        case .active:
            backgroundColor = Palette.goldEnd
            gradient.isHidden = isPressed
        }
        let ink = style == .active ? Palette.onGold : Palette.text
        label.textColor = muted ? Palette.textTertiary : ink
        icon.tintColor = ink
        CATransaction.commit()
    }

    override func accessibilityActivate() -> Bool {
        activate()
        return true
    }
}

/// The magnified key, shaped like the iPhone's: the key grows up into a wider head holding a large
/// copy of its character. The same geometry as the Android app's.
private final class Bubble: CALayer {
    private let shape = CAShapeLayer()
    private let text = CATextLayer()

    override init() {
        super.init()
        isHidden = true
        zPosition = 10
        shape.lineWidth = 1
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOpacity = 0.25
        shape.shadowRadius = 6
        shape.shadowOffset = CGSize(width: 0, height: 2)
        addSublayer(shape)
        text.alignmentMode = .center
        text.font = UIFont.monospacedSystemFont(ofSize: 34, weight: .regular)
        text.fontSize = 34
        addSublayer(text)
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Layers hold resolved colours: resolve them for the keyboard's own light or dark appearance.
    func show(over key: CGRect, label: String, within width: CGFloat, traits: UITraitCollection) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.fillColor = Palette.surface.resolvedColor(with: traits).cgColor
        shape.strokeColor = Palette.outline.resolvedColor(with: traits).cgColor
        text.foregroundColor = Palette.text.resolvedColor(with: traits).cgColor
        text.contentsScale = traits.displayScale
        let (l, t, r, b) = (key.minX, key.minY, key.maxX, key.maxY)
        let headWidth = max(key.width * 1.5, key.width + 16)
        let hl = min(max((l + r - headWidth) / 2, 2), width - 2 - headWidth)
        let hr = hl + headWidth
        let neckTop = t - 6
        let neckBottom = t + 10
        let ht = neckTop - key.height * 1.1
        let bend = (neckBottom - neckTop) / 2
        let rh: CGFloat = 12
        let rk: CGFloat = 8
        let path = UIBezierPath()
        path.move(to: CGPoint(x: l, y: b - rk))
        path.addLine(to: CGPoint(x: l, y: neckBottom))
        path.addCurve(to: CGPoint(x: hl, y: neckTop), controlPoint1: CGPoint(x: l, y: neckBottom - bend), controlPoint2: CGPoint(x: hl, y: neckTop + bend))
        path.addLine(to: CGPoint(x: hl, y: ht + rh))
        path.addQuadCurve(to: CGPoint(x: hl + rh, y: ht), controlPoint: CGPoint(x: hl, y: ht))
        path.addLine(to: CGPoint(x: hr - rh, y: ht))
        path.addQuadCurve(to: CGPoint(x: hr, y: ht + rh), controlPoint: CGPoint(x: hr, y: ht))
        path.addLine(to: CGPoint(x: hr, y: neckTop))
        path.addCurve(to: CGPoint(x: r, y: neckBottom), controlPoint1: CGPoint(x: hr, y: neckTop + bend), controlPoint2: CGPoint(x: r, y: neckBottom - bend))
        path.addLine(to: CGPoint(x: r, y: b - rk))
        path.addQuadCurve(to: CGPoint(x: r - rk, y: b), controlPoint: CGPoint(x: r, y: b))
        path.addLine(to: CGPoint(x: l + rk, y: b))
        path.addQuadCurve(to: CGPoint(x: l, y: b - rk), controlPoint: CGPoint(x: l, y: b))
        path.close()
        shape.path = path.cgPath
        shape.shadowPath = path.cgPath
        text.string = label
        let lineHeight: CGFloat = 42
        text.frame = CGRect(x: hl, y: (ht + neckTop - lineHeight) / 2, width: headWidth, height: lineHeight)
        isHidden = false
        CATransaction.commit()
    }

    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        isHidden = true
        CATransaction.commit()
    }
}

/// The keyboard in the SwiftUI screen, typing into whichever field the model has focused.
struct KeyboardBar: UIViewRepresentable {
    var model: KeyperModel

    final class Coordinator {
        var lastFocus: KeyperModel.Field?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> KeyperKeyboardView {
        let keyboard = KeyperKeyboardView()
        keyboard.accessibilityIdentifier = "keyboard"
        keyboard.onKey = { model.type($0) }
        keyboard.onDelete = { model.deleteBackward() }
        keyboard.onDone = { model.done() }
        return keyboard
    }

    func updateUIView(_ keyboard: KeyperKeyboardView, context: Context) {
        let s = model.strings
        keyboard.labels = .init(space: s["key_space"], done: s["key_done"], next: s["key_next"], shift: s["key_shift"], delete: s["key_delete"])
        keyboard.mode = model.focus == .email ? .email : .secret
        if model.focus != context.coordinator.lastFocus {
            context.coordinator.lastFocus = model.focus
            keyboard.reset()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyperKeyboardView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 390, height: KeyperKeyboardView.height)
    }
}
