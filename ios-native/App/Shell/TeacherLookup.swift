import FeatureMisc
import GxuAuth
import GxuDesign
import GxuFoundation
import GxuNetworking
import ScheduleUI
import SwiftUI

/// 课程详情的“任课教师”卡片（RN `CourseDetailSheet` 的 `useLookup` + `TeacherSheet`）：
/// 按教师姓名查 `/teachers/search`，卡片取第一条的单位和头像；“查看详情”只有一条结果时直接进详情，多条时列出让用户选。
/// 请求只用 FeatureMisc 公开的 `TeacherSearchPage` / `TeacherSummary` / `TeacherDetailView`，不另写解析；
/// TODO(C)：FeatureMisc 公开 `TeacherAPI.search` 后改用它（见 COORDINATION C 请求区）。
enum TeacherLookup {
    private actor Cache {
        private var storage: [String: [TeacherSummary]] = [:]
        func get(_ name: String) -> [TeacherSummary]? { storage[name] }
        func set(_ list: [TeacherSummary], for name: String) { storage[name] = list }
    }

    private static let cache = Cache()

    static func matches(_ name: String, services: AppServices) async -> [TeacherSummary]? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        if let cached = await cache.get(key) { return cached }
        do {
            let page = try await services.backend.getData("/teachers/search", query: ["q": key, "page": "1"], auth: nil, as: TeacherSearchPage.self)
            await cache.set(page.list, for: key)
            return page.list
        } catch {
            return nil   // 失败不缓存，下次再试
        }
    }

    @MainActor
    static func support(services: AppServices) -> ScheduleTeacherSupport {
        ScheduleTeacherSupport(
            lookup: { name in
                guard let first = await matches(name, services: services)?.first else { return nil }
                return .init(unit: first.unit, avatarURL: first.avatarURL)
            },
            destination: { name in AnyView(TeacherMatchesView(name: name, services: services)) }
        )
    }
}

private struct TeacherMatchesView: View {
    let name: String
    let services: AppServices
    @State private var matches: [TeacherSummary]?
    @State private var failed = false

    var body: some View {
        Group {
            if let matches {
                if matches.count == 1, let only = matches.first {
                    TeacherDetailView(teacher: only)
                } else if matches.isEmpty {
                    GxuEmptyView("暂无教师信息", systemImage: "person.text.rectangle")
                } else {
                    List(matches) { teacher in
                        NavigationLink { TeacherDetailView(teacher: teacher) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(teacher.name).font(.headline)
                                Text(teacher.unit).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle(name)
                    .navigationBarTitleDisplayMode(.inline)
                }
            } else if failed {
                GxuErrorView("教师信息查询失败") { Task { await load() } }
            } else {
                GxuLoadingView("正在查询教师信息…")
            }
        }
        .task { await load() }
    }

    private func load() async {
        failed = false
        matches = await TeacherLookup.matches(name, services: services)
        failed = matches == nil
    }
}
