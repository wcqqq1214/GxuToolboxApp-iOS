import Foundation

/// `GET /jw/exam` 返回的一条考试安排
public struct Exam: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var course: String
    public var classroom: String
    /// 形如 `2026-07-15(09:00-11:00)`，可能为空或格式不符
    public var time: String
    public var type: String
    /// 教务已不再提供座位号，缺失时为空串
    public var seat: String

    public init(id: String, course: String, classroom: String, time: String, type: String, seat: String = "") {
        self.id = id
        self.course = course
        self.classroom = classroom
        self.time = time
        self.type = type
        self.seat = seat
    }

    private enum CodingKeys: String, CodingKey { case id, course, classroom, time, type, seat }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        course = try c.decodeIfPresent(String.self, forKey: .course) ?? ""
        classroom = try c.decodeIfPresent(String.self, forKey: .classroom) ?? ""
        time = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        seat = try c.decodeIfPresent(String.self, forKey: .seat) ?? ""
    }
}

extension Exam {
    /// 座位号的统一显示：纯数字写成“8 号”，其他写法（如 A12）写成“座位 A12”，没有座位号返回空串。
    /// 首页、考试页等所有显示座位号的地方都用它。
    public var seatText: String {
        let seat = seat.trimmingCharacters(in: .whitespaces)
        if seat.isEmpty { return "" }
        return seat.allSatisfy(\.isNumber) ? "\(seat) 号" : "座位 \(seat)"
    }
}
