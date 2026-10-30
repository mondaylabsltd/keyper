import KeyperCore
import SwiftUI
import Testing
import UIKit
@testable import Keyper

extension KeyperClaims {
    /// Claim 4, "No screenshots": the whole screen, dialogs and the QR code included, is drawn inside
    /// the container iOS uses for a secure text field's characters, which the render server leaves
    /// out of every capture.
    ///
    /// On the simulator, `drawHierarchy` takes its picture through the render server and honours the
    /// shield just as a screenshot on a phone does; `layer.render(in:)` draws the layers itself and
    /// ignores it, which shows what the shield hides. (XCUIScreen screenshots on the simulator ignore
    /// the shield; the phone-only UI test testScreenShieldHidesTheScreen covers real screenshots.)
    @MainActor @Suite
    struct ScreenShieldTests {
        /// Fails as soon as an iOS release stops giving secure text fields this container, or stops
        /// excluding it from captures: the app would then run unshielded.
        @Test func theSecureContainerStillExists() {
            let shield = ScreenShield.make()
            #expect(type(of: shield) != UIView.self, "iOS no longer offers a secure text field's container: the screen shield is off")
            let mask = shield.layer.value(forKey: "disableUpdateMask") as? Int ?? 0
            #expect(mask != 0, "the container's layer is no longer left out of captures (disableUpdateMask \(mask))")
        }

        /// The app as it runs (the test host): one ShieldController, whose only subview is the shield,
        /// with the SwiftUI screen inside it and nothing presented over it.
        @Test func theRunningScreenIsInsideTheShield() throws {
            let window = try #require(hostScene.windows.first { $0.isKeyWindow } ?? hostScene.windows.first)
            let shielded = try #require(Self.shieldController(in: window), "no ShieldController in the app's window")
            #expect(shielded.view.subviews.count == 1, "something sits beside the shield")
            let shield = try #require(shielded.view.subviews.first)
            #expect(shield.layer.value(forKey: "disableUpdateMask") as? Int ?? 0 != 0)
            let screen = try #require(shielded.children.first { $0 is UIHostingController<MainView> })
            #expect(screen.view.isDescendant(of: shield))
            #expect(shielded.presentedViewController == nil)
        }

        /// A capture of the running app's window shows the page colour and nothing else.
        @Test func aCaptureOfTheRunningAppIsBlank() throws {
            let window = try #require(hostScene.windows.first { $0.isKeyWindow } ?? hostScene.windows.first)
            #expect(variedShare(Self.capture(window)) < 0.001, "the screen shows in a capture")
            #expect(variedShare(Self.layers(window)) > 0.01, "the control drew nothing: the check proves nothing")
        }

