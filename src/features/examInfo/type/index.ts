/**
 * 考试信息 DB 交互接口（全驼峰，与 schema 字段名一致，无需转换）。
 * date/status 不落库，读取时用 parseExamTime 动态计算。
 */
export interface ExamInfoRepo {
    id: string;
    studentId: string;
    year: number;
    term: number;
    course: string;
    classroom: string;
    time: string;
    type: string;
    seat: string;
    updatedAt: number; // 秒级时间戳
}
