import Foundation
import GxuFoundation

public struct Schedule: Codable, Sendable, Hashable {
    public var theoryList: [TheoryCourse]
    public var practiceList: [PracticeCourse]

    public init(theoryList: [TheoryCourse] = [], practiceList: [PracticeCourse] = []) {
        self.theoryList = theoryList
        self.practiceList = practiceList
    }

    private enum CodingKeys: String, CodingKey { case theoryList, practiceList }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        theoryList = try c.decodeIfPresent([TheoryCourse].self, forKey: .theoryList) ?? []
        practiceList = try c.decodeIfPresent([PracticeCourse].self, forKey: .practiceList) ?? []
    }
}

public struct TheoryCourse: Codable, Sendable, Hashable, Identifiable {
    public var building: String
    public var venueName: String
    public var sectionRange: String
    public var begin: Int
    public var end: Int
    public var courseName: String
    public var weeks: [Int]
    public var teacher: String
    public var credits: String
    public var courseCategory: String
    public var examMethod: String
    public var weekday: Int
    public var qqGroup: String
    public var enrollmentCount: Int
    public var seatCount: Int
    public var customID: String?

    public var id: String { "\(customID ?? "")|\(courseName)|\(weekday)|\(sectionRange)|\(venueName)|\(teacher)" }
    public var isCustom: Bool { customID != nil }

    public var locationText: String { LocationFormatter.display(building: building, venue: venueName) }

    public var isValid: Bool {
        (1...7).contains(weekday) && (1...ClassPeriods.count).contains(begin) && (begin...ClassPeriods.count).contains(end)
    }

    public init(
        building: String = "", venueName: String = "", sectionRange: String = "1-2", begin: Int = 1, end: Int = 2,
        courseName: String, weeks: [Int], teacher: String = "", credits: String = "", courseCategory: String = "",
        examMethod: String = "", weekday: Int, qqGroup: String = "", enrollmentCount: Int = 0, seatCount: Int = 0,
        customID: String? = nil
    ) {
        self.customID = customID
        self.building = building
        self.venueName = venueName
        self.sectionRange = sectionRange
        self.begin = begin
        self.end = end
        self.courseName = courseName
        self.weeks = weeks
        self.teacher = teacher
        self.credits = credits
        self.courseCategory = courseCategory
        self.examMethod = examMethod
        self.weekday = weekday
        self.qqGroup = qqGroup
        self.enrollmentCount = enrollmentCount
        self.seatCount = seatCount
    }

    private enum CodingKeys: String, CodingKey {
        case building, venueName, sectionRange, begin, end, courseName, weeks, teacher, credits
        case courseCategory, examMethod, weekday, qqGroup, enrollmentCount, seatCount, customID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        building = c.lenientString(.building)
        venueName = c.lenientString(.venueName)
        let range = c.lenientString(.sectionRange)
        sectionRange = range.isEmpty ? "1-2" : range
        let parts = sectionRange.split(separator: "-").compactMap { Int($0) }
        begin = c.lenientInt(.begin) ?? parts.first ?? 1
        end = c.lenientInt(.end) ?? parts.last ?? begin
        let name = c.lenientString(.courseName)
        courseName = name.isEmpty ? "课程名称" : name
        weeks = ((try? c.decodeIfPresent([Int].self, forKey: .weeks)) ?? nil) ?? []
        teacher = c.lenientString(.teacher)
        credits = c.lenientString(.credits)
        courseCategory = c.lenientString(.courseCategory)
        examMethod = c.lenientString(.examMethod)
        weekday = c.lenientInt(.weekday) ?? 0
        qqGroup = c.lenientString(.qqGroup)
        enrollmentCount = c.lenientInt(.enrollmentCount) ?? 0
        seatCount = c.lenientInt(.seatCount) ?? 0
        customID = (try? c.decodeIfPresent(String.self, forKey: .customID)) ?? nil
    }
}

public struct PracticeCourse: Codable, Sendable, Hashable {
    public var courseName: String
    public var time: String
    public var teacher: String

    public var title: String {
        guard let marker = courseName.firstIndex(where: { "●◆★○".contains($0) }) else { return courseName }
        let head = courseName[..<marker].trimmingCharacters(in: .whitespaces)
        return head.isEmpty ? courseName : head
    }

    public init(courseName: String, time: String = "", teacher: String = "") {
        self.courseName = courseName
        self.time = time
        self.teacher = teacher
    }

    private enum CodingKeys: String, CodingKey { case courseName, time, teacher }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courseName = c.lenientString(.courseName)
        time = c.lenientString(.time)
        teacher = c.lenientString(.teacher)
    }
}

public struct TermStartDay: Codable, Sendable, Hashable {
    public var year: Int
    public var term: Int
    public var day: String
    public var week: Int
    public var isCurrent: Bool

    public var academicTerm: AcademicTerm { AcademicTerm(year: year, term: term) }

    public init(year: Int, term: Int, day: String, week: Int, isCurrent: Bool = false) {
        self.year = year
        self.term = term
        self.day = day
        self.week = week
        self.isCurrent = isCurrent
    }

    private enum CodingKeys: String, CodingKey {
        case year, term, day, week
        case isCurrent = "is_current"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        year = c.lenientInt(.year) ?? 0
        term = c.lenientInt(.term) ?? 0
        day = c.lenientString(.day)
        week = c.lenientInt(.week) ?? 0
        isCurrent = (try? c.decodeIfPresent(Bool.self, forKey: .isCurrent)) ?? false
    }
}

extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return ""
    }

    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(exactly: value.rounded(.towardZero)) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
