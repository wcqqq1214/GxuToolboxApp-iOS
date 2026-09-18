CREATE TABLE `selectedCourses` (
	`studentId` text NOT NULL,
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`classId` text NOT NULL,
	`courseId` text NOT NULL,
	`courseName` text NOT NULL,
	`type` text NOT NULL,
	`selectionType` text NOT NULL,
	`classification` text NOT NULL,
	`belongTo` text NOT NULL,
	`system` text NOT NULL,
	`teacher` text NOT NULL,
	`teacherId` text NOT NULL,
	`credit` real NOT NULL,
	`updatedAt` integer NOT NULL,
	PRIMARY KEY(`studentId`, `year`, `term`, `classId`)
);
