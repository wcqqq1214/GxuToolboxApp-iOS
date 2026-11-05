import FeatureAccount
import GxuAuth
import GxuDesign
import SwiftUI

/// 设置首页骨架。账号相关页面由 FeatureAccount 提供，这里只放入口；外观设置在这里。
struct SettingsHomeView: View {
    @Environment(GxuTheme.self) private var theme
    @Environment(\.services) private var services

    var body: some View {
        @Bindable var theme = theme
        NavigationStack {
            List {
                Section("账号") {
                    NavigationLink {
                        AccountFeature.makeRootView()
                    } label: {
                        AccountRow(status: accountStatus)
                    }
                    NavigationLink {
                        AccountFeature.makePersonalInfoView()
                    } label: {
                        Text("个人信息")
                    }
                    NavigationLink {
                        AccountFeature.makeUnifiedAccountView()
                    } label: {
                        accountLabel("统一认证账号", state: services.accounts.states[.unified])
                    }
                    NavigationLink {
                        AccountFeature.makeAttendanceAccountView()
                    } label: {
                        accountLabel("考勤账号", state: services.accounts.states[.attendance])
                    }
                }

                Section("外观") {
                    Picker("外观模式", selection: $theme.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    AccentPicker()
                }

                Section("课表") {
                    comingSoon("课表显示设置", systemImage: "slider.horizontal.3")
                    comingSoon("课程颜色", systemImage: "paintpalette")
                }

                Section("关于") {
                    LabeledContent("版本", value: appVersion)
                    NavigationLink {
                        AccountFeature.makeFeedbackView()
                    } label: {
                        Label("意见反馈", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }

    private var accountStatus: String {
        Self.statusText(services.accounts.states[.jw])
    }

    private func accountLabel(_ title: LocalizedStringKey, state: AuthState?) -> some View {
        LabeledContent(title) {
            Text(Self.statusText(state)).foregroundStyle(.secondary)
        }
    }

    private static func statusText(_ state: AuthState?) -> String {
        switch state ?? .noAccount {
        case .noAccount: "未登录"
        case .signedOut: "已退出"
        case .authenticated: "已登录"
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private func comingSoon(_ title: LocalizedStringKey, systemImage: String) -> some View {
        LabeledContent {
            Text("即将上线").font(.footnote).foregroundStyle(.secondary)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// 账号入口：已登录时在标题下显示 “学号 · 学院”。资料先读缓存，再后台更新；拿不到资料时只显示学号。
private struct AccountRow: View {
    let status: String
    @Environment(\.services) private var services
    @State private var profile: UserProfile?

    private var studentId: String? { services.accounts.studentId }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("教务账号")
                if let summary {
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: GxuDesign.Spacing.s)
            Text(status).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .task(id: studentId) { await loadProfile() }
    }

    private var summary: String? {
        guard let studentId else { return nil }
        let college = profile?.studentId == studentId ? profile?.college ?? "" : ""
        return college.isEmpty ? studentId : "\(studentId) · \(college)"
    }

    private func loadProfile() async {
        guard let studentId else {
            profile = nil
            return
        }
        profile = services.profiles.cached(studentId: studentId)
        if let fresh = try? await services.profiles.profile(studentId: studentId, refresh: true) { profile = fresh }
    }
}

/// 主题色：一排预设色块，当前选中的带对勾
private struct AccentPicker: View {
    @Environment(GxuTheme.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
            Text("主题色")
            HStack(spacing: GxuDesign.Spacing.m) {
                ForEach(GxuTheme.presets) { preset in
                    Button {
                        theme.accentHex = preset.hex
                    } label: {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if theme.accentHex == preset.hex {
                                    Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(theme.accentHex == preset.hex ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, GxuDesign.Spacing.xs)
    }
}
