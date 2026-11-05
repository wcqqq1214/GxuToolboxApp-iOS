import GxuStorage

/// 无 UI 的课表逻辑（模型、接口、缓存、周次计算、下一节课）。小组件和 Live Activity 也可以用。
public enum ScheduleKit {
    public static let migrations = FeatureMigrations(feature: "schedule") { migrator in
        // 课表快照带 studentId：不同账号互不串数据（RN 的缓存不区分账号）
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
        // 冲突课程：用户选中显示哪一门（带 studentId 和学期）
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
        // 节假日和调课数据（data.json）是学校日历，整份 JSON 存一行
        migrator.registerMigration("schedule.v1.createCampusCalendar") { db in
            try db.create(table: "campus_calendar") { t in
                t.primaryKey("id", .integer)
                t.column("json", .blob).notNull()
                t.column("updatedAt", .double).notNull()
            }
        }
        // 学期开始日是学校日历，不含个人数据
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

    /// 小组件读取的快照；key 里带学号，切换账号后不会读到上个人的课
    public static func widgetSnapshotKey(studentId: String) -> SharedKey<NextCourses> {
        SharedKey("schedule.widgetSnapshot.\(studentId)")
    }
}
