import Foundation
import GxuAuth
import GxuFoundation
import Observation
import ScheduleKit

@MainActor @Observable
final class CampusContext {
    private(set) var terms: [AcademicTerm] = []
    private(set) var defaultTerm: AcademicTerm?
    private(set) var failure: String?
    private var calendars: [AcademicTerm: TermCalendar] = [:]

    func termCalendar(for term: AcademicTerm) -> TermCalendar? { calendars[term] }

    func load(services: AppServices) async {
        let repository = ScheduleRepository(backend: services.backend, database: services.database)
        var startDays = (try? await repository.cachedStartDays()) ?? []
        if startDays.isEmpty || TermResolver.current(in: startDays, now: .now).flatMap({ TermCalendar($0) })?.isEnded(at: .now) == true {
            do { startDays = try await repository.refreshStartDays() } catch {
                if error.isCancellation { return }
                if startDays.isEmpty { failure = ((error as? GxuError) ?? .network(error.localizedDescription)).userMessage }
            }
        }
        var calendars: [AcademicTerm: TermCalendar] = [:]
        for day in startDays {
            if day.academicTerm.isBackendQueryable, let calendar = TermCalendar(day) { calendars[day.academicTerm] = calendar }
        }
        self.calendars = calendars
        terms = calendars.keys.sorted(by: >)
        let current = TermResolver.current(in: startDays, now: .now)?.academicTerm
        defaultTerm = current.flatMap { calendars[$0] != nil ? $0 : nil } ?? terms.first
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-GxuCampusYear"), i + 1 < args.count, let year = Int(args[i + 1]) {
            defaultTerm = terms.first { $0.year == year && $0.term == 1 } ?? defaultTerm
        }
        #endif
        if terms.isEmpty && failure == nil { failure = "暂时无法获取学期信息" }
    }
}

actor ClassScheduleCache {
    static let shared = ClassScheduleCache()
    private var store: [String: Schedule] = [:]
    private var inFlight: [String: Task<Schedule, Error>] = [:]

    func schedule(term: AcademicTerm, of info: ClassInfo, api: CampusAPI) async throws -> Schedule {
        let key = "\(term.year)-\(term.term)-\(info.classId)"
        if let hit = store[key] { return hit }
        if let running = inFlight[key] { return try await running.value }
        let task = Task { try await api.schedule(term: term, of: info) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        let fresh = try await task.value
        store[key] = fresh
        return fresh
    }
}
