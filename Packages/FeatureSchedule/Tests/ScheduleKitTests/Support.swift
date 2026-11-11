import Foundation
import GxuTestSupport
@testable import ScheduleKit

let shanghai: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
}()

func at(_ text: String) -> Date {
    let f = DateFormatter()
    f.calendar = shanghai
    f.timeZone = shanghai.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = text.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
    return f.date(from: text)!
}

let term = TermCalendar(startDate: at("2026-09-07"), weekCount: 18, calendar: shanghai)
let realTerm = TermCalendar(startDate: at("2025-09-08"), weekCount: 20, calendar: shanghai)

func personalFixtureData() throws -> Data { try loadFixture("schedule-personal", bundle: .module) }
func startDayFixtureData() throws -> Data { try loadFixture("profile-startDay", bundle: .module) }

func personalFixture() throws -> Schedule {
    struct Envelope: Decodable { let data: Schedule }
    return try JSONDecoder().decode(Envelope.self, from: personalFixtureData()).data
}

func course(
    _ name: String, weekday: Int = 1, _ begin: Int, _ end: Int, weeks: [Int] = [1], teacher: String = "", venue: String = ""
) -> TheoryCourse {
    TheoryCourse(venueName: venue, sectionRange: "\(begin)-\(end)", begin: begin, end: end,
                 courseName: name, weeks: weeks, teacher: teacher, weekday: weekday)
}
