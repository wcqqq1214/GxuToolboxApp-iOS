PRAGMA foreign_keys=OFF;--> statement-breakpoint
CREATE TABLE `__new_customEvents` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`ownerKey` text NOT NULL,
	`title` text NOT NULL,
	`location` text NOT NULL,
	`teacher` text NOT NULL,
	`notes` text NOT NULL,
	`year` integer NOT NULL,
	`term` integer NOT NULL,
	`weeks` text NOT NULL,
	`weekday` integer NOT NULL,
	`begin` integer NOT NULL,
	`end` integer NOT NULL
);
--> statement-breakpoint
INSERT INTO `__new_customEvents`("id", "ownerKey", "title", "location", "teacher", "notes", "year", "term", "weeks", "weekday", "begin", "end")
SELECT "id", "ownerKey", "title", "location", "teacher", "notes", "year", "term", "weeks", "weekday", "begin", "end"
FROM `customEvents`
WHERE "category" = 'experiment' AND "mode" = 'teachingWeeks';--> statement-breakpoint
DROP TABLE `customEvents`;--> statement-breakpoint
ALTER TABLE `__new_customEvents` RENAME TO `customEvents`;--> statement-breakpoint
PRAGMA foreign_keys=ON;
