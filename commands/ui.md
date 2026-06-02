---
description: Quill · UI 风格 skill 工厂（扫描/选/总结风格 → 存成可复用 style skill，下次 dev 自动用）
argument-hint: "[风格名 | 空]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:ui · UI 风格 skill 工厂

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> 用户想优化 / 定义 UI 时用。**不产 sketch HTML、不写业务代码**。
> 产物：一个可复用的**风格 skill** `${QUILL_SKILL_DIR}/skills/style/<slug>/index.md`。
> 进索引后，`/quill:dev` / `/quill:dev-lite` 写前端会自动检索命中并遵循它 —— 下次直接用，不用重描述。

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行环境保护 + 配置 bootstrap + skill 校验。

## Step 2 · 走 UI 风格编排

Read `${QUILL_SKILL_DIR}/prompts/ui-style.md`，按其执行：

1. **Phase 0** — AskUserQuestion 选来源：
   - A 扫描现有代码提炼风格（mode=scan）
   - B 从内置风格库选一种（极简/玻璃拟态/暗黑/Bento/拟物/扁平/新拟物，mode=preset）
   - C 用户口述总结自有风格（mode=summary）
   - 确认风格名 + slug；已有同名则问覆盖/换名/取消（**系统引导**）
2. **Phase 1** — 调 `ui-style-author` 子 agent：产 `skills/style/<slug>/index.md` + **重建 skill 索引**
3. **Phase 2** — 收尾：系统引导提示「已存为可复用 skill `style/<slug>`，下次 dev 自动用」；更新 QUILL.md；提示下一步 `/quill:dev[-lite]`

## 铁律

1. 主 Agent 不提炼/写风格 skill 正文（交 ui-style-author 子 agent）
2. 风格 skill 只写到 `skills/style/`（受 `--exclude=style/` 保护，不被 update 删）
3. 不产 sketch HTML / ui-spec.md（只产风格 skill）
4. 写完必须重建索引（否则 dev 当次检索不到）
