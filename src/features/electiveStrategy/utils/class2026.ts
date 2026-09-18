import {ElectiveStats, ElectiveStrategy} from "@/features/electiveStrategy/type/types.ts";
import {SelectedCourse} from "gxu-tool-adapters/jw";

const REQUIREMENTS = {
    totalScore: 8,
    offlineScore: 4,
    artScore: 2,
    specialModules: 2,
    entrepreneurship: 2,
    tech: 1,
    ethnic: 1,
    ocean: 1,
    asean: 1,
};

function calculate2026(courses: SelectedCourse[]): ElectiveStats {
    const requiredCourses = new Set(["创新创业基础"]);

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
        tech: cur.modules.lead.score >= REQUIREMENTS.tech,
        ethnic: cur.modules.ethnic.score >= REQUIREMENTS.ethnic,
        ocean: cur.modules.ocean.score >= REQUIREMENTS.ocean,
        asean: cur.modules.asean.score >= REQUIREMENTS.asean,
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

export const class2026: ElectiveStrategy = {
    id: "grade-2026",
    name: "2026 级校选课毕业要求",
    calculate: calculate2026,
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
                key: "hasEntModule",
                label: `创业学分 (要求: ${REQUIREMENTS.entrepreneurship})`,
                format: stats => `${stats.modules.entrepreneurship.score} / ${REQUIREMENTS.entrepreneurship}  `,
                passed: stats => stats.modules.entrepreneurship.score >= REQUIREMENTS.entrepreneurship,
            },
            {
                key: "artScore",
                label: `艺术与审美 (要求: ${REQUIREMENTS.artScore})`,
                format: stats => `${stats.modules.art.score} / ${REQUIREMENTS.artScore}  `,
                passed: stats => stats.modules.art.score >= REQUIREMENTS.artScore,
            },
            {
                key: "tech",
                label: `科技与伦理 (要求: ${REQUIREMENTS.tech})`,
                format: stats => `${stats.modules.lead.score} / ${REQUIREMENTS.tech}  `,
                passed: stats => stats.modules.lead.score >= REQUIREMENTS.tech,
            },
            {
                key: "ethnic",
                label: `少数民族与中华文明 (要求: ${REQUIREMENTS.ethnic})`,
                format: stats => `${stats.modules.ethnic.score} / ${REQUIREMENTS.ethnic}  `,
                passed: stats => stats.modules.ethnic.score >= REQUIREMENTS.ethnic,
            },
            {
                key: "ocean",
                label: `亚热带与海洋生态 (要求: ${REQUIREMENTS.ocean})`,
                format: stats => `${stats.modules.ocean.score} / ${REQUIREMENTS.ocean}  `,
                passed: stats => stats.modules.ocean.score >= REQUIREMENTS.ocean,
            },
            {
                key: "asean",
                label: `东盟历史与世界文化 (要求: ${REQUIREMENTS.asean})`,
                format: stats => `${stats.modules.asean.score} / ${REQUIREMENTS.asean}  `,
                passed: stats => stats.modules.asean.score >= REQUIREMENTS.asean,
            },
        ],
        description: "关于通识选修课...",
        formalDescription: "形式化地...",
    },
};
