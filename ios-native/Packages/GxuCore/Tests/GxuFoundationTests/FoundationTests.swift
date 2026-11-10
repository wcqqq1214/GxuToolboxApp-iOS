import Testing
@testable import GxuFoundation

struct FoundationTests {
    @Test func termMapsToJwXqm() {
        #expect(AcademicTerm(year: 2025, term: 1).jwXqm == "3")
        #expect(AcademicTerm(year: 2025, term: 2).jwXqm == "12")
        #expect(AcademicTerm(year: 2025, term: 3).jwXqm == "16")
    }

    @Test func termRoundTripsFromXqm() {
        #expect(AcademicTerm(year: 2025, jwXqm: "12") == AcademicTerm(year: 2025, term: 2))
        #expect(AcademicTerm(year: 2025, jwXqm: "99") == nil)
    }

    @Test func termDisplayName() {
        #expect(AcademicTerm(year: 2025, term: 1).displayName == "2025-2026 秋季学期")
        #expect(AcademicTerm(year: 2025, term: 2).displayName == "2025-2026 春季学期")
    }

    @Test func termsAreOrdered() {
        #expect(AcademicTerm(year: 2024, term: 2) < AcademicTerm(year: 2025, term: 1))
        #expect(AcademicTerm(year: 2025, term: 1) < AcademicTerm(year: 2025, term: 2))
    }

    @Test func onlyAutumnAndSpringAreBackendQueryable() {
        #expect(AcademicTerm(year: 2025, term: 1).isBackendQueryable)
        #expect(AcademicTerm(year: 2025, term: 2).isBackendQueryable)
        #expect(!AcademicTerm(year: 2025, term: 3).isBackendQueryable)
    }

    @Test func errorMessages() {
        #expect(GxuError.notLoggedIn(.jw).userMessage.contains("教务"))
        #expect(GxuError.http(status: 500, message: "boom").userMessage == "boom")
        #expect(GxuError.http(status: 500, message: nil).userMessage.contains("500"))
        #expect(GxuError.decoding("x") == GxuError.decoding("x"))
    }
}
