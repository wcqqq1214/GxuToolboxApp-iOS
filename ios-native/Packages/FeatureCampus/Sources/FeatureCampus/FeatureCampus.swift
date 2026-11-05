import GxuStorage
import SwiftUI

public enum CampusFeature {
    public static let migrations = FeatureMigrations(feature: "campus") { migrator in
        // 物理实验课（PEC）：每个学号一份，整条存 JSON
        migrator.registerMigration("campus.v1.createPhyExperiment") { db in
            try db.create(table: "phy_experiment") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("json", .blob).notNull()
                t.primaryKey(["studentId", "id"])
            }
        }
        // 金工实训（工程训练中心）：每个学号一份
        migrator.registerMigration("campus.v1.createEngTraining") { db in
            try db.create(table: "eng_training") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("json", .blob).notNull()
                t.primaryKey(["studentId", "id"])
            }
        }
    }

    /// 工具箱 → 班级课表
    @MainActor
    public static func makeClassScheduleView() -> some View { ClassScheduleView() }

    /// 工具箱 → 全校课表
    @MainActor
    public static func makeFullScheduleView() -> some View { FullScheduleView() }

    /// 工具箱 → 物理实验课（PEC）
    @MainActor
    public static func makePhyExpView() -> some View { PhyExpView() }

    /// 工具箱 → 金工实训（工程训练中心）
    @MainActor
    public static func makeEngTrainingView() -> some View { EngTrainingView() }

    /// 工具箱 → 地图导航
    @MainActor
    public static func makeMapNavigationView() -> some View { MapNavigationView() }

    /// 工具箱 → 教学楼平面图
    @MainActor
    public static func makeTeachBuildingMapView() -> some View { TeachBuildingListView() }

    @MainActor
    public static func makeRootView() -> some View { makeClassScheduleView() }
}
