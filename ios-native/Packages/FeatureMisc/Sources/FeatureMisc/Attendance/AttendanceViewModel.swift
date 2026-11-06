import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation
import ScheduleKit

/// 考勤页（RN v2.2 `AttendanceScreen`）：学年 + 学期，考勤课表（按周）+ 考勤记录。登录要验证码，不能静默重登：
/// 没登录 / token 过期时 `access` 不是 `.ok`，界面引导去 设置 → 考勤账号。
@MainActor @Observable
final class AttendanceViewModel {
    enum Mode: Hashable { case records, schedule }
    enum Access: Equatable { case ok, notLoggedIn, expired }
    struct Selection: Hashable { var year: Int; var term: Int }

    var mode: Mode = .records
    var selection: Selection { didSet { if oldValue != selection { resetForSelection() } } }
    var week = 1
    /// 只看异常：迟到 / 缺勤，加上最近 7 天的全部记录（RN 默认开）
    var onlyAbnormal = true

    private(set) var years: [Int] = TermOptions.years(enrollmentYear: nil)
    private(set) var totalWeeks = 20
    private(set) var records: [AttendanceRecord] = []
    private(set) var courses: [AttendanceCourse] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var access: Access = .ok
    var isReady = false   // 测试里直接置位，跳过 resolveContext 的网络请求

    private var startDays: [TermStartDay] = []
    private var loadVersion = 0
    private let api: AttendanceAPI
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
        api = AttendanceAPI(backend: services.backend)
        let t = TermOptions.defaultTerm()
        selection = Selection(year: t.year, term: t.term)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-GxuAttendanceSchedule") { mode = .schedule }
        #endif
    }

    /// 默认学期：已开学看当前学期；假期看刚结束的学期（RN `vacationDefault: "past"`，和考试页一致）；学年范围来自个人信息
    func resolveContext() async {
        guard !isReady else { return }
        let context = await resolveTermContext(services: services)
        years = context.years
        startDays = (try? await ScheduleRepository(backend: services.backend, database: services.database).cachedStartDays()) ?? []
        selection = Selection(year: context.term.year, term: context.term.term)
        week = AttendanceWeek.initial(year: selection.year, term: selection.term, startDays: startDays)
        isReady = true
    }

    var summary: AttendanceSummary { AttendanceSummary(records) }
    var visibleRecords: [AttendanceRecord] { AttendanceFilter.visible(records, onlyAbnormal: onlyAbnormal) }
    var abnormalCount: Int { records.filter(\.isAbnormal).count }

    private func resetForSelection() {
        records = []; courses = []; totalWeeks = 20; error = nil
        week = AttendanceWeek.initial(year: selection.year, term: selection.term, startDays: startDays)
        loadVersion += 1
    }

    private func checkAccess() -> Bool {
        switch services.accounts.states[.attendance] {
        case .authenticated?: access = .ok; return true
        case .signedOut?: access = .expired; return false
        default: access = .notLoggedIn; return false
        }
    }

    private func handle(_ error: Error) {
        switch error {
        case GxuError.notLoggedIn(.attendance): access = .notLoggedIn
        case GxuError.sessionExpired(.attendance): access = .expired
        case is CancellationError: break
        default: self.error = (error as? GxuError) ?? .network(error.localizedDescription)
        }
    }

    func load() async {
        guard isReady, checkAccess() else { return }
        error = nil
        loadVersion += 1
        let version = loadVersion
        let selection = selection, week = week, mode = mode
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }
        do {
            // 课表里每节课的出勤状态要对着记录，所以两个页签都取记录
            let loadedRecords = try await api.records(year: selection.year, term: selection.term)
            guard version == loadVersion else { return }   // 期间换了学期或又发起了加载：旧响应作废
            records = loadedRecords
            AttendanceRecordCache.save(services, loadedRecords, year: selection.year, term: selection.term)
            if mode == .schedule {
                guard let userId = services.accounts.attendance?.loginInfo?.userId else { throw GxuError.sessionExpired(.attendance) }
                let loaded = try await api.schedule(year: selection.year, term: selection.term, week: week, userId: userId)
                guard version == loadVersion else { return }
                courses = loaded?.courses ?? []
                totalWeeks = max(loaded?.totalWeeks ?? 20, 1)
                self.week = min(max(self.week, 1), totalWeeks)
            }
        } catch {
            guard version == loadVersion else { return }   // 过期请求的失败不能盖在新数据上
            handle(error)
        }
    }

    /// 课表里这节课的考勤状态：同一天、同一节次范围的记录（RN 的 statusMap：`<date>-<periodRange>`）
    func state(of course: AttendanceCourse) -> AttendanceState? {
        records.first { "\($0.date)-\($0.periodRange)" == course.id }?.state
    }
}

/// 初始周次：所选学期开学日起算，限制在 1…总周数（取不到开学日就是第 1 周）
enum AttendanceWeek {
    static func initial(year: Int, term: Int, startDays: [TermStartDay], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = startDays.first(where: { $0.year == year && $0.term == term }),
              let termCalendar = TermCalendar(start, calendar: calendar) else { return 1 }
        return min(max(termCalendar.week(containing: now), 1), termCalendar.weekCount)
    }
}

enum AttendanceFilter {
    /// RN `RecordScreen`：只看异常时，迟到 / 缺勤保留，其余只保留最近 7 天（含今天）的
    static func visible(_ records: [AttendanceRecord], onlyAbnormal: Bool, now: Date = .now, calendar: Calendar = .current) -> [AttendanceRecord] {
        guard onlyAbnormal else { return records }
        let cutoff = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
        return records.filter { record in
            if record.isAbnormal { return true }
            guard let day = AttendanceDay.parse(record.date, calendar: calendar) else { return true }   // 日期解析不了就不藏
            return day >= cutoff
        }
    }
}

/// 记录按日期分组，日期降序
struct AttendanceDayGroup: Equatable, Identifiable {
    var day: String
    var records: [AttendanceRecord]
    var id: String { day }

    static func group(_ records: [AttendanceRecord]) -> [AttendanceDayGroup] {
        Dictionary(grouping: records) { String($0.date.prefix(10)) }
            .map { AttendanceDayGroup(day: $0.key, records: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// `11月3日 周一`
    var title: String { Self.title(of: day) }

    static func title(of day: String) -> String {
        let cal = Calendar.current
        guard let date = AttendanceDay.parse(day, calendar: cal) else { return day }
        let c = cal.dateComponents([.month, .day], from: date)
        let weekday = ["一", "二", "三", "四", "五", "六", "日"][(cal.component(.weekday, from: date) + 5) % 7]
        return "\(c.month ?? 0)月\(c.day ?? 0)日 周\(weekday)"
    }
}

/// 课表按日期分组（日期升序，组标题和记录页一致）
struct AttendanceCourseGroup: Equatable, Identifiable {
    var day: String
    var courses: [AttendanceCourse]
    var id: String { day }
    var title: String { AttendanceDayGroup.title(of: day) }
}

extension AttendanceDayGroup {
    static func groupCourses(_ courses: [AttendanceCourse]) -> [AttendanceCourseGroup] {
        Dictionary(grouping: courses, by: \.day)
            .map { AttendanceCourseGroup(day: $0.key, courses: $0.value.sorted { $0.firstPeriod < $1.firstPeriod }) }
            .sorted { $0.day < $1.day }
    }
}
