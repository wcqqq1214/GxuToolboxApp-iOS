import SwiftUI
import UIKit

/// 课程块配色。课程块是内容层，不用玻璃：用纯色铺底，浅色 / 深色各自校准对比度（文字对底 ≥ 4.5:1）。
/// 传入的是色盘里的基色，不要自己再调透明度。
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
        /// WCAG 相对亮度
        public var luminance: Double {
            func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }
        var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    }

    public struct Resolved: Sendable, Equatable {
        public var fill: RGB
        public var text: RGB
        /// 左侧竖条 / 小标记，介于基色与文字色之间
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
    /// 周视图底色：浅色 systemBackground / 深色 secondarySystemBackground 附近
    private static let darkBackdrop = RGB(r: 28 / 255, g: 28 / 255, b: 30 / 255)

    /// 基色极端（纯黑 / 纯白，用户自定义颜色时可能出现）时，逐步减淡底色 / 加深文字，保证文字对底 ≥ 4.5:1
    public func resolved(dark: Bool) -> Resolved {
        let base = RGB(hex: hex)
        var fillAmount = dark ? 0.38 : 0.55
        var textAmount = dark ? 0.60 : 0.72
        func make() -> Resolved {
            if dark {
                return Resolved(
                    fill: Self.darkBackdrop.mixed(with: base, fillAmount),
                    text: base.mixed(with: Self.white, textAmount),
                    marker: base.mixed(with: Self.white, 0.15)
                )
            }
            return Resolved(
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
