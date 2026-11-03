import {ReactNode} from "react";
import moment from "moment";
import {ExamWithMeta} from "@/features/examInfo/type/exam.types.ts";
import {Schedule} from "gxu-tool-adapters/jw";

export interface TimeScheduleItemData<T = any> {
    /** 元素数据 */
    data: T[];
    /** 元素渲染 */
    itemRender?: (item: T, day: moment.Moment, week: number) => ReactNode;
    /** 判断元素是否在当天渲染 */
    isItemShow?: (item: T, day: moment.Moment, week: number) => boolean;
    /** 判断两项是否应合并到同一个冲突栈 */
    isItemStack?: (a: T, b: T, ori: T[], day: moment.Moment, week: number) => boolean;
    /** 冲突栈渲染：同一时段重叠的多项数据合并渲染 */
    stackRender?: (items: T[], day: moment.Moment, week: number, timeRange: [number, number]) => ReactNode;
    /**
     * 是否需要应用调课，默认 true。
     *
     * 与 TimeSchedule 的补课日 / 调休日判定配套：
     *   - true  参与调课：补课日列渲染被补日的元素；调休日列整列不排课；
     *   - false 不参与调课：始终按本列自然日期渲染（如节假日标签）。
     */
    needShift?: boolean;
    /**
     * 补课日列是否额外渲染「本列自然日期本来应有的元素」，默认 false。
     *
     * 背景：补课日（workDate，如周日）列默认整列改渲染被补日（restDate，如周五）的课，
     * 本列原本排在这一天的元素会被顶掉（例如恰好安排在补课日当天的考试）。
     * 开启后两组元素同时渲染：
     *   - 主组：被补日的元素（受 needShift 控制）
     *   - 附加组：本列自然日期 + 当前教学周的元素
     * 两组各自做时段冲突合并，不互相吞并。
     *
     * 仅在补课日列生效；非补课日列（含调休日列）一律不受影响——
     * 调休日列按 needShift 的语义整列不排课。
     */
    showPreShiftItems?: boolean;
}

/**
 * @deprecated NBH建议弃用
 */
export interface ScheduleTableItem<T = any, K extends string = string> {
    id: string;
    week: number;
    day: 1 | 2 | 3 | 4 | 5 | 6 | 7;
    begin: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13;
    end: 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13;
    title: string;
    subtitle?: string;
    location?: string;
    teacher?: string;
    color?: string;
    kind?: K;
    seat?: string;
    status?: number;
    isShift?: boolean;
    qq?: string;
    /**
     * @deprecated 请不要用完全透传的原始数据。。。
     */
    raw?: T;
}

// 基础网格坐标（所有格子共有）
export interface ScheduleGridPos {
    id: string;
    week: number;
    day: 1 | 2 | 3 | 4 | 5 | 6 | 7;
    begin: number;
    end: number;
}

// 课程项
export interface ScheduleCourseItem extends ScheduleGridPos {
    kind: "course";
    title: string;
    location: string;
    teacher: string;
    qq?: string;
    // 完整的课程信息
    detail: Schedule["theoryList"][number];
}

// 考试项：直接挂完整的考试数据
export interface ScheduleExamItem extends ScheduleGridPos {
    kind: "exam";
    title: string;
    location: string;
    seat: string;
    // 完整的考试信息
    detail: ExamWithMeta;
}

// 联合类型：排他互斥
export type ScheduleTableItemV2 = ScheduleCourseItem | ScheduleExamItem;
