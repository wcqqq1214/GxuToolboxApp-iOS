import SwiftUI

/// 内容卡片：纯色圆角块，**不是玻璃**。放成绩、列表、说明文字等正文内容。
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
    /// 自拼页面（非 `List`）里的分组标题，默认和卡片内文字对齐。
    func gxuSectionHeader(leadingInset: CGFloat = GxuDesign.Layout.cardInset) -> some View {
        font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, leadingInset)
            .accessibilityAddTraits(.isHeader)
    }
}
