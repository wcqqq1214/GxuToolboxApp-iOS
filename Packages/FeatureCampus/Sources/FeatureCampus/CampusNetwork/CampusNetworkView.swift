import GxuAuth
import GxuStorage
import SwiftUI

struct CampusNetworkView: View {
    private enum Query {
        case usage, submitCaptcha, renewCaptcha
    }

    @Environment(\.services) private var services
    @State private var session = CampusNetworkSession()
    @State private var credential: Credential?
    @State private var usage: CampusNetworkUsage?
    @State private var username = ""
    @State private var password = ""
    @State private var captcha: UIImage?
    @State private var code = ""
    @State private var error: String?
    @State private var refreshTask: Task<Void, Never>?
    @State private var refreshing = false
    @State private var configuring = false

    let credentials: any CredentialStore
    private let cache = UserDefaultsSharedStore(suiteName: nil)

    var body: some View {
        Form {
            if let usage {
                Section {
                    LabeledContent("已用流量", value: usage.used)
                    LabeledContent("计费周期", value: usage.period)
                    if let free = usage.free { LabeledContent("免费流量", value: free) }
                    if let available = usage.available { LabeledContent("可用流量", value: available) }
                    if let balance = usage.balance { LabeledContent("账户余额", value: balance) }
                    if let plan = usage.plan { LabeledContent("套餐", value: plan) }
                } footer: {
                    Text("上次更新 \(usage.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            if configuring || credential == nil {
                Section {
                    TextField("校园网账号", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("校园网本地密码", text: $password)
                } header: {
                    Text("校园网账号")
                } footer: {
                    Text("学校自服务使用 HTTP，密码传输不加密。请使用单独设置的校园网本地密码。")
                }
                .disabled(refreshing || captcha != nil)
            }
            if let captcha {
                Section("验证码") {
                    Image(uiImage: captcha)
                        .interpolation(.none)
                        .accessibilityLabel("校园网验证码")
                    TextField("输入验证码", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("验证并查询") { startRefresh(.submitCaptcha) }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("换一张验证码") { startRefresh(.renewCaptcha) }
                }
                .disabled(refreshing)
            } else {
                Section {
                    Button(configuring || credential == nil ? "登录并查询" : "刷新用量") {
                        startRefresh()
                    }
                    .disabled(refreshing || ((configuring || credential == nil) && draft == nil))
                }
            }
        }
        .navigationTitle("校园网用量")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if refreshing {
                    ProgressView().accessibilityLabel("正在查询")
                } else if let credential {
                    Menu {
                        Button(configuring ? "取消修改" : "更换校园网账号") { toggleConfiguration() }
                        Button("移除校园网账号", role: .destructive) { remove(credential) }
                    } label: {
                        Image(systemName: "person.crop.circle").accessibilityLabel("校园网账号")
                    }
                }
            }
        }
        .task {
            guard credential == nil, !configuring else { return }
            credential = credentials.load(.campusNetwork)
            if let credential {
                usage = cache.value(cacheKey(credential.username))
                await refresh()
            } else {
                username = services.accounts.unifiedUsername ?? ""
            }
        }
        .onDisappear { refreshTask?.cancel() }
        .refreshable {
            if credential != nil, !configuring, captcha == nil { await refresh() }
        }
    }

    private var draft: Credential? {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !password.isEmpty else { return nil }
        return Credential(username: account, password: password)
    }

    private func cacheKey(_ account: String) -> SharedKey<CampusNetworkUsage> {
        SharedKey("campusNetwork.usage.\(account)")
    }

    private func toggleConfiguration() {
        configuring.toggle()
        username = credential?.username ?? ""
        password = ""
        captcha = nil
        code = ""
        error = nil
        session = CampusNetworkSession()
        usage = configuring ? nil : credential.flatMap { cache.value(cacheKey($0.username)) }
    }

    private func remove(_ credential: Credential) {
        credentials.delete(.campusNetwork)
        cache.set(nil, for: cacheKey(credential.username))
        self.credential = nil
        configuring = false
        username = services.accounts.unifiedUsername ?? ""
        password = ""
        captcha = nil
        code = ""
        error = nil
        usage = nil
        session = CampusNetworkSession()
    }

    private func startRefresh(_ query: Query = .usage) {
        guard !refreshing else { return }
        refreshTask?.cancel()
        refreshTask = Task { await refresh(query) }
    }

    private func refresh(_ query: Query = .usage) async {
        guard !refreshing, let account = (configuring ? draft : credential ?? draft) else { return }
        refreshing = true
        if query == .usage, configuring || credential == nil { session = CampusNetworkSession() }
        error = nil
        defer { refreshing = false }
        do {
            let result: CampusNetworkSession.Result
            switch query {
            case .submitCaptcha:
                result = try await session.submit(code.trimmingCharacters(in: .whitespacesAndNewlines), credential: account)
            case .renewCaptcha:
                result = try await session.renewCaptcha()
            case .usage:
                result = try await session.refresh(account)
            }
            try Task.checkCancellation()
            captcha = nil
            code = ""
            switch result {
            case .usage(let snapshot):
                if credential != account {
                    try credentials.save(account, for: .campusNetwork)
                    if let old = credential, old.username != account.username {
                        cache.set(nil, for: cacheKey(old.username))
                    }
                }
                cache.set(snapshot, for: cacheKey(account.username))
                credential = account
                usage = snapshot
                configuring = false
                password = ""
            case .captcha(let data, let rejected):
                guard let image = UIImage(data: data) else { throw CampusNetworkError.unexpectedPage }
                captcha = image
                if rejected { error = "验证码未通过，请输入新的验证码。" }
            }
        } catch is CancellationError {
            return
        } catch {
            captcha = nil
            code = ""
            self.error = error.localizedDescription
        }
    }
}
