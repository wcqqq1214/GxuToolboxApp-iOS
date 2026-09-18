import {integer, primaryKey, real, sqliteTable, text} from "drizzle-orm/sqlite-core";

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
