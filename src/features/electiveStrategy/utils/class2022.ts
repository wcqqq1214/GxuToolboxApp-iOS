import {ElectiveStats, ElectiveStrategy} from "@/features/electiveStrategy/type/types.ts";
import {SelectedCourse} from "gxu-tool-adapters/jw";

const REQUIREMENTS = {
    totalScore: 10,
    offlineScore: 5,
    artScore: 2,
    specialModules: 2,
};
function calculate2022(courses: SelectedCourse[]): ElectiveStats {
    const requiredCourses = new Set(["创业基础", "中文写作实训", "逻辑与批判性思维训练"]);

    const cur = courses.reduce<Pick<ElectiveStats, "totalScore" | "offlineScore" | "modules">>(
        (acc, course) => {
            const score = Number(course.credit) || 0;
            acc.totalScore += score;
            if (!(course.belongTo?.includes("网络") || course.teacher === "网络教师")) {
                acc.offlineScore += score;
            }

            if (course.system?.includes("领军") || course.system?.includes("伦理")) {
                acc.modules.lead.has = true;
                acc.modules.lead.score += score;
            }
            if (course.system?.includes("创业")) {
                acc.modules.entrepreneurship.has = true;
                acc.modules.entrepreneurship.score += score;
            }
            if (course.system?.includes("艺术")) {
                acc.modules.art.has = true;
                acc.modules.art.score += score;
            }
            if (course.system?.includes("东盟")) {
                acc.modules.asean.has = true;
                acc.modules.asean.score += score;
            }
            if (course.system?.includes("民族")) {
                acc.modules.ethnic.has = true;
                acc.modules.ethnic.score += score;
            }
            if (course.system?.includes("海洋")) {
                acc.modules.ocean.has = true;
                acc.modules.ocean.score += score;
            }

            // 从必修列表中移除已修课程
            if (requiredCourses.has(course.courseName)) {
                requiredCourses.delete(course.courseName);
            }
            return acc;
        },
        {
            totalScore: 0,
            offlineScore: 0,
            modules: {
                lead: {has: false, score: 0},
                entrepreneurship: {has: false, score: 0},
                art: {has: false, score: 0},
                asean: {has: false, score: 0},
                ethnic: {has: false, score: 0},
                ocean: {has: false, score: 0},
                specialModulesCount: 0,
            },
        },
    );

    cur.modules.specialModulesCount =
        (cur.modules.asean.has ? 1 : 0) + (cur.modules.ethnic.has ? 1 : 0) + (cur.modules.ocean.has ? 1 : 0);

    const passed = {
        totalScore: cur.totalScore >= REQUIREMENTS.totalScore,
        offlineScore: cur.offlineScore >= REQUIREMENTS.offlineScore,
        artScore: cur.modules.art.score >= REQUIREMENTS.artScore,
        specialModules: cur.modules.specialModulesCount >= REQUIREMENTS.specialModules,
        leadModule: cur.modules.lead.has,
        entModule: cur.modules.entrepreneurship.has,
        requiredCourses: requiredCourses.size === 0,
    };

    const isQualified = Object.values(passed).every(p => p);

    return {
        ...cur,
        required: REQUIREMENTS,
        passed,
        remainingRequired: Array.from(requiredCourses),
        isQualified,
    };
}

export const class2022: ElectiveStrategy = {
    id: "grade-2022",
    name: "2022 级校选课毕业要求",
    calculate: calculate2022,
    ui: {
        requirements: [
            {
                key: "totalScore",
                label: `总学分 (要求: ${REQUIREMENTS.totalScore})`,
                format: stats => `${stats.totalScore} / ${REQUIREMENTS.totalScore}  `,
                passed: stats => stats.totalScore >= REQUIREMENTS.totalScore,
            },
            {
                key: "offlineScore",
                label: `线下学分 (要求: ${REQUIREMENTS.offlineScore})`,
                format: stats => `${stats.offlineScore} / ${REQUIREMENTS.offlineScore}  `,
                passed: stats => stats.offlineScore >= REQUIREMENTS.offlineScore,
            },
            {
                key: "artScore",
                label: `公共艺术学分 (要求: ${REQUIREMENTS.artScore})`,
                format: stats => `${stats.modules.art.score} / ${REQUIREMENTS.artScore}  `,
                passed: stats => stats.modules.art.score >= REQUIREMENTS.artScore,
            },
            {
                key: "hasLeadModule",
                label: "领军模块",
                format: stats => (stats.modules.lead.has ? "已完成  " : "未完成  "),
                passed: stats => stats.modules.lead.has,
            },
            {
                key: "hasEntModule",
                label: "创业模块",
                format: stats => (stats.modules.entrepreneurship.has ? "已完成  " : "未完成  "),
                passed: stats => stats.modules.entrepreneurship.has,
            },
            {
                key: "specialModulesCount",
                label: "东盟、海洋、民族（要求: 三选二)",
                format: stats => `${stats.modules.specialModulesCount} / 2  `,
                passed: stats => stats.modules.specialModulesCount! >= 2,
            },
        ],
        description: "关于通识选修课...",
        formalDescription: "形式化地...",
    },
};
