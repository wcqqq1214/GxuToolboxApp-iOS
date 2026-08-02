import cheerio from "react-native-cheerio";

// 定义数据结构：好品味始于类型定义
interface UsualScoreItem {
    name: string;    // 分项名称
    ratio: string;   // 比例 (存字符串，因为可能有空值)
    score: string;   // 成绩
}

export function usualScoreParser(html: string): UsualScoreItem[] {
    // 1. 加载 HTML。null 选项是为了关闭一些非必要的闭合标签检查，提高速度
    const $ = cheerio.load(html, {
        decodeEntities: true, // 自动把 &nbsp; 转成空格
        xmlMode: false,
    });

    const results: UsualScoreItem[] = [];

    // 2. 定位选择器：ID 为 subtab 的表格 -> tbody -> 所有的 tr
    $("#subtab tbody tr").each((_, element) => {
        const tds = $(element).find("td");
        console.log("tds");
        // 3. 防御性编程：如果一行不是3列，那就是垃圾数据，跳过
        if (tds.length < 3) return;

        // 4. 提取并清洗数据
        // data-1: 名称。去掉 【 】 和多余空格
        const rawName = $(tds[0]).text();
        const name = rawName.replace(/[【】\s]/g, "");

        // data-2: 比例。去掉 % 和多余空格。如果是空(总评)，保留为空串或标记
        const rawRatio = $(tds[1]).text().trim();
        const ratio = rawRatio.replace("%", "");

        // data-3: 成绩。去掉多余空格
        const score = $(tds[2]).text().trim();

        // 5. 只有当名称和成绩都存在时，才算有效数据
        if (name && score) {
            results.push({
                name,
                ratio: ratio || "N/A", // 如果没有比例（如总评），标记为 N/A
                score,
            });
        }
    });

    return results;
}
