import FeatureAccount
import FeatureCampus
import FeatureCourse
import FeatureExam
import FeatureMisc
import GxuStorage
import ScheduleUI

/// 各 feature 只能增改自己那一行
enum FeatureRegistry {
    static let migrations: [FeatureMigrations] = [
        AccountFeature.migrations,
        ScheduleFeature.migrations,
        CampusFeature.migrations,
        ExamFeature.migrations,
        CourseFeature.migrations,
        MiscFeature.migrations,
    ]
}
