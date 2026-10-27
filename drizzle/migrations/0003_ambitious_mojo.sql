CREATE TABLE `emptyClassroomDays` (
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`week` integer NOT NULL,
	`day` integer NOT NULL,
	`fetchedAt` integer NOT NULL,
	`slotCount` integer DEFAULT 0 NOT NULL,
	PRIMARY KEY(`year`, `term`, `week`, `day`)
);
--> statement-breakpoint
CREATE TABLE `emptyClassroomRooms` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`building` text NOT NULL,
	`placeType` text DEFAULT '' NOT NULL,
	`seatCount` integer,
	`seatCountForExam` integer,
	`owner` text DEFAULT '' NOT NULL,
	`allowToUse` text DEFAULT '' NOT NULL,
	`updatedAt` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `emptyClassroomRooms_building_name_idx` ON `emptyClassroomRooms` (`building`,`name`);--> statement-breakpoint
CREATE TABLE `emptyClassroomSlots` (
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`week` integer NOT NULL,
	`day` integer NOT NULL,
	`period` integer NOT NULL,
	`roomId` integer NOT NULL,
	PRIMARY KEY(`year`, `term`, `week`, `day`, `period`, `roomId`)
);
--> statement-breakpoint
CREATE TABLE `emptyClassroomSnapshots` (
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`week` integer NOT NULL,
	`fetchedAt` integer NOT NULL,
	`completedDays` integer DEFAULT 0 NOT NULL,
	`slotCount` integer DEFAULT 0 NOT NULL,
	`roomCount` integer DEFAULT 0 NOT NULL,
	`complete` integer DEFAULT false NOT NULL,
	PRIMARY KEY(`year`, `term`, `week`)
);
