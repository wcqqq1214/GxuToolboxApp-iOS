import Foundation
import GxuAuth
import GxuFoundation
import Observation
import ScheduleKit

final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() { lock.withLock { value = true } }
}

@MainActor @Observable
final class EmptyClassroomModel {
    enum Mode: String, CaseIterable, Identifiable {
        case time = "按时间", room = "按教室"
        var id: String { rawValue }
    }

    var mode: Mode = .time {
        didSet { if mode != oldValue { persist() } }
    }
    private(set) var term: AcademicTerm?
    private(set) var snapshots: [WeekSnapshot] = []
    private(set) var setupError: String?
    private(set) var hasFinishedSetup = false
    private(set) var cacheRevision = 0

    var queryWeek: Int?
    var queryDay: Int?
    var startPeriod = 1
    var endPeriod = EmptyClassroomConstants.periods
    var selectedBuildings: [String] = []
    var selectedRooms: [RoomRecord] = []
    var keyword = ""
    var sortMode: TimeQuerySortMode = .default
    var sortDirection: TimeQuerySortDirection = .desc
    private(set) var results: [RoomAvailabilityResult] = []
    private(set) var totalCount = 0
    private(set) var hasMore = false
    private(set) var isQuerying = false
    private(set) var queryError: String?
    private(set) var buildingSummaries: [EmptyClassroomFloor.BuildingGroup] = []
    private(set) var cachedDays: [Int] = []

    private(set) var room: RoomRecord?
    var roomWeek = 1
    private(set) var roomRuns: [FreeRun] = []
    private(set) var roomError: String?

    let context: CampusContext
    private(set) var repository: EmptyClassroomRepository?
    private var queryGeneration = 0
    private var page = 1
    private let defaults: UserDefaults

    init(context: CampusContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    var cachedWeeks: [Int] { snapshots.map(\.week) }
    func snapshot(week: Int) -> WeekSnapshot? { snapshots.first { $0.week == week } }
    var year: Int { term?.year ?? 0 }
    var logicalTerm: Int { term?.term ?? 1 }

    func start(services: AppServices) async {
        guard repository == nil else { return }
        repository = EmptyClassroomRepository(database: services.database)
        await context.load(services: services)
        guard let defaultTerm = context.defaultTerm else {
            setupError = context.failure ?? "暂时无法获取学期信息"
            hasFinishedSetup = true
            return
        }
        restoreSelection(defaultTerm: defaultTerm)
        #if DEBUG
        if CommandLine.arguments.contains("-GxuEmptyDemo") { await seedDemo(services: services) }
        #endif
        await reloadSnapshots()
        hasFinishedSetup = true
    }

    func select(term newTerm: AcademicTerm) async {
        guard newTerm != term else { return }
        term = newTerm
        room = nil
        roomWeek = defaultWeek(for: newTerm)
        queryWeek = nil
        queryDay = nil
        persist()
        await reloadSnapshots()
    }

    func cacheChanged() async {
        cacheRevision += 1
        await reloadSnapshots()
    }

    private func defaultWeek(for term: AcademicTerm) -> Int {
        guard let calendar = context.termCalendar(for: term), calendar.isStarted(at: .now) else { return 1 }
        return min(max(calendar.clampedWeek(at: .now), 1), EmptyClassroomConstants.maxWeeks)
    }

    private func reloadSnapshots() async {
        guard let repository, let term else { return }
        do {
            snapshots = try await repository.listWeeks(year: term.year, term: term.term)
            setupError = nil
        } catch {
            setupError = "读取缓存失败：\(error.localizedDescription)"
            return
        }
        buildingSummaries = EmptyClassroomFloor.groupBuildings((try? await repository.listRoomBuildings()) ?? [])
        if queryWeek == nil || !cachedWeeks.contains(queryWeek ?? 0) {
            queryWeek = nearestCachedWeek(to: defaultWeek(for: term))
            queryDay = nil
        }
        await reloadCachedDays()
        if let id = room?.id, (try? await repository.listRooms(inBuilding: room?.building ?? "").contains { $0.id == id }) != true { room = nil }
        await loadRoomRuns()
        await runQuery(reset: true)
    }

    private func nearestCachedWeek(to week: Int) -> Int? {
        cachedWeeks.min { abs($0 - week) < abs($1 - week) }
    }

    func reloadCachedDays() async {
        guard let repository, let term, let week = queryWeek else { cachedDays = []; return }
        cachedDays = (try? await repository.completedDays(year: term.year, term: term.term, week: week)) ?? []
        if queryDay == nil || !cachedDays.contains(queryDay ?? 0) {
            let today = context.termCalendar(for: term).map { $0.weekday(of: .now) }
            queryDay = cachedDays.contains(today ?? 0) ? today : cachedDays.first
        }
    }

    func dateLabel(week: Int, day: Int) -> String? {
        guard let term, let calendar = context.termCalendar(for: term) else { return nil }
        let date = calendar.date(week: week, weekday: day)
        let c = calendar.calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)-\(String(format: "%02d", c.day ?? 0))"
    }


