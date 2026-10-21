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
            ShieldedScreen(model: model)
                .ignoresSafeArea() // the screen inside handles the safe area itself
                // The app switcher snapshots the screen as the app goes inactive: cover it first.
                .overlay { if phase != .active { Color(Palette.background).ignoresSafeArea() } }
                // While the keyboard is open, an upward swipe on the bottom row types instead of going
                // home: the first swipe from the edge is the app's, as Android keeps its back gesture
                // off the keyboard.
                .defersSystemGestures(on: model.focus != nil ? .bottom : [])
                .onChange(of: phase) { _, now in if now == .background { model.leave() } }
        }
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
