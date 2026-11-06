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
            .navigationTitle(model.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { model.prefillUsernameIfNeeded() }
            .onChange(of: model.needsRelogin) { model.prefillUsernameIfNeeded() }
        }

        @ViewBuilder private var signedInSection: some View {
            Section {
                LabeledContent(model.usernameLabel, value: model.studentId ?? "")
            } footer: {
                Text(model.footer)
            }
            Section {
                Button("退出登录", role: .destructive) { Task { await model.logout() } }
            }
        }

        @ViewBuilder private var loginSection: some View {
            Section {
                TextField(model.usernamePrompt, text: $model.username)
                    .textContentType(.username)
                    .keyboardType(model.system == .jw ? .numberPad : .asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField(model.passwordPrompt, text: $model.password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.submit() } }
            } header: {
                if model.needsRelogin { Text("需要重新登录：服务器拒绝了保存的账号或密码") }
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
