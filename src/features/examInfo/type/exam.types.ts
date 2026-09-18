import {ExamStatus} from "@/features/examInfo/utils/timeParser.ts";
import type {Exam} from "gxu-tool-adapters/jw";
import type {Dayjs} from "dayjs";

export interface ExamInformation {
    course: string;
    classroom: string;
    time: string;
    courseId: string;
    seat: string | null;
    type: string;

    date: Dayjs | null;
    status: ExamStatus;
}

/**
 * adapter 解析出的 Exam 再补上 parseExamTime 的结果。
 * seat 来自后端原始字段（若存在），默认空串。
 */
export interface ExamWithMeta extends Exam {
    seat: string;
    date: Dayjs | null;
    status: ExamStatus;
}
