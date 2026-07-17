# AutoLedger App Intent 一键记账 MVP 实施方案

> 文档状态：Historical
> 真源范围：早期一键记账 MVP 决策背景，不代表当前 App Intent、OCR 或确认流程
> 文档分类核验：2026-07-17
> 当前状态：[../PROJECT_STATUS.md](../PROJECT_STATUS.md)

目标非常明确：

操作按钮 → 快捷指令截图 → 图片传给 App Intent → OCR → 解析 → 入账 → 返回“已记好”

先只做一条最小主线，别贪多。

⸻

一、MVP 目标

第一版只要求做到：
	1.	操作按钮绑定快捷指令
	2.	快捷指令执行截图
	3.	快捷指令把截图图片传给 AutoLedger 的 App Intent
	4.	App Intent 调起核心服务
	5.	核心服务完成：
	•	OCR
	•	金额提取
	•	商户提取
	•	时间提取
	•	自动分类
	•	SQLite 入账
	6.	返回一句结果：
	•	已记好：瑞幸咖啡 ¥28
	•	或 识别失败，请打开 App 确认

⸻

二、MVP 范围

这版做
	•	App Intent 接收图片
	•	本地 OCR
	•	微信支付成功页解析
	•	SQLite 本地入账
	•	简单分类
	•	简单去重
	•	成功/失败返回结果

这版不做
	•	支付宝
	•	Apple 订阅
	•	多笔拆分
	•	自动删截图
	•	iCloud
	•	Apple Watch
	•	报表
	•	云端 AI
	•	复杂通知

三、主链路设计

4.1 用户链路

理想链路
	1.	用户停留在支付页
	2.	长按操作按钮
	3.	快捷指令执行：
	•	截图
	•	把图片传给 QuickLedgerIntent
	4.	App Intent 调用 QuickLedgerService
	5.	QuickLedgerService：
	•	OCR
	•	解析
	•	分类
	•	去重
	•	入库
	6.	系统返回一句：
	•	已记好：微信支付 ¥28

失败链路
	1.	图片 OCR 不出来
	2.	或金额没识别到
	3.	返回：
	•	没识别准，请打开 App 确认
