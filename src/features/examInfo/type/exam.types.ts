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

/**
 * 可持久化的纯数据形状：去掉运行时计算出来的 date/status。
 * dayjs 实例过 JSON/MMKV 序列化会丢原型，所以缓存一律用它。
 */
export type StoredExam = Omit<ExamWithMeta, "date" | "status">;
