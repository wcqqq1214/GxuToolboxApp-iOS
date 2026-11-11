import SwiftUI
import UIKit

public struct CourseTint: Sendable {
    public struct RGB: Sendable, Equatable {
        public var r: Double, g: Double, b: Double
        public init(r: Double, g: Double, b: Double) { (self.r, self.g, self.b) = (r, g, b) }
        init(hex: UInt32) {
            self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255)
        }
        func mixed(with other: RGB, _ amount: Double) -> RGB {
            RGB(r: r + (other.r - r) * amount, g: g + (other.g - g) * amount, b: b + (other.b - b) * amount)
        }
        var hsb: (h: Double, s: Double, b: Double) {
            var (h, sat, br): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
            uiColor.getHue(&h, saturation: &sat, brightness: &br, alpha: nil)
            return (Double(h), Double(sat), Double(br))
        }
        init(h: Double, s: Double, b: Double) {
            var (r, g, bl): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
            UIColor(hue: h, saturation: s, brightness: b, alpha: 1).getRed(&r, green: &g, blue: &bl, alpha: nil)
            self.init(r: Double(r), g: Double(g), b: Double(bl))
        }
        public var luminance: Double {
            func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }
        var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    }

    public struct Resolved: Sendable, Equatable {
        public var fill: RGB
        public var text: RGB
        public var marker: RGB
        public var contrast: Double { Self.contrast(fill, text) }
        static func contrast(_ a: RGB, _ b: RGB) -> Double {
            let (hi, lo) = (max(a.luminance, b.luminance), min(a.luminance, b.luminance))
            return (hi + 0.05) / (lo + 0.05)
        }
    }

    public let hex: UInt32
    public init(hex: UInt32) { self.hex = hex }

    private static let white = RGB(r: 1, g: 1, b: 1)
    private static let black = RGB(r: 0, g: 0, b: 0)

    public func resolved(dark: Bool) -> Resolved {
        let base = RGB(hex: hex)
        if dark { return resolvedDark(base) }
        var fillAmount = 0.55
        var textAmount = 0.72
        func make() -> Resolved {
            Resolved(
                fill: Self.white.mixed(with: base, fillAmount),
                text: base.mixed(with: Self.black, textAmount),
                marker: base.mixed(with: Self.black, 0.15)
            )
        }
        var result = make()
        for _ in 0..<20 where result.contrast < Self.minimumContrast {
            fillAmount = max(fillAmount - 0.04, 0)
            textAmount = min(textAmount + 0.04, 1)
            result = make()
        }
        return result
    }

    private func resolvedDark(_ base: RGB) -> Resolved {
        let (hue, sat, _) = base.hsb
        let isGray = sat < 0.05
        var fillBrightness = 0.36
        var textBrightness = 0.97
        func make() -> Resolved {
            let fillSat = isGray ? 0 : min(max(sat * 1.9, 0.42), 0.80)
            return Resolved(
                fill: RGB(h: hue, s: fillSat, b: fillBrightness),
                text: RGB(h: hue, s: isGray ? 0 : 0.14, b: textBrightness),
                marker: RGB(h: hue, s: isGray ? 0 : min(max(sat * 1.5, 0.40), 0.85), b: 0.92)
            )
        }
        var result = make()
        for _ in 0..<20 where result.contrast < Self.minimumContrast {
            fillBrightness = max(fillBrightness - 0.03, 0)
            textBrightness = min(textBrightness + 0.01, 1)
            result = make()
        }
        return result
    }

    static let minimumContrast = 4.5

    private func dynamic(_ keyPath: KeyPath<Resolved, RGB>) -> Color {
        let light = resolved(dark: false)[keyPath: keyPath].uiColor
        let dark = resolved(dark: true)[keyPath: keyPath].uiColor
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    public var fill: Color { dynamic(\.fill) }
    public var text: Color { dynamic(\.text) }
    public var marker: Color { dynamic(\.marker) }
}
