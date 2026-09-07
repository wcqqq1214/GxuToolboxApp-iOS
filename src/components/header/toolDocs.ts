// 工具箱各页面标题 → 对应文档网址
// 文档站点源码见 Desktop/AppDoc（VuePress，构建后部署到 tooldoc.gxutech.xyz）
const DOC_BASE = "https://tooldoc.gxutech.xyz";

export const toolDocs: Record<string, string> = {
    "课表查询": `${DOC_BASE}/tools/self-class.html`, // 个人课表
    "班级课表查询": `${DOC_BASE}/tools/class-table.html`, // 班级课表
    "考勤信息查询": `${DOC_BASE}/tools/attendance.html`, // 考勤信息
    "考试信息查询": `${DOC_BASE}/tools/exam%20room.html`, // 考场查询
    "考试成绩查询": `${DOC_BASE}/tools/grade%20query.html`, // 成绩查询
    "选课课程列表查询": `${DOC_BASE}/tools/list.html`, // 选课课程列表
    "校选课查漏": `${DOC_BASE}/tools/check%20missing.html`, // 校选课查漏
    "教师信息查询": `${DOC_BASE}/tools/teachinfo.html`, // 教师信息
    "物理实验课查询": `${DOC_BASE}/tools/practice.html`, // 实践课
    "金工实训查询": `${DOC_BASE}/tools/practice.html`, // 实践课
    "调课信息查询": `${DOC_BASE}/tools/class%20adj.html`, // 调课信息
    "调休信息查询": `${DOC_BASE}/tools/leave%20adj.html`, // 调休信息
    "假期安排": `${DOC_BASE}/tools/statutory%20holday.html`, // 法定节假日
    "学校文件": `${DOC_BASE}/tools/Sch%20files.html`, // 学校文件
    "期末学生评价": `${DOC_BASE}/tools/evaluation.html`, // 教学评价
    "学生评价细节": `${DOC_BASE}/tools/evaluation.html`, // 教学评价
    "填写评语": `${DOC_BASE}/tools/evaluation.html`, // 教学评价
    "评价模板": `${DOC_BASE}/tools/evaluation.html`, // 教学评价
    "全校实时课表": `${DOC_BASE}/tools/real-time%20sche.html`, // 全校实时课表
    "地图导航": `${DOC_BASE}/tools/navagation.html`, // 导航
    "教学楼平面图": `${DOC_BASE}/tools/floor%20plan.html`, // 平面图
    "楼层列表": `${DOC_BASE}/tools/floor%20plan.html`, // 平面图
    "楼层平面图": `${DOC_BASE}/tools/floor%20plan.html`, // 平面图
    "导出课表": `${DOC_BASE}/tools/export%20table.html`, // 导出课表

    // 设置 - 账号
    "查看个人信息": `${DOC_BASE}/setting/account.html`,
    "登录教务系统": `${DOC_BASE}/setting/account.html`,
    "统一认证系统账号设置": `${DOC_BASE}/setting/account.html`,
    "考勤系统账号设置": `${DOC_BASE}/setting/account.html`,
    // 设置 - 显示偏好
    "偏好设置": `${DOC_BASE}/setting/theme.html`,
    "课程元素详情显示": `${DOC_BASE}/setting/theme.html`,
    "考试元素详情显示": `${DOC_BASE}/setting/theme.html`,
    // 设置 - 软件
    "意见反馈": `${DOC_BASE}/setting/app.html`,
    // 设置首页分组标题
    "账号": `${DOC_BASE}/setting/account.html`,
    "主题": `${DOC_BASE}/setting/theme.html`,
    "软件": `${DOC_BASE}/setting/app.html`,
};

// 没有对应文档的页面，回退到文档首页
export const DEFAULT_DOC = `${DOC_BASE}/`;
