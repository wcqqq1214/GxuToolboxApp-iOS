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

    /// 标签栏上方的常驻附件（例如“下一节课”）。iOS 18 降级为贴在底部的材质条。
    func gxuTabAccessory<Accessory: View>(@ViewBuilder _ accessory: () -> Accessory) -> some View {
        modifier(TabAccessoryModifier(accessory: accessory()))
    }
}

private struct GlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            var glass = Glass.regular
            if let tint { glass = glass.tint(tint) }
            if interactive { glass = glass.interactive() }
            return content.glassEffect(glass, in: shape)
        } else {
            return content
                .background {
                    shape.fill(.regularMaterial)
                    if let tint { shape.fill(tint.opacity(0.35)) }
                }
                .overlay { shape.strokeBorder(.separator.opacity(0.6), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
    }
}

private struct GlassIDModifier<ID: Hashable & Sendable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

private struct TabBarMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

private struct TabAccessoryModifier<Accessory: View>: ViewModifier {
    let accessory: Accessory

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabViewBottomAccessory { accessory }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                accessory
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
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
        if #available(iOS 26, *) {
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
