export type TeacherInfoList = {
    list: {id: string; name: string; unit: string; picUrl: string}[];
    pages: number;
    total: number;
};

export type TeacherInfoDetail = {
    baseInfo: {
        supervisedDisciplines: {disciplineCategory: string; primaryDiscipline: string; secondary: string}[];
        name: string;
        sex: string;
        pic: string;
        politicalAffiliation: string;
        title: string;
        highestEducation: string;
        highestDegree: string;
        telephone: string;
        postalCode: string;
        email: string;
        qq: string;
        wechat: string;
        address: string;
        supervisor: string;
        updatedAt: number;
    };
    academicProfile: {
        employeeNumber: string;
        biography: string;
        coursesTaught: string;
        researchProjects: string;
        researchDirections: string;
        achievements: {papers: string; books: string; patents: string};
        honorsAndAwards: string;
        admissionsInformation: string;
        academicAppointments: string;
    };
};

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
