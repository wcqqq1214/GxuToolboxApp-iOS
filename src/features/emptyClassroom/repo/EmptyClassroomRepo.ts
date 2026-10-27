import {and, asc, count, countDistinct, eq, inArray, like, or} from "drizzle-orm";
import {db, expoDb} from "@/core/db";
import {emptyClassroomDays, emptyClassroomRooms, emptyClassroomSlots, emptyClassroomSnapshots} from "@/core/schema";
import type {DayPayload, FreePeriodRow, LogicalTerm, RoomBuildingSummary, RoomRecord, WeekSnapshot} from "../type";
import {DAYS, ROOM_BATCH_SIZE, SLOT_BATCH_SIZE} from "../utils/constants";
import {estimateSizeBytes} from "../utils/format";
import {roomKey} from "../utils/roomKey";

/** drizzle 事务回调参数类型。 */
type WriteTransaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

export type EmptyClassroomStorageUsage = {
    roomsBytes: number;
    availabilityBytes: number;
};

/**
 * 模块级写队列：op-sqlite 只有单连接，drizzle 的 transaction 是异步的。
 * saveDay/completeWeek/deleteWeek 必须串行，避免其他写操作插进当天事务。
 * 读操作不排队。
 */
let writeChain: Promise<void> = Promise.resolve();

function enqueueWrite<T>(operation: () => Promise<T>): Promise<T> {
    const result = writeChain.then(operation);
    // 队列自身永远 resolve，后续写操作不会因前一次失败被跳过。
    writeChain = result.then(
        () => undefined,
        () => undefined,
    );
    return result;
}

function chunked<T>(rows: T[], size: number): T[][] {
    const chunks: T[][] = [];
    for (let index = 0; index < rows.length; index += size) {
        chunks.push(rows.slice(index, index + size));
    }
    return chunks;
}

/** DB 的 term 是 integer；快照对外使用逻辑学期 1|2。 */
function toWeekSnapshot(row: typeof emptyClassroomSnapshots.$inferSelect): WeekSnapshot {
    return {...row, term: row.term as LogicalTerm};
}

/** 分块 upsert 教室维表；唯一索引 (building,name) 冲突时保留旧元数据。 */
async function upsertRooms(tx: WriteTransaction, payload: DayPayload, updatedAt: Date): Promise<void> {
    const rows = [...payload.rooms.values()].map(room => ({
        name: room.name,
        building: room.building,
        placeType: room.placeType,
        seatCount: room.seatCount,
        seatCountForExam: room.seatCountForExam,
        owner: room.owner,
        allowToUse: room.allowToUse,
        updatedAt,
    }));

    for (const batch of chunked(rows, ROOM_BATCH_SIZE)) {
        await tx
            .insert(emptyClassroomRooms)
            .values(batch)
            .onConflictDoNothing({target: [emptyClassroomRooms.building, emptyClassroomRooms.name]});
    }
}

/** 读取全部教室 id；不依赖 lastInsertRowid，兼容 onConflictDoNothing。 */
async function selectRoomIdMap(tx: WriteTransaction): Promise<Map<string, number>> {
    const rows = await tx
        .select({
            id: emptyClassroomRooms.id,
            building: emptyClassroomRooms.building,
            name: emptyClassroomRooms.name,
        })
        .from(emptyClassroomRooms);

    const map = new Map<string, number>();
    for (const row of rows) {
        map.set(roomKey(row.building, row.name), row.id);
    }
    return map;
}

/**
 * 重算并 upsert 周快照。
 * completedDays 以 day 表行数为准；slotCount 用 day.slotCount 求和；
 * roomCount 只在 7 天齐时对本周 slots 做一次 countDistinct。
 */
