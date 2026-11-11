import Foundation

public enum ClassPeriods {
    public struct Period: Sendable, Hashable {
        public let number: Int
        public let start: (hour: Int, minute: Int)
        public let end: (hour: Int, minute: Int)

        public var startText: String { String(format: "%02d:%02d", start.hour, start.minute) }
        public var endText: String { String(format: "%02d:%02d", end.hour, end.minute) }

        public static func == (lhs: Period, rhs: Period) -> Bool { lhs.number == rhs.number }
        public func hash(into hasher: inout Hasher) { hasher.combine(number) }
    }

    public static let all: [Period] = [
        (8, 0, 8, 45), (8, 55, 9, 40), (10, 0, 10, 45), (10, 55, 11, 40),
        (14, 30, 15, 15), (15, 20, 16, 5), (16, 25, 17, 10), (17, 15, 18, 0),
        (18, 10, 18, 55), (18, 45, 19, 30), (19, 40, 20, 25), (20, 30, 21, 15), (21, 20, 22, 5),
    ].enumerated().map { index, t in
        Period(number: index + 1, start: (t.0, t.1), end: (t.2, t.3))
    }

    public static var count: Int { all.count }

    public static func period(_ number: Int) -> Period? {
        (1...count).contains(number) ? all[number - 1] : nil
    }
}
