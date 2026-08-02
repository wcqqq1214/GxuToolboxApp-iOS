import {backendHttp} from "@/features/backend/api/index.ts";
import {FeedbackForm} from "@/features/feedback/screens/FeedbackView.tsx";
import {FeedbackItemVM, washFeedbackList} from "@/features/backend/api/feedbackSchema.ts";

export class CreateFeedback extends FeedbackForm {
    userId: string;
    deviceModel: string;
    appVersion: string;
}
export const feedbackApi = {
    submit: async (body: CreateFeedback): Promise<number> => {
        const res = await backendHttp.post<any>("/feedback", body);
        return res.data.data.id;
    },
    getMyList: async (userId: string, page: number = 1, pageSize: number = 10): Promise<FeedbackItemVM[]> => {
        const res = await backendHttp.get<any>(`/feedback/${userId}`, {
            params: {page, pageSize},
        });
        return washFeedbackList(res.data.data.list);
    },
};
