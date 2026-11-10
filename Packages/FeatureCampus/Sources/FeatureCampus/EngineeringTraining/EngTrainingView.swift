import GxuAuth
import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

/// 工具箱 → 金工实训：缓存优先，后台刷新；需要统一认证账号（工程训练中心用 CA 单点登录）。
struct EngTrainingView: View {
    @Environment(\.services) private var services
    @State private var loadedUsername: String?
    @State private var days: [EngTrainingDay] = []
    @State private var updating = false
    @State private var error: GxuError?
    @State private var loadedOnce = false

    private static let siteURL = URL(string: "http://xlzxms.gxu.edu.cn/api/security-server/dietc/loginsso/student")!

    var body: some View {
        Group {
            if username == nil {
                GxuEmptyView(
                    "需要统一认证账号", systemImage: "person.crop.circle.badge.questionmark",
                    message: "金工实训安排来自工程训练中心，请先在 设置 → 统一认证账号 登录"
                )
            } else if loadedUsername != username || (!loadedOnce && days.isEmpty) {
                GxuLoadingView("正在加载实训安排…")
            } else if days.isEmpty {
                if let error {
                    GxuErrorView(error.userMessage) { Task { await refresh() } }
                } else {
                    GxuEmptyView("暂时没有金工实训安排", systemImage: "wrench.and.screwdriver", message: "安排发布后会显示在这里")
                }
            } else {
                content
            }
        }
        .navigationTitle("金工实训")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if updating { ProgressView() } else { Link(destination: Self.siteURL) { Image(systemName: "safari") }.accessibilityLabel("在工程训练中心查看") }
            }
        }
        .task(id: username) { await load() }
    }

    private var content: some View {
        let today = Calendar.current.startOfDay(for: .now)
        return List {
            if let error {
                Section { Label(error.userMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            Section {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.name.isEmpty ? "暂无安排" : day.name).font(.body.weight(.medium))
                        Text(day.date.formatted(.dateTime.year().month().day().weekday().locale(Locale(identifier: "zh_CN"))))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(day.date < today ? 0.5 : 1)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(day.date < today ? "已结束" : "")
                }
            } footer: {
                Text("实训名称按日期列对应，以工程训练中心的安排为准。")
            }
        }
        .refreshable { await refresh() }
    }

    private var username: String? {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuEngDemo") { return "demo" }
        #endif
        return services.accounts.unifiedUsername
    }

    private func repository(username: String) -> EngTrainingRepository {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuEngDemo") { return EngTrainingRepository(database: services.database, client: DemoEng()) }
        #endif
        return EngTrainingRepository(database: services.database, client: LiveEngTrainingClient(unified: services.accounts.unified, username: username))
    }

    private func load() async {
        loadedUsername = username
        days = []
        error = nil
        updating = false
        loadedOnce = false
        guard let username else { return }
        let cached = await repository(username: username).cached(unifiedUsername: username)
        guard !Task.isCancelled, self.username == username else { return }
        days = cached
        loadedOnce = !cached.isEmpty
        await refresh()
        guard !Task.isCancelled, self.username == username else { return }
        loadedOnce = true
    }

    private func refresh() async {
        guard let username, !updating else { return }
        updating = true
        defer { if self.username == username { updating = false } }
        do {
            let fresh = try await repository(username: username).refresh(unifiedUsername: username)
            guard !Task.isCancelled, self.username == username else { return }
            days = fresh
            error = nil
        } catch {
            guard !error.isCancellation, !Task.isCancelled, self.username == username else { return }
            self.error = (error as? GxuError) ?? .network(error.localizedDescription)
        }
    }
}

#if DEBUG
/// 截图自查：`-GxuEngDemo`，不连真实工程训练中心
private struct DemoEng: EngTrainingClient {
    func scheduleTable() async throws -> Data {
        func label(_ offset: Int) -> String {
            let d = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
            return "\(Calendar.current.component(.month, from: d))月\(Calendar.current.component(.day, from: d))日"
        }
        let cells: [[String: Any]] = [
            ["startRow": 2, "startCol": 1, "colNumber": 1, "content": label(-6)],
            ["startRow": 2, "startCol": 2, "colNumber": 1, "content": label(2)],
            ["startRow": 2, "startCol": 3, "colNumber": 1, "content": label(3)],
            ["startRow": 9, "startCol": 1, "colNumber": 1, "content": "车工实训"],
            ["startRow": 9, "startCol": 2, "colNumber": 2, "content": "数控铣实训"],
        ]
        return try JSONSerialization.data(withJSONObject: ["datas": [cells], "message": "ok", "status": 200])
    }
}
#endif
