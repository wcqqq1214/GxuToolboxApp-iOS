import Foundation
import GxuStorage
import Observation

public struct DetailFieldSetting: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var label: String
    public var isShown: Bool

    public init(id: String, label: String, isShown: Bool = true) {
        self.id = id
        self.label = label
        self.isShown = isShown
    }
}

public struct SchedulePreferences: Codable, Sendable, Equatable {
    public var palette: CoursePalette
    public var showVenueInBlock: Bool
    public var showTeacherInBlock: Bool
    public var courseDetail: [DetailFieldSetting]
    public var examDetail: [DetailFieldSetting]

    public static let courseFieldDefaults: [DetailFieldSetting] = [
        .init(id: "time", label: "时间"), .init(id: "weeks", label: "周次"), .init(id: "venue", label: "地点"),
        .init(id: "teacher", label: "教师"), .init(id: "credits", label: "学分"), .init(id: "category", label: "类别"),
        .init(id: "examMethod", label: "考核"), .init(id: "enrollment", label: "选课人数"), .init(id: "qqGroup", label: "QQ 群"),
    ]

    public static let examFieldDefaults: [DetailFieldSetting] = [
        .init(id: "time", label: "时间"), .init(id: "classroom", label: "考场"), .init(id: "seat", label: "座位"),
        .init(id: "type", label: "类型"), .init(id: "countdown", label: "倒计时"),
    ]

    public init(
        palette: CoursePalette = .macaron, showVenueInBlock: Bool = true, showTeacherInBlock: Bool = true,
        courseDetail: [DetailFieldSetting] = SchedulePreferences.courseFieldDefaults,
        examDetail: [DetailFieldSetting] = SchedulePreferences.examFieldDefaults
    ) {
        self.palette = palette
        self.showVenueInBlock = showVenueInBlock
        self.showTeacherInBlock = showTeacherInBlock
        self.courseDetail = courseDetail
        self.examDetail = examDetail
    }

    private enum CodingKeys: String, CodingKey { case palette, showVenueInBlock, showTeacherInBlock, courseDetail, examDetail }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        palette = (try? c.decodeIfPresent(CoursePalette.self, forKey: .palette)) ?? .macaron
        showVenueInBlock = (try? c.decodeIfPresent(Bool.self, forKey: .showVenueInBlock)) ?? true
        showTeacherInBlock = (try? c.decodeIfPresent(Bool.self, forKey: .showTeacherInBlock)) ?? true
        courseDetail = Self.merged((try? c.decodeIfPresent([DetailFieldSetting].self, forKey: .courseDetail)) ?? nil, defaults: Self.courseFieldDefaults)
        examDetail = Self.merged((try? c.decodeIfPresent([DetailFieldSetting].self, forKey: .examDetail)) ?? nil, defaults: Self.examFieldDefaults)
    }

    static func merged(_ saved: [DetailFieldSetting]?, defaults: [DetailFieldSetting]) -> [DetailFieldSetting] {
        guard let saved else { return defaults }
        let known = Set(defaults.map(\.id))
        var seen = Set<String>()
        let kept = saved.filter { known.contains($0.id) && seen.insert($0.id).inserted }
        return kept + defaults.filter { !seen.contains($0.id) }
    }

    public static let key = SharedKey<SchedulePreferences>("schedule.preferences")
}

@MainActor @Observable
public final class SchedulePreferencesStore {
    public var value: SchedulePreferences {
        didSet { if value != oldValue { shared?.set(value, for: SchedulePreferences.key) } }
    }
    @ObservationIgnored private let shared: (any SharedStore)?

    public init(shared: (any SharedStore)? = nil) {
        self.shared = shared
        self.value = shared?.value(SchedulePreferences.key) ?? SchedulePreferences()
    }

    public func reset() { value = SchedulePreferences() }
}
