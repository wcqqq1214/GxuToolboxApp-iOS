import {z} from "zod";

const feedbackItemSchema = z.object({
    id: z.number(),
    userId: z.string(),
    type: z.string(),
    feature: z.string(),
    content: z.string(),
    contactType: z.string(),
    contact: z.string(),
    status: z.string(),
    deviceModel: z.string(),
    appVersion: z.string(),
    adminNote: z.string().nullable(),
    createdAt: z.string(),
    updatedAt: z.string(),
});
export function washFeedbackItem(raw: unknown): FeedbackItemVM | null {
    const result = feedbackItemSchema.safeParse(raw);
    if (!result.success) return null;
    return result.data;
}

export function washFeedbackList(rawList: unknown): FeedbackItemVM[] {
    if (!Array.isArray(rawList)) return [];
    const out: FeedbackItemVM[] = [];
    for (const raw of rawList) {
        const item = washFeedbackItem(raw);
        if (item) out.push(item);
    }
    return out;
}

export type FeedbackItemVM = z.infer<typeof feedbackItemSchema>;
