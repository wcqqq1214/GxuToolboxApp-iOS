import GxuAuth
import GxuDesign
import GxuFoundation
import Observation
import ScheduleKit
import ScheduleUI
import SwiftUI

// MARK: 模型

@MainActor @Observable
final class ClassScheduleModel {
    private(set) var schools: [School] = []
    private(set) var majors: [Major] = []
    private(set) var classes: [ClassInfo] = []
    private(set) var isLoadingClasses = false
    private(set) var error: String?

    var term: AcademicTerm?
    var schoolId = ""
    /// 空串 = 全部年级
    var grade = ""
    /// 空串 = 全部专业
    var majorId = ""

    private var api: CampusAPI?
    private var reloadTask: Task<Void, Never>?

    var gradeOptions: [String] {
        let year = Calendar.current.component(.year, from: .now)
        return (0..<8).map { String(year - $0) }
    }

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
        do {
            schools = try await api.schools()
        } catch {
            fail(error)
            return
        }
        // 默认选中用户自己的学院 / 年级 / 专业（和 RN 一致）
        let profile = await Self.profile(services)
        let school = schools.first { $0.name == profile?.college } ?? schools.first { $0.name.contains("学院") }
        schoolId = school?.id ?? ""
        grade = profile.map { String($0.enrollmentYear) } ?? gradeOptions.first ?? ""
        await reloadMajors(preferMajorNamed: profile?.major)
    }

    func schoolChanged() { majorId = ""; reload { await $0.reloadMajors(preferMajorNamed: nil) } }
    func gradeChanged() { majorId = ""; reload { await $0.reloadMajors(preferMajorNamed: nil) } }
    func majorChanged() { reload { await $0.reloadClasses() } }
    func termChanged() { reload { await $0.reloadClasses() } }

    private func reload(_ work: @escaping @MainActor (ClassScheduleModel) async -> Void) {
        reloadTask?.cancel()
        reloadTask = Task { await work(self) }
    }

    private func reloadMajors(preferMajorNamed name: String?) async {
        guard let api else { return }
        do {
            majors = try await api.majors(grade: grade, school: schoolId)
            if let name, !name.isEmpty, majorId.isEmpty, let match = majors.first(where: { $0.majorName.contains(name) }) { majorId = match.majorId }
        } catch {
            if error.isCancellation { return }
            majors = []
        }
        await reloadClasses()
    }

    private func reloadClasses() async {
        guard let api, let term else { return }
        isLoadingClasses = true
        error = nil
        defer { isLoadingClasses = false }
        do {
            classes = try await api.classes(term: term, school: schoolId, major: majorId, grade: grade)
        } catch {
            if error.isCancellation { return }
            classes = []
            fail(error)
        }
    }

    func retry() { reload { model in
        if model.schools.isEmpty, let api = model.api { model.schools = (try? await api.schools()) ?? [] }
        await model.reloadMajors(preferMajorNamed: nil)
    } }

    private func fail(_ error: Error) {
        if error.isCancellation { return }
        self.error = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage
    }
}

// MARK: 班级课表

struct ClassScheduleView: View {
    let exportDestination: (@MainActor () -> AnyView)?

    init(exportDestination: (@MainActor () -> AnyView)? = nil) {
        self.exportDestination = exportDestination
    }

    @Environment(\.services) private var services
    @State private var context = CampusContext()
    @State private var model = ClassScheduleModel()
    @State private var search = ""
    #if DEBUG
    @State private var debugOpened: ClassInfo?
    #endif

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
        .navigationTitle("班级课表")
        .toolbar {
            if let exportDestination {
                NavigationLink { exportDestination() } label: {
                    Label("导出课表", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await context.load(services: services)
            await model.start(services: services, context: context)
        }
    }

    private var visibleClasses: [ClassInfo] {
        let text = search.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? model.classes : model.classes.filter { $0.className.localizedStandardContains(text) }
    }

    private var list: some View {
        List {
            Section("筛选") {
                Picker("学期", selection: Binding(get: { model.term }, set: { model.term = $0; model.termChanged() })) {
                    ForEach(context.terms, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                }
                Picker("学院", selection: Binding(get: { model.schoolId }, set: { model.schoolId = $0; model.schoolChanged() })) {
                    ForEach(model.schools) { Text($0.name).tag($0.id) }
                }
                Picker("年级", selection: Binding(get: { model.grade }, set: { model.grade = $0; model.gradeChanged() })) {
                    Text("全部").tag("")
                    ForEach(model.gradeOptions, id: \.self) { Text("\($0) 级").tag($0) }
                }
                Picker("专业", selection: Binding(get: { model.majorId }, set: { model.majorId = $0; model.majorChanged() })) {
                    Text("全部").tag("")
                    ForEach(model.majors) { Text($0.majorName).tag($0.majorId) }
                }
            }

            Section {
                if model.isLoadingClasses {
                    HStack { ProgressView(); Text("正在查询班级…").foregroundStyle(.secondary) }
                } else if let error = model.error {
                    VStack(alignment: .leading, spacing: GxuDesign.Spacing.s) {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        Button("重试") { model.retry() }
                    }
                } else if visibleClasses.isEmpty {
                    Text(search.isEmpty ? "这个学期没有符合条件的班级，试试换个学期、年级或专业" : "没有名称含“\(search)”的班级").foregroundStyle(.secondary)
                } else {
                    ForEach(visibleClasses) { info in
                        NavigationLink {
                            ClassScheduleDetailView(info: info, term: model.term ?? context.terms[0], context: context)
                        } label: {
                            Text(info.className)
                        }
                    }
                }
            } header: {
                Text(model.classes.isEmpty ? "班级" : "班级（\(visibleClasses.count)）")
            } footer: {
                if !model.classes.isEmpty { Text("点一个班级查看它的课表。") }
            }
        }
        .searchable(text: $search, prompt: "搜索班级名称")
        #if DEBUG
        .navigationDestination(item: $debugOpened) { info in
            ClassScheduleDetailView(info: info, term: model.term ?? context.terms[0], context: context)
        }
        .onChange(of: model.classes) { _, classes in
            if CommandLine.arguments.contains("-GxuCampusOpenFirst"), debugOpened == nil { debugOpened = classes.first }
        }
        #endif
    }
}

/// 一个班级的课表：只读周网格
struct ClassScheduleDetailView: View {
    let info: ClassInfo
    let term: AcademicTerm
    let context: CampusContext
    @Environment(\.services) private var services
    @State private var state: LoadState = .loading

    enum LoadState {
        case loading
        case ready(Schedule, TermCalendar)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading: GxuLoadingView("正在加载课表…")
            case .failed(let message): GxuErrorView(message) { Task { await load() } }
            case .ready(let schedule, let calendar): StaticScheduleView(schedule: schedule, termCalendar: calendar)
            }
        }
        .navigationTitle(info.className)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let calendar = context.termCalendar(for: term) else {
            state = .failed("暂时无法获取\(term.displayName)的开学日期")
            return
        }
        state = .loading
        do {
            let schedule = try await ClassScheduleCache.shared.schedule(term: term, of: info, api: CampusAPI(backend: services.backend))
            state = .ready(schedule, calendar)
        } catch {
            if error.isCancellation { return }
            state = .failed(((error as? GxuError) ?? .network(error.localizedDescription)).userMessage)
        }
    }
}
