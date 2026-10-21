// Draws Keyper/Assets.xcassets/AppIcon.appiconset/AppIcon.png from the Android app's launcher icon:
// the ic_launcher_background gradient and the ic_key glyph, scaled so that the part of the 108-unit
// adaptive icon a launcher shows (the middle 72 units) fills the 1024-pixel square.
//
//     swift tools/make-icon.swift
import AppKit

let size = 1024
let scale = CGFloat(size) / 72
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1) // Android's coordinates: y grows downwards

func color(_ v: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
}

let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [color(0xFFD45C), color(0xF39200)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])

context.scaleBy(x: scale, y: scale)
context.translateBy(x: -18, y: -18)
// Shaft and teeth are unions; only the bow's hole is even-odd, so draw the bow and the rest apart.
for (dy, ink) in [(CGFloat(2.5), color(0xA35A00, alpha: 0.2)), (0, color(0xFFFFFF))] {
    context.setFillColor(ink)
    let bow = CGMutablePath()
    bow.addEllipse(in: CGRect(x: 23, y: 39 + dy, width: 30, height: 30))
    bow.addEllipse(in: CGRect(x: 32, y: 48 + dy, width: 12, height: 12))
    context.addPath(bow)
    context.fillPath(using: .evenOdd)
    let rest = CGMutablePath()
    rest.addRect(CGRect(x: 50, y: 50 + dy, width: 30, height: 8))
    rest.addEllipse(in: CGRect(x: 76, y: 50 + dy, width: 8, height: 8))
    rest.addPath(CGPath(roundedRect: CGRect(x: 66, y: 57 + dy, width: 6, height: 9), cornerWidth: 2, cornerHeight: 2, transform: nil))
    rest.addPath(CGPath(roundedRect: CGRect(x: 75, y: 57 + dy, width: 5, height: 7), cornerWidth: 2, cornerHeight: 2, transform: nil))
    context.addPath(rest)
    context.fillPath()
}

let out = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Keyper/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote", out.path)
