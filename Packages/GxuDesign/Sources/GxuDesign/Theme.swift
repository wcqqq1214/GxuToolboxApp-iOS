import Observation
import SwiftUI

public enum AppearanceMode: String, CaseIterable, Sendable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public struct AccentPreset: Identifiable, Hashable, Sendable {
    public let name: String
    public let hex: UInt32
    public var id: UInt32 { hex }
    public var color: Color { Color(hex: hex) }
}

@MainActor @Observable
public final class GxuTheme {
    public static let presets: [AccentPreset] = [
        AccentPreset(name: "蓝", hex: 0x2F6FED),
        AccentPreset(name: "青", hex: 0x14A3B8),
        AccentPreset(name: "绿", hex: 0x2FA66A),
        AccentPreset(name: "橙", hex: 0xF08A24),
        AccentPreset(name: "红", hex: 0xE5484D),
        AccentPreset(name: "紫", hex: 0x8E5AE8),
    ]
    public static let defaultAccentHex: UInt32 = presets[0].hex

    public var accentHex: UInt32 { didSet { defaults.set(Int(accentHex), forKey: Keys.accent) } }
    public var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    public var backgroundImage: Data? { didSet { defaults.set(backgroundImage, forKey: Keys.backgroundImage) } }
    public var backgroundMask: Double { didSet { defaults.set(backgroundMask, forKey: Keys.backgroundMask) } }
    public var accent: Color { Color(hex: accentHex) }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let accent = "gxu.theme.accentHex"
        static let backgroundImage = "gxu.theme.backgroundImage"
        static let backgroundMask = "gxu.theme.backgroundMask"
        static let appearance = "gxu.theme.appearance"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Keys.accent) as? Int
        accentHex = stored.map { UInt32(truncatingIfNeeded: $0) } ?? Self.defaultAccentHex
        backgroundImage = defaults.data(forKey: Keys.backgroundImage)
        backgroundMask = defaults.object(forKey: Keys.backgroundMask) as? Double ?? 0.65
        appearance = defaults.string(forKey: Keys.appearance).flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    public func resetAccent() { accentHex = Self.defaultAccentHex }
}

public extension View {
    func gxuPageBackground() -> some View { modifier(PageBackgroundModifier()) }

    func gxuTheme(_ theme: GxuTheme) -> some View {
        modifier(ThemeModifier(theme: theme))
    }
}

private struct PageBackgroundModifier: ViewModifier {
    @Environment(GxuTheme.self) private var theme: GxuTheme?

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(theme?.backgroundImage == nil ? .automatic : .hidden)
            .background {
                Color(.systemGroupedBackground)
                if let theme, let data = theme.backgroundImage, let image = UIImage(data: data) {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .overlay(Color(.systemGroupedBackground).opacity(min(max(theme.backgroundMask, 0), 1)))
                            .accessibilityHidden(true)
                    }
                    .ignoresSafeArea()
                }
            }
    }
}

private struct ThemeModifier: ViewModifier {
    let theme: GxuTheme
    func body(content: Content) -> some View {
        content
            .environment(theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.appearance.colorScheme)
    }
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
