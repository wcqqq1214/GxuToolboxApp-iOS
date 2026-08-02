import {db} from "@/core/db";
import {evaluationTemplates} from "@/core/schema";
import {desc, eq} from "drizzle-orm";

export interface TemplateData {
    selected: Record<number, Record<number, Record<number, number>>>;
    comment: string;
}

export interface TemplateRow {
    id: number;
    name: string;
    data: TemplateData;
    created_at: number;
    updated_at: number;
}

// 这里的 DB 操作全部变成异步的，因为 Drizzle 底层是基于 promise 的 API。
// 需要在调用方使用 await 或改成异步 Hook 逻辑
// （如果依然需要同步 API，只能用 runSync，但是 Drizzle 对 React Native 默认推崇 async）

// 列出所有模板（只取 id + name，不加载 data）
export async function listTemplates(): Promise<{id: number; name: string}[]> {
    const result = await db
        .select({
            id: evaluationTemplates.id,
            name: evaluationTemplates.name,
        })
        .from(evaluationTemplates)
        .orderBy(desc(evaluationTemplates.updatedAt));

    return result;
}

// 按 id 获取完整模板
export async function getTemplate(id: number): Promise<TemplateRow | null> {
    const result = await db.select().from(evaluationTemplates).where(eq(evaluationTemplates.id, id)).limit(1);

    if (result && result.length > 0) {
        const row = result[0];
        return {
            id: row.id,
            name: row.name,
            data: JSON.parse(row.data),
            created_at: row.createdAt ? Math.floor(row.createdAt.getTime() / 1000) : 0,
            updated_at: row.updatedAt ? Math.floor(row.updatedAt.getTime() / 1000) : 0,
        };
    }
    return null;
}

// 按名称获取（用于检查重名）
export async function getTemplateByName(name: string): Promise<TemplateRow | null> {
    const result = await db.select().from(evaluationTemplates).where(eq(evaluationTemplates.name, name)).limit(1);

    if (result && result.length > 0) {
        const row = result[0];
        return {
            id: row.id,
            name: row.name,
            data: JSON.parse(row.data),
            created_at: row.createdAt ? Math.floor(row.createdAt.getTime() / 1000) : 0,
            updated_at: row.updatedAt ? Math.floor(row.updatedAt.getTime() / 1000) : 0,
        };
    }
    return null;
}

// 新建模板
export async function createTemplate(name: string, data: TemplateData): Promise<number> {
    const json = JSON.stringify(data);
    const result = await db
        .insert(evaluationTemplates)
        .values({
            name: name,
            data: json,
            createdAt: new Date(),
            updatedAt: new Date(),
        })
        .returning({insertedId: evaluationTemplates.id});

    return result[0].insertedId;
}

// 更新模板（按 id）
export async function updateTemplate(id: number, name: string, data: TemplateData): Promise<void> {
    const json = JSON.stringify(data);
    await db
        .update(evaluationTemplates)
        .set({
            name: name,
            data: json,
            updatedAt: new Date(),
        })
        .where(eq(evaluationTemplates.id, id));
}

// 删除模板
export async function deleteTemplate(id: number): Promise<void> {
    await db.delete(evaluationTemplates).where(eq(evaluationTemplates.id, id));
}
