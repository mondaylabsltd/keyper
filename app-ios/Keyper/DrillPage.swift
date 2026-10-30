import SwiftUI

/// The recovery drill, a page of its own: a title bar with Back, the email and the sentence typed
/// again from memory into empty fields, and Check. A match shows a passed state, whose button goes
/// back to the phrase; a mismatch stays here, with a line under the fields. Drawn by MainView, so it
/// is inside the screen shield, on Keyper's keyboard, and goes away with the phrase (going online,
/// leaving the app).
struct DrillPage: View {
    @Bindable var model: KeyperModel

    private var s: L10n { model.strings }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { model.focus = nil } // a tap beside the fields closes the keyboard
                }
                .scrollDismissesKeyboard(.never)
                .onChange(of: model.scrollTarget) { _, target in
                    guard let target, model.drilling else { return }
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .bottom) }
                    model.scrollTarget = nil
                }
            }
        }
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: nil) }
    }

    private var titleBar: some View {
        ZStack {
            Text(s["drill_title"])
                .keyperFont(17, .semibold)
                .foregroundStyle(Color(Palette.text))
                .lineLimit(1)
                .padding(.horizontal, 96)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("drill_title")
            HStack {
                Button { model.closeDrill() } label: {
                    Text(s["drill_back"]).keyperFont(17).foregroundStyle(Color(Palette.accent)).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s["drill_back"].trimmingCharacters(in: CharacterSet(charactersIn: "‹ ")))
                .accessibilityIdentifier("drill_back")
                .accessibilityAction(.escape) { model.closeDrill() }
                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(s["drill_intro"]).keyperFont(15).foregroundStyle(Color(Palette.textSecondary)).padding(.top, 4)
            if model.drillResult == .passed {
                passed.padding(.top, 20)
            } else {
                inputCard.padding(.top, 20)
                PrimaryButton(title: s["drill_check"], enabled: model.offline && !model.busy) { model.checkDrill() }
                    .accessibilityIdentifier("drill_check")
                    .padding(.top, 16)
            }
        }
    }

    private var inputCard: some View {
        Card {
            FieldLabel(text: s["email_label"])
            EmailField(model: model, field: .drillEmail)
                .fieldBox(focused: model.focus == .drillEmail)
                .padding(.top, 8)
                .id(KeyperModel.ScrollTarget.field(.drillEmail))
            SecretLabel(title: s["secret_label"], reveal: s[model.drillRevealed ? "hide" : "show"], id: "drill_reveal") { model.drillRevealed.toggle() }
                .padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                SecretInput(model: model, field: .drillSecret)
                if model.drillResult == .mismatch {
                    ErrorText(text: s["drill_mismatch"]).accessibilityIdentifier("drill_mismatch")
                }
            }
            .id(KeyperModel.ScrollTarget.field(.drillSecret))
        }
    }

    private var passed: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(Palette.levelStrong))
                    .accessibilityHidden(true)
                Text(s["drill_passed"])
                    .keyperFont(16, .medium)
                    .foregroundStyle(Color(Palette.text))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
                    .accessibilityIdentifier("drill_passed")
            }
            PrimaryButton(title: s["drill_return"], enabled: true) { model.closeDrill() }
                .accessibilityIdentifier("drill_return")
                .padding(.top, 16)
        }
        .accessibilityElement(children: .contain)
    }
}
