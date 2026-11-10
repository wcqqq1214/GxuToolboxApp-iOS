import Foundation
import GxuAuth
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Testing
@testable import FeatureCampus

/// 按请求参数返回响应的假后端
private final class ClosureBackend: BackendAPI, @unchecked Sendable {
    typealias Handler = @Sendable ([String: String]) async throws -> String
    private let handler: Handler
    private let lock = NSLock()
    private var recorded: [[String: String]] = []
    init(_ handler: @escaping Handler) { self.handler = handler }
    var queries: [[String: String]] { lock.withLock { recorded } }

    func get<T: Decodable & Sendable>(_ path: String, query: [String: String], auth: AuthSystem?, as type: T.Type) async throws -> T {
        lock.withLock { recorded.append(query) }
        let body = try await handler(query)
        // 和真实后端客户端一样：解码失败包成 GxuError.decoding
        do { return try JSONDecoder().decode(type, from: Data(body.utf8)) } catch { throw GxuError.decoding(String(describing: error)) }
    }
    func post<T: Decodable & Sendable, Body: Encodable & Sendable>(_ path: String, body: Body, auth: AuthSystem?, as type: T.Type) async throws -> T {
        throw GxuError.network("unstubbed")
    }
}

private func envelope(items: [(String, String)], totalCount: Int? = nil, totalPage: Int? = nil) -> String {
    let rows = items.map { #"{"classroomName":"\#($0.1)","building":"\#($0.0)","placeType":"多媒体","seatCount":60,"seatCountForExam":"40","owner":null}"# }.joined(separator: ",")
    var page = #""items":[\#(rows)]"#
    if let totalCount { page += #","totalCount":"\#(totalCount)""# }
    if let totalPage { page += #","totalPage":\#(totalPage)"# }
    return #"{"code":200,"message":"ok","data":{\#(page)}}"#
}

struct EmptyClassroomLogicTests {
    @Test func freeRunsMergeAdjacentPeriodsOnly() {
        let rows = [(1, 1, 3), (1, 1, 1), (1, 1, 2), (1, 1, 2), (1, 1, 5), (1, 2, 1), (1, 1, 99), (0, 1, 1)]
            .map { FreePeriodRow(week: $0.0, day: $0.1, period: $0.2) }
        let runs = EmptyClassroomLogic.buildFreeRuns(rows)
        #expect(runs.map(\.id) == ["1-1-1-3", "1-1-5-5", "1-2-1-1"])   // 乱序、重复、越界行都被处理；不跨天
    }

    @Test func seatCountsAndNullsDecodeLeniently() throws {
        let page = try JSONDecoder().decode(ClassroomPage.self, from: Data(#"{"totalCount":"3","items":[{"classroomName":"101","building":"A","seatCount":60,"seatCountForExam":null,"owner":7}]}"#.utf8))
        #expect(page.totalCount == 3 && page.items[0].seatCount == "60" && page.items[0].seatCountForExam == "" && page.items[0].owner == "7")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ClassroomPage.self, from: Data(#"{"items":"nope"}"#.utf8)) }
    }

    private func room(_ id: Int64, _ building: String, _ name: String) -> RoomRecord {
        RoomRecord(id: id, building: building, name: name, placeType: "", seatCount: nil, seatCountForExam: nil, owner: "", allowToUse: "")
    }

    @Test func resultsGroupSortAndLabelEmptyBuilding() {
        let rows = [(1, "A", "101", [1, 2, 3]), (2, "", "X", [5]), (3, "A", "102", [1])].flatMap { id, b, n, ps in
            ps.map { AvailableRoomPeriodRow(room: room(Int64(id), b, n), week: 1, day: 1, period: $0) }
        }
        let results = EmptyClassroomLogic.buildResults(rows)
        #expect(results.map(\.freePeriodCount) == [3, 1, 1])
        #expect(results[0].freeRuns.map(\.id) == ["1-1-1-3"] && results[0].longestFreeRun == 3 && results[0].firstFreePeriod == 1)
        let byFree = EmptyClassroomLogic.sort(results, mode: .free, direction: .desc)
        #expect(byFree.map(\.room.name) == ["101", "102", "X"])           // 同节数先比首次空闲，再比楼栋 / 教室名
        let groups = EmptyClassroomLogic.group(EmptyClassroomLogic.sort(results, mode: .default, direction: .asc))
        #expect(groups.map(\.title) == ["", "A"].map { $0.isEmpty ? "其他楼栋" : $0 })   // 空楼栋排在前（码点顺序）并显示“其他楼栋”
    }

    @Test func cooldownCountsFromLastStart() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(CacheRunner.remainingCooldown(lastStartedAt: nil, now: now) == 0)
        #expect(CacheRunner.remainingCooldown(lastStartedAt: now.addingTimeInterval(-20), now: now) == 40)
        #expect(CacheRunner.remainingCooldown(lastStartedAt: now.addingTimeInterval(-61), now: now) == 0)
    }
}

struct EmptyClassroomFetchTests {
    @Test func paginationUsesTotalCountEvenWhenPagesAreShort() async throws {
        let calls = LockedBox<[Int]>([])
        let items = try await EmptyClassroomAPI.collectSlotPages(pageSize: 10_000, maxPages: 10) { pageNum in
            calls.mutate { $0.append(pageNum) }
            let chunk = pageNum == 1 ? [("A", "1"), ("A", "2")] : [("A", "3")]
            return ClassroomPage(totalCount: 3, items: chunk.map { .init(classroomName: $0.1, building: $0.0) })
        }
        #expect(calls.value == [1, 2] && items.count == 3)
    }

    @Test func paginationRejectsTruncatedAndRunawayData() async {
        await #expect(throws: IncompleteDataError.self) {
            _ = try await EmptyClassroomAPI.collectSlotPages(pageSize: 10, maxPages: 3) { pageNum in
                // totalCount=5，但第 2 页是空页：数据被截断
                ClassroomPage(totalCount: 5, items: pageNum == 1 ? [.init(classroomName: "1", building: "A")] : [])
            }
        }
        await #expect(throws: IncompleteDataError.self) {
            _ = try await EmptyClassroomAPI.collectSlotPages(pageSize: 1, maxPages: 2) { pageNum in
                ClassroomPage(items: [.init(classroomName: "\(pageNum)", building: "A")])   // 每页都是满页，永远不结束
            }
        }
    }

    @Test func fetchDayMergesThirteenPeriodsAndDedupes() async throws {
        let backend = ClosureBackend { query in
            let period = Int(query["timeList"]!)!
            // 教室 101 每节都空闲；102 只有 2、3 节；名字为空的行被跳过
            var items = [("A", "101")]
            if period == 2 || period == 3 { items.append(("A", "102")) }
            items.append(("B", " "))
            return envelope(items: items)
        }
        let day = try await EmptyClassroomAPI(backend: backend).fetchDay(year: 2026, term: 1, week: 3, day: 2)
        #expect(day.rooms.count == 2)
        #expect(day.freePeriods[emptyRoomKey("A", "101")] == Array(1...13))
        #expect(day.freePeriods[emptyRoomKey("A", "102")] == [2, 3])
        let first = try #require(backend.queries.first)
        #expect(first["year"] == "2026" && first["term"] == "1" && first["weekList"] == "3" && first["weekDay"] == "2")
        #expect(backend.queries.count == 13)
    }

    @Test func transientErrorsRetryButAuthLikeResponsesDoNot() async throws {
        let attempts = LockedBox(0)
        let flaky = ClosureBackend { _ in
            let n = attempts.mutate { $0 += 1; return $0 }
            if n < 3 { throw GxuError.network("offline") }
            return envelope(items: [("A", "1")])
        }
        let page = try await EmptyClassroomAPI(backend: flaky, retryDelay: .milliseconds(1)).requestPage(year: 2026, term: 1, week: 1, day: 1, period: 1, pageNum: 1)
        #expect(page.items.count == 1 && attempts.value == 3)

        let alwaysDown = ClosureBackend { _ in throw GxuError.http(status: 503, message: nil) }
        await #expect(throws: GxuError.self) {
            _ = try await EmptyClassroomAPI(backend: alwaysDown, maxTransientRetries: 1, retryDelay: .milliseconds(1)).requestPage(year: 2026, term: 1, week: 1, day: 1, period: 1, pageNum: 1)
        }
        #expect(alwaysDown.queries.count == 2)                       // 1 次 + 1 次重试

        let nullData = ClosureBackend { _ in #"{"code":200,"message":"ok","data":null}"# }
        await #expect(throws: EmptyClassroomError.self) {
            _ = try await EmptyClassroomAPI(backend: nullData).requestPage(year: 2026, term: 1, week: 1, day: 1, period: 1, pageNum: 1)
        }
        let badItems = ClosureBackend { _ in #"{"code":200,"message":"ok","data":{"items":"x"}}"# }
        await #expect(throws: EmptyClassroomError.self) {
            _ = try await EmptyClassroomAPI(backend: badItems).requestPage(year: 2026, term: 1, week: 1, day: 1, period: 1, pageNum: 1)
        }
        let forbidden = ClosureBackend { _ in throw GxuError.http(status: 400, message: "不支持的学期参数") }
        await #expect(throws: GxuError.self) {
            _ = try await EmptyClassroomAPI(backend: forbidden).requestPage(year: 2026, term: 3, week: 1, day: 1, period: 1, pageNum: 1)
        }
        #expect(forbidden.queries.count == 1)                        // 4xx 不重试
    }
}

