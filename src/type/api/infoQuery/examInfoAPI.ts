import {QueryResRoot} from "@/type/global.ts";
import {OldExamScore} from "@/type/infoQuery/exam/oldExamScore.ts";
import {UsualScore} from "@/type/infoQuery/exam/usualScore.ts";

// 考试成绩查询返回结果数据类型
export interface ExamScoreQueryRes extends QueryResRoot<OldExamScore> {}

// 平时分查询返回结果数据类型
export interface UsualScoreQueryRes extends QueryResRoot<UsualScore> {}
