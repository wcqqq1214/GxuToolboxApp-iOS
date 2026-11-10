import Foundation
import GxuStorage
import Observation

/// 详情页里的一个字段：可显示 / 隐藏、可改标签，顺序即数组顺序
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

/// 课表和考试的显示偏好（设备级，存在 App Group，小组件也能读）。
public struct SchedulePreferences: Codable, Sendable, Equatable {
    public var palette: CoursePalette
    /// 周网格的课程块里是否显示地点 / 教师
    public var showVenueInBlock: Bool
    public var showTeacherInBlock: Bool
    /// 课程详情的字段
    public var courseDetail: [DetailFieldSetting]
    /// 考试详情的字段（C 的考试页读取）
    public var examDetail: [DetailFieldSetting]

    public static let courseFieldDefaults: [DetailFieldSetting] = [
        .init(id: "time", label: "时间"), .init(id: "weeks", label: "周次"), .init(id: "venue", label: "地点"),
        .init(id: "teacher", label: "教师"), .init(id: "credits", label: "学分"), .init(id: "category", label: "类别"),
        .init(id: "examMethod", label: "考核"), .init(id: "enrollment", label: "选课人数"), .init(id: "qqGroup", label: "QQ 群"),
    ]

    /// 考试卡片的字段：课程名始终显示，不在列表里
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

    /// 宽容解码：缺字段用默认值；版本升级新增的字段补到末尾，已下线的字段丢掉
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

/// 可观察的偏好存储。App 在根视图创建一个，设置页和课表页共用。
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
