# 开发 skills

Codex 会发现 `.agents/skills/` 中的仓库级 skills。开发流程以根目录的 [AGENTS.md](../AGENTS.md) 为准。

- `poteto-mode` 和 `pstack-*` 使用 pstack 0.15.36 及其 Cursor Team Kit 依赖。上游固定在 [`ae5650f`](https://github.com/cursor/plugins/tree/ae5650febf4320793844c12c4adaa937f417f8da)。Codex 入口在 `skills/`，上游文件和 [Codex 适配说明](vendor/pstack/CODEX-ADAPTER.md) 在 `vendor/pstack/`。保留 [pstack](vendor/pstack/pstack/LICENSE) 和 [Cursor Team Kit](vendor/pstack/cursor-team-kit/LICENSE) 的 MIT 许可。
- `swiftui-pro` 2.0.0 来自 Paul Hudson 的 SwiftUI Agent Skill，与本项目此前在 Claude Code 使用的版本一致。上游固定在 [`f2920b6`](https://github.com/twostraws/SwiftUI-Agent-Skill/tree/f2920b63995263f57b3e198674e89a602efba6d2/swiftui-pro)，并保留 [MIT 许可](skills/swiftui-pro/LICENSE)。
