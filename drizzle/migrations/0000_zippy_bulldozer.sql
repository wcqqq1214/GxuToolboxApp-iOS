CREATE TABLE `evaluationTemplates`
(
    `id`        integer PRIMARY KEY AUTOINCREMENT NOT NULL,
    `name`      text                              NOT NULL,
    `data`      text                              NOT NULL,
    `createdAt` integer,
    `updatedAt` integer
);
--> statement-breakpoint
CREATE UNIQUE INDEX `evaluationTemplates_name_unique` ON `evaluationTemplates` (`name`);--> statement-breakpoint
CREATE TABLE `examScore`
(
    `id`          text PRIMARY KEY NOT NULL,
    `year`        integer          NOT NULL,
    `term`        integer          NOT NULL,
    `courseName`  text             NOT NULL,
    `credit`      integer          NOT NULL,
    `score`       integer          NOT NULL,
    `teacherName` text             NOT NULL,
    `uploadAt`    text             NOT NULL,
    `usualScore`  text             NOT NULL,
    `updatedAt`   integer          NOT NULL
);
--> statement-breakpoint
CREATE TABLE `termStartDay`
(
    `year`      integer NOT NULL,
    `term`      integer NOT NULL,
    `day`       integer NOT NULL,
    `week`      integer NOT NULL,
    `isCurrent` integer NOT NULL,
    PRIMARY KEY (`year`, `term`)
);
--> statement-breakpoint
CREATE TABLE `userProfiles`
(
    `studentId`  text PRIMARY KEY NOT NULL,
    `name`       text,
    `idCard`     text,
    `grade`      text,
    `college`    text,
    `major`      text,
    `className`  text,
    `studyYears` integer,
    `updatedAt`  integer          NOT NULL
);
