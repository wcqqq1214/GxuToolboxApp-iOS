import SwiftUI

public struct ContentCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = GxuDesign.Layout.cardInset, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: GxuDesign.Radius.card, style: .continuous)
            )
    }
}

public extension View {
    func gxuSectionHeader(leadingInset: CGFloat = GxuDesign.Layout.cardInset) -> some View {
        font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, leadingInset)
            .accessibilityAddTraits(.isHeader)
    }
}
