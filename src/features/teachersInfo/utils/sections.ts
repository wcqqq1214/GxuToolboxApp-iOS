import type {TeacherInfoDetail} from "@/features/teachersInfo/type/info";

export type DetailSection = {
    key: string;
    title: string;
    text: string;
};

/**
 * 将教师详情转换为「标题 + 文本」的平面列表，供详情页和教师信息弹窗复用。
 * @param info 教师详情数据
 * @returns 按展示顺序排列的分组，空值已统一为“暂无信息”
 */
export function buildSections(info: TeacherInfoDetail): DetailSection[] {
    const subjects = (info.baseInfo.supervisedDisciplines ?? [])
        .map(
            item =>
                `门类：${item.disciplineCategory || "无"}，一级学科：${item.primaryDiscipline || "无"}，二级学科：${item.secondary || "无"}`,
        )
        .join("\n");
    [
        info.academicProfile.achievements.papers,
        info.academicProfile.achievements.books,
        info.academicProfile.achievements.patents,
    ]
        .filter(Boolean)
        .join("\n");
    const education = [
        `最后学位：${info.baseInfo.highestDegree || "暂无信息"}`,
        `学历信息：${info.baseInfo.highestEducation || "暂无信息"}`,
        `导师类别：${info.baseInfo.supervisor || "暂无信息"}`,
    ]
        .filter(Boolean)
        .join("\n");
    const contact = [
        `邮政编码：${info.baseInfo.postalCode || "暂无信息"}`,
        `Email：${info.baseInfo.email || "暂无信息"}`,
        `联系电话：${info.baseInfo.telephone || "暂无信息"}`,
        `QQ：${info.baseInfo.qq || "暂无信息"}`,
        `微信：${info.baseInfo.wechat || "暂无信息"}`,
    ]
        .filter(Boolean)
        .join("\n");

    return [
        {
            key: "education",
            title: "学历与导师类型",
            text: education || "暂无信息",
        },
        {
            key: "subjects",
            title: "指导学科",
            text: subjects || "暂无信息",
        },
        {
            key: "contact",
            title: "联系方式",
            text: contact || "暂无信息",
        },
        {key: "introduction", title: "个人简介", text: info.academicProfile.biography || "暂无信息"},
        {key: "courses", title: "主讲课程", text: info.academicProfile.coursesTaught || "暂无信息"},
        {
            key: "projects",
            title: "主持（参与）的主要科研项目",
            text: info.academicProfile.researchProjects || "暂无信息",
        },
        {key: "research", title: "主要研究方向", text: info.academicProfile.researchDirections || "暂无信息"},
        {key: "achievements", title: "取得的主要成果", text: ""},
        {key: "papers", title: "论文", text: info.academicProfile.achievements.papers},
        {key: "patents", title: "著作", text: info.academicProfile.achievements.books},
        {key: "books", title: "专利", text: info.academicProfile.achievements.patents},
        {key: "honors", title: "荣誉与获奖", text: info.academicProfile.honorsAndAwards || "暂无信息"},
        {key: "admissions", title: "招生信息", text: info.academicProfile.admissionsInformation || "暂无信息"},
        {key: "partTime", title: "学术兼职", text: info.academicProfile.academicAppointments || "暂无信息"},
    ];
}
