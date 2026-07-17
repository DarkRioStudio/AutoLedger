# AutoLedger iCloud 数据备份设计草案

> 文档状态：Reference
> 真源范围：单文件备份 / 恢复设计背景；不作为当前 CloudKit 多设备同步完整真源
> 文档分类核验：2026-07-17
> 当前同步状态：[../../PROJECT_STATUS.md](../../PROJECT_STATUS.md)

版本：v0.1
目标版本：AutoLedger v1.x
设计目标：本地优先、轻量备份、防止卸载丢数据，并为后续跨设备同步预留空间。

---

## 1. 背景与目标

AutoLedger 当前以本地数据为主，核心数据包括：

- 账单数据
- 自定义来源
- 自定义分类
- 用户自定义商户别名映射

如果用户卸载 App、换机或清空本地数据，这些数据会丢失。

本设计希望通过 iCloud 文件备份机制，让用户在重新安装 App 后可以自动恢复数据。

本阶段不做复杂 CloudKit 结构化同步，不引入账号体系，不做实时协同同步。目标是用一份最新的 JSON 备份文件，解决“数据不丢”和“轻量跨设备恢复”的问题。

---

## 2. 总体设计原则

### 2.1 本地优先

App 的主数据仍然保存在本地数据库中。iCloud 中保存的是一份备份文件，不作为主数据库直接读写。

### 2.2 单文件备份

iCloud 仅维护一份最新备份文件：

```text
AutoLedgerBackup.json
```

MVP 阶段只维护最新文件。必要时未来可以增加历史快照。

### 2.3 可导入、可导出

同一套 `BackupBundle` 同时用于：

- 手动导出 JSON 文件
- 手动导入 JSON 文件
- 自动写入 iCloud 文件
- App 重新安装后自动从 iCloud 恢复

### 2.4 可恢复优先，不追求强实时同步

本阶段的同步语义是：

```text
本地数据变化
→ 延迟生成 BackupBundle
→ 覆盖 iCloud 最新备份文件
```

另一台设备或重装后的 App：

```text
启动时发现 iCloud 备份文件
→ 对比本地状态
→ 自动恢复或提示用户恢复
```

---

## 3. 备份范围

### 3.1 必须备份

#### 账单数据 transactions

包括：

- 金额
- 商户
- 时间
- 分类
- 来源
- 备注
- 创建时间
- 更新时间
- 是否需要复核
- 识别置信度
- 原始来源类型

#### 自定义分类 categories

包括：

- 分类 ID
- 分类名称
- 图标
- 是否系统分类
- 排序
- 是否隐藏

#### 自定义来源 sources

包括：

- 来源 ID
- 来源名称
- 来源类型
- 是否系统来源
- 排序

#### 商户别名映射 merchantAliases

包括：

- 原始商户文本
- 归一化商户名称
- 默认分类 ID
- 默认来源 ID
- 命中次数
- 最后使用时间

---

## 4. BackupBundle 顶层定义

```json
{
  "schemaVersion": 1,
  "bundleId": "uuid",
  "exportedAt": "2026-04-24T18:00:00Z",
  "app": {
    "name": "AutoLedger",
    "version": "1.1.0",
    "build": "12"
  },
  "device": {
    "model": "iPhone16,1",
    "systemName": "iOS",
    "systemVersion": "26.4.1"
  },
  "summary": {
    "transactionCount": 83,
    "categoryCount": 12,
    "sourceCount": 6,
    "merchantAliasCount": 52
  },
  "transactions": [],
  "categories": [],
  "sources": [],
  "merchantAliases": []
}
```

---

## 5. JSON 数据结构

### 5.1 Transaction

```json
{
  "id": "txn_8C8E0B9E-5D7D-4D8D-B9F2-000000000001",
  "amount": 17.0,
  "currency": "CNY",
  "merchant": "山西面馆",
  "merchantRaw": "扫码付款-给山西面馆",
  "transactionDate": "2026-04-24T11:41:00Z",
  "categoryId": "cat_food",
  "sourceId": "src_wechat",
  "note": "",
  "sourceType": "shortcut",
  "confidence": 0.92,
  "needsReview": false,
  "isMultiItemReceipt": false,
  "createdAt": "2026-04-24T11:41:10Z",
  "updatedAt": "2026-04-24T11:41:10Z",
  "deletedAt": null
}
```

### 5.2 Category

```json
{
  "id": "cat_food",
  "name": "餐饮",
  "icon": "fork.knife",
  "color": "orange",
  "isSystem": true,
  "sortOrder": 10,
  "isHidden": false,
  "createdAt": "2026-04-01T00:00:00Z",
  "updatedAt": "2026-04-01T00:00:00Z",
  "deletedAt": null
}
```

### 5.3 Source

