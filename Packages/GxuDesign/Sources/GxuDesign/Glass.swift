import SwiftUI

// 玻璃封装。iOS 26 才有的 API（glassEffect / GlassEffectContainer / glassEffectID）只在这个文件里出现，
// 并统一在 iOS 18 降级为 Material。feature 代码禁止直接写 `.glassEffect`、`.buttonStyle(.glass)`。

public extension View {
    /// 玻璃背景。只用于导航层和浮动控件，不要用在内容上，也不要在玻璃上再叠玻璃。
    /// - Parameters:
    ///   - shape: 玻璃形状，默认胶囊
    ///   - tint: 着色（例如强调按钮用主题色）
    ///   - interactive: 按下有高光反馈（按钮用）
    func gxuGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    func gxuGlass(tint: Color? = nil, interactive: Bool = false) -> some View {
        gxuGlass(in: Capsule(), tint: tint, interactive: interactive)
    }

    /// 让相邻玻璃控件在状态切换时变形（需要放在同一个 `GlassGroup` 里，并共用一个 `@Namespace`）
    func gxuGlassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        modifier(GlassIDModifier(id: id, namespace: namespace))
    }

    /// 标签栏随滚动收起（iOS 26）；iOS 18 无效果
    func gxuTabBarMinimizeOnScroll() -> some View {
        modifier(TabBarMinimizeModifier())
    }

    /// 标签栏上方的常驻附件（例如“下一节课”）。`isEnabled` 为 false 时不显示（iOS 26.1+；26.0 和 18 降级为不放内容）。
    /// 标签栏收起时（iOS 26 的 inline 位置）空间很窄，附件里用 `@Environment(\.gxuAccessoryCompact)` 判断并精简内容。
    /// iOS 18 降级为贴在标签栏上方的材质条：**每个标签页的内容都要加 `.gxuAccessoryInset()`**（iOS 26 上它什么都不做）。
    /// 二级页面用：隐藏标签栏，同时隐藏标签栏上方的附件（iOS 26 的附件属于标签栏，iOS 18 降级的附件靠这个偏好值收起）。
    func gxuHidesTabChrome() -> some View {
        toolbar(.hidden, for: .tabBar).preference(key: HidesTabChromeKey.self, value: true)
    }

    /// 配合 `gxuTabAccessory` 的 iOS 18 降级：放在每个标签页内容上，附件显示在标签栏上方。
    func gxuAccessoryInset() -> some View {
        modifier(LegacyAccessoryInsetModifier())
    }

    func gxuTabAccessory<Accessory: View>(isEnabled: Bool = true, @ViewBuilder _ accessory: () -> Accessory) -> some View {
        modifier(TabAccessoryModifier(isEnabled: isEnabled, accessory: accessory()))
    }
}

extension EnvironmentValues {
    @Entry var gxuLegacyAccessory: AnyView? = nil

    /// iOS 18 降级附件的高度（没有附件或 iOS 26 为 0）。贴着底部的浮动控件要把它加进底部间距，否则会被附件盖住
    @Entry public var gxuAccessoryHeight: CGFloat = 0

    /// 底部附件处于收起（inline）位置，只有很窄的空间
    @Entry public var gxuAccessoryCompact: Bool = false
}

private struct GlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if GxuDesign.useModernGlass, #available(iOS 26, *) {
            content.glassEffect(glassStyle, in: shape)
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    if let tint { shape.fill(tint.opacity(0.35)) }
                }
                .overlay { shape.strokeBorder(.separator.opacity(0.6), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
    }

    @available(iOS 26, *)
    private var glassStyle: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

private struct GlassIDModifier<ID: Hashable & Sendable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if GxuDesign.useModernGlass, #available(iOS 26, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

private struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if GxuDesign.useModernGlass, #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct TabAccessoryModifier<Accessory: View>: ViewModifier {
    let isEnabled: Bool
    let accessory: Accessory

    func body(content: Content) -> some View {
        if GxuDesign.useModernGlass, #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) { AccessoryHost(content: accessory) }
        } else if GxuDesign.useModernGlass, #available(iOS 26, *) {
            content.tabViewBottomAccessory { AccessoryHost(content: isEnabled ? accessory : nil) }
        } else {
            // iOS 18：没有系统附件。把内容交给环境，由各标签页内容用 `.gxuAccessoryInset()` 放在标签栏上方
            // （直接给 TabView 加 safeAreaInset 会盖住标签栏）
            content.environment(\.gxuLegacyAccessory, isEnabled ? AnyView(accessory) : nil)
        }
    }
}

private struct HidesTabChromeKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct LegacyAccessoryInsetModifier: ViewModifier {
    @Environment(\.gxuLegacyAccessory) private var accessory
    @State private var height: CGFloat = 0
    @State private var hidden = false

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(HidesTabChromeKey.self) { hidden = $0 }
            .environment(\.gxuAccessoryHeight, accessory == nil || hidden ? 0 : height)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let accessory, !hidden {
                    accessory
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, GxuDesign.Spacing.s)
                        .background(.bar)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                }
            }
    }
}

@available(iOS 26, *)
private struct AccessoryHost<Content: View>: View {
    let content: Content?
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let content { content.environment(\.gxuAccessoryCompact, placement == .inline) }
    }
}

/// 一组相邻的玻璃控件。内部是 `GlassEffectContainer`，控件靠近时会合并，状态切换时会变形；iOS 18 就是普通容器。
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = GxuDesign.Spacing.s, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if GxuDesign.useModernGlass, #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// 玻璃按钮。`title` 为空就是圆形图标按钮（至少 44pt，符合点击热区）。
public struct GlassButton: View {
    private let title: LocalizedStringKey?
    private let systemImage: String
    private let accessibilityLabel: LocalizedStringKey
    private let prominent: Bool
    private let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: LocalizedStringKey? = nil, systemImage: String, accessibilityLabel: LocalizedStringKey? = nil,
        prominent: Bool = false, action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel ?? title ?? ""
        self.prominent = prominent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if let title {
                    Label(title, systemImage: systemImage)
                        .padding(.horizontal, GxuDesign.Spacing.l)
                } else {
                    Image(systemName: systemImage).frame(width: 44)
                }
            }
            .font(.body.weight(.medium))
            .frame(minHeight: 44)
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .gxuGlass(tint: prominent ? .accentColor : nil, interactive: true)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel)
    }
}
