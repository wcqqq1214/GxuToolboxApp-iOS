import SwiftUI

/// 加载中
public struct GxuLoadingView: View {
    private let message: LocalizedStringKey
    public init(_ message: LocalizedStringKey = "加载中…") { self.message = message }

    public var body: some View {
        VStack(spacing: GxuDesign.Spacing.m) {
            ProgressView()
            Text(message).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 空状态。`action` 不为空时显示一个按钮（例如“去登录”）
public struct GxuEmptyView: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let message: LocalizedStringKey?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringKey, systemImage: String, message: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent)
            }
        }
    }
}

/// 错误状态。`message` 直接传 `GxuError.userMessage`
public struct GxuErrorView: View {
    private let message: String
    private let retry: (() -> Void)?

    public init(_ message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        ContentUnavailableView {
            Label("出错了", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry { Button("重试", action: retry).buttonStyle(.bordered) }
        }
    }
}

/// 离线 / 刷新失败时，贴在内容上方的非阻塞提示：“上次更新于 …”
public struct GxuStaleBanner: View {
    private let updatedAt: Date?
    private let message: String?

    /// App 只有中文界面：固定成 “11月5日 20:10”，不随系统语言变成英文
    private static let timestampStyle = Date.FormatStyle(locale: Locale(identifier: "zh_Hans_CN")).month().day().hour().minute()

    public init(updatedAt: Date?, message: String? = nil) {
        self.updatedAt = updatedAt
        self.message = message
    }

    public var body: some View {
        HStack(spacing: GxuDesign.Spacing.s) {
            Image(systemName: "icloud.slash")
            VStack(alignment: .leading, spacing: 2) {
                if let message { Text(message) }
                if let updatedAt {
                    Text("上次更新于 \(updatedAt.formatted(Self.timestampStyle))")
                }
            }
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, GxuDesign.Spacing.l)
        .padding(.vertical, GxuDesign.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .combine)
    }
}