        /// The weak-sentence dialog, the error dialog, the copy warning, the QR code and the recovery
        /// drill's page (with Keyper's keyboard open on it, and in its passed state) are drawn inside
        /// the shield, not as alerts, sheets or windows of their own: each is there in the layers, and
        /// absent from a capture.
        @Test(arguments: ["weak_dialog", "error_dialog", "copy_warning", "qr_screen", "drill_page", "drill_passed"])
        func dialogsAndTheQrCodeAreInsideTheShield(overlay: String) async throws {
            let h = Harness()
            h.generated()
            let window = UIWindow(windowScene: hostScene)
            window.frame = hostScene.screen.bounds
            window.rootViewController = ShieldController(model: h.model)
            window.isHidden = false
            defer { window.isHidden = true }
            try await spin(1)
            let without = Self.layers(window)
            let windowsBefore = Set(hostScene.windows.filter { !$0.isHidden }.map(ObjectIdentifier.init))

            switch overlay {
            case "weak_dialog": h.model.weakWarning = Strength.of("my cat is called mimi")
            case "error_dialog": h.model.errorMessage = "Something went wrong"
            case "copy_warning": h.model.requestCopy()
            case "drill_page":
                h.model.startDrill()
                h.model.drillEmail = Harness.email
            case "drill_passed":
                h.model.startDrill()
                h.model.drillEmail = Harness.email
                h.model.drillSecret = Harness.sentence
                h.model.checkDrill()
            default: h.model.showingQr = true
            }
            try await spin(1)
            let with = Self.layers(window)

            if overlay == "drill_page" { #expect(h.model.drilling && h.model.focus == .drillEmail, "the drill page and its keyboard did not open") }
            if overlay == "drill_passed" { #expect(h.model.drillResult == .passed) }
            #expect(Self.differingShare(without, with) > 0.05, "\(overlay) did not appear: the check proves nothing")
            #expect(window.rootViewController?.presentedViewController == nil, "\(overlay) is presented outside the shield")
            let opened = hostScene.windows.filter { !$0.isHidden && !windowsBefore.contains(ObjectIdentifier($0)) }
            // UIKit's own window for the text cursor, made the first time any field in the process
            // takes the focus (the drill page focuses its email), may appear; it must draw nothing.
            let effects = opened.filter { String(describing: type(of: $0)) == "UITextEffectsWindow" }
            for effect in effects { #expect(variedShare(Self.layers(effect)) < 0.001, "\(overlay): UIKit's text effects window draws something") }
            #expect(opened.count == effects.count, "\(overlay) opened a window of its own: \(opened.map { String(describing: type(of: $0)) })")
            #expect(variedShare(Self.capture(window)) < 0.001, "\(overlay) shows in a capture")

            // The control: the same screen without the shield shows in a capture.
            let open = UIWindow(windowScene: hostScene)
            open.frame = hostScene.screen.bounds
            open.rootViewController = UIHostingController(rootView: MainView(model: h.model))
            open.isHidden = false
            defer { open.isHidden = true }
            try await spin(1)
            #expect(variedShare(Self.capture(open)) > 0.01, "an unshielded capture is blank too: the check proves nothing")
        }

        /// Claim 3 too: while the scene is not active (as the app switcher snapshots it), the screen
        /// is covered with the page colour, the drill page included; the layers themselves, which
        /// ignore the shield, show nothing.
        @Test(arguments: [false, true])
        func theAppSwitcherSnapshotIsCovered(drilling: Bool) async throws {
            let h = Harness()
            h.generated()
            if drilling {
                h.model.startDrill()
                h.model.drillEmail = Harness.email
            }
            func render(_ phase: ScenePhase) async throws -> UIImage {
                let window = UIWindow(windowScene: hostScene)
                window.frame = hostScene.screen.bounds
                window.rootViewController = UIHostingController(rootView: AppScreen(model: h.model, phase: phase))
                window.isHidden = false
                defer { window.isHidden = true }
                try await spin(1)
                return Self.layers(window)
            }
            #expect(variedShare(try await render(.active)) > 0.01, "the active screen drew nothing: the check proves nothing")
            #expect(variedShare(try await render(.inactive)) < 0.001, "the app switcher would see the screen (inactive)")
            #expect(variedShare(try await render(.background)) < 0.001, "the app switcher would see the screen (background)")
        }

        /// Going online, leaving the app or Clear all from the drill page: the page is gone at once,
        /// with no exit animation keeping it on screen, and no field left in the window (the main
        /// page's, which lay under the drill page, included) holds the sentence or the drill's
        /// typing. Checked right after the window's next layout pass, with no time for an animation;
        /// Back, the control, slides out, and is still there at that point.
        @Test(arguments: ["online", "leave", "clearAll", "back"])
        func nothingSensitiveRemainsInTheViews(how: String) async throws {
            let h = Harness()
            h.generated()
            let window = UIWindow(windowScene: hostScene)
            window.frame = hostScene.screen.bounds
            window.rootViewController = ShieldController(model: h.model)
            window.isHidden = false
            defer { window.isHidden = true }
            h.model.revealed = true
            try await spin(1)
            h.model.startDrill()
            try await spin(1)
            h.type(Harness.email, into: .drillEmail) // into the page's own fields, now the model's targets
            h.type("In 2009 Grandma", into: .drillSecret)
            try await spin(0.5)
            let typed = Self.fields(in: window)
            #expect(typed.contains { $0.id == "drill_secret" && $0.text == "In 2009 Grandma" } && typed.contains { $0.id == "secret" && $0.text == Harness.sentence },
                    "the drill page's field holds nothing: the check proves nothing (\(typed))")

            switch how {
            case "online": h.goOnline()
            case "leave": h.model.leave()
            case "clearAll": h.model.clearAll()
            default: h.model.closeDrill() // Back
            }
            window.layoutIfNeeded() // SwiftUI applies the change in this pass; no animation time passes

            let left = Self.fields(in: window)
            if how == "back" {
                // The control: an animated exit is still on screen at this point, so the check sees one.
                #expect(left.contains { $0.id == "drill_email" }, "Back left at once: this check could not see an exit animation")
                #expect(h.model.showsResult, "Back keeps the phrase")
                try await spin(1)
                #expect(!Self.fields(in: window).contains { $0.id.hasPrefix("drill_") }, "Back never finished")
                return
            }
            #expect(!left.contains { $0.id.hasPrefix("drill_") }, "the drill page is still in the window after \(how): \(left.map(\.id))")
            for field in left where field.id != "email" || how == "clearAll" {
                #expect(field.text.isEmpty, "\(field.id) still holds \(field.text.count) characters after \(how)")
            }
            if how != "clearAll" { #expect(left.first { $0.id == "email" }?.text == Harness.email, "the email is kept, by design") }
            #expect(h.model.phrase == nil && !h.model.drilling)
        }

        // MARK: Helpers

        /// Every Keyper field in the window, by accessibility identifier, with what it holds.
        private static func fields(in window: UIWindow) -> [(id: String, text: String)] {
            var out = [(id: String, text: String)]()
            var views: [UIView] = [window]
            while let view = views.popLast() {
                if let field = view as? KeyperTextField { out.append((field.accessibilityIdentifier ?? "", field.text ?? "")) }
                if let text = view as? KeyperTextView { out.append((text.accessibilityIdentifier ?? "", text.secret)) }
                views += view.subviews
            }
            return out
        }

        private static func shieldController(in window: UIWindow) -> ShieldController? {
            var controllers = [window.rootViewController].compactMap { $0 }
            while let controller = controllers.popLast() {
                if let found = controller as? ShieldController { return found }
                controllers += controller.children
            }
            return nil
        }

        private static var format: UIGraphicsImageRendererFormat {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }

        /// A capture through the render server, as a screenshot is taken.
        private static func capture(_ window: UIWindow) -> UIImage {
            UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
        }

        /// The layers drawn in process, shield ignored.
        private static func layers(_ window: UIWindow) -> UIImage {
            UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
                window.layer.render(in: context.cgContext)
            }
        }

        private static func differingShare(_ a: UIImage, _ b: UIImage) -> Double {
            func pixels(_ image: UIImage) -> [UInt8] {
                let cg = image.cgImage!
                var out = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
                let context = CGContext(data: &out, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                return out
            }
            let (pa, pb) = (pixels(a), pixels(b))
            guard pa.count == pb.count else { return 1 }
            var differ = 0
            for i in stride(from: 0, to: pa.count, by: 4) {
                let d: Int = abs(Int(pa[i]) - Int(pb[i])) + abs(Int(pa[i + 1]) - Int(pb[i + 1])) + abs(Int(pa[i + 2]) - Int(pb[i + 2]))
                if d > 24 { differ += 1 }
            }
            return Double(differ) / Double(pa.count / 4)
        }
    }
}
