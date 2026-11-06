import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import ScheduleKit
import SwiftUI

/// 某一时刻某个班正在上的课
struct ClassInSession: Identifiable, Sendable {
    let info: ClassInfo
    let course: TheoryCourse
    var id: String { info.classId }
}

@MainActor @Observable
final class FullScheduleModel {
    enum Phase: Equatable {
        case idle
        case running
        case finished
        case failed(String)
    }

    private(set) var schools: [School] = []
    private(set) var phase: Phase = .idle
    private(set) var total = 0
    private(set) var checked = 0
    private(set) var failedCount = 0
    private(set) var results: [ClassInSession] = []
    private(set) var majorNames: [String: String] = [:]

    var term: AcademicTerm?
    var schoolId = ""
    var moment = ClassMoment(week: 1, weekday: 1, period: 1)

    private var api: CampusAPI?
    private var runTask: Task<Void, Never>?
    /// 每次 `run()` 加一。上一轮还在飞的请求回来时，generation 对不上就丢弃，不能混进新一轮的结果
    private var generation = 0
    private nonisolated static let concurrency = 6

    /// 本人资料（学院 / 年级 / 专业用来给筛选条件设默认值）：先缓存，没有再联网；拿不到就不设默认值
    private static func profile(_ services: AppServices) async -> UserProfile? {
        guard let studentId = await services.accounts.studentId else { return nil }
        return try? await services.profiles.profile(studentId: studentId, refresh: false)
    }

    func start(services: AppServices, context: CampusContext) async {
        guard api == nil else { return }
        let api = CampusAPI(backend: services.backend)
        self.api = api
        term = context.defaultTerm
        if let term, let calendar = context.termCalendar(for: term) { moment = .now(term: calendar) }
        do {
            // 和 RN 一致：只列“…学院”
            schools = try await api.schools().filter { $0.name.hasSuffix("学院") }
        } catch {
            phase = .failed(((error as? GxuError) ?? .network(error.localizedDescription)).userMessage)
            return
        }
        let profile = await Self.profile(services)
        schoolId = schools.first { $0.name == profile?.college }?.id ?? schools.first?.id ?? ""
        #if DEBUG
        // 截图自查：`-GxuCampusMoment 3,2,3`（周,星期,节）和 `-GxuCampusAutoRun`
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-GxuCampusMoment"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: ",").compactMap { Int($0) }
            if parts.count == 3 { moment = ClassMoment(week: parts[0], weekday: parts[1], period: parts[2]) }
        }
        if args.contains("-GxuCampusAutoRun") { run() }
        #endif
    }

    func resetMoment(context: CampusContext) {
        if let term, let calendar = context.termCalendar(for: term) { moment = .now(term: calendar) }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        if phase == .running { phase = .idle }
    }

    func run() {
        guard let api, let term, !schoolId.isEmpty else { return }
        runTask?.cancel()
        generation += 1
        let gen = generation
        let (school, moment) = (schoolId, moment)
        results = []
        total = 0
        checked = 0
        failedCount = 0
        phase = .running
        runTask = Task { [weak self] in
            do {
                async let majors = (try? await api.majors(grade: "", school: school)) ?? []
                let classes = try await api.classes(term: term, school: school)
                let names = Dictionary(uniqueKeysWithValues: (await majors).map { ($0.majorId, $0.majorName) })
                guard !Task.isCancelled, await self?.generation == gen else { return }
                self?.begin(total: classes.count, majorNames: names)
                await Self.scan(classes: classes, term: term, moment: moment, api: api) { outcome in
                    self?.record(outcome, generation: gen)
                }
                if !Task.isCancelled, self?.generation == gen { self?.phase = .finished }
            } catch {
                if error.isCancellation || self?.generation != gen { return }
                self?.phase = .failed(((error as? GxuError) ?? .network(error.localizedDescription)).userMessage)
            }
        }
    }

    private func begin(total: Int, majorNames: [String: String]) {
        self.total = total
        self.majorNames = majorNames
    }

    enum Outcome: Sendable {
        case inSession(ClassInSession)
        case free
        case failed
    }

    private func record(_ outcome: Outcome, generation gen: Int) {
        guard gen == generation else { return }
        checked += 1
        switch outcome {
        case .inSession(let item): results.append(item)
        case .free: break
        case .failed: failedCount += 1
        }
    }

    /// 并发度受限地逐个查班级课表。单个班级失败不影响整体。
    private nonisolated static func scan(
        classes: [ClassInfo], term: AcademicTerm, moment: ClassMoment, api: CampusAPI,
        report: @escaping @Sendable @MainActor (Outcome) -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var iterator = classes.makeIterator()
            func addNext() -> Bool {
                guard let info = iterator.next() else { return false }
                group.addTask {
                    if Task.isCancelled { return }
                    do {
                        let schedule = try await ClassScheduleCache.shared.schedule(term: term, of: info, api: api)
                        let outcome: Outcome = Occupancy.course(in: schedule, at: moment).map { .inSession(ClassInSession(info: info, course: $0)) } ?? .free
                        await report(outcome)
                    } catch {
                        if !error.isCancellation { await report(.failed) }
                    }
                }
                return true
            }
            for _ in 0..<concurrency where addNext() {}
            while await group.next() != nil {
                if Task.isCancelled { group.cancelAll(); break }
                _ = addNext()
            }
        }
    }

    /// 按专业分组，组内按班级名排序；组按专业名排序
    var grouped: [(major: String, items: [ClassInSession])] {
        Dictionary(grouping: results, by: \.info.majorId)
            .map { id, items in
                (major: majorNames[id] ?? "其他专业", items: items.sorted { $0.info.className < $1.info.className })
            }
            .sorted { $0.major < $1.major }
    }
}