struct EmptyClassroomRepositoryTests {
    private func makeRepo() throws -> EmptyClassroomRepository {
        EmptyClassroomRepository(database: try AppDatabase.inMemory(features: [CampusFeature.migrations]))
    }

    private func payload(day: Int, _ rooms: [(String, String, [Int])]) -> DayPayload {
        var r: [String: RoomPayload] = [:], f: [String: [Int]] = [:]
        for (b, n, ps) in rooms {
            let key = emptyRoomKey(b, n)
            r[key] = RoomPayload(key: key, building: b, name: n, placeType: "多媒体", seatCount: 60, seatCountForExam: nil, owner: "", allowToUse: "")
            f[key] = ps
        }
        return DayPayload(day: day, rooms: r, freePeriods: f)
    }

    @Test func saveDayThenQueryAndPaginate() async throws {
        let repo = try makeRepo()
        let rooms = (1...5).map { ("A楼", "10\($0)", $0 == 5 ? [9] : [1, 2, 3]) }
        try await repo.saveDay(year: 2026, term: 1, week: 3, day: 2, payload: payload(day: 2, rooms))
        #expect(try await repo.completedDays(year: 2026, term: 1, week: 3) == [2])

        var query = AvailableRoomsQuery(year: 2026, term: 1, week: 3, day: 2, startPeriod: 1, endPeriod: 4)
        query.pageSize = 2
        let page1 = try await repo.listAvailableRooms(query)
        #expect(page1.totalCount == 4 && page1.hasMore && Set(page1.rows.map(\.room.name)) == ["101", "102"])
        query.page = 2
        let page2 = try await repo.listAvailableRooms(query)
        #expect(Set(page2.rows.map(\.room.name)) == ["103", "104"] && !page2.hasMore)

        // 范围外的节次不算
        query.page = 1; query.pageSize = 40; query.startPeriod = 9; query.endPeriod = 9
        #expect(try await repo.listAvailableRooms(query).rows.map(\.room.name) == ["105"])
        // 关键词按教室名 / 类型筛选；% 按字面处理
        query.startPeriod = 1; query.endPeriod = 13; query.keyword = "103"
        #expect(Set(try await repo.listAvailableRooms(query).rows.map(\.room.name)) == ["103"])
        query.keyword = "%"
        #expect(try await repo.listAvailableRooms(query).rows.isEmpty)
    }

