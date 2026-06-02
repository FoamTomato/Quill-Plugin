# /quill:ui 编排（UI 风格 skill 工厂）

> 入口：`/quill:ui`
> 定位：用户想优化 / 定义 UI 时调用。**不产 sketch HTML、不写业务代码**。
> 产物：一个可复用的风格 skill `${QUILL_SKILL_DIR}/skills/style/<slug>/index.md`，进索引后 dev/dev-lite 自动复用。

---

## 主 Agent 铁律

1. **不自己提炼/写风格 skill 正文**（交 `ui-style-author` 子 agent）
2. 风格 skill 只写到 `skills/style/`（受 `--exclude=style/` 保护，不被 bundle 同步删掉）
3. 保存前**用 AskUserQuestion 给用户系统引导**：确认 slug + 是否覆盖已有同名风格

---

## Phase 0 · 选来源（AskUserQuestion）

问用户风格从哪来：

- **A 扫描现有代码**（mode=scan）：从项目前端代码提炼当前实际风格（配色/间距/组件库/字体/布局）。
- **B 选内置风格**（mode=preset）：极简 / 玻璃拟态 / 暗黑 / Bento / 拟物 / 扁平 / 新拟物，选一种。
- **C 总结自有风格**（mode=summary）：用户口述风格描述，agent 整理成 skill。

再问 / 确认：风格名 `style_name` + 目录 slug（kebab，如 `acme-minimal`）。
若 `skills/style/<slug>/` 已存在 → AskUserQuestion：覆盖 / 换 slug / 取消。

---

## Phase 1 · 调 ui-style-author（单次调用）

```
Agent(
  subagent_type="ui-style-author",
  description="Author UI style skill",
  prompt="""mode=<scan|preset|summary>
slug=<slug>
style_name=<style_name>
preset=<内置风格名，仅 preset 模式>
style_desc=<用户口述，仅 summary 模式>
skill_dir=$QUILL_SKILL_DIR/skills/style
plugin_root=$CLAUDE_PLUGIN_ROOT
"""
)
```

ui-style-author 写 `skills/style/<slug>/index.md`（含 `applies_to` glob）→ **自己跑 `build-skill-index.sh` 重建索引** → 返回 `STYLE_SKILL=...` `STYLE_SLUG=...`。

---

## Phase 2 · 收尾

1. 系统引导提示用户：
   - 「✅ 风格已存为可复用 skill `style/<slug>`，下次 `/quill:dev` / `/quill:dev-lite` 写前端会自动检索命中并遵循它。」
   - 「想跨项目复用：它在 `~/.claude/quill-skills/skills/style/` 全局目录，已设保护不被 update 删除。」
2. 可选自检：`bash $CLAUDE_PLUGIN_ROOT/lib/skill-pick.sh ui <style_name 关键字>` 应能返回该 skill。
3. 更新 `QUILL.md`：能力清单 `/quill:ui` ✅、产物完成度勾「UI 风格 skill」、最近活动 append 一行。
4. 询问下一步：`/quill:dev` / `/quill:dev-lite`（写前端会用上这个风格）。

---

## 绝对禁止

- ❌ 产 sketch HTML / ui-spec.md（本命令只产风格 skill）
- ❌ 把风格写到 `style/` 以外目录（dev 检索不到 + 不受保护）
- ❌ scan 模式不实测就编 token
- ❌ 不重建索引（dev 当次检索不到）
