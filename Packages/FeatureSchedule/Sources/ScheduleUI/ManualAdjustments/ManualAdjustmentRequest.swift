import Foundation
import GxuFoundation
import ScheduleKit

struct ManualAdjustmentRequest: Identifiable {
    let id = UUID()
    let studentId: String
    let sessionID: UUID
    let term: AcademicTerm
    let source: CourseOccurrence
    let related: [CourseOccurrence]
    let existing: ManualCourseAdjustment?
}
