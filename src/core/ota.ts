import axios from "axios";
import ReactNativeBlobUtil from "react-native-blob-util";
import PackageJSON from "@/../package.json";
import {mmkv} from "@/store/mmkv";
import type {OtaItem, VersionRes} from "@/components/UpdateCard";

const OTA_VERSION_KEY = "ota_version_code";
const OTA_APP_VERSION_KEY = "ota_app_version_code";
const OTA_DIR = "ota";

function getChannel(): "beta" | "release" {
    return PackageJSON.version.indexOf("beta") > -1 ? "beta" : "release";
}

export function getCurrentOTAVersionCode(): number {
    return mmkv.getNumber(OTA_VERSION_KEY) ?? 0;
}

/** 清除跨版本后的过期 OTA 文件，防止旧 bundle 覆盖新包内置代码 */
export async function cleanStaleOTA(): Promise<void> {
    const savedAppVersion = mmkv.getNumber(OTA_APP_VERSION_KEY);
    if (savedAppVersion && savedAppVersion !== PackageJSON.versionCode) {
        console.log(`[OTA] 检测到版本变更: ${savedAppVersion} → ${PackageJSON.versionCode}，清理所有 OTA`);
        await clearAllOTA();
        return;
    }
    // 旧版本未记录 appVersion，但若存在 OTA 标记文件则一并清理
    if (!savedAppVersion && getCurrentOTAVersionCode() > 0) {
        console.log("[OTA] 检测到旧格式 OTA 数据，清理");
        await clearAllOTA();
    }
}

async function clearAllOTA(): Promise<void> {
    try {
        const otaRoot = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/${OTA_DIR}`;
        const exists = await ReactNativeBlobUtil.fs.exists(otaRoot);
        if (exists) {
            await ReactNativeBlobUtil.fs.unlink(otaRoot);
        }
        const versionTagPath = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/ota_version`;
        const tagExists = await ReactNativeBlobUtil.fs.exists(versionTagPath);
        if (tagExists) {
            await ReactNativeBlobUtil.fs.unlink(versionTagPath);
        }
        mmkv.remove(OTA_VERSION_KEY);
        mmkv.remove(OTA_APP_VERSION_KEY);
    } catch {}
}

export async function checkOTA(): Promise<void> {
    try {
        const channel = getChannel();
        const {data} = await axios.get<VersionRes>(
            `${PackageJSON.versionJsonUrl}?_=${Date.now()}`,
            {timeout: 15000},
        );

        const versions = data[channel];
        if (!versions) return;

        const matched = versions.find(v => v.versionCode === PackageJSON.versionCode);
        if (!matched?.ota?.length) return;

        const latestOTA = matched.ota.reduce((max, cur) =>
            cur.versionCode > max.versionCode ? cur : max,
        );

        const currentOTACode = getCurrentOTAVersionCode();
        if (latestOTA.versionCode <= currentOTACode) return;

        console.log(`[OTA] 发现新 OTA: ${latestOTA.versionName}`);
        await downloadAndApplyOTA(latestOTA);
    } catch (e) {
        console.warn("[OTA] 检查失败:", e);
    }
}

async function downloadAndApplyOTA(ota: OtaItem): Promise<void> {
    const otaRoot = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/${OTA_DIR}`;
    const bundleDir = `${otaRoot}/${ota.versionCode}`;

    try {
        const rootExists = await ReactNativeBlobUtil.fs.exists(otaRoot);
        if (!rootExists) {
            await ReactNativeBlobUtil.fs.mkdir(otaRoot);
        }
        await ReactNativeBlobUtil.fs.mkdir(bundleDir);

        const bundlePath = `${bundleDir}/index.android.bundle`;

        console.log(`[OTA] 开始下载: ${ota.bundleUrl}`);
        const res = await ReactNativeBlobUtil.config({
            fileCache: true,
            path: bundlePath,
        }).fetch("GET", ota.bundleUrl);

        console.log(`[OTA] 下载完成，状态: ${res.respInfo.status}`);

        // 写入版本标记文件，格式: "otaVersionCode|appVersionCode"，供原生层校验
        const versionTagPath = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/ota_version`;
        const tagContent = `${ota.versionCode}|${PackageJSON.versionCode}`;
        await ReactNativeBlobUtil.fs.writeFile(versionTagPath, tagContent, "utf8");

        mmkv.set(OTA_VERSION_KEY, ota.versionCode);
        mmkv.set(OTA_APP_VERSION_KEY, PackageJSON.versionCode);

        await cleanOldOTA(ota.versionCode);

        console.log(`[OTA] 应用成功: ${ota.versionName}，下次启动生效`);
    } catch (e) {
        console.error("[OTA] 下载或应用失败:", e);
        try {
            await ReactNativeBlobUtil.fs.unlink(bundleDir);
        } catch {}
    }
}

async function cleanOldOTA(currentVersionCode: number): Promise<void> {
    try {
        const otaRoot = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/${OTA_DIR}`;
        const exists = await ReactNativeBlobUtil.fs.exists(otaRoot);
        if (!exists) return;

        const entries = await ReactNativeBlobUtil.fs.ls(otaRoot);
        for (const entry of entries) {
            const code = parseInt(entry, 10);
            if (!isNaN(code) && code !== currentVersionCode) {
                await ReactNativeBlobUtil.fs.unlink(`${otaRoot}/${entry}`);
            }
        }
    } catch {}
}
