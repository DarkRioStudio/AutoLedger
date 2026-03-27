# Docs Template Index

更新日期：2026-03-26

## 1. 目录目标

本目录用于沉淀可跨项目复用的文档模板，支持新项目快速启动“IDEA 入池 -> 需求评审 -> 版本规划 -> 迭代执行 -> 回归验证 -> 发布门禁”全流程。

目标：
- 抽取当前项目已验证有效的文档组织架构经验
- 将“模板结构”与“业务需求内容”分层
- 新项目通过填空即可快速进入评审和迭代

## 2. 目录结构

- [00-bootstrap/项目文档组织架构模板](00-bootstrap/项目文档组织架构模板.md)
- [00-bootstrap/项目启动流程与快速迭代模板](00-bootstrap/项目启动流程与快速迭代模板.md)
- [01-planning/业务需求评审模板](01-planning/业务需求评审模板.md)
- [01-planning/版本计划模板](01-planning/版本计划模板.md)
- [01-planning/路线图模板](01-planning/路线图模板.md)
- [01-planning/前后端分离设计模板](01-planning/前后端分离设计模板.md)
- [02-execution/标准迭代提示模板](02-execution/标准迭代提示模板.md)
- [02-execution/迭代工作流模板](02-execution/迭代工作流模板.md)
- [02-execution/迭代想法池模板](02-execution/迭代想法池模板.md)
- [02-execution/迭代日志模板](02-execution/迭代日志模板.md)
- [02-execution/多人协作与AI并行模板](02-execution/多人协作与AI并行模板.md)
- [03-verification/回归基线模板](03-verification/回归基线模板.md)
- [04-release/版本发布与门禁模板](04-release/版本发布与门禁模板.md)
- [05-frontend/前端界面设计规范模板](05-frontend/前端界面设计规范模板.md)
- [05-frontend/前端详细设计方案模板](05-frontend/前端详细设计方案模板.md)
- [05-frontend/前端版本计划模板](05-frontend/前端版本计划模板.md)
- [05-frontend/前端回归基线模板](05-frontend/前端回归基线模板.md)

## 3. 推荐使用顺序

1. 先复制 [项目文档组织架构模板](00-bootstrap/项目文档组织架构模板.md) 与 [项目启动流程与快速迭代模板](00-bootstrap/项目启动流程与快速迭代模板.md)
2. 先在想法池填写 `IDEA-001`（宏观目标）
3. 基于 `IDEA-001` 使用 [业务需求评审模板](01-planning/业务需求评审模板.md)
4. 填 [版本计划模板](01-planning/版本计划模板.md)、[路线图模板](01-planning/路线图模板.md)、[前后端分离设计模板](01-planning/前后端分离设计模板.md)
5. 启动执行阶段模板（工作流、想法池、迭代日志、标准提示模板、多人协作模板）
6. 实施前先建立 [回归基线模板](03-verification/回归基线模板.md)
7. 发布前按 [版本发布与门禁模板](04-release/版本发布与门禁模板.md) 判定
8. 若存在前端子团队，补齐 [05-frontend](05-frontend/前端界面设计规范模板.md) 四份前端模板
9. 每轮落地后同步更新项目 `docs/CHANGELOG.md`

## 4. 维护规则

- 模板文件只维护结构，不写项目特有结论
- 业务事实写入目标项目自身文档，不反向污染模板
- 模板新增/修改后，需在主项目 `docs/CHANGELOG.md` 追加文档记录
