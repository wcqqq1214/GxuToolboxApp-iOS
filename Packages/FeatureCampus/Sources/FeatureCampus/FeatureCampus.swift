import GxuAuth
import GxuStorage
import SwiftUI

public enum CampusFeature {
    public static let migrations = FeatureMigrations(feature: "campus") { migrator in
        migrator.registerMigration("campus.v1.createPhyExperiment") { db in
            try db.create(table: "phy_experiment") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("json", .blob).notNull()
                t.primaryKey(["studentId", "id"])
            }
        }
        migrator.registerMigration("campus.v1.createEmptyClassroom") { db in
            try db.create(table: "empty_room") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("building", .text).notNull()
                t.column("name", .text).notNull()
                t.column("placeType", .text).notNull().defaults(to: "")
                t.column("seatCount", .integer)
                t.column("seatCountForExam", .integer)
                t.column("owner", .text).notNull().defaults(to: "")
                t.column("allowToUse", .text).notNull().defaults(to: "")
                t.column("updatedAt", .double).notNull()
                t.uniqueKey(["building", "name"])
            }
            try db.create(table: "empty_day") { t in
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("week", .integer).notNull()
                t.column("day", .integer).notNull()
                t.column("fetchedAt", .double).notNull()
                t.column("slotCount", .integer).notNull()
                t.primaryKey(["year", "term", "week", "day"])
            }
            try db.create(table: "empty_slot") { t in
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("week", .integer).notNull()
                t.column("day", .integer).notNull()
                t.column("period", .integer).notNull()
                t.column("roomId", .integer).notNull().references("empty_room", onDelete: .cascade)
                t.primaryKey(["year", "term", "week", "day", "period", "roomId"])
            }
            try db.create(index: "empty_slot_room", on: "empty_slot", columns: ["roomId", "year", "term", "week"])
            try db.create(table: "empty_snapshot") { t in
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("week", .integer).notNull()
                t.column("fetchedAt", .double).notNull()
                t.column("completedDays", .integer).notNull()
                t.column("slotCount", .integer).notNull()
                t.column("roomCount", .integer).notNull()
                t.column("complete", .integer).notNull()
                t.primaryKey(["year", "term", "week"])
            }
        }
        migrator.registerMigration("campus.v1.createEngTraining") { db in
            try db.create(table: "eng_training") { t in
                t.column("studentId", .text).notNull()
                t.column("id", .text).notNull()
                t.column("json", .blob).notNull()
                t.primaryKey(["studentId", "id"])
            }
        }
    }

    @MainActor
    public static func makeClassScheduleView(exportDestination: (@MainActor () -> AnyView)? = nil) -> some View {
        ClassScheduleView(exportDestination: exportDestination)
    }

    @MainActor
    public static func makeFullScheduleView() -> some View { FullScheduleView() }

    @MainActor
    public static func makePhyExpView() -> some View { PhyExpView() }

    @MainActor
    public static func makeEngTrainingView() -> some View { EngTrainingView() }

    @MainActor
    public static func makeMapNavigationView() -> some View { MapNavigationView() }

    @MainActor
    public static func makeTeachBuildingMapView() -> some View { TeachBuildingListView() }

    @MainActor
    public static func makeEmptyClassroomView() -> some View { EmptyClassroomView() }

    @MainActor
    public static func makeCampusNetworkView(credentials: any CredentialStore) -> some View {
        CampusNetworkView(credentials: credentials)
    }

    @MainActor
    public static func makeRootView() -> some View { makeClassScheduleView() }
}
