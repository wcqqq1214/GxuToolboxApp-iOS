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

/// 2026-09-07 是周一，共 18 周
let term = TermCalendar(startDate: at("2026-09-07"), weekCount: 18, calendar: shanghai)

// TODO(verify): 手写 fixture（按适配器 Schedule 类型），等 capture-fixtures.sh 抓到真实数据后脱敏替换
func personalFixture() throws -> Schedule {
    struct Envelope: Decodable { let data: Schedule }
    let data = try loadFixture("personal", bundle: .module)
    return try JSONDecoder().decode(Envelope.self, from: data).data
}

func course(
    _ name: String, weekday: Int = 1, _ begin: Int, _ end: Int, weeks: [Int] = [1], teacher: String = "", venue: String = ""
) -> TheoryCourse {
    TheoryCourse(venueName: venue, sectionRange: "\(begin)-\(end)", begin: begin, end: end,
                 courseName: name, weeks: weeks, teacher: teacher, weekday: weekday)
}