struct FullScheduleView: View {
    @Environment(\.services) private var services
    @State private var context = CampusContext()
    @State private var model = FullScheduleModel()
    /// 出结果后查询条件折叠成一行，点“修改”再展开
    @State private var editingFilters = false

    var body: some View {
        Group {
            if let failure = context.failure {
                GxuErrorView(failure) { Task { await context.load(services: services) } }
            } else if context.terms.isEmpty {
                GxuLoadingView("正在加载…")
            } else {
                list
            }
        }
        .navigationTitle("全校课表")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await context.load(services: services)
            await model.start(services: services, context: context)
        }
        .onDisappear { model.cancel() }
    }

    private var list: some View {
        List {
            if showFilters {
                Section {
                    Picker("学院", selection: $model.schoolId) {
                        ForEach(model.schools) { Text($0.name).tag($0.id) }
                    }
                    MomentPickers(model: model, context: context)
                } header: {
                    Text("查询条件")
                } footer: {
                    Text("查看这一刻这个学院有哪些班级正在上课。需要逐个读取班级课表，学院班级多时要等一会儿，读取过的班级课表会缓存。")
                }

                Section {
                    Button("开始查询", systemImage: "magnifyingglass") {
                        editingFilters = false
                        model.run()
                    }
                    .disabled(model.schoolId.isEmpty)
                }
            } else {
                Section {
                    Button { editingFilters = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.schools.first { $0.id == model.schoolId }?.name ?? "").foregroundStyle(Color.primary)
                                Text(momentSummary).font(.footnote).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            if model.phase == .running {
                                Button("停止", role: .destructive) { model.cancel() }.buttonStyle(.borderless)
                            } else {
                                Text("修改").font(.subheadline)
                            }
                        }
                    }
                }
            }

            resultSections
        }
    }

    /// 出结果（或正在查询）后条件折叠，结果成为页面主体
    private var showFilters: Bool {
        switch model.phase {
        case .idle, .failed: true
        case .running, .finished: editingFilters
        }
    }

    private var momentSummary: String {
        let term = model.term?.displayName ?? ""
        let moment = model.moment
        return "\(term) · 第 \(moment.week) 周 \(WeekdayName.full(moment.weekday)) 第 \(moment.period) 节"
    }

    @ViewBuilder
    private var resultSections: some View {
        switch model.phase {
        case .idle:
            EmptyView()
        case .failed(let message):
            Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
        case .running, .finished:
            Section {
                if model.total > 0 {
                    VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                        ProgressView(value: Double(model.checked), total: Double(max(model.total, 1)))
                        Text(progressText).font(.footnote).foregroundStyle(.secondary)
                    }
                } else if model.phase == .running {
                    HStack { ProgressView(); Text("正在获取班级列表…").foregroundStyle(.secondary) }
                }
            }
            if model.phase == .finished, model.results.isEmpty {
                Section { Text("这个时刻没有班级上课").foregroundStyle(.secondary) }
            }
            ForEach(model.grouped, id: \.major) { group in
                Section("\(group.major)（\(group.items.count)）") {
                    ForEach(group.items) { item in
                        NavigationLink {
                            ClassScheduleDetailView(info: item.info, term: model.term ?? context.terms[0], context: context)
                        } label: { SessionRow(item: item) }
                    }
                }
            }
        }
    }

    private var progressText: String {
        var text = "已查询 \(model.checked) / \(model.total) 个班级，\(model.results.count) 个班正在上课"
        if model.failedCount > 0 { text += "，\(model.failedCount) 个班级读取失败" }
        return text
    }
}

private struct SessionRow: View {
    let item: ClassInSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.info.className)
            Text([item.course.courseName, item.course.venueName].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 学期 + 周次 + 星期 + 节次；“现在”一键回到当前时刻
private struct MomentPickers: View {
    @Bindable var model: FullScheduleModel
    let context: CampusContext

    var body: some View {
        Picker("学期", selection: Binding(get: { model.term }, set: { model.term = $0; model.resetMoment(context: context) })) {
            ForEach(context.terms, id: \.self) { Text($0.displayName).tag(Optional($0)) }
        }
        let weekCount = model.term.flatMap { context.termCalendar(for: $0)?.weekCount } ?? 20
        Picker("周次", selection: $model.moment.week) {
            ForEach(1...weekCount, id: \.self) { Text("第 \($0) 周").tag($0) }
        }
        Picker("星期", selection: $model.moment.weekday) {
            ForEach(1...7, id: \.self) { Text(WeekdayName.full($0)).tag($0) }
        }
        Picker("节次", selection: $model.moment.period) {
            ForEach(ClassPeriods.all, id: \.number) { Text("第 \($0.number) 节  \($0.startText)").tag($0.number) }
        }
        Button("回到现在", systemImage: "clock.arrow.circlepath") { model.resetMoment(context: context) }
    }
}
