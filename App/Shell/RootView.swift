import ExamKit
import FeatureAccount
import FeatureCampus
import FeatureMisc
import GxuAuth
import GxuFoundation
import GxuDesign
import GxuStorage
import ScheduleKit
import ScheduleUI
import SwiftUI

enum AppTab: Hashable {
    case home, schedule, toolbox, settings
}

struct RootView: View {
    @State private var theme = GxuTheme()
    @State private var selection: AppTab = Self.initialTab
    @State private var home: HomeModel
    @State private var scheduleRefresh: ScheduleRefreshCoordinator
    @State private var clock = Date.now
    @State private var toolboxPushed = false
    @State private var preferences = SchedulePreferencesStore(shared: RootView.makeSharedStore())
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.services) private var services

    init() {
        let refresh = ScheduleRefreshCoordinator()
        _scheduleRefresh = State(initialValue: refresh)
        _home = State(initialValue: HomeModel(refreshCoordinator: refresh))
    }

    private static var initialTab: AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-GxuTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "toolbox": return .toolbox
            case "settings": return .settings
            case "schedule": return .schedule
            default: break
            }
        }
        #endif
        return .home
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("今天", systemImage: "sun.horizon", value: AppTab.home) {
                HomeView(model: home, onRequestLogin: { selection = .settings }).gxuAccessoryInset()
            }
            Tab("课表", systemImage: "calendar", value: AppTab.schedule) {
                ScheduleRootView(onRequestLogin: { selection = .settings }, layers: layersProvider,
                                 exportDestination: { AnyView(JwScheduleExportView()) },
                                 refreshCoordinator: scheduleRefresh) { studentId, term in
                    let services = resolvedServices
                    guard services.accounts.studentId == studentId, (1...2).contains(term.term) else { return }
                    await AttendanceRecordCache.refresh(services: services, year: term.year, term: term.term)
                }
                .gxuAccessoryInset()
            }
            Tab("工具箱", systemImage: "square.grid.2x2", value: AppTab.toolbox) {
                ToolboxView(onSelectTab: { selection = $0 }, isPushed: $toolboxPushed).gxuAccessoryInset()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsHomeView().gxuAccessoryInset()
            }
        }
        .gxuTabBarMinimizeOnScroll()
        .gxuTabAccessory(isEnabled: home.phase == .ready && (selection == .schedule || (selection == .toolbox && !toolboxPushed)) && home.hasNextEvent(now: clock)) { NextEventAccessory(model: home) }
        .gxuTheme(theme)
        .environment(preferences)
        .environment(\.scheduleMapPlan, Self.mapPlan)
        .environment(\.scheduleTeacherSupport, TeacherLookup.support(services: resolvedServices))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                clock = .now
            }
        }
        .task(id: accountKey) {
            await home.load(services: resolvedServices)
        }
        .task(id: HomeCacheKey(account: accountKey, unifiedUsername: resolvedServices.accounts.unifiedUsername,
                               day: Calendar.current.startOfDay(for: clock))) {
            await home.observeCache(services: resolvedServices)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await home.load(services: resolvedServices) } }
        }
        #if DEBUG
        .environment(\.services, DemoMode.isEnabled ? DemoMode.services : services)
        #endif
    }
}

extension RootView {
    static let mapPlan: ScheduleMapPlanProvider = { target in
        MapNavigation.plan(text: target.text, keyword: target.mapKeyword)
    }

    private var layersProvider: ScheduleExtraLayersProvider {
        let services = resolvedServices
        return { studentId, term in
            let items = ((try? await ExamRepository(database: services.database).exams(studentId: studentId, term: term)) ?? []).map { ExamItem($0) }
            let exams = items.compactMap { item -> GridExam? in
                guard let start = item.date, let end = Self.examEnd(item.exam.time, start: start) else { return nil }
                return GridExam(id: item.id, title: item.exam.course, location: item.exam.classroom, seat: item.exam.seatText, start: start, end: end, term: term)
            }
            let overrides = await PhyExpOverrides.cached(database: services.database, unifiedUsername: await services.accounts.unifiedUsername)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-GxuDemo") { return ScheduleExtraLayers(exams: exams, overrides: overrides, attendance: DemoMode.attendanceMarks()) }
            #endif
            let attendance = await MainActor.run {
                guard services.accounts.studentId == studentId,
                      let userId = services.accounts.attendance?.loginInfo?.userId else { return [AttendanceMark]() }
                return AttendanceRecordCache.cached(store: services.shared, studentId: studentId, year: term.year,
                                                    term: term.term, attendanceUserId: userId).map {
                    AttendanceMark(date: $0.date, periodRange: $0.periodRange, statusCode: $0.statusCode)
                }
            }
            return ScheduleExtraLayers(exams: exams, overrides: overrides, attendance: attendance)
        }
    }

    private nonisolated static func examEnd(_ time: String, start: Date) -> Date? {
        guard let match = time.firstMatch(of: /\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)/), let h = Int(match.3), let m = Int(match.4) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: start)
    }

    static func makeSharedStore() -> any SharedStore {
        #if DEBUG
        if DemoMode.isEnabled { return UserDefaultsSharedStore(suiteName: nil) }
        #endif
        return UserDefaultsSharedStore()
    }

    private struct AccountKey: Hashable {
        var studentId: String?
        var state: AuthState?
        var sessionID: UUID
    }

    private struct HomeCacheKey: Hashable {
        var account: AccountKey
        var unifiedUsername: String?
        var day: Date
    }

    private var accountKey: AccountKey {
        let accounts = resolvedServices.accounts
        return AccountKey(studentId: accounts.studentId, state: accounts.states[.jw], sessionID: accounts.jwSessionID)
    }

    private var resolvedServices: AppServices {
        #if DEBUG
        DemoMode.isEnabled ? DemoMode.services : services
        #else
        services
        #endif
    }
}

#Preview { RootView() }

