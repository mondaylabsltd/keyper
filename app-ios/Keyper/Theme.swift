import SwiftUI
import UIKit

/// The warm gold palette, the same values as the Android app's colors.xml, light and dark.
enum Palette {
    static let background = color(0xFBF8F3, 0x14110D)
    static let surface = color(0xFFFFFF, 0x1E1A15)
    static let surfaceVariant = color(0xF5EFE5, 0x2A241C)
    static let outline = color(0xE9E0D1, 0x3A3227)
    static let text = color(0x211B14, 0xF3EDE4)
    static let textSecondary = color(0x6B6153, 0xBFB5A6)
    static let textTertiary = color(0x9B907F, 0x8B8172)
    static let goldStart = color(0xFFCB45, 0xFFCB45)
    static let goldEnd = color(0xF6A400, 0xF6A400)
    static let onGold = color(0x2B1D00, 0x2B1D00)
    static let accent = color(0xA86400, 0xFFC14D)
    static let accentSoft = color(0xFBEFD6, 0x3A2D14)
    static let danger = color(0xC5221F, 0xF28B82)
    static let dangerSoft = color(0xFCE8E6, 0x3B1F1E)
    static let levelVeryWeak = color(0xD93025, 0xF28B82)
    static let levelWeak = color(0xE8710A, 0xFCAD70)
    static let levelGood = color(0xC08A00, 0xFDD663)
    static let levelStrong = color(0x188038, 0x81C995)

    private static func color(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
    }

    private static func rgb(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(_ ui: UIColor) { self.init(uiColor: ui) }
}

/// The gold gradient of the primary button and the logo, top left to bottom right.
let goldGradient = LinearGradient(colors: [Color(Palette.goldStart), Color(Palette.goldEnd)], startPoint: .topLeading, endPoint: .bottomTrailing)

/// Text sizes follow the Android app's sp values and scale with Dynamic Type, as sp scale with the font size.
struct KeyperFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(_ size: CGFloat, _ weight: Font.Weight, _ design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func keyperFont(_ size: CGFloat, _ weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(KeyperFont(size, weight, design))
    }
}
