import {TeacherInfoDetail, TeacherInfoList} from "@gxutool/adapters/teacherInfo";
export type SimpleTeacherInfo = TeacherInfoList["list"][number];

export interface BaseInfoRes {
    code: number;
    data: TeacherInfoList;
    message: string | null;
}
export interface DetailTeacherInfo {
    code: number;
    data: TeacherInfoDetail;
    message: string | null;
}

export type TeacherStackParamList = {
    Query: undefined;
    Detail: {teacher: SimpleTeacherInfo};
};
