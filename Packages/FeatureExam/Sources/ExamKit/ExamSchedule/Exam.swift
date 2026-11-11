import Foundation

public struct Exam: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var course: String
    public var classroom: String
    public var time: String
    public var type: String
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
    public var seatText: String { ExamSeat.text(seat) }
}
