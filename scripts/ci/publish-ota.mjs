#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import {putObject} from "./cos.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const MAX_DESC_LENGTH = 4000;
const BLOCKED_PATH_PATTERNS = [
    /^android\//,
    /^ios\//,
    /^package\.json$/,
    /^pnpm-lock\.yaml$/,
    /^yarn\.lock$/,
    /^package-lock\.json$/,
    /^src\/pictures\//,
    /\.(png|jpe?g|gif|webp|ttf|otf)$/i,
];

const args = parseArgs(process.argv.slice(2));

main().catch(error => {
    console.error(`[OTA] 失败: ${error.message}`);
    process.exit(1);
});

function parseArgs(argv) {
    const result = {
        dryRun: false,
        skipBuild: false,
        skipDiffCheck: false,
    };

    for (let index = 0; index < argv.length; index += 1) {
        const arg = argv[index];
        if (arg === "--channel") {
            result.channel = argv[(index += 1)];
        } else if (arg === "--base") {
            result.base = argv[(index += 1)];
        } else if (arg === "--desc") {
            result.desc = argv[(index += 1)];
        } else if (arg === "--dry-run") {
            result.dryRun = true;
        } else if (arg === "--skip-build") {
            result.skipBuild = true;
        } else if (arg === "--skip-diff-check") {
            result.skipDiffCheck = true;
        } else if (arg === "--help" || arg === "-h") {
            printHelp();
            process.exit(0);
        } else {
            throw new Error(`未知参数: ${arg}`);
        }
    }

    return result;
}

function printHelp() {
    console.log(`用法: node scripts/ci/publish-ota.mjs [选项]

  --channel beta|release   目标通道，默认由 package.json 的 version 推断
  --base <sha>             diff 基线，默认 CI_MERGE_REQUEST_DIFF_BASE_SHA 或 CI_COMMIT_BEFORE_SHA
  --desc <text>            覆盖版本说明（默认取 MR 描述）
  --dry-run                只构建和校验，不上传
  --skip-build             跳过 bundle 构建（用于本地验证元数据）
  --skip-diff-check        跳过原生/依赖/图片变更检查（仅 bootstrap 或本地测试）
  -h, --help               查看帮助`);
}

