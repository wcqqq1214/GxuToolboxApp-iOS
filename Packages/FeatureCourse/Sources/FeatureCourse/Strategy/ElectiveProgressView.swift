import ExamKit
import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import SwiftUI

/// 校选课修读进度：先显示本地缓存，再后台刷新；刷新失败保留上次结果并提示；账号切换、新的刷新会让旧请求作废。
@MainActor @Observable
final class ElectiveProgressModel {
    /// 后端结果；有待核对课程时已用本地成绩记录核对过（`ElectiveReviewResolver`）
    private(set) var data: ElectiveProgress?
    private(set) var confirmed: [String: String] = [:]
    private(set) var unresolved: [String: String] = [:]
    private var raw: ElectiveProgress?
    private(set) var isCached = false
    private(set) var isLoading = false
    private(set) var error: String?
    private var generation = 0
    private let services: AppServices

    init(services: AppServices) { self.services = services }

    private func show(_ progress: ElectiveProgress?, scores: [Score]?) {
        raw = progress
        guard let progress else { data = nil; confirmed = [:]; unresolved = [:]; return }
        let r = ElectiveReviewResolver.resolve(progress, scores: scores)
        data = r.progress; confirmed = r.confirmed; unresolved = r.unresolved
    }

    func load() async {
        generation += 1
        let version = generation
        guard let studentId = services.accounts.studentId?.trimmingCharacters(in: .whitespaces), !studentId.isEmpty else {
            data = nil; error = "未找到当前教务账号，请先登录"; return
        }
        let examRepo = ExamRepository(database: services.database)
        if raw?.studentId != studentId {
            show(ElectiveProgressCache.load(services.shared, studentId: studentId), scores: try? await examRepo.allScores(studentId: studentId))
            isCached = data != nil
        }
        error = nil
        isLoading = true
        defer { if version == generation { isLoading = false } }
        do {
            let result = try await ElectiveProgressAPI(backend: services.backend).fetch(studentId: studentId)
            guard version == generation else { return }
            try? ElectiveProgressCache.save(services.shared, result, studentId: studentId)
            // 成绩记录用来核对"待核对"的课程：先刷新一次全部成绩（失败用本地缓存），都不可用就保留待核对
            if result.courses.contains(where: { $0.status == .review }), let scores = try? await ScoreAPI(backend: services.backend).allScores() {
                try? await examRepo.replaceAllScores(scores, studentId: studentId)
            }
            guard version == generation else { return }
            show(result, scores: try? await examRepo.allScores(studentId: studentId))
            isCached = false
        } catch is CancellationError {
        } catch {
            guard version == generation else { return }
            isCached = data != nil
            self.error = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
        }
    }
}

public struct ElectiveStrategyView: View {
    @Environment(\.services) private var services

    public init() {}

    public var body: some View { Content(services: services) }

    private struct Content: View {
        @State private var model: ElectiveProgressModel

        init(services: AppServices) { _model = State(initialValue: ElectiveProgressModel(services: services)) }

        var body: some View {
            List {
                if let error = model.error {
                    if model.data == nil {
                        GxuErrorView(error) { Task { await model.load() } }.listRowBackground(Color.clear)
                    } else {
                        GxuStaleBanner(updatedAt: model.data?.computedDate, message: "\(error)（已保留上次查询结果）")
                            .listRowBackground(Color.clear)
                    }
                }
                if let data = model.data {
                    content(data)
                } else if model.isLoading {
                    GxuLoadingView("正在查询校选课修读进度…").frame(minHeight: 240).listRowBackground(Color.clear)
                }
            }
            .navigationTitle("选课策略")
            .navigationBarTitleDisplayMode(.inline)
            .gxuHidesTabChrome()
            .task { await model.load() }
            .refreshable { await model.load() }
        }

        @ViewBuilder
        private func content(_ data: ElectiveProgress) -> some View {
            Section {
                ForEach(data.requirements) { item in
                    HStack {
                        Text(item.label)
                        Spacer()
                        Text(ElectiveProgressDisplay.format(item)).bold().foregroundStyle(color(data.passed(item)))
                    }
                }
                HStack {
                    Text("通识选修要求").font(.headline)
                    Spacer()
                    Text(data.qualified.map { $0 ? "达标" : "未达标" } ?? "待核对").font(.headline).foregroundStyle(color(data.qualified))
                }
            } header: {
                Text(data.ruleName)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let date = data.computedDate {
                        Text("\(model.isCached ? "上次查询" : "更新于") \(date.formatted(Date.FormatStyle(date: .numeric, time: .shortened).locale(Locale(identifier: "zh_CN"))))")
                    }
                    if !data.complete { Text("学分仅统计已确认课程。") }
                }
            }
            if !data.issues.isEmpty {
                Section("待核对课程") {
                    ForEach(Array(data.issues.enumerated()), id: \.offset) { _, issue in
                        let course = data.courses.first { $0.courseId == issue.courseId }
                        // 有具体原因就用具体原因，不用后端的笼统说明
                        Text("\(course?.courseName ?? "课程记录")：\(course.flatMap { model.unresolved[$0.id] } ?? issue.message)").foregroundStyle(.orange)
                    }
                }
            }
            Section("尚未确认完成的指定课程") {
                if data.remainingRequired.isEmpty {
                    Label("指定课程均已确认完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    ForEach(data.remainingRequired, id: \.self) { Text($0) }
                }
            }
            Section {
                if data.courses.isEmpty { Text("暂无通识选修课记录").foregroundStyle(.secondary) }
                ForEach(data.courses) { CourseRow(course: $0, note: model.confirmed[$0.id]) }
            } header: {
                Text("课程成绩 · \(data.courses.count) 门")
            }
        }

        private func color(_ passed: Bool?) -> Color {
            switch passed {
            case true?: .green
            case false?: .red
            case nil: .secondary
            }
        }
    }
}

private struct CourseRow: View {
    let course: ElectiveProgress.Course
    let note: String?

    private var statusText: String {
        let label = ElectiveProgressDisplay.statusLabel(course.status)
        guard let score = course.score else { return label }
        return "\(score.formatted(.number.precision(.fractionLength(0...1))))分 · \(label)"
    }

    private var statusColor: Color { course.status == .passed ? .green : course.status == .failed ? .red : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                if course.online == true { Image(systemName: "wifi").font(.caption).foregroundStyle(.tint).accessibilityLabel("网课") }
                Text(course.courseName.isEmpty ? "未命名课程" : course.courseName)
                Spacer()
                Text(statusText).font(.subheadline).foregroundStyle(statusColor)
            }
            Text([course.credit.map { "\(ElectiveStrategy.number($0)) 学分" } ?? "学分待核对",
                  course.counted ? "已计入 \(ElectiveStrategy.number(course.countedCredits)) 学分" : (course.excludedReason ?? "暂未计入学分")]
                .joined(separator: " · "))
                .font(.caption).foregroundStyle(.secondary)
            if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            if !course.teachers.isEmpty { Text("教师：" + course.teachers.joined(separator: "、")).font(.caption).foregroundStyle(.secondary) }
            if !course.locations.isEmpty { Text("地点：" + course.locations.joined(separator: "、")).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 2)
    }
}
