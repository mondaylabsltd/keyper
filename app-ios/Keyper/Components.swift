import KeyperCore
import SwiftUI
import UIKit

/// The key of the logo and the app icon, from the Android app's ic_key vector (108 × 108 units).
struct KeyGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // The bow: a ring around (38, 54), drawn even-odd.
        p.addEllipse(in: CGRect(x: 23, y: 39, width: 30, height: 30))
        p.addEllipse(in: CGRect(x: 32, y: 48, width: 12, height: 12))
        // The shaft with its rounded end, and two teeth.
        p.addRoundedRect(in: CGRect(x: 50, y: 50, width: 34, height: 8), cornerRadii: RectangleCornerRadii(bottomTrailing: 4, topTrailing: 4))
        p.addRoundedRect(in: CGRect(x: 66, y: 57, width: 6, height: 9), cornerRadii: RectangleCornerRadii(bottomLeading: 2, bottomTrailing: 2))
        p.addRoundedRect(in: CGRect(x: 75, y: 57, width: 5, height: 7), cornerRadii: RectangleCornerRadii(bottomLeading: 2, bottomTrailing: 2))
        let scale = min(rect.width, rect.height) / 108
        return p.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}

/// The 44-point logo: the white key on the gold gradient, with the key's soft drop shadow.
struct Logo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(goldGradient)
            KeyGlyph().offset(y: 44 * 2.5 / 108).fill(Color(red: 0xA3 / 255, green: 0x5A / 255, blue: 0).opacity(0.2), style: FillStyle(eoFill: true))
            KeyGlyph().fill(.white, style: FillStyle(eoFill: true))
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

/// A QR code with the standard four-module quiet zone, in whole points per module so no seams show.
struct QrSymbol: View {
    let code: QrCode

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let unit = floor(side / CGFloat(code.size + 8))
            let origin = CGPoint(x: (size.width - unit * CGFloat(code.size)) / 2, y: (size.height - unit * CGFloat(code.size)) / 2)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var dark = Path()
            for y in 0..<code.size {
                var x = 0
                while x < code.size {
                    guard code[x, y] else {
                        x += 1
                        continue
                    }
                    let start = x
                    while x < code.size && code[x, y] { x += 1 }
                    dark.addRect(CGRect(x: origin.x + CGFloat(start) * unit, y: origin.y + CGFloat(y) * unit, width: CGFloat(x - start) * unit, height: unit))
                }
            }
            context.fill(dark, with: .color(.black))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The phrase in two columns. Every word must show whole: if the widest cell does not fit its
/// column, all cells shrink alike, as on Android.
struct WordGrid: View {
    let words: [String]
    @ScaledMetric(relativeTo: .body) private var baseSize: CGFloat = 17
    @State private var width: CGFloat = 0
    private static let spacing: CGFloat = 6

    var body: some View {
        let size = fittedSize()
        // A plain grid, not a lazy one: every word exists even below the fold, for VoiceOver too.
        Grid(horizontalSpacing: WordGrid.spacing, verticalSpacing: WordGrid.spacing) {
            ForEach(0..<(words.count + 1) / 2, id: \.self) { row in
                GridRow {
                    ForEach(2 * row..<min(2 * row + 2, words.count), id: \.self) { i in cell(i, size) }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .combine)
    }

    private func cell(_ i: Int, _ size: CGFloat) -> some View {
        (Text(String(format: "%02d", i + 1)).foregroundStyle(Color(Palette.textTertiary)) + Text("\u{00A0}\u{00A0}" + words[i]).foregroundStyle(Color(Palette.text)))
            .font(.system(size: size, weight: .medium).monospacedDigit())
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(Palette.surfaceVariant)))
    }

    private func fittedSize() -> CGFloat {
        guard width > 0 else { return baseSize }
        let room = (width - WordGrid.spacing) / 2 - 22
        let font = UIFont.monospacedDigitSystemFont(ofSize: baseSize, weight: .medium)
        let widest = words.enumerated().map { i, word in
            (String(format: "%02d\u{00A0}\u{00A0}", i + 1) + word as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        let needed = widest / 0.96 // a little slack
        return needed > room ? baseSize * room / needed : baseSize
    }
}

/// The 12 / 24 words switch: a tinted track with a white, outlined selected segment.
struct WordCountPicker: View {
    @Binding var words: Int
    let labels: (String, String)

    var body: some View {
        HStack(spacing: 0) {
            segment(12, labels.0)
            segment(24, labels.1)
        }
        .padding(3)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(Palette.surfaceVariant)))
    }

    private func segment(_ n: Int, _ label: String) -> some View {
        Button { words = n } label: {
            Text(label)
                .keyperFont(14, .medium)
                .foregroundStyle(Color(words == n ? Palette.text : Palette.textSecondary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if words == n {
                        RoundedRectangle(cornerRadius: 10).fill(Color(Palette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(Palette.outline), lineWidth: 1))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(words == n ? .isSelected : [])
    }
}

/// The surface card with a hairline outline, as on Android.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(Palette.surface)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(Palette.outline), lineWidth: 1))
    }
}

/// Gold text buttons and links: no chrome, an accent label.
struct TextLink: View {
    let title: String
    var size: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).keyperFont(size).foregroundStyle(Color(Palette.accent)).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// An alert drawn inside the screen. SwiftUI's .alert is presented by UIKit in a window of its own,
/// outside the screen shield, where screenshots and recordings would see it. Laid out as the Android
/// app's AlertDialog: title, message, then text buttons at the trailing edge.
struct Dialog: View {
    struct Action {
        let title: String
        let run: () -> Void
    }

    /// For UI tests, which cannot find it among the alerts.
    let id: String
    var title: String?
    let message: String
    let actions: [Action]
    /// VoiceOver's escape gesture, as the cancel button of a system alert.
    let cancel: () -> Void

    var body: some View {
        ZStack {
            // The page beneath stays out of reach, as under a system alert; a tap outside does nothing.
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                if let title {
                    Text(title).keyperFont(20, .medium).foregroundStyle(Color(Palette.text)).padding(.bottom, 12).accessibilityAddTraits(.isHeader)
                }
                Text(message).keyperFont(15).foregroundStyle(Color(Palette.textSecondary)).lineSpacing(2)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(actions.indices, id: \.self) { i in
                        TextLink(title: actions[i].title, size: 15, action: actions[i].run).frame(minHeight: 44).padding(.horizontal, 12)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.top, 24)
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 360, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(Palette.surface)))
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
            .accessibilityAddTraits(.isModal) // VoiceOver reads only the dialog, as it would an alert
            .accessibilityAction(.escape, cancel)
        }
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: nil) }
    }
}

/// The tinted buttons under the phrase.
struct TonalButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .keyperFont(14, .medium)
                .foregroundStyle(Color(Palette.accent))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(Palette.accentSoft)))
        }
        .buttonStyle(PressedOpacity())
    }
}

/// The gold primary button; tinted grey while disabled.
struct PrimaryButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .keyperFont(16, .medium)
                .foregroundStyle(Color(enabled ? Palette.onGold : Palette.textTertiary))
                .frame(maxWidth: .infinity, minHeight: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14).fill(enabled ? AnyShapeStyle(goldGradient) : AnyShapeStyle(Color(Palette.surfaceVariant)))
                }
        }
        .buttonStyle(PressedOpacity())
        .disabled(!enabled)
    }
}

struct PressedOpacity: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// The gold progress bar of the derivation.
struct GoldProgress: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(Palette.surfaceVariant))
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [Color(Palette.goldStart), Color(Palette.goldEnd)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}
