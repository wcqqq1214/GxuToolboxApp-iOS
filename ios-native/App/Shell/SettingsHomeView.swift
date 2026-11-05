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
                        AccountFeature.makeRootView().navigationTitle("教务账号")
                    } label: {
                        LabeledContent("教务账号") {
                            Text(accountStatus).foregroundStyle(.secondary)
                        }
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
                    comingSoon("意见反馈", systemImage: "bubble.left.and.text.bubble.right")
                }
            }
            .navigationTitle("设置")
        }
    }

    private var accountStatus: String {
        switch services.accounts.states[.jw] ?? .noAccount {
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