```json
{
  "id": "src_wechat",
  "name": "微信支付",
  "type": "payment",
  "icon": "message.fill",
  "isSystem": true,
  "sortOrder": 10,
  "createdAt": "2026-04-01T00:00:00Z",
  "updatedAt": "2026-04-01T00:00:00Z",
  "deletedAt": null
}
```

### 5.4 MerchantAlias

```json
{
  "id": "alias_001",
  "raw": "扫码付款-给山西面馆",
  "normalized": "山西面馆",
  "categoryId": "cat_food",
  "sourceId": "src_wechat",
  "matchType": "exact",
  "hitCount": 8,
  "lastUsedAt": "2026-04-24T11:41:00Z",
  "createdAt": "2026-04-10T10:00:00Z",
  "updatedAt": "2026-04-24T11:41:00Z",
  "deletedAt": null
}
```

---

## 6. 文件命名与存储位置

### 6.1 iCloud 最新备份文件

固定文件名：

```text
AutoLedgerBackup.json
```

推荐 iCloud 容器路径：

```text
Documents/AutoLedgerBackup.json
```

### 6.2 手动导出文件名

手动导出时使用带时间戳的文件名：

```text
AutoLedger_backup_2026-04-24_180000.json
```

---

## 7. 导出流程

### 7.1 手动导出

用户路径：

```text
设置 → 数据管理 → 导出备份
```

流程：

```text
读取本地数据库
→ 构建 BackupBundle
→ JSON 编码
→ 生成 .json 文件
→ 调起系统分享面板
→ 用户保存到 Files / iCloud Drive / AirDrop
```

### 7.2 自动备份到 iCloud

触发时机：

- 新增账单后
- 修改账单后
- 删除账单后
- 修改分类、来源、商户别名后
- App 进入后台时
- 每日首次启动后

为了避免频繁写文件，建议加 debounce：

```text
数据变化后 10~30 秒内合并写一次
```

流程：

```text
本地数据变化
→ 标记 backupDirty = true
→ 延迟生成 BackupBundle
→ 写入临时文件 AutoLedgerBackup.tmp
→ 原子替换 AutoLedgerBackup.json
→ 更新 lastBackupAt
```

---

## 8. 导入与恢复流程

### 8.1 手动导入

用户路径：

```text
设置 → 数据管理 → 从 JSON 恢复
```

流程：

```text
用户选择 JSON
→ 解码 BackupBundle
→ 校验 schemaVersion
→ 展示摘要
→ 用户选择恢复方式
→ 执行导入
```

恢复前展示：

```text
备份时间：2026-04-24 18:00
账单：83 笔
分类：12 个
来源：6 个
商户别名：52 个
```

### 8.2 App 重装后自动恢复

首次启动检测条件：

```text
本地数据库为空
且 iCloud 中存在 AutoLedgerBackup.json
```

建议弹出引导：

```text
检测到 iCloud 备份

备份时间：2026-04-24 18:00
账单：83 笔
分类：12 个
来源：6 个
商户别名：52 个

是否恢复？
[立即恢复] [暂不恢复]
```

不建议完全静默恢复，避免用户不清楚数据来源。

### 8.3 自动跨设备恢复

另一台设备首次安装时，逻辑同重装恢复：

```text
本地为空
→ iCloud 有备份
→ 提示恢复
```

如果本地不为空，则不自动覆盖，应提示：

```text
检测到 iCloud 中存在较新的备份，是否导入？
```

---

## 9. 恢复策略

### 9.1 覆盖恢复（MVP 推荐）

适合：

- 重装后本地为空
- 用户明确选择“覆盖当前数据”

流程：

```text
清空本地数据
→ 导入 categories
→ 导入 sources
→ 导入 merchantAliases
→ 导入 transactions
```

导入顺序很重要，必须先导入被引用的数据。

### 9.2 合并恢复（进阶）

适合跨设备已有数据的场景。

合并规则：

```text
同 id：
  保留 updatedAt 更新的一方

不同 id：
  直接插入

deletedAt 不为空：
  视为软删除记录
```

MVP 可暂不实现复杂合并，但字段需要预留。

---

## 10. iCloud 文件同步策略

### 10.1 单一最新文件

iCloud 中理论上只维护：

```text
AutoLedgerBackup.json
```

每次自动备份覆盖它。

优点：

- 简单
- 易恢复
- 不需要清理历史版本
- 便于用户理解

缺点：

- 不能回滚到历史版本
- 多设备同时写时可能有覆盖风险

### 10.2 多设备写入冲突

MVP 规则：

```text
lastExportedAt 较新的备份获胜
```

如果检测到：

```text
iCloud exportedAt > local lastBackupAt
```

且本地也有近期改动，提示用户选择：

```text
发现 iCloud 备份比本机更新

[使用 iCloud 备份]
[保留本机数据]
[稍后处理]
```

不要静默覆盖。

---

## 11. 状态字段与本地设置

本地建议保存：

