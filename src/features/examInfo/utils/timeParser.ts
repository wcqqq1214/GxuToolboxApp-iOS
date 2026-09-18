import dayjs, {Dayjs} from "dayjs";

export type ExamStatus = "upcoming" | "past" | "tbd"; // tbd: to be determined

/**
 * Parses an exam time string (e.g., "2023-01-01(09:00-11:00)") and determines its status.
 * The status is 'past' if the exam's end time is in the past.
 * The returned date is the start time, used for sorting.
 * @param timeStr The string to parse.
 * @param now
 * @returns An object with the parsed start Dayjs and its status.
 */
export function parseExamTime(timeStr: string, now: Dayjs = dayjs()): {date: Dayjs | null; status: ExamStatus} {
    const match = timeStr.match(/(\d{4}-\d{2}-\d{2})\((\d{2}:\d{2})-(\d{2}:\d{2})\)/);

    if (!match) {
        return {date: null, status: "tbd"};
    }

    const [, datePart, startTimePart, endTimePart] = match;
    const startDate = dayjs(`${datePart}T${startTimePart}:00`);
    const endDate = dayjs(`${datePart}T${endTimePart}:00`);

    if (!startDate.isValid() || !endDate.isValid()) {
        return {date: null, status: "tbd"};
    }

    const status: ExamStatus = endDate.isBefore(now) ? "past" : "upcoming";

    return {
        date: startDate, // Return the start date for sorting purposes
        status: status,
    };
}
