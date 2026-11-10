# 发布流程与发布说明

## 版本号

- App 版本：`package.json.versionCode` 和 `android/app/build.gradle` 的 `versionCode` 必须一致。
- App 版本名：`package.json.version`，beta 渠道必须包含 `beta`。
- OTA 版本：`<appVersionCode><MMDD><seq>`，例如 `20200` + `1030` + `02` = `20200103002`。
- OTA 版本名：`2.2.0beta-103002`。

## OTA 发布

1. feature/fix 从 `vX.X` 切出，PR 合回 `vX.X`。
2. 从 `vX.X` 向 `beta-ota` / `ota` 发 PR。
3. MR 流水线执行 `--dry-run`：构建 bundle、校验通道和 APK 条目、检查 diff。
4. 合并后在 push 流水线里手动触发 `publish_beta_ota` / `publish_ota`（验证通过后可改为自动）。
5. 脚本上传 bundle 和 `version.json`，然后创建或更新 GitLab Release。
6. 客户端下次启动检查并下载，再下次启动加载。

要求：

- 只能包含 JS 变更；`android/`、`ios/`、`package.json`、`pnpm-lock.yaml`、`src/pictures/`、图片/字体都会失败。
- `version.json` 里必须已有同 `versionCode` 的 APK 条目，且 `ori.official` 非空。
- OTA 不能先于 APK；新版本先发整包，再发 OTA。

## GitLab Release

- 每次 OTA 发布成功后自动创建或更新，不会在 MR 校验阶段提前创建。
- 标签：`ota-beta-<OTA versionCode>` / `ota-release-<OTA versionCode>`。
- 名称：`<OTA versionName> · <channel> OTA`。
- 说明：复用本次 OTA 的发布说明，并附通道、App/OTA 版本、commit。
- 附件以链接形式提供 OTA bundle、`version.json` 和对应 APK，文件仍由 COS 托管，不占 GitLab 仓库空间。
- 重跑同一 OTA 只更新 Release 说明；已有 tag 不移动。要修订已发布内容，必须发新的 OTA `versionCode`。

## APK 发布（规划）

1. `vX.X` → `main` / `beta`，更新通道基线，不发布。
2. `main` / `beta` → `apk` / `beta-apk`，发布整包。
3. 版本号变更在 `vX.X` 上完成，`package.json` 和 `android/app/build.gradle` 同时改。
4. 整包构建校验签名、`versionCode` 单调性和通道字符串，再上传并用 PR 描述更新 `version.json`。
5. 整包发布同样创建独立 Release（建议标签 `apk-beta-<versionCode>` / `apk-release-<versionCode>`，规划中）。

## 发布说明

发布说明取发布 PR 的描述，按以下优先级：

1. `<!-- release-notes:start -->...<!-- release-notes:end -->` 之间的内容。
2. `## 更新内容` / `## Release Notes` 这一节。
3. 整段描述；为空时回退到 MR 标题，再回退到 commit message。

脚本会去掉 Markdown 标记、图片、链接和 HTML 注释，截断到 4000 字符，然后写入 `version.json` 的 `desc`；同一份文本也会作为 GitLab Release 的更新内容。

模板见 `.gitlab/merge_request_templates/Release.md`。

## version.json

```json
{
    "beta": [
        {
            "versionName": "2.2.0 beta",
            "versionCode": 20200,
            "desc": "...",
            "dependency": "",
            "ori": {"official": "https://file.unde.site/GxuToolApp/beta/gxu_tool_app-v2.2.0%20beta.apk"},
            "ota": [
                {
                    "versionName": "2.2.0beta-103002",
                    "versionCode": 20200103002,
                    "desc": "...",
                    "bundleUrl": "https://file.unde.site/GxuToolApp/ota/20200/20200103002.index.android.bundle",
                    "sha256": "...",
                    "commit": "..."
                }
            ]
        }
    ],
    "release": []
}
```

- 通道数组按 `versionCode` 降序；客户端用 `find(v => v.versionCode > 当前)` 取第一条。
- `ota` 数组也按 `versionCode` 降序。
- `sha256` / `commit` 客户端会忽略，用于发布追踪和幂等。

## 回滚

- 客户端一旦下载并写入 OTA 标记，删除 `version.json` 条目不会自动回滚。
- 回滚方式：基于上一个版本代码重新打一个更高 `versionCode` 的 OTA，发到同一通道；客户端会覆盖。
- 当前原生层没有崩溃回退逻辑，如果 OTA bundle 启动崩溃，用户可能一直卡住。发布前务必在真机测试包上验证。

## 排查

- `[OTA] 检查失败`：看网络、`version.json` 是否可访问、通道是否匹配。
- `[OTA] 下载或应用失败`：看 bundle URL、COS 权限、文件大小。
- 首次启动只下载，第二次启动才加载；验证时至少启动两次。
- Release 创建失败时，先看 job 日志里的 GitLab API 状态码；OTA 已上传成功的情况下，直接重跑发布 job 会复用 OTA 并补建 Release。
