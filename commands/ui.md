---
description: Quill · 前端 UI 设计（产 sketch HTML + ui-spec.md）
argument-hint: "[--pages P1,P2,...]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
---

# /quill:ui · 前端 UI 设计

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。

## Step 2 · 前置校验

```bash
test -f "$QUILL_PRD_DIR/product-requirements.md" || {
    echo "❌ 没找到 PRD ($QUILL_PRD_DIR/product-requirements.md)。请先跑 /quill:prd 产出。"
    exit 1
}
```

## Step 3 · 走 UI 编排

Read `${QUILL_SKILL_DIR}/prompts/ui-design.md`，按其编排执行：启动 `ui-designer` 子 agent 产：
- `${QUILL_PRD_DIR}/sketch/index.html`（导航页）+ 每页 `<page-key>.html`
- `${QUILL_PRD_DIR}/ui-spec.md`（机器可读规约，dev 消费）

## Step 4 · 收尾

- 转发用户「在浏览器打开 `<sketch_dir>/index.html` 看原型」
- 等用户 `确认` / `修改：<点>` → SendMessage 改稿循环
- 更新 `QUILL.md`：`/quill:ui` 状态改 ✅，sketch + ui-spec 打勾
- 询问：「下一步：`/quill:dev` 开始开发？」

## 铁律

- 必须先调 antd MCP 查组件 API 再写组件（不调 MCP 瞎写 = 违规）
- 单页 sketch HTML ≤ 200 行
- 不引构建工具（双击 .html 必须能开）
