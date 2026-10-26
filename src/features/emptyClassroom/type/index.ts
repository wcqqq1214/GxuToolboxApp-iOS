import type {EmptyClassroom} from "gxu-tool-adapters/jw";

/** 后端清洗后的一页空闲教室数据。 */
export type ClassroomPage = EmptyClassroom;

/** 单间教室条目。 */
export type ClassroomItem = EmptyClassroom["items"][number];

/** 逻辑学期：1 或 2。教务系统的 3/12 在边界处转换。 */
export type LogicalTerm = 1 | 2;

/** API 层解析后的教室元数据，座位数已转成 number|null。 */
export type RoomPayload = {
    /** 业务键：building + "\u0000" + name。 */
    key: string;
    building: string;
    name: string;
    placeType: string;
    seatCount: number | null;
    seatCountForExam: number | null;
    owner: string;
    allowToUse: string;
};

/** 教室维表行。 */
export type RoomRecord = Omit<RoomPayload, "key"> & {
    id: number;
    updatedAt: Date;
};

/** 按天进度行。 */
export type DayRecord = {
    year: number;
    term: LogicalTerm;
    week: number;
    day: number;
    fetchedAt: Date;
    slotCount: number;
};

/** 周快照元数据。 */
export type WeekSnapshot = {
    year: number;
    term: LogicalTerm;
    week: number;
    fetchedAt: Date;
    completedDays: number;
    slotCount: number;
    roomCount: number;
    complete: boolean;
};

/** 构建连续空闲段所需的最小行结构。 */
export type FreePeriodRow = {
    week: number;
    day: number;
    period: number;
};

/** 合并后的连续空闲段，供 TimeSchedule 渲染。 */
export type FreeRunItem = {
    /** 稳定 ID：`${week}-${day}-${begin}-${end}`。 */
    id: string;
    week: number;
    day: number;
    /** 起始节次，1-based，含。 */
    begin: number;
    /** 结束节次，1-based，含。 */
    end: number;
};

/** 一个教学日的抓取结果。 */
export type DayPayload = {
    day: number;
    /** roomKey -> 教室元数据（同一教室元数据第一份为准）。 */
    rooms: Map<string, RoomPayload>;
    /** roomKey -> 当天空闲节次（升序、已去重）。 */
    freePeriods: Map<string, number[]>;
};
