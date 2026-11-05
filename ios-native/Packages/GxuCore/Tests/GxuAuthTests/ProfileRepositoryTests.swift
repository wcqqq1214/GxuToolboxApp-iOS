import Foundation
import GxuFoundation
import GxuTestSupport
import Testing
@testable import GxuAuth
@testable import GxuStorage

struct ProfileRepositoryTests {
    // 与脱敏后的 Fixtures/sanitized/profile.json 同构
    private let json = #"{"code":200,"message":"success","data":{"student_id":"2200000001","name":"测试同学","id_card":"450000200001010019","grade":"2022","college":"土木建筑工程学院","major":"土木工程(0311)","class_name":"示例专业221","study_years":"4"}}"#

    private func makeRepo(_ mock: MockBackendAPI = MockBackendAPI()) -> (ProfileRepository, MockBackendAPI, InMemorySharedStore) {
        let store = InMemorySharedStore()
        return (ProfileRepository(backend: mock, shared: store), mock, store)
    }

    @Test func loadParsesStringFieldsAndCaches() async throws {
        let (repo, mock, _) = makeRepo()
        mock.stub("POST /jw/profile", json: json)
        let profile = try await repo.load(studentId: "2200000001")
        #expect(profile.enrollmentYear == 2022 && profile.studyYears == 4)
        #expect(profile.academicYears == [2022, 2023, 2024, 2025])
        #expect(repo.cached(studentId: "2200000001") == profile)
    }

    @Test func cacheIsIsolatedByStudent() async throws {
        let (repo, mock, _) = makeRepo()
        mock.stub("POST /jw/profile", json: json)
        try await repo.load(studentId: "2200000001")
        #expect(repo.cached(studentId: "2299999999") == nil)
    }

    @Test func mismatchedStudentIdIsRejectedAndNotCached() async {
        let (repo, mock, _) = makeRepo()
        mock.stub("POST /jw/profile", json: json)
        await #expect(throws: GxuError.self) { try await repo.load(studentId: "2299999999") }
        #expect(repo.cached(studentId: "2299999999") == nil)
    }

    @Test func profileUsesCacheUnlessRefreshAndFallsBackOnFailure() async throws {
        let (repo, mock, _) = makeRepo()
        mock.stub("POST /jw/profile", json: json)
        _ = try await repo.profile(studentId: "2200000001")
        _ = try await repo.profile(studentId: "2200000001")
        #expect(mock.calls.count == 1)
        mock.stub("POST /jw/profile", error: .network("offline"))
        let stale = try await repo.profile(studentId: "2200000001", refresh: true)
        #expect(stale.studyYears == 4)
        await #expect(throws: GxuError.network("offline")) { try await repo.profile(studentId: "2200000002") }
    }

    @Test func missingGradeIsInvalidData() async {
        let (repo, mock, _) = makeRepo()
        mock.stub("POST /jw/profile", json: #"{"data":{"student_id":"1","grade":"","study_years":"4"}}"#)
        await #expect(throws: GxuError.invalidData("用户资料缺少入学年份或学制")) { try await repo.load(studentId: "1") }
    }
}
