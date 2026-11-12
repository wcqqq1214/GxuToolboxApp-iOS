import FeatureAccount
import GxuAuth
import GxuDesign
import ImageIO
import PhotosUI
import SwiftUI

struct SettingsHomeView: View {
    private static let sourceRepositoryURL = URL(string: "https://github.com/wcqqq1214/GxuToolboxApp-iOS")!

    @Environment(GxuTheme.self) private var theme
    @Environment(\.services) private var services

    var body: some View {
        @Bindable var theme = theme
        NavigationStack {
            List {
                Section("账号") {
                    NavigationLink("打开教务") {
                        WebViewScreen(url: URL(string: "https://jwxt2018.gxu.edu.cn/jwglxt/xtgl/index_initMenu.html")!, title: "教务系统")
                    }
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
                    NavigationLink {
                        AccountFeature.makeOAAccountView()
                    } label: {
                        accountLabel("OA 账号", state: services.accounts.states[.oa])
                    }
                }

                Section("外观") {
                    Picker("外观模式", selection: $theme.appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    AccentPicker()
                    BackgroundSettings(theme: theme)
                }

                Section("课表与考试") {
                    NavigationLink("课表外观") { ScheduleAppearanceSettingsView() }
                    NavigationLink("课程详情显示") { DetailFieldsSettingsView(kind: .course) }
                    NavigationLink("考试详情显示") { DetailFieldsSettingsView(kind: .exam) }
                }

                AnalyticsSettingsSection(tracker: services.analytics)

                Section("关于") {
                    NavigationLink {
                        AppVersionListView()
                    } label: {
                        LabeledContent("软件版本", value: appVersion)
                    }
                    Link(destination: Self.sourceRepositoryURL) {
                        HStack {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("开源地址")
                                        .foregroundStyle(Color(uiColor: .label))
                                    Text(verbatim: "wcqqq1214/GxuToolboxApp-iOS")
                                        .font(.footnote)
                                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                                }
                            } icon: {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                .accessibilityHidden(true)
                        }
                    }
                    NavigationLink {
                        AccountFeature.makeErrorLogView()
                    } label: {
                        Label("诊断日志", systemImage: "stethoscope")
                    }
                    NavigationLink {
                        AccountFeature.makeFeedbackView()
                    } label: {
                        Label("意见反馈", systemImage: "bubble.left.and.text.bubble.right")
                    }
                }
            }
            .gxuPageBackground()
            .navigationTitle("设置")
            .toolbar(.hidden, for: .tabBar)
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
        (state ?? .noAccount).displayText
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


private struct BackgroundSettings: View {
    @Bindable var theme: GxuTheme
    @State private var selection: PhotosPickerItem?
    @State private var imageError = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) { Text("选择背景图") }
            .task(id: selection) {
                guard let selection else { return }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self),
                          let image = await Self.thumbnail(data) else {
                        if !Task.isCancelled { imageError = true }
                        return
                    }
                    if !Task.isCancelled { theme.backgroundImage = image }
                } catch {
                    if !Task.isCancelled { imageError = true }
                }
            }
            .alert("无法读取背景图", isPresented: $imageError) { Button("好", role: .cancel) {} }
        if theme.backgroundImage != nil {
            Slider(value: $theme.backgroundMask, in: 0...1, step: 0.01) { Text("背景蒙版透明度") }
            Button("重置背景", role: .destructive) {
                selection = nil
                theme.backgroundImage = nil
            }
        }
    }

    private nonisolated static func thumbnail(_ data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1600,
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: image).jpegData(compressionQuality: 0.75)
        }.value
    }
}
