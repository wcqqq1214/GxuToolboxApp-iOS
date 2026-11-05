import GxuAuth
import GxuFoundation
import SwiftUI

public struct JwAccountView: View {
    @Environment(\.services) private var services

    private let system: AuthSystem

    public init() { system = .jw }
    init(system: AuthSystem) { self.system = system }

    public var body: some View {
        Content(model: JwAccountModel(accounts: services.accounts, system: system))
    }

    private struct Content: View {
        @State var model: JwAccountModel
        @FocusState private var focus: Field?
        private enum Field { case username, password }

        var body: some View {
            Form {
                if model.isSignedIn {
                    signedInSection
                } else {
                    loginSection
                }
            }
            .navigationTitle(model.system == .jw ? "教务账号" : "统一认证账号")
            .navigationBarTitleDisplayMode(.inline)
        }

        @ViewBuilder private var signedInSection: some View {
            Section {
                LabeledContent(model.system == .jw ? "学号" : "账号", value: model.studentId ?? "")
            } footer: {
                Text(model.system == .jw
                    ? "账号密码仅保存在本机钥匙串中，用于教务会话过期后自动重新登录。"
                    : "账号密码仅保存在本机钥匙串中，用于登录物理实验平台、工程训练中心等需要统一认证的服务。")
            }
            Section {
                Button("退出登录", role: .destructive) { Task { await model.logout() } }
            }
        }

        @ViewBuilder private var loginSection: some View {
            Section {
                TextField(model.system == .jw ? "学号" : "统一认证账号", text: $model.username)
                    .textContentType(.username)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField(model.system == .jw ? "教务系统密码" : "统一认证密码", text: $model.password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.submit() } }
            } footer: {
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
            }
            Section {
                Button {
                    focus = nil
                    Task { await model.submit() }
                } label: {
                    HStack {
                        Text("登录")
                        if model.isWorking { Spacer(); ProgressView() }
                    }
                }
                .disabled(!model.canSubmit)
            }
        }
    }
}

#if DEBUG
import GxuTestSupport

#Preview("未登录") {
    NavigationStack { JwAccountView() }
        .environment(\.services, .preview(signedIn: false))
}
#Preview("已登录") {
    NavigationStack { JwAccountView() }
        .environment(\.services, .preview)
}
#endif
