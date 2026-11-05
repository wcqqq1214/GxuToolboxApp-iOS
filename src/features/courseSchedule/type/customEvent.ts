import {z} from "zod";
import type {ScheduleTableItem} from "./schedule";

const period = z.number().int().min(1).max(13);

export const customEventSchema = z
    .object({
        title: z.string().trim().min(1, "请输入实验课名称").max(100, "名称最多 100 字"),
        location: z.string().trim().max(200),
        teacher: z.string().trim().max(100),
        notes: z.string().trim().max(2000, "备注最多 2000 字"),
        year: z.number().int().positive(),
        term: z.union([z.literal(1), z.literal(2)]),
        weeks: z
            .array(z.number().int().min(1).max(53))
            .min(1, "请选择教学周")
            .transform(weeks => [...new Set(weeks)].sort((a, b) => a - b)),
        weekday: z.number().int().min(1).max(7),
        begin: period,
        end: period,
    })
    .refine(value => value.end >= value.begin, {
        message: "结束节次不能早于开始节次",
        path: ["end"],
    });

export type CustomEventInput = z.infer<typeof customEventSchema>;
export type CustomEvent = CustomEventInput & {id: number};

export interface CustomEventOccurrence extends ScheduleTableItem<never, "custom"> {
    eventId: number;
}
