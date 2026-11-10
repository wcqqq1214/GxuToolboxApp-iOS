---
name: pstack-principle-separate-before-serializing-shared-state
description: "pstack principle-separate-before-serializing-shared-state: Apply when concurrent actors might write to the same file, branch, key, or state object. Eliminate the sharing first; serialize structurally only when one shared writer is a real invariant."
---

Read the [Codex compatibility rules](../../vendor/pstack/CODEX-ADAPTER.md), then read the [upstream skill](../../vendor/pstack/pstack/skills/principle-separate-before-serializing-shared-state/SKILL.md). Follow its dependencies using the adapter mapping.
