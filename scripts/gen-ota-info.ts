import * as fs from "node:fs";
import * as path from "node:path";

interface OtaItem {
    versionName: string;
    versionCode: number;
    desc: string;
    bundleUrl: string;
}

interface VersionEntry {
    versionName: string;
    versionCode: number;
    desc: string;
    dependency: string;
    ori: Record<string, string>;
    ota?: OtaItem[];
}

interface VersionJson {
    beta: VersionEntry[];
    release: VersionEntry[];
}

const PKG_PATH = path.resolve(__dirname, "..", "package.json");
const DIST_DIR = path.resolve(__dirname, "..", "dist");
const VERSION_JSON_URL = "https://file.unde.site/GxuToolApp/version.json";

function getDateSeq(): string {
    const now = new Date();
    const mm = String(now.getMonth() + 1).padStart(2, "0");
    const dd = String(now.getDate()).padStart(2, "0");
    return `${mm}${dd}`;
}

async function getSeq(dateSeq: string, pkgVersionCode: number): Promise<number> {
    try {
        const res = await fetch(VERSION_JSON_URL);
        if (!res.ok) return 1;
        const json: VersionJson = await res.json();

        // 在 beta 和 release 中查找匹配的版本
        for (const channel of ["beta", "release"] as const) {
            const entry = json[channel]?.find(v => v.versionCode === pkgVersionCode);
            if (!entry?.ota?.length) continue;

            // 查找今天已有的最高序号
            const todayOta = entry.ota.filter(o => {
                const m = o.versionName.match(/-(\d{4})(\d{2})$/);
                return m && m[1] === dateSeq;
            });
            if (todayOta.length > 0) {
                const maxSeq = Math.max(
                    ...todayOta.map(o => {
                        const m = o.versionName.match(/-(\d{4})(\d{2})$/);
                        return m ? parseInt(m[2], 10) : 0;
                    }),
                );
                return maxSeq + 1;
            }
            // 今天还没有 OTA，从 1 开始
            return 1;
        }
    } catch (e) {
        console.warn("[OTA] 获取远端 version.json 失败，默认序号为 1:", e);
    }
    return 1;
}

function getChannel(versionName: string): "beta" | "release" {
    return versionName.indexOf("beta") > -1 ? "beta" : "release";
}

async function main(): Promise<void> {
    const raw = fs.readFileSync(PKG_PATH, "utf-8");
    const pkg = JSON.parse(raw);
    const baseVersion = pkg.version.replace(/\s+/g, "");
    const dateSeq = getDateSeq();
    const seqNum = parseInt(process.argv[2], 10) || (await getSeq(dateSeq, pkg.versionCode));
    const seq = String(seqNum).padStart(2, "0");

    const versionName = `${baseVersion}-${dateSeq}${seq}`;
    const versionCode = parseInt(`${pkg.versionCode}${dateSeq}${seq}`, 10);
    const bundleFile = `${pkg.versionCode}${dateSeq}${seq}.index.android.bundle`;

    // 创建 dist/{pkg.versionCode}/ 目录
    const bundleDir = path.join(DIST_DIR, String(pkg.versionCode));
    fs.mkdirSync(bundleDir, {recursive: true});

    // 移动 bundle 文件
    const srcBundle = path.join(DIST_DIR, "index.android.bundle");
    const dstBundle = path.join(bundleDir, bundleFile);
    if (fs.existsSync(srcBundle)) {
        fs.renameSync(srcBundle, dstBundle);
        console.log(`[OTA] bundle 已移动: ${dstBundle}`);
    } else {
        console.warn(`[OTA] 警告: ${srcBundle} 不存在，跳过移动`);
    }

    const otaItem: OtaItem = {
        versionName,
        versionCode,
        desc: "",
        bundleUrl: `https://file.unde.site/GxuToolApp/ota/${pkg.versionCode}/${bundleFile}`,
    };

    // 从远端获取 version.json 并追加新 OTA 条目
    let versionJson: VersionJson;
    try {
        const res = await fetch(VERSION_JSON_URL);
        versionJson = res.ok ? await res.json() : {beta: [], release: []};
    } catch {
        versionJson = {beta: [], release: []};
    }

    const channel = getChannel(baseVersion);
    const entry = versionJson[channel]?.find(v => v.versionCode === pkg.versionCode);
    if (entry) {
        entry.ota = [...(entry.ota ?? []), otaItem];
    } else {
        versionJson[channel] = [
            ...(versionJson[channel] ?? []),
            {
                versionName: baseVersion,
                versionCode: pkg.versionCode,
                desc: "",
                dependency: "",
                ori: {},
                ota: [otaItem],
            },
        ];
    }

    // 写出更新后的 version.json 到 dist/
    const versionJsonPath = path.join(DIST_DIR, "version.json");
    fs.writeFileSync(versionJsonPath, JSON.stringify(versionJson, null, 2), "utf-8");

    // 写出 ota-info.json（本地引用）
    const infoPath = path.join(DIST_DIR, "ota-info.json");
    fs.writeFileSync(infoPath, JSON.stringify(otaItem, null, 2), "utf-8");

    // 保留历史记录
    const historyPath = path.join(DIST_DIR, `ota-info-${dateSeq}${seq}.json`);
    fs.writeFileSync(historyPath, JSON.stringify(otaItem, null, 2), "utf-8");

    console.log("[OTA] 版本信息已生成:");
    console.log(`  versionName: ${versionName}`);
    console.log(`  versionCode: ${versionCode}`);
    console.log(`  bundle: dist/${pkg.versionCode}/${bundleFile}`);
    console.log(`  bundleUrl: ${otaItem.bundleUrl}`);
    console.log(
        `  version.json 已更新，共 ${versionJson[channel]!.find(v => v.versionCode === pkg.versionCode)!.ota!.length} 个 OTA`,
    );
}

main();
