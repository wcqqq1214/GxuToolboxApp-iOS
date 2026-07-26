import * as fs from "node:fs";
import * as path from "node:path";

interface OtaInfo {
    versionName: string;
    versionCode: number;
    desc: string;
    bundleUrl: string;
}

const PKG_PATH = path.resolve(__dirname, "..", "package.json");
const DIST_DIR = path.resolve(__dirname, "..", "dist");

function getDateSeq(): string {
    const now = new Date();
    const mm = String(now.getMonth() + 1).padStart(2, "0");
    const dd = String(now.getDate()).padStart(2, "0");
    return `${mm}${dd}`;
}

function getSeq(dateSeq: string): number {
    const infoPath = path.join(DIST_DIR, "ota-info.json");
    if (fs.existsSync(infoPath)) {
        try {
            const existing: OtaInfo = JSON.parse(fs.readFileSync(infoPath, "utf-8"));
            const m = existing.versionName.match(/-(\d{4})(\d{2})$/);
            if (m && m[1] === dateSeq) return parseInt(m[2], 10) + 1;
        } catch {}
    }
    return 1;
}

function main(): void {
    const raw = fs.readFileSync(PKG_PATH, "utf-8");
    const pkg = JSON.parse(raw);
    const baseVersion = pkg.version.replace(/\s+/g, "");
    const dateSeq = getDateSeq();
    const seqNum = parseInt(process.argv[2], 10) || getSeq(dateSeq);
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

    // 生成 ota 版本信息
    const otaInfo: OtaInfo = {
        versionName,
        versionCode,
        desc: "",
        bundleUrl: `https://file.unde.site/GxuToolApp/ota/${pkg.versionCode}/${bundleFile}`,
    };

    // 保留历史记录
    const historyPath = path.join(DIST_DIR, `ota-info-${dateSeq}${seq}.json`);
    fs.writeFileSync(historyPath, JSON.stringify(otaInfo, null, 2), "utf-8");

    // 覆盖最新引用
    const latestPath = path.join(DIST_DIR, "ota-info.json");
    fs.writeFileSync(latestPath, JSON.stringify(otaInfo, null, 2), "utf-8");

    console.log(`[OTA] 版本信息已生成:`);
    console.log(`  versionName: ${versionName}`);
    console.log(`  versionCode: ${versionCode}`);
    console.log(`  bundle: dist/${pkg.versionCode}/${bundleFile}`);
    console.log(`  bundleUrl: ${otaInfo.bundleUrl}`);
}

main();
