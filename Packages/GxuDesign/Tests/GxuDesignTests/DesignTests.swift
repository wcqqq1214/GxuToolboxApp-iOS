import Foundation
import Testing
@testable import GxuDesign

struct CourseTintTests {
    /// 色盘里的极端颜色：纯黄、纯白、纯黑、饱和蓝 / 红、灰
    private let hexes: [UInt32] = [0xFFFF00, 0xFFFFFF, 0x000000, 0x536DFE, 0xFF5252, 0x78909C, 0x18FFFF, 0xEFEBE9]

    @Test func textContrastMeetsAA() {
        for hex in hexes {
            for dark in [false, true] {
                let contrast = CourseTint(hex: hex).resolved(dark: dark).contrast
                #expect(contrast >= 4.5, "0x\(String(hex, radix: 16)) dark=\(dark) 对比度 \(contrast)")
            }
        }
    }

    @Test func darkFillIsDarkerThanLightFill() {
        let tint = CourseTint(hex: 0xB5EAD7)
        #expect(tint.resolved(dark: true).fill.luminance < tint.resolved(dark: false).fill.luminance)
    }
}

@MainActor
struct ThemeTests {
    @Test func persistsAccentAndAppearance() throws {
        let suite = "test.theme.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let theme = GxuTheme(defaults: defaults)
        #expect(theme.accentHex == GxuTheme.defaultAccentHex && theme.appearance == .system)
        theme.accentHex = 0xE5484D
        theme.appearance = .dark

        let reloaded = GxuTheme(defaults: defaults)
        #expect(reloaded.accentHex == 0xE5484D && reloaded.appearance == .dark)
        reloaded.resetAccent()
        #expect(GxuTheme(defaults: defaults).accentHex == GxuTheme.defaultAccentHex)
    }
}
