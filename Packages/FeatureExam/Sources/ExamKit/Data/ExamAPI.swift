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
        let page = try await backend.getData(
            "/jw/score",
            query: [
                "pageSize": "1000", "pageNo": "1", "orderBy": "desc", "order": "cjbdsj",
                "year": String(term.year), "term": String(term.term),
            ],
            as: ScorePage?.self
        )
        return page?.items ?? []
    }

    public func allScores() async throws -> [Score] {
        let page = try await backend.getData(
            "/jw/score",
            query: ["pageSize": "1000", "pageNo": "1", "orderBy": "desc", "order": "cjbdsj"],
            as: ScorePage?.self
        )
        return page?.items ?? []
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
