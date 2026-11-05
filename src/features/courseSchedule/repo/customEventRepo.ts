import {and, eq} from "drizzle-orm";
import {db, initDB} from "@/core/db";
import {customEvents} from "@/core/schema";
import {customEventSchema, type CustomEvent, type CustomEventInput} from "../type/customEvent";

function toEvent(row: typeof customEvents.$inferSelect): CustomEvent {
    return {id: row.id, ...customEventSchema.parse(row)};
}

export const customEventRepo = {
    /** 按本地身份读取实验课。 */
    async list(ownerKey: string): Promise<CustomEvent[]> {
        await initDB();
        const rows = await db.select().from(customEvents).where(eq(customEvents.ownerKey, ownerKey));
        return rows.map(toEvent);
    },

    /** 校验后保存实验课，更新时同时匹配账号和记录 ID。 */
    async save(ownerKey: string, input: CustomEventInput, id?: number): Promise<CustomEvent> {
        const event = customEventSchema.parse(input);
        await initDB();
        const values = {...event, ownerKey};
        const rows =
            id === undefined
                ? await db.insert(customEvents).values(values).returning()
                : await db
                      .update(customEvents)
                      .set(values)
                      .where(and(eq(customEvents.ownerKey, ownerKey), eq(customEvents.id, id)))
                      .returning();
        if (!rows[0]) throw new Error("实验课已删除或不属于当前账号，请重新打开列表");
        return toEvent(rows[0]);
    },

    async remove(ownerKey: string, id: number): Promise<void> {
        await initDB();
        await db.delete(customEvents).where(and(eq(customEvents.ownerKey, ownerKey), eq(customEvents.id, id)));
    },
};
