import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

struct ProfileBoundsTests {
    @Test func academicYearsNeverTrapsOnAbsurdValues() {
        let huge = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: 2022, studyYears: Int.max)
        #expect(huge.academicYears.count == 12)
        let wrap = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: Int.max, studyYears: 4)
        #expect(wrap.academicYears.count == 4)
        let none = UserProfile(studentId: "1", name: "", college: "", major: "", className: "", enrollmentYear: 2022, studyYears: -5)
        #expect(none.academicYears == [2022])
    }

    @Test func repositoryRejectsAbsurdGradeAndStudyYears() async {
        let backend = MockBackendAPI()
        backend.stub("POST /jw/profile", json: #"{"code":200,"data":{"student_id":"1","name":"n","grade":"99999999999","study_years":"4"}}"#)
        let repo = ProfileRepository(backend: backend, shared: InMemorySharedStore())
        await #expect(throws: GxuError.invalidData("用户资料中的入学年份或学制异常")) { try await repo.load(studentId: "1") }
        backend.stub("POST /jw/profile", json: #"{"code":200,"data":{"student_id":"1","name":"n","grade":"2022","study_years":"999999"}}"#)
        await #expect(throws: GxuError.invalidData("用户资料中的入学年份或学制异常")) { try await repo.load(studentId: "1") }
        #expect(repo.cached(studentId: "1") == nil)
    }
}
