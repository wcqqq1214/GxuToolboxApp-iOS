import GxuAuth
import SwiftUI

public struct AttendanceAccountView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View {
        Content(model: AttendanceAccountModel(accounts: services.accounts))
    }

    private struct Content: View {
        @State var model: AttendanceAccountModel
        @FocusState private var focus: Field?
        private enum Field { case username, password, captcha }

        var body: some View {
            Form {
                if model.isSignedIn {
                    signedInSection
                } else {
                    loginSection
                }
            }
            .navigationTitle("考勤账号")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                model.prefillUsernameIfNeeded()
                if !model.isSignedIn { await model.loadCaptcha() }
            }
        }

        @ViewBuilder private var signedInSection: some View {
            Section {
                LabeledContent("状态", value: "已登录")
                if let name = model.displayName, !name.isEmpty { LabeledContent("账号", value: name) }
            } footer: {
                Text("考勤系统的登录需要验证码，登录状态过期后需要重新输入验证码登录。")
            }
            Section {
                Button("退出登录", role: .destructive) { Task { await model.logout() } }
            }
        }

        @ViewBuilder private var loginSection: some View {
            Section {
                TextField("学号 / 工号", text: $model.username)
                    .textContentType(.username)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                SecureField("考勤系统密码", text: $model.password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focus = .captcha }
                HStack {
                    TextField("验证码", text: $model.captchaCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .captcha)
                        .submitLabel(.go)
                        .onSubmit { Task { await model.submit() } }
                    Button {
                        Task { await model.loadCaptcha() }
                    } label: {
                        Group {
                            if let image = model.captchaImage {
                                Image(uiImage: image).resizable().scaledToFit()
                            } else if model.isLoadingCaptcha {
                                ProgressView()
                            } else {
                                Label("刷新验证码", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                        }
                        .frame(width: 96, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("验证码，点击刷新")
                }
            } header: {
                if model.needsRelogin { Text("登录已过期，请重新登录") }
            } footer: {
                Text("账号密码保存在本机钥匙串中。登录时会通过 HTTPS 将账号、密码和验证码发送至第三方代理服务器 api.tool.gxutech.xyz，由其代为访问学校考勤系统。")
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
    NavigationStack { AttendanceAccountView() }
        .environment(\.services, .preview(signedIn: false))
}
#endif
