# 项目原型（Axure RP）

本目录用于存放项目原型文件，以 Axure RP 为主要工具，服务于"RP 原型驱动启动"流程。

## 目录结构建议

```
prototype/
  vX.Y.Z/            # 按版本归档原型文件
    screens/         # 页面截图（PNG/SVG），供文档引用与评审
    *.rp             # Axure RP 源文件
    *.html（可选）   # Axure 导出的 HTML 预览包
  README.md          # 本文件
```

## 使用规则

- 每个版本原型放在独立子目录 `vX.Y.Z/` 下，与版本计划同步。
- `screens/` 目录存放关键页面截图，用于 `docs/demo/versions/` 下的版本计划文档和前端详细设计方案引用。
- 原型文件命名：`[版本号]-[模块名].rp`，如 `v0.1.0-workbench.rp`。
- 原型评审通过后，基于原型产出对应的"前端详细设计方案"与一批 `IDEA`，再进入迭代执行阶段。

## 与其他文档的关系

| 原型产物 | 对应文档 |
|---|---|
| 页面截图 + 交互标注 | `docs/demo/template/05-frontend/前端详细设计方案模板.md` |
| 页面/功能需求列表 | `docs/demo/process/iteration-idea-backlog.md`（批量新增 IDEA） |
| 版本归属 | `docs/demo/versions/vX.Y.Z-plan.md` |
