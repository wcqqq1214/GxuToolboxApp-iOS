// 描述毕业要求的“策略”
import {SelectedCourse} from "gxu-tool-adapters/jw";

export interface ElectiveStrategy {
    id: string; // 唯一标识，如 'grade-2024'
    name: string; // 显示在界面的标题，如 '非 2025 级毕业要求'

    // 一个函数，接收学生已修课程，返回计算后的统计数据
    calculate: (courses: SelectedCourse[]) => ElectiveStats;

    // UI 展示需要的元数据
    ui: {
        // 用于界面上逐项展示的规则
        requirements: Array<{
            key: string;
            label: string;
            // 一个函数，用于格式化显示的值
            format: (stats: ElectiveStats) => string;
            passed: (stats: ElectiveStats) => boolean;
        }>;

        // 弹出框里的详细说明
        description: string;
        formalDescription: string;
    };
}

export interface ModuleStats {
    score: number; // 修了多少分
    has: boolean; // 是否修过 (至少一门)
}

export interface ElectiveStats {
    totalScore: number;
    offlineScore: number;

    // 新增：用一个对象统一管理所有模块的数据
    modules: {
        lead: ModuleStats;
        entrepreneurship: ModuleStats;
        art: ModuleStats;
        asean: ModuleStats;
        ocean: ModuleStats;
        ethnic: ModuleStats;
        specialModulesCount?: number;
    };

    // 毕业要求的值
    required: {
        totalScore: number;
        offlineScore: number;
        artScore?: number;
    };

    // 各单项是否达标
    passed: {
        totalScore: boolean;
        offlineScore: boolean;
        art?: boolean;
        lead?: boolean;
        entrepreneurship?: boolean;
        specialModules?: boolean;
        requiredCourses?: boolean;
    };

    remainingRequired: string[];
    isQualified: boolean;
}
