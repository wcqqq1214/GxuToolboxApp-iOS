import Foundation
import GxuFoundation

/// 后端 `GET /jw/schedule/personal` 返回的课表（适配器输出，已解析）。
/// 解码很宽容：缺字段给默认值，数字字段兼容字符串。
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
    /// 楼号，如 "西三教"
    public var building: String
    /// 教室，如 "西3-406"
    public var venueName: String
    /// 节次区间，如 "1-2"
    public var sectionRange: String
    public var begin: Int
    public var end: Int
    public var courseName: String
    /// 已展开的周次，升序
    public var weeks: [Int]
    public var teacher: String
    public var credits: String
    public var courseCategory: String
    public var examMethod: String
    /// 1 = 周一 … 7 = 周日
    public var weekday: Int
    public var qqGroup: String
    public var enrollmentCount: Int
    public var seatCount: Int
    /// 用户自己添加的日程（`CustomActivity.id`）；教务课程为 nil
    public var customID: String?

    /// 同名同节次的不同班级 / 教室也不会撞 id（RN 的 id 会撞）
    public var id: String { "\(customID ?? "")|\(courseName)|\(weekday)|\(sectionRange)|\(venueName)|\(teacher)" }
    public var isCustom: Bool { customID != nil }

    /// 数据可用：星期、节次都在合法范围内
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
    /// 后端原样返回，里面内嵌了教师和周次，如 "创新创业实践●教师70(共16周)/1-16周/无"。显示请用 `title`
    public var courseName: String
    /// 如 "1-16周"
    public var time: String
    public var teacher: String

    /// 去掉内嵌的教师 / 周次后的课程名（在第一个 ●◆★○ 标记处截断）
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

/// `GET /jw/profile/startDay` 的一项
public struct TermStartDay: Codable, Sendable, Hashable {
    public var year: Int
    /// 逻辑学期 1 / 2
    public var term: Int
    /// `YYYY-MM-DD`，也兼容带时区的 ISO 8601
    public var day: String
    /// 本学期总周数
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
    /// 字符串 / 整数 / 小数都当字符串读，失败返回空串
    func lenientString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return ""
    }

    /// 整数或数字字符串；无法解析（含 NaN）返回 nil
    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
