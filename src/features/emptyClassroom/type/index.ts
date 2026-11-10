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

/** 教室选择器首层：楼栋及该楼栋的教室数。 */
export type RoomBuildingSummary = {
    /** 原始楼栋名；空串表示教务未返回可识别楼栋。 */
    building: string;
    roomCount: number;
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

/** 按日期和节次范围查询时，数据库返回的教室空闲节次行。 */
export type AvailableRoomPeriodRow = {
    room: RoomRecord;
    week: number;
    day: number;
    period: number;
};

/** 时间查询结果：教室元数据及选中范围内合并后的空闲区间。 */
export type RoomAvailabilityResult = {
    room: RoomRecord;
    freeRuns: FreeRunItem[];
    /** 选中范围内空闲节次总数。 */
    freePeriodCount: number;
    /** 最长的一段连续空闲节数；无空闲时为 0。 */
    longestFreeRun: number;
    /** 选中范围内最早的空闲节次；无空闲时为 null。 */
    firstFreePeriod: number | null;
};

/** 时间查询排序方式。 */
export type TimeQuerySortMode = "default" | "free";

/** 时间查询排序方向；仅空闲时间排序会翻转。 */
export type TimeQuerySortDirection = "asc" | "desc";

/** 已缓存周中的日期选项。 */
export type CachedDateOption = {
    /** ISO 星期，周一为 1。 */
    day: number;
    weekday: string;
    /** 例如 10-26。 */
    dateLabel: string;
    /** 例如 2026-10-26。 */
    dateKey: string;
    cached: boolean;
};

/** 一个教学日的抓取结果。 */
export type DayPayload = {
    day: number;
    /** roomKey -> 教室元数据（同一教室元数据第一份为准）。 */
    rooms: Map<string, RoomPayload>;
    /** roomKey -> 当天空闲节次（升序、已去重）。 */
    freePeriods: Map<string, number[]>;
};
