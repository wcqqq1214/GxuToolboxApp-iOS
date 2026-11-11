import GxuStorage

public enum ScheduleKit {
    public static let migrations = FeatureMigrations(feature: "schedule") { migrator in
        migrator.registerMigration("schedule.v1.createSnapshots") { db in
            try db.create(table: "schedule_snapshot") { t in
                t.column("studentId", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("json", .blob).notNull()
                t.column("updatedAt", .double).notNull()
                t.primaryKey(["studentId", "year", "term"])
            }
        }
        migrator.registerMigration("schedule.v1.createConflictChoice") { db in
            try db.create(table: "schedule_conflict_choice") { t in
                t.column("studentId", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("groupKey", .text).notNull()
                t.column("choice", .text).notNull()
                t.primaryKey(["studentId", "year", "term", "groupKey"])
            }
        }
        migrator.registerMigration("schedule.v1.createCustomActivity") { db in
            try db.create(table: "schedule_custom_activity") { t in
                t.column("studentId", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("id", .text).notNull()
                t.column("json", .blob).notNull()
                t.primaryKey(["studentId", "year", "term", "id"])
            }
        }
        migrator.registerMigration("schedule.v1.createCampusCalendar") { db in
            try db.create(table: "campus_calendar") { t in
                t.primaryKey("id", .integer)
                t.column("json", .blob).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }
        migrator.registerMigration("schedule.v1.createTermStartDay") { db in
            try db.create(table: "term_start_day") { t in
                t.column("year", .integer).notNull()
                t.column("term", .integer).notNull()
                t.column("day", .text).notNull()
                t.column("week", .integer).notNull()
                t.primaryKey(["year", "term"])
            }
        }
    }

    public static func widgetSnapshotKey(studentId: String) -> SharedKey<NextCourses> {
        SharedKey("schedule.widgetSnapshot.\(studentId)")
    }
}
