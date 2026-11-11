import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation
import ScheduleKit

@MainActor @Observable
final class AttendanceViewModel {
    enum Mode: Hashable { case records, schedule }
    enum Access: Equatable { case ok, notLoggedIn, expired }
    struct Selection: Hashable { var year: Int; var term: Int }

    var mode: Mode = .records
    var selection: Selection { didSet { if oldValue != selection { resetForSelection() } } }
    var week = 1
    var recordFilter: AttendanceFilter = .abnormalAndRecent

    private(set) var years: [Int] = TermOptions.years(enrollmentYear: nil)
    private(set) var totalWeeks = 20
    private(set) var records: [AttendanceRecord] = []
    private(set) var courses: [AttendanceCourse] = []
    private(set) var isLoading = false
    private(set) var error: GxuError?
    private(set) var access: Access = .ok
    var isReady = false

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
    var visibleRecords: [AttendanceRecord] { recordFilter.visible(records) }
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
        let studentId = services.accounts.studentId
        let token = services.accounts.attendance?.token
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }
        do {
            let loadedRecords = try await api.records(year: selection.year, term: selection.term)
            guard version == loadVersion, !Task.isCancelled,
                  services.accounts.studentId == studentId,
                  services.accounts.attendance?.token == token else { return }
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
            guard version == loadVersion else { return }
            handle(error)
        }
    }

    func state(of course: AttendanceCourse) -> AttendanceState? {
        records.first { "\($0.date)-\($0.periodRange)" == course.id }?.state
    }
}

enum AttendanceWeek {
    static func initial(year: Int, term: Int, startDays: [TermStartDay], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = startDays.first(where: { $0.year == year && $0.term == term }),
              let termCalendar = TermCalendar(start, calendar: calendar) else { return 1 }
        return min(max(termCalendar.week(containing: now), 1), termCalendar.weekCount)
    }
}

enum AttendanceFilter: Hashable {
    case all, abnormalAndRecent, abnormal

    func visible(_ records: [AttendanceRecord], now: Date = .now, calendar: Calendar = .current) -> [AttendanceRecord] {
        switch self {
        case .all:
            return records
        case .abnormal:
            return records.filter(\.isAbnormal)
        case .abnormalAndRecent:
            let cutoff = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) ?? now
            return records.filter { record in
                if record.isAbnormal { return true }
                guard let day = AttendanceDay.parse(record.date, calendar: calendar) else { return true }
                return day >= cutoff
            }
        }
    }
}

struct AttendanceDayGroup: Equatable, Identifiable {
    var day: String
    var records: [AttendanceRecord]
    var id: String { day }

    static func group(_ records: [AttendanceRecord]) -> [AttendanceDayGroup] {
        Dictionary(grouping: records) { String($0.date.prefix(10)) }
            .map { AttendanceDayGroup(day: $0.key, records: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var title: String { Self.title(of: day) }

    static func title(of day: String) -> String {
        let cal = Calendar.current
        guard let date = AttendanceDay.parse(day, calendar: cal) else { return day }
        let c = cal.dateComponents([.month, .day], from: date)
        let weekday = ["一", "二", "三", "四", "五", "六", "日"][(cal.component(.weekday, from: date) + 5) % 7]
        return "\(c.month ?? 0)月\(c.day ?? 0)日 周\(weekday)"
    }
}

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