    @Test func freeSortPicksTheRightPageThenSortsWithinIt() async throws {
        let repo = try makeRepo()
        try await repo.saveDay(year: 2026, term: 1, week: 1, day: 1, payload: payload(day: 1, [("A", "1", [1]), ("A", "2", [1, 2, 3]), ("A", "3", [1, 2])]))
        var q = AvailableRoomsQuery(year: 2026, term: 1, week: 1, day: 1, startPeriod: 1, endPeriod: 13)
        q.sortMode = .free
        q.sortDirection = .desc
        q.pageSize = 2
        // 空闲最多的两间（2 和 3）在第一页；页内按空闲节数降序排
        let page1 = try await repo.listAvailableRooms(q)
        let sorted1 = EmptyClassroomLogic.sort(EmptyClassroomLogic.buildResults(page1.rows), mode: .free, direction: .desc)
        #expect(sorted1.map(\.room.name) == ["2", "3"] && page1.hasMore)
        q.page = 2
        let page2 = try await repo.listAvailableRooms(q)
        #expect(page2.rows.map(\.room.name) == ["1"] && !page2.hasMore)
        // 升序时最少的在前
        q.page = 1; q.sortDirection = .asc
        let asc = try await repo.listAvailableRooms(q)
        let sortedAsc = EmptyClassroomLogic.sort(EmptyClassroomLogic.buildResults(asc.rows), mode: .free, direction: .asc)
        #expect(sortedAsc.map(\.room.name) == ["1", "3"])
    }

