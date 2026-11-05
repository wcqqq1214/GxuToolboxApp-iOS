import GxuFoundation
import GxuNetworking

/// 只依赖 `BackendAPI`，不碰存储。
public struct ExamAPI: Sendable {
    let backend: any BackendAPI

    public init(backend: any BackendAPI) { self.backend = backend }

    /// `GET /jw/exam`；后端 `data` 为 null 时返回空数组（调用方仍要用它替换缓存）
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

    /// `GET /jw/score`。参数名 `orderBy`/`order` 与 RN 一致（看似互换，但后端按此接收）
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

    /// 不带学年和学期的全部历史成绩（校选课查漏用；RN 同样不传 year / term）
    public func allScores() async throws -> [Score] {
        let page = try await backend.getData(
            "/jw/score",
            query: ["pageSize": "1000", "pageNo": "1", "orderBy": "desc", "order": "cjbdsj"],
            as: ScorePage?.self
        )
        return page?.items ?? []
    }

    /// `GET /jw/score/usual`
    public func usualScores(year: Int, term: Int, id: String) async throws -> [UsualScoreItem] {
        let list = try await backend.getData(
            "/jw/score/usual",
            query: ["year": String(year), "term": String(term), "id": id],
            as: [UsualScoreItem]?.self
        )
        return list ?? []
    }
}
