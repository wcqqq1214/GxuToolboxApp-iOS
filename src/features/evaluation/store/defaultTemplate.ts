import {createTemplate, getTemplateByName} from "@/features/evaluation/store/template.ts";

export async function migrateTemplates() {
    const data = {
        selected: {
            "0": {
                "0": {"0": 0, "1": 0, "2": 0, "3": 0},
                "1": {"0": 0, "1": 0, "2": 0},
                "2": {"0": 0, "1": 0, "2": 1},
                "3": {"0": 0, "1": 0, "2": 0},
                "4": {"0": 0, "1": 0, "2": 0},
            },
        },
        comment: "",
    };
    if (!getTemplateByName("默认模板")) {
        createTemplate("默认模板", data);
    }
}