    @Test func saveDayReplacesThatDayAndSnapshotsTheWeek() async throws {
        let repo = try makeRepo()
        for day in 1...7 { try await repo.saveDay(year: 2026, term: 1, week: 1, day: day, payload: payload(day: day, [("A", "1", [1, 2])])) }
        let full = try #require(try await repo.week(year: 2026, term: 1, week: 1))
        #expect(full.complete && full.completedDays == 7 && full.slotCount == 14 && full.roomCount == 1)

        // 重新抓第 3 天：这一天旧的空闲节次被替换，不叠加
        try await repo.saveDay(year: 2026, term: 1, week: 1, day: 3, payload: payload(day: 3, [("A", "1", [5])]))
        let rows = try await repo.roomWeekSlots(year: 2026, term: 1, roomId: 1, weeks: [1])
        #expect(rows.filter { $0.day == 3 }.map(\.period) == [5])
        #expect(try await repo.listWeeks(year: 2026, term: 1).count == 1)

        try await repo.deleteWeek(year: 2026, term: 1, week: 1)
        #expect(try await repo.week(year: 2026, term: 1, week: 1) == nil)
        #expect(try await repo.listRoomBuildings() == [RoomBuildingSummary(building: "A", roomCount: 1)])   // 教室维表保留
        try await repo.clearAll()
        #expect(try await repo.listRoomBuildings().isEmpty)
    }
}

struct CacheRunnerTests {
    private func day(_ n: Int) -> DayPayload { DayPayload(day: n, rooms: [:], freePeriods: [:]) }

    @Test func resumesFromCompletedDaysAndCompletesTheWeek() async throws {
        let saved = LockedBox<[Int]>([])
        let completedFlag = LockedBox(false)
        let started = LockedBox(0)
        let deps = CacheRunnerDeps(
            completedDays: { _ in [1, 2, 3] },
            fetchDay: { _, d, _ in DayPayload(day: d, rooms: [:], freePeriods: [:]) },
            saveDay: { _, d, _ in saved.mutate { $0.append(d) } },
            completeWeek: { _ in completedFlag.mutate { $0 = true } },
            beforeFirstRequest: { started.mutate { $0 += 1 } }
        )
        let result = try await CacheRunner.runWeek(CacheRunnerRange(year: 2026, term: 1, week: 1), deps: deps)
        #expect(saved.value == [4, 5, 6, 7] && result.complete && !result.canceled && completedFlag.value && started.value == 1)
    }

    @Test func alreadyCompleteWeekMakesNoRequestAndNoCooldown() async throws {
        let fetched = LockedBox(0), started = LockedBox(0)
        let deps = CacheRunnerDeps(
            completedDays: { _ in Array(1...7) },
            fetchDay: { _, d, _ in fetched.mutate { $0 += 1 }; return DayPayload(day: d, rooms: [:], freePeriods: [:]) },
            saveDay: { _, _, _ in }, completeWeek: { _ in },
            beforeFirstRequest: { started.mutate { $0 += 1 } }
        )
        let result = try await CacheRunner.runWeek(CacheRunnerRange(year: 2026, term: 1, week: 1), deps: deps)
        #expect(result.complete && fetched.value == 0 && started.value == 0)
    }

    @Test func cancelAfterAFetchedDayStillSavesIt() async throws {
        let saved = LockedBox<[Int]>([])
        let cancel = LockedBox(false)
        let deps = CacheRunnerDeps(
            completedDays: { _ in [] },
            fetchDay: { _, d, _ in cancel.mutate { $0 = true }; return DayPayload(day: d, rooms: [:], freePeriods: [:]) },
            saveDay: { _, d, _ in saved.mutate { $0.append(d) } },
            completeWeek: { _ in },
            shouldCancel: { cancel.value }
        )
        let result = try await CacheRunner.runWeek(CacheRunnerRange(year: 2026, term: 1, week: 1), deps: deps)
        #expect(saved.value == [1] && result.canceled && !result.complete && result.completedDays == [1])
    }

    @Test func errorKeepsSavedDaysAndPropagates() async {
        let saved = LockedBox<[Int]>([])
        let deps = CacheRunnerDeps(
            completedDays: { _ in [] },
            fetchDay: { _, d, _ in
                if d == 3 { throw GxuError.network("offline") }
                return DayPayload(day: d, rooms: [:], freePeriods: [:])
            },
            saveDay: { _, d, _ in saved.mutate { $0.append(d) } },
            completeWeek: { _ in }
        )
        await #expect(throws: GxuError.self) { _ = try await CacheRunner.runWeek(CacheRunnerRange(year: 2026, term: 1, week: 1), deps: deps) }
        #expect(saved.value == [1, 2])
    }
}

/// 测试里跨并发共享的小盒子
final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T { lock.withLock { stored } }
    @discardableResult func mutate<R>(_ body: (inout T) -> R) -> R { lock.withLock { body(&stored) } }
}