async function upsertSnapshot(
    tx: WriteTransaction,
    year: number,
    term: LogicalTerm,
    week: number,
    fetchedAt: Date,
): Promise<void> {
    const dayRows = await tx
        .select({slotCount: emptyClassroomDays.slotCount})
        .from(emptyClassroomDays)
        .where(
            and(
                eq(emptyClassroomDays.year, year),
                eq(emptyClassroomDays.term, term),
                eq(emptyClassroomDays.week, week),
            ),
        );

    const completedDays = dayRows.length;
    const slotCount = dayRows.reduce((total, row) => total + row.slotCount, 0);
    const complete = completedDays === DAYS;

    let roomCount = 0;
    if (complete) {
        const [countRow] = await tx
            .select({value: countDistinct(emptyClassroomSlots.roomId)})
            .from(emptyClassroomSlots)
            .where(
                and(
                    eq(emptyClassroomSlots.year, year),
                    eq(emptyClassroomSlots.term, term),
                    eq(emptyClassroomSlots.week, week),
                ),
            );
        roomCount = Number(countRow?.value ?? 0);
    }

    const snapshot = {
        year,
        term,
        week,
        fetchedAt,
        completedDays,
        slotCount,
        roomCount,
        complete,
    };

    await tx
        .insert(emptyClassroomSnapshots)
        .values(snapshot)
        .onConflictDoUpdate({
            target: [emptyClassroomSnapshots.year, emptyClassroomSnapshots.term, emptyClassroomSnapshots.week],
            set: {
                fetchedAt,
                completedDays,
                slotCount,
                roomCount,
                complete,
            },
        });
}

