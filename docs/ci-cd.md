# CI/CD 说明

## 当前状态

- 当前代码面向正式版 `2.2.0 / 20200`，`package.json` 和 Android 版本名统一为 `2.2.0`。
- 正式版 OTA 的比较基线由 `OTA_RELEASE_BASE_SHA` 固定，当前取 `v2.1` 的提交 `a4a06769b6e6fa03771bcc65a5760149704fc060`
  。发布新 APK 后应同步更新。
- `beta-ota` 继续用于 beta 通道，待发布代码的版本名应包含 `beta`。
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
- 比较 APK 基线与工作区，原生代码、图片、字体及原生依赖变化需要整包发布。
- 允许同一 App 版本添加或移除 `beta` 后缀，以及已审阅的两个 adapters 入口更新。当前仅审阅 `@gxutool/adapters` 与
  `gxu-tool-adapters` 对应的 `1.1.1` 包，其依赖仅限 `cheerio` 和 `zod`。
- `package.json` 的其他字段、锁文件的其他依赖解析结果、Gradle 的其他内容仍须与基线一致。锁文件中的弃用提示可以变化。
- 基线缺失或不可读取时停止发布。
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

| 变量               | 敏感 | 说明                                                                                       |
| ------------------ | ---- | ------------------------------------------------------------------------------------------ |
| `COS_BUCKET`       | 否   | 桶名，格式 `xxx-1250000000`                                                                |
| `COS_REGION`       | 否   | 如 `ap-guangzhou`                                                                          |
| `COS_SECRET_ID`    | 是   | COS 写入凭证                                                                               |
| `COS_SECRET_KEY`   | 是   | COS 写入凭证                                                                               |
| `GITLAB_NPM_TOKEN` | 是   | 拉取私有 `@gxutool` npm 包；PAT 需要 `read_api`，Deploy Token 需要 `read_package_registry` |
| `GITLAB_API_TOKEN` | 是   | 可选；创建 Release、反查 MR 描述。默认用 `CI_JOB_TOKEN`，改用 PAT 时需要 `api` 权限        |

设置位置：项目 → Settings → CI/CD → Variables。敏感项勾选 Masked 和 Protected；`beta-ota` / `ota` 必须是 Protected 分支，否则变量不会注入。

`GITLAB_NPM_TOKEN` 是必需项。pnpm 10 会忽略项目 `.npmrc` 里的 `${GITLAB_NPM_TOKEN}` 展开，流水线会在 `before_script` 中把它写到临时 userconfig（`.ci-npmrc`），请不要把这个文件提交。

权限建议：单独 CAM 子账号，只给 `cos:PutObject` 到 `GxuToolApp/*`，不要给 Delete，也不要给整个桶的权限。有条件用 STS 临时密钥。

## 分支保护

- `beta-ota` / `ota`：Allowed to push = No one，Allowed to merge = Maintainers。
- 只允许 MR 合并，禁止直接 push；否则 `CI_COMMIT_BEFORE_SHA` 的 diff 基线不可靠。
- 发布 job 使用 `resource_group: gxu-cos-publish`，四条通道串行，避免并发改 `version.json`。

## 本地测试

```bash
pnpm i --frozen-lockfile

# 只构建和校验，不上传
node scripts/ci/publish-ota.mjs --channel release --dry-run --base a4a06769b6e6fa03771bcc65a5760149704fc060

# 真正上传并创建 Release（CI 外还需提供 CI_API_V4_URL、CI_PROJECT_ID、GITLAB_API_TOKEN）
COS_BUCKET=xxx-1250000000 \
COS_REGION=ap-guangzhou \
COS_SECRET_ID=... \
COS_SECRET_KEY=... \
node scripts/ci/publish-ota.mjs --channel release --base a4a06769b6e6fa03771bcc65a5760149704fc060 --create-release
```

同版本的通道标识修复由兼容检查自动识别。正常发布应提供有效 APK 基线并保持检查开启。

## 常见问题

- **通道不匹配**：`package.json` 的 version 必须含 `beta` 才会发 beta；否则请先修版本标识。
- **找不到 APK 条目**：先发整包。OTA 不能先于对应 `versionCode` 的 APK 发布，否则没有客户端能收到。
- **OTA 被拒绝**：检查是否改了原生代码、依赖、`src/pictures/` 或图片/字体。这些只能走整包。
- **CDN 缓存**：脚本会给 `version.json` 设置 `Cache-Control: no-cache`，但仍建议在腾讯云控制台刷新该路径。
- **重复发布**：相同 bundle 会按 `sha256` 复用；如果只是想重试上传，直接重跑流水线即可。
- **Release 401/403**：确认 job token 未被禁用；否则配置 `GITLAB_API_TOKEN`，并给 `api` 权限。发布者至少需要 Developer 角色。
- **Release 已存在**：脚本会先查再更新；如果两个人同时发布，重跑一次即可。已有 tag 不会移动到新 commit。
- **pnpm install 401/404**：检查 `GITLAB_NPM_TOKEN` 是否已配置、是否对项目 86 的 Package Registry 有读取权限；不要依赖项目 `.npmrc` 里的环境变量展开。
