import SwiftUI
import UIKit

@main
struct KeyperApp: App {
    @State private var model = KeyperModel()
    @Environment(\.scenePhase) private var phase

    init() {
        #if DEBUG
        DeviceBench.runIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppScreen(model: model, phase: phase)
                // While the keyboard is open, an upward swipe on the bottom row types instead of going
                // home: the first swipe from the edge is the app's, as Android keeps its back gesture
                // off the keyboard.
                .defersSystemGestures(on: model.focus != nil ? .bottom : [])
                .onChange(of: phase) { _, now in if now == .background { model.leave() } }
        }
    }
}

/// The shielded screen, covered whenever the scene is not active: the app switcher snapshots the
/// screen as the app goes inactive, and must find only the page colour.
struct AppScreen: View {
    let model: KeyperModel
    let phase: ScenePhase

    var body: some View {
        ShieldedScreen(model: model)
            .ignoresSafeArea() // the screen inside handles the safe area itself
            .overlay { if phase != .active { Color(Palette.background).ignoresSafeArea() } }
    }
}

/// The screen inside a layer that iOS leaves out of screenshots, screen recordings and mirroring,
/// the closest iOS comes to Android's FLAG_SECURE.
struct ShieldedScreen: UIViewControllerRepresentable {
    let model: KeyperModel

    func makeUIViewController(context: Context) -> ShieldController { ShieldController(model: model) }

    func updateUIViewController(_ controller: ShieldController, context: Context) {}
}

final class ShieldController: UIViewController {
    private let host: UIHostingController<MainView>

    init(model: KeyperModel) {
        host = UIHostingController(rootView: MainView(model: model))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background
        let shield = ScreenShield.make()
        shield.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shield)
        pin(shield, to: view)
        addChild(host)
        host.view.backgroundColor = Palette.background
        host.view.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(host.view)
        pin(host.view, to: shield)
        host.didMove(toParent: self)
        #if DEBUG
        let probe = PasteboardProbe(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        shield.addSubview(probe) // inside the shield: nothing may sit beside it
        #endif
    }

    private func pin(_ child: UIView, to parent: UIView) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }
}

#if DEBUG
/// UI tests: what the pasteboard holds, without its contents, which the test runner cannot read
/// without a paste prompt. An invisible element whose value is looked up each time it is read:
/// "hasStrings=<Bool> changeCount=<Int> keyperCopy=<Bool> otherApp=<Bool>": whether the pasteboard
/// holds Keyper's copy (its marker type), and the marker the test runner adds when it copies as
/// "another app". None of these reads the contents, so none raises the paste prompt.
final class PasteboardProbe: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityIdentifier = "pasteboard_state"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var accessibilityValue: String? {
        get {
            let board = UIPasteboard.general
            let keyperCopy = board.contains(pasteboardTypes: [KeyperModel.copyMarker])
            let otherApp = board.contains(pasteboardTypes: ["app.getkeyper.debug.other-app"])
            return "hasStrings=\(board.hasStrings) changeCount=\(board.changeCount) keyperCopy=\(keyperCopy) otherApp=\(otherApp)"
        }
        set {}
    }
}
#endif

/// The container iOS draws a secure text field's characters in is left out of every capture of the
/// screen. Content placed in it is too. iOS offers no public API for this, so if the container is
/// ever missing the screen still works, only without the protection.
@MainActor
enum ScreenShield {
    static func make() -> UIView {
        #if DEBUG
        // UI tests need screenshots of the screen they check.
        if ProcessInfo.processInfo.arguments.contains("-KeyperAllowScreenshots") { return UIView() }
        #endif
        let field = UITextField()
        field.isSecureTextEntry = true
        guard let container = field.subviews.first else { return UIView() }
        container.subviews.forEach { $0.removeFromSuperview() }
        container.isUserInteractionEnabled = true
        return container
    }
}
