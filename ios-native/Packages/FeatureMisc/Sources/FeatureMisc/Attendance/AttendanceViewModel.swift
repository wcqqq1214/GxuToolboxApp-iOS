import Foundation
import GxuAuth
import GxuFoundation
import Observation

/// 考勤页：记录（分页）+ 考勤课表（按周）。登录要验证码，不能静默重登：
/// 没登录 / token 过期时 `access` 不是 `.ok`，界面引导去 设置 → 考勤账号。
@MainActor @Observable
final class AttendanceViewModel {
    enum Mode: Hashable { case records, schedule }
    enum Access: Equatable { case ok, notLoggedIn, expired }

    var mode: Mode = .records
    var calendarId: Int? { didSet { if oldValue != calendarId { resetForCalendar() } } }
    var week = 1

    private(set) var calendars: [AttendanceCalendar] = []
    private(set) var records: [AttendanceRecord] = []
    private(set) var totalRecords = 0
    private(set) var hasMore = false
    private(set) var courses: [AttendanceCourse] = []
    /// 整个学期的记录（课表里给每节课标状态用）
    private(set) var termRecords: [AttendanceRecord] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var access: Access = .ok

    private var page = 1
    /// 每次 load / 换学期都递增；下拉刷新的请求不会被 `.task(id:)` 取消，旧响应回来时靠它判断是否已过期
    private var loadVersion = 0
    private let api: AttendanceAPI
    private let services: AppServices
    private let pageSize = 20

    init(services: AppServices) {
        self.services = services
        api = AttendanceAPI(backend: services.backend)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-GxuAttendanceSchedule") { mode = .schedule }
        #endif
    }

    var calendar: AttendanceCalendar? { calendars.first { $0.calendarId == calendarId } }
    var summary: AttendanceSummary { AttendanceSummary(termRecords.isEmpty ? records : termRecords) }

    private func resetForCalendar() {
        records = []; termRecords = []; courses = []; page = 1; hasMore = false; totalRecords = 0
        if let calendar { week = calendar.currentWeek() }
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
        guard checkAccess() else { return }
        error = nil
        loadVersion += 1
        var version = loadVersion
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }
        do {
            if calendars.isEmpty {
                let loaded = try await api.calendars()
                guard version == loadVersion else { return }
                calendars = loaded
                if calendarId == nil {
                    calendarId = (calendars.first { $0.isCurrent } ?? calendars.last)?.calendarId   // 设置默认学期会触发 didSet 递增版本，这不是用户切换，沿用新版本
                    version = loadVersion
                }
            }
            guard let calendarId else { return }
            switch mode {
            case .records:
                let first = try await api.records(calendarId: calendarId, page: 1, pageSize: pageSize)
                guard version == loadVersion else { return }   // 期间换了学期或又发起了加载：旧响应作废
                records = first.records
                page = first.pageIndex
                totalRecords = first.totalRecord
                hasMore = first.pageIndex < first.totalPage
                termRecords = []
            case .schedule:
                guard let userId = services.accounts.attendance?.loginInfo?.userId else { throw GxuError.sessionExpired(.attendance) }
                async let table = api.schedule(calendarId: calendarId, week: week, userId: userId)
                async let all = api.records(calendarId: calendarId, page: 1, pageSize: 1000)
                let loadedCourses = try await table
                let loadedRecords = try await all.records
                guard version == loadVersion else { return }
                courses = loadedCourses
                termRecords = loadedRecords
            }
        } catch {
            guard version == loadVersion else { return }   // 过期请求的失败不能盖在新数据上
            handle(error)
        }
    }

    func loadMore() async {
        guard mode == .records, hasMore, !isLoading, access == .ok, let calendarId else { return }
        let version = loadVersion
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }
        do {
            let next = try await api.records(calendarId: calendarId, page: page + 1, pageSize: pageSize)
            guard version == loadVersion else { return }
            records += next.records
            page = next.pageIndex
            hasMore = next.pageIndex < next.totalPage
        } catch {
            guard version == loadVersion else { return }
            handle(error)
        }
    }

    /// 课表里这节课的考勤状态（同一天、同课程名的记录）
    func state(of course: AttendanceCourse) -> AttendanceState? {
        termRecords.first { $0.day.hasPrefix(course.day) && $0.courseName == course.name }?.state
    }
}

/// 记录按日期分组，日期降序
struct AttendanceDayGroup: Equatable, Identifiable {
    var day: String
    var records: [AttendanceRecord]
    var id: String { day }

    static func group(_ records: [AttendanceRecord]) -> [AttendanceDayGroup] {
        Dictionary(grouping: records) { String($0.day.prefix(10)) }
            .map { AttendanceDayGroup(day: $0.key, records: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// `11月3日 周一`
    var title: String {
        let cal = Calendar.current
        guard let date = AttendanceDay.parse(day, calendar: cal) else { return day }
        let c = cal.dateComponents([.month, .day], from: date)
        let weekday = ["一", "二", "三", "四", "五", "六", "日"][(cal.component(.weekday, from: date) + 5) % 7]
        return "\(c.month ?? 0)月\(c.day ?? 0)日 周\(weekday)"
    }
}
