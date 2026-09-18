import {PageData} from "@/core/type/global.ts";

export interface ScoreRepo {
    id: string;
    year: number;
    term: number;
    course_name: string;
    credit: number;
    score: number;
    teacher_name: string;
    upload_at: string;
    usual_score: string;
    updated_at: number;
}

export type ScoreData = PageData<ScoreRepo>;