```text
lastBackupAt
lastRestoreAt
lastBackupBundleId
iCloudBackupEnabled
backupDirty
lastBackupError
```

设置页展示：

```text
iCloud 备份：已开启
上次备份：今天 18:00
备份内容：83 笔账单，52 个商户别名
```

---

## 12. UI 设计建议

### 12.1 设置页入口

```text
设置
  数据管理
    iCloud 自动备份：开启/关闭
    上次备份时间：今天 18:00
    立即备份
    导出 JSON 备份
    从 JSON 恢复
```

### 12.2 开启 iCloud 备份说明

```text
开启后，AutoLedger 会将账单、分类、来源和商户别名保存为一份 iCloud 备份文件。
重新安装 App 或更换设备后，可以从 iCloud 恢复数据。
```

### 12.3 恢复确认文案

```text
恢复前请确认

此操作将使用备份中的账单、分类、来源和商户别名恢复数据。
建议在恢复前先导出当前数据。
```

---

## 13. 错误处理

### 13.1 iCloud 不可用

场景：

- 用户未登录 Apple ID
- iCloud Drive 未开启
- App iCloud 权限不可用
- 网络不可用

提示：

```text
暂时无法访问 iCloud。你的数据仍保存在本机，可稍后重试。
```

### 13.2 备份文件损坏

提示：

```text
备份文件无法读取，可能已损坏或版本不兼容。
```

### 13.3 schemaVersion 不兼容

提示：

```text
该备份来自较新版本的 AutoLedger，请更新 App 后再尝试恢复。
```

---

## 14. 安全与隐私

### 14.1 数据内容

备份文件包含账单、商户、分类等个人财务数据。隐私政策需说明：

- 用户数据默认本地保存
- 开启 iCloud 备份后，数据会保存到用户自己的 iCloud
- 开发者不拥有或读取用户 iCloud 中的备份文件

### 14.2 是否加密

MVP 可暂不做自定义加密，依赖 Apple iCloud 和系统安全机制。
如果后续做自定义加密，需要重新评估出口合规与用户恢复流程。

### 14.3 文件可读性

JSON 明文文件便于用户导出与迁移，但也意味着用户应妥善保管。导出时提示：

```text
备份文件可能包含账单和商户信息，请妥善保存。
```

---

## 15. 实现建议

### 15.1 Swift 文件建议

```text
BackupBundle.swift
BackupService.swift
ICloudBackupStore.swift
BackupImportService.swift
```

### 15.2 职责划分

#### BackupBundle.swift

定义 Codable 数据结构。

#### BackupService.swift

负责：

- 从数据库构建 BackupBundle
- 将 BackupBundle 写回数据库

#### ICloudBackupStore.swift

负责：

- 获取 iCloud container URL
- 读写 AutoLedgerBackup.json
- 判断 iCloud 是否可用

#### BackupImportService.swift

负责：

- 校验版本
- 预览摘要
- 覆盖恢复
- 合并恢复（未来）

---

## 16. 推荐执行顺序

### Phase 1：手动导出/导入 JSON

目标：

- BackupBundle 定义稳定
- 能导出 JSON
- 能手动恢复

验收：

```text
导出 10 笔账单
删除 App 数据
手动导入 JSON
账单、分类、来源、别名全部恢复
```

### Phase 2：自动写入 iCloud 最新备份

目标：

- 数据变化后自动写 `AutoLedgerBackup.json`
- 设置页显示备份状态

验收：

```text
新增账单
等待自动备份
Files/iCloud 容器中存在最新备份
```

### Phase 3：重装后自动检测恢复

目标：

- 本地为空时检测 iCloud 备份
- 弹出恢复提示
- 用户确认后恢复

验收：

```text
卸载 App
重新安装
启动 App
提示发现 iCloud 备份
确认后恢复数据
```

### Phase 4：跨设备轻同步

目标：

- 第二台设备安装后可读取同一份 iCloud 备份
- 提示导入

验收：

```text
设备 A 新增账单并自动备份
设备 B 启动检测到 iCloud 备份
设备 B 恢复后看到设备 A 的账单
```

---

## 17. 不做事项

MVP 不做：

- 云端账号系统
- 后端数据库
- 多人共享账本
- 复杂冲突合并
- 逐条 CloudKit Record 实时同步
- 自定义端到端加密
- 多版本历史备份管理

---

## 18. 总结

本方案采用：

```text
本地数据库作为主数据源
BackupBundle 作为统一备份格式
JSON 文件作为手动导入导出介质
iCloud 文件作为自动备份与轻同步介质
```

它的优势是：

- 实现成本低
- 用户容易理解
- 不引入账号体系
- 可以防止卸载丢数据
- 可为未来 CloudKit 结构化同步预留数据模型

当前阶段应优先完成：

```text
BackupBundle
手动导入导出
iCloud 最新备份文件
重装恢复提示
```