async function main() {
    const pkg = readPackageJson();
    const appVersionCode = Number(pkg.versionCode);
    if (!Number.isSafeInteger(appVersionCode)) {
        throw new Error("package.json 的 versionCode 不是有效整数");
    }
    if (!pkg.versionJsonUrl) {
        throw new Error("package.json 缺少 versionJsonUrl");
    }

    const detectedChannel = String(pkg.version).includes("beta") ? "beta" : "release";
    const channel = args.channel ?? detectedChannel;
    if (!["beta", "release"].includes(channel)) {
        throw new Error(`不支持的通道: ${channel}`);
    }
    if (channel !== detectedChannel) {
        throw new Error(
            `package.json 版本 "${pkg.version}" 属于 ${detectedChannel} 通道，但本次目标是 ${channel}。请先修正版本标识。`,
        );
    }

    const manifest = await fetchJson(pkg.versionJsonUrl);
    const entry = (manifest[channel] ?? []).find(item => item.versionCode === appVersionCode);
    if (!entry) {
        throw new Error(
            `version.json 的 ${channel} 通道里没有 versionCode ${appVersionCode} 的 APK 条目，先发布整包。`,
        );
    }
    if (!entry.ori?.official) {
        throw new Error(`${channel} 通道 versionCode ${appVersionCode} 的条目没有 ori.official，先发布整包。`);
    }

    checkChangedFiles();

    const bundlePath = path.join(ROOT, "dist", String(appVersionCode), "index.android.bundle");
    buildBundle(bundlePath);

    const hasBundle = fs.existsSync(bundlePath);
    if (!args.dryRun && !hasBundle) {
        throw new Error(`bundle 不存在: ${bundlePath}`);
    }

    const sha256 = hasBundle ? crypto.createHash("sha256").update(fs.readFileSync(bundlePath)).digest("hex") : null;
    const otaList = Array.isArray(entry.ota) ? entry.ota : [];
    const duplicate = sha256 ? otaList.find(item => item.sha256 === sha256) : undefined;
    const description = sanitizeDescription(
        args.desc ??
            process.env.CI_MERGE_REQUEST_DESCRIPTION ??
            (await fetchMergeRequestDescription()) ??
            process.env.CI_COMMIT_MESSAGE ??
            "",
    );

    const plan = duplicate
        ? {
              versionName: duplicate.versionName,
              versionCode: duplicate.versionCode,
              bundleUrl: duplicate.bundleUrl,
          }
        : buildNewPlan(pkg, appVersionCode, otaList);

    const commit = process.env.CI_COMMIT_SHA ?? git(["rev-parse", "HEAD"]);
    const item = {
        ...plan,
        desc: description || `OTA ${plan.versionName}`,
        ...(sha256 ? {sha256} : {}),
        ...(commit ? {commit} : {}),
    };

    if (duplicate) {
        Object.assign(duplicate, item);
    } else {
        entry.ota = [...otaList, item].sort((left, right) => right.versionCode - left.versionCode);
    }

    const manifestPath = path.join(ROOT, "dist", "version.json");
    fs.mkdirSync(path.dirname(manifestPath), {recursive: true});
    fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 4)}\n`, "utf8");

    console.log("[OTA] 发布计划:");
    console.log(`  通道: ${channel}`);
    console.log(`  App: ${pkg.version} (${appVersionCode})`);
    console.log(`  OTA: ${item.versionName} (${item.versionCode})`);
    console.log(`  Bundle: ${item.bundleUrl}`);
    console.log(`  说明: ${item.desc.slice(0, 100)}${item.desc.length > 100 ? "..." : ""}`);
    console.log(`  version.json: ${path.relative(ROOT, manifestPath)}`);
    console.log(`  模式: ${args.dryRun ? "dry-run（不上传）" : "发布"}`);

    if (args.dryRun) return;

    const finalBundlePath = path.join(ROOT, "dist", String(appVersionCode), `${item.versionCode}.index.android.bundle`);
    if (finalBundlePath !== bundlePath) {
        fs.copyFileSync(bundlePath, finalBundlePath);
    }

    await putObject({
        key: `GxuToolApp/ota/${appVersionCode}/${item.versionCode}.index.android.bundle`,
        body: fs.readFileSync(finalBundlePath),
        contentType: "application/octet-stream",
        cacheControl: "public, max-age=31536000, immutable",
    });
    await putObject({
        key: "GxuToolApp/version.json",
        body: Buffer.from(`${JSON.stringify(manifest, null, 4)}\n`, "utf8"),
        contentType: "application/json; charset=utf-8",
        cacheControl: "no-cache, no-store, must-revalidate",
    });

    console.log("[OTA] 上传完成。记得刷新 CDN 的 version.json。");
}

function readPackageJson() {
    return JSON.parse(fs.readFileSync(path.join(ROOT, "package.json"), "utf8"));
}

async function fetchJson(url) {
    const separator = url.includes("?") ? "&" : "?";
    const response = await fetch(`${url}${separator}_=${Date.now()}`, {
        headers: {"Cache-Control": "no-cache"},
    });
    if (!response.ok) {
        throw new Error(`GET ${url} 失败: ${response.status} ${response.statusText}`);
    }
    return response.json();
}

function checkChangedFiles() {
    if (args.skipDiffCheck || process.env.OTA_SKIP_DIFF_CHECK === "1") {
        console.warn("[OTA] 已跳过原生/依赖/图片变更检查");
        return;
    }
    const base = args.base ?? process.env.CI_MERGE_REQUEST_DIFF_BASE_SHA ?? process.env.CI_COMMIT_BEFORE_SHA;
    if (!base || /^0+$/.test(base)) {
        console.warn("[OTA] 没有可用的 diff 基线，跳过原生/依赖/图片变更检查");
        return;
    }

    let changed;
    try {
        changed = git(["diff", "--name-only", base, "HEAD"]).split(/\r?\n/).filter(Boolean);
    } catch (error) {
        console.warn(`[OTA] 无法计算 diff（${base}），跳过检查: ${error.message}`);
        return;
    }

    const blocked = changed.filter(file => BLOCKED_PATH_PATTERNS.some(pattern => pattern.test(file)));
    if (blocked.length) {
        throw new Error(
            `OTA 只能包含 JS 变更，以下文件必须走整包发布:\n${blocked.map(file => `  - ${file}`).join("\n")}`,
        );
    }
}

function buildBundle(outputPath) {
    if (args.skipBuild) {
        console.warn("[OTA] 已跳过 bundle 构建");
        return;
    }

    const cli = path.join(ROOT, "node_modules", "react-native", "cli.js");
    if (!fs.existsSync(cli)) {
        throw new Error("找不到 node_modules/react-native/cli.js，先执行 pnpm install");
    }

    fs.mkdirSync(path.dirname(outputPath), {recursive: true});
    console.log(`[OTA] 构建 bundle -> ${path.relative(ROOT, outputPath)}`);
    execFileSync(
        process.execPath,
        [
            cli,
            "bundle",
            "--platform",
            "android",
            "--dev",
            "false",
            "--entry-file",
            "index.js",
            "--bundle-output",
            outputPath,
        ],
        {cwd: ROOT, stdio: "inherit"},
    );
}

function buildNewPlan(pkg, appVersionCode, otaList) {
    const dateSeq = todaySeq();
    const usedSequences = otaList
        .map(item => {
            const match = /-(\d{4})(\d{2})$/.exec(item.versionName ?? "");
            return match && match[1] === dateSeq ? Number(match[2]) : null;
        })
        .filter(value => value !== null);
    const sequence = String((usedSequences.length ? Math.max(...usedSequences) : 0) + 1).padStart(2, "0");
    const versionName = `${String(pkg.version).replace(/\s+/g, "")}-${dateSeq}${sequence}`;
    const versionCode = Number(`${appVersionCode}${dateSeq}${sequence}`);
    if (!Number.isSafeInteger(versionCode)) {
        throw new Error(`生成的 OTA versionCode 超出安全整数范围: ${versionCode}`);
    }
    const maxVersionCode = otaList.reduce((max, item) => Math.max(max, item.versionCode ?? 0), 0);
    if (versionCode <= maxVersionCode) {
        throw new Error(`生成的 OTA versionCode ${versionCode} 不大于现有最大值 ${maxVersionCode}`);
    }

    return {
        versionName,
        versionCode,
        bundleUrl: new URL(
            `/GxuToolApp/ota/${appVersionCode}/${versionCode}.index.android.bundle`,
            pkg.versionJsonUrl,
        ).toString(),
    };
}

function todaySeq() {
    const parts = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Shanghai",
        month: "2-digit",
        day: "2-digit",
    }).formatToParts(new Date());
    const month = parts.find(part => part.type === "month").value;
    const day = parts.find(part => part.type === "day").value;
    return `${month}${day}`;
}

async function fetchMergeRequestDescription() {
    const {CI_API_V4_URL, CI_PROJECT_ID, CI_COMMIT_SHA, CI_COMMIT_BRANCH, GITLAB_API_TOKEN} = process.env;
    if (!CI_API_V4_URL || !CI_PROJECT_ID || !CI_COMMIT_SHA || !GITLAB_API_TOKEN) {
        return null;
    }

    const url = `${CI_API_V4_URL}/projects/${encodeURIComponent(
        CI_PROJECT_ID,
    )}/repository/commits/${CI_COMMIT_SHA}/merge_requests`;
    const response = await fetch(url, {
        headers: {"PRIVATE-TOKEN": GITLAB_API_TOKEN},
    });
    if (!response.ok) {
        console.warn(`[OTA] 获取 MR 描述失败: ${response.status} ${response.statusText}`);
        return null;
    }

    const mergeRequests = await response.json();
    const candidates = mergeRequests.filter(
        mergeRequest =>
            mergeRequest.state === "merged" && (!CI_COMMIT_BRANCH || mergeRequest.target_branch === CI_COMMIT_BRANCH),
    );
    candidates.sort(
        (left, right) => new Date(right.merged_at ?? 0).getTime() - new Date(left.merged_at ?? 0).getTime(),
    );
    const mergeRequest = candidates[0] ?? (CI_COMMIT_BRANCH ? null : mergeRequests[0]);
    return mergeRequest?.description || mergeRequest?.title || null;
}

function sanitizeDescription(value) {
    let text = String(value ?? "");
    const marker = text.match(/<!--\s*release-notes:start\s*-->([\s\S]*?)<!--\s*release-notes:end\s*-->/i);

    if (marker) {
        text = marker[1];
    } else {
        text = text.replace(/<!--[\s\S]*?-->/g, "");
        const section = text.match(/^##\s*(?:更新内容|Release Notes?)\s*$/im);
        if (section) {
            const start = section.index + section[0].length;
            const rest = text.slice(start);
            const next = rest.search(/^##\s+/m);
            text = next >= 0 ? rest.slice(0, next) : rest;
        }
    }

    text = text
        .replace(/!\[[^\]]*\]\([^)]*\)/g, "")
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
        .replace(/^#{1,6}\s*/gm, "")
        .replace(/^\s*[-*]\s*\[[ xX]\]\s*/gm, "- ")
        .replace(/\*\*([^*]+)\*\*/g, "$1")
        .replace(/__([^_]+)__/g, "$1")
        .replace(/`([^`]+)`/g, "$1")
        .replace(/^```.*$/gm, "")
        .replace(/[ \t]+$/gm, "")
        .replace(/\n{3,}/g, "\n\n")
        .trim();

    return text.slice(0, MAX_DESC_LENGTH);
}

function git(gitArgs) {
    return execFileSync("git", ["-c", `safe.directory=${ROOT}`, ...gitArgs], {
        cwd: ROOT,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
    }).trim();
}
