import fs from "node:fs";
import path from "node:path";
import {createRequire} from "node:module";
import {isDeepStrictEqual} from "node:util";

// CI 已安装 ESLint，复用它声明的 YAML 解析器读取 pnpm 锁文件。
const require = createRequire(import.meta.url);
const {load} = createRequire(require.resolve("eslint/package.json"))("js-yaml");
const JS_ADAPTERS = ["@gxutool/adapters", "gxu-tool-adapters"];
const BLOCKED_PATHS = [
    /^android\//,
    /^ios\//,
    /^yarn\.lock$/,
    /^package-lock\.json$/,
    /^src\/pictures\//,
    /\.(png|jpe?g|gif|webp|ttf|otf)$/i,
];

/** 比较 APK 基线与当前工作区，仅放行同版本通道标识和已审阅的 JS adapters 变更。 */
export function checkOtaChanges({root, base, git}) {
    git(["rev-parse", "--verify", `${base}^{commit}`]);
    const changed = new Set(
        [
            ...git(["diff", "--name-only", base, "--"]).split(/\r?\n/),
            ...git(["ls-files", "--others", "--exclude-standard"]).split(/\r?\n/),
        ].filter(Boolean),
    );
    const readBefore = file => git(["show", `${base}:${file}`]);
    const readCurrent = file => fs.readFileSync(path.join(root, file), "utf8");

    if (changed.has("package.json")) {
        const before = normalizePackage(JSON.parse(readBefore("package.json")));
        const current = normalizePackage(JSON.parse(readCurrent("package.json")));
        if (!isDeepStrictEqual(before, current)) {
            throw new Error(
                "package.json 包含 APK 版本号、原生依赖或其他配置变化，请发布整包。OTA 仅允许同版本 beta 标识调整及已审阅的 JS adapters 更新。",
            );
        }
    }
    if (changed.has("pnpm-lock.yaml")) {
        if (
            !isDeepStrictEqual(
                normalizeLockfile(load(readBefore("pnpm-lock.yaml"))),
                normalizeLockfile(load(readCurrent("pnpm-lock.yaml"))),
            )
        ) {
            throw new Error("pnpm-lock.yaml 包含 JS adapters 之外的依赖解析变化，请发布整包。");
        }
    }
    if (changed.has("package.json") || changed.has("pnpm-lock.yaml")) {
        assertReviewedAdapters(root);
    }

    const gradle = "android/app/build.gradle";
    if (changed.has(gradle)) {
        if (normalizeGradle(readBefore(gradle)) !== normalizeGradle(readCurrent(gradle))) {
            throw new Error("android/app/build.gradle 包含原生构建变化，请发布整包。OTA 仅允许同版本 beta 标识调整。");
        }
        changed.delete(gradle);
    }
    const blocked = [...changed].filter(file => BLOCKED_PATHS.some(pattern => pattern.test(file)));
    if (blocked.length) {
        throw new Error(`以下原生或资源文件必须走整包发布:\n${blocked.map(file => `  - ${file}`).join("\n")}`);
    }
}

/** 只去除 beta 后缀，实际 App 版本和版本号仍参与比较。 */
function normalizePackage(pkg) {
    pkg.version = pkg.version.replace(/\s+beta$/, "");
    for (const section of ["dependencies", "devDependencies"]) {
        for (const name of JS_ADAPTERS) delete pkg[section]?.[name];
    }
    return pkg;
}

/** 适配器包以外的解析结果完整参与比较，弃用提示不影响安装内容。 */
function normalizeLockfile(lock) {
    if (String(lock.lockfileVersion) !== "9.0" || !lock.importers?.["."]) {
        throw new Error("OTA 检查仅支持当前 pnpm v9 锁文件结构，请先审阅锁文件格式变化。");
    }
    for (const section of ["dependencies", "devDependencies"]) {
        for (const name of JS_ADAPTERS) delete lock.importers["."][section]?.[name];
    }
    for (const section of ["packages", "snapshots"]) {
        for (const [key, value] of Object.entries(lock[section] ?? {})) {
            if (JS_ADAPTERS.some(name => key.startsWith(`${name}@`))) delete lock[section][key];
            else if (section === "packages") delete value.deprecated;
        }
    }
    return lock;
}

/** 本次仅审阅了 adapters 1.1.1，后续版本须重新确认原生入口和传递依赖。 */
function assertReviewedAdapters(root) {
    for (const name of JS_ADAPTERS) {
        const pkg = JSON.parse(fs.readFileSync(path.join(root, "node_modules", name, "package.json"), "utf8"));
        const dependencies = Object.keys(pkg.dependencies ?? {});
        const scripts = pkg.scripts ?? {};
        if (
            pkg.name !== "@gxutool/adapters" ||
            pkg.version !== "1.1.1" ||
            pkg["react-native"] ||
            pkg.codegenConfig ||
            pkg.gypfile ||
            Object.keys(pkg.optionalDependencies ?? {}).length ||
            Object.keys(pkg.peerDependencies ?? {}).length ||
            scripts.preinstall ||
            scripts.install ||
            scripts.postinstall ||
            dependencies.some(dependency => !["cheerio", "zod"].includes(dependency))
        ) {
            throw new Error(`${name} 超出已审阅的纯 JS adapters 1.1.1 范围，请重新审阅依赖或发布整包。`);
        }
    }
}

/** 原生构建脚本仅忽略版本名的 beta 后缀，其余内容必须与 APK 基线一致。 */
function normalizeGradle(text) {
    return text
        .replace(/\r\n/g, "\n")
        .replace(
            /^(\s*versionName\s+["'])([^"'\r\n]+)(["']\s*)$/gm,
            (_line, prefix, version, suffix) => prefix + version.replace(/\s+beta$/, "") + suffix,
        )
        .trim();
}
