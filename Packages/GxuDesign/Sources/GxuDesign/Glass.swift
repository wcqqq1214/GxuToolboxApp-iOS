import SwiftUI
import UIKit


public extension View {
    func gxuGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    func gxuGlass(tint: Color? = nil, interactive: Bool = false) -> some View {
        gxuGlass(in: Capsule(), tint: tint, interactive: interactive)
    }

    func gxuGlassID(_ id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        modifier(GlassIDModifier(id: id, namespace: namespace))
    }

    func gxuHidesTabChrome() -> some View {
        toolbar(.hidden, for: .tabBar).preference(key: HidesTabChromeKey.self, value: true)
    }

    func gxuBottomChrome<Navigation: View, Accessory: View>(
        @ViewBuilder navigation: () -> Navigation,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        modifier(BottomChromeModifier(navigation: navigation(), accessory: accessory()))
    }
}

extension EnvironmentValues {
    @Entry public var gxuAccessoryHeight: CGFloat = 0
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

private struct HidesTabChromeKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct BottomChromeModifier<Navigation: View, Accessory: View>: ViewModifier {
    let navigation: Navigation
    let accessory: Accessory
    @State private var height: CGFloat = 0
    @State private var hidden = false

    func body(content: Content) -> some View {
        content
            .background(NativeTabBarHider())
            .toolbar(.hidden, for: .tabBar)
            .onPreferenceChange(HidesTabChromeKey.self) { hidden = $0 }
            .environment(\.gxuAccessoryHeight, hidden ? 0 : height)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !hidden {
                    VStack(spacing: 0) {
                        accessory
                            .frame(maxWidth: .infinity)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                        navigation
                    }
                    .background(.bar)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                }
            }
    }
}

private struct NativeTabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.hideTabBar()
    }

    final class Controller: UIViewController {
        override func loadView() { view = UIView(frame: .zero) }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hideTabBar()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            hideTabBar()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            hideTabBar()
        }

        func hideTabBar() {
            tabBarController?.tabBar.isHidden = true
        }
    }
}

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
