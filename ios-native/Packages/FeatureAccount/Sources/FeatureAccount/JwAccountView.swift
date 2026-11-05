import GxuAuth
import SwiftUI

public struct JwAccountView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        Content(model: JwAccountModel(accounts: services.accounts))
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
            .navigationTitle("教务账号")
            .navigationBarTitleDisplayMode(.inline)
        }

        @ViewBuilder private var signedInSection: some View {
            Section {
                LabeledContent("学号", value: model.studentId ?? "")
            } footer: {
                Text("账号密码仅保存在本机钥匙串中，用于教务会话过期后自动重新登录。")
            }
            Section {
                Button("退出登录", role: .destructive) { Task { await model.logout() } }
            }
        }

        @ViewBuilder private var loginSection: some View {
            Section {
                TextField("学号", text: $model.username)
                    .textContentType(.username)
                    .keyboardType(.numberPad)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField("教务系统密码", text: $model.password)
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