    var hasRoomFilters: Bool { !selectedBuildings.isEmpty || !selectedRooms.isEmpty }

    func clearRoomFilters() async {
        selectedBuildings = []
        selectedRooms = []
        await runQuery(reset: true)
    }

    func runQuery(reset: Bool) async {
        if reset { queryGeneration += 1; page = 1 }
        guard let repository, let term, let week = queryWeek, let day = queryDay else {
            results = []; totalCount = 0; hasMore = false; isQuerying = false; queryError = nil
            return
        }
        let generation = queryGeneration
        let requestedPage = page
        var query = AvailableRoomsQuery(year: term.year, term: term.term, week: week, day: day, startPeriod: min(startPeriod, endPeriod), endPeriod: max(startPeriod, endPeriod))
        query.buildings = selectedBuildings
        query.roomIds = selectedRooms.map(\.id)
        query.keyword = keyword
        query.page = requestedPage
        query.sortMode = sortMode
        query.sortDirection = sortDirection
        query.includeTotal = reset
        isQuerying = true
        do {
            let result = try await repository.listAvailableRooms(query)
            guard generation == queryGeneration else { return }
            let sorted = EmptyClassroomLogic.sort(EmptyClassroomLogic.buildResults(result.rows), mode: sortMode, direction: sortDirection)
            results = reset ? sorted : results + sorted
            if reset { totalCount = result.totalCount }
            hasMore = result.hasMore
            queryError = nil
        } catch {
            guard generation == queryGeneration else { return }
            queryError = error.localizedDescription
        }
        if generation == queryGeneration { isQuerying = false }
    }

    func loadMore() async {
        guard hasMore, !isQuerying else { return }
        page += 1
        await runQuery(reset: false)
    }

    func toggleSortDirection() { sortDirection = sortDirection == .desc ? .asc : .desc }


    func select(room newRoom: RoomRecord?) async {
        room = newRoom
        persist()
        await loadRoomRuns()
    }

    func loadRoomRuns() async {
        guard let repository, let term, let room else { roomRuns = []; return }
        do {
            let rows = try await repository.roomWeekSlots(year: term.year, term: term.term, roomId: room.id, weeks: [roomWeek])
            guard room.id == self.room?.id else { return }
            roomRuns = EmptyClassroomLogic.buildFreeRuns(rows)
            roomError = nil
        } catch {
            roomError = error.localizedDescription
        }
    }


    private static let key = "emptyClassroom.selection"

    private func persist() {
        guard let term else { return }
        defaults.set(["year": term.year, "term": term.term, "week": roomWeek, "roomId": room?.id ?? 0, "mode": mode.rawValue] as [String: Any], forKey: Self.key)
    }

    private func restoreSelection(defaultTerm: AcademicTerm) {
        var chosen = defaultTerm
        roomWeek = defaultWeek(for: defaultTerm)
        if let saved = defaults.dictionary(forKey: Self.key),
           let year = saved["year"] as? Int, let termValue = saved["term"] as? Int, let week = saved["week"] as? Int,
           let restored = context.terms.first(where: { $0.year == year && $0.term == termValue }),
           (1...EmptyClassroomConstants.maxWeeks).contains(week) {
            chosen = restored
            roomWeek = week
            if let raw = saved["mode"] as? String, let mode = Mode(rawValue: raw) { self.mode = mode }
            if let id = saved["roomId"] as? Int64 ?? (saved["roomId"] as? Int).map(Int64.init), id > 0 { pendingRoomId = id }
        }
        term = chosen
        if pendingRoomId != nil { Task { await self.restoreRoom() } }
    }

    private var pendingRoomId: Int64?

    private func restoreRoom() async {
        guard let repository, let id = pendingRoomId, let term else { return }
        pendingRoomId = nil
        guard let found = try? await repository.room(id: id), self.term == term, room == nil else { return }
        room = found
        await loadRoomRuns()
    }
}

@MainActor @Observable
final class EmptyClassroomCacheController {
    enum State: Equatable {
        case idle
        case running(week: Int, day: Int, period: Int)
        case finished(week: Int, complete: Bool, canceled: Bool)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var completedDays: [Int] = []
    private(set) var lastStartedAt: Date?

