import {class2023} from "@/features/electiveStrategy/utils/class2023.ts";
import {class2024} from "@/features/electiveStrategy/utils/class2024.ts";
import {class2025} from "@/features/electiveStrategy/utils/class2025.ts";
import {class2022} from "@/features/electiveStrategy/utils/class2022.ts";
import {class2021} from "@/features/electiveStrategy/utils/class2021.ts";
import {class2026} from "@/features/electiveStrategy/utils/class2026.ts";

export const getStrategy = (grade: number) => {
    if (grade === 2021) {
        return class2021;
    }
    if (grade === 2022) {
        return class2022;
    }
    if (grade === 2023) {
        return class2023;
    }
    if (grade === 2024) {
        return class2024;
    }
    if (grade === 2025) {
        return class2025;
    }
    if (grade === 2026) {
        return class2026;
    }
    return class2025;
};
