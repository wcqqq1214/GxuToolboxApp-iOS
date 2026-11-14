import GxuFoundation
import GxuNetworking

public struct ExamAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func exams(_ term: AcademicTerm) async throws -> [Exam] {
        let list = try await backend.getData(
            "/jw/exam",
            query: ["year": String(term.year), "term": String(term.term)],
            as: [Exam]?.self
        )
        return list ?? []
    }
}

public struct ScoreAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    public func scores(_ term: AcademicTerm) async throws -> [Score] {
        try await fetchScores(filters: ["year": String(term.year), "term": String(term.term)])
    }

    public func allScores() async throws -> [Score] {
        try await fetchScores(filters: [:])
    }

    private func fetchScores(filters: [String: String]) async throws -> [Score] {
        var items: [Score] = []
        var pageNumber = 1
        var totalPages: Int?
        var totalCount: Int?
        repeat {
            try Task.checkCancellation()
            var query = filters
            query.merge(["pageSize": "1000", "pageNo": String(pageNumber), "orderBy": "desc", "order": "cjbdsj"]) { _, new in new }
            let page = try await backend.getData("/jw/score", query: query, as: ScorePage?.self)
            guard let page else {
                if pageNumber == 1 { return [] }
                throw GxuError.invalidData("成绩分页数据不完整")
            }
            if pageNumber == 1 {
                totalPages = page.totalPage
                totalCount = page.totalCount
            }
            guard page.currentPage == nil || page.currentPage == pageNumber,
                  page.totalPage == totalPages, page.totalCount == totalCount,
                  (totalPages ?? 1) >= 0, (totalCount ?? 0) >= 0,
                  pageNumber == 1 || !page.items.isEmpty else {
                throw GxuError.invalidData("成绩分页数据不完整，请重试")
            }
            items.append(contentsOf: page.items)
            pageNumber += 1
        } while pageNumber <= (totalPages ?? 1)
        guard totalCount == nil || totalCount == items.count,
              Set(items.map(\.id)).count == items.count else {
            throw GxuError.invalidData("成绩分页数据不完整，请重试")
        }
        return items
    }

    public func usualScores(year: Int, term: Int, id: String) async throws -> [UsualScoreItem] {
        let list = try await backend.getData(
            "/jw/score/usual",
            query: ["year": String(year), "term": String(term), "id": id],
            as: [UsualScoreItem]?.self
        )
        return list ?? []
    }
}
