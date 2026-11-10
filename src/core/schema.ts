import {integer, primaryKey, real, sqliteTable, text, uniqueIndex} from "drizzle-orm/sqlite-core";

/** 按账号保存实验课，时间由学期、教学周、星期和节次确定。 */
export const customEvents = sqliteTable("customEvents", {
    id: integer("id").primaryKey({autoIncrement: true}),
    ownerKey: text("ownerKey").notNull(),
    title: text("title").notNull(),
    location: text("location").notNull(),
    teacher: text("teacher").notNull(),
    notes: text("notes").notNull(),
    year: integer("year").notNull(),
    term: integer("term").notNull(),
    weeks: text("weeks", {mode: "json"}).$type<number[]>().notNull(),
    weekday: integer("weekday").notNull(),
    begin: integer("begin").notNull(),
    end: integer("end").notNull(),
});

export const evaluationTemplates = sqliteTable("evaluationTemplates", {
    id: integer("id").primaryKey({autoIncrement: true}),
    name: text("name").notNull().unique(),
    data: text("data").notNull(),
    createdAt: integer("createdAt", {mode: "timestamp"}),
    updatedAt: integer("updatedAt", {mode: "timestamp"}),
});

export const userProfiles = sqliteTable("userProfiles", {
    studentId: text("studentId").notNull().primaryKey(),
    name: text("name"),
    idCard: text("idCard"),
    grade: text("grade"),
    college: text("college"),
    major: text("major"),
    className: text("className"),
    studyYears: integer("studyYears"),
    updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
});

export const termStartDay = sqliteTable(
    "termStartDay",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        day: integer("day", {mode: "timestamp"}).notNull(),
        week: integer("week").notNull(),
        isCurrent: integer("isCurrent", {mode: "boolean"}).notNull(),
    },
    table => {
        return {
            pk: primaryKey({columns: [table.year, table.term]}),
        };
    },
);

export const examScore = sqliteTable("examScore", {
    id: text("id").notNull().primaryKey(),
    year: integer("year").notNull(),
    term: integer("term").notNull(),
    courseName: text("courseName").notNull(),
    credit: integer("credit").notNull(),
    score: integer("score").notNull(),
    teacherName: text("teacherName").notNull(),
    uploadAt: text("uploadAt").notNull(),
    usualScore: text("usualScore").notNull(),
    updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
});

export const examInfo = sqliteTable(
    "examInfo",
    {
        id: text("id").notNull(),
        studentId: text("studentId").notNull(),
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        course: text("course").notNull(),
        classroom: text("classroom").notNull(),
        time: text("time").notNull(),
        type: text("type").notNull(),
        seat: text("seat").notNull(),
        updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
    },
    table => {
        return {
            pk: primaryKey({columns: [table.id, table.studentId, table.year, table.term]}),
        };
    },
);

export const selectedCourses = sqliteTable(
    "selectedCourses",
    {
        studentId: text("studentId").notNull(),
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        classId: text("classId").notNull(),
        courseId: text("courseId").notNull(),
        courseName: text("courseName").notNull(),
        type: text("type").notNull(),
        selectionType: text("selectionType").notNull(),
        classification: text("classification").notNull(),
        belongTo: text("belongTo").notNull(),
        system: text("system").notNull(),
        teacher: text("teacher").notNull(),
        teacherId: text("teacherId").notNull(),
        credit: real("credit").notNull(),
        updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
    },
    table => ({
        pk: primaryKey({columns: [table.studentId, table.year, table.term, table.classId]}),
    }),
);

/** 空闲教室维表。正方接口没有稳定教室编号，业务键为 (building, name)。 */
export const emptyClassroomRooms = sqliteTable(
    "emptyClassroomRooms",
    {
        id: integer("id").primaryKey({autoIncrement: true}),
        name: text("name").notNull(),
        building: text("building").notNull(),
        placeType: text("placeType").notNull().default(""),
        seatCount: integer("seatCount"),
        seatCountForExam: integer("seatCountForExam"),
        owner: text("owner").notNull().default(""),
        allowToUse: text("allowToUse").notNull().default(""),
        updatedAt: integer("updatedAt", {mode: "timestamp"}).notNull(),
    },
    table => ({
        buildingNameUnique: uniqueIndex("emptyClassroomRooms_building_name_idx").on(
            table.building,
            table.name,
        ),
    }),
);

/** 教室-节次事实表，仅存空闲节次。不额外建索引，按复合主键前缀查询。 */
export const emptyClassroomSlots = sqliteTable(
    "emptyClassroomSlots",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        week: integer("week").notNull(),
        day: integer("day").notNull(),
        period: integer("period").notNull(),
        roomId: integer("roomId").notNull(),
    },
    table => ({
        pk: primaryKey({
            columns: [table.year, table.term, table.week, table.day, table.period, table.roomId],
        }),
    }),
);

/** 按天抓取进度，断点续传的唯一真相。 */
export const emptyClassroomDays = sqliteTable(
    "emptyClassroomDays",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        week: integer("week").notNull(),
        day: integer("day").notNull(),
        fetchedAt: integer("fetchedAt", {mode: "timestamp"}).notNull(),
        slotCount: integer("slotCount").notNull().default(0),
    },
    table => ({
        pk: primaryKey({columns: [table.year, table.term, table.week, table.day]}),
    }),
);

/** 周缓存快照元数据，不存 sizeBytes，大小由 slotCount/roomCount 实时估算。 */
export const emptyClassroomSnapshots = sqliteTable(
    "emptyClassroomSnapshots",
    {
        year: integer("year").notNull(),
        term: integer("term").notNull(),
        week: integer("week").notNull(),
        fetchedAt: integer("fetchedAt", {mode: "timestamp"}).notNull(),
        completedDays: integer("completedDays").notNull().default(0),
        slotCount: integer("slotCount").notNull().default(0),
        roomCount: integer("roomCount").notNull().default(0),
        complete: integer("complete", {mode: "boolean"}).notNull().default(false),
    },
    table => ({
        pk: primaryKey({columns: [table.year, table.term, table.week]}),
    }),
);
