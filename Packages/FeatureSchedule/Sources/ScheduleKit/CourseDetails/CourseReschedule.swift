package struct CourseReschedule: Decodable, Sendable {
    package struct Arrangement: Decodable, Sendable {
        package let weeks: String?
        package let weekday: String?
        package let sections: String?
        package let teacher: String?
        package let venueName: String?
    }

    package let type: String?
    package let reason: String?
    package let reasonCategory: String?
    package let before: Arrangement
    package let after: Arrangement
}
