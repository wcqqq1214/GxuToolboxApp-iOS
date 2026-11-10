import Foundation
import GxuFoundation
import GxuNetworking

/// 数据没取全（达不到 totalCount / totalPage，或超过翻页上限）：不能静默缓存被截断的数据
public struct IncompleteDataError: Error, Sendable, Equatable {
    public var collected: Int
    public var expected: Int?
    public var pagesFetched: Int
}

public enum EmptyClassroomError: Error, Sendable, Equatable {
    /// 用户取消；抓了一半的当天数据由上层丢弃，已保存的天保留
    case canceled
    /// 教务返回的数据不是预期结构（`data` 为 null 或 `items` 不是数组，通常是教务登录失效）
    case invalidResponse
}

/// `GET /jw/emptyClassroom`：某周某天某节次的空闲教室。学期只用逻辑学期 1 / 2；教务登录失效由后端客户端自动重新登录一次。
public struct EmptyClassroomAPI: Sendable {
    private let backend: any BackendAPI
    /// 网络错误 / 5xx 的最大重试次数，以及间隔
    private let maxTransientRetries: Int
    private let retryDelay: Duration

    public init(backend: any BackendAPI, maxTransientRetries: Int = 2, retryDelay: Duration = .milliseconds(800)) {
        self.backend = backend
        self.maxTransientRetries = maxTransientRetries
        self.retryDelay = retryDelay
    }

    /// 请求并解析某个节次的一页。网络错误 / 5xx 最多重试 2 次；其他错误不重试。
    func requestPage(year: Int, term: Int, week: Int, day: Int, period: Int, pageNum: Int) async throws -> ClassroomPage {
        var transientRetries = 0
        while true {
            try Task.checkCancellation()
            do {
                let page = try await backend.getData(
                    "/jw/emptyClassroom",
                    query: [
                        "weekDay": String(day), "weekList": String(week), "timeList": String(period),
                        "year": String(year), "term": String(term),
                        "pageNum": String(pageNum), "pageSize": String(EmptyClassroomConstants.pageSize),
                    ],
                    as: ClassroomPage?.self
                )
                guard let page else { throw EmptyClassroomError.invalidResponse }
                return page
            } catch let error as GxuError {
                let transient: Bool
                switch error {
                case .network: transient = true
                case .http(let status, _): transient = (500..<600).contains(status)
                case .decoding: throw EmptyClassroomError.invalidResponse   // `items` 不是数组等
                default: transient = false
                }
                guard transient, transientRetries < maxTransientRetries else { throw error }
                transientRetries += 1
                try await Task.sleep(for: retryDelay)
            }
        }
    }

    /// 顺序翻页取完一个节次的所有空闲教室。完整性判断优先级：
    /// 1. 有 totalCount：去重前累计行数 < totalCount 就继续（即使当前页短于 pageSize）；
    /// 2. 没有 totalCount 但有 totalPage：翻到 pageNum >= totalPage；
    /// 3. 都没有：用短页判定结束。空页一律停止；达不到完整性或超过翻页上限抛 `IncompleteDataError`。
    static func collectSlotPages(
        pageSize: Int = EmptyClassroomConstants.pageSize, maxPages: Int = EmptyClassroomConstants.maxPages,
        fetchPage: (Int) async throws -> ClassroomPage
    ) async throws -> [ClassroomPage.Item] {
        var items: [ClassroomPage.Item] = []
        var seen = Set<String>()
        var totalCount: Int?, totalPage: Int?
        var pagesFetched = 0, rawCount = 0
        var hitMax = true
        for pageNum in 1...maxPages {
            let page = try await fetchPage(pageNum)
            pagesFetched = pageNum
            if totalCount == nil { totalCount = page.totalCount }
            if totalPage == nil { totalPage = page.totalPage }
            if page.items.isEmpty { hitMax = false; break }
            rawCount += page.items.count
            for item in page.items where seen.insert(emptyRoomKey(item.building, item.classroomName)).inserted { items.append(item) }
            if let totalCount {
                if rawCount >= totalCount { hitMax = false; break }
                continue
            }
            if let totalPage {
                if pagesFetched >= totalPage { hitMax = false; break }
                continue
            }
            if page.items.count < pageSize { hitMax = false; break }
        }
        if let totalCount, rawCount < totalCount { throw IncompleteDataError(collected: rawCount, expected: totalCount, pagesFetched: pagesFetched) }
        if hitMax, let totalPage, pagesFetched < totalPage { throw IncompleteDataError(collected: rawCount, expected: totalCount, pagesFetched: pagesFetched) }
        if hitMax, totalCount == nil, totalPage == nil { throw IncompleteDataError(collected: rawCount, expected: nil, pagesFetched: pagesFetched) }
        return items
    }

    /// 并发抓一天 13 个节次，合并成按 roomKey 索引的 `DayPayload`。
    /// - 教室元数据以节次升序里的第一份为准；空闲节次升序去重；教室名为空的条目跳过。
    /// - `onPeriod` 在每个节次完整抓完后回调（并发完成顺序不固定，进度可能跳变）。
    public func fetchDay(year: Int, term: Int, week: Int, day: Int, onPeriod: (@Sendable (Int, Int) -> Void)? = nil) async throws -> DayPayload {
        try Task.checkCancellation()
        let results = try await withThrowingTaskGroup(of: (Int, [ClassroomPage.Item]).self) { group in
            for period in 1...EmptyClassroomConstants.periods {
                group.addTask {
                    let items = try await Self.collectSlotPages { pageNum in
                        try await requestPage(year: year, term: term, week: week, day: day, period: period, pageNum: pageNum)
                    }
                    onPeriod?(day, period)
                    return (period, items)
                }
            }
            var all: [(Int, [ClassroomPage.Item])] = []
            for try await result in group { all.append(result) }
            return all
        }
        var rooms: [String: RoomPayload] = [:]
        var free: [String: [Int]] = [:]
        for (period, items) in results.sorted(by: { $0.0 < $1.0 }) {
            for item in items {
                let building = item.building.trimmingCharacters(in: .whitespaces)
                let name = item.classroomName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                let key = emptyRoomKey(building, name)
                if rooms[key] == nil {
                    rooms[key] = RoomPayload(
                        key: key, building: building, name: name, placeType: item.placeType,
                        seatCount: Self.seat(item.seatCount), seatCountForExam: Self.seat(item.seatCountForExam),
                        owner: item.owner, allowToUse: item.allowToUse
                    )
                }
                if free[key]?.contains(period) != true { free[key, default: []].append(period) }
            }
        }
        for key in free.keys { free[key] = Array(Set(free[key] ?? [])).sorted() }
        return DayPayload(day: day, rooms: rooms, freePeriods: free)
    }

    static func seat(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }
}
