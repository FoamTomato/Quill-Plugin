# /quill ui 编排

> 入口：`/quill ui`
> 上游：`/quill prd` 已产 `product-requirements.md`
> 产物：`${QUILL_PRD_DIR}/sketch/` 目录 + `${QUILL_PRD_DIR}/ui-spec.md`

---

## 前置校验

```bash
test -f "$QUILL_PRD_DIR/product-requirements.md" || {
    echo "❌ 没找到 PRD。请先跑 /quill prd 产出 product-requirements.md"
    exit 1
}
```

---

## 单 Agent · ui-designer

```
Agent(
  subagent_type="ui-designer",
  description="Design UI sketch + spec",
  prompt="""prd=$QUILL_PRD_DIR/product-requirements.md
sketch_dir=$QUILL_PRD_DIR/sketch
ui_spec=$QUILL_PRD_DIR/ui-spec.md
project_name=$QUILL_PROJECT_NAME
"""
)
```

ui-designer 行为：
1. Read PRD「三、需求设计预览」+「四、模块流程图」段识别**前端页面清单**
2. 调 antd MCP（`antd_info` / `antd_demo` / `antd_token`）查每个页面要用的组件 API
3. 写 `sketch/index.html`（导航页）
4. 每个页面写一份 `<page-key>.html`（antd CDN 静态原型，双击可开，每页 ≤ 200 行）
5. 写 `ui-spec.md`（组件清单 + 交互态 + token + 路由 → /quill dev 消费）
6. 返回 stdout：`SKETCH_DIR=<绝对路径>` `UI_SPEC=<绝对路径>` `PAGE_COUNT=<n>`

---

## 主 Agent 收尾

1. 收路径 → 转发用户「在浏览器打开 `<sketch_dir>/index.html` 看原型」
2. 等用户回 `确认` / `修改：<点>` → SendMessage 改稿循环
3. 更新 `QUILL.md`：
   - 「能力清单」`/quill ui` 状态改 ✅
   - 产物 checklist 打勾 `sketch/index.html` + `ui-spec.md`
   - 「最近活动」append 一行
4. 询问：「下一步：`/quill dev` 开始开发？」

---

## 时序日志

append 到 `${QUILL_PRIVATE_DIR}/logs/ui-log.md`：

```
[260528 1900] ui-designer started id=...
[260528 1925] sketch submitted, dir=docs/prd/.../sketch/, pages=5
[260528 1930] user feedback: 改 P2 表单
[260528 1945] sketch revised
[260528 1950] confirmed
```

---

## 绝对禁止

- ❌ 跳过 antd MCP 直接瞎写组件（必须先调 MCP 查 API）
- ❌ 引构建工具（Vite / npm / React JSX 编译链）— 必须**双击 .html 浏览器打开**
- ❌ 任何 page.html > 200 行（拆 tab / step）
- ❌ ui-spec.md 用人话写（必须机器可读：组件 token / 路由 / state 列）
