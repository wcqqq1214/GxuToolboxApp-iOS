import {open} from "@op-engineering/op-sqlite";
import {drizzle} from "drizzle-orm/op-sqlite";
import migrations from "../../drizzle/migrations/migrations";
import {migrate} from "drizzle-orm/op-sqlite/migrator";
import * as schema from "./schema";

export const expoDb = open({name: "gxu_tool.db"});

// 兼容补丁：drizzle-orm 0.45.2 的 op-sqlite driver 在 all()/get() 里直接对
// executeRawAsync 的返回值调用 .map()，期望拿到 Scalar[][]；但 op-sqlite 17 的
// executeRaw 返回 { rawRows, columnNames, rowsAffected } 对象，导致 db.select() 抛
// "undefined is not a function"。这里把返回值规整为 rawRows 数组。
const originalExecuteRawAsync = (expoDb as any).executeRawAsync;
(expoDb as any).executeRawAsync = async (query: string, params?: unknown[]) => {
    const res = await originalExecuteRawAsync(query, params);
    return res?.rawRows ?? res;
};

export const db = drizzle(expoDb, {schema});

export async function initDB() {
    // 删除所有可能遗留的旧表
    const oldTables = ["evaluation_templates", "user_profiles", "term_start_day", "exam_score"];

    for (const table of oldTables) {
        await expoDb.execute(`DROP TABLE IF EXISTS ${table};`);
    }

    console.log("已删出表");

    // 交由 Drizzle 执行所有迁移
    await migrate(db, migrations);
}
