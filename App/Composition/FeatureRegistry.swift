import FeatureAccount
import FeatureCampus
import FeatureCourse
import ExamUI
import FeatureMisc
import GxuStorage
import ScheduleUI

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
