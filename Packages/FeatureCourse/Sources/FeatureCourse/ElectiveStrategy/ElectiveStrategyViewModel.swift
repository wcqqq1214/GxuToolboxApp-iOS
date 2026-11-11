import ExamKit
import Foundation
import GxuAuth
import GxuFoundation
import Observation

@MainActor @Observable
final class ElectiveStrategyViewModel {
    private(set) var courses: [SelectedCourse] = []
    private(set) var passedScores: [String: Double] = [:]
    private(set) var grade = 2025
    private(set) var isLoading = false
    private(set) var error: GxuError?

    private var loadVersion = 0
    private let services: AppServices

    init(services: AppServices) { self.services = services }

    var strategy: ElectiveStrategy { ElectiveStrategies.strategy(forGrade: grade) }

    var stats: ElectiveStats {
        strategy.calculate(courses.filter { passedScores[$0.courseName] != nil })
    }

    func load() async {
        guard let studentId = services.accounts.studentId else {
            error = .notLoggedIn(.jw)
            return
        }
        loadVersion += 1
        let version = loadVersion
        error = nil
        isLoading = true
        defer { if version == loadVersion { isLoading = false } }

        if let profile = try? await services.profiles.profile(studentId: studentId), profile.enrollmentYear > 0 {
            grade = profile.enrollmentYear
        }
        let selectedRepo = SelectedCourseRepository(database: services.database)
        let examRepo = ExamRepository(database: services.database)
        await showCached(studentId: studentId, selectedRepo: selectedRepo, examRepo: examRepo, version: version)

        var failures: [GxuError] = []
        do {
            let remote = try await SelectedCourseAPI(backend: services.backend).list(.all)
            try await selectedRepo.replaceAll(remote, studentId: studentId)
        } catch is CancellationError { return } catch { failures.append(asGxuError(error)) }
        do {
            let remote = try await ScoreAPI(backend: services.backend).allScores()
            try await examRepo.replaceAllScores(remote, studentId: studentId)
        } catch is CancellationError { return } catch { failures.append(asGxuError(error)) }

        guard version == loadVersion else { return }
        await showCached(studentId: studentId, selectedRepo: selectedRepo, examRepo: examRepo, version: version)
        guard version == loadVersion else { return }
        if let first = failures.first, courses.isEmpty && passedScores.isEmpty { error = first }
    }

    private func showCached(studentId: String, selectedRepo: SelectedCourseRepository, examRepo: ExamRepository, version: Int) async {
        let selected = (try? await selectedRepo.list(studentId: studentId, scope: .all)) ?? []
        let scores = (try? await examRepo.allScores(studentId: studentId)) ?? []
        guard version == loadVersion else { return }
        courses = selected.filter { $0.selectionType == "通识选修课" }
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