export const emptyClassroomRepo = {
    /**
     * 作用：原子写入一天的空闲教室数据（教室维表 + 当天 slots + day 行 + 周快照）。
     * 入参：
     * - year/term/week/day：定位当天；
     * - payload：API 合并后的教室元数据与空闲节次。
     * 出参：无。
     * 修改注意：整个操作走模块写队列并包在一个事务里；任一步失败则该天回滚，
     * 下次续传会重抓这一天。
     */
    async saveDay(year: number, term: LogicalTerm, week: number, day: number, payload: DayPayload): Promise<void> {
        await enqueueWrite(() =>
            db.transaction(async tx => {
                const fetchedAt = new Date();

                await upsertRooms(tx, payload, fetchedAt);
                const roomIds = await selectRoomIdMap(tx);

                await tx
                    .delete(emptyClassroomSlots)
                    .where(
                        and(
                            eq(emptyClassroomSlots.year, year),
                            eq(emptyClassroomSlots.term, term),
                            eq(emptyClassroomSlots.week, week),
                            eq(emptyClassroomSlots.day, day),
                        ),
                    );

                const slotRows: (typeof emptyClassroomSlots.$inferInsert)[] = [];
                for (const [key, periods] of payload.freePeriods) {
                    const roomId = roomIds.get(key);
                    if (roomId === undefined) continue;

                    const seen = new Set<number>();
                    for (const period of periods) {
                        if (seen.has(period)) continue;
                        seen.add(period);
                        slotRows.push({year, term, week, day, period, roomId});
                    }
                }
                for (const batch of chunked(slotRows, SLOT_BATCH_SIZE)) {
                    await tx.insert(emptyClassroomSlots).values(batch);
                }

                let slotCount = 0;
                for (const periods of payload.freePeriods.values()) {
                    slotCount += periods.length;
                }

                await tx
                    .insert(emptyClassroomDays)
                    .values({year, term, week, day, fetchedAt, slotCount})
                    .onConflictDoUpdate({
                        target: [
                            emptyClassroomDays.year,
                            emptyClassroomDays.term,
                            emptyClassroomDays.week,
                            emptyClassroomDays.day,
                        ],
                        set: {fetchedAt, slotCount},
                    });

                await upsertSnapshot(tx, year, term, week, fetchedAt);
            }),
        );
    },

    /** 作用：读取某周已完成（已原子写入）的 day 列表，升序。入参 year/term/week；出参 day[]。 */
    async getCompletedDays(year: number, term: LogicalTerm, week: number): Promise<number[]> {
        const rows = await db
            .select({day: emptyClassroomDays.day})
            .from(emptyClassroomDays)
            .where(
                and(
                    eq(emptyClassroomDays.year, year),
                    eq(emptyClassroomDays.term, term),
                    eq(emptyClassroomDays.week, week),
                ),
            )
            .orderBy(asc(emptyClassroomDays.day));

        return rows.map(row => row.day);
    },

    /**
     * 作用：读取单周快照。
     * 出参：completedDays===0 的幽灵快照视为未缓存，返回 null。
     */
    async getWeek(year: number, term: LogicalTerm, week: number): Promise<WeekSnapshot | null> {
        const rows = await db
            .select()
            .from(emptyClassroomSnapshots)
            .where(
                and(
                    eq(emptyClassroomSnapshots.year, year),
                    eq(emptyClassroomSnapshots.term, term),
                    eq(emptyClassroomSnapshots.week, week),
                ),
            )
            .limit(1);

        const row = rows[0];
        if (!row || row.completedDays === 0) return null;
        return toWeekSnapshot(row);
    },

    /**
     * 作用：读取某学期所有已缓存周快照，按周次升序。
     * 出参：completedDays===0 的快照被过滤，等价于未缓存。
     */
    async listWeeks(year: number, term: LogicalTerm): Promise<WeekSnapshot[]> {
        const rows = await db
            .select()
            .from(emptyClassroomSnapshots)
            .where(and(eq(emptyClassroomSnapshots.year, year), eq(emptyClassroomSnapshots.term, term)))
            .orderBy(asc(emptyClassroomSnapshots.week));

        return rows.filter(row => row.completedDays > 0).map(toWeekSnapshot);
    },

    /**
     * 作用：读取空闲教室数据在当前数据库中的占用估算。
     * 入参：无；统计范围覆盖本机所有学期。
     * 出参：教室维表和空闲情况分别对应的字节数。
     * 修改注意：周数据从 snapshot.slotCount 汇总，避免扫描最多数十万条 slots。
     */
    async getStorageUsage(): Promise<EmptyClassroomStorageUsage> {
        const result = await expoDb.execute(`
            SELECT
                (SELECT COUNT(*) FROM emptyClassroomRooms) AS roomCount,
                (SELECT COALESCE(SUM(slotCount), 0) FROM emptyClassroomSnapshots) AS slotCount
        `);
        const row = result.rows[0];
        const roomCount = Math.max(0, Number(row?.roomCount ?? 0));
        const slotCount = Math.max(0, Number(row?.slotCount ?? 0));

        return {
            roomsBytes: estimateSizeBytes(0, roomCount),
            availabilityBytes: estimateSizeBytes(slotCount, 0),
        };
    },

    /**
     * 作用：对账并完成某周快照（幂等）。
     * 入参 year/term/week；出参无。
     * 修改注意：用于「7 天都在但 complete=false」的崩溃恢复；不会伪造 0/7 快照以外的数据。
     */
    async completeWeek(year: number, term: LogicalTerm, week: number): Promise<void> {
        await enqueueWrite(() =>
            db.transaction(async tx => {
                await upsertSnapshot(tx, year, term, week, new Date());
            }),
        );
    },

    /** 作用：事务删除某周的 slots/day/snapshot；保留教室维表。 */
    async deleteWeek(year: number, term: LogicalTerm, week: number): Promise<void> {
        await enqueueWrite(() =>
            db.transaction(async tx => {
                await tx
                    .delete(emptyClassroomSlots)
                    .where(
                        and(
                            eq(emptyClassroomSlots.year, year),
                            eq(emptyClassroomSlots.term, term),
                            eq(emptyClassroomSlots.week, week),
                        ),
                    );
                await tx
                    .delete(emptyClassroomDays)
                    .where(
                        and(
                            eq(emptyClassroomDays.year, year),
                            eq(emptyClassroomDays.term, term),
                            eq(emptyClassroomDays.week, week),
                        ),
                    );
                await tx
                    .delete(emptyClassroomSnapshots)
                    .where(
                        and(
                            eq(emptyClassroomSnapshots.year, year),
                            eq(emptyClassroomSnapshots.term, term),
                            eq(emptyClassroomSnapshots.week, week),
                        ),
                    );
            }),
        );
    },

    /** 作用：事务清除全部周数据，保留教室维表。 */
    async clearWeeks(): Promise<void> {
        await enqueueWrite(() =>
            db.transaction(async tx => {
                await tx.delete(emptyClassroomSlots);
                await tx.delete(emptyClassroomDays);
                await tx.delete(emptyClassroomSnapshots);
            }),
        );
    },

    /**
     * 作用：事务清除全部空闲教室数据。
     * 修改注意：周数据通过 roomId 依赖教室维表，因此清除教室时必须一并清除周数据，避免留下悬空引用。
     */
    async clearAll(): Promise<void> {
        await enqueueWrite(() =>
            db.transaction(async tx => {
                await tx.delete(emptyClassroomSlots);
                await tx.delete(emptyClassroomDays);
                await tx.delete(emptyClassroomSnapshots);
                await tx.delete(emptyClassroomRooms);
            }),
        );
    },

    /**
     * 作用：教室选择器首层，直接聚合全局教室维表，避免扫描 slot 事实表。
     * 出参：楼栋及教室数；排序与“其他楼栋”置顶由 UI 工具处理。
     */
    async listRoomBuildings(): Promise<RoomBuildingSummary[]> {
        const rows = await db
            .select({
                building: emptyClassroomRooms.building,
                roomCount: count(),
            })
            .from(emptyClassroomRooms)
            .groupBy(emptyClassroomRooms.building);

        return rows.map(row => ({
            building: row.building,
            roomCount: Number(row.roomCount),
        }));
    },

    /** 作用：进入某楼栋后按需读取该楼栋教室，使用 building/name 唯一索引。 */
    async listRoomsByBuilding(building: string): Promise<RoomRecord[]> {
        return db
            .select()
            .from(emptyClassroomRooms)
            .where(eq(emptyClassroomRooms.building, building))
            .orderBy(asc(emptyClassroomRooms.name));
    },

    /**
     * 作用：直接搜索教室名或场地类别。
     * 入参 building 为 undefined 时搜索全部楼栋；空串仍表示只搜索“其他楼栋”。
     */
    async searchRooms(keyword: string, building?: string): Promise<RoomRecord[]> {
        const normalizedKeyword = keyword.trim();
        if (!normalizedKeyword) return [];

        const pattern = `%${normalizedKeyword}%`;
        return db
            .select()
            .from(emptyClassroomRooms)
            .where(
                and(
                    or(like(emptyClassroomRooms.name, pattern), like(emptyClassroomRooms.placeType, pattern)),
                    building === undefined ? undefined : eq(emptyClassroomRooms.building, building),
                ),
            )
            .orderBy(asc(emptyClassroomRooms.building), asc(emptyClassroomRooms.name));
    },

    /** 作用：按 id 读取单间教室元数据；不存在返回 null。 */
    async getRoom(roomId: number): Promise<RoomRecord | null> {
        const rows = await db.select().from(emptyClassroomRooms).where(eq(emptyClassroomRooms.id, roomId)).limit(1);
        return rows[0] ?? null;
    },

    /**
     * 作用：读取某教室在若干周内的空闲节次行。
     * 入参 weeks 为空时直接返回 []，避免 inArray 空数组。
     */
    async getRoomWeekSlots(year: number, term: LogicalTerm, roomId: number, weeks: number[]): Promise<FreePeriodRow[]> {
        if (weeks.length === 0) return [];

        return db
            .select({
                week: emptyClassroomSlots.week,
                day: emptyClassroomSlots.day,
                period: emptyClassroomSlots.period,
            })
            .from(emptyClassroomSlots)
            .where(
                and(
                    eq(emptyClassroomSlots.year, year),
                    eq(emptyClassroomSlots.term, term),
                    eq(emptyClassroomSlots.roomId, roomId),
                    inArray(emptyClassroomSlots.week, weeks),
                ),
            )
            .orderBy(asc(emptyClassroomSlots.week), asc(emptyClassroomSlots.day), asc(emptyClassroomSlots.period));
    },
};
