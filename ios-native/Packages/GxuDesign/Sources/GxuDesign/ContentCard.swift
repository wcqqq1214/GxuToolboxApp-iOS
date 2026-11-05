import SwiftUI

/// 内容卡片：纯色圆角块，**不是玻璃**。放成绩、列表、说明文字等正文内容。
public struct ContentCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = GxuDesign.Spacing.l, @ViewBuilder content: () -> Content) {
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
