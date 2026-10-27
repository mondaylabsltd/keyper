import KeyperCore
import SwiftUI

/// Keyper's single screen, laid out as the Android app's: the offline gate, both inputs on Keyper's
/// keyboard, the strength estimate, the derivation's progress, the phrase and the recovery drill.
struct MainView: View {
    @Bindable var model: KeyperModel

    private var s: L10n { model.strings }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                GeometryReader { geo in
                    ScrollView {
                        content
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 24)
                            .frame(minHeight: geo.size.height, alignment: .top)
                            .contentShape(Rectangle())
                            .onTapGesture { model.focus = nil } // a tap beside the fields closes the keyboard
                    }
                    .scrollDismissesKeyboard(.never)
                    .onChange(of: model.scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeOut(duration: 0.25)) {
                            // The result and the header go to the top, as on Android; a field just above the keyboard.
                            proxy.scrollTo(target, anchor: target == .top || target == .result ? .top : .bottom)
                        }
                        model.scrollTarget = nil
                    }
                }
            }
            if model.focus != nil {
                KeyboardBar(model: model)
                    .frame(height: KeyperKeyboardView.height)
                    .transition(.move(edge: .bottom))
                    .zIndex(1) // the magnified key rises over the page
            }
        }
        .background(alignment: .bottom) {
            // The keyboard's colour runs on under the home indicator.
            if model.focus != nil { Color(Palette.surfaceVariant).frame(height: 80).ignoresSafeArea(edges: .bottom) }
        }
        .background(Color(Palette.background).ignoresSafeArea())
        // An opaque status bar, as on Android: the page scrolls beneath it, not through the clock.
        .overlay(alignment: .top) {
            GeometryReader { geo in
                Color(Palette.background).frame(height: geo.safeAreaInsets.top).ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.2), value: model.focus == nil)
        .overlay(alignment: .bottom) { toast }
        .overlay { if model.showingQr, let phrase = model.phrase { QrScreen(text: phrase.joined(separator: " "), caption: s["qr_caption"]) { model.showingQr = false } } }
        // Overlays like the QR code, not .alert: they stay inside the screen shield.
        .overlay {
            if let estimate = model.weakWarning {
                Dialog(
                    id: "weak_dialog",
                    title: s["weak_title"],
                    message: s.format("weak_message", s.duration(estimate.crackSeconds(gpus: 1000)), s.money(estimate.crackDollars())),
                    actions: [.init(title: s["weak_edit"]) { model.weakWarning = nil }, .init(title: s["weak_continue"]) { model.generateAnyway() }],
                    cancel: { model.weakWarning = nil }
                )
            }
        }
        .overlay {
            if let message = model.errorMessage {
                Dialog(id: "error_dialog", message: message, actions: [.init(title: s["ok"]) { model.errorMessage = nil }], cancel: { model.errorMessage = nil })
            }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.id(KeyperModel.ScrollTarget.top)
            if model.isTestBuild { banner(s["test_build"]).padding(.top, 16) }
            if !model.offline { offlineCard.padding(.top, 20) }
            if model.drilling { drillBanner.padding(.top, 20) }
            inputCard.padding(.top, 20)
            WordCountPicker(words: $model.words, labels: (s["words_12"], s["words_24"])).padding(.top, 16)
            PrimaryButton(title: s[model.drilling ? "drill_check" : "generate"], enabled: model.offline && !model.busy) { model.generate() }
                .accessibilityIdentifier("generate")
                .padding(.top, 12)
            if model.busy { progressCard.padding(.top, 12) }
            if model.showsResult, let phrase = model.phrase { resultCard(phrase).padding(.top, 16).id(KeyperModel.ScrollTarget.result) }
            Spacer(minLength: 24)
            Text(s.format("footer", model.domainId))
                .keyperFont(11)
                .foregroundStyle(Color(Palette.textTertiary))
                .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Logo()
            Text("Keyper").keyperFont(28, .medium).foregroundStyle(Color(Palette.text))
            Spacer()
            Button { model.language = model.language.other } label: {
                Text(s["language_switch"])
                    .keyperFont(13)
                    .foregroundStyle(Color(Palette.text))
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Color(Palette.surface)))
                    .overlay(Capsule().strokeBorder(Color(Palette.outline), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("language")
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .keyperFont(13)
            .foregroundStyle(Color(Palette.danger))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(Palette.dangerSoft)))
    }

    /// Shown only while the phone is online. iOS lets no app open those settings, so the steps are
    /// instructions rather than links; Bluetooth cannot be read without a permission, so it is a reminder.
    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s["offline_needed"]).keyperFont(14, .medium).foregroundStyle(Color(Palette.danger))
            if model.radios.cellular { offlineStep(s["offline_airplane"]) }
            if model.radios.wifi { offlineStep(s["offline_wifi"]) }
            if model.radios.otherNetwork { offlineStep(s["offline_network"]) }
            Text(s["offline_bluetooth"])
                .keyperFont(12)
                .foregroundStyle(Color(Palette.textSecondary))
                .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(Palette.dangerSoft)))
        .accessibilityIdentifier("offline_card")
    }

    private func offlineStep(_ text: String) -> some View {
        Text(text).keyperFont(15, .medium).foregroundStyle(Color(Palette.text)).padding(.vertical, 8).padding(.top, 2)
    }

    private var drillBanner: some View {
        HStack(spacing: 0) {
            Text(s["drill_banner"]).keyperFont(14).foregroundStyle(Color(Palette.text)).padding(.vertical, 12)
            Spacer(minLength: 8)
            TextLink(title: s["drill_exit"]) { model.endDrill(passed: false) }.frame(minHeight: 44).padding(.horizontal, 14)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(Palette.accentSoft)))
    }

    private var inputCard: some View {
        Card {
            label(s["email_label"])
            EmailField(model: model)
                .fieldBox(focused: model.focus == .email)
                .padding(.top, 8)
                .id(KeyperModel.ScrollTarget.field(.email))
            if let error = model.emailError { errorText(error) }
            HStack {
                label(s["secret_label"])
                Spacer()
                TextLink(title: s[model.revealed ? "hide" : "show"]) { model.revealed.toggle() }
                    .frame(minHeight: 32)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("reveal")
            }
            .padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    SecretField(model: model)
                    if model.secret.isEmpty {
                        Text(s[model.offline ? "secret_hint" : "secret_hint_offline"])
                            .keyperFont(16, design: .monospaced)
                            .foregroundStyle(Color(Palette.textTertiary))
                            .allowsHitTesting(false)
                    }
                }
                .fieldBox(focused: model.focus == .secret)
                // Unlike the email, the secret counts every capital, symbol and space between words.
                Text(s["secret_rule"]).keyperFont(12).foregroundStyle(Color(Palette.textTertiary)).lineSpacing(2).padding(.top, 6)
                if let error = model.secretError { errorText(error) }
                if let strength = model.strength { strengthBlock(strength) }
            }
            .id(KeyperModel.ScrollTarget.field(.secret))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).keyperFont(14, .medium).foregroundStyle(Color(Palette.text))
    }

    private func errorText(_ text: String) -> some View {
        Text(text).keyperFont(12).foregroundStyle(Color(Palette.danger)).padding(.top, 6)
    }

    private func strengthBlock(_ estimate: Strength) -> some View {
        let (label, color): (String, UIColor) = switch estimate.level {
        case .veryWeak: ("level_very_weak", Palette.levelVeryWeak)
        case .weak: ("level_weak", Palette.levelWeak)
        case .good: ("level_good", Palette.levelGood)
        case .strong: ("level_strong", Palette.levelStrong)
        }
        let length = model.secretLength
        let short = length < Keyper.minSecretLength
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Color(i <= estimate.level.rawValue ? color : Palette.outline)).frame(height: 4)
                }
            }
            .padding(.top, 12)
            // Characters exactly as the 12-character rule counts them; bits mean nothing to most people.
            Text(short ? s.format("secret_too_short", length, Keyper.minSecretLength) : s.format("strength_summary", s[label], length))
                .keyperFont(13, .medium)
                .foregroundStyle(Color(short ? Palette.danger : color))
                .padding(.top, 8)
                .accessibilityIdentifier("strength")
            Text(s.format("crack_time", s.duration(estimate.crackSeconds(gpus: 1000)), s.money(estimate.crackDollars())))
                .keyperFont(12)
                .foregroundStyle(Color(Palette.textSecondary))
                .lineSpacing(2)
                .padding(.top, 2)
                .accessibilityIdentifier("crack_time")
            if estimate.level < .good {
                Text(s["strength_tip"]).keyperFont(12).foregroundStyle(Color(Palette.textTertiary)).lineSpacing(2).padding(.top, 6)
            }
        }
    }

    private var progressCard: some View {
        let (done, total, elapsed) = model.progress
        let fraction = Double(done) / Double(total)
        return Card {
            HStack {
                Text(s.format("working", Int(fraction * 100))).keyperFont(15, .medium).foregroundStyle(Color(Palette.text))
                Spacer()
                TextLink(title: s["cancel"]) { model.stopDerivation() }.frame(minHeight: 36).padding(.horizontal, 10)
            }
            GoldProgress(fraction: fraction).padding(.top, 10)
            // The time left only once a few percent give a steady rate.
            Text(fraction < 0.03 ? s["working_detail_start"] : s.format("working_detail", s.duration(elapsed * (1 / fraction - 1))))
                .keyperFont(12)
                .foregroundStyle(Color(Palette.textSecondary))
                .padding(.top, 10)
        }
    }

    private func resultCard(_ phrase: [String]) -> some View {
        Card {
            label(s["result_title"])
            WordGrid(words: phrase).padding(.top, 12).accessibilityIdentifier("words")
            HStack(spacing: 8) {
                TonalButton(title: s["copy"]) { model.copyPhrase() }
                TonalButton(title: s["qr"]) { model.showingQr = true }
                TonalButton(title: s["clear"]) { model.clearSecret() }
            }
            .padding(.top, 14)
            TextLink(title: s["drill_start"], size: 13) { model.startDrill() }
                .padding(.vertical, 8)
                .padding(.top, 8)
        }
    }

    @ViewBuilder private var toast: some View {
        if let text = model.toast {
            Text(text)
                .keyperFont(14)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .padding(.bottom, model.focus != nil ? KeyperKeyboardView.height + 16 : 48)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }
}

/// The QR code, full screen on white at full brightness; a tap anywhere closes it.
struct QrScreen: View {
    let text: String
    let caption: String
    let close: () -> Void
    @State private var brightness: CGFloat?

    var body: some View {
        VStack(spacing: 20) {
            QrSymbol(code: QrCode.encode(text))
            Text(caption).keyperFont(14).foregroundStyle(Color(white: 0.27))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: close)
        .onAppear {
            brightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1
        }
        .onDisappear { if let brightness { UIScreen.main.brightness = brightness } }
        .accessibilityIdentifier("qr_screen")
    }
}
