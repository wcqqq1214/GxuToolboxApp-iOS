import SwiftUI

public extension View {
    func gxuToast(_ message: Binding<String?>, duration: Duration = .seconds(2)) -> some View {
        modifier(GxuToastModifier(message: message, duration: duration))
    }
}

private struct GxuToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: Duration

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, GxuDesign.Spacing.l)
                        .padding(.vertical, GxuDesign.Spacing.m)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.separator))
                        .padding(.horizontal, GxuDesign.Layout.pageMargin)
                        .padding(.bottom, GxuDesign.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                        .task(id: message) {
                            try? await Task.sleep(for: duration)
                            if !Task.isCancelled { withAnimation { self.message = nil } }
                        }
                }
            }
            .animation(.snappy, value: message)
            .onChange(of: message) { _, new in
                if let new { AccessibilityNotification.Announcement(new).post() }
            }
    }
}
