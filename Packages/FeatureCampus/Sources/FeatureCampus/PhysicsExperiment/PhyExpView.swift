import CampusKit
import GxuAuth
import GxuDesign
import GxuFoundation
import ScheduleKit
import SwiftUI

struct PhyExpView: View {
    @Environment(\.services) private var services
    @State private var loadedUsername: String?
    @State private var list: [PhyExperiment] = []
    @State private var updating = false
    @State private var error: GxuError?
    @State private var loadedOnce = false

    private static let pecURL = URL(string: "https://pec.gxu.edu.cn/Customer/MasterPage/UserCenterPage.html")!

    var body: some View {
        Group {
            if username == nil {
                GxuEmptyView(
                    "需要统一认证账号", systemImage: "person.crop.circle.badge.questionmark",
                    message: "物理实验课来自物理实验教学中心，请先在 设置 → 统一认证账号 登录"
                )
            } else if loadedUsername != username || (!loadedOnce && list.isEmpty) {
                GxuLoadingView("正在加载实验课…")
            } else if list.isEmpty {
                if let error {
                    GxuErrorView(error.userMessage) { Task { await refresh() } }
                } else {
                    GxuEmptyView("当前学期没有实验课", systemImage: "atom", message: "只能查询当前学期的实验课，过往学期的无法查询")
                }
            } else {
                content
            }
        }
        .navigationTitle("物理实验课")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if updating { ProgressView() } else { Link(destination: Self.pecURL) { Image(systemName: "safari") }.accessibilityLabel("在物理实验中心查看") }
            }
        }
        .task(id: username) { await load() }
    }

    private var content: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let upcoming = list.filter { ($0.date().map { $0 >= today }) ?? true }
        let past = list.filter { ($0.date().map { $0 < today }) ?? false }
        return List {
            if let error {
                Section { Label(error.userMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }
            if !upcoming.isEmpty {
                Section("即将上课") { ForEach(upcoming) { ExperimentRow(item: $0, isPast: false) } }
            }
            if !past.isEmpty {
                Section("已结束") { ForEach(past) { ExperimentRow(item: $0, isPast: true) } }
            }
        }
        .refreshable { await refresh() }
    }

    private var username: String? {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuPECDemo") { return "demo" }
        #endif
        return services.accounts.unifiedUsername
    }

    private func repository(username: String) -> PhyExpRepository {
        #if DEBUG
        if CommandLine.arguments.contains("-GxuPECDemo") { return PhyExpRepository(database: services.database, client: DemoPEC()) }
        #endif
        return PhyExpRepository(database: services.database, client: LivePECClient(unified: services.accounts.unified, username: username))
    }

    private func load() async {
        loadedUsername = username
        list = []
        error = nil
        updating = false
        loadedOnce = false
        guard let username else { return }
        let cached = await repository(username: username).cached(unifiedUsername: username)
        guard !Task.isCancelled, self.username == username else { return }
        list = cached
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
            list = fresh
            error = nil
        } catch {
            guard !error.isCancellation, !Task.isCancelled, self.username == username else { return }
            self.error = (error as? GxuError) ?? .network(error.localizedDescription)
        }
    }
}

private struct ExperimentRow: View {
    let item: PhyExperiment
    let isPast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title).font(.body.weight(.medium))
            Text(dateLine).font(.footnote).foregroundStyle(.secondary)
            let place = [item.place, item.teacher].filter { !$0.isEmpty }.joined(separator: " · ")
            if !place.isEmpty { Text(place).font(.footnote).foregroundStyle(.secondary) }
        }
        .opacity(isPast ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isPast ? "已结束" : "")
    }

    private var dateLine: String {
        let day = item.date().map { $0.formatted(.dateTime.year().month().day().weekday().locale(Locale(identifier: "zh_CN"))) } ?? item.dateText
        return [day, item.timeText].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

#if DEBUG
private struct DemoPEC: PECClient {
    func ruleManage() async throws -> Data {
        func day(_ offset: Int) -> String {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.string(from: Calendar.current.date(byAdding: .day, value: offset, to: .now)!)
        }
        let rows = [
            ["ID": "D1", "SKRQ": day(-14), "SKSJ": "14:30-17:10", "XMMC": "示波器的使用", "ZJJSXM": "教师甲", "FJBH": "理科楼101"],
            ["ID": "D2", "SKRQ": day(3), "SKSJ": "14:30-17:10", "XMMC": "光栅衍射", "ZJJSXM": "教师乙", "FJBH": "理科楼203"],
            ["ID": "D3", "SKRQ": day(17), "SKSJ": "08:30-11:10", "XMMC": "迈克尔逊干涉仪", "ZJJSXM": "教师乙", "FJBH": "理科楼203"],
        ]
        let inner = String(data: try JSONSerialization.data(withJSONObject: ["data": rows]), encoding: .utf8)!
        return try JSONSerialization.data(withJSONObject: ["d": inner])
    }
}
#endif
