import Foundation
import GxuTestSupport
@testable import ScheduleKit

/// 所有测试固定在东八区，避免依赖开发机时区
let shanghai: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
}()

/// "2026-09-07 08:30" → Date
func at(_ text: String) -> Date {
    let f = DateFormatter()
    f.calendar = shanghai
    f.timeZone = shanghai.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = text.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
    return f.date(from: text)!
}

/// 合成数据用的学期：2026-09-07 是周一，共 18 周
let term = TermCalendar(startDate: at("2026-09-07"), weekCount: 18, calendar: shanghai)
/// 真实 fixture 对应的学期（2025-2026 秋季，`/jw/profile/startDay` 里 2025 年第 1 学期）
let realTerm = TermCalendar(startDate: at("2025-09-08"), weekCount: 20, calendar: shanghai)

/// 真实接口响应，由 A 脱敏（Fixtures/sanitized/schedule-personal.json），含多余的 `personalInfo` 字段
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
