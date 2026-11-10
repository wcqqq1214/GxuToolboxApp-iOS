import {gitLabRequest} from "./gitlab.mjs";

export function otaReleaseTag(channel, versionCode) {
    return `ota-${channel}-${versionCode}`;
}

/**
 * 创建或更新 OTA 对应的 GitLab Release。
 * 同一 OTA 版本标签重跑时只更新发布说明，不移动已有标签。
 */
export async function createOrUpdateOtaRelease({
    channel,
    appVersion,
    appVersionCode,
    ota,
    commit,
    releaseNotes,
    versionJsonUrl,
    apkUrl,
}) {
    if (!commit) throw new Error("缺少 commit，无法创建 Release 标签");

    const tagName = otaReleaseTag(channel, ota.versionCode);
    const encodedTag = encodeURIComponent(tagName);
    const name = `${ota.versionName} · ${channel} OTA`;
    const description = buildDescription({
        channel,
        appVersion,
        appVersionCode,
        ota,
        commit,
        releaseNotes,
    });

    const existing = await gitLabRequest("GET", `/releases/${encodedTag}`, {allowNotFound: true});
    const release = existing
        ? await gitLabRequest("PUT", `/releases/${encodedTag}`, {body: {name, description}})
        : await gitLabRequest("POST", "/releases", {
              body: {
                  tag_name: tagName,
                  ref: commit,
                  name,
                  description,
                  assets: {
                      links: [
                          {name: "OTA bundle", url: ota.bundleUrl, link_type: "other"},
                          {name: "version.json", url: versionJsonUrl, link_type: "other"},
                          ...(apkUrl ? [{name: "APK", url: apkUrl, link_type: "package"}] : []),
                      ],
                  },
              },
          });

    const projectUrl = process.env.CI_PROJECT_URL?.replace(/\/+$/, "");
    console.log(`[Release] ${existing ? "已更新" : "已创建"} ${tagName}`);
    return {
        tagName,
        release,
        webUrl: projectUrl ? `${projectUrl}/-/releases/${encodedTag}` : null,
    };
}

function buildDescription({channel, appVersion, appVersionCode, ota, commit, releaseNotes}) {
    const notes = String(releaseNotes ?? "").trim() || `OTA ${ota.versionName}`;
    return [
        "## 更新内容",
        "",
        notes,
        "",
        "## 发布信息",
        "",
        `- 通道：\`${channel}\``,
        `- App：\`${appVersion}\`（\`${appVersionCode}\`）`,
        `- OTA：\`${ota.versionName}\`（\`${ota.versionCode}\`）`,
        `- Commit：\`${commit}\``,
    ].join("\n");
}
