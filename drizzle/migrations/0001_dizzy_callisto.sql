CREATE TABLE `examInfo` (
	`id` text NOT NULL,
	`studentId` text NOT NULL,
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`course` text NOT NULL,
	`classroom` text NOT NULL,
	`time` text NOT NULL,
	`type` text NOT NULL,
	`seat` text NOT NULL,
	`updatedAt` integer NOT NULL,
	PRIMARY KEY(`id`, `studentId`, `year`, `term`)
);
