import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation

/// 校选课查漏的数据入口：已选课程（只取通识选修课）、已及格的成绩、年级（入学年份）。
/// 都是先用本地缓存，再后台刷新；刷新失败且有缓存时保留缓存。
@MainActor @Observable
final class ElectiveStrategyViewModel {
    private(set) var courses: [SelectedCourse] = []
    /// 成绩 ≥ 60 的课程名 → 分数
    private(set) var passedScores: [String: Double] = [:]
    private(set) var grade = 2025
    private(set) var isLoading = false
    private(set) var error: GxuError?

    private let services: AppServices

    init(services: AppServices) { self.services = services }

    var strategy: ElectiveStrategy { ElectiveStrategies.strategy(forGrade: grade) }

    /// RN：只统计"已选且成绩及格"的通识选修课
    var stats: ElectiveStats {
        strategy.calculate(courses.filter { passedScores[$0.courseName] != nil })
    }

    func load() async {
        guard let studentId = services.accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        error = nil
        isLoading = true
        defer { isLoading = false }

        if let profile = try? await services.profiles.profile(studentId: studentId), profile.enrollmentYear > 0 {
            grade = profile.enrollmentYear
        }
        let selectedRepo = SelectedCourseRepository(database: services.database)
        let examRepo = ExamRepository(database: services.database)
        await showCached(studentId: studentId, selectedRepo: selectedRepo, examRepo: examRepo)

        var failures: [GxuError] = []
        do {
            let remote = try await SelectedCourseAPI(backend: services.backend).list(.all)
            try await selectedRepo.replaceAll(remote, studentId: studentId)
        } catch is CancellationError { return } catch { failures.append(asGxuError(error)) }
        do {
            let remote = try await ScoreAPI(backend: services.backend).allScores()
            try await examRepo.replaceAllScores(remote, studentId: studentId)
        } catch is CancellationError { return } catch { failures.append(asGxuError(error)) }

        await showCached(studentId: studentId, selectedRepo: selectedRepo, examRepo: examRepo)
        // 有缓存就保留；两边都没有数据才报错
        if let first = failures.first, courses.isEmpty && passedScores.isEmpty { error = first }
    }

    private func showCached(studentId: String, selectedRepo: SelectedCourseRepository, examRepo: ExamRepository) async {
        let selected = (try? await selectedRepo.list(studentId: studentId, scope: .all)) ?? []
        courses = selected.filter { $0.selectionType == "通识选修课" }
        let scores = (try? await examRepo.allScores(studentId: studentId)) ?? []
        passedScores = Self.passed(scores)
    }

    nonisolated static func passed(_ scores: [Score]) -> [String: Double] {
        var result: [String: Double] = [:]
        for s in scores {
            guard let value = s.score, value >= 60 else { continue }
            result[s.courseName] = max(result[s.courseName] ?? 0, value)
        }
        return result
    }
}
