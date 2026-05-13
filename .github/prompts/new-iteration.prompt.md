---
description: "启动一轮新迭代。填写执行前检查模板，确认目标、文件范围、风险和验收点后再开始实施。"
argument-hint: "IDEA-XXX 或本轮目标描述"
agent: agent
---

按照 [迭代工作流](../../../process/agent-iteration-workflow.md) 的 5 步流程，为本轮迭代填写执行前检查，然后等待用户确认范围后再实施。

## 步骤

### 1. 读取上下文

先读取以下文件，获取当前状态：

- [process/iteration-log.md](../../../process/iteration-log.md) — 最近 2 条日志，了解上轮结论与遗留风险
- [process/iteration-idea-backlog.md](../../../process/iteration-idea-backlog.md) — 找到目标 IDEA 条目
- 最新版本计划（[versions/v1.3.5-plan.md](../../../versions/v1.3.5-plan.md) 或更新版本）

### 2. 填写执行前检查

输出以下模板（严格按格式，不省略任何字段）：

```markdown
### ITER-XXX 执行前检查
- 本轮目标：
- 所属 IDEA：IDEA-XXX
- 建议版本：vX.Y.Z
- 本轮计划改动文件：
  - [ ] 文件路径 — 改动说明
- 本轮明确不改范围：
- 风险点：
- 验收点：
- 最小回归包：bash scripts/run_offline_regression.sh（若改动 Core 层）
- 预期回滚方式：git revert / 手动还原
```

### 3. 等待用户确认

**输出检查表后停止，等待用户确认范围无误后再开始实施。**

用户确认后，按照检查表中的文件清单逐一实施，完成后提醒执行最小回归包。

### 4. 实施后提示

实施完成后，提示用户：

1. 执行最小回归包验证
2. 回填 [process/iteration-log.md](../../../process/iteration-log.md) 迭代日志条目
3. 更新 [CHANGELOG.md](../../../CHANGELOG.md)