    private var task: Task<Void, Never>?
    private var cancelFlag = CancelFlag()
    private let defaults: UserDefaults
    private static let startedAtKey = "emptyClassroom.lastCacheStartedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.startedAtKey)
        lastStartedAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    var isRunning: Bool { if case .running = state { true } else { false } }
    func remainingCooldown(now: Date = .now) -> TimeInterval { CacheRunner.remainingCooldown(lastStartedAt: lastStartedAt, now: now) }

    func start(week: Int, term: AcademicTerm, services: AppServices, model: EmptyClassroomModel) {
        guard !isRunning, remainingCooldown() == 0 else { return }
        guard services.accounts.states[.jw] != .noAccount else {
            state = .failed("请先登录教务账号")
            return
        }
        let range = CacheRunnerRange(year: term.year, term: term.term, week: week)
        guard term.isBackendQueryable else {
            state = .failed("暂不支持缓存\(term.displayName)")
            return
        }
        let repository = EmptyClassroomRepository(database: services.database)
        let api = EmptyClassroomAPI(backend: services.backend)
        let flag = CancelFlag()
        cancelFlag = flag
        completedDays = []
        state = .running(week: week, day: 1, period: 0)
        task = Task { [weak self] in
            let deps = CacheRunnerDeps(
                completedDays: { try await repository.completedDays(year: $0.year, term: $0.term, week: $0.week) },
                fetchDay: { range, day, onPeriod in try await api.fetchDay(year: range.year, term: range.term, week: range.week, day: day, onPeriod: onPeriod) },
                saveDay: { range, day, payload in try await repository.saveDay(year: range.year, term: range.term, week: range.week, day: day, payload: payload) },
                completeWeek: { try await repository.completeWeek(year: $0.year, term: $0.term, week: $0.week) },
                beforeFirstRequest: { Task { @MainActor in self?.markStarted() } },
                onProgress: { day, period, done in Task { @MainActor in self?.progress(week: week, day: day, period: period, done: done) } },
                onDaySaved: { _, done in Task { @MainActor in self?.completedDays = done } },
                shouldCancel: { flag.isSet }
            )
            do {
                let result = try await CacheRunner.runWeek(range, deps: deps)
                await MainActor.run {
                    self?.completedDays = result.completedDays
                    self?.state = .finished(week: week, complete: result.complete, canceled: result.canceled)
                }
            } catch {
                await MainActor.run {
                    if error.isCancellation { self?.state = .finished(week: week, complete: false, canceled: true) } else {
                        self?.state = .failed(((error as? GxuError) ?? .network(error.localizedDescription)).userMessage)
                    }
                }
            }
            await model.cacheChanged()
        }
    }

    func cancel() {
        cancelFlag.set()
        task?.cancel()
    }

    private func markStarted() {
        let now = Date.now
        lastStartedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: Self.startedAtKey)
    }

    private func progress(week: Int, day: Int, period: Int, done: [Int]) {
        guard isRunning else { return }
        state = .running(week: week, day: day, period: period)
        completedDays = done
    }

    func dismissResult() { if !isRunning { state = .idle } }
}

#if DEBUG
extension EmptyClassroomModel {
    fileprivate func seedDemo(services: AppServices) async {
        guard let repository, let term else { return }
        let weeks = [defaultWeek(for: term), defaultWeek(for: term) + 1]
        let rooms: [(String, String, String, Int)] = [
            ("西3教", "西3-101", "多媒体教室", 120), ("西3教", "西3-203", "多媒体教室", 90), ("西3教", "西3-406", "普通教室", 60),
            ("西2教", "西2-302", "多媒体教室", 80), ("东10教", "东10-B406", "多媒体教室", 150), ("东10教", "东10-A105", "阶梯教室", 200),
            ("", "报告厅", "报告厅", 300),
        ]
        for week in weeks where week >= 1 && week <= EmptyClassroomConstants.maxWeeks {
            for day in 1...EmptyClassroomConstants.days {
                var payloadRooms: [String: RoomPayload] = [:], free: [String: [Int]] = [:]
                for (index, item) in rooms.enumerated() {
                    let key = emptyRoomKey(item.0, item.1)
                    payloadRooms[key] = RoomPayload(key: key, building: item.0, name: item.1, placeType: item.2, seatCount: item.3, seatCountForExam: nil, owner: "", allowToUse: "")
                    let start = (index + day) % 5 + 1
                    free[key] = Array(start...min(start + 2 + index % 3, EmptyClassroomConstants.periods))
                }
                try? await repository.saveDay(year: term.year, term: term.term, week: week, day: day, payload: DayPayload(day: day, rooms: payloadRooms, freePeriods: free))
            }
        }
    }
}
#endif
