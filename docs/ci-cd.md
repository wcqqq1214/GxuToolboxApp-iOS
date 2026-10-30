# CI/CD 说明

## 当前状态

- `beta-ota` 从 `beta` 拉出，用于验证 OTA 发布链路。
- `origin/beta` 当前的 `package.json` 版本是 `2.2.0`，不带 `beta`，客户端会判定为 release 通道。`beta-ota` 上已恢复为 `2.2.0 beta`（`package.json` 和 `android/app/build.gradle`）。
- 这个修复应尽快合回 `beta`，否则后续从 `beta` 切出的 OTA 分支都会走错通道。
- 目前只启用 OTA；`ota` / `apk` / `beta-apk` 的 job 已预留，分支创建后自动生效。
- 发布 job 目前是 `when: manual`。验证通过后删掉这一行即可自动发布，并自动创建/更新 GitLab Release。

## 分支模型

```text
main ──切出──> vX.X ──<── feature/fix
                  ├── 快进 ──> ota / beta-ota             → 发布 OTA
                  ├── 快进 ──> main / beta                → 更新通道基线（不发布）
                  └── main/beta ──快进──> apk / beta-apk  → 发布 APK
```

- 唯一代码线是 `vX.X`，feature 只进这里。
- `main` / `beta` 是通道基线，只接收 `vX.X` 快进。
- `ota` / `beta-ota` / `apk` / `beta-apk` 是发布指针，不允许有独有提交。
- `main` 同时是下个版本的切出点。

## 流水线

| Job                | 触发              | 行为                                                       |
| ------------------ | ----------------- | ---------------------------------------------------------- |
| `verify_beta_ota`  | MR → `beta-ota`   | 构建 bundle、校验，不上传                                  |
| `publish_beta_ota` | push → `beta-ota` | 上传 bundle、更新 `version.json`、创建 Release；当前为手动 |
| `verify_ota`       | MR → `ota`        | 同上，release 通道                                         |
| `publish_ota`      | push → `ota`      | 同上，release 通道；当前为手动                             |

校验内容包括：

- `package.json.version` 与目标通道一致（含 `beta` 才是 beta 通道）。
- `version.json` 中必须已存在同 `versionCode` 的 APK 条目，且 `ori.official` 非空。
- diff 中不能出现 `android/`、`ios/`、`package.json`、`pnpm-lock.yaml`、`src/pictures/`、图片或字体文件。
- 新 OTA 的 `versionCode` 必须大于同版本下已有 OTA。
- bundle 内容相同（`sha256`）时复用已有 OTA 条目，不重复追加。

## GitLab Release

- 只有 COS 上传成功后才创建或更新 Release；MR 校验和 `--dry-run` 都不会创建。
- 标签格式：`ota-beta-<OTA versionCode>` / `ota-release-<OTA versionCode>`，例如 `ota-beta-20200103002`。
- Release 名称：`<OTA versionName> · <channel> OTA`。
- 发布说明复用 `version.json` 的 `desc`，并附带通道、App/OTA 版本、commit、OTA bundle、`version.json` 和 APK 链接。
- 同一标签重跑只更新发布说明，不移动已有 tag。需要修订已发布内容时，应发一个更高 `versionCode` 的新 OTA。
- 默认使用 `CI_JOB_TOKEN` 调 GitLab API；如果项目禁用了 job token 或接口返回 403，再配置 `GITLAB_API_TOKEN`。

## 变量

| 变量               | 敏感 | 说明                                                                                |
| ------------------ | ---- | ----------------------------------------------------------------------------------- |
| `COS_BUCKET`       | 否   | 桶名，格式 `xxx-1250000000`                                                         |
| `COS_REGION`       | 否   | 如 `ap-guangzhou`                                                                   |
| `COS_SECRET_ID`    | 是   | COS 写入凭证                                                                        |
| `COS_SECRET_KEY`   | 是   | COS 写入凭证                                                                        |
| `GITLAB_API_TOKEN` | 是   | 可选；创建 Release、反查 MR 描述。默认用 `CI_JOB_TOKEN`，改用 PAT 时需要 `api` 权限 |

设置位置：项目 → Settings → CI/CD → Variables。敏感项勾选 Masked 和 Protected；`beta-ota` / `ota` 必须是 Protected 分支，否则变量不会注入。

权限建议：单独 CAM 子账号，只给 `cos:PutObject` 到 `GxuToolApp/*`，不要给 Delete，也不要给整个桶的权限。有条件用 STS 临时密钥。

## 分支保护

- `beta-ota` / `ota`：Allowed to push = No one，Allowed to merge = Maintainers。
- 只允许 MR 合并，禁止直接 push；否则 `CI_COMMIT_BEFORE_SHA` 的 diff 基线不可靠。
- 发布 job 使用 `resource_group: gxu-cos-publish`，四条通道串行，避免并发改 `version.json`。

## 本地测试

```bash
pnpm i --frozen-lockfile

# 只构建和校验，不上传
node scripts/ci/publish-ota.mjs --channel beta --dry-run

# 真正上传并创建 Release（CI 外还需提供 CI_API_V4_URL、CI_PROJECT_ID、GITLAB_API_TOKEN）
COS_BUCKET=xxx-1250000000 \
COS_REGION=ap-guangzhou \
COS_SECRET_ID=... \
COS_SECRET_KEY=... \
node scripts/ci/publish-ota.mjs --channel beta --create-release
```

首次 bootstrap 如果 `package.json` 的版本标识修复还在 diff 里，需要加 `--skip-diff-check`；CI 里对应设置 `OTA_SKIP_DIFF_CHECK=1`。bootstrap 阶段可以直接 push 到 `beta-ota`，验证通过后开启分支保护走 MR。正常发布不要跳过检查。

## 常见问题

- **通道不匹配**：`package.json` 的 version 必须含 `beta` 才会发 beta；否则请先修版本标识。
- **找不到 APK 条目**：先发整包。OTA 不能先于对应 `versionCode` 的 APK 发布，否则没有客户端能收到。
- **OTA 被拒绝**：检查是否改了原生代码、依赖、`src/pictures/` 或图片/字体。这些只能走整包。
- **CDN 缓存**：脚本会给 `version.json` 设置 `Cache-Control: no-cache`，但仍建议在腾讯云控制台刷新该路径。
- **重复发布**：相同 bundle 会按 `sha256` 复用；如果只是想重试上传，直接重跑流水线即可。
- **Release 401/403**：确认 job token 未被禁用；否则配置 `GITLAB_API_TOKEN`，并给 `api` 权限。发布者至少需要 Developer 角色。
- **Release 已存在**：脚本会先查再更新；如果两个人同时发布，重跑一次即可。已有 tag 不会移动到新 commit。
