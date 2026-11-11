import Foundation
import GxuFoundation
import GxuNetworking

public struct IncompleteDataError: Error, Sendable, Equatable {
    public var collected: Int
    public var expected: Int?
    public var pagesFetched: Int
}

public enum EmptyClassroomError: Error, Sendable, Equatable {
    case canceled
    case invalidResponse
}

public struct EmptyClassroomAPI: Sendable {
    private let backend: any BackendAPI
    private let maxTransientRetries: Int
    private let retryDelay: Duration

    public init(backend: any BackendAPI, maxTransientRetries: Int = 2, retryDelay: Duration = .milliseconds(800)) {
        self.backend = backend
        self.maxTransientRetries = maxTransientRetries
        self.retryDelay = retryDelay
    }

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
                case .decoding: throw EmptyClassroomError.invalidResponse
                default: transient = false
                }
                guard transient, transientRetries < maxTransientRetries else { throw error }
                transientRetries += 1
                try await Task.sleep(for: retryDelay)
            }
        }
    }

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
        if totalCount == nil, let totalPage, pagesFetched < totalPage { throw IncompleteDataError(collected: rawCount, expected: nil, pagesFetched: pagesFetched) }
        if hitMax, totalCount == nil, totalPage == nil { throw IncompleteDataError(collected: rawCount, expected: nil, pagesFetched: pagesFetched) }
        return items
    }

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
