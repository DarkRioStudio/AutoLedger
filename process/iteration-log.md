# 迭代日志

更新日期：2026-06-19（GOAL-1730 学习缓存设计）

## 记录规则

- 每轮迭代都记录
- 记录事实，不写愿景
- 记录执行后的真实结果，不记录执行前计划
- 至少包含目标、范围、完成度、测试、风险、回滚

## 条目模板

```markdown
### ITER-XXX 标题
- 日期：YYYY-MM-DD
- 所属版本：vX.Y.Z
- 所属阶段：Phase N
- 类型：重构 / 测试 / 文档 / 治理 / 能力增强 / Bugfix
- 目标：
- 改动范围：
- 未改动范围：
- 完成内容：
- 未完成内容：
- 测试情况：
- 风险与注意事项：
- 回滚方式：
- 结论：
- 下一步建议：
```

## 与迭代工作流模板的边界

- `迭代工作流`：执行前流程与门禁
- 本模板：执行后记录与追溯
- 若执行前计划与实际不一致，以本模板中的“实际结果”为准，并在条目中说明偏差

## 关联要求

每条日志应可追溯到：
- 版本计划
- 相关代码/文档变更
- CHANGELOG 条目

## 日志条目

### ITER-209 GOAL-1730 商户 / 分类 / 订阅倾向学习缓存设计
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：文档 / 架构设计 / 隐私边界
- 目标：冻结商户、分类和订阅倾向学习缓存的安全边界，明确不缓存原始 OCR 和敏感字段。
- 改动范围：新增 `docs/recognition-learning-cache-design.md`；`versions/v1.6.0-plan.md` 标记 `GOAL-1730` 完成并补充设计记录；`CHANGELOG.md` 回填本轮变更。
- 未改动范围：未实现运行时代码；未新增 SQLite schema；未改变 iCloud 同步 schema；未修改 Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：学习缓存分层为 L1 用户确认规则、L2 商户级低风险画像、L3 短期脱敏 OCR hash 缓存；明确 L1 复用现有商户别名、分类修正和用户确认订阅；L2 只保存低风险商户级统计；L3 顺延到 `GOAL-1735`，不进入 iCloud 或 JSON 备份。
- 未完成内容：短期脱敏 OCR hash 缓存、商户画像运行时代码、订阅提示负向学习和清除识别学习数据入口继续后续推进。
- 测试情况：执行 `git diff --check`，结果 PASS。本轮仅文档设计，无需构建。
- 风险与注意事项：后续实现必须继续遵守“缓存只增强候选，不覆盖金额和日期，不自动创建订阅”的边界；任何进入 iCloud 的学习数据都必须保持商户级低风险粒度。
- 回滚方式：删除 `docs/recognition-learning-cache-design.md`，并恢复 `versions/v1.6.0-plan.md`、`CHANGELOG.md` 和本条 iteration log。
- 结论：本轮完成，GOAL-1730 已冻结设计边界。
- 下一步建议：进入 `GOAL-1735`，实现外部辅助识别短期脱敏 OCR hash 缓存，补 TTL 和隐私回归。

### ITER-208 GOAL-1720 外部辅助识别订阅 hint
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：能力增强 / 解析链路 / 测试
- 目标：让外部辅助识别返回订阅候选判断，并在调试记录中可见，但不自动创建订阅。
- 改动范围：`ExternalReceiptAssistSuggestion` 新增 `subscriptionHint`；新增 `ExternalReceiptAssistSubscriptionHint` 结构；OpenAI-compatible codec 提示词要求模型返回订阅 hint，并兼容 camelCase / snake_case；`SmartReceiptParser` 外部 Assist trace 增加订阅 hint 摘要；离线回归新增请求提示和解码断言。
- 未改动范围：未自动写入订阅管理；未在入账后弹出订阅创建提示；未实现订阅倾向学习缓存或短期识别缓存；未修改 SQLite schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：外部模型可返回 `isSubscription / serviceName / billingCycle / confidence`；调试导出中的模型输出会显示 `subscriptionHint`；如果模型只返回订阅 hint 而没有有效商户增强，系统保留规则解析账单，只记录外部 Assist trace。
- 未完成内容：高置信订阅 hint 后的用户确认提示、商户 / 分类 / 订阅倾向学习缓存和短期结果缓存继续按 `GOAL-1730 / 1735` 推进。
- 测试情况：执行 `git diff --check`、`bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh` 和主 App iOS generic Debug build，结果 PASS。
- 风险与注意事项：订阅 hint 目前只是调试可见的候选判断，不进入正式订阅数据；实际自动提示前需要再设计误判处理、重复订阅检测和用户确认文案。
- 回滚方式：恢复 `ExternalReceiptAssistPayload.swift`、`SmartReceiptParser.swift`、`scripts/OfflineRegression.swift` 与本轮文档记录即可；本轮没有 schema 迁移。
- 结论：本轮完成，外部辅助识别已经具备订阅 hint 观测能力。
- 下一步建议：进入 `GOAL-1730`，先设计商户 / 分类 / 订阅倾向学习缓存边界，尤其明确不缓存原始 OCR 和敏感字段。

### ITER-207 GOAL-1715 账单详情创建订阅
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：能力增强 / UI / 测试
- 目标：在已有账单详情 / 编辑页提供显式创建订阅入口，让用户确认后把当前账单转为订阅管理项。
- 改动范围：`Subscription.draft(from:)` 新增账单转订阅草稿 helper；`TransactionEditorView` 已有账单模式新增“从这笔账单创建订阅”入口和确认 sheet；保存后调用 `LedgerStore.createSubscription`；三语本地化补齐入口、确认说明、重复提示和创建成功提示；离线回归新增草稿断言。
- 未改动范围：未在新增账单模式展示入口；未实现外部模型订阅 hint；未做缓存；未修改 SQLite schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：从已有账单进入编辑页后可打开订阅确认页；确认页预填商户、金额、最近扣费时间和默认月付周期，允许用户编辑周期、金额和下次扣费时间；保存后订阅进入订阅管理，不修改当前账单。
- 未完成内容：AI 订阅判断、入账后订阅提示和订阅倾向学习缓存继续按 `GOAL-1720 / 1730 / 1735` 推进。
- 测试情况：执行 `git diff --check`、三语 `Localizable.strings` plist lint、`bash scripts/run_offline_regression.sh` 和主 App iOS generic Debug build，结果 PASS。
- 风险与注意事项：重复同商户同周期订阅只提示不阻断，允许用户显式新增多条；后续如果要强去重，需要独立设计多方案 / 多服务名场景。
- 回滚方式：恢复 `Subscription`、`TransactionEditorView`、三语本地化、离线回归和版本文档本轮改动即可；本轮未新增 schema。
- 结论：本轮完成，账单详情到订阅管理的手动确认链路已打通。
- 下一步建议：进入 `GOAL-1720`，让外部辅助识别返回订阅 hint，并在入账后只做用户确认提示。

### ITER-206 GOAL-1710 订阅管理基础 CRUD
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：能力增强 / 数据迁移 / 测试
- 目标：让订阅管理从“自动识别和展示”升级为可维护的基础 CRUD，支持手动新增、编辑、暂停 / 恢复、取消和删除订阅。
- 改动范围：`Subscription` 新增 `active / paused / canceled` 状态；SQLite 订阅表新增 `status` 字段和迁移；订阅管理页新增手动创建、状态编辑、暂停 / 恢复 / 取消操作；暂停 / 取消订阅不再进入即将扣费、摘要统计和本地提醒；补齐三语文案和离线回归。
- 未改动范围：未实现账单详情一键创建订阅；未实现外部模型订阅判断；未做多账本订阅归属；未修改 Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：用户可从订阅管理页新增订阅，保存后进入现有 SQLite / 备份 / iCloud 配置推送链路；已有订阅可编辑状态；暂停 / 取消订阅降权展示，并从提醒和即将扣费统计中排除；旧备份或旧同步 payload 缺少 `status` 时默认兼容为 active。
- 未完成内容：账单转订阅、AI 订阅 hint、识别学习缓存仍按 `GOAL-1715 / 1720 / 1730` 后续推进。
- 测试情况：执行 `git diff --check`、三语 `Localizable.strings` plist lint、`bash scripts/run_offline_regression.sh` 和主 App iOS generic Debug build，结果 PASS。
- 风险与注意事项：订阅状态进入备份和配置同步 payload，旧版本 App 可读性依赖旧客户端的 Codable 兼容；建议多端都升级到 `v1.6.0` 后再长期混用暂停 / 取消状态。
- 回滚方式：恢复 `Subscription` / SQLite 订阅 schema / `SubscriptionListView` / `LedgerStore` / `NotificationService` / `InboxView` 本轮改动，并移除新增本地化、离线回归和文档记录；若已发布到测试设备，需要按数据迁移策略处理新增 `status` 字段。
- 结论：本轮完成，`GOAL-1710` 可作为 `v1.6.0` 第一批订阅管理能力基线。
- 下一步建议：进入 `GOAL-1715`，在账单详情里补“创建订阅”显式确认链路，再接 `GOAL-1720` 外部辅助识别订阅 hint。

### ITER-205 v1.6.0 版本计划落地
- 日期：2026-06-18
- 所属版本：v1.6.0
- 所属阶段：计划 / Draft
- 类型：文档 / 产品规划 / 本地化
- 目标：在 `v1.5.1` 提审前落下一条后续开发线，把订阅管理补强、AI 订阅判断、识别学习缓存、tvOS / visionOS 展示版和 Mac / 全平台 polish 纳入 `v1.6.0` 计划。
- 改动范围：新增 `versions/v1.6.0-plan.md`；更新中文 / 英文 README Roadmap；更新三语设置页“后续计划”文案；同步回填 CHANGELOG。
- 未改动范围：未修改 App 功能代码、Xcode project / workspace / scheme / target、Bundle ID、entitlements、iCloud / App Group、Xcode Cloud 脚本、App Store Connect 配置或多账本数据模型。
- 完成内容：`v1.6.0` 明确以订阅管理基础 CRUD、账单转订阅、外部模型订阅 hint、商户 / 分类 / 订阅倾向学习缓存、tvOS 只读看板、visionOS 展示版和 Mac / 多端 polish 为主要方向；多账本继续顺延。
- 未完成内容：`v1.6.0` 仅建立计划，未开始编码实现。
- 测试情况：执行三语 `Localizable.strings` plist lint，结果 PASS；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：设置页后续计划仅作为路线预告，不声明订阅 AI、tvOS 或 visionOS 已在当前版本可用。
- 回滚方式：删除 `versions/v1.6.0-plan.md`，恢复 README Roadmap 和三语 `settings.release_status.body`，移除本次 CHANGELOG / iteration log 记录。
- 结论：本轮完成，`v1.6.0` 后续开发线已落文档并与 App 内后续计划对齐。
- 下一步建议：`v1.5.1` 可继续按当前 release candidate 进入 ASC 审核；审核后按 `GOAL-1700` 冻结 `v1.6.0` 计划。

### ITER-204 外部辅助识别请求瘦身
- 日期：2026-06-18
- 所属版本：v1.5.1
- 所属阶段：正式发布
- 类型：性能优化 / 隐私 / 测试
- 目标：在保持外部辅助识别高频触发策略不变的前提下，降低单次外部 API 请求 payload 和输出 token 规模。
- 改动范围：`ExternalReceiptAssistPayloadBuilder` 默认截断上限从 1200 字符降到 800 字符；OpenAI-compatible prompt 不再要求模型返回 explanation；调试记录的外部辅助响应摘要不再展示 explanation；离线回归补充 payload 800 字符上限和默认不请求 explanation 的断言；同步回填 CHANGELOG。
- 未改动范围：未调整外部 Assist 触发频率、provider / model / endpoint 默认值、API key 存储、规则识别优先级、金额合并策略、UI 开关或 App Store Connect 配置。
- 完成内容：外部辅助识别仍会积极参与疑难商户识别，但每次请求更短，模型输出字段更少；兼容解码仍保留 explanation 字段，避免自定义 provider 或旧响应返回 explanation 时失败。
- 未完成内容：未接入 provider 级别流式输出、软超时、缓存或动态 payload 选线；这些可作为后续性能优化项。
- 测试情况：执行 `git diff --check`、`bash scripts/run_offline_regression.sh`、主 App generic iOS Debug build，结果 PASS。
- 风险与注意事项：payload 截断更短后，极长 OCR 文本中靠后的商户候选可能不进入外部请求；当前保留高频触发策略，后续可再做“金额/商户附近行优先保留”来降低此风险。
- 回滚方式：将默认 `maxCharacters` 恢复为 1200，并把 prompt / 调试摘要恢复为包含 explanation；移除新增回归断言和本次文档记录。
- 结论：本轮完成，外部辅助识别请求已瘦身，同时不降低触发频率。
- 下一步建议：真机继续观察外部 API 最近 / 平均 / P50 / P90 指标，重点看 P50 是否下降、P90 是否更稳定。

### ITER-203 设置页后续计划说明更新
- 日期：2026-06-18
- 所属版本：v1.5.1
- 所属阶段：正式发布
- 类型：文案 / 本地化
- 目标：将设置页“当前版本”和“后续计划”从偏内部开发 / 发布总结的口径更新为更适合 App 内展示的用户可读说明。
- 改动范围：更新简体中文、繁体中文、英文 `settings.version.body` 与 `settings.release_status.body` 本地化文案；同步回填 CHANGELOG。
- 未改动范围：未调整设置页布局、版本号、构建号、功能逻辑、App Store Connect 配置、发布计划或多账本实现。
- 完成内容：当前版本说明改为面向用户描述 iPhone / iPad / Apple Watch / Mac 快速记账、iCloud 同步、截图 / 小票识别、账单编辑保存和可选脱敏外部辅助识别；后续计划改为说明下一阶段继续打磨 Mac 与全平台体验、评估 tvOS / visionOS 展示版、优化截图 / 小票 / 复杂支付场景识别，并明确多账本后续版本单独规划。
- 未完成内容：未执行 Xcode 构建；本轮仅做本地化文案与文档记录。
- 测试情况：执行三语 `Localizable.strings` plist lint，结果 PASS；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：文案使用“评估”而非承诺 tvOS / visionOS 已落地，避免与当前发布能力不一致。
- 回滚方式：恢复三语 `settings.version.body` 与 `settings.release_status.body` 至上一版本，并移除本次 CHANGELOG / iteration log 记录。
- 结论：本轮完成，设置页版本说明已与 v1.5.1 当前能力和后续产品路线对齐。
- 下一步建议：提交前如需，可在真机或模拟器设置页快速复核三语展示。

### ITER-202 修复简体中文本地化 plist 解析失败
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：正式发布
- 类型：Bugfix / 本地化
- 目标：修复 Xcode Cloud validation failed: Couldn't parse property list because the input data was in an invalid format。
- 改动范围：修正简体中文 `settings.privacy.body` 中未转义英文双引号；同步回填 CHANGELOG。
- 未改动范围：未调整设置页功能、版本号、构建号、隐私行为或其他语言文案语义。
- 完成内容：将简体中文“外部辅助识别”的包裹符号改为中文引号，避免 `.strings` 文件被 plist parser 识别为非法字符串。
- 未完成内容：未执行完整 Xcode Cloud archive；需由云端流水线重新验证。
- 测试情况：执行 `plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings`，结果 PASS；执行全仓库 plist / entitlements / xcprivacy / strings / xcsettings lint，结果 PASS；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：本轮仅修复资源格式问题，不改变运行时逻辑；若 Xcode Cloud 仍失败，应继续检查构建产物中的其他 InfoPlist.strings 或生成式 Info.plist。
- 回滚方式：恢复本轮 `Localizable.strings`、CHANGELOG 和 iteration log 改动。
- 结论：本轮完成，已定位并修复导致 property list validation 失败的简体中文本地化格式错误。
- 下一步建议：重新触发 Xcode Cloud 构建，确认 validation 阶段通过。

### ITER-201 设置页当前版本说明更新
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：正式发布
- 类型：文案 / 本地化
- 目标：将设置页"当前版本"说明从旧的 v1.4.x 能力清单更新为当前 v1.5.1 正式发布版面向用户的版本说明，并同步修正设置页隐私策略文案。
- 改动范围：更新简体中文、繁体中文、英文 `settings.version.body` 本地化文案；修正三语 `settings.privacy.body`，补充 iCloud（CloudKit）同步说明和可选外部辅助识别的脱敏摘要行为；同步回填 CHANGELOG。
- 未改动范围：未调整 `MARKETING_VERSION`、构建号、设置页布局、后续计划文案或发布计划。
- 完成内容：当前版本说明改为概括 iPhone / iPad / Apple Watch / Mac 当前发布平台收口、iCloud 同步、截图与小票识别优化、账单编辑保存稳定性修复，以及可选脱敏外部辅助识别；隐私策略文案同步更正为准确描述 iCloud 同步和外部辅助行为。
- 未完成内容：未执行 Xcode 构建；本轮仅做本地化文案与文档记录。
- 测试情况：执行 `plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings`，结果 PASS；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：无。
- 回滚方式：恢复三语 `settings.version.body` 和 `settings.privacy.body` 至上一版本，并移除本次 CHANGELOG / iteration log 记录。
- 结论：本轮完成，设置页"当前版本"说明已同步到 v1.5.1 正式发布口径，隐私策略文案已与实际功能对齐。
- 下一步建议：发布前统一复核 App Store 文案是否一致。

### ITER-200 v1.5.1 仓库侧收尾
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：发布收口 / Release Candidate
- 类型：文档 / 治理 / 发布收口
- 目标：将 `v1.5.1` 从“开发中”收口为 release candidate，明确当前平台完成范围、App Preview v001 状态、Xcode Cloud / TestFlight / ASC 回填结果、顺延事项和保留风险。
- 改动范围：
  - `versions/v1.5.1-plan.md`：更新文档状态、版本定位、GOAL 队列、门禁结论、App Preview v001 验证记录和当前结论。
  - `README.md`：将 Roadmap 中 `v1.5.1` 状态更新为“收尾完成”，并改写主要内容摘要。
  - `CHANGELOG.md`：新增 `v1.5.1` release candidate 收口记录和 Hyperframes App Preview v001 记录。
  - `process/iteration-log.md`：新增本条迭代日志。
- 未改动范围：未修改 App 代码、Xcode project / workspace / scheme / target、Bundle ID、`DEVELOPMENT_TEAM`、App Group、iCloud Container、entitlements、Xcode Cloud 脚本、App Store Connect 配置、截图管线脚本或 Hyperframes 成片。
- 完成内容：`v1.5.1` 已明确为 App Store `1.4.0` 的 TestFlight / 提审候选基线；当前发布平台范围收口为 iPhone / iPad / Apple Watch / Mac Catalyst；最低系统需求优化、识别链路 Core 化、外部辅助识别试点、账单编辑保存稳定性、iCloud 同步性能修复、当前平台截图与 App Preview v001 均已纳入完成范围。根据用户回填，Xcode Cloud archive、TestFlight 分发和 ASC 素材上传已完成。
- 未完成内容：Mac 端素材尚未做 ASC 侧实测 / 预览确认，作为非阻断风险保留；tvOS / visionOS 产品代码、截图和平台发布准备顺延到 `v1.6.0`；多账本继续顺延。
- 测试情况：文档收口，无新增构建；沿用 `versions/v1.5.1-plan.md` 中已记录的本地 smoke、iOS generic build、Mac Catalyst build、截图导出、Hyperframes render 和 ffprobe 验证结果。
- 风险与注意事项：`收尾完成` 不等于 App Store 已上架；Xcode Cloud archive、TestFlight 分发和 ASC 素材上传虽已完成，但 Mac 端素材未做 ASC 侧实测，如果本次提交包含 Mac 平台展示素材，仍建议在提交审核前单独预览确认。
- 回滚方式：若后续发现 blocker，可将 `versions/v1.5.1-plan.md` 文档状态改回“开发中 / 阻断”，把 README Roadmap 状态回退，并在 CHANGELOG 增加 blocker 记录。
- 结论：本轮完成，`v1.5.1` 可以作为当前 App Store `1.4.0` 提审候选基线；Xcode Cloud archive、TestFlight 分发和 ASC 素材上传已完成。
- 下一步建议：提交审核前如包含 Mac 平台素材，单独预览 Mac 展示素材；提审完成后再创建对应 tag 或 release 记录。

### ITER-199 App Store 截图视觉回归修正
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：营销素材 / 发布收口
- 类型：Bugfix / 截图管线 / UI Fixture
- 目标：修复 App Store 截图升级后 iPhone 画面过小、Apple Watch 标题与截图内容不匹配、Watch 输出仍像旧截图的问题。
- 改动范围：
  - `render_marketing.py`：放大 iPhone store 渲染框，改为顶部 cover 裁切，减少画面过小和下方留白。
  - `export_mac.sh` / `render_marketing.py`：Mac 截图改为按 AutoLedger 窗口 ID 捕获，并在营销渲染时裁掉系统窗口阴影，避免屏幕上重叠窗口污染截图。
  - `ScreenshotModeConfig` / `ScreenshotHostView`：新增 `watch_ecosystem` screenshot-only 静态场景，用虚构 Watch + iPhone 同步画面承接第三张 iPhone 截图。
  - `WatchScreenshotModeConfig` / `WatchScreenshotHostView`：将旧 `watch_confirm` 替换为 `watch_complication`，新增表盘复杂功能静态预览，并刷新 Watch 虚构演示数据。
  - `screenshots.json` / 截图管线 README / audit 文档：同步 iPhone 与 Watch scene 映射。
- 未改动范围：未修改 App Store Connect、证书、profile、entitlements、Bundle ID、DEVELOPMENT_TEAM、Xcode Cloud 脚本、真实 OCR / LLM / iCloud / 相册 / 相机 / 麦克风链路，也未引入真实支付截图或用户账本数据。
- 完成内容：iPhone 首图和第三张导出图已目视确认画面更大；第三张不再是普通 iPhone 页面，而是 Watch 生态静态展示；Watch `zh-Hans` 导出已生成 `02_watch_complication`；`zh-Hant` / `en` 本地化截图已补齐到 iPhone 6 张、iPad 5 张、Mac 4 张、Watch 4 张；旧 iPhone / Watch 生成残留已从 output 目录清理；preview.html 已重建。
- 未完成内容：仍需人工最终目视复核全平台 store 图，尤其是真实 App Store 上传前的多语言输出；真实表盘复杂功能截图仍可作为人工 fallback。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`python3 -m json.tool tools/appstore-screenshots/config/screenshots.json`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --locale zh-Hant --locale en`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale en`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --mac-only --locale zh-Hant`
- 风险与注意事项：`watch_ecosystem` 和 `watch_complication` 均为 screenshot-only 静态 fixture，不触发 WatchConnectivity、真实数据库、iCloud、OCR、LLM、相册、相机或麦克风；当前修正优先保证 App Store 截图表达一致性，不代表真实 Watch 表盘系统截图。
- 回滚方式：回退 `watch_ecosystem` / `watch_complication` scene、`screenshots.json` 映射和 iPhone 渲染框调整，即可恢复 ITER-198 的截图输出。
- 结论：本轮完成，iPhone 与 Watch 截图的主要视觉回归已修复，可继续进行全平台目视复核。
- 下一步建议：打开 `tools/appstore-screenshots/output/preview.html` 逐张复核 zh-Hans 输出；确认后再补跑 zh-Hant / en 导出。

### ITER-198 App Store 营销素材截图管线升级
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：营销素材 / 发布收口
- 类型：文档 / 截图管线 / 配置 / UI Fixture
- 目标：在现有 `tools/appstore-screenshots` 管线基础上升级 App Store 截图策略、Watch 文案和 App Preview / Hyperframes 制作资料，不另起平行 marketing 目录。
- 改动范围：
  - `tools/appstore-screenshots/config/screenshots.json`：更新 iPhone / iPad / Mac / Watch 三语截图文案和 iPhone 截图顺序。
  - `ScreenshotModeConfig` / `ScreenshotHostView`：新增 `ocr_bill` / `voice_entry` screenshot-only 静态场景，更新截图 fixture 为虚构演示账单。
  - `tools/appstore-screenshots/docs/APPSTORE_SCREENSHOT_PIPELINE_AUDIT.md`：记录当前平台、locale、scene、自动化能力和人工项。
  - `tools/appstore-screenshots/app-preview/`：新增 App Preview / Hyperframes README、中文脚本、brief、shotlist 和导出要求。
  - `tools/appstore-screenshots/README.md`：补充 App Preview keyframe 说明、推荐导出命令、上传顺序和 Watch complication fallback。
- 未改动范围：未修改 App Store Connect、证书、profile、entitlements、Bundle ID、DEVELOPMENT_TEAM、Xcode Cloud 脚本、真实 OCR / LLM / iCloud / 相册 / 相机 / 麦克风链路，也未引入真实支付截图或用户账本数据。
- 完成内容：
  - iPhone 截图收敛为 6 张：截图识别、语音记账、Watch 生态、月报、iCloud 同步、快捷指令导入。
  - Watch 截图保留 4 张并更新为新版 Watch UI 方向；表盘复杂功能自动截图仍标记为人工 fallback。
  - iPad / Mac 常规截图能力保留，文案转向大屏账本、桌面整理和多设备同步。
  - Hyperframes 所需制作资料已放入现有工具目录，可使用截图管线输出作为关键帧。
  - 截图 fixture 覆盖午饭 28 元、Demo Coffee 18 元、City Metro 4 元、Example Market 86.5 元、Sample Cinema 45 元、Mobile Carrier 50 元、Bookstore 39 元、Delivery Dinner 32 元等虚构演示数据。
- 未完成内容：未生成官方 App Preview 视频；未上传 ASC；未人工复核全部平台截图最终视觉效果；Watch 真表盘复杂功能截图仍需人工捕获。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`python3 -m json.tool tools/appstore-screenshots/config/screenshots.json`
  - PASS：截图管线敏感关键词检查未命中 API key / private key / `ghp_` / 证书类文件名 / 真实支付等风险词。
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans`
- 风险与注意事项：`ocr_bill` / `voice_entry` 是静态截图 fixture，不代表自动读取相册、启动 OCR 或打开麦克风；Mac `mac_reports` 复用已有 workspace reports 映射，iPhone-only 导出时会提示 Mac raw 截图尚未重新生成，后续执行 `--mac-only` 后即可补齐；全部平台最终上传前仍需人工目视确认。
- 回滚方式：回退 `screenshots.json`、`ocr_bill` / `voice_entry` scene、App Preview 文档和 README / audit 记录即可恢复上一轮截图管线状态。
- 结论：本轮完成，现有截图导出脚本保持可用，iPhone `zh-Hans` 最小导出已通过。
- 下一步建议：先执行 `export.sh --ios-only --locale zh-Hans` 生成 iPhone 首批截图，再人工打开 `output/preview.html` 复核排版。

### ITER-197 GOAL-1608G / GOAL-1611 地铁规则短路与外部 API 调试观测
- 日期：2026-06-17
- 所属版本：v1.5.1
- 所属阶段：识别链路回归 / 调试观测
- 类型：Bugfix / 测试 / UI
- 目标：修复地铁 / 公交储值卡计费文本在快捷指令路径下仍进入外部大模型辅助的问题，并让调试页能观察外部 API 调用耗时。
- 改动范围：
  - `SmartReceiptParser`：当规则解析已明确得到地铁 / 公交路线商户和出行分类时，直接返回规则结果，跳过外部辅助识别。
  - `DebugView`：新增外部 API 性能统计卡片；优化 provider 显示名和耗时格式；移除调试记录卡片右上角重复阶段胶囊。
  - `OfflineRegression.swift` 与 Golden case：增加脱敏地铁通知样式回归，覆盖路线、金额、余额行和社媒噪声混排。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本轮验证结果。
- 未改动范围：未修改 OCRService、SQLite schema、CloudKit schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或外部 provider 默认开关。
- 完成内容：
  - 快捷指令和主 App 识别路径在明确地铁 / 公交计费样式下都会优先采用纯规则解析，不再为了商户候选调用 DeepSeek / Qwen / OpenAI。
  - 调试页可以看到外部 API 最近一次耗时、平均耗时、P50、P90 和样本数；单条导出使用 DeepSeek / Qwen / OpenAI 短名称，避免 `external_deepseek` 折行。
  - 调试记录卡片去掉右上角“已入账”胶囊，减少重复状态展示。
- 未完成内容：仍需真机用快捷指令或通知中心地铁样式重新验证，确认调试记录显示纯规则解析且不出现外部模型链路；外部 API 性能优化策略仍需基于更多真实耗时样本再判断。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：当前短路条件只针对已经被规则解析为出行分类且商户以 `地铁：` / `公交：` 开头的确定性结果，避免扩大到普通城市卡、余额、交通资讯或含噪声截图；如果后续出现其他明确交通票据形态，应继续在规则层补专用识别，而不是放宽外部辅助短路条件。
- 回滚方式：回退 `SmartReceiptParser` 的规则短路 helper、`DebugView` 外部 API 统计展示和本轮新增脱敏回归样例即可恢复到本轮前状态。
- 结论：本轮完成，地铁 / 公交储值卡计费在代码层已经不会被外部模型覆盖；可进入真机复测。
- 下一步建议：真机跑一次同类快捷指令样例，确认调试记录为纯规则解析；若外部 API 平均耗时仍偏高，再基于统计卡决定是否增加超时、缓存或更严格的触发门槛。

### ITER-196 GOAL-1606 本地 smoke 收口
- 日期：2026-06-16
- 所属版本：v1.5.1
- 所属阶段：最终 smoke / 发布收口
- 类型：测试 / Bugfix / 文档
- 目标：执行 `v1.5.1` 当前发布平台的本地 smoke，覆盖命令级回归、iOS / Mac Catalyst 构建和 iPhone / iPad / Mac / Watch 截图管线，并回填最终收口状态。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/PaymentAmountExtractor.swift`：将中文支付详情里的 `金额` 标签视为可靠已支付金额，避免支付宝详情样例被误标记为需复核。
  - `scripts/run_golden_regression.sh`：补齐 `PaymentAmountExtractor`、`MerchantResolver`、`CategoryResolver` 编译清单。
  - `versions/v1.5.1-plan.md`、`versions/v1.5.1-regression-baseline.md`、`CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1606` 本地 smoke 结果和剩余人工项。
- 未改动范围：未修改 Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、CloudKit schema、Xcode Cloud 脚本、ASC 设置或发布 tag。
- 完成内容：
  - 修复 Golden 回归脚本在 Core 解析模块拆分后漏编的问题。
  - 修复中文 `金额：￥xx` 支付详情在 Core 金额提取中被视为 approximate 的问题。
  - 完成本地命令级回归、iOS generic build、Mac Catalyst build 和当前四个平台 `zh-Hans` 截图导出烟测。
- 未完成内容：Xcode Cloud 验证构建、TestFlight 安装 smoke、ASC 隐私 / 审核说明 / 截图最终上传检查仍需人工执行。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ipad-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --mac-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans`
- 风险与注意事项：Mac Catalyst 第一次与 iOS 构建并发执行时出现 DerivedData `build.db` lock，单独重跑后通过；该问题属于本地并发构建环境，不是源码或 signing 失败。截图烟测只覆盖 `zh-Hans`，正式提交前仍需按 ASC 需要复核全语言、全尺寸和网页上传状态。
- 回滚方式：回退 `PaymentAmountExtractor` 的 `金额` 标签识别、`run_golden_regression.sh` 编译清单补充和本轮文档记录即可恢复到本轮前状态。
- 结论：`GOAL-1606` 本地 smoke 已完成；当前无本地命令级 blocker，版本可进入 Xcode Cloud / TestFlight / ASC 人工收口。
- 下一步建议：推送当前分支，触发 Xcode Cloud 验证构建；通过后在 TestFlight 执行 iPhone / iPad / Watch / Mac 安装 smoke，并完成 ASC 隐私、审核说明和截图最终检查。

### ITER-195 v1.5.1 发布边界收口
- 日期：2026-06-16
- 所属版本：v1.5.1
- 所属阶段：最终 smoke / 发布边界
- 类型：文档 / 治理
- 目标：明确 tvOS / visionOS 是否继续纳入 `v1.5.1` 落代码范围，并把后续推进重心收敛到当前发布平台最终 smoke。
- 改动范围：
  - `versions/v1.5.1-plan.md`：将 tvOS / visionOS 产品代码、截图和发布准备顺延到 `v1.6.0`；`GOAL-1603 / GOAL-1604` 标记为已顺延，`GOAL-1605` 调整为当前发布平台截图复核，`GOAL-1606` 标记为待执行。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本次发布边界决策。
- 未改动范围：未修改业务代码、target、Bundle ID、signing、entitlements、Xcode project / workspace / scheme、CloudKit、截图脚本或 Xcode Cloud 脚本。
- 完成内容：`v1.5.1` 不再继续扩 tvOS / visionOS 产品代码，当前发布收口范围明确为 iPhone / iPad / Apple Watch / Mac Catalyst。
- 未完成内容：尚未执行 `GOAL-1606` 最终 smoke、Xcode Cloud 和 ASC 收口。
- 测试情况：文档边界调整，无代码构建；本轮未新增命令验证。
- 风险与注意事项：tvOS / visionOS target 和设计评估仍保留，但不应在 `v1.5.1` 发布判断中被当作 blocker；后续 `v1.6.0` 需要重新建立平台实现与截图门禁。
- 回滚方式：如决定重新纳入 tvOS / visionOS，可回退本轮文档改动并恢复 `GOAL-1603 / GOAL-1604 / GOAL-1605` 为规划中。
- 结论：本轮完成，`v1.5.1` 进入当前发布平台最终 smoke 收口阶段。
- 下一步建议：执行 `GOAL-1606`，先跑 iOS / iPad / Mac 手工 smoke，再跑 Xcode Cloud / TestFlight。

### ITER-194 v1.5.1 当前平台回归基线
- 日期：2026-06-16
- 所属版本：v1.5.1
- 所属阶段：最终 smoke / 当前平台收口
- 类型：测试 / 文档 / 治理
- 目标：确认 iOS / iPad 当前是否仍有未落地内容、Mac Catalyst 当前测试覆盖到什么程度，并补齐发布前可重复执行的回归用例清单。
- 改动范围：
  - `versions/v1.5.1-regression-baseline.md`：新增 iOS / iPad / Mac Catalyst 当前落地状态、命令级回归、自动 / 离线覆盖、手工 smoke 用例和当前执行记录。
  - `versions/v1.5.1-plan.md`：增加回归基线引用和当前平台回归结果说明。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本次回归治理更新。
- 未改动范围：未修改业务代码、UI、SQLite schema、CloudKit、Bundle ID、signing、entitlements、Xcode project / workspace / scheme / target 或 Xcode Cloud 脚本。
- 完成内容：明确 iOS / iPad / Mac 不是缺主线代码，而是缺最终端到端 smoke 记录；Mac Catalyst 当前已有 build、Core 离线回归和截图导出基线，但没有自动 UI 测试，发布前需要执行菜单、快捷键、拖拽、CSV / JSON、表格批量编辑、重复检查和 iCloud 同步手工回归。
- 未完成内容：未执行 Mac UI 手工 smoke；未新增 UI 自动化测试 target。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
  - 已复用本轮前序验证：`git diff --check`、`bash scripts/run_offline_regression.sh`、iOS generic build 均已在同一工作区通过。
- 风险与注意事项：Mac Catalyst build 通过不等于菜单 / 拖拽 / 文件导入等桌面交互已通过；这些仍必须由手工 smoke 或后续 UI 自动化覆盖。
- 回滚方式：回退 `versions/v1.5.1-regression-baseline.md` 及本轮文档引用即可。
- 结论：本轮完成，v1.5.1 当前平台发布前测试用例已经成型；下一步应按该基线执行 iOS / iPad / Mac 手工 smoke。
- 下一步建议：先跑 `MAC-001` 到 `MAC-011`，再统一执行 iOS / iPad 真机 smoke 和 Xcode Cloud 验证构建。

### ITER-193 GOAL-1608G 通知中心地铁样式规则短路
- 日期：2026-06-16
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：Bugfix / 规则解析 / 可观测性
- 目标：让通知中心样式的地铁储值消费文本在 App 解析入口直接走纯规则链路，避免外部辅助识别把商户改成泛化运营主体；同时补齐快捷指令调试记录中的 provider 元数据。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerTextInterpreter.swift`：对 Core 返回的 `transit_stored_value` 结果做硬前置，直接构造规则 `SmartResult`，短路 DeepSeek / Qwen / OpenAI 等外部辅助分支。
  - `AutoLedger/AutoLedger/Domain/Services/QuickLedgerIntent.swift`：快捷指令调试记录写入 `llmProvider` 与 `llmLatencyMs`。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增通知中心地铁样式脱敏回归，并让外部 Assist stub 在开启时返回错误商户以证明规则短路生效。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：记录本次修复。
- 未改动范围：未修改 UI、SQLite schema、外部 API key 存储、默认开关、CloudKit 同步逻辑、Bundle ID、signing、entitlements、Xcode project / workspace / scheme / target 或 Xcode Cloud 脚本。
- 完成内容：通知中心“储值消费成功 + 城市卡 + 地铁：CN¥金额 + 路线行 + 步行 / 游戏 / 天气噪声”文本会解析为 `地铁：示例站A→示例站B`、金额 `2.70`、分类 `transport`，并且在外部 Assist 开启时仍不会进入模型分支；快捷指令外部模型调试记录后续可显示 provider 和耗时。
- 未完成内容：未做真机重新识别验证；需要用户用同类地铁通知截图 / 快捷指令文本再跑一次确认调试记录为纯规则解析。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：本次规则只针对明确 `地铁：` / `公交：` 标签和金额 / 路线组合，避免泛化吞掉普通支付截图；调试记录仍不写 API key、图片、真实截图或未脱敏完整 secret。
- 回滚方式：回退 `LedgerTextInterpreter.transitStoredValueSmartResult` 前置逻辑、`QuickLedgerIntent.writeDebugEvent` provider 字段补齐，以及本轮新增离线回归即可恢复旧行为。
- 结论：本轮完成，地铁储值消费已从 App 入口短路外部模型，符合“特殊清晰样式不需要 LLM”的链路要求。
- 下一步建议：真机重新导入同类地铁通知样式，确认解析模式为纯规则解析；若仍看到模型链路，继续检查 OCR 清洗后文本是否保留 `地铁：CN¥金额` 和路线行。

### ITER-192 GOAL-1611 外部调试记录与 iCloud 同步卡顿修复
- 日期：2026-06-15
- 所属版本：v1.5.1
- 所属阶段：Phase D / 当前主线平台稳定收口
- 类型：Bugfix / 可观测性 / 性能
- 目标：补齐外部辅助识别是否命中、provider / model / 结果摘要等调试记录，并缓解 iCloud 同步大量账单时 App UI 无响应卡顿。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/SmartReceiptParser.swift`：将模型 trace 改为通用 provider id / display name；外部辅助命中时记录脱敏请求摘要、商户候选、分类提示、置信度、解释和耗时。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：调试记录改用通用 provider id；CloudKit 拉取写入本地时改用 SQLite 批量 apply summary。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/SyncMetadata.swift`、`SQLiteTransactionStore.swift`：新增 `TransactionSyncApplySummary` 与批量 `applyRemoteSyncRecords`，避免逐条远端记录触发全表读取。
  - `AutoLedger/AutoLedger/Features/Settings/DebugView.swift`、`FeedbackBundleBuilder.swift`：调试卡片、单条复制、整页导出和反馈 trace 显示 provider、耗时、置信度与规则兜底信息。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：补齐批量远端同步回归与 SmartReceiptParser stub 字段。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：记录本次修复。
- 未改动范围：未修改 CloudKit schema、iCloud Container、Bundle ID、signing、entitlements、Xcode Cloud 脚本、外部 API key 存储策略或默认开关策略；未把 SQLite store 迁移到跨线程后台 actor。
- 完成内容：外部辅助识别命中后，单条调试记录可看到 provider / model / 脱敏请求摘要 / 模型候选 / 置信度 / 耗时；iCloud 拉取写库从近似 N² 的逐条全表扫描改为一次建索引后批量 apply，降低 TestFlight / 真机同步时 UI 卡死风险。
- 未完成内容：未完成 Instruments trace 对比；如果真机大量同步仍卡顿，下一步应把 SQLite 同步写入迁到明确串行后台执行器，并审计 `refreshFromStore()` 的全量刷新频率。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：外部模型调试记录只写脱敏 payload，不写 API key、图片或完整未脱敏原始 OCR；批量 apply 仍在当前同步路径内执行，已移除最明显的重复全表读取，但极端大账本仍建议后续继续后台化。
- 回滚方式：回退 `SmartReceiptParser.LLMTrace` 通用 provider 改动、DebugView / FeedbackBundleBuilder 展示改动，以及 `SQLiteTransactionStore.applyRemoteSyncRecords` 和 `LedgerStore.pullRemoteLedgerChanges` 调用切换即可恢复旧行为。
- 结论：本轮完成，外部模型识别链路已经可从调试记录判断是否命中；iCloud 同步写库卡顿的主要 N² 根因已修复。
- 下一步建议：TestFlight 中部署 Production CloudKit schema 后，使用 300 条左右账本做一次强制刷新，观察 UI 响应；同时复制一条外部辅助命中的调试记录确认日志内容符合预期。

### ITER-191 GOAL-1608F 地铁规则解析前置
- 日期：2026-06-15
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：Bugfix / 规则解析
- 目标：将地铁 / 公交储值卡 OCR 形态放到识别链路最前面，纯规则优先输出路线商户、车费金额和出行分类。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：在通用 bill relevance、金额提取和商户 resolver 前增加地铁 / 公交储值卡专用规则。
  - `AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift`：在 App 层规则解析入口最前面增加同类地铁 / 公交解析，覆盖快捷指令纯规则兜底路径。
  - `scripts/OfflineRegression.swift`：新增脱敏回归，覆盖城市卡名称、`地铁：CN¥金额`、路线行和后续社媒噪声混排场景。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：记录本次修复。
- 未改动范围：未修改 UI、SQLite schema、CloudKit / iCloud 同步、外部 API、LLM 合并策略、Bundle ID、signing、entitlements 或 Xcode Cloud 脚本。
- 完成内容：Core 与 App 规则入口均会优先识别 `地铁：CN¥X.XX` / `公交：¥X.XX` 及后续路线行，跳过余额、城市卡、推荐、评论、社媒数字等噪声；回归样例使用虚构站点和虚构社媒文本，不保存真实路线、截图或 OCR 原文。
- 未完成内容：未做真实图片 OCR 端到端真机回归；如后续出现无冒号、站点换行更碎或缺少路线行的新形态，需要继续补充样例。
- 测试情况：
  - PASS：先新增 Core 失败回归，确认旧逻辑会输出城市卡名称并取错金额 / 分类。
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：规则只在明确 `地铁：` / `公交：` 标签命中时触发，避免误伤普通商户；样例已脱敏，未提交用户真实路线或社媒内容。
- 回滚方式：回退 `LedgerTextInterpreterCore.swift` 和 `ReceiptParser.swift` 中新增的 transit stored-value 规则与 `OfflineRegression.swift` 对应回归即可。
- 结论：地铁 / 公交储值卡识别已前置到纯规则链路，快捷指令和 App 规则解析路径都应优先输出路线账单。
- 下一步建议：真机用同类地铁截图重新跑快捷指令，确认商户为路线、金额为车费、分类为出行。

### ITER-190 GOAL-1610C 真机编辑保存验证
- 日期：2026-06-13
- 所属版本：v1.5.1
- 所属阶段：Phase D2 / 账单编辑保存链路稳定性
- 类型：真机验证 / Bugfix 收口
- 目标：记录账单编辑保存链路的真机回填结果，并收口 `GOAL-1610` 功能侧状态。
- 改动范围：
  - `versions/v1.5.1-plan.md`：新增 `GOAL-1610C` 真机验证结果，将 `GOAL-1610` 功能侧标记为已完成。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录真机回填结果。
- 未改动范围：未修改 App 代码、SQLite schema、Widget、iCloud、CloudKit、外部辅助识别、Bundle ID、signing、entitlements 或 Xcode Cloud 脚本。
- 完成内容：根据用户真机回填，编辑保存基本测试已通过，保存按钮状态、保存后展示一致性和商户别名确认式学习功能侧没有继续出现阻断问题。
- 未完成内容：若后续真实使用仍出现卡顿或保存不一致，再按 `TransactionEditorView -> LedgerStore.updateTransaction -> SQLiteTransactionStore.update -> Widget / Backup / CloudKit` 分段继续定位。
- 测试情况：
  - PASS：用户真机基本测试通过，编辑保存没有继续出现问题。
  - PASS：本轮为文档回填，未新增代码。
- 风险与注意事项：本记录不保存真实账单内容、商户名、金额或截图；商户别名确认式学习仍建议在更多真实识别样本中继续观察。
- 回滚方式：回退本轮文档回填即可将 `GOAL-1610` 状态恢复为进行中；不影响代码。
- 结论：`GOAL-1610` 功能侧已完成，可转入版本后续平台与发布收口。
- 下一步建议：进入 tvOS / visionOS 是否本版落代码的最终取舍，或继续执行最终 smoke 前的发布检查清单。

### ITER-189 GOAL-1609G 真机 API 调用验证
- 日期：2026-06-13
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：真机验证 / 能力收口
- 目标：记录外部辅助识别真实 provider 调用的真机验证结果，并收口 `GOAL-1609` 功能侧状态。
- 改动范围：
  - `versions/v1.5.1-plan.md`：新增 `GOAL-1609G` 真机验证结果，将 `GOAL-1609` 功能侧标记为已完成，并补充发布前隐私 / Pro gate 检查保留项。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录真机回填结果。
- 未改动范围：未修改 App 代码、API key 存储、provider endpoint、模型名、本地规则主链路、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或 Xcode Cloud 脚本。
- 完成内容：根据用户真机回填，外部 provider 基本测试已通过且已看到真实 API 调用；provider / model / endpoint / Keychain API key / OpenAI-compatible request 主链路具备真机闭环证据。
- 未完成内容：发布前仍需复核隐私政策、App Store 审核说明和 Pro gate 取舍；后续仍可继续观察不同真实截图上的商户候选质量。
- 测试情况：
  - PASS：用户真机基本测试通过，已看到外部 API 调用。
  - PASS：本轮为文档回填，未新增代码。
- 风险与注意事项：本记录不保存 API key、provider 响应原文、请求日志、真实账单 OCR 或截图内容；外部 API 能力仍保持默认关闭，用户需主动开启并自行配置 key。
- 回滚方式：回退本轮文档回填即可将 `GOAL-1609` 状态恢复为进行中；不影响代码。
- 结论：`GOAL-1609` 功能侧已完成，可从识别链路外部辅助试点转入版本发布前人工检查。
- 下一步建议：继续处理 `GOAL-1610` 真机编辑保存链路收口，或进入 tvOS / visionOS 是否本版落代码的最终取舍。

### ITER-188 GOAL-1609F Provider 测试入口
- 日期：2026-06-13
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：能力增强 / 真机验证入口
- 目标：为外部辅助识别设置页增加一个不读取真实账本数据的 provider 测试入口，方便真机填写 DeepSeek / Qwen / OpenAI API key 后先验证 endpoint、model、Keychain 和响应解码链路。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Settings/ExternalReceiptAssistSettingsView.swift`：新增“测试 Provider”按钮和测试状态；测试会保存当前 provider 配置，读取运行时 API key，并发送虚构脱敏样例请求。
  - `AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings`、`AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`、`AutoLedger/AutoLedger/en.lproj/Localizable.strings`：补齐测试按钮与测试状态三语文案。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果，并将 `GOAL-1600` 状态修正为已完成。
- 未改动范围：未默认开启外部辅助识别，未接 Pro / IAP gate，未修改本地规则主链路、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或 Xcode Cloud 脚本。
- 完成内容：设置页可用虚构样例 `Demo Coffee / 支付金额 12.34` 调用当前 provider；测试复用真实 `ExternalReceiptAssistClient`、Keychain API key、OpenAI-compatible request codec 和 response decoder；成功 / 无候选 / 缺 Key / 失败均有用户提示，不输出 API key、响应原文或用户数据。
- 未完成内容：尚未用真实 DeepSeek API key 在真机点按测试；尚未补正式隐私政策 / App Store 文案或 Pro gate。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：测试按钮会产生一次真实外部 API 调用和可能的 provider 计费；请求内容为虚构样例，不包含真实账单。若用户曾保存旧模型或自定义 endpoint，测试会按当前设置页保存后的配置发送。
- 回滚方式：回退提交 `feat: add external assist provider test` 及本轮文档回填即可移除测试入口，外部辅助主链路和本地规则识别不受影响。
- 结论：`GOAL-1609F` 已完成命令级验证，下一步可以在真机用 DeepSeek API key 做外部辅助设置页测试和真实截图端到端测试。
- 下一步建议：真机进入设置 -> 外部辅助识别，选择 DeepSeek，确认模型为 `deepseek-v4-flash`，保存 API key 后先点“测试 Provider”；通过后再用支付成功截图验证商户候选增强。

### ITER-187 GOAL-1609E DeepSeek 默认模型调整
- 日期：2026-06-13
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：能力增强 / 配置修正
- 目标：将 DeepSeek provider 默认模型从兼容别名切换到当前正式 V4 Flash 模型，避免新用户真机测试时落到即将退役的模型名。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/ExternalReceiptAssistPayload.swift`：DeepSeek 默认模型改为 `deepseek-v4-flash`。
  - `AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings`、`AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`、`AutoLedger/AutoLedger/en.lproj/Localizable.strings`：同步设置页模型 placeholder。
  - `scripts/OfflineRegression.swift`：DeepSeek provider preset 回归改为断言 `deepseek-v4-flash`。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 endpoint、API key 存储、外部辅助默认关闭状态、本地规则主链路、SQLite schema、Bundle ID、signing、entitlements 或 CloudKit 配置。
- 完成内容：DeepSeek 新配置默认走 `deepseek-v4-flash`，用户仍可在设置页手动覆盖模型名。
- 未完成内容：尚未用真实 DeepSeek API key 做真机端到端网络识别。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
- 风险与注意事项：已经保存过旧模型名的用户本地 UserDefaults 可能继续保留自定义模型值；真机测试时如曾保存 `deepseek-chat`，需要在设置页重新选择 DeepSeek 或手动改为 `deepseek-v4-flash`。
- 回滚方式：回退提交 `fix: update deepseek default model` 及本轮文档回填即可恢复 `deepseek-chat` 默认值。
- 结论：DeepSeek provider 默认模型已对齐当前官方 V4 Flash 模型。
- 下一步建议：真机填写 API key 后，先用支付宝支付成功页样本测试商户候选增强链路。

### ITER-186 GOAL-1609E 真实外部 provider 接入
- 日期：2026-06-12
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：能力增强 / 受控外部辅助识别
- 目标：把外部辅助识别从自定义 endpoint skeleton 推进到真实 OpenAI-compatible provider，优先支持 DeepSeek，同时预留 Qwen、OpenAI 和 Custom 选择。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/ExternalReceiptAssistPayload.swift`：新增 `ExternalReceiptAssistProvider` 与 `ExternalReceiptAssistOpenAICompatibleCodec`，固定 provider preset、生成 chat/completions 请求并解码 `choices[0].message.content`。
  - `AutoLedger/AutoLedger/Domain/Services/ExternalReceiptAssistClient.swift`：外部辅助请求改为 OpenAI-compatible body，保留 Bearer API key、Keychain 优先和默认关闭 gate。
  - `AutoLedger/AutoLedger/Features/Settings/ExternalReceiptAssistSettingsView.swift`：新增 provider 下拉、模型输入和 endpoint 输入，选择 provider 时自动填充默认 endpoint / model。
  - `AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings`、`AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`、`AutoLedger/AutoLedger/en.lproj/Localizable.strings`：补齐三语设置页文案。
  - `scripts/OfflineRegression.swift`：新增 provider preset 和 OpenAI-compatible codec 回归。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未默认开启外部辅助识别，未接 Pro / IAP gate，未修改本地规则主链路、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或 Xcode Cloud 脚本。
- 完成内容：设置页现在可选择 DeepSeek / Qwen / OpenAI / Custom；DeepSeek 默认 endpoint 为 `https://api.deepseek.com/chat/completions`，默认模型为 `deepseek-v4-flash`；Qwen 和 OpenAI 也有默认 endpoint / model；用户仍可手动覆盖模型和 endpoint。真实请求只发送脱敏 payload，并要求模型只返回商户候选、分类提示、置信度和解释。
- 未完成内容：尚未用真实 DeepSeek API key 在真机跑通端到端网络识别；尚未接 Pro gate、正式隐私政策文案或 App Store 审核说明。
- 测试情况：
  - RED：新增 provider / codec 回归后，`bash scripts/run_offline_regression.sh` 先因缺少新类型失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：外部模型服务质量、可用性和计费不可由 App 保证；当前能力仍应保持默认关闭，用户需自行保存 API key 并理解会向第三方发送脱敏文本。模型默认值后续可能需要跟随 provider 官方推荐更新，但 endpoint / model 均可在设置页手动覆盖。
- 回滚方式：回退提交 `feat: add external assist provider presets` 及本轮文档回填，可回到 1609D 的自定义 endpoint 设置入口；本地规则识别链路不受影响。
- 结论：`GOAL-1609E` 已完成命令级验证，具备真机填写 DeepSeek API key 后端到端测试的条件。
- 下一步建议：在真机设置页开启外部辅助识别，选择 DeepSeek，填写 API key 后用同一张支付宝支付成功页截图复测，确认外部候选能把真实商户排在营销文案之前。

### ITER-185 GOAL-1608E 支付成功页商户候选修正
- 日期：2026-06-12
- 所属版本：v1.5.1
- 所属阶段：Phase C / 账单 OCR 与文本识别链路 Core 化重构
- 类型：Bugfix / 解析稳定性
- 目标：修复真机支付宝支付成功页 OCR 中优惠 / 奖励 / UI 文案压过真实商户的问题，避免继续按简单文本顺序选中“碰友日立减”。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift`：支付宝支付成功页专用商户候选过滤新增立减、优惠、折扣、代金券、满减、返现、特价、指定商品等营销词。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/MerchantResolver.swift`：Core 商户候选过滤新增回首页、付款方式、立减、红包、森林能量、葵花籽、待领取等 UI / 营销噪声；新增便利店 / 门店括号 / 餐厅 / 咖啡 / market / store 等真实商户形态加分。
  - `scripts/OfflineRegression.swift`：新增真机形态 OCR 回归，覆盖 `易择便利（陈塘科创园店）` 优先于 `碰友日立减`，并验证金额保持 `¥14.32`。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 UI、SQLite schema、外部 API、LLM 合并策略、Bundle ID、signing、entitlements、CloudKit 配置或 Xcode Cloud 脚本。
- 完成内容：商户候选从“靠前文本优先”进一步收敛为“过滤 UI / 营销噪声 + 提高门店形态权重”；App 层专用解析和 Core resolver 双层均覆盖该类样本。
- 未完成内容：尚未在真机重新识别同一张截图；更多平台营销文案仍需要通过后续真实样本扩展回归。
- 测试情况：
  - RED：新增真实形态 OCR 回归后，`bash scripts/run_offline_regression.sh` 先失败，Core resolver 会选中非商户候选。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：营销词过滤会降低优惠文案成为商户的概率；如果未来确有商户名包含“立减 / 红包”等词，需要通过别名或更强上下文规则处理。
- 回滚方式：回退提交 `fix: prefer store merchant over payment reward text` 及本轮文档回填即可恢复原解析行为。
- 结论：`GOAL-1608E` 已完成命令级验证，可以进入真机复测。
- 下一步建议：用同一张支付成功截图真机重测，确认调试记录商户变为真实门店；若仍出现营销文案，继续把该 OCR 原文加入回归。

### ITER-184 GOAL-1610B 商户别名学习用户确认
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D2 / 账单编辑保存链路稳定性
- 类型：Bugfix / 数据一致性 / UI
- 目标：取消高置信识别账单编辑时自动学习商户别名的行为，改为由用户在编辑保存时确认是否保存别名。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`updateTransaction` 新增 `saveMerchantAlias` 参数；新增 `shouldOfferMerchantAlias(from:to:)`；只有用户确认且符合高置信识别商户改名条件时才写入别名。
  - `AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift`：保存流程新增“保存商户别名？”确认弹窗；选择“不保存别名”只保存当前账单。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`、`AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`、`AutoLedger/AutoLedger/Screenshots/ScreenshotHostView.swift`：同步编辑器保存参数。
  - `AutoLedger/AutoLedger/en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings`、`zh-Hant.lproj/Localizable.strings`：补三语别名确认文案。
  - `scripts/OfflineRegression.swift`：新增“可提示但不自动保存别名”和“用户确认后才学习别名”回归。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改商户 resolver、OCR 解析规则、SQLite schema、CloudKit schema、Bundle ID、signing、entitlements 或 Xcode Cloud 脚本。
- 完成内容：商户别名学习由自动副作用改为用户确认；普通编辑、新增账单和未命中高置信识别记录的账单不提示也不学习别名。
- 未完成内容：尚未完成真机弹窗交互、长商户名文案截断和后续同商户识别套用别名的实机复测。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：若用户修改商户但不保存别名，后续相同原商户仍会按规则识别，需要用户再次确认；这是当前刻意选择的数据安全边界。
- 回滚方式：回退提交 `fix: require confirmation before saving merchant aliases` 及本轮文档回填即可恢复自动学习行为。
- 结论：`GOAL-1610B` 已完成命令级验证，可以进入真机识别链路和编辑保存链路联合测试。
- 下一步建议：用真实支付截图测试“识别 -> 保存 -> 编辑商户 -> 不保存别名 / 保存别名 -> 再次识别同商户”的完整链路。

### ITER-183 GOAL-1610A 账单编辑保存链路稳定性第一步
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D2 / 账单编辑保存链路稳定性
- 类型：Bugfix / 数据一致性
- 目标：修复真机账单编辑中保存按钮异常置灰、点击保存不生效、普通编辑污染商户别名和保存结果不明确的问题，并拆清编辑保存链路。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerAmountInputParser.swift`：新增金额输入解析器。
  - `AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift`：保存闭包改为返回成功 / 失败；保存失败时保留当前编辑页并显示提示；保存中禁止重复点击。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`addTransaction` / `updateTransaction` 改为返回保存结果；`updateTransaction` 先写 SQLite，成功后再刷新内存、Widget、备份和 iCloud 推送；普通手动编辑不再学习商户别名。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`、`AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`、`AutoLedger/AutoLedger/Screenshots/ScreenshotHostView.swift`：同步编辑器保存结果调用点。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：补金额输入解析和普通编辑不学习商户别名回归。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 SQLite schema、CloudKit schema、Bundle ID、signing、entitlements、Xcode Cloud 脚本、截图管线和主页面结构；未改变快捷指令 / Watch / iCloud 同步策略。
- 完成内容：编辑保存链路明确为“表单草稿 -> 金额解析 -> LedgerStore 保存 -> SQLite 写入 -> 内存刷新 -> Widget / 备份 / iCloud 推送”；写库失败不再关闭编辑页；常见金额输入形态不再导致保存按钮误置灰；普通手动编辑不再生成商户别名。
- 未完成内容：尚未完成真机 iPhone / iPad 编辑保存全路径复测；若仍有卡死，需要继续沿 `TransactionEditorView -> LedgerStore.updateTransaction -> SQLiteTransactionStore.update -> Widget / Backup / CloudKit` 分段定位。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：本步解决保存链路的同步成功 / 失败表达与明显数据污染风险，但真机输入法、长列表刷新、CloudKit 后台推送和 iPad 详情页状态仍需实际设备复测。
- 回滚方式：回退提交 `fix: stabilize transaction edit save inputs`、`fix: make transaction editor save explicit` 及本轮文档回填，可恢复到原编辑保存行为。
- 结论：`GOAL-1610A` 已完成代码和命令级验证，可以进入真机编辑保存复测。
- 下一步建议：在真机 iPhone / iPad 上各选一笔账单，分别修改商户、金额、分类、时间和备注；保存后立即返回列表和详情检查一致性，再重启 App 检查 SQLite 落盘结果。

### ITER-182 GOAL-1609D 外部辅助识别设置入口
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D / 脱敏外部 API 辅助识别试点
- 类型：能力增强 / 隐私 / UI
- 目标：为外部辅助识别补独立设置入口和 API key 安全存储边界，保持默认关闭，不配置真实 provider。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Settings/ExternalReceiptAssistSettingsView.swift`：新增外部辅助识别设置页。
  - `AutoLedger/AutoLedger/Features/Settings/SettingsView.swift`：新增设置页入口。
  - `AutoLedger/AutoLedger/Domain/Services/ExternalReceiptAssistClient.swift`：新增 Keychain API key 存取与清除，`runtimeAPIKey` 优先读取 Keychain，保留环境变量 fallback。
  - `AutoLedger/AutoLedger/en.lproj/Localizable.strings`、`zh-Hans.lproj/Localizable.strings`、`zh-Hant.lproj/Localizable.strings`：补齐三语文案。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未配置真实 provider、未接 Pro / IAP gate、未补正式隐私政策页面或 App Store 文案、未保存请求 payload / 响应内容 / 截图 / 完整 OCR 原文、未修改 Core、SQLite schema、Bundle ID、signing、entitlements 或 CloudKit 配置。
- 完成内容：外部辅助识别有独立设置入口；默认关闭；endpoint 可保存 / 清除为空；API key 可保存到 Keychain 或清除；UI 文案说明只发送最小化脱敏 payload，金额仍由本地规则决定。
- 未完成内容：尚未接真实 provider endpoint、正式隐私文案、Pro 功能门控、真机端到端外部 API 调用验证和 App Store 审核说明。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：Keychain 存储路径需要真机 / 模拟器手动点验；真实 provider 接入前仍不应开启给普通用户；若发布前隐私和成本未收口，应保持隐藏或 Debug 使用。
- 回滚方式：回退提交 `feat: add external assist settings` 及本轮文档回填，可回到 1609C 的主链路默认关闭状态。
- 结论：`GOAL-1609D` 已完成，外部辅助识别具备用户可控设置入口和 Keychain key 存储边界。
- 下一步建议：进入 `GOAL-1609E`，接入真实 provider 配置 / mock server 端到端验证，并同步隐私政策和 App Store 文案评估。

### ITER-181 GOAL-1609C 外部辅助识别主链路接入
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D / 脱敏外部 API 辅助识别试点
- 类型：能力增强 / 隐私 / 测试
- 目标：在默认关闭和脱敏 payload 边界下，把外部辅助候选接入 SmartParser / 文本解释器 / 快捷指令解析链路，并验证失败时仍完整回退到本地规则。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/ExternalReceiptAssistPayload.swift`：新增 `ExternalReceiptAssistSuggestionMapper`，将外部候选映射成 `ReceiptAISuggestion`。
  - `AutoLedger/AutoLedger/Domain/Services/SmartReceiptParser.swift`：新增默认关闭的外部辅助解析路径，并通过 `SmartReceiptMergePolicy` 合并本地规则结果。
  - `AutoLedger/AutoLedger/Domain/Services/LedgerTextInterpreter.swift`、`AutoLedger/AutoLedger/Domain/Services/QuickLedgerIntent.swift`：在设置开启时走外部辅助分支，失败或关闭时保留原有本地链路。
  - `AutoLedger/AutoLedger/Domain/Services/ExternalReceiptAssistClient.swift`：补充运行时 API key 环境变量读取边界。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增 mapper 回归与离线 stub。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未接 UI 开关、未接 Keychain 存储、未写入真实 API key、未配置真实 provider、未发送图片 / 完整 OCR 原文、未修改 SQLite schema、Bundle ID、signing、entitlements 或 CloudKit 配置。
- 完成内容：外部辅助路径现在可在运行时完整配置后参与解析；外部结果只补商户和分类，不覆盖规则金额；开关关闭、配置不全、网络失败或响应无效时会降级到本地规则 / 既有增强路径。
- 未完成内容：尚未实现用户可见开关、API key 安全输入 / 存储、隐私文案、真实 provider 配置、多 provider 选择和真机端到端外部 API 验证。
- 测试情况：
  - RED：新增 `ExternalReceiptAssistSuggestionMapper` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到 mapper 失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：当前外部辅助能力仍没有用户入口，且 API key 只支持运行时环境变量；后续接 UI 时必须补隐私提示、Keychain / 本地安全存储和日志脱敏检查。
- 回滚方式：回退提交 `feat: connect external assist parser path` 及本轮文档回填，可保留 1609A / 1609B 的脱敏 payload 和门控 skeleton，主本地解析链路不受影响。
- 结论：`GOAL-1609C` 已完成，外部辅助识别试点已接入主解析分支但仍默认关闭。
- 下一步建议：进入 `GOAL-1609D`，补用户可见开关、API key 安全输入 / 存储、隐私说明和真实 provider 配置；若发布前隐私或成本未收口，则保持隐藏 / Debug 开关。

### ITER-180 GOAL-1609B 外部辅助识别门控与 adapter
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D / 脱敏外部 API 辅助识别试点
- 类型：能力增强 / 隐私 / 测试
- 目标：在脱敏 payload 基础上增加默认关闭门控和 App 层 provider adapter skeleton，确保外部请求只有在运行时显式配置完整时才可能发起。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/ExternalReceiptAssistPayload.swift`：新增 `ExternalReceiptAssistSuggestion`、`ExternalReceiptAssistConfiguration`、`ExternalReceiptAssistGate`、`ExternalReceiptAssistGateDecision` 和阻断原因。
  - `AutoLedger/AutoLedger/Domain/Services/ExternalReceiptAssistClient.swift`：新增 App 层 URLSession adapter skeleton 和 settings key 常量。
  - `scripts/OfflineRegression.swift`：新增 gate 独立回归，覆盖默认关闭、缺 API key、endpoint 非法和完整配置放行。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未接 UI、未接 `SmartReceiptParser` 主链路、未默认调用外部服务、未写入真实 API key、未修改 SQLite schema、Bundle ID、signing、entitlements 或 CloudKit 配置。
- 完成内容：外部辅助识别现在有默认关闭门控；外部请求必须满足开关开启、payload 非空、endpoint 合法且运行时存在 API key；App 层 adapter 只发送已脱敏文本，不发送图片或原始 OCR 全文。
- 未完成内容：尚未接入 SmartParser 增强链路、失败降级、响应候选合并、UI 开关和 API key 安全输入 / 存储路径。
- 测试情况：
  - RED：新增 `ExternalReceiptAssistGate` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到 `ExternalReceiptAssistGate` / `ExternalReceiptAssistConfiguration` 失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：当前 adapter skeleton 具备网络发送能力，但没有任何主链路调用；后续接 UI / provider 时 API key 不应进入源码、日志、截图或 iCloud 配置同步。
- 回滚方式：回退提交 `feat: add external assist request gate` 及本轮文档回填，可保留 1609A 脱敏 payload 或一并回退，主本地解析链路不受影响。
- 结论：`GOAL-1609B` 已完成，外部 API 试点具备默认关闭门控和 App 层 adapter skeleton。
- 下一步建议：进入 `GOAL-1609C`，在 SmartParser 增强链路中接入外部辅助候选，并验证关闭 / 失败时完整降级到本地规则。

### ITER-179 GOAL-1609A 外部辅助识别脱敏 payload
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase D / 脱敏外部 API 辅助识别试点
- 类型：能力增强 / 隐私 / 测试
- 目标：在不接真实网络和不引入 API key 的前提下，先建立外部辅助识别前的最小化脱敏 payload 边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/ExternalReceiptAssistPayload.swift`：新增 `ExternalReceiptAssistPayload` 与 `ExternalReceiptAssistPayloadBuilder`。
  - `scripts/OfflineRegression.swift`：新增脱敏 payload 独立回归，覆盖订单号、商户单号、卡尾号、手机号、地址行、样本文件 ID 和超长编号脱敏。
  - `scripts/run_offline_regression.sh`：将新 Core 文件纳入离线编译列表。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未接入网络请求、真实外部 API provider、API key、UI 开关、`SmartReceiptParser` 主链路、日志输出、SQLite schema、Bundle ID、signing、entitlements 或 CloudKit 配置。
- 完成内容：外部辅助识别 payload 已可在 Core 层生成脱敏文本；商户候选和短金额上下文保留，敏感编号 / 地址 / 手机号 / 卡尾号会被替换；离线回归覆盖脱敏契约。
- 未完成内容：尚未新增默认关闭开关、provider adapter、响应解析、SmartParser 接入和失败降级；尚未补隐私文案和 UI。
- 测试情况：
  - RED：新增 `ExternalReceiptAssistPayload` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到 `ExternalReceiptAssistPayloadBuilder` 失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：脱敏器是第一版启发式规则，不能替代真实隐私审计；后续接 provider 时不得记录原始 OCR 全文，不得把 API key 写入源码或仓库。
- 回滚方式：回退提交 `feat: add redacted external assist payload` 及本轮文档回填，可移除外部辅助识别 payload 边界，主本地解析链路不受影响。
- 结论：`GOAL-1609A` 已完成，外部 API 试点具备第一层本地脱敏边界。
- 下一步建议：进入 `GOAL-1609B`，新增默认关闭开关、API key 读取边界和 provider adapter skeleton，仍不默认调用外部服务。

### ITER-178 GOAL-1608D SmartParser 金额职责边界收敛
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase C / 识别链路 Core 化重构
- 类型：重构 / 测试
- 目标：收紧 `SmartReceiptParser` 与规则解析的职责边界，确保 AI / LLM 候选不能覆盖规则解析得到的金额，同时为后续默认关闭的外部 API 辅助识别提供可测试的合并策略。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/SmartReceiptMergePolicy.swift`：新增 `ReceiptAISuggestion`、`SmartReceiptMergeOutcome` 和 `SmartReceiptMergePolicy`。
  - `AutoLedger/AutoLedger/Domain/Services/SmartReceiptParser.swift`：高置信 LLM 路径改为先拿规则解析结果，再通过 Core 合并策略进行商户 / 分类增强；金额优先保留规则结果。
  - `scripts/OfflineRegression.swift`：新增 `SmartReceiptMergePolicy` 独立回归，覆盖 AI 金额与规则金额冲突时的规则金额优先契约。
  - `scripts/run_offline_regression.sh`：将新 Core 文件纳入离线编译列表。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 UI、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置、`ReceiptParser` 特殊平台规则、OCR 服务、外部 API 接入或用户可见入账流程。
- 完成内容：SmartParser 的 AI 增强路径已改为规则金额优先；Core 合并策略允许 AI 补商户和分类，但规则已有金额时不会被 AI 金额覆盖；离线回归新增了可追溯契约。
- 未完成内容：尚未接入默认关闭的脱敏外部 API 辅助识别；尚未把外部 API 候选接入 `MerchantResolver`；尚未执行 Golden 回归和全平台 build。
- 测试情况：
  - RED：新增 `SmartReceiptMergePolicy` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到 `ReceiptAISuggestion` / `SmartReceiptMergePolicy` 失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：当规则解析完全失败时，高置信 AI 候选仍可作为 fallback 产出候选；后续外部 API 接入时仍必须保持默认关闭、脱敏、失败降级和日志不泄露。
- 回滚方式：回退提交 `refactor: preserve rule amounts in smart parser` 及本轮文档回填，可恢复 SmartParser 原有 LLM 构建 / 低置信合并逻辑。
- 结论：`GOAL-1608D` 已完成，`GOAL-1608` 第一阶段可收口为已完成；下一步进入 `GOAL-1609` 脱敏外部 API 辅助识别试点。
- 下一步建议：按默认关闭、最小化脱敏 payload、失败降级到本地解析的原则开始 `GOAL-1609`，先做配置与接口边界，再接真实 provider。

### ITER-177 GOAL-1608C 分类识别 Core 化第一步
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase C / 识别链路 Core 化重构
- 类型：重构 / 测试
- 目标：将 `LedgerTextInterpreterCore` 中的分类推断从解释器内联映射抽为平台无关的 `CategoryResolver`，让金额、商户、分类三段解析都有独立 Core 边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/CategoryResolver.swift`：新增 `CategoryResolver` 与 `CategoryResolutionResult`。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：分类推断入口改为调用 `CategoryResolver`，并保留 `inferCategory(from:)` 兼容门面；分类 debug trace 接回解释结果。
  - `scripts/OfflineRegression.swift`：新增 `CategoryResolver` 独立回归，覆盖餐饮、商超、出行和数字服务已知商户。
  - `scripts/run_offline_regression.sh`：将新 Core 文件纳入离线编译列表。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 `ReceiptParser` 特殊平台规则、`SmartReceiptParser` LLM 职责、UI、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或用户可见入账流程。
- 完成内容：分类推断已具备独立 resolver、详细结果、置信度、规则名和 debug trace；既有 `LedgerTextInterpreterCore.inferCategory(from:)` 调用方式仍可用；离线回归和 iOS generic build 通过。
- 未完成内容：尚未让 App 层 `ReceiptParser` / `SmartReceiptParser` 统一复用新 resolver；尚未执行 Golden 回归和全平台 build；分类仍是既有关键词模型，未引入历史学习信号。
- 测试情况：
  - RED：新增 `CategoryResolver` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到新类型失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：分类 resolver 当前只是边界抽取，不扩大分类能力；后续如果合并历史分类学习，应保持本地优先和可解释 debug trace。
- 回滚方式：回退提交 `refactor: extract category resolver` 及本轮文档回填，可恢复 `LedgerTextInterpreterCore` 内联分类映射。
- 结论：`GOAL-1608C` 已完成，Core 层金额、商户、分类三段解析边界已初步拆出。
- 下一步建议：继续评估 `ReceiptParser` / `SmartReceiptParser` 的职责边界，保证 LLM 不覆盖规则金额；随后进入 `GOAL-1609` 默认关闭的脱敏外部 API 辅助识别试点。

### ITER-176 GOAL-1608B 商户识别 Core 化第一步
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase C / 识别链路 Core 化重构
- 类型：重构 / 测试
- 目标：将 `LedgerTextInterpreterCore` 中的商户选择从行序优先的内联规则抽为平台无关的候选提取与 resolver，为后续 LLM 商户候选合并和脱敏外部增强准备稳定接口。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/MerchantResolver.swift`：新增 `MerchantCandidate`、`MerchantCandidateSource`、`MerchantResolutionResult`、`MerchantNormalizer`、`RuleMerchantExtractor` 和 `MerchantResolver`。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：商户选择入口改为调用 `RuleMerchantExtractor + MerchantResolver`，并把商户 debug trace 接回解释结果；删除旧内联商户辅助规则。
  - `scripts/OfflineRegression.swift`：新增 `MerchantResolver` 独立回归，覆盖标签商户、发票页眉排除和支付渠道噪声排除。
  - `scripts/run_offline_regression.sh`：将新 Core 文件纳入离线编译列表。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改 `ReceiptParser` 特殊平台规则、`SmartReceiptParser` LLM 职责、分类 resolver、UI、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或用户可见入账流程。
- 完成内容：商户识别已具备独立候选模型、normalizer、标签候选、行候选、黑名单 / 编号 / 金额 / 时间 / 商品编号排除和基础评分；`LedgerTextInterpreterCore` 公开 API 保持不变；既有商户离线样例继续通过。
- 未完成内容：尚未将 App 层 `ReceiptParser` 的平台特殊商户规则复用到新 resolver；尚未接入历史别名信号、外部 LLM 候选、分类 resolver 和 Golden 回归；候选评分仍是第一版轻量规则。
- 测试情况：
  - RED：新增 `RuleMerchantExtractor` / `MerchantResolver` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到新类型失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：商户评分当前只覆盖 Core 解释器第一阶段，不代表所有支付平台特殊解析已经统一；后续接外部 API 时外部结果只能作为 `MerchantCandidate` 输入 resolver，不得直接覆盖金额或静默入账。
- 回滚方式：回退提交 `refactor: extract merchant resolver` 及本轮文档回填，可恢复 `LedgerTextInterpreterCore` 内联商户选择逻辑。
- 结论：`GOAL-1608B` 已完成，商户识别从解释器内联规则抽为独立 Core 候选与 resolver，并通过离线回归和 iOS generic build。
- 下一步建议：继续 Phase C，抽取 `CategoryResolver` 并评估 `ReceiptParser` / `SmartReceiptParser` 的金额与商户职责边界，随后进入 `GOAL-1609` 脱敏外部 API 辅助识别试点。

### ITER-175 GOAL-1608A 金额识别 Core 化第一步
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase C / 识别链路 Core 化重构
- 类型：重构 / 测试
- 目标：先将 `LedgerTextInterpreterCore` 中的金额选择规则抽成平台无关的 Core 服务，为后续商户候选评分、分类 resolver 和外部脱敏增强接入准备稳定边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/PaymentAmountExtractor.swift`：新增 `PaymentAmountExtractor`、`AmountRole`、`AmountCandidate`、`AmountExtractionResult`。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：金额提取入口改为调用 `PaymentAmountExtractor`，并将 amount debug trace 接回解释结果。
  - `scripts/OfflineRegression.swift`：新增 `PaymentAmountExtractor` 独立回归，覆盖支付金额标签、`TOTAL RM` 优先和无标签 fallback。
  - `scripts/run_offline_regression.sh`：将新 Core 文件纳入离线编译列表。
  - `versions/v1.5.1-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填本步结果。
- 未改动范围：未修改商户选择、分类推断、`ReceiptParser` 特殊平台规则、`SmartReceiptParser` LLM 职责、UI、SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置或用户可见入账流程。
- 完成内容：金额提取器已独立输出候选、角色、置信度、证据、规则名、debug trace 和近似标记；既有 `LedgerTextInterpreterCore` 金额行为保持通过离线回归；新模块保持 `Foundation` 级别，不引入 `UIKit` / `SwiftUI` / `Vision` / `FoundationModels` 等平台依赖。
- 未完成内容：尚未迁移商户候选、商户标准化、分类 resolver；尚未修改 `ReceiptParser` / `SmartReceiptParser` 的金额和商户职责边界；尚未执行 Golden 回归和全平台 build。
- 测试情况：
  - RED：新增 `PaymentAmountExtractor` 离线回归后，`bash scripts/run_offline_regression.sh` 因找不到新类型失败。
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：新提取器当前以搬迁既有规则为主，不代表金额识别算法已最终完成；候选列表包含调试证据，后续对外展示或日志导出时仍应继续避免输出敏感 OCR 全文；`AppFormatters` 的 `nonisolated(unsafe)` warning 为既有 warning，本轮未处理。
- 回滚方式：回退提交 `refactor: extract payment amount parser` 及本轮文档回填，可恢复 `LedgerTextInterpreterCore` 内联金额提取逻辑。
- 结论：`GOAL-1608A` 已完成，金额识别从解释器内联规则抽为独立 Core 服务，并通过离线回归和 iOS generic build。
- 下一步建议：进入 `GOAL-1608B`，抽取 `MerchantCandidate` / `RuleMerchantExtractor` / `MerchantResolver`，把商户选择从行序优先改为候选评分。

### ITER-174 GOAL-1602 最低系统需求下调实施
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase B / 最低系统下调实施
- 类型：重构 / 工程配置 / 平台兼容
- 目标：在不破坏现有发布链路的前提下，将主 App / Watch / tvOS / visionOS 等 target 下调到 `v1.5.1` 目标最低系统矩阵，并保留 Apple Foundation Models 与 ControlWidget 的高版本边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift`：删除 Core 内的 AppIntents 入口。
  - `AutoLedger/AutoLedger/Domain/Services/ClipboardImportIntent.swift`：新增主 App 层剪贴板导入 Intent 与 App Group handoff 消费。
  - `AutoLedger/ControlWidgetExtension/ClipboardImportIntent.swift`、`ClipboardImportControl.swift`：新增 Control Widget 层 Intent，并移除对 `AutoLedgerCore` 的直接 import。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：App 激活 / 首次出现时消费 Control Widget 剪贴板导入 handoff。
  - `AutoLedger/AutoLedgerCore/Package.swift`：下调 Core package platform。
  - `AutoLedger/AutoLedger.xcodeproj/project.pbxproj`：下调主 App、Share Extension、Widget、Watch、tvOS、visionOS target deployment target，保留 `ControlWidgetExtension` 为 `iOS 18.0`。
  - `AutoLedger/AutoLedger/Domain/Services/LedgerTextInterpreter.swift`、`QuickLedgerIntent.swift`：补充低系统 feature gate，避免 `SmartReceiptParser.parse` 和 iOS 18-only `@Parameter` API 污染 iOS 17 主线。
  - `AutoLedger/Podfile`、`AutoLedger/Podfile.lock`：CocoaPods baseline 下调到 iOS 17。
  - `AutoLedger/Packages/RealityKitContent/Package.swift`：下调 RealityKitContent package platform。
  - `docs/minimum-platform-baseline-reduction-plan.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md`：回填实施结果。
- 未改动范围：未修改 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本、SQLite schema、CloudKit schema、App Store Connect 线上配置或用户可见主流程 UI。
- 完成内容：主发布线最低系统下调到 `iOS 17.0`；Mac Catalyst 跟随 `iOS 17 / macOS 14` line；Watch App / Watch Widget 下调到 `watchOS 10.0`；tvOS 下调到 `tvOS 17.0`；visionOS 下调到 `visionOS 1.0`；`ControlWidgetExtension` 独立保留 `iOS 18.0`；Apple Foundation Models 仍作为 `iOS 26+` optional enhancement。
- 未完成内容：尚未更新 README / App Store Connect 对外最低系统说明；尚未做真机 iOS 17 / watchOS 10 / tvOS / visionOS simulator 全量 smoke；尚未执行 Xcode Cloud validation build。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme ControlWidgetExtension -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`
- 风险与注意事项：Control Widget 的剪贴板导入现在通过 App Group handoff 触发主 App 消费，仍需真机或模拟器手动点验；Mac Catalyst 仍保留 MediaPipe xcframework 无 Catalyst slice 的既有 warning，当前 fallback 可构建；Apple Foundation Models 在 iOS 17 主线下不会启用，低系统默认走规则解析。
- 回滚方式：回退本轮相关提交可恢复：`refactor: move clipboard intent out of core`、`chore: lower AutoLedgerCore platform baseline`、`chore: lower platform deployment targets`、`fix: gate model parsing for iOS 17 baseline`、`chore: align CocoaPods baseline with iOS 17`、`chore: lower RealityKitContent platform baseline` 以及本轮文档回填。
- 结论：`GOAL-1602` 已完成命令级验证，主 App / Watch / tvOS / visionOS 的最低系统需求已按 `v1.5.1` 目标矩阵落地。
- 下一步建议：进入 `GOAL-1608` 识别链路 Core 化重构，先实现 `PaymentAmountExtractor` 与金额候选回归。

### ITER-173 GOAL-1601 AutoLedgerCore 平台依赖审计
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase B / 最低系统下调准备
- 类型：文档 / 架构审计 / 平台规划
- 目标：审计 `AutoLedgerCore` 当前平台依赖，判断是否必须先拆 `CoreBase`，并为后续 deployment target 下调给出实施顺序。
- 改动范围：
  - `docs/autoledgercore-platform-dependency-audit.md`：新增 Core 平台依赖审计结论。
  - `docs/minimum-platform-baseline-reduction-plan.md`：补充 GOAL-1601 审计结论，收紧 Phase B 顺序。
  - `versions/v1.5.1-plan.md`：将 `GOAL-1601` 标记为已完成，并补充最低系统实施结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮审计。
- 未改动范围：未修改 Swift 源码、Xcode target、deployment target、Bundle ID、entitlements、CloudKit 配置、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：确认 `AutoLedgerCore` 主要源码仍是 `Foundation` / `SQLite3` 级别；当前唯一高层平台依赖命中是 `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift` 中的 `AppIntents`；结论是不需要先大规模拆 `CoreBase`，应先把 `ClipboardImportIntent` 迁出为 App / Extension 层 Intent Adapter，再下调 `AutoLedgerCore/Package.swift`。
- 未完成内容：尚未迁移 `ClipboardImportIntent`；尚未修改 `AutoLedgerCore/Package.swift`；尚未下调任何 Xcode target 的 deployment target；尚未运行低系统构建验证。
- 测试情况：未运行测试。本轮仅做依赖审计与文档回填，不涉及源码或工程配置修改。
- 风险与注意事项：`ClipboardImportIntent` 当前被 `ControlWidgetExtension/ClipboardImportControl.swift` 使用，后续迁移时必须保持 Control Widget 和剪贴板导入入口行为不变；迁移后如果 Core 仍出现低系统编译阻塞，再重新评估是否需要独立 `CoreBase`。
- 回滚方式：删除 `docs/autoledgercore-platform-dependency-audit.md`，回退 `docs/minimum-platform-baseline-reduction-plan.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md` 和本条日志即可。
- 结论：`GOAL-1601` 已完成。下一步进入 `GOAL-1602`，优先迁出 `ClipboardImportIntent`，再下调 Core package 和相关 target deployment target。
- 下一步建议：实施 `GOAL-1602` 时先保持行为不变地迁移 Intent Adapter，再跑 iOS generic、Mac Catalyst、Watch 和离线回归。

### ITER-172 GOAL-1608 识别链路 Core 化重构规划
- 日期：2026-06-11
- 所属版本：v1.5.1
- 所属阶段：Phase C / 识别链路 Core 化重构
- 类型：文档 / 架构规划 / 回归规划
- 目标：将 `v1.5.0` 遗留的账单 OCR / 文本识别链路重构纳入 `v1.5.1`，明确金额、商户、分类解析的 Core Pipeline、LLM 边界、脱敏外部 API 辅助识别试点和回归验收。
- 改动范围：
  - `versions/v1.5.1-plan.md`：新增 `4.7 账单 OCR / 文本识别链路 Core 化重构`、Phase C、Phase D、`GOAL-1608` 和 `GOAL-1609`。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮规划变更。
- 未改动范围：未修改任何 Swift 源码、Xcode project、target、deployment target、Bundle ID、entitlements、CloudKit 配置、截图脚本或 App Store Connect 线上配置。
- 完成内容：明确新 Pipeline 为 `OCR / 原始文本 -> TextClean + PaymentAmountExtractor -> Merchant Extraction -> MerchantResolver / MerchantNormalizer -> CategoryResolver -> TransactionDraft / ImportedReceipt 适配`；明确金额只由规则决定，LLM 只辅助商户候选；明确商户选择不再依赖 OCR 文本行顺序，而是按分词候选、上下文证据、支付渠道排除、主体名特征、历史别名和 LLM 候选一致性综合评分；明确新增 Core 类型、`LedgerTextInterpreterCore` 接入边界、`ReceiptParser` 渐进复用策略、`SmartReceiptParser` 不再允许 LLM 金额覆盖规则金额；补充离线回归和 Golden 回归验收；将脱敏外部大模型 API 辅助识别从后续评估前移为 `v1.5.1` 受控试点，要求默认关闭、用户主动开启、请求脱敏最小化、失败降级、本地链路完整可用。
- 未完成内容：尚未实现 `PaymentAmountExtractor`、`MerchantResolver`、`MerchantNormalizer`、`CategoryResolver` 等 Core 类型；尚未迁移现有规则；尚未扩展离线回归；尚未实现外部大模型增强的脱敏 schema、开关 UI、隐私说明、API Adapter 和失败降级。
- 测试情况：未运行测试。本轮仅更新版本规划与迭代记录，不涉及源码。
- 风险与注意事项：该重构会触及 OCR 入账主链路，后续实施必须分阶段落地并保持 `LedgerTextInterpreterCore`、`ReceiptParser`、`SmartReceiptParser` 外部调用兼容；不得在 Core 中引入平台框架依赖；外部大模型增强进入 `v1.5.1` 试点后仍必须默认关闭、用户主动开启、只发送脱敏最小化文本，并保持本地识别链路完整可用。
- 回滚方式：回退 `versions/v1.5.1-plan.md` 中 `4.7`、Phase C、`GOAL-1608` 和门禁补充，并移除本条日志与 CHANGELOG 条目。
- 结论：`GOAL-1608` 与 `GOAL-1609` 已进入 `v1.5.1` 规划队列，作为最低系统准备之后、tvOS / visionOS 落代码之前的识别链路稳定性目标。
- 下一步建议：实施时先做 `PaymentAmountExtractor` 和金额候选回归，再迁移商户候选 / resolver；随后接入默认关闭的脱敏外部 API Adapter，把外部结果转成商户候选而不是正式账单。

### ITER-171 GOAL-1607 Shortcuts JSON 账单导入
- 日期：2026-06-09
- 所属版本：v1.5.1
- 所属阶段：Phase A / 当前主线自动化入口补充
- 类型：能力增强 / App Intent / UI
- 目标：新增 `导入 JSON 账单` App Intent，让 Shortcuts 或剪贴板可以传入结构化账单 JSON，并根据置信度决定自动保存、打开确认页或返回错误。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/StructuredLedgerJSONParser.swift`：新增纯 Foundation JSON 解析器、字段别名、日期 / 币种 / 分类 / 置信度处理和自动保存 / 确认 / 报错决策。
  - `AutoLedger/AutoLedger/Domain/Services/ImportLedgerJSONIntent.swift`：新增 App Intent，支持 Shortcuts 参数和剪贴板兜底输入。
  - `AutoLedger/AutoLedger/Domain/Services/StructuredLedgerJSONIntentHandoff.swift`：新增中置信度账单的 App 内确认页 handoff。
  - `AutoLedger/AutoLedger/Features/Ledger/StructuredLedgerJSONConfirmView.swift`、`AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：新增确认页并接入根视图 sheet。
  - `AutoLedger/AutoLedger/Domain/Services/QuickLedgerIntent.swift`：把 JSON 导入加入 App Shortcuts。
  - `AutoLedger/AutoLedger/{zh-Hans,zh-Hant,en}.lproj/Localizable.strings`：新增三语文案。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增离线回归覆盖。
  - `docs/shortcuts-json-ledger-import.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md`：补充功能说明与版本记录。
- 未改动范围：未修改 SQLite schema、Bundle ID、signing、entitlements、CloudKit 配置、Xcode Cloud 脚本、截图管线或多账本模型。
- 完成内容：JSON 可解析金额、商户、分类、日期、备注、币种和置信度；`confidence >= 0.85` 自动保存，`0.50..<0.85` 打开确认页，`< 0.50` 或缺少金额 / 商户等关键字段时报错；缺省置信度按确认处理；币种当前不新增字段，非 `CNY` 会写入备注。
- 未完成内容：当前只支持单笔 JSON 对象，不支持 JSON 数组批量导入；确认页还没有导入源详情和重复账单检测；Shortcuts 真机端的参数选择与剪贴板路径仍需人工 smoke。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
- 风险与注意事项：高置信度路径会直接保存正式账单，后续如果接入外部解析器，需要控制传入 confidence 的来源可信度；`currency` 暂存在备注里，未来若支持多币种正式模型，需要做 schema 迁移；App Intent 因确认页需要设置 `openAppWhenRun`。
- 回滚方式：移除新增 JSON parser、App Intent、handoff、确认页、App Shortcuts 入口、本地化键、离线回归和文档记录，并从 `AutoLedgerApp` 删除 handoff sheet 接入。
- 结论：GOAL-1607 已完成代码侧闭环，Shortcuts / 剪贴板结构化 JSON 账单导入具备自动保存、确认和报错三条路径。
- 下一步建议：在真机 Shortcuts 中分别测试高置信度自动保存、中置信度确认页和低置信度报错；随后继续 `v1.5.1` 主队列的最低系统需求审计或 tvOS / visionOS 落代码。

### ITER-170 v1.5.1 版本接管与最低系统规划
- 日期：2026-06-08
- 所属版本：v1.5.1
- 所属阶段：Phase 0 / 版本策略与平台基线规划
- 类型：文档 / 版本策略 / 平台规划
- 目标：将 `v1.5.0` 的遗留收口项、全平台内容补齐方向和最低系统需求优化整合为新的 `v1.5.1` 版本计划，并明确多账本继续顺延。
- 改动范围：
  - `versions/v1.5.1-plan.md`：新增 `v1.5.1` 版本计划，承接 `v1.5.0` 遗留 smoke、tvOS / visionOS 第一版代码、最低系统需求优化与最终全平台收口。
  - `versions/v1.5.0-plan.md`：新增 `1.1.2`，明确 `v1.5.0` 现在视为实现基线，不再单独执行最终提审 smoke。
  - `docs/minimum-platform-baseline-reduction-plan.md`：将承接版本改为 `v1.5.1`，并补充 `AutoLedgerCore -> CoreBase + Intent Adapter` 的拆分判断。
  - `README.md`：Roadmap 将 `v1.5.0` 标记为“基线完成”，新增 `v1.5.1` 当前开发线条目。
  - `CHANGELOG.md`、`process/iteration-log.md`：回填本轮版本接管记录。
- 未改动范围：未修改任何 Swift 源码、Xcode target、deployment target、Bundle ID、entitlements、CloudKit 配置、截图脚本实现或 App Store Connect 线上配置。
- 完成内容：将最终 smoke / Xcode Cloud / ASC 提交门禁整体后移到 `v1.5.1`；明确 `v1.5.1` 承接 tvOS / visionOS 第一版落代码与最低系统需求优化；明确多账本继续 delay，不进入当前执行范围；固定新的目标版本矩阵：`iOS 17 / macOS 14 line / watchOS 10 / tvOS 17 / visionOS 1 / ControlWidget iOS 18 / Apple FM iOS 26+ optional enhancement`。
- 未完成内容：尚未实际下调 deployment target；尚未拆分 `AutoLedgerCore`；尚未落 tvOS / visionOS 产品代码；尚未执行 `v1.5.1` 的最终 smoke / Xcode Cloud / ASC 收口。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：文档自检，`README`、`v1.5.0-plan.md`、`v1.5.1-plan.md` 与最低系统规划口径一致。
- 风险与注意事项：当前只是版本与平台规划调整，不代表最低系统已经下调成功，也不代表 tvOS / visionOS 已有可发布代码；后续真正实施时必须按 target 分层处理，不允许用全局 `@available(iOS 26.0, *)` 包裹主链路来“假降版本”。
- 回滚方式：删除 `versions/v1.5.1-plan.md`，回退 `versions/v1.5.0-plan.md`、`docs/minimum-platform-baseline-reduction-plan.md`、`README.md`、`CHANGELOG.md` 和本条日志即可恢复到 `v1.5.0` 收口口径。
- 结论：当前开发线正式切换为 `v1.5.1` 规划阶段；`v1.5.0` 作为实现基线保留，多账本继续顺延。
- 下一步建议：先执行 `GOAL-1601`，审计 `AutoLedgerCore` 真实平台依赖并给出 `CoreBase` 拆分与 deployment target 下调实施清单。

### ITER-169 GOAL-1592 当前发布平台回归矩阵与 Review Notes
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 11 / 发布资产与收口
- 类型：文档 / 回归 / 发布准备
- 目标：把 `v1.5.0` 当前发布主线的验证结果、剩余人工检查项和 App Review 说明整理成提交前可直接复用的资料。
- 改动范围：
  - `versions/v1.5.0-regression-baseline.md`：新增当前发布平台回归基线，区分命令 PASS、离线覆盖、用户点验和 PENDING 项。
  - `versions/v1.5.0-review-notes.md`：新增 Review Notes 英文草稿、中文备忘、审核路径和提交前人工清单。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1592` 标记为已完成，并新增 `13.67` 记录门禁结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：回填本轮收口资料。
- 未改动范围：未改动任何业务代码、签名、CloudKit 配置、IAP 产品 ID、截图 fixture、Xcode Cloud 配置或 App Store Connect 线上配置。
- 完成内容：形成 `v1.5.0` 当前发布平台的完整回归矩阵；明确 `backup / CSV / screenshot / iCloud sync / IAP` 的验证层级；给出可直接粘贴到 ASC 的 Review Notes 英文草稿；把 `Watch 表盘后台自动刷新`、`IAP 真机购买`、`Xcode Cloud archive` 和 `ASC 最终提交` 收敛为发布前人工清单。
- 未完成内容：仍未替代真机 Watch 后台刷新复测、IAP 沙盒购买点验、Xcode Cloud archive / TestFlight 上传和 ASC 实际提交操作。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：沿用本轮已完成的 generic iOS build、Mac Catalyst build、`export.sh --ios-only --watch-only --ipad-only --mac-only --locale zh-Hans`
- 风险与注意事项：本轮文档已经明确“本地构建 / 离线回归通过”不等于“Xcode Cloud archive / 真机 Watch 自动刷新 / IAP 购买 / ASC 提交完成”；提审前仍要按人工清单逐项复核。
- 回滚方式：删除 `versions/v1.5.0-regression-baseline.md`、`versions/v1.5.0-review-notes.md`，回退 `GOAL-1592` 对应版本与日志条目即可。
- 结论：`GOAL-1592` 已完成，`v1.5.0` 当前发布线的回归资料与审核说明已经齐备。
- 下一步建议：停止新增范围，按回归基线执行最后一轮真机 / Xcode Cloud / ASC 提交前 smoke。

### ITER-168 GOAL-1591 当前发布平台截图管线实现
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 11 / 发布资产与收口
- 类型：工具链 / 能力增强 / 文档
- 目标：在不破坏现有 iPhone / Watch 导出链路的前提下，把当前发布平台所需的 iPad / Mac 截图真正接入统一导出管线。
- 改动范围：
  - `AutoLedger/AutoLedger/Screenshots/ScreenshotModeConfig.swift`、`ScreenshotHostView.swift`、`App/AutoLedgerApp.swift`：新增 `ipad` / `mac` screenshot-mode 平台和 scene 路由。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：暴露可初始化的工作台 section，便于截图宿主稳定切页。
  - `tools/appstore-screenshots/config/screenshots.json`：新增 `ipad` / `mac` 平台、targets、设备候选、scene 与文案。
  - `tools/appstore-screenshots/scripts/export.sh`、`export_ipad.sh`、`export_mac.sh`、`render_marketing.py`、`build_preview.py`：新增 iPad / Mac 导出、渲染、preview 分组与 incomplete frame 检测。
  - `tools/appstore-screenshots/README.md`、`versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：同步回填工具说明与版本状态。
- 未改动范围：未接入 tvOS / visionOS 截图导出；未上传 App Store Connect；未改动真实账本、OCR、CloudKit、Bundle ID、签名或 Xcode Cloud 配置。
- 完成内容：统一截图工具现已支持 `--ios-only`、`--ipad-only`、`--mac-only`、`--watch-only`；`preview.html` 现按 `iPhone / Apple Watch / iPad / Mac` 分组展示；iPad / Mac 使用固定 fixture 与 screenshot host 导出关键页面；营销图标题区与截图框比例已按用户反馈收紧，减少标题和内容之间的视觉割裂。
- 未完成内容：tvOS / visionOS 截图仍顺延到 `v1.6.0`；App Store Connect 上传与最终商店页精选文案仍待 `GOAL-1592` 收口。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --watch-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ipad-only --locale zh-Hans`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --mac-only --locale zh-Hans`
  - PASS：人工查看 iPad / Mac 导出图，确认首张 iPad 不再白屏，横屏裁切不再失真，Mac 窗体截图可正常导出。
- 风险与注意事项：Mac 导出依赖本机 Accessibility 权限与 `System Events`；若权限不足，脚本会跳过 Mac 并在 preview 中保留状态。iPad / Mac 当前用的是稳定 fixture，并非真实用户账本快照。
- 回滚方式：回退 screenshot host、`screenshots.json`、三个导出脚本、renderer、preview 和文档改动即可恢复到旧的 iPhone / Watch-only 管线。
- 结论：`GOAL-1591` 已完成，当前发布平台截图导出能力已经闭环；下一步应进入 `GOAL-1592`，整理发布回归矩阵与 Review Notes。
- 下一步建议：基于当前脚本输出整理 `iPhone / iPad / Watch / Mac` 发布前检查表，并补充 ASC / Xcode Cloud / IAP / backup 说明。

### ITER-167 v1.5.0 收口策略更新
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 11 / 发布资产与收口
- 类型：文档 / 版本策略 / 发布收口
- 目标：把 `v1.5.0` 的版本边界重新收紧，避免在发布收口阶段继续背着 tvOS / visionOS 产品实现范围。
- 改动范围：
  - `versions/v1.5.0-plan.md`：更新版本收口策略，明确 `v1.5.0` 只对 `iPhone / iPad / Watch / Mac Catalyst` 负责；将 `GOAL-1591` / `GOAL-1592` 重新收口为当前发布平台截图和回归；新增 `13.65` 记录本轮判断。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录版本边界调整。
- 未改动范围：未修改任何业务代码、Xcode target、Bundle ID、签名、entitlements、截图脚本实现或 tvOS / visionOS 模板代码。
- 完成内容：明确 `tvOS / visionOS` 当前只保留 target 基线、设计稿和实现评估，不在 `v1.5.0` 中继续落产品代码；明确 `v1.5.1` 仅作为当前开发线内部补丁 / TestFlight 节点，不承接新平台实现；明确 `v1.6.0` 承接 tvOS / visionOS 第一版产品代码、截图和平台发布准备。
- 未完成内容：`GOAL-1591` 当前发布平台截图实现、`GOAL-1592` 当前发布平台回归矩阵与 Review Notes 仍待继续执行。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：文档自检，GOAL 队列、推荐推进顺序、验收口径和收口判断保持一致。
- 风险与注意事项：这次调整是范围收紧，不是能力回退；tvOS / visionOS 的设计与评估文档仍然有效，但不应被误解为 `v1.5.0` 已承诺上线的平台能力。
- 回滚方式：回退本轮文档改动，将 `GOAL-1591` / `GOAL-1592` 恢复为覆盖 tvOS / visionOS 的全平台发布范围。
- 结论：`v1.5.0` 现在的剩余目标已经明确收敛到当前发布主线，接下来应直接进入截图实现和发布回归，而不是继续新增平台代码。
- 下一步建议：进入 `GOAL-1591`，优先补齐 iPad / Mac 截图管线，并保持 iPhone / Watch 现有导出稳定。

### ITER-166 GOAL-1590 全平台截图管线设计
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 11 / 全平台截图与发布准备
- 类型：文档 / 设计 / 工具链规划
- 目标：在不破坏现有 iPhone / Watch 截图导出链路的前提下，定义 iPad / Mac / tvOS / visionOS 如何进入统一截图管线。
- 改动范围：
  - `docs/all-platform-screenshot-pipeline-design.md`：新增全平台截图设计稿，覆盖配置扩展、CLI flag、输出目录、preview 分组、平台场景和 `GOAL-1591` 实施顺序。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1590` 状态改为已完成，并新增 `13.64` 记录本轮结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1590` 完成范围。
- 未改动范围：未修改 `tools/appstore-screenshots/config/screenshots.json`、`scripts/export.sh`、`scripts/build_preview.py` 或任一 render 脚本；未新增任何 iPad / Mac / tvOS / visionOS 实际截图 scene；未生成新平台图片。
- 完成内容：收敛出单一 `screenshots.json` 的多平台扩展方式；明确 `--ipad-only`、`--mac-only`、`--tvos-only`、`--visionos-only` 的参数设计；定义六平台 raw/store 输出目录与 `preview.html` 分组；明确 iPad / Mac / tvOS / visionOS 的首批截图场景和 `GOAL-1591` 的分步实施顺序。
- 未完成内容：未真正实现新 flag、未扩 preview 脚本、未导出任何新平台截图。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：文档自检，设计稿与版本计划中的截图资产章节、GOAL 队列保持一致。
  - PASS：核对 `tools/appstore-screenshots/README.md`、`config/screenshots.json`、`scripts/export.sh`、`scripts/build_preview.py` 当前基线。
- 风险与注意事项：如果 `GOAL-1591` 一次性同时接六个平台，调试面会过大；更稳妥的顺序是先 iPad / Mac，再 tvOS / visionOS，同时保持现有 iPhone / Watch 输出不回退。
- 回滚方式：删除 `docs/all-platform-screenshot-pipeline-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1590` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1590` 设计完成，下一步可直接实现截图管线扩展，而不需要继续讨论总体方案。
- 下一步建议：进入 `GOAL-1591`，先做配置 / flag / preview 的骨架扩展，再按 iPad / Mac → tvOS / visionOS 的顺序接入 capture。

### ITER-165 GOAL-1583 visionOS 展示实现评估
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 10 / visionOS 空间展示版本
- 类型：文档 / 实现评估 / 平台扩展
- 目标：确认 `AutoLedgerVision` target / simulator 是否已可用，收敛首版 scene 选择、数据入口边界和最小 smoke 定义，避免直接把范围膨胀到 immersive 空间实现。
- 改动范围：
  - `docs/visionos-implementation-assessment.md`：新增实现评估文档，记录 target 现状、build smoke、scene 方案对比、RealityKit 模板判断、推荐实现路径和最小 smoke 定义。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1583` 状态改为已完成，并新增 `13.63` 记录本轮实现评估结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1583` 完成范围。
- 未改动范围：未修改 `AutoLedgerVision` 模板代码、未接只读 view model、未接 CloudKit 数据读链路、未移除 RealityKit 模板包、未修改 Bundle ID / signing / entitlements / App Group / iCloud Container / Xcode Cloud 脚本。
- 完成内容：确认 `AutoLedgerVision` 的 destinations、generic build 和 `Apple Vision Pro` simulator build 全部可用；明确首版应从 `WindowGroup` 单窗口开始，而不是先做 `Volume` 或 immersive space；明确 `RealityKitContent` 当前仍是模板资源，不应成为首版 blocker；收敛出“SwiftUI 四区只读骨架 + 稳定读模型”的推荐路径。
- 未完成内容：未实现 visionOS 骨架 UI、未接真实账本数据、未做 simulator 视觉 smoke、未确定未来是否保留 RealityKit 装饰层。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -showdestinations -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision`。
  - PASS：`xcrun simctl list devices available | rg "Vision|visionOS|Apple Vision"`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build`。
- 风险与注意事项：如果下一轮继续保留模板 `RealityKitContent + Hello, world!` 同时叠加真实账本 UI，很容易得到一套不稳定的混合界面；更稳妥的路径是先用 SwiftUI 落首版只读四区骨架，再决定是否需要 `Volume` 或 RealityKit 增强。
- 回滚方式：删除 `docs/visionos-implementation-assessment.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1583` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1583` 评估完成，visionOS target / simulator 已可继续推进；下一步应实现首版只读骨架，或转入 `GOAL-1590` 统一规划全平台截图管线。
- 下一步建议：如果继续按“第三批后段”推进，可直接进入 `GOAL-1590`；如果希望 visionOS 先落一个可见结果，也可以单开一轮仅做 `WindowGroup` 四区静态骨架，不接真实数据。

### ITER-164 GOAL-1582 visionOS 空间展示设计
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 10 / visionOS 空间展示版本
- 类型：文档 / 设计 / 平台扩展
- 目标：为 `AutoLedgerVision` 首版输出可直接交接到实现评估阶段的空间展示设计，明确入口 scene、空间层次、数据口径、交互密度和隐私边界。
- 改动范围：
  - `docs/visionos-spatial-design.md`：新增 visionOS 设计稿，覆盖平台定位、入口形态、四个展示区、空间布局原则、轻交互模型、隐私模式和 `GOAL-1583` 交接问题。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1582` 状态改为已完成，并新增 `13.62` 记录本轮设计结论和 build smoke 结果。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1582` 完成范围。
- 未改动范围：未修改 `AutoLedgerVision` 模板代码、未接 CloudKit 数据读模型、未实现 visionOS UI、未修改 Bundle ID / signing / App Group / iCloud Container / Xcode Cloud 脚本、未接 App Store Connect visionOS 平台。
- 完成内容：visionOS 首版定位收口为“空间展示端而非生产力工作台”；入口推荐从 `WindowGroup` 主窗口开始，不把 immersive space 作为首版必需条件；一个主窗口内固定 `月度空间看板 / 分类漂浮卡片 / 年度时间线墙 / 最近账单悬浮列表` 四个展示区；明确只读、单一正式账本、隐私模式和 stale 状态是一等边界。
- 未完成内容：未决定是否需要 `Volume` 或额外 scene；未验证 simulator 视觉呈现；未实现 view model、CloudKit 只读接入和空间布局代码。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：文档自检，设计稿与 `6.7 visionOS 空间展示版本`、`10.5 visionOS` 和 GOAL 队列保持一致。
  - PASS：`xcodebuild -showdestinations -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`。
- 风险与注意事项：visionOS target 虽然已能 build，但当前仍只是模板 scene；如果下一轮直接进入 immersive / RealityKit 深度实现，范围会比首版只读展示扩大很多。更稳妥的路径是先在 `GOAL-1583` 决定首版是否仅用 SwiftUI 空间面板完成四区展示，再评估是否保留 RealityKit 模板资源。
- 回滚方式：删除 `docs/visionos-spatial-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1582` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1582` 设计完成，visionOS 首版展示口径已定型，下一步进入 `GOAL-1583` 回答 scene / 数据入口 / 最小 smoke 的实现问题。
- 下一步建议：继续按顺序推进 `GOAL-1583`，先把 `WindowGroup / Volume / RealityKit / 只读数据入口` 的最小实现路径评估清楚，再决定是否开始写 visionOS 骨架界面。

### ITER-163 GOAL-1581 tvOS 看板实现评估
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 9 / tvOS 只读大屏看板
- 类型：文档 / 实现评估 / 平台扩展
- 目标：确认 `AutoLedgerTV` target / simulator 是否可用，明确 tvOS 首版 dashboard 的最小实现面和正确数据入口。
- 改动范围：
  - `docs/tvos-implementation-assessment.md`：新增实现评估文档，记录 target 现状、build smoke、数据入口方案对比、推荐路径、主要缺口和下一步建议。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1581` 状态改为已完成，并新增 `13.61` 记录本轮工程评估结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1581` 完成范围。
- 未改动范围：未修改 `AutoLedgerTV` 模板代码、未新增 tvOS entitlements、未接 CloudKit capability、未实现 tvOS dashboard UI、未修改 Bundle ID / signing / App Group / iCloud Container / Xcode Cloud 脚本。
- 完成内容：确认 `AutoLedgerTV` 的 generic tvOS build、tvOS Simulator build 和 destinations 全部可用；明确 tvOS 不能直接复用 iPhone Widget 的本地 App Group SQLite 读法；收敛出首版最小路径应为 CloudKit 正式账单只读拉取 + 本地派生 `TodaySpendingSummary` / `MonthlySnapshot` 指标。
- 未完成内容：未实现 tvOS 专用只读 view model、未拆 `LedgerCloudKitSyncAdapter` 的只读门禁、未写总览页 smoke UI。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -showdestinations -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build`。
  - PASS：`xcrun simctl list devices available | rg 'Apple TV'`。
- 风险与注意事项：tvOS 首版如果直接拉全量 CloudKit 正式账单，展示端仍需自己管理 `loading / stale / empty / unavailable` 状态；若后续发现拉取成本过高，可以单独立项引入 dashboard snapshot record，不建议在这一轮顺手扩 schema。
- 回滚方式：删除 `docs/tvos-implementation-assessment.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1581` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1581` 评估完成，tvOS target 和 simulator 已不是 blocker；下一步可直接开始 tvOS 最小骨架实现，或按顺序进入 `GOAL-1582` 完成 visionOS 设计。
- 下一步建议：若继续沿第七批推进，进入 `GOAL-1582`；若希望 tvOS 先落一个可见成果，可单开一轮仅实现总览页 smoke，不扩到四页完整 UI。

### ITER-162 GOAL-1580 tvOS 只读看板设计
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 9 / tvOS 只读大屏看板
- 类型：文档 / 设计 / 平台扩展
- 目标：为 tvOS 首版输出可直接交接到实现评估阶段的信息架构，明确只读边界、页面结构、遥控器焦点模型、隐私模式和同步口径。
- 改动范围：
  - `docs/tvos-dashboard-design.md`：新增 tvOS 设计稿，覆盖目标、页面职责、布局草案、焦点导航、隐私模式、快照状态和 `GOAL-1581` 交接建议。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1580` 状态改为已完成，并新增 `13.60` 记录本轮设计结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1580` 文档完成范围。
- 未改动范围：未修改 `AutoLedgerTV` target 模板代码、Bundle ID、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本；未实现 tvOS UI、未做 tvOS build smoke、未接 App Store Connect 平台。
- 完成内容：tvOS 首版定位收口为“家庭大屏只读账本看板”，一级导航固定为 `总览 / 分类 / 趋势 / 摘要` 四页；明确只读展示单一正式账本稳定快照，隐私模式作为一等能力；遥控器焦点模型保持极简，不把 iPad / Mac 工作台交互照搬到 tvOS。
- 未完成内容：未实现 tvOS SwiftUI 页面或 scene；未决定最终技术接入方式，只明确 `GOAL-1581` 应优先评估只读展示快照或共享读模型。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：文档自检，设计稿与 `6.6 tvOS 只读大屏看板`、`10.4 tvOS`、`13.4 推荐推进顺序` 保持一致。
- 风险与注意事项：当前本机缺 tvOS runtime，下一轮实现评估前仍需先补 Xcode Components；设计稿已明确 tvOS 不应承接导入、清洗或写入链路，后续若新增功能应单独立项，避免再次扩张范围。
- 回滚方式：删除 `docs/tvos-dashboard-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1580` 状态恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1580` 设计稿完成，可进入 `GOAL-1581` 的 target / scene / 数据入口实现评估。
- 下一步建议：下一轮只做 `GOAL-1581`，先评估 `AutoLedgerTV` 最小 scene 结构、焦点导航和只读快照读取方式，再决定是否进入 tvOS UI 第一版。

### ITER-161 Watch 表盘后台同步快照修复
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / Watch & Widget 今日支出
- 类型：Bugfix / watchOS / WidgetKit / WatchConnectivity
- 目标：修复 iOS 端或快捷指令新增账单后，Apple Watch 表盘小组件仍显示旧值或 0，必须点开 Watch App 后才更新的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：iPhone 侧同步 payload 改为可从 `LedgerStore` 或 SQLite fallback 构建；账本变化时除 `updateApplicationContext` / 前台 `sendMessage` 外，同时排队后台 `transferUserInfo` 和当前 complication userInfo。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`：Watch 侧新增 `didReceiveUserInfo` 处理，收到后台同步 payload 后写入 Watch App Group 今日支出快照并刷新表盘 Widget timeline。
  - `AddTransactionIntent.swift`、`QuickLedgerIntent.swift`、`VoiceLedgerIntent.swift`：App Intent / 快捷指令直写 SQLite 成功后主动触发 Watch 今日支出快照推送，不再只依赖主 App 前台通知。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮修复范围。
- 未改动范围：未修改 Watch Widget UI 样式、target / Bundle ID / App Group / entitlements / iCloud Container / Xcode Cloud 脚本；未让表盘 Widget 直接访问 iPhone SQLite 或 CloudKit。
- 完成内容：iPhone App 内新增 / 删除 / 恢复等账本变化继续走现有 `LedgerStore.reloadWidgets()` 触发 Watch 同步；快捷指令、Siri 和 App Intent 直写 SQLite 后也会构建最新今日支出 payload 并排队给 Watch。Watch 收到后台 userInfo 后会刷新本地 Widget 快照，降低表盘停留在 0 的概率。
- 未完成内容：未做 Apple Watch 真机表盘后台刷新时延测试；WidgetKit 和 WatchConnectivity 仍受系统调度影响，不承诺秒级实时更新。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 formatter warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`，仅有既有 AppIntent / Gemma warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerWatchWidgetsExtensionExtension -configuration Debug -destination 'generic/platform=watchOS' build`。
- 风险与注意事项：`transferUserInfo` / complication userInfo 是后台队列，真机表盘刷新仍可能有系统延迟；如果 Apple Watch 未连接、低电量、WatchConnectivity 被系统延后，表盘不会像同设备 Widget 读 SQLite 一样即时。真机验收应以“无需打开 Watch App，稍等后表盘能自动更新”为目标。
- 回滚方式：移除 iPhone 侧后台 transfer 队列、Watch 侧 `didReceiveUserInfo` 处理，以及三个 Intent 中的 `WatchConnectivityHost` 推送调用；恢复为只在 Watch App 前台或可达时同步。
- 结论：代码侧修复完成，构建门禁通过；仍需用户在真机上通过 iPhone / 快捷指令新增账单后观察表盘是否自动更新。
- 下一步建议：真机测试时先保持 Watch 戴在手腕且与 iPhone 连接，新增一笔今日支出后等待 30～120 秒观察表盘；若仍不更新，再抓 WatchConnectivity 日志判断是否后台 payload 未送达或 Widget timeline 未刷新。

### ITER-160 GOAL-1575 Mac 重复账单检查
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：能力增强 / Mac Catalyst / 数据清洗
- 目标：为 Mac Catalyst 账本页补齐重复账单检查与处理预览，保持“只提示、用户确认后处理、不静默删除”的边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/DataCleaningPreviewPlanner.swift`：重复检测从同商户 / 同金额 / 近时间扩展到同金额 / 同来源 / 近 10 分钟 / 备注文本高度相似；相似度复用 `TextSimilarity.jaccard`。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：Mac Catalyst 账本表格上方新增疑似重复面板，展示重复组数量、相似度、涉及账单，支持选中影响账单和确认后移入最近删除。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐 Mac 重复检查相关中英繁文案。
  - `scripts/OfflineRegression.swift`：新增同来源 + 相似文本重复候选回归。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1575 完成范围。
- 未改动范围：未新增 OCR 原文字段、候选队列持久化、清洗历史表、CloudKit schema、BackupBundle schema；未实现自动合并、永久删除、静默删除、跨币种重复检测或手动选择保留哪一笔；未修改 project / workspace / scheme / target 名称、Bundle ID、signing、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：Mac 账本页可以看到疑似重复组，查看相似度和涉及账单，一键选中影响账单；确认处理后复用现有 `applyDataCleaningPreview`，保留较新账单，把较旧项软删除到最近删除。
- 未完成内容：未做 Mac Catalyst 运行态人工 smoke；重复检测仍是轻量规则，不替代后续更复杂的 OCR 原文相似度、跨来源支付流水去重或手动保留项选择。
- 测试情况：
  - PASS：TDD 红灯。新增同来源 + 相似文本重复候选断言后，旧实现离线回归失败 2 项。
  - PASS：`bash scripts/run_offline_regression.sh`，新增重复检测断言通过，仅有既有 formatter warning。
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`。
- 风险与注意事项：当前文本相似度复用 `Transaction.note`，如果真实 OCR 原文不进入正式账单 note，文本重复能力只覆盖已有备注文本；处理重复项会软删除较旧账单，虽然可从最近删除恢复，但仍建议先在小批量数据上 smoke。
- 回滚方式：移除 `DataCleaningPreviewPlanner` 的文本相似重复规则、Mac 疑似重复面板、新增本地化 key 和离线回归断言，将 `versions/v1.5.0-plan.md` 中 GOAL-1575 状态恢复为未完成，并删除对应 CHANGELOG / iteration-log 条目。
- 结论：GOAL-1575 代码侧第一版完成，Mac Catalyst Phase 8 最小生产力闭环已覆盖重复账单检查。
- 下一步建议：进入 GOAL-1580 tvOS 只读看板设计，先做信息架构和只读边界，不急于扩大写入能力。

### ITER-159 GOAL-1574 Mac 大表格与批量编辑
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：能力增强 / Mac Catalyst / 批量编辑
- 目标：为 Mac Catalyst 账本页补齐桌面大表格、多选、排序筛选和批量商户 / 分类修正能力。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `applyBatchTransactionEdits(transactionIDs:merchant:category:)`，批量更新正式账单商户 / 分类，并同步商户别名、分类修正、Widget、自动备份和 CloudKit 增量推送。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：Mac Catalyst 下账本页改为表格工作区，支持搜索、排序、多选、全选、清空选择、批量商户修正、批量分类修正和写入前确认。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐 Mac 账本搜索、排序、批量编辑和确认弹窗三语文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1574 完成范围。
- 未改动范围：未实现重复账单检查、批量删除、批量恢复、批量导出选中项、列自定义、原生 Mac inspector、新 SQLite / CloudKit / BackupBundle schema；未修改 project / workspace / scheme / target 名称、Bundle ID、signing、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：Mac Catalyst 账本页现在具备更适合桌面的大表格；用户可筛选和排序正式账单，选择多笔后统一修正商户或分类，并在确认弹窗中看到影响条数和目标值后再写入。
- 未完成内容：未做 Mac Catalyst 运行态人工 smoke；GOAL-1575 的重复账单检查和批量重复处理预览仍待下一轮。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 formatter warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`，仍有既有 MediaPipe XCFramework 缺少 maccatalyst slice 的 CocoaPods copy warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：批量写入会批量改正式账单，虽然已有确认弹窗，但当前还没有跨启动撤销历史；用户应先在 Mac 运行态 smoke 小批量选择、商户修正和分类修正。重复账单检查仍未实现，不应把本轮视为完整桌面清洗工作台。
- 回滚方式：移除 `applyBatchTransactionEdits`、Mac 表格工作区和新增本地化 key，将 `versions/v1.5.0-plan.md` 中 GOAL-1574 状态恢复为未完成，并删除对应 CHANGELOG / iteration-log 条目。
- 结论：GOAL-1574 代码侧第一版完成，Mac Catalyst 大表格与批量商户 / 分类修正能力已具备。
- 下一步建议：进入 GOAL-1575 Mac 重复账单检查，先做只读检测与影响范围预览，再决定是否接批量处理。

### ITER-158 Watch 今日 / 最近页面标题去重与 UI 统一
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / Watch 体验修复
- 类型：Bugfix / watchOS / SwiftUI
- 目标：修复 Apple Watch “今日支出”和“最近支出”页面同屏出现两个同名标题，并统一两页开头 UI 结构。
- 改动范围：
  - `AutoLedger/AutoLedgerWatch Watch App/ContentView.swift`：移除今日页内部 `watch.today.title` 和最近页内部 `watch.recent.title`；新增共享 `WatchLedgerContextHeader`，两页统一使用图标 + 账本名作为内容区上下文行，导航栏标题作为唯一页面标题。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮 Watch UI 修复。
- 未改动范围：未修改 Watch 数据同步、表盘小组件、App Group、entitlements、Bundle ID、target、iCloud、SQLite 或 Xcode Cloud 配置。
- 完成内容：今日页和最近页都保留顶部导航标题，不再在内容区重复显示同一标题；内容区第一行统一展示“本地账本”上下文，视觉结构更接近同一套 Watch 页面模板。
- 未完成内容：未做 Apple Watch 真机截图复测；需要用户在真机上确认两页标题和间距是否符合预期。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
- 风险与注意事项：本轮去掉了今日页的内部 material 摘要卡背景，让今日页和最近页更统一；如果真机上觉得摘要内容缺少层次，可后续为两页引入同一套 section 容器，而不是只给今日页单独加卡片。
- 回滚方式：恢复今日页和最近页内部标题，并移除 `WatchLedgerContextHeader`。
- 结论：代码侧修复完成，Watch generic 构建通过；等待真机视觉复测。
- 下一步建议：在 Watch 真机左右滑动今日 / 最近两页，确认导航栏标题唯一、内容区账本行一致、今日金额和最近列表的视觉节奏协调。

### ITER-157 Watch App 与表盘小组件今日支出快照一致性修复
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / Watch 与 Widget 同步体验修复
- 类型：Bugfix / watchOS / Widget
- 目标：修复 Apple Watch App 内“今日支出”为 0，但表盘小组件已有今日支出数据，必须杀后台再打开 Watch App 才刷新的问题。
- 改动范围：
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`：新增从 App Group `WatchLedgerWidget.todaySummary` 读取今日支出快照的前台恢复路径；当本地快照不旧于内存态或内存态为空时，先回灌 `todaySummary`；写入快照后同时刷新默认金额组件和文字版 corner 组件。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchLedgerViewModel.swift`：初始化、初次同步和前台恢复时先同步本地 Widget 快照，再发起 WatchConnectivity 同步请求。
  - `AutoLedger/AutoLedgerWatch Watch App/AutoLedgerWatchApp.swift`：监听 `scenePhase == .active`，Watch App 回到前台时刷新本地快照并请求 iPhone 补齐最新数据。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮修复和验证。
- 未改动范围：未修改 Watch App / Widget target、Bundle ID、signing、App Group、entitlements、iCloud Container、主 App 同步 schema、SQLite 或 Xcode Cloud 脚本。
- 完成内容：Watch App 的今日支出页面和表盘小组件现在共享同一份本地 App Group 快照作为前台恢复基线；即使 WCSession 回调还没回来，Watch App 首屏也能先显示小组件已经拿到的今日金额，然后再由 iPhone 同步覆盖为最新状态。
- 未完成内容：未做 Apple Watch 真机前后台切换复测；需要用户在真机上验证“iPhone 新记一笔 / 小组件更新 / 打开 Watch App 首屏”的链路。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
- 风险与注意事项：本地快照只用于今日摘要的快速恢复，不替代 iPhone 的 WatchConnectivity 增量同步；最近账单列表仍以 WCSession payload 为准。
- 回滚方式：移除 `refreshFromWidgetSnapshot()`、ViewModel 前台恢复调用和 `scenePhase` 监听，恢复 Watch App 只依赖 WCSession 内存态。
- 结论：代码侧修复完成，Watch generic 构建通过；等待真机验证。
- 下一步建议：在 iPhone 端新增一笔今日支出后，等待表盘小组件显示更新，再直接打开 Watch App（不杀后台）确认今日支出立即显示同一金额；随后下拉刷新确认最近账单列表补齐。

### ITER-156 全平台统计卡与 iPad 分析组件尺寸固定
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / Phase 8 工作台体验修复
- 类型：Bugfix / SwiftUI
- 目标：修复 iPhone / iPad / Mac Catalyst 第一屏统计卡，以及 iPad 分析页不同统计组件因为文本长度自适应撑高，导致外框大小不一致、网格不平均对齐的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Shared/Components/MetricCard.swift`：共享统计卡固定外框高度，标题、数值和说明文本使用 `lineLimit`、`minimumScaleFactor` 与 tightening 在卡片内部自适应。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：iPad 分析页面板固定外框高度；分类占比、趋势和摘要行的标题 / 数值改为在面板内部缩放适配。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮体验修复。
- 未改动范围：未调整统计口径、账本数据、iCloud 同步、批量导入、Mac 菜单命令、SQLite schema、Bundle ID、signing、App Group、iCloud Container、entitlements、scheme 或 Xcode Cloud 脚本。
- 完成内容：统计卡和分析面板从“外框跟随内容高度变化”改为“外框固定、内部文字适配”，优先保证首页和宽屏分析网格平均对齐；长商户名、长分类名或较大金额不会继续把单个组件撑高。
- 未完成内容：未做 iPad / Mac Catalyst 运行态截图目检；具体字号压缩效果仍需在真机或运行包中确认。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`。
- 风险与注意事项：固定高度会让极端长文本优先缩小而不是撑开卡片；如后续视觉上觉得金额过小，可按具体页面再拆分专用卡片高度或专用字号策略。
- 回滚方式：还原 `MetricCard` 的固定高度和 iPad 分析面板固定高度，恢复由内容决定组件高度的布局。
- 结论：代码侧布局约束修复完成，iOS 与 Mac Catalyst 构建通过；等待运行态视觉复测。
- 下一步建议：在 iPad 横屏、Mac Catalyst 窗口和 iPhone 首页分别检查“本月支出 / Top 商户 / 分类占比 / 最近趋势 / 本月摘要”的外框对齐和文字缩放效果。

### ITER-155 iPad / Mac Catalyst 侧边栏二级页面切换修复
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 3 / Phase 8 工作台体验修复
- 类型：Bugfix / SwiftUI
- 目标：修复 iPad 工作台进入某个 Tab 的二级页面后，点击其他侧边栏 Tab 时右侧 detail 仍停留在旧二级页面的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：`IPadWorkspaceSection` 增加 `Hashable`，侧边栏引入 `sidebarSelection` 并绑定 `List(selection:)`；行点击和系统 list selection 都统一调用 `select(_:)`；切换 Tab 时继续重置 detail identity 和设置页局部 identity。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮修复和验证。
- 未改动范围：未改 iPad / Mac 各 Tab 的业务页面；未改 CloudKit、导入队列、正式账本保存、Bundle ID、signing、App Group、iCloud Container、entitlements、scheme 或 Xcode Cloud 脚本。
- 完成内容：侧边栏选择状态从“自定义 Button 自管状态”改为同时绑定 SwiftUI `List(selection:)`，避免子 `NavigationStack` 在二级页面时压住 detail 切换；点击文字、图标或行内空白区域都会走同一套切换和 detail 重置逻辑。
- 未完成内容：未做 iPad 真机手动复测；需要用户在真机上再次验证“进入设置 / 账本 / 候选等二级页面后点击其他 Tab”的切换行为。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`。
- 风险与注意事项：这是 SwiftUI `NavigationSplitView` + 自定义 sidebar button 的状态同步修复；如果后续仍出现个别 Tab 内部 `NavigationStack` 残留，需要把每个 Tab 的导航路径拆为显式 `NavigationPath`。
- 回滚方式：移除 `sidebarSelection`、`List(selection:)`、`.tag(section)` 和对应 `onChange`，恢复上一轮自定义 Button 侧边栏。
- 结论：代码侧修复完成，构建通过；等待 iPad 真机复测确认。
- 下一步建议：真机进入任一二级页面后，连续点击“总览 / 导入 / 账本 / 分析 / 候选账单 / 数据清洗 / 设置”各 Tab，确认右侧都回到目标 Tab 根页面。

### ITER-154 GOAL-1573 Mac 基础菜单栏与键盘快捷键
- 日期：2026-06-05
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：能力增强 / Mac Catalyst / 桌面交互
- 目标：为 Mac Catalyst 工作台补齐基础菜单栏和常用键盘快捷键，让文件导入、CSV 导入导出、JSON 备份导出和设置入口可以通过桌面菜单触发。
- 改动范围：
  - `AutoLedger/AutoLedger/App/AutoLedgerMacCommandCenter.swift`：新增 Catalyst 命令中心和 `AutoLedgerMacCommands`，提供 `Import` / `Export` / `Backup` 菜单及设置快捷入口。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：在 Mac Catalyst 下挂载菜单命令，不影响 iPhone / iPad / Watch 路径。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：接收 Mac 菜单命令并路由到工作台；导入文件、导入 CSV、导出 CSV、导出 JSON 备份复用现有页面动作；设置命令切换到设置页。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐菜单和命令三语文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1573 完成范围。
- 未改动范围：未新增原生 `NSSavePanel` / `NSOpenPanel`，未实现多窗口，未实现大表格、批量选择、批量修正或重复账单处理；JSON 覆盖恢复不挂菜单快捷键，仍保留在页面内二次确认；未修改 Bundle ID、signing、App Group、iCloud Container、entitlements、scheme 或 Xcode Cloud 脚本。
- 完成内容：
  - `Import > Import Files...` 可打开现有文件导入器。
  - `Import > Import CSV...` 可打开 CSV 导入器，CSV 行继续进入候选账单队列。
  - `Export > Export CSV...` 复用现有 CSV 导出能力。
  - `Backup > Export JSON Backup...` 复用现有 JSON BackupBundle 导出能力。
  - 设置命令可切换到工作台设置页。
  - 快捷键覆盖导入文件、导入 CSV、导出 CSV、导出 JSON 和设置入口。
- 未完成内容：菜单 smoke 仍需在真实 Mac Catalyst 运行包里人工确认；剪贴板导入、筛选后局部导出、JSON 恢复预览、原生文件面板和菜单禁用态可在后续桌面打磨中继续增强。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`，仍有 MediaPipe XCFramework 缺少 maccatalyst slice 的 CocoaPods copy warning，但不影响当前构建。
  - PASS：`plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 formatter warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`，仅有既有 Swift / MediaPipe warning。
- 风险与注意事项：当前命令路由基于工作台内的现有 SwiftUI file importer / exporter / share flow；如果未来改成更原生的 Mac 文件面板，需要单独处理沙盒安全范围和保存路径。菜单命令不应绕过候选复核或覆盖恢复确认。
- 回滚方式：移除 `AutoLedgerMacCommandCenter.swift`、`AutoLedgerApp` 的 Catalyst `.commands`、工作台的命令路由和新增本地化 key，并将 GOAL-1573 状态恢复为未完成。
- 结论：GOAL-1573 代码侧第一版完成，Mac Catalyst 已具备基础菜单栏和快捷键入口。
- 下一步建议：在 Mac Catalyst 运行包中人工 smoke 菜单项和快捷键；随后进入 GOAL-1574 Mac 大表格与批量编辑。

### ITER-153 GOAL-1572 Mac CSV / JSON 导入导出
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：能力增强 / Mac Catalyst / 导入导出
- 目标：为 Mac Catalyst 工作台补齐 CSV / JSON 导入导出第一版，让桌面端可以导出正式账单、导入 CSV 候选，并继续复用 JSON BackupBundle 的备份 / 恢复能力。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/LedgerCSVCodec.swift`：新增 CSV 编解码工具，固定列为 `id, occurredAt, merchant, amount, category, source, note`，支持引号、逗号和无效行诊断。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `writeCSVExportFile()`，只导出当前正式账单，不包含最近删除、候选队列或调试日志。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：Mac Catalyst 导入页新增 CSV 导入导出与 JSON 备份导出 / 恢复入口；CSV 导入行进入候选队列，JSON 恢复保留二次确认。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐 CSV / JSON 数据交换三语文案。
  - `scripts/run_offline_regression.sh`、`scripts/OfflineRegression.swift`：将 CSV codec 纳入离线回归，新增 CSV 往返、转义和无效金额用例。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1572 完成范围。
- 未改动范围：未实现菜单栏 Import / Export / Backup 命令，未实现键盘快捷键，未实现 CSV 字段映射 UI，未实现选中账单局部导出，未把 CSV 导入直接写入正式账本，未修改 signing、Bundle ID、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - Mac 导入页可以导出正式账单 CSV。
  - Mac 导入页可以导入 CSV，并把每一行转换为候选账单或需处理候选，不会自动写入正式账本。
  - Mac 导入页可以导出 JSON BackupBundle。
  - Mac 导入页可以选择 JSON 备份并通过二次确认恢复，继续复用既有安全备份 / 覆盖恢复语义。
- 未完成内容：CSV 字段映射和恢复预览 UI 仍是后续增强；本轮 JSON 恢复确认复用既有确认弹窗，还没有独立差异预览；菜单栏和快捷键进入 GOAL-1573。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：`plutil -lint AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings AutoLedger/AutoLedger/en.lproj/Localizable.strings AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：CSV 导入是候选账单导入，不是完整备份恢复；用户仍需逐条确认入账。JSON 恢复会覆盖本地账本和配置，必须保留 destructive confirmation。真实 Mac 桌面文件选择 / 分享面板手感仍需人工 smoke。
- 回滚方式：移除 `LedgerCSVCodec.swift`、`LedgerStore.writeCSVExportFile()`、工作台 CSV / JSON 数据交换入口、本地化键和离线回归新增用例，并将 GOAL-1572 状态恢复为未完成。
- 结论：GOAL-1572 代码侧第一版完成，Mac Catalyst 已具备 CSV / JSON 数据交换基础能力，可以继续进入 GOAL-1573 菜单栏与快捷键。
- 下一步建议：在 Mac Catalyst 真机运行中 smoke CSV 导出、CSV 导入候选、JSON 导出和 JSON 恢复确认；随后推进 GOAL-1573。

### ITER-152 GOAL-1571 Mac 拖拽截图 / 文件导入
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：能力增强 / Mac Catalyst / SwiftUI
- 目标：在 Mac Catalyst 工作台中提供 Finder 拖拽图片 / 文件导入入口，让拖入内容先进入识别队列或需处理队列，不直接写入正式账本。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：Mac Catalyst 下在导入页和识别队列页显示拖拽导入区；新增 `onDrop` 处理 Finder file URL；拖入文件复用既有 `importFileAsRawInput` 和 `appendBatchRawInputs`；文件夹先标记为不支持文件类型。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐 Mac 拖拽导入区标题、说明、失败和导入结果文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1571 第一版完成范围和未做边界。
- 未改动范围：未实现 PDF OCR、文件夹递归扫描、拖拽后自动入账、CSV / JSON 导入导出、菜单栏、快捷键或大表格；未修改 Xcode project、target、Bundle ID、`DEVELOPMENT_TEAM`、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - Mac Catalyst 导入页和识别队列页提供明显的拖拽导入区域。
  - 从 Finder 拖入图片会执行 OCR，并以 raw input 进入待识别队列。
  - 从 Finder 拖入文本文件会读取文本，并进入待识别队列。
  - PDF 和文件夹会进入队列并标记为需处理 / 不支持文件类型，不会误判为已识别。
  - 文件选择和拖拽导入共用同一条 `BatchRawInput` 队列路径，候选生成仍需用户点击识别，正式入账仍需复核确认。
- 未完成内容：未做 Mac 真机拖拽手感测试；未支持拖入非文件 URL 的图片数据；未支持文件夹递归；未做 PDF OCR。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`，仍有 MediaPipe XCFramework 缺少 maccatalyst slice 的 CocoaPods copy warning，但不影响当前构建。
- 风险与注意事项：拖拽入口当前只消费 Finder file URL；从浏览器或其他 App 拖出的图片对象如果不是文件 URL，可能显示“未能读取拖入的文件”。PDF / 文件夹先进入需处理队列，后续是否支持取决于实际需求。
- 回滚方式：移除 Mac drop zone、`importDroppedProviders` / `loadDroppedFileURL` / `importFileURLs` helper 和新增本地化 key，恢复仅通过文件选择导入。
- 结论：GOAL-1571 第一版已具备 Mac Finder 拖拽导入闭环，且不改变正式账本写入边界。
- 下一步建议：在 Mac Catalyst 运行包中实际拖拽图片、文本、PDF 和文件夹做手感测试；随后进入 GOAL-1572 CSV / JSON 导入导出，或补 GOAL-1571 的 PDF / 文件夹细化能力。

### ITER-151 iPad / Mac Catalyst 工作台侧边栏命中区与 detail 导航重置
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / Phase 8 工作台体验修复
- 类型：Bugfix / SwiftUI
- 目标：修复 iPad / Mac Catalyst 工作台左侧菜单只有点中文字才生效，以及 Tab 进入下一层页面后点击其他主菜单仍停留在上一层详情页的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：侧边栏按钮 label 增加整行 frame 与 `contentShape(Rectangle())`；主菜单 selection 变化时更新 detail reset identity，并把 identity 绑定到 detail 根视图。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录本轮体验修复。
- 未改动范围：未调整 iPad 各 Tab 的业务内容；未改动 CloudKit、批量识别、账本保存、Xcode project、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 侧边栏每一行的空白区域也会响应点击，避免误以为 Tab 切换卡顿。
  - 从设置、账本、导入、候选账单等页面进入内层 NavigationStack 后，再点击其他主菜单会重建 detail 根页面，清理上一层导航残留。
- 未完成内容：未做真机 iPad / Mac Catalyst 手感复测；未重构各 Tab 为显式 `NavigationPath`。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 formatter warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`，仍有 MediaPipe XCFramework 缺少 maccatalyst slice 的 CocoaPods copy warning，但不影响当前构建。
- 风险与注意事项：切换主菜单会重建 detail 根视图，这是为保证跨 Tab 切换可靠性做的明确取舍；如果后续某个 Tab 需要保留独立导航历史，可再改为每个 section 持有独立 `NavigationPath`。
- 回滚方式：移除 `detailResetID` 与侧边栏 label 的整行 hit area 设置，恢复上一轮 `IPadWorkspaceView` 结构。
- 结论：工作台主菜单交互已按“点击整行立即切换并回到目标 Tab 根页”的桌面 / iPad 预期修复。
- 下一步建议：在 iPad 真机和 Mac Catalyst 上连续测试“进入设置内页 -> 点导入 / 账本 / 分析”、“进入账单详情 -> 点其他主菜单”的切换行为。

### ITER-150 全平台 target 基线与 Mac Catalyst 构建 smoke
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Phase 9 / Phase 10 平台接入基线
- 类型：能力增强 / Xcode 配置 / 构建验证
- 目标：在用户手动补齐 Mac Catalyst supported destination、tvOS target 和 visionOS target 后，保护现有 iOS / iPad / Watch 发布链，并确认当前工程进入 Mac Catalyst 主线前的真实构建状态。
- 改动范围：
  - `AutoLedger/AutoLedger.xcodeproj/project.pbxproj`：主 App target 保持原 Bundle ID，开启 Mac Catalyst supported destination，关闭 Mac Designed for iPad；新增 `AutoLedgerTV` / `AutoLedgerVision` target；为主 App 的 iOS Extension 和 Watch embed 项增加 iOS platform filter，避免 Mac Catalyst 包嵌入 iOS / watchOS 内容。
  - `AutoLedger/AutoLedger/Domain/Services/GemmaService.swift`：Mac Catalyst 下跳过 MediaPipe import 和模型加载，返回受控不可用状态。
  - `AutoLedger/Podfile`、`AutoLedger/Podfile.lock`：保留 iOS MediaPipe 依赖，调整 Pods xcconfig，使 MediaPipe / OpenGLES link flags 只作用于 iPhoneOS / iPhone Simulator，Mac Catalyst 使用基础系统 framework link flags。
  - `AutoLedger/AutoLedgerTV/`、`AutoLedger/AutoLedgerVision/`、`AutoLedger/Packages/RealityKitContent/`：保留 Xcode 新 target 生成的模板入口，作为后续 tvOS / visionOS 只读展示平台基线。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录本轮实际状态、验证和阻断项。
- 未改动范围：未修改主 App、Watch App、Extension 的 Bundle ID；未修改 `DEVELOPMENT_TEAM`、App Group、iCloud Container、entitlements、scheme 名称或 Xcode Cloud 脚本；未向 App Store Connect 添加新平台；未实现 tvOS / visionOS 产品 UI。
- 完成内容：
  - 主 App iOS generic Debug build 继续通过。
  - 主 App Mac Catalyst Debug build 通过。
  - Mac Catalyst 下不再尝试链接不可用的 MediaPipe 二进制，也不会嵌入 iOS Share / Widget / ControlWidget extension 或 watchOS app。
  - tvOS / visionOS target 已进入 workspace scheme 列表，可作为后续只读展示平台开发入口。
- 未完成内容：tvOS / visionOS 当前仍是模板 target；本机未安装 tvOS 26.5 / visionOS 26.5 platform runtime，无法执行 simulator build smoke；tvOS 真机开发仍需要开发者账号下可用 Apple TV 设备 UDID / profile。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' build`。
  - BLOCKED：`AutoLedgerTV` / `AutoLedgerVision` 本机 simulator build，原因是当前 Xcode 未安装 tvOS 26.5 / visionOS 26.5 platform runtime。
- 风险与注意事项：Mac Catalyst 当前是“可构建基线”，不等于 Mac 功能完成；Gemma / MediaPipe 在 Catalyst 下暂不可用，后续 Mac 导入和解析链路需要继续依赖规则解析、Core 解析或另行评估桌面端 AI 能力。tvOS / visionOS 不应加入 ASC 平台，直到目标 UI、截图和 archive smoke 完成。
- 回滚方式：关闭主 App `SUPPORTS_MACCATALYST`，移除新 target 及本轮 Pods / Gemma / embed platform filter 调整，恢复到 GOAL-1570 评估完成但未启用 Catalyst 的状态。
- 结论：全平台 target 基线已建立，Mac Catalyst 已具备继续推进 GOAL-1571 的构建基础；tvOS / visionOS 进入“target 已建、runtime 待装、产品 UI 待实现”的状态。
- 下一步建议：继续 GOAL-1571 Mac 拖拽截图 / 文件导入；另行安装 tvOS / visionOS Xcode Components 后再做展示端 target smoke。

### ITER-149 全平台截图管线顺延决策
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 11 路线调整
- 类型：产品决策 / 文档 / 治理
- 目标：根据 iPad 主线与后续 Mac Catalyst 商店页需求，调整截图管线推进策略，避免先做 iPad 临时管线再为 Mac / tvOS / visionOS 返工。
- 改动范围：
  - `versions/v1.5.0-plan.md`：将“iPad 截图管线”调整为“全平台截图管线”；GOAL-1590 / GOAL-1591 改为全平台设计与实现；截图管线等待 iPad、Mac、tvOS、visionOS 关键页面稳定后统一推进。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮路线调整。
- 未改动范围：未修改截图脚本、截图 host、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 明确 iPad 截图不再作为 Mac Catalyst 前置任务。
  - 明确全平台截图输出需要覆盖 iPhone、Watch、iPad、Mac、tvOS 和 visionOS 的平台分组、locale、fixture 和 `preview.html`。
  - 当前推进顺序改为：iPad 主线收口后继续 Mac Catalyst；截图管线进入全平台发布收口阶段。
- 未完成内容：未实现任何新截图导出能力；未生成 iPad / Mac / tvOS / visionOS 截图。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：截图管线不能拖到发布最后一天；进入全平台发布收口前需要提前为各平台准备稳定演示数据和人工目检时间。
- 回滚方式：恢复 GOAL-1591 为 iPad-only 截图实现，并将 iPad 截图重新放回 Mac Catalyst 前置任务。
- 结论：截图管线已调整为全平台后段统一推进，当前可以继续进入 Mac Catalyst 主线。
- 下一步建议：按 GOAL-1571 开始 Mac 拖拽截图 / 文件导入设计与最小实现，同时继续保持 iPad 主线不引入新的样例数据。

### ITER-148 iPad 批量队列真实导入入口与样例移除
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / Phase 5 收口
- 类型：能力增强 / iPad / SwiftUI
- 目标：继续收口 iPad 主线，移除批量导入工作台内置样例队列，并让用户选择的图片 / 文本文件能进入识别队列。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：新增 iPad 批量队列 `fileImporter` 多选入口；图片文件先跑 Vision OCR 后生成 raw input，文本文件读取为 raw text，PDF / 不支持文件进入需处理状态；默认队列从内置样例改为空队列。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐选择文件、导入中、文件导入结果文案，并移除 iPad 批量队列专用样例文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 iPad 队列默认空状态、真实文件入口和剩余边界。
- 未改动范围：未新增 SQLite 候选队列表，未做候选队列持久化，未实现 PDF OCR，未改变确认入账链路，未修改 iPhone 首页、CloudKit schema、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - iPad 导入 / 候选队列启动时不再显示内置样例账单。
  - 用户可通过“选择文件”批量选择图片、文本或 PDF。
  - 图片文件经 OCR 后进入待识别队列，文本文件直接进入待识别队列。
  - PDF 和暂不支持文件进入需处理状态，不会假装已识别或直接写入正式账本。
  - 队列项仍需用户点击“开始识别”生成候选，再复核确认后才写入正式账本。
- 未完成内容：队列仍为内存态；App 重启后不保留候选队列；PDF OCR、文件夹导入、拖拽导入和候选持久化仍待后续。
- 测试情况：
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：图片 OCR 仍在导入动作中执行，真机大批量图片可能需要后续补进度、取消和节流；当前文件入口是 iPad 主线产品化收口，不代表 Mac 拖拽导入已完成。
- 回滚方式：移除 `fileImporter`、文件导入按钮和 `importSelectedFiles` / `importFileAsRawInput` / `appendBatchRawInputs`，恢复空队列 UI 或回到 GOAL-1552 状态。
- 结论：iPad 批量队列已移除内置样例数据，并具备真实文件进入候选队列的第一版入口。
- 下一步建议：用户有明确需求场景后再真机 iPad 测试图片文件、文本文件、PDF 选择和“开始识别 -> 候选复核 -> 确认入账”链路；截图管线已调整为全平台后段统一推进，当前继续进入 Mac Catalyst。

### ITER-147 v1.5.0 全平台单账本路线调整
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：路线调整 / Phase 6 顺延
- 类型：产品决策 / 文档 / 治理
- 目标：将多账本从当前 v1.5.0 执行范围中搁置，先按全平台共享同一个正式账本推进，降低同步和跨平台发布复杂度。
- 改动范围：
  - `versions/v1.5.0-plan.md`：更新版本定位、目标、验收口径、风险、推荐推进顺序和 GOAL 队列；GOAL-1560～1562 改为后续版本顺延。
  - `README.md`：Roadmap 删除 v1.5.0 的多账本承诺，改为后续版本规划。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮路线调整。
- 未改动范围：未修改 Swift 源码、SQLite schema、CloudKit schema、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - v1.5.0 统一为单一正式账本口径，所有活跃正式账单视为同一账本。
  - iPhone / iPad / 后续 Mac 可写端围绕同一账本同步；Apple Watch 作为轻写入端回传同一账本；Widget / tvOS / visionOS 只读展示同一同步后快照。
  - 多账本模型、账本归属字段、账本管理 UI、按账本统计和账单移动从当前队列移出，保留为 v1.6.0+ 候选规划。
  - GOAL-1552 后的下一步从 GOAL-1560 改为跳过 Phase 6，进入 Mac Catalyst / 展示平台 / 截图管线等单账本可推进任务。
- 未完成内容：未重写早期 GOAL-1501 / GOAL-1503 的历史记录；这些仍作为曾经评估过的 schema 方案保留。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：后续如果恢复多账本，需要重新评审 CloudKit schema、BackupBundle、截图素材、Watch / Widget 口径和历史账单迁移；当前 v1.5.0 不应在 UI 或 README 中承诺多账本。
- 回滚方式：将 `versions/v1.5.0-plan.md` 中 GOAL-1560～1562 恢复为当前队列，并恢复 README / CHANGELOG / iteration-log 对多账本的 v1.5.0 承诺。
- 结论：v1.5.0 当前阶段按单一正式账本推进，多账本进入后续版本。
- 下一步建议：跳过 GOAL-1560～1562，按调整后的队列继续推进 Mac Catalyst 或截图管线相关 GOAL。

### ITER-146 GOAL-1552 数据清洗应用与回滚策略
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 5 / 数据清洗与候选复核
- 类型：能力增强 / iPad / LedgerStore / 测试
- 目标：在 GOAL-1551 的影响范围预览之后，提供用户确认后的数据清洗应用入口，并保留可恢复路径。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `applyDataCleaningPreview(_:)`、`undoLastDataCleaningApplication()`、最近一次应用结果和内存撤销快照；清洗写入使用专用路径，避免普通编辑自动学习反向规则。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：数据清洗详情页新增确认应用、重复项软删除说明、最近一次结果和撤销上次清洗按钮。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐清洗应用、确认、撤销和结果文案。
  - `scripts/OfflineRegression.swift`：新增商户统一应用 / 撤销、分类清洗应用、疑似重复软删除 / 撤销断言。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1552 完成范围和未做边界。
- 未改动范围：未新增 SQLite 清洗历史表、长期审计日志、BackupBundle 清洗历史 schema、多账本归属字段、OCR 文本相似重复合并或永久删除重复项；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 商户统一和分类修正可在 iPad 端确认后批量写入受影响正式账单。
  - 疑似重复只会保留较新的账单，将较旧账单软删除到“最近删除”，用户仍可恢复。
  - 最近一次清洗可通过 session 内快照撤销，撤销时只恢复实际改变过的账单，避免无意义增加全账本 sync revision。
  - 应用成功后统一触发排序、Widget 刷新、自动备份和 iCloud 增量推送。
  - 应用失败时尝试恢复应用前快照，避免半写入留在 UI 状态中。
- 未完成内容：撤销快照不跨 App 重启；没有持久化清洗历史表；重复检测仍是商户 / 金额 / 时间窗口，不含 OCR 文本相似度；多账本清洗范围已顺延到后续版本，不再阻塞 v1.5.0。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前清洗应用会触发正常的本地账本更新和 iCloud 增量推送；真机测试时建议先用少量可恢复样例验证“应用 / 撤销 / 最近删除恢复”链路。撤销只覆盖最近一次清洗，不是长期审计能力。
- 回滚方式：移除 `LedgerStore` 的数据清洗应用 / 撤销 API，删除 iPad 数据清洗操作区和对应本地化 key，回退新增离线断言，恢复 GOAL-1551 的只读预览状态。
- 结论：GOAL-1552 第一版完成，Phase 5 已具备候选入账、清洗预览、确认应用和最近一次撤销的最小闭环。
- 下一步建议：多账本已顺延；进入下一轮前先考虑提交当前 Phase 4 / Phase 5 变更，再按单账本路线推进 Mac Catalyst、展示平台或截图管线相关 GOAL。

### ITER-145 GOAL-1551 数据清洗规则预览
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 5 / 数据清洗与候选复核
- 类型：能力增强 / iPad / Core 规则预览
- 目标：在不静默修改历史账单的前提下，让 iPad 数据清洗页先展示商户统一、分类修正和疑似重复的影响范围。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/DataCleaningPreviewPlanner.swift`：新增纯 Foundation 预览规划器，输出 merchant alias、category correction、duplicate candidate 三类预览。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：数据清洗入口从规划占位页改为真实预览页，展示摘要、预览列表、详情和受影响账单。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐数据清洗预览中英繁文案。
  - `scripts/run_offline_regression.sh`、`scripts/OfflineRegression.swift`：将预览规划器纳入离线回归，并覆盖三类预览断言。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1551 完成范围和未做边界。
- 未改动范围：未实现批量应用、撤销栈、清洗历史持久化、SQLite schema 变更、CloudKit schema 变更、多账本归属字段或真实重复合并；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 商户别名预览会显示原商户、目标商户和受影响账单。
  - 分类修正预览会显示当前分类、建议分类和受影响账单。
  - 疑似重复预览会基于标准化商户、金额和 60 秒时间窗口展示候选组，不自动删除或合并。
  - iPad 数据清洗页明确标注为预览，不提供写入按钮。
- 未完成内容：清洗动作应用、事务写入、失败回滚和清洗记录追踪顺延到 GOAL-1552；候选队列持久化仍未接入。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前重复检测是保守的同商户 / 同金额 / 近时间窗口预览，仍可能漏掉 OCR 文本相似但字段不同的重复账单；本轮只读展示不会影响真实历史账单。
- 回滚方式：删除 `DataCleaningPreviewPlanner.swift`，将 iPad 数据清洗入口恢复为规划占位页，从离线脚本移除预览断言，并回退本轮新增本地化和文档记录。
- 结论：GOAL-1551 第一版完成，iPad 数据清洗已经具备确认前影响范围预览。
- 下一步建议：进入 GOAL-1552，围绕批量应用、事务写入、变更记录和可恢复路径推进。

### ITER-144 GOAL-1550 候选账单复核与正式入账
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 5 / 数据清洗与候选复核
- 类型：能力增强 / iPad / SwiftUI / Core 状态流
- 目标：让 iPad 识别队列中的候选账单可以被用户编辑、确认入账或忽略，守住“用户确认后才写入正式账本”的边界。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：新增候选账单编辑草稿；右侧详情支持编辑商户、金额、时间、分类、来源和备注；新增“确认入账”和“忽略候选”动作。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐确认入账、忽略候选、字段校验和结果提示文案。
  - `scripts/OfflineRegression.swift`：补充候选项 converted / rejected 状态断言。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1550 完成范围和未做边界。
- 未改动范围：未实现候选队列 SQLite 持久化、真实多文件 picker、PDF OCR、批量应用、撤销栈或复杂重复账单合并；未修改 iPhone `InboxView`、OCR、CloudKit schema、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 候选账单字段可在 iPad 右侧检查器内直接编辑。
  - 商户为空或金额无效时禁用确认入账，并显示校验提示。
  - 确认入账会构造正式 `Transaction` 并调用 `LedgerStore.addTransaction(_:)`，复用既有 SQLite 保存、Widget 刷新和 iCloud 增量推送链路。
  - 入账成功后队列项进入 `transaction` 状态并记录 `convertedTransactionID`。
  - 忽略候选会进入 `rejected` 状态，不写入正式账本。
- 未完成内容：队列仍是内存状态，App 重启后不会保留候选；重复账单目前仍是警示与人工判断，不做自动合并；真实多文件与 PDF 入口仍未接入。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
- 风险与注意事项：本轮确认入账使用正式 `LedgerStore.addTransaction`，因此候选入账会触发正常的本地保存和 iCloud 增量推送；真机测试时应确认候选队列只保存用户导入的真实项目，不应出现内置样例。
- 回滚方式：移除 `IPadBatchCandidateDraft`、候选字段编辑表单、确认 / 忽略按钮和离线断言，恢复候选详情只读展示。
- 结论：GOAL-1550 第一版完成，iPad 候选队列已经具备“复核后入账”的核心闭环。
- 下一步建议：进入 GOAL-1551，做数据清洗规则预览，或先按真机反馈微调候选检查器布局。

### ITER-143 iPad 导入页与识别队列分离
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：能力增强 / iPad / SwiftUI
- 目标：解决 iPad 导入页展示不全、导入操作和查看队列混在一起、两个“开始识别”按钮造成歧义的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：导入页仅展示支付账单导入、语音快捷记账和识别队列入口；队列筛选、队列列表、候选详情和“开始识别”仅在识别队列 / 候选账单页面展示。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：新增“查看队列 / Show Queue”文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录导入页职责收口和后续 GOAL-1550 边界。
- 未改动范围：未实现真实多文件 picker、PDF OCR、候选编辑、确认入账、队列持久化；未修改 iPhone `InboxView`、OCR、LedgerStore 入账链路、SQLite schema、CloudKit、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - “导入”页不再显示筛选条、队列列表和详情面板，首屏只承载导入入口。
  - “识别队列 / 候选账单”页保留唯一的“开始识别”按钮，并承载队列筛选、识别结果和详情检查。
  - 导入页的“查看队列”按钮会切换到队列页，避免用户在导入页误以为可以同时完成全部批处理。
- 未完成内容：真实候选账单字段编辑、确认入账、忽略和重复账单处理仍按 GOAL-1550 推进。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前导入页中的识别队列摘要来自内存队列，不代表真实持久化队列；GOAL-1550 / 后续持久化前需要继续明确这是候选工作台，不是正式账本。
- 回滚方式：恢复 `showsImportActions` 模式下同时渲染 `filterBar`、`queueList` 和 `detailPane`，并恢复导入页卡片中的“开始识别”按钮。
- 结论：iPad 导入页和识别队列职责已经分开，第四批可以在队列页上继续推进候选复核与正式入账。
- 下一步建议：进入 GOAL-1550，围绕队列页补候选字段编辑、确认入账、忽略和重复提示。

### ITER-142 iPad 工作台菜单切换性能收口
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：Bugfix / iPad / SwiftUI 性能
- 目标：降低 iPad 工作台点击左侧主菜单时的明显卡顿，同时保留设置页进入内部页面后再切换主菜单能够刷新右侧内容的修复。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：移除 detail 区域的全局 `.id(selection)`；新增 `select(_:)` 统一切换入口；仅在离开设置页时刷新 `SettingsView` 的局部 identity。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录卡顿原因、修复边界和验证结果。
- 未改动范围：未修改 iPhone 首页、iPad 导入 / 账本 / 分析业务逻辑、OCR、批量识别执行器、SQLite、CloudKit 同步、Watch / Widget、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 普通主菜单切换不再触发整个 detail view tree 销毁重建。
  - 设置页内部 push 后切换到其他主菜单仍会显示对应右侧页面。
  - 从其他页面再次进入设置页时会回到设置根视图，避免保留旧的内部导航栈。
- 未完成内容：尚未在真机 iPad 上做主观流畅度复测；若仍有卡顿，需要继续用 Instruments / SwiftUI template 定位具体页面初始化成本。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：本轮修的是“切换时被迫整页重建”的主要卡顿源；各页面自身的统计计算、列表排序或首屏渲染成本仍可能在低性能设备上产生轻微延迟。
- 回滚方式：若设置页导航状态再次异常，可恢复 detail 的 `.id(selection)`；若只是设置页重置策略不合适，可仅回退 `settingsResetID` 与 `select(_:)` 中的设置页局部 identity 逻辑。
- 结论：iPad 主菜单切换的主要强制重建点已移除，代码侧可以进入真机复测。
- 下一步建议：在真机 iPad 上连续切换“导入 / 账本 / 分析 / 设置 / 数据清洗”，确认右侧页面切换和滚动响应是否明显改善；通过后进入 GOAL-1550。

### ITER-141 iPad 导入 Tab 专用 UI 收口
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：能力增强 / iPad / SwiftUI
- 目标：让 iPad “导入”Tab 不再复用 iPhone 首页型 `InboxView`，只展示 iPad 工作台需要的导入动作、语音入口和批量队列操作。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：移除 iPad 批量导入页中的 `InboxView` sheet；新增 iPad 专用导入动作区，内联提供相册、拍照、剪贴板、语音快捷记账、识别队列和查看候选入口；保留候选队列和详情检查器。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：新增 iPad 导入专用标题和三语文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 iPad 导入页不再复用 iPhone 首页的边界。
- 未改动范围：未修改 iPhone `InboxView`、iPhone 首页体验、OCRService、LedgerStore 入账链路、批量队列模型、SQLite schema、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - iPad 导入 Tab 不再展示 iPhone 首屏大标题、本月支出、Top 商户、快捷指令设置卡片和最近解析列表。
  - 支付账单导入仍可从相册、相机和剪贴板进入现有 OCR -> 正式入账链路。
  - 语音快捷记账从 iPad 导入页打开 `VoiceLedgerConfirmView`。
  - 识别队列入口继续提供“开始识别”和“查看候选”，承接 GOAL-1542；当前仍是内存候选队列，不代表真实多文件导入已接入。
- 未完成内容：未实现 iPad 真实多文件 picker、PDF OCR、拖拽导入、候选持久化和候选确认入账。
- 测试情况：
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前 iPad 导入页的相册 / 拍照 / 剪贴板仍是单张直接入账路径，批量队列仍是内存候选路径；两条链路在 GOAL-1550 前保持分离。
- 回滚方式：恢复 `IPadBatchImportWorkspaceView` 的 `InboxView` sheet 和 `selectedTabBinding`，删除 iPad 导入动作区及新增本地化 key，并回退文档记录。
- 结论：iPad 导入 Tab 已从 iPhone 首页复用收口为专用导入 UI。
- 下一步建议：进入 GOAL-1550，把批量候选复核、字段编辑和确认入账补齐。

### ITER-140 GOAL-1542 批量 OCR / 文本解析执行器
- 日期：2026-06-04
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：能力增强 / Core 服务 / iPad / 测试
- 目标：把 GOAL-1540 的批量导入队列从静态展示推进到可执行识别，让已有文本 / OCR 文本的队列项可以生成候选账单，并继续保证用户确认前不写入正式账本。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/BatchImportRecognitionExecutor.swift`：新增批量识别执行器、识别结果和识别日志，逐条调用 `LedgerTextInterpreterCore` 生成候选或失败状态。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：iPad 批量导入工作台新增“开始识别”、单项重试、识别摘要和详情日志；队列默认空状态，真实导入项进入后可执行内存识别。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐批量识别按钮、摘要和日志文案。
  - `scripts/run_offline_regression.sh`、`scripts/OfflineRegression.swift`：将执行器纳入离线编译并新增批量识别回归。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1542 完成范围和第三批收尾判断。
- 未改动范围：未实现真实多选文件 picker、图片 / PDF Vision OCR 队列、SQLite 候选持久化、候选编辑、确认入账、忽略或重复处理；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 文本、剪贴板、分享、快捷指令以及已带 OCR 文本的相册 / 拍照队列项可以进入 `LedgerTextInterpreterCore` 并生成候选账单。
  - 空文本、没有 OCR 文本的图片 / 拍照输入、无文本文件会进入可诊断失败状态，保留重试路径和识别日志。
  - iPad 工作台可以手动执行整队识别，也可以只重试选中的失败项。
  - 离线回归确认执行器不会向正式账本写入交易，候选入账边界仍留给 GOAL-1550。
- 未完成内容：真实图片 OCR 执行、PDF 文本抽取、队列落库、候选字段编辑、确认入账和批量清洗仍未实现。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前执行器处理的是已经存在的文本，不代表原始图片 / PDF 批量 OCR 已完成；队列仍是内存状态，App 重启后不会保留候选。
- 回滚方式：移除 `BatchImportRecognitionExecutor.swift`，从 iPad 工作台删除“开始识别”和单项执行逻辑，从离线脚本移除对应编译与断言，并回退本轮本地化与文档记录。
- 结论：GOAL-1542 代码侧完成，第三批 iPad 工作台与候选队列链路可以收尾。
- 下一步建议：进入 GOAL-1550，做候选账单复核、字段编辑和用户确认后的正式入账。

### ITER-139 Watch accessory corner 样式修正
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / iPhone 与 Watch Widget
- 类型：Bugfix / Widget / watchOS
- 目标：根据真机表盘截图修正 Apple Watch accessory corner 组件，让今日支出金额与支出程度条更接近系统天气角落组件的读数结构。
- 改动范围：
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/AutoLedgerWatchWidgetsExtension.swift`：将 corner 收口为两个可选 Widget 版本。默认 `AutoLedgerWatchDailyExpenseWidget` 的 corner 显示大号 `xx.xx` 金额并保留系统边缘色条；新增 `AutoLedgerWatchCornerTextWidget` 仅支持 `.accessoryCorner`，主体显示 `¥` 图标，边缘 label 显示“今日支出：xx.xx”。
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/AutoLedgerWatchWidgetsExtensionBundle.swift`：将第二个 corner-only Widget 注册进 Watch Widget bundle。
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐第二个 Widget 的展示名、描述和边缘文字格式。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录真机反馈修正与验证结果。
- 未改动范围：未修改 Widget family、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、WatchConnectivity、App Group 快照数据源或 Xcode Cloud 脚本。
- 完成内容：
  - accessory corner 不再在小内容区域内自绘水平支出条。
  - 真机验证显示 `.widgetLabel` 中的系统 `Gauge` 可稳定沿表盘边缘显示支出程度条。
  - 真机验证也显示系统 `Gauge` 自动读数无法稳定复刻官方天气角落样式，因此不再继续押注纯系统读数。
  - 默认 corner 版移除金额前缀 `¥`，放大 `xx.xx` 主体读数并填满角落内容区。
  - 新增文字 corner 版让边缘 label 承载“今日支出：xx.xx”，用于需要更完整语义的表盘。
- 未完成内容：尚未在真实 Apple Watch 或 Apple Watch Simulator 表盘上手动添加 corner complication 目检边缘渲染；当前完成代码侧修正与构建验证。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)' build`。
  - PARTIAL：Apple Watch Ultra 3 Simulator 中 Watch App bundle 可安装并可 launch；CLI 截图停在模拟器主屏，未能自动完成表盘 corner complication 添加与边缘样式截图。
- 风险与注意事项：`simctl` 当前没有直接把指定 complication 自动添加到表盘角落的命令，边缘渲染仍需手动在表盘上添加后目检；新增第二个 Widget 后，表盘复杂功能选择列表可能需要重新安装 Watch App 或稍等系统刷新。
- 回滚方式：从 `AutoLedgerWatchWidgetsExtensionBundle` 移除 `AutoLedgerWatchCornerTextWidget`，并将 `cornerView` 恢复为单一主体金额 + 系统色条。
- 结论：代码侧已按真机反馈修正 accessory corner 样式。
- 下一步建议：重新 Run Watch App / Widget 后，在真实 Apple Watch 表盘添加 corner complication 目检。

### ITER-138 GOAL-1541 iPad 批量导入 UI
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：能力增强 / iPad / SwiftUI
- 目标：把 GOAL-1540 的队列模型展示到 iPad 工作台中，让“导入”和“候选账单”不再只是规划入口，并保留当前单张导入路径。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：新增 iPad 批量导入工作台、状态筛选、队列列表、详情检查器、疑似重复展示和重试入口；`.capture` 与 `.reviewQueue` 入口接入同一工作台。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐新增 UI 文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录完成范围与验证结果。
- 未改动范围：未接真实文件 picker、OCR 执行器、SQLite 持久化、候选编辑 / 确认入账；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - iPad “导入”入口默认展示全部批量队列。
  - iPad “候选账单”入口复用同一工作台并默认筛选待复核候选。
  - UI 可展示待识别、待复核、需处理、疑似重复等状态，以及候选字段、置信度、失败原因和 warning。
  - 对可重试 item 提供重试入口并在 UI 中标记重试状态。
  - “单张导入”按钮弹出既有 `InboxView`，保留当前真实截图 / 拍照 / 剪贴板导入路径。
- 未完成内容：真实批量图片 / 文件选择、OCR / 文本解析批处理、候选队列持久化、确认入账和批量编辑尚未实现。
- 测试情况：
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`。
- 风险与注意事项：当前版本已移除 iPad 内置队列样例；后续接更多真实输入时仍需要避免大批量 OCR 阻塞主线程。
- 回滚方式：将 `.capture` 恢复为 `InboxView(selectedTab:)`，将 `.reviewQueue` 恢复为 `IPadPlanningWorkspaceView`，删除 `IPadBatchImportWorkspaceView` 和新增本地化 key，并回退文档记录。
- 结论：GOAL-1541 代码侧完成，iPad 导入页已从纯复用单导入推进到批量队列工作台第一版。
- 下一步建议：进入 GOAL-1542，将 OCR / `LedgerTextInterpreterCore` 执行器接入队列，并设计批处理节流与进度反馈。

### ITER-137 GOAL-1540 批量导入队列模型
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 4 / 批量导入与识别队列
- 类型：能力增强 / Core 模型 / 测试
- 目标：建立 iPad 批量导入、Mac 拖拽导入和候选账单复核共用的队列模型，让导入项可以从原始输入进入候选状态，并保证用户确认前不污染正式账本。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/BatchImportQueue.swift`：新增 batch、raw input、queue item、状态、失败原因、warning、重试、疑似重复和 reviewed / transaction 转换模型。
  - `scripts/run_offline_regression.sh`：将新模型纳入离线回归编译。
  - `scripts/OfflineRegression.swift`：新增批量导入队列状态断言。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1540 完成范围和下一步边界。
- 未改动范围：未新增 SQLite 表，未升级 BackupBundle，未修改 iPad UI、OCR 执行器、Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：
  - 原始输入可创建 `rawInput` item，不进入正式账本。
  - 高置信解析结果进入 `candidate`，保留结构化草稿但不自动保存。
  - 缺金额、缺商户、缺日期、低置信和疑似重复会进入可复核候选状态并记录原因。
  - 非账单和不支持类型可以进入 rejected。
  - reviewed / converted 状态边界固定，只有带 `convertedTransactionID` 的 item 才算正式账本输出。
- 未完成内容：iPad 批量导入 UI、队列持久化、批量 OCR / 文本解析执行器、候选账单正式入账和重复处理 UI 均未实现。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前模型仍是内存 / Codable 契约，后续落 SQLite 时需要保持 additive migration；iPad 当前“导入”Tab 仍复用既有 `InboxView` 单导入能力，不代表批量导入 UI 已完成。
- 回滚方式：删除 `BatchImportQueue.swift`，从 `run_offline_regression.sh` 和 `OfflineRegression.swift` 移除对应编译与断言，并回退文档记录。
- 结论：GOAL-1540 代码侧完成，批量导入已有平台无关队列模型，正式账本污染边界清晰。
- 下一步建议：进入 GOAL-1541，基于该模型实现 iPad 批量导入 UI：导入箱、状态筛选、失败重试入口和候选列表。

### ITER-136 GOAL-1532 iPad 统计分析基础页
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 3 / iPad 工作台
- 类型：能力增强 / iPad / 统计分析
- 目标：在第一批、第二批代码侧完成后进入第三批剩余 GOAL，为 iPad 工作台补齐基础统计分析页，并保持 iPhone 月报原路径不回退。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：将 iPad 侧“分析”入口切换为 `IPadReportWorkspaceView`，新增宽屏布局，复用 `MonthlySnapshot` 展示当前月份总支出、账单数、Top 商户、商户数、分类占比、近 6 个月趋势和本月摘要。
  - `AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`：补齐 iPad 分析页新增文案。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1532 完成范围和验证结果。
- 未改动范围：未修改 iPhone `ReportView`、`MonthlySnapshot` 统计模型、SQLite schema、CloudKit 同步、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、scheme、target 或 Xcode Cloud 脚本。
- 完成内容：
  - iPad 工作台“分析”页拥有独立宽屏统计视图，不再直接套用 iPhone 月报纵向页面。
  - 统计口径继续复用 `MonthlySnapshot.build(from:referenceDate:)`，与 iPhone 月报保持一致。
  - 支持月份前后切换；未来月份按钮禁用。
  - 分类占比与 Top 商户以进度条展示，近 6 个月趋势使用 Charts BarMark，点击月份可查看该月金额和账单数。
- 未完成内容：未新增 iPad 专属截图管线；未新增统计模型测试；未进入批量导入队列、候选账单或数据清洗实现。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedger/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前验证为 generic iOS build，尚未在真机 iPad 横竖屏目检；iPad 分析页依赖现有 `MonthlySnapshot`，因此任何统计口径修正仍应优先在 Core 层处理。
- 回滚方式：将 iPad `.reports` detail 从 `IPadReportWorkspaceView()` 切回 `ReportView()`，删除新增 iPad 分析子视图和对应本地化 key，并回退文档记录。
- 结论：GOAL-1532 代码侧完成，第三批 iPad 工作台的基础统计分析页已具备可构建的第一版。
- 下一步建议：进入 GOAL-1540，先实现批量导入队列模型，让 iPad 导入、Mac 拖拽导入和候选账单复核都有共同落点。

### ITER-135 GOAL-1521B2 watchOS 表盘小组件 target 接入
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / iPhone 与 Watch Widget
- 类型：能力增强 / Widget / watchOS
- 目标：在用户已通过 Xcode 默认配置新增 Watch Widget target 后，接入真实 AutoLedger 今日支出表盘小组件，并保证 Watch App、主 App 和 Xcode Cloud 发布链仍可构建。
- 改动范围：
  - `AutoLedger/AutoLedger.xcodeproj/project.pbxproj`：保留 Xcode 默认生成的 `AutoLedgerWatchWidgetsExtensionExtension` target 名；补齐 watchOS supported platforms；保持 Bundle ID `top.darkrio326.AutoLedger.watchkitapp.widgets`，并将 extension marketing version 对齐当前 Watch App `1.4.0`。
  - `AutoLedger/AutoLedgerWatch Watch App/AutoLedgerWatch Watch App.entitlements`、`AutoLedger/AutoLedgerWatchWidgetsExtensionExtension.entitlements`：保留用户新增的 `group.top.darkrio326.AutoLedger` App Group。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`：收到 iPhone 今日支出 payload 或主动拉取回复后，将轻量 summary 写入 Watch App Group，并触发 Watch Widget timeline 刷新。
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/AutoLedgerWatchWidgetsExtension.swift`：替换模板 emoji widget，新增 accessory inline / circular / rectangular / corner 今日支出表盘展示。
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/AutoLedgerWatchWidgetsExtensionBundle.swift`：只注册真实 AutoLedger Watch Widget。
  - `AutoLedger/AutoLedgerWatchWidgetsExtension/AppIntent.swift`、`AutoLedger/AutoLedgerWatchWidgetsExtension/AutoLedgerWatchWidgetsExtensionControl.swift`：移除 Xcode 模板生成的 Timer Control Widget / Emoji 配置示例。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`、`process/iteration-log.md`：记录 GOAL-1521B2 完成范围和人工验证项。
- 未改动范围：未修改主 App / Watch App / iPhone Widget / Share Extension / Control Widget 既有 Bundle ID、DEVELOPMENT_TEAM、iCloud Container、主 App scheme、Watch App scheme、App Store 发布脚本或 CloudKit 同步逻辑；未让表盘 Widget 直接读取 iPhone SQLite 或直接连接 CloudKit。
- 完成内容：
  - 新 watchOS Widget target 已能作为 Watch App 依赖构建并嵌入 `AutoLedgerWatch Watch App.app/PlugIns`。
  - 表盘 Widget 读取 `group.top.darkrio326.AutoLedger` 中的 `WatchLedgerWidget.todaySummary` 快照，展示今日支出金额、笔数、最近商户和待同步状态，覆盖 inline / circular / rectangular / corner。
  - Accessory circular 只显示今日金额；accessory corner 使用参考天气组件的线性彩色支出程度条，短金额放在系统角落主读数位置，隐藏 current / min / max 标签并用位置点表达当前支出；accessory rectangular 内容左对齐。
  - 表盘 Widget 展示名、描述、待同步、空状态和计数文案补齐简体中文、英文、繁体中文本地化。
  - Watch App 收到 iPhone WatchConnectivity 今日摘要后会写入该快照，并调用 `WidgetCenter.shared.reloadTimelines(ofKind:)` 刷新表盘 timeline。
  - 模板 Control Widget 与示例 AppIntent 已删除，避免发布包出现无关 “Timer” 控制。
- 未完成内容：未在真实 Apple Watch 表盘上人工添加 complication 目检；未实现隐私隐藏开关；未把 watchOS Widget 单独 scheme 固化为共享 scheme。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`plutil -lint AutoLedger/AutoLedgerWatchWidgetsExtension/{zh-Hans,en,zh-Hant}.lproj/Localizable.strings`。
  - PASS：`xcodebuild -project AutoLedger/AutoLedger.xcodeproj -target AutoLedgerWatchWidgetsExtensionExtension -configuration Debug build`，仅有无 scheme 时忽略 destination 与 `ONLY_ACTIVE_ARCH` 的 xcodebuild 提示。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：`xcodebuild -list` 会显示自动 scheme `AutoLedgerWatchWidgetsExtensionExtension`，但该单独 scheme 解析 destination 时偶尔按 iOS 自动 scheme 枚举；可靠门禁为直接 target 构建、Watch App scheme 构建和主 App scheme 构建。发布前仍需用 Xcode Cloud / Archive 验证完整签名。
- 回滚方式：移除 Watch Widget target 与嵌入关系，删除 `AutoLedgerWatchWidgetsExtension` 目录和 extension entitlements，恢复 `WatchSessionManager` 的 App Group 快照写入改动，并回退对应文档记录。
- 结论：GOAL-1521B2 代码侧完成，Watch 表盘小组件已具备可构建、可嵌入、可读取 Watch 同步快照的第一版闭环。
- 下一步建议：在真实 Apple Watch 表盘添加 `今日支出` complication，点验 inline / circular / rectangular / corner 四种样式和 iPhone 记账后的刷新延迟；通过后可继续 13.4 推荐推进顺序的下一批 GOAL。

### ITER-134 iCloud 启动同步先推后拉
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 同步链路
- 目标：根据真机同步测试中“未删除但记录消失”的反馈，修正 App 启动自动同步顺序，确保任何平台启动时先推送本机增量，再拉取远端。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`syncLedgerWithCloudKitOnLaunchIfNeeded()` 改为先调用本机增量推送；推送成功后清理外部入口 pending 标记，再拉取远端；推送失败时暂停本次拉取。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：移除启动同步后的额外 pending 补推调用，避免启动链路重复推送。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录风险判断、现行同步口径和真机复测步骤。
- 未改动范围：未修改 CloudKit schema、record type、字段、索引、SQLite schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、scheme、target 或 Xcode Cloud 配置。
- 完成内容：
  - App 启动且 iCloud 同步开启时，后台同步顺序变为“先推本机增量 -> 推送成功 -> 清理外部入口 pending -> 拉取远端”。
  - 如果本机增量推送失败，本次启动同步不会继续拉取远端，降低本机变更未上云时先合并远端状态的风险。
  - 手动“强制刷新数据”仍保持全量推送 + 拉取；账本页下拉刷新仍保持拉取远端。
- 未完成内容：未实现 CloudKit server change token、silent push、同步健康详情页或按 record 级别的冲突恢复 UI；未直接检查用户真机数据库内容。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：本轮修复启动顺序，不等于解决所有同步一致性问题；如果仍出现记录消失，需要继续检查远端 tombstone、push checkpoint、同一 transactionID 的历史状态和真机本地 SQLite 最近删除列表。
- 回滚方式：恢复 `syncLedgerWithCloudKitOnLaunchIfNeeded()` 为启动只拉取，恢复 `AutoLedgerApp` 启动后 pending 补推调用，移除对应文档记录。
- 结论：启动同步应改为先推后拉，符合用户对 iPhone / iPad 启动同步的直觉和数据保护优先级。
- 下一步建议：真机复测 iPhone 新增后立刻退出、重新启动推送，再到 iPad 拉取；反向也测一次。

### ITER-133 GOAL-1521B1 Widget 点击路径
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / iPhone 与 Watch Widget
- 类型：能力增强 / Widget / 导航
- 目标：按 `13.4 推荐推进顺序` 回补第二批未完成项，先在不新增 watchOS target 的前提下补齐今日支出 Widget 点击进入账本页的路径。
- 改动范围：
  - `AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift`：`DailyExpenseWidget` 增加 `autoledger://ledger/today` deep link。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：根视图接收 `autoledger://ledger/today`、`autoledger://ledger` 或 `autoledger://today` 后，复用现有 `QuickLedgerNavigationState` 和账本导航通知打开账本页。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录第二批回补、完成范围和 Watch 表盘 target 风险。
- 未改动范围：未新增 watchOS WidgetKit extension target；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 CocoaPods 配置。
- 完成内容：
  - iPhone 桌面今日支出 Widget 点击后进入账本页。
  - iPhone 负一屏 / Today View 今日支出 Widget 点击后进入账本页。
  - iPad 收到同一 deep link 时会切到账本工作区。
  - 冷启动和运行中两种状态都复用现有 pending navigation / notification 机制。
- 未完成内容：真正 Apple Watch 表盘小组件仍未完成，因为还没有 watchOS WidgetKit extension target、Watch App embedding、独立 Bundle ID 和 signing 验证。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerWidgetsExtension -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：`autoledger://ledger/today` 作为 Widget 跳转 URL 已接入 App 侧处理；仍需真机点按 iPhone 桌面 / 负一屏 Widget 验证系统传递 URL 的实际行为。本轮不为此新增 Info.plist URL Types 或修改 Xcode project 配置。
- 回滚方式：移除 `DailyExpenseWidget` 的 `.widgetURL(...)` 和 `AutoLedgerRootView.handleDeepLink(_:)`，恢复对应文档记录。
- 结论：本轮完成后，第二批仍未完全完成；剩余 blocker 是 GOAL-1521B2 watchOS WidgetKit extension target。
- 下一步建议：评估是否在受控分支新增 watchOS WidgetKit extension target；若暂不碰发布链，则继续把第二批状态保留为部分完成并进入第三批 GOAL-1532。

### ITER-132 GOAL-1570 Mac Catalyst 接入评估
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 8 / Mac Catalyst 生产力工作台
- 类型：文档 / 架构评估 / 发布链保护
- 目标：评估当前 iPad 工作台和同步底座推进到 Mac Catalyst 的可行性，输出复用资产、配置现状、主要风险和后续实施顺序，同时保护 iPhone / iPad / Watch 现有发布链。
- 改动范围：
  - `versions/v1.5.0-plan.md`：将 GOAL-1570 标记为已完成，新增 `13.41 GOAL-1570 Mac Catalyst 接入评估`，记录当前 Xcode 配置、可复用资产、Catalyst 风险、文件权限、菜单快捷键、大表格和推荐实施顺序。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮评估结果。
- 未改动范围：未修改 Swift 源码、Xcode project 配置、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 CocoaPods 配置；未开启 `SUPPORTS_MACCATALYST`。
- 完成内容：
  - 确认主 App 当前仍为 iPhone + iPad，`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`，`SUPPORTS_MACCATALYST = NO`。
  - 确认可复用资产包括 `AutoLedgerCore`、SQLite 正式账本与同步元数据、CloudKit private database 同步策略、BackupBundle、iPad `NavigationSplitView` 工作台和现有回归脚本。
  - 记录主要风险：MediaPipe / CocoaPods Catalyst 可用性、Mac 文件权限、导入队列缺失、菜单命令、大表格密度、同步性能和发布签名验证。
  - 明确推荐顺序：先完成 GOAL-1540 批量导入队列，再进入 GOAL-1571 Mac 拖拽导入，随后推进 CSV / JSON、菜单快捷键、大表格和重复检查。
- 未完成内容：未做 Catalyst build smoke；未开启 Mac destination；未实现 Mac 拖拽导入、菜单、快捷键或大表格。
- 测试情况：
  - PASS：`xcodebuild -list -workspace AutoLedger/AutoLedger.xcworkspace`，workspace 可列出 `AutoLedger`、`AutoLedgerCore`、Watch App、Widget、Control Widget、Pods、ReceiptDebugTool 和 ShareExtension schemes。
- 风险与注意事项：GOAL-1570 是评估完成，不代表 Mac Catalyst 已可构建或可发布；任何开启 Catalyst 的变更都应在独立分支先做 smoke。
- 回滚方式：恢复 `versions/v1.5.0-plan.md` 的 GOAL-1570 状态与新增评估章节，移除对应 CHANGELOG / iteration-log 条目。
- 结论：GOAL-1570 完成，当前 main 保持 iPhone / iPad / Watch 发布链不变；Mac Catalyst 下一步不应直接启用，而应先补批量导入队列。
- 下一步建议：回到依赖顺序先执行 GOAL-1540 批量导入队列模型，随后再进入 GOAL-1571 Mac 拖拽导入。

### ITER-131 GOAL-1566 Watch / Widget 同步快照收尾
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：文档 / 治理 / Watch / Widget
- 目标：把 GOAL-1566 从 Watch / Widget 快照元数据的部分完成状态收口为最小闭环完成，并将 tvOS / visionOS 展示端从 1566 中拆出给后续独立 GOAL。
- 改动范围：
  - `versions/v1.5.0-plan.md`：将 GOAL-1566 标记为已完成，新增 `13.40 GOAL-1566 收尾结论`，记录已完成范围、不再纳入 1566 的范围、真机检查口径和收尾判断。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮收尾决策。
- 未改动范围：未修改 Swift 源码、WatchConnectivity payload schema、Widget target、CloudKit schema、SQLite schema、entitlements、Bundle ID、App Group、iCloud Container、Xcode project、workspace、scheme、target 或 Xcode Cloud 脚本。
- 完成内容：
  - 确认 Watch 今日支出、Watch 最近支出、Widget 今日支出 / 月报小组件都读取主 App 同步后的本机稳定快照或 App Group 元数据。
  - 确认 Watch / Widget 已具备快照更新时间和轻量过期提示。
  - 确认 Watch 第二屏标题修复已纳入 1566 收尾范围。
  - 明确 tvOS / visionOS 展示端由 GOAL-1580～1583 单独承接，不作为 1566 的继续扩张项。
- 未完成内容：发布前仍需用户执行 iPhone Widget / Today View / Apple Watch 真机 smoke；未实现 tvOS / visionOS target。
- 测试情况：
  - PASS：`git diff --check`。
  - 说明：本轮为文档治理；承接上一轮已通过的离线回归和 generic iOS build。
- 风险与注意事项：GOAL-1566 的“已完成”指 Watch / Widget 最小同步快照闭环完成，不代表 tvOS / visionOS 已实现，也不代表 Watch 拥有完整 CloudKit 同步。
- 回滚方式：恢复 GOAL-1566 队列状态和新增收尾章节，移除对应 CHANGELOG / iteration-log 条目。
- 结论：GOAL-1566 可以收尾，避免基础同步目标继续扩张；后续进入 Mac Catalyst 评估和只读展示端独立设计。
- 下一步建议：执行 GOAL-1570 Mac Catalyst 接入评估。

### ITER-130 iCloud 同步真机体验修复
- 日期：2026-06-03
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 性能 / iPad / Watch
- 目标：根据真机反馈修复 iCloud 同步接入后的启动 UI 卡顿、iPad 设置页内部页面阻塞主菜单 detail 切换、Apple Watch 第二屏标题仍显示“今日支出”的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：App 启动时不再立即在根 `.task` 中触发 iCloud 拉取 / 外部入口补推和 Gemma 预热；改为首屏渲染后延迟 1.5 秒调度 iCloud 后台任务、延迟 2.5 秒调度 Gemma 预热，避免和首屏交互抢主线程。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：右侧 detail 增加 `.id(selection)`，切换侧边栏主菜单时重建右侧上下文，避免设置页内部 push 后右侧页面停留在旧子页。
  - `AutoLedger/AutoLedgerWatch Watch App/ContentView.swift`：Watch `TabView` 绑定当前页 selection，navigation title 根据当前页在“今日支出”和“最近支出”之间切换。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮真机反馈和修复结果。
- 未改动范围：未修改 CloudKit schema、SQLite schema、同步 record 字段、entitlements、Bundle ID、App Group、iCloud Container、Xcode project、workspace、scheme、target、WatchConnectivity 消息结构或 Xcode Cloud 脚本。
- 完成内容：
  - iPhone / iPad 启动后 iCloud 同步不会抢首屏立即执行，降低首屏 UI 无响应风险。
  - iPad 设置页进入内部页面后，点击其他主菜单项会刷新右侧 detail。
  - Apple Watch 左滑到最近支出页后，顶部标题会显示“最近支出”。
- 未完成内容：未做 Instruments / ETTrace 性能采样；启动卡顿修复以调度避让为第一步，仍需用户真机复测体感。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：启动 iCloud 拉取现在延后约 1.5 秒，首屏显示会更快，但最新远端数据到达会比原先略晚；这是为了保护启动交互，仍保留后台自动拉取。
- 回滚方式：恢复 `AutoLedgerApp` 直接在 `.task` 中启动同步 / Gemma 预热，移除 iPad detail `.id(selection)`，恢复 Watch 固定 navigation title。
- 结论：本轮修复完成，generic iOS Debug build 通过；建议用户在 iPhone、iPad、Apple Watch 真机重新安装后复测三条反馈路径。
- 下一步建议：真机确认卡顿和导航问题消失后，继续收口 GOAL-1566 或进入 GOAL-1570 Mac Catalyst 接入评估。

### ITER-129 GOAL-1566A Watch / Widget 同步快照元数据
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / Watch / Widget / 同步底座
- 目标：让 Watch 与 Widget 读取同一份主 App 本机账本快照元数据，避免只读端展示的更新时间只是 timeline / payload 生成时间，并在 iCloud 同步长时间未成功时显示轻量过期提示。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：在 App Group defaults 写入 `ledgerSnapshotUpdatedAt`、`lastSuccessfulCloudKitSyncAt` 和 iCloud 同步开关；本机账本快照刷新时 reload Widget 并触发 Watch payload。
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：Watch 今日摘要 payload 的 `updatedAt` 改用账本快照更新时间，并携带 `isSnapshotStale`。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchTransaction.swift`、`ContentView.swift`、三语 `Localizable.strings`：Watch 今日支出卡片支持“数据可能较旧”轻提示。
  - `AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift`：Widget 读取 App Group 快照元数据，今日支出和月报小组件显示轻量“较旧 / Stale”状态。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1566A 范围、状态和验证。
- 未改动范围：未修改 WatchConnectivity pending 草稿协议、Widget target 配置、CloudKit schema、SQLite schema、entitlements、Bundle ID、App Group、iCloud Container、Xcode project、workspace、scheme、target 或 Xcode Cloud 脚本；未让 Widget 直接访问 CloudKit。
- 完成内容：
  - Watch 和 Widget 都能读取主 App 写入的账本快照更新时间。
  - iCloud 同步开启但 12 小时内没有成功同步时，Watch / Widget 会展示轻量过期提示。
  - Widget 统计仍来自 App Group SQLite，Watch 仍来自 iPhone WatchConnectivity payload，数据口径保持 local-first。
- 未完成内容：未做真机 Watch / Widget 视觉 smoke；tvOS / visionOS 展示端快照仍未实现。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：过期判断当前使用 12 小时阈值，属于轻量健康提示，不阻止用户查看本机快照；如果后续引入 silent push / server change token，阈值和文案需要重新评估。
- 回滚方式：移除 App Group 快照元数据写入、Watch payload 的 `isSnapshotStale` 字段、Watch / Widget 过期提示 UI，恢复只显示本机统计。
- 结论：GOAL-1566A 完成，Watch / Widget 已接入主 App 账本快照元数据和轻量过期提示，编译与离线回归门禁通过。
- 下一步建议：验证通过后进行 iPhone Widget 与 Apple Watch 真机 smoke，再决定是否关闭 GOAL-1566 或进入 GOAL-1570。

### ITER-128 GOAL-1565 基础 iCloud 同步闭环收尾
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：文档 / 治理 / 同步底座
- 目标：把长期拆分推进的 GOAL-1565 从“部分完成”收口为“已完成”，明确当前 iPhone / iPad 基础 iCloud 同步闭环已满足 v1.5.0 最小交付要求，并把剩余平台和性能增强拆给后续 GOAL。
- 改动范围：
  - `versions/v1.5.0-plan.md`：将 GOAL 队列表中 `GOAL-1565` 标记为已完成，新增 `13.37 GOAL-1565 收尾结论`，列出已完成范围、不再纳入 1565 的范围和后续承接 GOAL。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮收尾决策。
- 未改动范围：未修改 Swift 源码、CloudKit schema、SQLite schema、entitlements、Bundle ID、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本。
- 完成内容：
  - 确认 1565 已覆盖正式账单、软删除、iPhone / iPad 同步、iCloud 同步 UI、启动拉取、本地变化推送、账本下拉拉取、App Intents / Share Extension 外部入口补推和主要配置快照同步。
  - 明确 Mac Catalyst 实际复用验证转入 GOAL-1570～1575。
  - 明确 Watch / Widget / tvOS / visionOS 只读展示快照与过期状态转入 GOAL-1566。
  - 明确 CloudKit custom zone、server change token、silent push、配置逐条 record 和冲突人工解决 UI 不再作为 GOAL-1565 blocker。
- 未完成内容：本轮不做新的真机 smoke；Share Extension 到 iPad 的端到端 smoke 仍建议用户按 13.36.6 执行。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：GOAL-1565 的“已完成”是 v1.5.0 最小基础同步闭环完成，不等于所有同步增强、Mac Catalyst 复用和只读展示端快照都已完成。
- 回滚方式：撤销 `versions/v1.5.0-plan.md` 中 GOAL-1565 状态和 13.37 收尾段落，恢复为部分完成。
- 结论：GOAL-1565 可以收尾；v1.5.0 基础 iPhone / iPad iCloud 同步闭环完成，后续进入 GOAL-1566。
- 下一步建议：进入 GOAL-1566，处理 Watch / Widget / 展示端读取同步后稳定快照和离线 / 过期状态。

### ITER-127 GOAL-1565O Share Extension iCloud 补推链路
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 同步底座 / Share Extension
- 目标：补齐 Share Extension 直写 App Group SQLite 后的 iCloud 待推送链路，避免分享截图入账只落本机共享数据库、主 App 回前台后不主动把该笔账单推到 CloudKit。
- 改动范围：
  - `AutoLedger/ShareExtension/ShareViewController.swift`：分享扩展保存正式账单成功后，在 App Group `UserDefaults` 写入待推送标记；复用 App Group 常量写入最近一次 OCR / 解析结果。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：消费待推送标记时同时检查标准 `UserDefaults` 与 App Group `UserDefaults`；iCloud 增量推送成功后统一清除两个位置的标记。
  - `AutoLedger/AutoLedger/Domain/Services/NotificationService.swift`：快捷指令 / App Intent 入口保留标准 defaults 标记，同时同步写入 App Group 标记，让所有外部入口共享同一补推语义。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：启动、外部入口通知和回前台的同步状态文案从“快捷指令”扩展为“外部入口”。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮补推链路与验证结果。
- 未改动范围：未修改 CloudKit schema、record type、SQLite schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未把 CloudKit push 逻辑放入 Share Extension 进程。
- 完成内容：
  - Share Extension 入账成功后会留下跨进程可见的待推送标记。
  - 主 App 下次启动或回前台会刷新本地账本，并在 iCloud 同步开启时尝试增量推送该笔外部入口账单。
  - 推送失败或 iCloud 未开启时标记不会被清除，后续仍可重试；推送成功后统一清除标准 defaults 与 App Group defaults。
  - 快捷指令和 Share Extension 现在共享“外部入口待推送”语义，后续也可接入其他扩展入口。
- 未完成内容：未做真机 Share Extension -> 主 App -> iPad 拉取端到端复测；该链路仍依赖主 App 进程消费待推送标记，不在 Share Extension 内直接写 CloudKit。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：App Group 标记需要主 App 与 Share Extension provisioning profile 均具备同一 App Group；若用户分享入账后长期不打开主 App，远端 iCloud 仍不会立即收到该笔账单。
- 回滚方式：移除 Share Extension 保存成功后的待推送标记，`LedgerStore` 恢复只检查标准 `UserDefaults`，`NotificationService` 恢复只写标准 defaults。
- 结论：GOAL-1565O 完成，Share Extension 直写账单后的 iCloud 补推链路已接入，编译与核心回归门禁通过。
- 下一步建议：验证通过后进行 iPhone 真机分享截图入账 -> 打开主 App -> iPad 下拉刷新 smoke。

### ITER-126 设置页导航环境注入崩溃修复
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / UI
- 目标：修复 iPad 设置页进入“数据管理”后，`DataManagementView` 首屏读取 `LedgerStore` 时因缺少 `@EnvironmentObject` 而崩溃的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Settings/SettingsView.swift`：对依赖 `LedgerStore` 的导航目的页显式补 `.environmentObject(store)`，覆盖数据管理、订阅、商户别名、分类、来源、分类学习和 Debug 页。
  - `AutoLedger/AutoLedger/AutoLedger.entitlements`：保留 CloudKit 后台通知与 iCloud KVS 所需 entitlement，支撑后续 iCloud 同步通知 / 配置同步能力。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮崩溃修复与验证结果。
- 未改动范围：未修改 `DataManagementView` 的业务逻辑、CloudKit / iCloud 同步流程、SQLite schema、Bundle ID、App Group、Watch target、Widget target 或 Xcode project 配置。
- 完成内容：设置页推入依赖账本状态的子页时会显式沿用根 `LedgerStore`，避免 SwiftUI 导航目的页环境传播不稳定导致 `No ObservableObject of type LedgerStore found`。
- 未完成内容：未在真机上重新启动并手动进入数据管理页复测；当前验证为代码检查和 generic iOS 构建。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`git diff --cached --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：本轮只补设置页内部导航的环境转交，不改变根 `LedgerStore` 所有权；entitlement 变更不改变 Bundle ID / Team / App Group / iCloud Container，但真机与 Xcode Cloud 仍需使用具备对应能力的 provisioning profile；如果其他独立宿主直接打开这些子页，仍需要对应宿主注入环境对象。
- 回滚方式：移除 `SettingsView.swift` 中各导航目的页新增的 `.environmentObject(store)`。
- 结论：本轮完成，编译门禁通过；建议重新 Run 到 iPad 后从设置页进入数据管理验证崩溃已消失。
- 下一步建议：在 iPad 真机继续做 iCloud 配置同步 smoke，并保留这次设置页导航修复作为同步设置入口的稳定性补丁。

### ITER-125 GOAL-1565N iCloud 配置快照同步
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 同步底座
- 目标：把订阅、商户别名和必要用户配置纳入 iCloud 同步，避免正式账单已同步但配置仍停留在单机或旧 iCloud Drive 备份路径。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/LedgerSyncPlan.swift`：新增 `LedgerConfigurationSyncPayload`，定义固定 `LedgerConfiguration` record type 和 `ledger-configuration-default` recordName。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：新增 `replaceConfigurationForSync`，只替换订阅、分类修正和商户别名，不触碰正式账单。
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：新增配置快照 push / fetch，使用 `payloadJSON` + `updatedAt` + `deviceID` 存储配置包。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：配置变化更新时间戳并触发 iCloud 增量推送；push 时按更新时间决定是否顺带保存配置快照；pull 时应用较新的远端配置。
  - `AutoLedger/AutoLedger/Features/Settings/SubscriptionListView.swift`：订阅年费覆盖 / 备注变化也标记配置变更并触发推送。
  - `scripts/run_offline_regression.sh`：补齐离线 CloudKit stub 的配置同步接口，保持回归脚本可编译。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮同步范围和验证结果。
- 未改动范围：未修改 entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未将配置同步拆成逐条 CloudKit record；未把旧 iCloud Drive 备份入口恢复到 UI。
- 完成内容：
  - 订阅、商户别名、分类修正、自定义分类 / 来源、订阅年费覆盖 / 备注和必要用户设置会进入 `LedgerConfiguration` 配置快照。
  - 本地配置变化后会标记配置更新时间，并通过已有 iCloud push 任务增量推送。
  - 强制刷新会推送当前配置快照。
  - 拉取时如果远端配置更新时间更新且来自其他设备，会应用到本机 SQLite / UserDefaults，并刷新订阅提醒和 Watch payload。
  - 旧 iCloud Drive 备份开关不会通过配置快照重新打开。
- 未完成内容：配置冲突暂为整包 last-write-wins；未实现订阅 / 商户别名逐条 tombstone；未完成 iPhone / iPad 真机配置同步 smoke。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：配置快照是整包覆盖，适合当前小体量配置；如果两台设备同时改商户别名或订阅，较新的整包会覆盖较旧整包。后续如果用户配置规模变大，应拆成逐条 record 和 tombstone。
- 回滚方式：移除 `LedgerConfigurationSyncPayload`、CloudKit adapter 配置 push / fetch、LedgerStore 配置推拉与时间戳触发，恢复仅同步正式账单。
- 结论：GOAL-1565N 完成，基础账本同步已覆盖正式账单和当前主要配置区。
- 下一步建议：进入 iPhone / iPad 真机配置同步 smoke，并补 Share Extension 直写账单后的 iCloud 补推链路或进入下一阶段同步性能 / UI 收口。

### ITER-124 GOAL-1565M 快捷指令记账 iCloud 补推链路
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / App Intents / 同步底座
- 目标：补齐快捷指令直写 SQLite 后的 iCloud 推送链路，避免 iPhone 通过快捷指令记账后只更新本机账本、远端 iCloud 未及时更新。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/NotificationService.swift`：新增 Intent 保存账单后的待推送标记。
  - `QuickLedgerIntent.swift`、`VoiceLedgerIntent.swift`、`AddTransactionIntent.swift`：保存账单成功后标记待推送并通知主 App 刷新；其中 AddTransactionIntent 补齐原先缺失的主 App 刷新通知。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：App 启动、收到 Intent 保存通知、回到前台时消费待推送标记并触发 iCloud 增量推送。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `pushPendingIntentLedgerSaveIfNeeded`，并让 `pushLedgerChangesToCloudKitIfEnabled` 返回是否推送成功，成功后才清除待推送标记。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮快捷指令同步链路。
- 未改动范围：未修改 CloudKit schema、record type、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未在本轮实现订阅 / 商户别名独立 CloudKit schema。
- 完成内容：
  - QuickLedgerIntent / VoiceLedgerIntent / AddTransactionIntent 保存成功后都会标记“有待推送账单”。
  - 主 App 如果正在运行，会在收到通知后刷新本地列表并立即尝试增量推送 iCloud。
  - 如果快捷指令执行时主 App 没有接住通知，待推送标记会保留到 App 下次启动或回前台再补推。
  - iCloud 不可用、同步正在运行或推送失败时不会清除待推送标记，后续仍可重试。
- 未完成内容：该链路仍依赖主 App 进程消费待推送标记；未把 CloudKit push 逻辑直接放入 App Intent 运行体；订阅、商户别名、自定义分类 / 来源自身仍未建独立 CloudKit record type。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：快捷指令保存后若 iCloud 同步开关未启用，则标记会保留，但首次启用 iCloud 同步会执行全量同步；若用户长期不打开主 App，远端 iCloud 仍不会立刻收到该条记录。
- 回滚方式：移除 Intent 保存后的待推送标记与通知，`AutoLedgerApp` 恢复只刷新本地账本，`pushLedgerChangesToCloudKitIfEnabled` 恢复无返回值。
- 结论：GOAL-1565M 完成，快捷指令 / App Intents 直写 SQLite 后的 iCloud 补推链路已接上。
- 下一步建议：订阅、商户别名和必要用户配置的 iCloud schema 顺延为 GOAL-1565N。

### ITER-123 GOAL-1565L iCloud 同步推拉职责拆分
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 同步底座
- 目标：按真机反馈将 iCloud 同步触发拆成拉取和推送两条线：App 启动只拉取，本地账本数据变化只推送，账本页下拉刷新只拉取，设置页强制刷新保留完整全量刷新。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增本地账本变化后的延迟增量推送任务；将启动同步改为 pull-only；拆出 `pullLedgerFromCloudKitIfEnabled`、`pushLedgerChangesToCloudKitIfEnabled`、`pushLocalLedgerChanges`、`pullRemoteLedgerChanges`。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`：账本页下拉刷新改为从 iCloud 拉取一次，未启用 iCloud 同步时仍只刷新本地 SQLite。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：iPad 账本 workspace 下拉刷新改为从 iCloud 拉取一次。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮触发策略调整。
- 未改动范围：未修改 CloudKit record type、schema、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未在本轮实现订阅 / 商户别名独立 CloudKit schema。
- 完成内容：
  - App 启动且 iCloud 同步开启时，只执行远端拉取和本地合并，不再顺带推送。
  - 本地新增、编辑、软删除、恢复、永久删除、OCR 入账以及商户别名批量刷新账单后，会在 2 秒防抖后触发增量推送。
  - 账本页和 iPad 账本页下拉刷新改为 pull-only 懒加载。
  - 数据管理页“强制刷新数据”仍执行一次全量 push + pull。
- 未完成内容：订阅、商户别名、自定义分类 / 来源自身仍未建独立 CloudKit record type；push checkpoint 仍按本机成功推送时间保存，pull 端仍为 query 分页。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：App Intents / Share Extension 若在 App 未运行时直接写入 SQLite，仍主要依赖后续 App 启动拉取和用户触发流程；后续可补一个启动时“本机未推送变更检测”或通知钩子，避免后台直写漏推。
- 回滚方式：将 `syncLedgerWithCloudKitOnLaunchIfNeeded()` 恢复为调用 `syncLedgerWithCloudKitNow(forceFull: false)`，账本页 / iPad 下拉刷新恢复 `refreshFromStore()`，移除本地变更后的延迟推送任务。
- 结论：GOAL-1565L 完成，iCloud 同步已按启动拉取、本地变更推送、账本下拉拉取、强制刷新全量同步拆分。
- 下一步建议：订阅、商户别名和必要用户配置的 iCloud schema 可顺延为 GOAL-1565M。

### ITER-122 GOAL-1565K iCloud 同步设置页收口
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / UI / 同步底座
- 目标：根据 iPad 真机同步通过结果，将数据管理页的同步入口收口为面向用户的“iCloud 同步”，隐藏旧 iCloud Drive 备份入口，减少技术细节外露。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Settings/DataManagementView.swift`：隐藏 `iCloudCard`；删除 iCloud 同步标题下方长说明；删除开关下方重复状态行；保留同步日志；按钮从“同步一次”改为“强制刷新数据”，触发 `forceFull: true` 全量同步。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：用户可见同步状态从“CloudKit”改为“iCloud”。
  - `AutoLedger/AutoLedger/*/Localizable.strings`：三语标题改为 iCloud 同步，新增“强制刷新数据”文案。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 iPad 真机通过、UI 收口和后续同步范围。
- 未改动范围：未修改 CloudKit schema、record type、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未在本轮实现订阅 / 商户别名 CloudKit record type。
- 完成内容：
  - iPad 数据同步结果回填为通过。
  - 设置页不再展示 iCloud Drive 旧备份卡片。
  - 设置页不再展示 CloudKit private database 等技术说明。
  - 同步进度和错误统一进入“同步日志”区域。
  - 强制刷新按钮会执行一次全量同步，适合人工排查或重拉数据。
- 未完成内容：订阅和商户别名仍需下一轮扩展 iCloud 同步 schema / 远端合并 / 删除语义；pull 端仍为 query 全量分页，不是 server change token 增量；未完成 Xcode Cloud validation build。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：旧 iCloud Drive 备份入口只是从数据管理页隐藏，相关恢复代码仍保留以便旧用户迁移；强制刷新会清除 push checkpoint 并做全量推送。
- 回滚方式：恢复 `iCloudCard` 展示、恢复说明 / 状态行、按钮改回增量同步入口，并回退本地化与文档记录。
- 结论：GOAL-1565K 完成，iCloud 同步入口已从开发诊断界面收口为用户可理解的设置项。
- 下一步建议：进入订阅与商户别名 iCloud 同步 schema 扩展，避免旧备份隐藏后这些配置只能靠本机保存。

### ITER-121 GOAL-1565J iCloud 同步启用流程
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 同步底座 / UI
- 目标：将 CloudKit 手动同步入口升级为“先启用 iCloud 同步，首次全量，后续启动自动增量”的用户流程，并在 UI 展示同步进度和近期日志。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `ledgerCloudSyncEnabled` 持久化开关、`ledgerCloudSyncLog`、首次启用全量同步、App 启动自动增量同步入口和统一状态日志。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：启动 `.task` 中调用 `syncLedgerWithCloudKitOnLaunchIfNeeded()`。
  - `AutoLedger/AutoLedger/Features/Settings/DataManagementView.swift`：CloudKit 卡片新增开关、运行进度和近期日志；手动“同步一次”仅在开关开启且未运行时可用。
  - `AutoLedger/AutoLedger/*/Localizable.strings`：补齐简体中文、繁体中文、英文文案。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮流程和验证结果。
- 未改动范围：未修改 CloudKit record type、字段名、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未迁移到 custom CloudKit zone。
- 完成内容：
  - 用户在数据管理页首次开启 iCloud 同步时，会清除 push checkpoint，并立即触发一次全量同步。
  - 开关保持开启后，App 下次启动会自动执行一次后台增量同步。
  - 同步阶段会写入状态和近期日志，包括账号检查、推送、拉取、写入本地和完成 / 失败结果。
  - 手动“同步一次”保留为已启用状态下的补跑入口。
- 未完成内容：pull 端仍为 query 全量分页，不是 server change token 增量；未实现后台静默 push、CloudKit subscription、同步取消、同步健康详情页、iPad 真机拉取回填或 Xcode Cloud validation build。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：启动自动同步当前在 App 启动 `.task` 中运行一次，不是系统后台任务；如果 CloudKit schema / query index 不完整，仍可能在 pull 阶段显示拉取失败日志。开关关闭时不会取消已经开始的同步任务。
- 回滚方式：回退 `LedgerStore` 的开关 / 日志 / 启动同步入口，回退 `AutoLedgerApp` `.task` 调用、`DataManagementView` UI 和新增本地化 key。
- 结论：GOAL-1565J 完成，可以进入 iPhone / iPad 真机流程测试。
- 下一步建议：在 iPhone 打开“启用 iCloud 同步”观察首次全量日志；重启 App 验证自动增量日志；再到 iPad 启用同步并验证拉取账本。

### ITER-120 GOAL-1565I CloudKit 全量 / 增量同步性能收口
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 同步底座 / 性能
- 目标：修复真机 `_defaultZone` 不支持 `getChanges` 导致的 CloudKit 拉取失败，并把手动同步从每次全量单条 push 收口为首轮全量、后续增量、每批最多 100 条。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：撤回 default zone changes 拉取，恢复 `CKQueryOperation` 分页拉取；query `resultsLimit` 设为 100；push 保存 / 删除 operation 改为 100 条一批。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：读取 `lastSuccessfulCloudKitPushAt` 作为 `LedgerSyncPlanner.changedAfter`；push 成功后记录 checkpoint；备份恢复会清除 checkpoint。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录真机错误、默认 zone 限制、全量 / 增量边界和验证结果。
- 未改动范围：未迁移到 CloudKit custom zone；未修改 CloudKit record type、字段名、SQLite schema、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本。
- 完成内容：
  - 修复 `AppDefaultZone does not support getChanges call`：当前默认 zone 不再走 `CKFetchRecordZoneChangesOperation`。
  - 首次安装本轮构建后，如果本机没有 checkpoint，会做一次全量 push；成功后保存 `lastSuccessfulCloudKitPushAt`。
  - 第二次及之后手动同步只把 `sync metadata.updatedAt > lastSuccessfulCloudKitPushAt` 的本机记录放入 push batch。
  - push operation 从诊断期单条 record 恢复为最多 100 条一批，降低 290 条账单场景的网络往返次数。
- 未完成内容：pull 端仍是 query 全量分页，不是 server change token 增量；仍未实现后台自动同步、CloudKit subscription / silent push、同步健康页、统计分解 UI 或 iPad 真机拉取回填。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前 pull 依然依赖 CloudKit query schema / index 可用；真正的 pull 增量需要后续迁移到 custom record zone，或将 `updatedAt` Queryable 纳入 schema deploy 后用时间窗口 query。当前 checkpoint 只控制本机 push，不代表远端 pull token。
- 回滚方式：回退本轮 batch chunk、query pull 恢复、`lastSuccessfulCloudKitPushAt` 读写和文档记录；本地账本数据不受影响。
- 结论：GOAL-1565I 代码侧完成，可以重新安装到 iPhone / iPad 真机验证；预期第一次仍可能全量，第二次开始 push 应明显变少。
- 下一步建议：iPhone 连续点两次 CloudKit 同步，观察第二次是否显示“增量推送 0 条”或只推新增变更；再到 iPad 执行同步验证拉取。

### ITER-119 GOAL-1565H CloudKit 拉取索引依赖收口
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 同步底座 / 真机诊断
- 目标：根据真机回填确认 CloudKit push / pull 已成功后，移除手动拉取对 `recordName` Queryable 索引的运行时依赖，降低 CloudKit Dashboard 手工配置复杂度。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：远端拉取从 `CKQueryOperation(TRUEPREDICATE)` 改为 `CKFetchRecordZoneChangesOperation` 读取 default zone changes，并继续通过 payload mapper 过滤正式账单 record。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮真机结论、CloudKit index 边界、同步慢和计数口径问题。
- 未改动范围：未修改 CloudKit record type、字段名、SQLite schema、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未提交 Xcode 能力页自动写入的 entitlement 变化。
- 完成内容：
  - 明确 `recordName` Queryable 属于 CloudKit server-side schema / index 配置，App 不能可靠地在运行时为 Dashboard 创建查询索引。
  - 手动同步的 pull 阶段改用 zone changes，不再需要以 `recordName` 为 queryable 才能拉取。
  - 当前仍未持久化 server change token，因此每次手动同步仍按全量 zone changes 拉取；这解释了首次同步和当前手动同步仍可能偏慢。
  - 真机回填的 `推送 290 / 拉取 290 / 保留本地 290` 被记录为 sync record 口径，不直接等同于数据管理页“账单 + 最近删除”的展示口径。
- 未完成内容：未实现 server change token 持久化、后台自动同步、CloudKit subscription / silent push、同步健康页、统计分解 UI、iPad 真机拉取回填或 Xcode Cloud validation build。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。
  - PASS：`bash scripts/run_golden_regression.sh`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：zone changes 当前不保存 change token，会重新扫描 default zone；如果默认 zone 后续承载更多 record type，应继续保持 mapper 过滤，并在 GOAL-1565I 引入 token / checkpoint，避免同步越来越慢。
- 回滚方式：若 zone changes 在真机 iPad / iPhone 上表现异常，可回退到 `CKQueryOperation` 拉取路径，但需要在 CloudKit Dashboard 继续维护相关 queryable index。
- 结论：GOAL-1565H 代码侧完成，CloudKit 拉取不再依赖 `recordName` query index；需要安装到 iPad 真机验证拉取账本。
- 下一步建议：进入 GOAL-1565I，优先做 iPad 真机拉取 smoke、同步统计口径拆分和 server change token 持久化。

### ITER-118 GOAL-1565G CloudKit 最小探针诊断
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 诊断 / 同步底座
- 目标：根据真机回填确认单条 `LedgerTransaction` 完整 record 仍被 `serverRejectedRequest` / `CKInternalErrorDomain 2000` 拒绝后，继续区分“record type / 容器本身不可写”和“完整字段集合被拒绝”。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：`CKModifyRecordsOperation.savePolicy` 改为 `.allKeys`；完整 record 保存失败后，使用相同 record type 写入最小探针 record，并尝试删除探针；错误文案增加 `Probe: minimal-save ...`。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮真机错误链条、诊断策略和复测口径。
- 未改动范围：未修改 CloudKit record type、字段名、SQLite schema、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本；未碰本轮外的 `ReceiptParser` / Golden Case 工作区改动。
- 完成内容：
  - 明确当前 blocker 不是批量大小，单条完整 record 仍会被服务端拒绝。
  - 新建 record 的保存策略改为 `.allKeys`，减少 CloudKit changed keys 新建行为的不确定性。
  - 完整保存失败后会自动做最小 `LedgerTransaction` 探针：只写入 `transactionID` 与 `updatedAt`，成功后尝试删除。
  - 下一次真机 UI 将显示探针结果：`minimal-save failed` 或 `minimal-save succeeded...`。
- 未完成内容：未完成用户真机复测；未确认 CKInternalError 2000 最终原因；未配置 CloudKit Dashboard schema / index；未实现后台自动同步、增量 token、冲突解决 UI 或同步健康页。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：探针会短暂写入一个 `transaction-...-probe` record，成功后立即删除；若删除失败，UI 会显示 probe delete failed，需要在 CloudKit Dashboard 人工检查是否遗留探针 record。
- 回滚方式：回退本轮 `savePolicy = .allKeys`、`diagnoseMinimalSave` 和 `recordSaveRejected` probe 文案，以及文档记录；本地 SQLite 数据不受影响。
- 结论：GOAL-1565G 诊断路径完成，可以重新安装到 iPhone 真机复测 CloudKit push。
- 下一步建议：重新点击 iPhone CloudKit 同步一次；若仍失败，回填包含 `Probe:` 的完整错误文案。

### ITER-117 GOAL-1594 平台无关解释器主链路收口规划
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：识别链路 / 架构收口
- 类型：文档 / 治理 / 架构规划
- 目标：把“平台无关层已存在但未作为最终文本转结构化账单主链路”的当前事实写入版本文档，并拆出后续可逐步落实的 GOAL。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增 `8.4 平台无关解释器收口方向（GOAL-1594）`，记录当前 `LedgerTextInterpreterCore`、`LedgerTextInterpreter`、`SmartReceiptParser`、`ReceiptParser`、QuickLedgerIntent / Share Extension 的职责边界；补充目标链路、候选商户原则、AI rerank 边界和 GOAL-1595～1598。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮 docs-only 架构收口。
- 未改动范围：未修改 `LedgerTextInterpreterCore`、`LedgerTextInterpreter`、`SmartReceiptParser`、`ReceiptParser`、QuickLedgerIntent、Share Extension、Golden Case、SQLite、CloudKit、Watch、Widget、iPad UI 或 Xcode project。
- 完成内容：
  - 明确当前平台无关层已存在并能输出 `TransactionDraft`，但主入账链路目前主要用它做 `nonBillImage` gate。
  - 明确最终结构化账单仍主要来自 App 层 `SmartReceiptParser` / `ReceiptParser`，平台规则仍堆在 App target。
  - 固定后续目标：Core 提供文本标准化、分段、候选实体、评分解释和可选本地 AI rerank；App adapter 只保留 OCR、provider、UI、保存和 iOS 专属能力。
  - 新增后续 GOAL：1595 Core 候选实体模型、1596 App 主链路采用 Core draft、1597 Intent / Share Extension Core-first、1598 平台规则迁移与 App `ReceiptParser` 瘦身。
- 未完成内容：未开始代码迁移；GOAL-1593 的淘宝闪购支付宝账单详情规则仍暂留 App 层 `ReceiptParser`；未新增 Core 候选实体模型或回归样本。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：后续迁移应按 Golden Case 分批推进，避免一次性替换 `ReceiptParser` 导致真实支付截图大面积回退；AI 介入只应作为本地候选 rerank，不默认自由生成商户名。
- 回滚方式：回退本轮 `versions/v1.5.0-plan.md` 的 GOAL-1594～1598 文档增量，以及 `CHANGELOG.md`、`process/iteration-log.md` 对应条目；无代码或数据影响。
- 结论：本轮完成，v1.5.0 文档已把平台无关解释器主链路收口列为可追踪 GOAL 序列。
- 下一步建议：进入 GOAL-1595，先定义 Core 候选实体模型、候选来源枚举、评分字段和 debug reason，再迁移支付宝 / 淘宝闪购 / 微信 / 云闪付样本。

### ITER-116 GOAL-1593 淘宝闪购支付宝账单详情商户提取
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：识别链路 / 真实样本修复
- 类型：Bugfix / 解析规则 / 测试
- 目标：修复淘宝闪购支付宝账单详情截图中，规则解析把平台行“淘宝闪购”误作为商户，而没有从“商品说明”字段提取真实店铺说明的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift`：新增支付宝 / 淘宝账单详情“商品说明”标签块解析；按连续标签和值块顺序提取商品说明，合并 OCR 换行，并清理“外卖订单”等尾缀。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 `taobao_flash_alipay_bill_detail_linlee` Golden Case，覆盖 `LINLEE林里•手打柠檬茶（南开海光MALL店）` 样本。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录本轮范围、验证结果和回滚方式。
- 未改动范围：未修改来源推断优先级；含“淘宝 / 闪购”的账单仍可归为 `taobao` 来源；未改 MerchantAliasResolver、SQLite、LedgerStore 保存路径、CloudKit 同步、Watch、Widget、iPad UI、Xcode project 或 schema。
- 完成内容：
  - `ReceiptParser` 在通用负数金额邻近行规则之前，优先从“商品说明”值提取真实商户说明。
  - 样本中的 `LINLEE林里•手打柠檬茶（南开海光MAL` + `L店）外卖订单` 会合并并清理为 `LINLEE林里•手打柠檬茶（南开海光MALL店）`。
  - 新 Golden Case 同时断言金额 `21.87`、商户、餐饮分类和 `taobao` 来源。
- 未完成内容：未做更多淘宝 / 饿了么 / 美团 / 支付宝账单详情样本的批量准确率评估；未调整分类词库；未改变用户已保存的历史账单。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`，34 cases；仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`bash scripts/run_offline_regression.sh`；仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：“商品说明”字段本质上是订单说明，不一定所有平台都等同于店铺名；本轮仅在支付宝账单详情结构明显存在时启用，避免影响普通支付成功页和淘宝订单进行中页。
- 回滚方式：回退 `ReceiptParser` 中 `parseAlipayBillDetailMerchant` 及调用顺序、删除新增 Golden Case，并回退本轮文档记录；本地账本数据不受影响。
- 结论：本轮完成，用户反馈的淘宝闪购支付宝支付截图可解析出更精确的店铺说明商户名，不再默认落到平台名“淘宝闪购”。
- 下一步建议：继续收集同类外卖 / 电商账单详情样本，按平台拆小样本加入 Golden Case，再决定是否抽象为更通用的字段块解析器。

### ITER-115 GOAL-1565F CloudKit 推送拒绝定位
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 诊断 / 同步底座
- 目标：根据真机 UI 回填的 `CloudKit 推送失败：CKError 15 ... underlying: CKInternalErrorDomain 2000`，进一步定位 push 阶段是整批请求、单条记录内容、字段长度、schema 还是服务端限制导致拒绝。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：手动同步 push 临时改为单条 record 一个 `CKModifyRecordsOperation`；单条保存 / 删除失败时抛出包含 recordName 和字段摘要的诊断错误；CKError code 15 显示为 `serverRejectedRequest`。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录真机截图反馈和下一轮复测口径。
- 未改动范围：未修改 CloudKit record schema、SQLite schema、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、workspace、scheme、target、Watch target、Widget target 或 Xcode Cloud 脚本。
- 完成内容：
  - 确认当前 blocker 在 CloudKit push 阶段，不是 iPad fetch / SQLite apply 阶段。
  - 手动 smoke 路径不再一次保存 100 条，避免 CloudKit 整批拒绝时无法定位。
  - 新错误文案不会输出商户、备注或账单原文，只输出 recordName、字段名、字段类型和字符串长度。
  - CKError 15 后续会显示为 `serverRejectedRequest`，比 `CKErrorCode(rawValue: 15)` 更容易判断。
- 未完成内容：未完成用户真机复测；未确认 CKInternalError 2000 最终原因；未配置 CloudKit Dashboard schema / index；未实现后台自动同步、增量 token、冲突解决 UI 或同步健康页。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：单条 push 是诊断优先的 smoke 策略，271 条账单首轮同步会比批量慢；真机确认失败原因后再恢复受控批量和后台增量同步。
- 回滚方式：回退本轮 `LedgerCloudKitSyncAdapter` 单条 push 与错误包装变更，以及文档记录；本地 SQLite 数据不受影响。
- 结论：GOAL-1565F 诊断路径完成，可以重新安装到 iPhone 真机复测 push 阶段。
- 下一步建议：重新点击 iPhone CloudKit 同步一次；如果仍失败，回填新状态文案中 `CloudKit rejected record save ... Fields: ... Error: ...` 的完整内容。

### ITER-114 GOAL-1565E CloudKit 真机错误诊断
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：Bugfix / 诊断 / 同步底座
- 目标：处理两台真机手动 CloudKit 同步 smoke 中出现的 `CKErrorDomain` code 15，并把原先不可定位的“同步失败”拆成可判断 push / fetch / 本地写入阶段的错误信息。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：新增 CloudKit 错误描述工具，提取 CKError code、localized 信息、partial error 和 underlying error；push 保存和删除操作按 100 条一组分批提交。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：手动同步状态拆分为推送、拉取和本地 SQLite 写入阶段；失败时保留阶段信息。
  - `scripts/run_offline_regression.sh`：补齐离线 CloudKit stub 的错误描述 API，保持离线回归可编译。
  - `CHANGELOG.md`、`versions/v1.5.0-plan.md`：记录真机错误、诊断边界和复测步骤。
- 未改动范围：未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、CloudKit record schema、SQLite schema、Watch target、Widget target 或 Xcode Cloud 脚本。
- 完成内容：
  - 明确用户日志中的 `WCSession counterpart app not installed` 属于 Watch app 未安装 / 未配对场景，不是 iPad CloudKit 拉取阻断。
  - 手动同步按钮现在会显示 `CloudKit 推送失败` 或 `CloudKit 拉取失败`，方便判断服务端拒绝发生在写入还是查询阶段。
  - CKError 15 后续可在 App UI 中看到更完整的错误描述，而不是只看到 code。
  - push operation 已分批，降低单次 modify records 请求过大导致服务端拒绝的概率。
- 未完成内容：未完成用户真机复测；未确认 CKError 15 的最终服务端原因；未配置 CloudKit Dashboard schema / index；未实现后台自动同步、增量 token、冲突解决 UI 或同步健康页。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：如果下一次状态显示推送失败，优先检查 CloudKit record type / field schema / capability / provisioning；如果显示拉取失败，优先检查 `LedgerTransaction` query、CloudKit index 或 private database schema 部署状态。当前同步仍为手动全量 query，不是最终后台增量同步。
- 回滚方式：回退本轮 `LedgerCloudKitSyncAdapter` 分批与错误描述、`LedgerStore` 状态文案、离线 stub 和文档记录；已存在的本地 SQLite 数据不受影响。
- 结论：GOAL-1565E 诊断增强完成，可以重新安装到 iPhone / iPad 真机并复测手动同步。
- 下一步建议：重新运行新构建后，先在 iPhone 点击 CloudKit 同步一次；若失败，回填完整状态文案，尤其是 `CloudKit 推送失败` 或 `CloudKit 拉取失败` 后面的详细内容。

### ITER-113 GOAL-1565D 手动 CloudKit 同步入口
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 数据 / 同步底座
- 目标：在 iPhone / iPad 真机均可启动且 CloudKit capability 已开启后，解释“刷新账本不拉取远端”的原因，并补上可手动触发的 CloudKit 同步一次入口。
- 改动范围：
  - `AutoLedger/AutoLedger/AutoLedger.entitlements`：保留 CloudDocuments、App Group 和原 iCloud container，新增 CloudKit；去除本轮不需要的 `aps-environment`。
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：新增 fetch `LedgerTransaction` records 并映射回 `LedgerTransactionSyncPayload`。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/LedgerSyncPlan.swift`：补充 payload 显式 init 与 `syncRecord` 往返入口。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/SyncMetadata.swift`：新增 `TransactionSyncApplyOutcome`。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：新增 `applyRemoteSyncRecord`，按 revision / updatedAt 插入、更新、软删除或标记冲突。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `syncLedgerWithCloudKitNow()`、同步状态和运行中状态；旧 iCloud Drive 自动备份开关固定关闭。
  - `AutoLedger/AutoLedger/Features/Settings/DataManagementView.swift`、三语 `Localizable.strings`：新增 CloudKit 同步卡片；旧 iCloud Drive 备份文案降级为 legacy 手动备份 / 恢复。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增 payload round-trip 与 SQLite 远端 insert / update / tombstone / conflict 回归，并补离线 CloudKit stub。
- 未改动范围：未新增后台自动同步、CloudKit subscription / push notification、冲突解决 UI、自定义分类 / 来源同步、商户别名同步、多账本元数据同步、Watch / Widget / tvOS / visionOS 快照同步；未修改 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、scheme 或 target。
- 完成内容：
  - 用户已确认 iPhone 真机和 iPad 真机均可正常启动。
  - 明确 iPad 端“刷新账本”此前只刷新本地 SQLite，不会自动拉 CloudKit。
  - 数据管理页新增“CloudKit 账本同步”卡片，手动点击后执行 push 本机正式账单、fetch 远端正式账单、应用到 SQLite、刷新 UI / Widget / Watch payload。
  - 远端记录应用规则：无本地记录则插入；远端 revision / updatedAt 更高则应用；远端 tombstone 更高则软删除；本地更新更高则保留本地；同 revision 内容分叉标记 `conflictPendingReview`。
  - 旧 iCloud Drive 单文件自动备份从自动开关降级，不再作为多端同步入口；仍保留手动旧备份和旧备份恢复能力。
- 未完成内容：未做用户真机手动同步结果回填；未实现后台自动同步；未实现远端变更增量 token；未实现冲突解决 UI；未同步自定义分类 / 来源、商户别名、分类修正或多账本元数据；未完成 Xcode Cloud validation build。
- 测试情况：
  - PASS：用户手动确认 iPhone / iPad 真机均可启动。
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前同步为手动全量 query，不是最终后台增量同步；若两端都有 seed / 测试账单，首次同步会把两端现有正式账单都推入 CloudKit。CloudKit private database 真机同步结果仍需用户在两台设备上点击手动同步验证。
- 回滚方式：回退本轮 CloudKit fetch / SQLite apply / LedgerStore 手动同步 / DataManagementView / 本地化 / entitlements / 回归脚本变更；旧本地 SQLite 数据不受回滚破坏。
- 结论：GOAL-1565D 代码闭环完成，可以进入两台真机手动同步 smoke。
- 下一步建议：在 iPhone 新增一笔明显测试账单，进入设置 -> 数据管理 -> CloudKit 账本同步 -> 同步一次；随后在 iPad 打开同一入口点击同步一次，确认状态文案显示拉取到远端账单且账本页出现该测试账单。通过后再跑 Xcode Cloud validation build。

### ITER-112 GOAL-1565C CloudKit live 前置门控
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 数据 / 同步底座
- 目标：在不修改 entitlements、不默认启用真实 CloudKit 写入的前提下，为后续真机 smoke 增加 iCloud account status 检查、live 写入手动门控和最小 modify records 代码路径。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：新增 `LedgerCloudKitAccountState`、`LedgerCloudKitAccountCheck`、`LedgerCloudKitPushResult`、`checkAccountStatus()`、`push(batch:)` 和 `allowsLiveCloudKitWrites` 手动写入开关。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1565C 范围、验证结果和真机 / Xcode 配置要求。
- 未改动范围：未修改 CloudKit capability、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、scheme、target、WatchConnectivity payload、Widget SQL、iCloud Drive BackupBundle、SQLite schema 或 App Store 发布脚本。
- 完成内容：
  - `checkAccountStatus()` 可读取 `CKContainer.accountStatus()` 并映射为可展示 / 可诊断的账户状态。
  - `push(batch:)` 只允许在 `mode == .live` 且 `allowsLiveCloudKitWrites == true` 时进入真实 CloudKit 路径。
  - live 前会检查 iCloud account status，非 available 时抛出受控 `accountUnavailable` 错误。
  - 最小 `CKModifyRecordsOperation` 路径可保存 upserts / retained tombstones，并按 expired tombstone IDs 删除对应远端 record。
  - 默认初始化仍为 disabled，且 live writes 默认 false，避免未完成人工迁移前误写 CloudKit。
- 未完成内容：未修改 Xcode capability；未做真机 CloudKit smoke；未接入自动同步入口；未实现 pull / merge / applyRemote；未实现冲突 UI 或同步健康 UI；未同步自定义分类 / 来源、商户别名、分类修正或多账本元数据。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
- 风险与注意事项：真实 CloudKit private database 写入必须由用户在 Xcode / Apple Developer 中开启 CloudKit capability，并在真机与 Xcode Cloud 上验证 provisioning；当前代码只提供受控入口，不代表多端同步已完成。
- MANUAL_MIGRATION_REQUIRED：在 Xcode 主 App target 的 iCloud capability 中保留现有 CloudDocuments，并启用 CloudKit；使用现有 `iCloud.top.darkrio326.AutoLedger` container；重新生成 provisioning profile；用两台登录同一 Apple ID 的真机做 iPhone / iPad smoke；随后跑 Xcode Cloud validation build。
- 回滚方式：回退 `LedgerCloudKitSyncAdapter.swift` 的 GOAL-1565C 增量和本轮文档记录；默认入口未接运行时，回滚不影响现有账本、Watch、Widget 或备份功能。
- 结论：GOAL-1565C 代码门控完成，真机 live 同步验证仍未完成。
- 下一步建议：先由用户完成 Xcode CloudKit capability 配置和真机 smoke；验证通过后再进入 GOAL-1565D，接入受控同步入口、pull / merge / applyRemote 和同步状态 UI。

### ITER-111 GOAL-1565B CloudKit dry-run adapter
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 数据 / 同步底座
- 目标：在不修改 entitlements、不启用真实 CloudKit 写入的前提下，给 GOAL-1565A 的同步计划层增加 CloudKit adapter 外壳、dry-run record mapping 和 live 模式保护。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift`：新增 disabled / dry-run / live 三态 adapter、CloudKit 字段值包装、mapped record 结构和 `CKRecord` 构造入口。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1565B 范围、发布链影响和下一步。
- 未改动范围：未修改 CloudKit capability、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、scheme、target、WatchConnectivity payload、Widget SQL、iCloud Drive BackupBundle、SQLite schema 或 App Store 发布脚本。
- 完成内容：
  - `disabled` 模式默认启用，调用 push 准备会抛出受控 disabled 错误。
  - `dryRun` 模式可把 `LedgerSyncPushBatch` 的 upserts 和 tombstones 映射为 `LedgerCloudKitMappedRecord`，并保留 expired tombstone 计数。
  - `live` 模式在 capability、provisioning profile、Xcode Cloud signing 和隐私披露完成前抛出受控错误，不会误写 CloudKit。
  - `makeCKRecord(from:)` 可从 dry-run mapped record 构造 `CKRecord`，为后续真实 adapter 复用字段映射。
- 未完成内容：未实现 CloudKit save / fetch / modifyRecords；未实现 pull / merge / applyRemote；未做 CloudKit account status；未做同步 smoke；未同步自定义分类 / 来源、商户别名、分类修正或多账本元数据。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：本轮已 import CloudKit，但仅在主 App target 内使用，不进入 `AutoLedgerCore`；GOAL-1565 仍为部分完成，不能声明多设备真实同步。
- 回滚方式：回退 `LedgerCloudKitSyncAdapter.swift` 和本轮文档记录；该 adapter 尚未接入运行时入口，回滚不影响现有账本、Watch、Widget 或备份功能。
- 结论：GOAL-1565B 完成，CloudKit dry-run adapter 外壳已可编译，但真实多端同步仍未启用。
- 下一步建议：验证通过后进入 GOAL-1565C，做 capability-gated 的 CloudKit account/status 检查与真实 modify records 接入方案；CloudKit entitlement 和 Xcode Cloud signing 必须单独人工验证。

### ITER-110 GOAL-1565A 基础账本同步计划层
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 数据 / 同步底座
- 目标：在不接入 CloudKit、不修改 entitlements 的前提下，先固定正式账单同步的 record schema、record name、push batch 拆分和 tombstone 保留边界。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/LedgerSyncPlan.swift`：新增 `CloudLedgerSyncSchema`、`LedgerTransactionSyncPayload`、`LedgerSyncPushBatch`、`LedgerSyncPlanner`。
  - `scripts/OfflineRegression.swift`：新增 record type、record name、upsert / tombstone / expired tombstone、`changedAfter` 增量过滤回归。
  - `scripts/run_offline_regression.sh`：加入 `LedgerSyncPlan.swift`。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1565A，GOAL-1565 标记为部分完成。
- 未改动范围：未 import CloudKit；未修改 CloudKit capability、entitlements、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、Xcode project、scheme、target、WatchConnectivity payload、Widget SQL、iCloud Drive BackupBundle 或 App Store 发布脚本。
- 完成内容：
  - 正式账单 CloudKit record type 固定为 `LedgerTransaction`。
  - 交易 record name 固定为 `transaction-<uuid-lowercased>`，后续多设备可对同一账单写入同一条 record。
  - payload 覆盖正式账单字段与 GOAL-1564 sync metadata。
  - 本地 push batch 可拆分 active upserts、retained tombstones、expired tombstone IDs。
  - 支持 `changedAfter` 增量过滤，避免未变化 active record 进入 push batch。
- 未完成内容：未实现 CloudKit adapter；未做真实 iCloud private database 读写；未实现 pull / merge / applyRemote；未同步自定义分类 / 来源、商户别名、分类修正或多账本元数据；未实现同步健康 UI、冲突解决 UI或同步 smoke。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
- 风险与注意事项：GOAL-1565 仍为部分完成，不能对用户或发布说明声明多设备真实同步；后续接 CloudKit 前仍需人工验证 capability、provisioning profile、Xcode Cloud signing 和隐私披露。
- 回滚方式：回退 `LedgerSyncPlan.swift`、离线回归新增用例和文档记录；该层尚未接运行时服务，回滚不影响现有账本。
- 结论：GOAL-1565A 完成，正式账单同步的本地计划层已固定。
- 下一步建议：进入 GOAL-1565B，增加 CloudKit adapter 的 disabled / dry-run 包装和 record mapping；真实 capability 与 Xcode Cloud signing 单独验证。

### ITER-109 GOAL-1564 基础同步元数据与冲突模型
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：能力增强 / 数据 / 同步底座
- 目标：在不接入 CloudKit、不改变发布链配置的前提下，为后续 iPhone / iPad / Mac 多端同步补齐最小 sync metadata、删除 tombstone、幂等键和冲突判定基础。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/SyncMetadata.swift`：新增 `TransactionSyncMetadata`、`TransactionSyncRecord`、`SyncConflictState`、`TransactionSyncResolution` 和基础冲突判定器。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：`transactions` 增量补齐 `sync_revision`、`sync_device_id`、`sync_idempotency_key`、`sync_conflict_state`；保存、更新、软删除、恢复维护 revision / tombstone；新增 sync record 读取 API。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/BackupBundle.swift`：`BackupTransaction` 新增 optional `syncMetadata`，保持旧 v1 JSON 兼容。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增同步模型、SQLite metadata、tombstone 和旧备份兼容回归。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1564 完成状态。
- 未改动范围：未实现 CloudKit；未修改 Xcode project、workspace、scheme、target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、WatchConnectivity payload、Widget SQL 读取逻辑、iCloud Drive backup service 或 App Store 发布脚本。
- 完成内容：
  - 新交易默认获得本机安装级 `sync_device_id`、`sync_revision = 0`、默认幂等键和 clean 冲突状态。
  - 更新、软删除和恢复会递增 sync revision，并刷新 `updated_at` 与本机 `sync_device_id`。
  - 软删除保留 `deleted_at` tombstone；同步层可选择读取包含删除或仅活跃的 sync records。
  - 备份交易可携带 optional sync metadata；旧备份 JSON 缺失该字段时仍能解码。
  - 基础冲突判定支持 higher revision 应用、same revision 内容分叉进入待复核冲突。
- 未完成内容：未实现真实多端同步；未定义 CloudKit record schema；未做冲突解决 UI；未新增批量清洗变更日志表；未迁移自定义分类 / 来源到 SQLite per-item 同步表。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`bash scripts/run_offline_regression.sh`。仅有既有 `nonisolated(unsafe)` warning。
- 风险与注意事项：`permanentlyDeleteTransaction` 仍为物理删除，后续 GOAL-1565 必须定义 tombstone 保留期或远端确认后再永久删除的策略；否则未同步软删除可能被过早清除。
- 回滚方式：回退本轮新增 `SyncMetadata.swift`、SQLite sync metadata 增量、BackupTransaction optional 字段、离线回归和文档记录；旧数据库中已添加的 additive columns 可保留，不影响现有查询。
- 结论：GOAL-1564 完成，可以进入 GOAL-1565 的 iPhone / iPad / Mac 基础同步闭环设计与实现。
- 下一步建议：进入 GOAL-1565 前先明确 CloudKit record schema、拉取 / 推送顺序、tombstone 保留策略和冲突 UI 入口。

### ITER-108 GOAL-1563 多端同步现状审计与策略冻结
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：文档 / 审计 / 治理
- 目标：审计当前 SQLite、BackupBundle、iCloud Drive、WatchConnectivity、Widget App Group 和 entitlements 的真实同步能力，冻结 v1.5.0 最小多端同步策略。
- 改动范围：
  - `versions/v1.5.0-plan.md`：补充 GOAL-1563 审计结论、数据范围矩阵、策略冻结、发布链影响和下一步 GOAL-1564。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮完成范围。
- 未改动范围：未修改 Swift 代码、SQLite schema、BackupBundle schema、CloudKit、WatchConnectivity payload、Widget 读取逻辑、entitlements、Xcode project、scheme、target、Bundle ID、signing、App Group 或 iCloud Container。
- 完成内容：
  - 确认当前 iCloud 能力是 CloudDocuments / iCloud Drive 单文件 `AutoLedgerBackup.json` 备份，不是 CloudKit 结构化同步。
  - 确认当前 Watch 只承担最近账单、今日支出摘要、自定义分类和 pending 回传，不是完整账本复制。
  - 确认当前 Widget 只读取本机 App Group SQLite，不能代表其他设备最新账本。
  - 冻结 v1.5.0 最小策略：local-first，本机 SQLite 仍为运行时事实源；CloudKit private database 作为结构化多端同步优先方向；iCloud Drive BackupBundle 保留备份、导出、恢复和人工迁移角色。
  - 明确原始截图、支付截图、小票图片、OCR 全文、raw input 和调试包默认不进入同步。
  - 明确 GOAL-1564 必须先补同步元数据、幂等键、删除合并和冲突模型，再进入 GOAL-1565 同步闭环。
- 未完成内容：未实现 CloudKit；未实现 iPhone / iPad / Mac 多端同步；未新增同步 metadata；未做真机多设备同步验证。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：若后续引入 CloudKit private database，需要单独验证 Apple Developer capability、provisioning profile、Xcode Cloud signing、隐私披露、离线冲突和真机多设备同步；如果 capability 未就绪，应标记为 `MANUAL_MIGRATION_REQUIRED`，不要用单文件 BackupBundle 伪装静默同步。
- 回滚方式：回退本轮 `versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md` 文档变更。
- 结论：GOAL-1563 完成，v1.5.0 多端同步方向已冻结为“本地优先 + CloudKit 结构化同步优先 + iCloud Drive 备份保留”。
- 下一步建议：进入 GOAL-1564，设计并实现基础同步元数据与冲突模型。

### ITER-107 v1.5.0 基础多端数据同步规划
- 日期：2026-06-02
- 所属版本：v1.5.0
- 所属阶段：Phase 7 / 基础多端数据同步
- 类型：文档 / 规划 / 治理
- 目标：记录 v1.5.0 仍需解决基础多端数据同步问题，避免 iPad、Mac、Watch、Widget、tvOS 和 visionOS 各自形成孤立数据口径。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增“基础多端数据同步”章节，补充同步现状、同步范围、冲突策略、隐私边界和 GOAL-1563～1566。
  - `README.md`、`README.en.md`：Roadmap 将基础多端数据同步列入 v1.5.0 开发范围。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮文档规划变更。
- 未改动范围：未修改代码、SQLite schema、BackupBundle、CloudKit、entitlements、Xcode project、scheme、target、Bundle ID、signing、App Group 或 iCloud Container。
- 完成内容：
  - 明确 iCloud Drive 单文件备份不是实时多端同步。
  - 明确 WatchConnectivity 当前只承担 Watch 轻量同步和 pending 回传，不是完整账本复制。
  - 明确 Widget 当前读取本机 App Group SQLite，不代表其他设备最新状态。
  - 将 Mac Catalyst、tvOS、visionOS 的可发布质量依赖调整到基础同步底座之后。
  - 新增 GOAL-1563 多端同步策略、GOAL-1564 同步元数据 / 冲突模型、GOAL-1565 iPhone / iPad / Mac 基础账本同步、GOAL-1566 Watch / Widget / 展示端快照同步。
- 未完成内容：未选择 CloudKit 或 iCloud Drive BackupBundle 作为最终同步方案；未实现任何同步代码；未做真机多设备验证。
- 测试情况：
  - PASS：`git diff --check`。
- 风险与注意事项：后续若引入 CloudKit private database，需要同步验证 Apple Developer capability、entitlements、Xcode Cloud signing、隐私披露和离线冲突；如果继续使用 BackupBundle，需要避免把它误写成无感实时同步。
- 回滚方式：回退本轮 README / CHANGELOG / iteration-log / v1.5.0 plan 文档变更。
- 结论：v1.5.0 规划已把基础多端数据同步提升为必须收口的底座任务。
- 下一步建议：进入 GOAL-1563 前，先审计当前 SQLite、BackupBundle、WatchConnectivity、Widget App Group 和 iCloud entitlement 的真实能力，再决定同步介质。

### ITER-106 GOAL-1521A Widget accessory UI
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / 表盘小组件
- 类型：能力增强 / Widget / UI
- 目标：在不新增 Xcode target 的前提下，先为现有 `DailyExpenseWidget` 补齐可复用的 accessory inline / circular / rectangular 今日支出 UI。
- 改动范围：
  - `AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift`：`DailyExpenseWidgetView` 根据 `widgetFamily` 分流系统小组件和 accessory family；新增 inline、circular、rectangular 三种今日支出展示；`DailyExpenseWidget` 支持 `.accessoryInline`、`.accessoryCircular`、`.accessoryRectangular`。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：记录 GOAL-1521A 的完成范围和 true Watch complication target 缺口。
- 未改动范围：未新增 watchOS WidgetKit extension target；未修改 Xcode project、scheme、target、Bundle ID、signing、entitlements、App Group 或 iCloud Container；未实现表盘点击深链；未新增隐私隐藏开关。
- 完成内容：
  - Accessory Inline 显示 `今日支出 ¥xx` / `Today ¥xx`。
  - Accessory Circular 显示压缩金额和今日笔数。
  - Accessory Rectangular 显示标题、压缩金额和今日笔数。
  - 三种 accessory family 复用现有 `WidgetLedgerStore.loadMetrics()` 今日支出口径。
  - 当前实现可覆盖 iPhone 锁屏 / 待机等 accessory widget 场景，并可作为后续 Watch complication target 的 UI 复用基础。
- 未完成内容：Apple Watch 表盘 complication 尚未真正接入，因为当前工程没有独立 watchOS WidgetKit extension target，也没有 Watch App 嵌入该 extension 的配置。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerWidgetsExtension -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：不要把本轮描述为“Watch 表盘小组件已上线”；它只是完成 accessory UI 和数据口径复用。真正 Watch 表盘能力需要后续谨慎新增 target、bundle id、entitlements、embedding 和 Xcode Cloud 验证。
- 回滚方式：回退 `DailyExpenseWidgetView` 的 `widgetFamily` 分流、三种 accessory view、`.supportedFamilies` 扩展和对应文档记录。
- 结论：GOAL-1521A 部分完成；Widget accessory UI 已有可复用实现，但 Watch complication target 仍是后续工程任务。
- 下一步建议：拆分 GOAL-1521B，专门新增 watchOS WidgetKit extension target，并在不破坏 Xcode Cloud 的前提下做 Watch / iOS 双构建验证。

### ITER-105 GOAL-1512 Watch 最近支出第二屏
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 1 / Watch 今日支出与最近支出
- 类型：能力增强 / Watch UI / WatchConnectivity
- 目标：完善 Watch 左滑第二屏，让最近支出列表具备当前账本提示、短时间文案和单笔只读详情入口，方便真机点验同步结果。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：最近账单 payload 增加分类和来源展示字段。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchTransaction.swift`：扩展 Watch 侧交易模型，增加分类、来源、相对日期、详情时间、备注兜底等只读展示属性。
  - `AutoLedger/AutoLedgerWatch Watch App/ContentView.swift`：第二页增加当前账本提示，最近支出行改为 `NavigationLink`，新增单笔只读详情页。
  - `AutoLedger/AutoLedgerWatch Watch App/*.lproj/Localizable.strings`：补齐详情页、来源、备注、今天 / 昨天三语文案。
  - `CHANGELOG.md`、`process/iteration-log.md`、`versions/v1.5.0-plan.md`：回填 GOAL-1512 执行结果。
- 未改动范围：未实现 Watch 端编辑、删除、批量操作或账本切换；未修改 Watch pending 队列格式；未新增 Watch complication target；未修改 Xcode project、scheme、target、Bundle ID、signing、entitlements、App Group 或 iCloud Container。
- 完成内容：
  - Watch 第二页顶部显示最近支出标题和当前默认账本名。
  - 最近支出列表仍限制最近 5 笔，保持 Watch 小屏可扫读。
  - 行内时间改为“今天 / 昨天 / MM/dd + HH:mm”，减少完整日期占用。
  - 点按最近支出可进入只读详情，查看金额、商户、分类、来源、时间和备注。
  - 旧 payload 未带分类或来源时，Watch 详情页会显示兜底分类 / 来源，不影响解析。
- 未完成内容：未在真实 Apple Watch 上点验左右滑、详情返回和大字号；未实现详情页编辑或跳转 iPhone 深链。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`find 'AutoLedger/AutoLedgerWatch Watch App' -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
- 风险与注意事项：详情页目前是只读，不处理账单编辑或删除；分类和来源来自 iPhone 端展示标题，后续若做 Watch 多语言动态分类，需要再统一本地化来源。
- 回滚方式：回退 WatchConnectivityHost 的分类 / 来源 payload 字段、WatchTransaction 展示扩展、ContentView 第二页导航详情、本地化 key 和对应文档记录。
- 结论：GOAL-1512 完成；Watch 小闭环已具备今日支出首页、最近支出第二页和单笔详情。
- 下一步建议：进入 GOAL-1521 或重新拆分 Watch complication 目标，开始表盘小组件 UI 与跳转；同时建议用真机 Apple Watch 点验 GOAL-1511 / GOAL-1512 的滑动和同步手感。

### ITER-104 GOAL-1511 Watch 首屏今日支出
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 1 / Watch 今日支出与最近支出
- 类型：能力增强 / Watch UI / WatchConnectivity
- 目标：将 Watch App 打开后的第一屏从最近账单列表切换为今日支出摘要，同时保留快速记账、语音记账和最近支出入口。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：同步 payload 新增 `todaySummary`。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchTransaction.swift`：新增 Watch 侧 `WatchTodaySummary` 轻量模型和旧 payload fallback。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`、`WatchLedgerViewModel.swift`：接收并暴露今日支出摘要。
  - `AutoLedger/AutoLedgerWatch Watch App/ContentView.swift`：首屏改为今日支出摘要，最近 5 笔保留为左滑第二页。
  - `AutoLedger/AutoLedgerWatch Watch App/*.lproj/Localizable.strings`：补齐今日支出和最近支出三语文案。
  - `AutoLedger/AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`：更新 Watch 截图 fixture 的今日支出摘要。
- 未改动范围：未新增 Watch complication / 表盘小组件 target，未修改 Watch pending 队列格式，未修改 SQLite schema、BackupBundle、Xcode project、scheme、target、Bundle ID、signing、entitlements、App Group 或 iCloud Container。
- 完成内容：
  - iPhone 端 `syncTransactions` 仍保留 `transactions` 与 `customCategories`，并新增 `todaySummary` 字典。
  - Watch 端收到新 payload 时展示今日总额、今日笔数、最近展示名和更新时间。
  - 旧 iPhone payload 未带 `todaySummary` 时，Watch 可从最近账单做本地今日摘要 fallback。
  - Watch 首屏提供语音记账和快速记账图标按钮；Toolbar 中的既有入口继续保留。
  - 最近支出列表移到第二页，展示最近 5 笔，不引入复杂编辑。
- 未完成内容：未实现单笔只读详情页；未做真实 Apple Watch 实机点验；未新增表盘小组件。
- 测试情况：
  - PASS：`find 'AutoLedger/AutoLedgerWatch Watch App' -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' build`。
- 风险与注意事项：Watch 首屏信息密度比旧列表更高，仍需要真机大字号 / VoiceOver / 小表盘尺寸目检；当前默认账本名在 Watch 侧做本地化兜底，多账本上线后仍需统一真实账本名的跨端显示策略。
- 回滚方式：回退 WatchConnectivityHost 的 `todaySummary` payload、WatchTodaySummary、Watch session/view model 状态、ContentView 首屏改造、本地化 key 和截图 fixture。
- 结论：GOAL-1511 完成；Watch App 已具备“抬腕看今日支出”的第一屏。
- 下一步建议：继续 GOAL-1512，补单笔只读详情与第二页实机手感，或进入 GOAL-1521 规划 Watch 表盘小组件。

### ITER-103 GOAL-1520 iPhone Widget 今日支出口径
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 2 / Widget 今日支出
- 类型：能力增强 / Widget / 数据口径
- 目标：回答并落实“今日支出是否覆盖 iPhone 桌面小组件与负一屏”，将现有 `DailyExpenseWidget` 纳入 GOAL-1510 今日支出口径。
- 改动范围：
  - `AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift`：调整 Widget 数据读取、日期边界、正金额过滤和最近展示名回退。
  - `versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：记录 GOAL-1520 范围调整和执行结果。
- 未改动范围：未新增 Watch complication / 表盘小组件 target，未修改 Widget UI 视觉布局，未修改 Watch App UI，未改 Xcode project、Bundle ID、signing、App Group、iCloud 或 entitlements。
- 完成内容：
  - 确认现有 `DailyExpenseWidget` 覆盖 iPhone 桌面小组件和 iPhone 负一屏 / Today View。
  - 今日支出查询改为 `deleted_at IS NULL` + `amount > 0`。
  - 今日边界使用 `Calendar.autoupdatingCurrent` 的本地日区间。
  - Widget SQLite 日期查询对齐 `SQLiteTransactionStore` 的 ISO8601 fractional seconds 存储格式，并保留旧格式解析 fallback。
  - 最近展示名按商户 -> 分类 -> 来源回退，避免商户为空时空白。
- 未完成内容：Watch 表盘小组件仍未创建 target / UI；Widget extension 当前没有直接 import `AutoLedgerCore`，本轮通过同口径规则保持一致。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：Widget extension 仍有一份本地 SQLite 读取逻辑，后续如果允许调整 target 依赖，可评估让 Widget 直接复用 Core 层 summary / transaction decoder，进一步减少口径漂移。
- 回滚方式：回退 `AutoLedgerWidgets.swift` 的数据读取改动和对应文档记录。
- 结论：iPhone 桌面小组件与负一屏已纳入今日支出口径；GOAL-1520 先记为 PARTIAL DONE，Watch 表盘小组件后续单独收口。
- 下一步建议：继续 GOAL-1511，把 Watch App 首屏切换为今日支出。

### ITER-102 GOAL-1510 Watch 今日支出数据服务
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 1 / Watch 今日支出与最近支出
- 类型：能力增强 / Core / 测试
- 目标：完成 GOAL-1510，在 Core 或 App 层提供今日支出 summary，包含总金额、笔数、最近商户 / 展示名、空状态和本地日边界，为 Watch 首屏、Widget 和后续展示平台提供统一数据口径。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/TodaySpendingSummary.swift`：新增 Core 级今日支出 summary。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：新增 `todaySpendingSummary` 只读属性。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增并接入今日支出口径回归。
  - `versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填执行结果。
- 未改动范围：未修改 Watch UI、Widget、WatchConnectivity payload、SQLite schema、BackupBundle、多账本字段、Xcode project 或发布链配置。
- 完成内容：
  - `TodaySpendingSummary.build` 接受活跃正式账单数组、reference date 和 calendar，返回默认账本、日区间、总金额、笔数、最近交易、最近展示名和空状态。
  - 今日支出按 `amount > 0` 与 `[localStartOfDay, nextLocalStartOfDay)` 过滤。
  - 最近交易按 `occurredAt` 倒序；商户为空时展示名回退到分类，再回退来源。
  - `LedgerStore.todaySpendingSummary` 使用当前 `transactions`，因此已删除账单不会进入 summary。
  - 离线回归覆盖今日 / 昨日 / 零负金额 / 自定义分类来源 / active input contract / 日边界 / 展示名回退。
- 未完成内容：Watch 首屏尚未切换到今日支出；表盘小组件尚未接该数据；多账本上线后还需由调用方按账本过滤输入。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`，仅有既有 `nonisolated(unsafe)` warning。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`。
- 风险与注意事项：当前 `Transaction` 仍没有 `createdAt` / `updatedAt`，同一 `occurredAt` 的最近排序只能按展示名做稳定兜底；多账本上线前 summary 默认视为 `default-local-ledger`。
- 回滚方式：回退 `TodaySpendingSummary.swift`、`LedgerStore.todaySpendingSummary`、离线回归新增用例和对应文档记录。
- 结论：GOAL-1510 完成，可以进入 GOAL-1511 Watch 首屏 UI。
- 下一步建议：执行 GOAL-1511，将 Watch App 首屏从最近账单列表切换为今日支出摘要，并保留快速记账入口。

### ITER-101 GOAL-1503 SQLite / BackupBundle schema 缺口评估
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 设计与数据口径校准
- 类型：文档 / schema 设计 / 治理
- 目标：完成 GOAL-1503，基于当前 `Transaction`、`SQLiteTransactionStore`、`BackupBundle` 和 `LedgerStore` 备份恢复实现，评估多账本与候选账单所需 schema 缺口，输出兼容旧数据和 v1 备份的迁移方案。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增“SQLite / BackupBundle 迁移方案（GOAL-1503）”，记录当前 schema 事实、迁移原则、schema version 策略、多账本表、候选区表、BackupBundle v2 草案、推荐实施顺序和回归要求。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮执行结果。
- 未改动范围：未修改 `Transaction`、未新增 `Ledger` model、未新增或迁移 SQLite 表、未升级 BackupBundle、未修改备份恢复实现、未接 UI、未修改 Xcode project 或发布链配置。
- 完成内容：
  - 确认当前正式账单模型缺少 `ledgerId`、`currencyCode`、`transactionType` 等字段，SQLite `transactions` 表已有 timestamp / soft delete 但无账本归属。
  - 确认 `debug_events` 是调试日志，不适合作为 iPad / Mac 候选队列。
  - 建议引入 `PRAGMA user_version` 管理复杂 schema 迁移，保留列存在性检测作为兼容小迁移。
  - 规划 `ledgers` 表，并将旧账单全部回填到固定默认账本 `default-local-ledger`。
  - 规划独立候选区表：`import_batches`、`raw_inputs`、`candidate_transactions`、`candidate_events`。
  - 规划 BackupBundle v2：支持 ledgers、transaction extensions、optional candidates，并继续兼容 v1 恢复。
  - 明确自动 iCloud backup 默认不包含原始图片、PDF 或 OCR 全文。
- 未完成内容：schema 尚未编码；BackupBundle v2 尚未实现；候选队列、多账本 UI、CSV / JSON 导入导出仍待后续 GOAL。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，仅有既有 Swift warning。
- 风险与注意事项：BackupBundle 新增非可选字段会破坏旧 JSON 解码，后续实现 v2 时必须使用 optional/default/custom Decodable；候选区 raw input 涉及敏感财务数据，自动备份和公开样例必须默认排除。
- 回滚方式：如后续 schema 方向调整，可回退 `versions/v1.5.0-plan.md` 中 GOAL-1503 段落和对应日志 / changelog 条目，不影响代码。
- 结论：GOAL-1503 完成，可以进入 GOAL-1510 今日支出数据服务，或进入 GOAL-1560 多账本模型与默认账本迁移实现。
- 下一步建议：优先执行 GOAL-1510，把 GOAL-1501 的今日支出口径落成可测试服务，为 Watch 首屏和 Widget 提供数据基础。

### ITER-100 GOAL-1502 候选账单状态模型设计
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 设计与数据口径校准
- 类型：文档 / 模型设计 / 治理
- 目标：完成 GOAL-1502，定义 Raw Input / Candidate / Reviewed / Transaction / Rejected 状态流、失败原因、置信度策略、重复提示字段和隐私边界，为 iPad / Mac 批量导入、复核、清洗和正式入账提供统一契约。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增“候选账单状态模型（GOAL-1502）”，定义状态流、最小字段草案、失败原因枚举、置信度与复核策略、重复提示策略、后续落库 / BackupBundle 边界和测试用例设计。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮执行结果。
- 未改动范围：未新增 Swift model、未新增 SQLite 表、未升级 BackupBundle、未实现批量导入队列、未接 iPad / Mac 候选区真实 UI、未修改 Xcode project 或发布链配置。
- 完成内容：
  - 明确 `rawInput -> candidate -> reviewed -> transaction` 主路径，以及 raw / candidate 转 `rejected`、candidate 重试和 reviewed 提交失败回退路径。
  - 明确只有正式 `transaction` 写入当前账本并进入今日支出、月报、Top 商户和展示平台统计。
  - 给出候选记录字段组：身份与批次、原始输入、解析草稿、扩展草稿、状态与质量、重复提示、复核与入账、隐私与清理。
  - 定义 `emptyInput`、`ocrFailed`、`nonBillImage`、`missingAmount`、`missingMerchant`、`missingDate`、`lowConfidence`、`multipleReceipts`、`duplicateSuspected` 等失败原因。
  - 定义 High / Medium / Low 置信度策略：置信度只影响复核优先级，批量导入场景不绕过用户确认自动入账。
  - 明确重复检测只提示和分组，不自动删除候选或正式账单。
  - 标出原图、OCR 全文、PDF 文本等原始输入的隐私边界，以及 BackupBundle schema v2 的后续评估点。
- 未完成内容：候选模型尚未编码；SQLite / BackupBundle 迁移尚未设计；批量导入队列、iPad 候选列表和数据清洗执行逻辑仍待后续 GOAL。
- 测试情况：执行 `git diff --check`，结果 PASS；本轮只改文档，未运行构建。
- 风险与注意事项：后续实现时不能让候选记录复用正式 `Transaction` 表并参与统计；如果备份候选区或原始输入，必须显式处理隐私和 schema 兼容。
- 回滚方式：如后续模型口径调整，可回退 `versions/v1.5.0-plan.md` 中 GOAL-1502 段落和对应日志 / changelog 条目，不影响代码。
- 结论：GOAL-1502 完成，可以进入 GOAL-1503 SQLite / BackupBundle schema 缺口评估。
- 下一步建议：执行 GOAL-1503，评估 `Transaction`、SQLite、BackupBundle、默认账本和候选区落库的兼容迁移方案。

### ITER-099 GOAL-1501 默认账本与今日支出口径
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 设计与数据口径校准
- 类型：文档 / 口径定义 / 治理
- 目标：完成 GOAL-1501，明确默认账本、全部账本、今日支出、最近支出、币种和后续测试用例口径，为 Watch 今日支出、Widget、iPad 总览、Mac Catalyst、tvOS 和 visionOS 展示提供同一套统计基础。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增“默认账本与今日支出口径（GOAL-1501）”，定义虚拟默认账本 `default-local-ledger`、今日支出统计范围、日期边界、最近支出、币种边界和 GOAL-1510 测试用例设计。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮执行结果。
- 未改动范围：未新增 `Ledger` 模型、未修改 `Transaction` / SQLite / BackupBundle、未实现今日支出数据服务、未改 Watch / Widget / iPad UI、未改 Xcode project 或发布链配置。
- 完成内容：
  - 在多账本上线前，所有活跃正式账单视为属于虚拟默认账本；多账本迁移后旧账单统一进入 `default-local-ledger`。
  - 今日支出只统计本地日历日内、`occurredAt` 命中、金额大于 0、未删除、已确认的正式账单。
  - 候选账单、已删除账单、零 / 负金额、订阅元数据和未确认多币种不进入今日支出。
  - Watch / Widget / tvOS / visionOS 首版默认展示默认账本；iPad / Mac 工作台可在后续显式选择当前账本或全部账本。
  - 为 GOAL-1510 列出 today / yesterday / deleted / candidate / zero-negative / custom category / timezone boundary / default ledger scope 等离线测试设计。
- 未完成内容：统计服务尚未编码；测试用例尚未落地到脚本；多账本 schema 和 BackupBundle 迁移仍待 GOAL-1503 / GOAL-1560。
- 测试情况：执行 `git diff --check`，结果 PASS；本轮只改文档，未运行构建。
- 风险与注意事项：当前 `AppFormatters.calendar` 是固定 Gregorian calendar，后续编码今日支出服务时应显式注入用户本地 calendar / timezone，避免 UTC 或测试环境差异；当前 `Transaction` 没有币种和类型字段，未来收入 / 退款 / 多币种能力需要单独 schema 设计。
- 回滚方式：如后续产品口径调整，可回退 `versions/v1.5.0-plan.md` 中 GOAL-1501 段落和对应日志 / changelog 条目，不影响代码。
- 结论：GOAL-1501 完成，可以进入 GOAL-1502 候选账单状态模型设计，或在需要 Watch UI 前进入 GOAL-1510 今日支出数据服务实现。
- 下一步建议：执行 GOAL-1502，定义 Raw Input / Candidate / Reviewed / Transaction / Rejected 状态和失败 / 置信度 / 重复提示字段。

### ITER-098 v1.5.0 全平台扩展路线规划
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 7+ / 全平台扩展规划
- 类型：文档 / 产品规划 / 治理
- 目标：更新当前 v1.5.0 版本计划，把 iPad 完善后的路线扩展到 Mac Catalyst、tvOS 和 visionOS，明确平台定位、首版能力、边界和 GOAL 拆解。
- 改动范围：
  - `versions/v1.5.0-plan.md`：将版本定位从多设备工作流扩展为全平台本地优先账单工作流；补充 Mac Catalyst、tvOS、visionOS 的产品定位、能力范围、验收口径、风险和 GOAL 队列。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮文档规划更新。
- 未改动范围：未修改 Xcode project、target、scheme、Bundle ID、signing、entitlements、App Group、iCloud Container、业务代码、截图脚本或构建配置。
- 完成内容：
  - Mac Catalyst 路线明确为 iPad 工作台稳定后的生产力扩展，首版覆盖拖拽截图 / 文件导入、CSV / JSON 导入导出、快捷键、基础菜单栏、大表格、批量选择、批量修正和重复账单检查。
  - tvOS 路线明确为只读家庭大屏看板，覆盖本月支出总览、分类占比、最近消费趋势、年度 / 月度摘要和隐私模式。
  - visionOS 路线明确为空间展示版本，覆盖月度空间看板、漂浮分类卡片、年度时间线墙和最近账单悬浮列表。
  - GOAL 队列扩展到 GOAL-1570～GOAL-1592，拆分 Mac Catalyst、tvOS、visionOS、全平台截图与发布回归。
- 未完成内容：未开启 Mac Catalyst、tvOS 或 visionOS target；未实现任何新平台代码；未新增截图管线实现。
- 测试情况：文档更新；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：全平台规划不等于当前发布承诺；Mac 需等待 iPad 工作台、候选队列、数据清洗和多账本稳定后再接入；tvOS / visionOS 首版必须保持只读展示，避免新增写入链路和同步口径分叉。
- 回滚方式：如后续决定收窄范围，可回退 `versions/v1.5.0-plan.md` 的全平台扩展段落和 GOAL 队列增量，保留 iPad / Watch 原计划。
- 结论：本轮完成，v1.5.0 计划已从 iPhone / Watch / iPad 扩展为 iPad → Mac Catalyst → tvOS / visionOS 的全平台路线。
- 下一步建议：继续按现有顺序完成 iPad 工作台、候选队列、批量导入、数据清洗和多账本，再启动 GOAL-1570 Mac Catalyst 接入评估。

### ITER-097 GOAL-1531 iPad 工作台深化与部署烟测
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 3 / iPad 信息架构与入口策略
- 类型：能力增强 / iPad / SwiftUI / 文档
- 目标：继续完成 iPad 线，让当前 main 可以构建到 iPad 目标并具备可上真机测试的 iPad 工作台主路径。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：把 iPad 工作台从首版壳层深化为总览、导入、账本、分析、候选账单、数据清洗和设置结构；账本区采用 iPad 原生列表 + 详情检查器，接入真实 `LedgerStore` 交易数据与编辑 / 删除 / 新增 / 语音入口。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：补齐总览指标、最近账单、整理工作流、详情检查器、候选账单和数据清洗规划项的中英繁三语文案。
  - `versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填执行结果与部署验证方式。
- 未改动范围：未新增候选账单状态模型、批量 OCR、数据清洗执行器、多账本、SQLite schema 迁移、BackupBundle schema 升级、iPad 截图导出脚本或 Mac Catalyst。
- 完成内容：iPad 首屏进入工作台总览；账本在 iPad 上不再只是复用手机列表，而是具备宽屏列表和右侧检查器；空状态下可继续通过导入 / 新增 / 语音入口进入现有账单链路；候选账单与数据清洗以规划工作区形式留出后续落点。
- 未完成内容：真机 iPad 还需用户在 Xcode 设备列表中完成签名部署验证；通知权限、相册权限、相机权限、Share Extension 和 Watch 配套仍需真机人工回归。
- 测试情况：
  - `git diff --check`：PASS。
  - `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`：PASS。
  - `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`：PASS。
  - `xcrun simctl install 5784B992-36AB-4721-9537-5C24E8DD2D86 .../AutoLedger.app` + `xcrun simctl launch ... top.darkrio326.AutoLedger`：PASS，iPad 工作台截图已确认侧边栏与总览渲染。
  - `bash scripts/run_offline_regression.sh`：PASS，仅有既有 Swift warning。
  - `bash scripts/run_golden_regression.sh`：PASS，32 case(s)，仅有既有 Swift warning。
- 风险与注意事项：当前 iPad 工作台仍是 v1.5.0 的第一版真实工作区，候选账单和数据清洗尚未接数据模型；真机签名可能受本机证书、设备注册、Apple Developer Team 或 Xcode 26 beta 环境影响，但本轮未修改这些发布链配置。
- 回滚方式：如 iPad 工作台在真机出现阻断，可回退 `IPadWorkspaceView.swift` 和本地化文案到 GOAL-1530 状态；iPhone 原 `HomeView` 主路径未被改动。
- 结论：本轮完成，main 已具备 iPad Simulator build/install/launch 证据，可以进入真机 iPad 部署测试。
- 下一步建议：在真机 iPad 上用 Xcode 选择 `AutoLedger.xcworkspace` / `AutoLedger` scheme / 目标 iPad 直接 Run；通过后进入 GOAL-1501 / GOAL-1502 / GOAL-1503，补默认账本、候选账单模型和持久化迁移方案。

### ITER-096 GOAL-1530 iPad 线第一版入口
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 3 / iPad 信息架构与入口策略
- 类型：能力增强 / iPad / SwiftUI / 文档
- 目标：执行 GOAL-1530，先建立 iPad 线入口：主 App 支持 iPad 设备族，iPad 使用侧边栏工作台结构，iPhone 继续保持原 Tab 主路径。
- 改动范围：
  - `AutoLedger/AutoLedger.xcodeproj/project.pbxproj`：主 App target Debug / Release 设备族切为 iPhone + iPad，并显式保持 iOS / iPadOS 平台与 Mac Catalyst 关闭。
  - `AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：根视图按 iPad / 非 iPad 分流，iPad 进入 `IPadWorkspaceView`，iPhone 继续进入 `HomeView`。
  - `AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift`：新增 iPad `NavigationSplitView` 工作台壳层。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：补齐 iPad 工作台中英繁三语文案。
  - `versions/v1.5.0-plan.md`、`CHANGELOG.md`、`process/iteration-log.md`：回填执行结果。
  - `LICENSE`：保留本轮开始前已有的版权主体更新。
- 未改动范围：未实现候选账单真实数据模型、批量 OCR、数据清洗执行、多账本、SQLite schema 迁移、BackupBundle schema 升级、iPad 截图导出脚本或 Mac Catalyst。
- 完成内容：
  - iPad 设备进入 `IPadWorkspaceView`，采用 sidebar + detail 工作台结构。
  - Sidebar 当前包含导入、账本、分析、候选账单、数据清洗、设置。
  - 导入、账本、分析、设置复用现有 `InboxView` / `LedgerView` / `ReportView` / `SettingsView`。
  - 候选账单与数据清洗仅为规划入口，使用占位页，不写入正式账本或本地数据库。
  - Quick Ledger 导航事件在 iPad 工作台中会切到账本。
  - 三语本地化已补齐。
- 未完成内容：GOAL-1501 / GOAL-1502 / GOAL-1503 仍未执行；iPad 后续真实工作台骨架应进入 GOAL-1531。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`git diff --check`
- 风险与注意事项：
  - 本轮没有运行 iPad Simulator 人工目检；需要在 GOAL-1531 前用真实 iPad 模拟器检查 sidebar / detail 嵌套导航体验。
  - 当前 iPad 工作台复用的 iPhone 页面内部仍各自持有 `NavigationStack`，后续深化时应逐步拆出更适合 iPad 的列表 / 详情 / 检查器组件。
  - 候选账单和数据清洗入口是占位，不应在发布文案中声明为已完成能力。
- 回滚方式：回退 `IPadWorkspaceView.swift`、`AutoLedgerApp.swift` 的 iPad 分流、三语 iPad 文案、主 App target 设备族改动和对应文档记录。
- 结论：GOAL-1530 已完成，AutoLedger 已具备 iPad 线第一版入口，仍可保持 iPhone 发布主路径。
- 下一步建议：进入 GOAL-1501 / GOAL-1502 / GOAL-1503 补底层口径与 schema，再推进 GOAL-1531 iPad 工作台真实骨架。

### ITER-095 GOAL-1500 v1.5.0 基线审计
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 基线审计
- 类型：文档 / 版本治理 / 回归验证
- 目标：执行 GOAL-1500，建立当前 v1.5.0 工程事实基线，记录版本号、设备族配置、数据模型/SQLite/BackupBundle 缺口、截图管线现状和最小回归结果。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增 GOAL-1500 执行记录，记录 Git / 版本 / workspace / scheme / target / 数据模型 / 截图管线 / 验证结果。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未实现 Watch、Widget、iPad、批量导入、多账本、数据清洗或截图管线功能；未修改 Swift 源码、SQLite schema、截图脚本、Bundle Identifier、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、scheme 或 target 名称。
- 完成内容：
  - 确认当前分支为 `main`，HEAD 为 `ce6c054 chore: switch to internal 1.5.0 development`，`v1.4.0` tag 指向内部 v1.4.0 / App Store v1.3.0 发布基准。
  - 确认全 target `MARKETING_VERSION = 1.4.0`，`CURRENT_PROJECT_VERSION = 1`。
  - 确认主 App 当前工作区设备族为 iPhone + iPad，Watch target、Widget、Share Extension、Control Widget target 仍存在。
  - 记录 `Transaction`、SQLite 与 `BackupBundle.schemaVersion = 1` 对多账本、候选账单、导入批次和清洗历史的缺口。
  - 记录 `tools/appstore-screenshots` 当前只覆盖 iPhone / Apple Watch，不包含 iPad target、iPad scenes 或 iPad preview 分组。
- 未完成内容：GOAL-1501 默认账本与今日支出口径、GOAL-1502 候选账单状态模型、GOAL-1503 SQLite / BackupBundle 迁移方案尚未执行。
- 测试情况：
  - PASS：`xcodebuild -list -workspace AutoLedger/AutoLedger.xcworkspace`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`
- 风险与注意事项：
  - 本轮开始前已有未提交的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 与 `LICENSE` 改动，GOAL-1500 仅记录其当前事实，不回退、不混入业务实现。
  - `LedgerStore.makeBackupBundle()` 读取不到 bundle 版本时仍有 `"1.3.0"` fallback，后续版本治理可清理。
  - 多账本、候选账单、导入队列和数据清洗动作进入实现前，应先完成 schema / backup / migration 设计。
- 回滚方式：回退 `versions/v1.5.0-plan.md` 的 GOAL-1500 执行记录，以及 `CHANGELOG.md` / `process/iteration-log.md` 对应条目。
- 结论：GOAL-1500 已完成，当前 v1.5.0 可进入 GOAL-1501 / GOAL-1502 的口径与模型设计。
- 下一步建议：先执行 GOAL-1501 定义默认账本与今日支出口径，再执行 GOAL-1502 候选账单状态模型；不要直接跳到 iPad 或 Watch UI。

### ITER-094 v1.5.0 GOAL 目标拆解
- 日期：2026-06-01
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 计划评审
- 类型：文档 / 版本治理
- 目标：评审当前 v1.5.0 版本计划，把大范围规划拆成可由 agent 按轮驱动的 GOAL 目标。
- 改动范围：
  - `versions/v1.5.0-plan.md`：新增“计划评审与 GOAL 拆解”，补充评审结论、GOAL 执行规则、GOAL-1500～GOAL-1590 队列、推荐推进顺序和首个可执行 GOAL 建议。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未实现任何 v1.5.0 功能；未修改 Xcode project、业务代码、截图脚本、数据库 schema 或本地化文案。
- 完成内容：已把 Watch 今日支出、表盘小组件、iPad 工作台、批量导入与识别、数据清洗、多账本、Mac 复用评估、iPad 截图管线和发布回归拆成独立 GOAL，并为每个 GOAL 记录范围、验收标准、最小回归和依赖。
- 未完成内容：GOAL-1500 及后续目标尚未执行；本轮只完成计划拆解。
- 测试情况：仅文档变更，执行 `git diff --check` 作为格式门禁。
- 风险与注意事项：当前工作区另有未提交的 `project.pbxproj` 和 `LICENSE` 改动，本轮文档拆解不应混入这些无关变更。
- 回滚方式：回退 `versions/v1.5.0-plan.md` 的新增 GOAL 章节，以及 CHANGELOG / iteration-log 对应记录。
- 结论：本轮完成，v1.5.0 已具备可按 GOAL 分步驱动的执行队列。
- 下一步建议：从 GOAL-1500 建立工程事实基线开始，不直接跳到 iPad 或 Watch UI 实现。

### ITER-093 切换到内部 v1.5.0 / App Store v1.4.0
- 日期：2026-05-28
- 所属版本：v1.5.0
- 所属阶段：版本切换
- 类型：版本治理 / 文档 / 配置
- 目标：将当前项目从内部 v1.4.0 发布基准切换到内部 v1.5.0 开发线，并把 App Store 对外版本推进到 v1.4.0。
- 改动范围：
  - `AutoLedger/AutoLedger.xcodeproj/project.pbxproj`：全 target `MARKETING_VERSION` 从 `1.3.0` 更新为 `1.4.0`。
  - `README.md`、`README.en.md`：Roadmap 将内部 v1.5.0 状态更新为开发中。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：设置页“后续计划”文案切换到 v1.5.0 方向。
  - `versions/v1.5.0-plan.md`：记录当前项目版本值。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充追溯记录。
- 未改动范围：未修改 Bundle Identifier、DEVELOPMENT_TEAM、App Groups、iCloud Container、entitlements、scheme、target、Xcode Cloud 脚本或业务功能代码。
- 完成内容：工程商店版本已切到 `1.4.0`，内部开发线文档与 App 设置页文案已进入 v1.5.0 口径。
- 未完成内容：未实现 v1.5.0 功能；本轮只做版本切换。
- 测试情况：待执行 `xcodebuild -list` 和 Debug build 验证。
- 风险与注意事项：`CURRENT_PROJECT_VERSION` 仍保持现有值，构建号继续交给 Xcode Cloud / 发布流程处理；如果 App Store Connect 要求本地递增 build number，需要在发布前单独处理。
- 回滚方式：将 `MARKETING_VERSION` 恢复为 `1.3.0`，并回退本轮 README / Localizable / 版本文档改动。
- 结论：本轮完成后，后续代码工作应按内部 v1.5.0 规划推进。
- 下一步建议：运行构建验证后提交推送。

### ITER-092 内部 v1.4.0 发布基准与 v1.5.0 规划承接
- 日期：2026-05-28
- 所属版本：v1.4.0 / v1.5.0
- 所属阶段：发布基准 / 下一轮规划
- 类型：文档 / 版本治理
- 目标：记录内部 v1.4.0 对应的 App Store v1.3.0 已过审发布，并把后续开发承接到内部 v1.5.0。
- 改动范围：
  - `README.md`、`README.en.md`：Roadmap 标记内部 v1.4.0 / App Store v1.3.0 为已发布，并新增内部 v1.5.0 规划行。
  - `versions/v1.4.0-RELEASE(draft).md`：从发布前草稿状态更新为已发布基准记录。
  - `versions/v1.5.0-plan.md`：明确承接内部 v1.4.0 发布基准，面向下一轮 App Store v1.4.0 开发。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充追溯记录。
- 未改动范围：未修改 Xcode 工程、Bundle ID、签名、entitlements、截图脚本或业务代码。
- 完成内容：根目录 Roadmap、英文 README Roadmap、v1.4 发布基准文档和 v1.5 规划文档已对齐当前发布状态。
- 未完成内容：本轮不实现 v1.5.0 功能；iPad 截图管线、iPad 工作台、Watch 表盘小组件等仍停留在规划阶段。
- 测试情况：仅文档变更，未运行构建；执行 `git diff --check` 作为文档格式门禁。
- 风险与注意事项：`versions/v1.4.0-RELEASE(draft).md` 文件名仍保留 draft 字样以避免路径重命名影响既有链接，但标题和内容已标记为已发布基准。
- 回滚方式：回退本轮文档改动，并删除对应 tag 即可。
- 结论：本轮完成，内部 v1.4.0 可作为 App Store v1.3.0 已发布基准打 tag，后续开发进入 v1.5.0。
- 下一步建议：打 `v1.4.0` tag 并推送 main / tag；新功能开发从 v1.5.0 规划拆分任务。

### ITER-091 v1.5.0 iPad 截图管线规划记录
- 日期：2026-05-28
- 所属版本：v1.5.0
- 所属阶段：Phase 0 / 设计与数据口径校准
- 类型：文档 / 发布资产规划
- 目标：记录当前 App Store 截图管线尚未覆盖 iPad，并把 iPad 截图扩展明确纳入 v1.5.0 规划。
- 改动范围：
  - `versions/v1.5.0-plan.md`：修正“现有截图管线已经覆盖 iPad 端”的错误表述，明确当前仅覆盖 iPhone 与 Apple Watch；补充 v1.5.0 iPad 截图管线扩展范围、验收口径和施工前清单。
  - `tools/appstore-screenshots/README.md`：在 Not Implemented 中保留 iPad screenshots 限制，并指向 v1.5.0 规划。
  - `CHANGELOG.md`：补充本轮文档变更记录。
- 未改动范围：未修改截图导出脚本、截图 host、Xcode 工程、target、scheme、Bundle ID、entitlements 或 Xcode Cloud 配置。
- 完成内容：v1.5.0 规划已明确要求补齐 `--ipad-only`、iPad target size、横屏工作台画布、稳定演示数据、多语言输出目录和 `preview.html` 分组目检。
- 未完成内容：iPad 截图管线尚未实现；iPad 工作台 UI、截图 fixture、渲染模板和导出脚本仍待 v1.5.0 实施阶段处理。
- 测试情况：仅文档变更，未运行构建；执行文档 diff / whitespace 检查即可。
- 风险与注意事项：在 iPad 管线实现前，不应把 App Store iPad 截图资产标记为已准备完成；后续若决定发布 iPad 端，需要预留截图实现、导出和人工目检时间。
- 回滚方式：回退本轮文档记录即可，不影响现有 iPhone / Watch 截图管线。
- 结论：本轮完成，iPad 截图管线缺口已记录为 v1.5.0 正式规划项。
- 下一步建议：v1.5.0 开工前先确认 iPad 信息架构、首屏横屏布局、演示数据口径和 App Store 截图尺寸，再进入脚本实现。

### ITER-090 App Store 截图管线稳定性修复
- 日期：2026-05-28
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / 截图工具 / 本地化
- 目标：修复繁体截图导出时页面继承模拟器大字体，以及 `00_preview` 首张 raw screenshot 可能捕获到模拟器黑屏的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Screenshots/ScreenshotHostView.swift`：截图宿主根视图固定 Dynamic Type 为默认 `.large`，避免继承模拟器辅助功能大字体设置。
  - `AutoLedger/AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`：Watch 截图宿主同样固定 Dynamic Type，保持自动截图输出稳定。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchLedgerViewModel.swift`：截图模式下跳过真实 WatchConnectivity 初始同步和刷新，避免最近账单 fixture 被空会话状态覆盖。
  - `tools/appstore-screenshots/scripts/export_ios.sh`、`tools/appstore-screenshots/scripts/export_watch.sh`：启动截图模式时传入 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryL`，并在写入 raw PNG 前检测 mostly black 画面，最多重试 5 次。
  - `tools/appstore-screenshots/README.md`：补充黑屏与大字体排查说明。
  - `README.md`：新增截图预览 HTML 入口，方便从根目录 README 打开本地生成的截图总览。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未修改实际 App 正常运行时的 Dynamic Type 支持；未修改营销图模板字体大小、截图场景内容、OCR、账本、IAP 或 Watch 同步逻辑；未把生成 PNG 纳入 Git 跟踪。
- 完成内容：截图模式不再受模拟器全局文字大小影响；首张截图若遇到黑屏首帧会自动重试；本轮重新导出 `zh-Hant` iPhone 截图后，`00_preview` 已不再黑屏，页面内字体恢复为默认尺寸；重新导出本版计划上传的 `zh-Hans` / `en` iPhone 与 Watch 截图，Watch 最近账单截图已恢复为三条 fixture 记录；根 README 可直接跳转到本地 `preview.html` 总览。
- 未完成内容：繁体中文截图本版暂不作为 App Store 上传资产；Watch 自动截图仍需在最终上传前按 `preview.html` 做人工目检。
- 测试情况：
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hant`
  - PASS：`bash tools/appstore-screenshots/scripts/export.sh --locale zh-Hans --locale en`
  - PASS：黑屏像素检查确认 `tools/appstore-screenshots/output/raw/ios/zh-Hant/00_preview.png` dark pixel 约 1.23%，不是黑屏。
  - PASS：目检 `tools/appstore-screenshots/output/store/ios/zh-Hant/00_preview.png`，页面内字体已恢复默认尺寸。
- 风险与注意事项：黑屏检测依赖 Pillow；若本机缺少 Pillow，脚本会跳过黑屏判断并在后续渲染步骤失败提示安装。生成截图仍需要最终人工目检布局、文案和裁切。
- 回滚方式：回退两个 ScreenshotHostView 的 Dynamic Type 固定、两个 export 脚本的 content size 参数与黑屏重试逻辑，以及 README / CHANGELOG / 本条日志。
- 结论：本轮完成，繁体 iPhone 截图管线已修复大字体继承和 `00_preview` 黑屏问题。
- 下一步建议：继续执行 `--locale zh-Hans`、`--locale en` 与 Watch 截图导出，确认三语言最终成品都无黑屏和异常字号。

### ITER-089 App Store 截图管线繁体中文输出
- 日期：2026-05-28
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：能力增强 / 本地化 / 截图工具
- 目标：在现有简体中文与英文 App Store 截图管线基础上，新增一套繁体中文截图输出，匹配 App UI 已覆盖中英繁三语的发布口径。
- 改动范围：
  - `tools/appstore-screenshots/config/screenshots.json`：新增 `zh-Hant` locale（`appleLanguages=(zh-Hant)`、`appleLocale=zh_TW`），并为 iPhone 与 Apple Watch 所有截图场景补齐繁体中文标题 / 副标题。
  - `AutoLedger/AutoLedger/Screenshots/ScreenshotHostView.swift`：截图宿主文案选择从简中 / 英文扩展为简中 / 繁中 / 英文三语，补齐导入方式等硬编码截图文案的繁体版本。
  - `AutoLedger/AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`：Watch 截图宿主同样识别 `zh-Hant`，补齐同步状态等截图内文案的繁体版本。
  - `tools/appstore-screenshots/scripts/export.sh`、`tools/appstore-screenshots/README.md`：更新 CLI 帮助、支持语言、导出示例和输出目录说明，支持 `--locale zh-Hant` 单独导出。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未修改 OCR、账本、IAP、设置页本地化资源、Watch 记账 / 同步逻辑，也未重新导出实际截图 PNG。
- 完成内容：截图配置、iPhone 截图宿主、Watch 截图宿主和截图工具文档已统一支持 `zh-Hant`；繁体截图可与 `zh-Hans`、`en` 一起批量导出，也可通过 `--locale zh-Hant` 单独导出。
- 未完成内容：未在本轮实际跑完整截图导出脚本生成 `tools/appstore-screenshots/output/zh-Hant` 图片；未上传 App Store Connect 截图。
- 测试情况：
  - PASS：截图配置 locale 覆盖检查，确认 `zh-Hans`、`zh-Hant`、`en` 均覆盖所有 iPhone / Watch 截图标题和副标题。
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -destination 'generic/platform=watchOS' build`
- 风险与注意事项：实际营销截图仍需跑导出脚本并目检繁体标题、副标题、设备截图裁切和 Watch 尺寸输出；App Store Connect 侧繁体截图需要按对应 locale 单独上传。
- 回滚方式：回退 `screenshots.json` 的 `zh-Hant` locale 与文案、两个 ScreenshotHostView 的三语选择改动，以及截图 README / export help 和本条文档记录。
- 结论：本轮完成，截图管线已具备繁体中文输出能力。
- 下一步建议：在发版截图前执行 `tools/appstore-screenshots/scripts/export.sh --locale zh-Hant`，检查输出图片后再上传到 App Store Connect 繁体中文 locale。

### ITER-088 Support IAP 价格刷新修复
- 日期：2026-05-28
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / StoreKit
- 目标：修复 TestFlight 中切换 App Store 商店区域后，Support AutoLedger 页面可能仍显示旧币种价格，而 App Store 购买弹窗显示新商店区域价格的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/SupportPurchaseManager.swift`：新增 `Storefront.updates` 监听，商店区域变化时强制重新拉取 StoreKit 产品并清空旧 `Product` 列表。
  - `AutoLedger/AutoLedger/Features/Settings/SupportAutoLedgerView.swift`：页面启动 storefront 监听，并在 App 回到前台时强制刷新产品，降低 TestFlight / 沙盒切区后继续显示旧 `displayPrice` 的概率。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未写死价格；未改变 IAP product id、App Store Connect 配置、购买 / 交易校验 / 交易完成逻辑；未实现 Pro 或订阅权益。
- 完成内容：Support 页面价格继续使用 StoreKit `Product.displayPrice`，但会在 storefront 变化和 App 回前台时重新请求 `Product.products(for:)`，让 UI 价格更及时地跟随当前 App Store 商店区域。
- 未完成内容：未在 TestFlight 沙盒账号中实测切换商店区域后的刷新表现；App Store / StoreKit 侧仍可能有短时间缓存，必要时需要重新打开页面或重启 App。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：购买弹窗始终以 App Store 当前结算 storefront 为准；页面展示依赖 `Product.displayPrice` 的返回值，如果 Apple 沙盒缓存未及时刷新，可能需要重新进入页面或重启 TestFlight App。
- 回滚方式：回退 `SupportPurchaseManager.swift` 的 storefront listener 和 `SupportAutoLedgerView.swift` 的 scenePhase 刷新逻辑，并回退本条文档记录。
- 结论：本轮完成，代码已避免 Support 页面长期持有旧币种 `Product` 价格。
- 下一步建议：重新发一个 TestFlight 构建后，用中国区沙盒账号验证页面价格和购买弹窗是否同为人民币。

### ITER-087 v1.4.x Release Notes 更新
- 日期：2026-05-28
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：文档 / Release Notes
- 目标：更新 v1.4.0 / v1.4.x Release Notes 草稿，使其反映当前 Watch 语音入口、Support Developer IAP、设置页版本状态文案、本地化 key 数、验证结果和 TestFlight 测试重点。
- 改动范围：
  - `versions/v1.4.0-RELEASE(draft).md`：更新日期、迭代范围、发布状态、已实现功能、Support IAP 说明、本地化 key 数、回归验证、TestFlight RN 建议文案、测试重点、已知限制和发布结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未修改 App 代码；未修改版本号、App Store Connect 元数据或 `.storekit` 配置；未新增真机截图或上传 TestFlight 构建。
- 完成内容：RN 已补入 Watch 语音记账离线优先入口，说明系统听写完成后自动解析并进入确认保存；补入 Support AutoLedger 可选支持入口，明确 consumable IAP 不解锁功能、不改变免费边界，真实沙盒购买需 App Store Connect 创建产品后点验；本地化 key 数更新为主 App 495、Watch App 43；测试重点新增 Watch 离线暂存和 Support IAP 本地 / 沙盒购买点验。
- 未完成内容：未做 Markdown 渲染截图；未做真机多语言 / Watch / IAP 沙盒人工验证；未提交或推送。
- 测试情况：
  - PASS：`ruby -e 'ARGV.each do |dir|; files=Dir[File.join(dir,"*.lproj/Localizable.strings")]; puts dir; files.sort.each do |f|; keys=File.readlines(f).grep(/^\s*"/).map{|l| l[/^\s*"([^"]+)"/,1]}.compact; puts "  #{File.basename(File.dirname(f))}: #{keys.uniq.size}"; end; end' 'AutoLedger/AutoLedger' 'AutoLedger/AutoLedgerWatch Watch App' 'AutoLedger/ControlWidgetExtension' 'AutoLedger/ShareExtension'`
- 风险与注意事项：RN 仍是草稿，TestFlight 对外文案需要在真实 App Store Connect IAP 配置和 Watch 真机点验后再最终冻结。
- 回滚方式：回退 `versions/v1.4.0-RELEASE(draft).md`、`CHANGELOG.md` 和本条迭代日志。
- 结论：本轮完成，v1.4.x RN 已同步到当前实现与待验证状态。
- 下一步建议：在真机 Apple Watch、TestFlight 沙盒账号和 App Store Connect IAP 配置完成后，再把 RN 从草稿调整为发布候选。

### ITER-086 Watch 语音记账离线优先入口
- 日期：2026-05-28
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：能力增强 / Watch UI / 本地化
- 目标：在 Apple Watch 端保持离线可用优先的前提下，把语音记账入口从点击 TextField 触发系统输入，调整为更明确的“语音输入”按钮，并在听写完成后进入既有确认保存链路。
- 改动范围：
  - `AutoLedger/AutoLedgerWatch Watch App/WatchVoiceRecorderView.swift`：引入 WatchKit `presentTextInputController`，新增语音输入按钮、输入中状态、系统文本输入不可用错误提示；听写返回文本后自动调用 `VoiceLedgerParser` 解析，成功后进入 `WatchVoiceConfirmView`，失败时保留识别文本供用户修改后重新解析。
  - `AutoLedger/AutoLedgerWatch Watch App/zh-Hans.lproj/Localizable.strings`、`zh-Hant.lproj/Localizable.strings`、`en.lproj/Localizable.strings`：更新 Watch 语音入口说明，新增按钮、辅助功能、错误与建议短句三语文案。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未把 Watch 端录音转发到 iPhone；未引入 Watch 端自研离线 ASR 模型；未改 iPhone 端 `VoiceSpeechRecognizer`；未改 Watch pending 队列、确认页保存和同步协议。
- 完成内容：Watch 语音页主路径改为“语音输入”按钮；系统听写完成后自动解析并跳转确认；文本输入仍保留为识别失败或用户修正的兜底；文案明确未连接 iPhone 时会先暂存，符合离线优先产品口径。
- 未完成内容：未在真实 Apple Watch 上点验系统听写弹层和离线听写可用性；系统听写是否完全离线取决于 watchOS / 语言包 / 设备状态，App 不再额外依赖 iPhone 识别。
- 测试情况：
  - PASS：`plutil -lint 'AutoLedger/AutoLedgerWatch Watch App/zh-Hans.lproj/Localizable.strings' 'AutoLedger/AutoLedgerWatch Watch App/zh-Hant.lproj/Localizable.strings' 'AutoLedger/AutoLedgerWatch Watch App/en.lproj/Localizable.strings'`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -destination 'generic/platform=watchOS' build`
- 风险与注意事项：`presentTextInputController` 是系统输入界面而不是 App 自己录音识别；如果真机上系统听写入口受语言包或网络影响，需要保留手动文本输入和快速记账作为兜底。
- 回滚方式：回退 `WatchVoiceRecorderView.swift` 中 WatchKit 文本输入按钮逻辑和三套 Watch `Localizable.strings` 新增 key，并回退本轮文档记录。
- 结论：本轮完成，Watch 语音记账入口已更贴近“点语音输入 -> 听写 -> 确认保存”的用户心智，同时不牺牲未连接 iPhone 时的本地暂存能力。
- 下一步建议：用真机 Apple Watch 分别在连接 iPhone / 未连接 iPhone 场景下验证系统听写、解析跳转和 pending 同步反馈。

### ITER-085 Support Developer 消耗型内购首版
- 日期：2026-05-27
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：能力增强 / StoreKit / 文档
- 目标：为 AutoLedger 增加第一版“支持独立开发者”消耗型 IAP，走通 StoreKit 2、App Store Connect 和 TestFlight IAP 测试链路，但不做订阅、不做 Pro 解锁、不回收任何现有免费功能。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/SupportPurchaseManager.swift`：新增 StoreKit 2 支持服务，拉取 3 个 consumable 产品、发起购买、处理 verified / unverified / pending / userCancelled / unknown，并监听 `StoreKit.Transaction.updates`。
  - `AutoLedger/AutoLedger/Features/Settings/SupportAutoLedgerView.swift`：新增支持页面，展示说明、3 个支持档位、本地化价格、购买中状态、错误重试、感谢状态和本地支持记录。
  - `AutoLedger/AutoLedger/Features/Settings/SettingsView.swift`、`AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：设置页接入“支持 AutoLedger”入口；App 启动时启动 transaction updates 监听。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：补齐支持页面、购买状态和错误提示三语文案。
  - `AutoLedger/AutoLedgerSupport.storekit`、`AutoLedger.xcscheme`、`AutoLedger.xcodeproj/project.pbxproj`：新增本地 StoreKit 配置并挂到 Run scheme，3 个产品均覆盖英文、简体中文、繁体中文展示名 / 说明。
  - `docs/iap-support.md`：新增本地测试、App Store Connect 配置、三语内购说明和 Review Notes 文档。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未实现订阅；未实现 Pro entitlement；未增加 restore entitlement；未改变记账、OCR、JSON 导出、iCloud、Watch、快捷指令、商户别名、分类和月报等现有免费功能边界；未引导外部支付。
- 完成内容：3 个产品 ID 已统一为 `top.darkrio326.AutoLedger.support.coffee/lunch/sponsor`；verified support transaction 会记录本地支持次数、最近产品和最近时间并调用 `finish()`；unverified transaction 不记录支持状态；pending 会给出明确提示；取消购买不会显示成功；已处理 transaction id 会保留最近 50 条避免重复计数；UI 使用现有设置页卡片风格并支持 Dynamic Type / VoiceOver 的基础可读性。
- 未完成内容：未在真实 App Store Connect / TestFlight 沙盒账号中点验；未在交互式 Xcode StoreKit 购买弹窗中完成本地购买；`.storekit` 配置需在 Xcode Scheme Editor 中人工确认是否被当前 Xcode 版本正确识别；3 个 IAP 仍需在 App Store Connect 手动创建并随新版本提交审核。
- 测试情况：
  - PASS：`find AutoLedger/AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`ruby -rjson -e 'JSON.parse(File.read("AutoLedger/AutoLedgerSupport.storekit"))'`
  - PASS：`ruby -rrexml/document -e 'REXML::Document.new(File.read("AutoLedger/AutoLedger.xcodeproj/xcshareddata/xcschemes/AutoLedger.xcscheme"))'`
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
- 风险与注意事项：本轮是 consumable support，不提供权益恢复；如果未来扩展到一次性 Pro 或订阅，需要新增 entitlement 模型和 restore/sync 逻辑，不能复用当前“只记录支持次数”的语义。
- 回滚方式：删除 `SupportPurchaseManager.swift`、`SupportAutoLedgerView.swift`、`AutoLedgerSupport.storekit` 和 `docs/iap-support.md`，回退设置页入口、App 启动监听、scheme/project 配置、本地化 key、CHANGELOG 与迭代日志。
- 结论：本轮完成，AutoLedger 已具备第一版 Support Developer consumable IAP 代码链路、本地 StoreKit 配置和 App Store Connect 配置文档；真实 IAP 购买仍需在 Xcode StoreKit / TestFlight 沙盒中人工点验。
- 下一步建议：完成本地 StoreKit 购买点验后，在 App Store Connect 创建 3 个 consumable IAP，并随下一版 App 一起提交审核。

### ITER-084 设置页版本状态文案更新
- 日期：2026-05-27
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：文案 / 本地化 / 治理
- 目标：让设置页“当前版本”与 App Store v1.3.0 发布候选状态一致，并让“后续计划”保持用户可读的产品路线表达，同时保持版本号继续同步工程/App Store 版本。
- 改动范围：
  - `AutoLedger/AutoLedger/zh-Hans.lproj/Localizable.strings`：更新 `settings.version.body` 与 `settings.release_status.body`。
  - `AutoLedger/AutoLedger/zh-Hant.lproj/Localizable.strings`：更新同两条繁体中文文案。
  - `AutoLedger/AutoLedger/en.lproj/Localizable.strings`：更新同两条英文文案。
  - `CHANGELOG.md`、`process/iteration-log.md`：补充本轮追溯记录。
- 未改动范围：未改 `SettingsView` 版本号渲染逻辑；未改 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`；未改 Watch、解析器、SQLite、App Intents 或截图导出逻辑。
- 完成内容：当前版本正文已覆盖 Apple Watch 轻量记账、快捷指令与语音记账、月报历史月份、iCloud 备份恢复、商户别名与分类批量整理；后续计划改为面向用户的产品路线表达，包含更多支付场景识别优化、更多专业版功能和更灵活的账单整理能力；版本号仍由 `Bundle.main.infoDictionary["CFBundleShortVersionString"]` 读取。
- 未完成内容：未做真机设置页截图点验；本轮只做本地化资源与静态校验。
- 测试情况：
  - PASS：`find AutoLedger/AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：文案为用户可见产品路线口径，若专业版功能范围或后续支付场景支持范围调整，需要同步更新这两条 key。
- 回滚方式：回退三套 `Localizable.strings` 中 `settings.version.body` / `settings.release_status.body` 以及本轮文档记录。
- 结论：本轮完成，设置页版本状态文案已同步到当前发布候选能力与用户可见产品路线口径，版本号仍保持工程配置读取。
- 下一步建议：在真机或截图脚本中确认设置页长文案不溢出。

### ITER-083 Watch 记账 UI 与同步修复
- 日期：2026-05-27
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / UI / 同步
- 目标：修复 Apple Watch 端数据不同步、快速记账和语音入口布局偏移、分类选择对勾撑高 UI、金额输入弹出文本输入、截图资产与实际 Watch UI 不一致，以及 Watch 分类缺少用户自定义分类的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/WatchConnectivityHost.swift`：最近账单同步 payload 扩展为 `transactions + customCategories`，通过 `updateApplicationContext` 保留离线可取状态，并在 Watch 可达时继续 `sendMessage` 即时推送；Watch 保存入账时使用 `Transaction(categoryLabel:sourceLabel:)`，保留自定义分类字符串。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`、`AutoLedger/AutoLedger/App/AutoLedgerApp.swift`：自定义分类保存、账单新增/更新/导入触发 Widget 刷新时，通过 App 注入的 Watch 同步 handler 刷新 Watch payload，避免 `LedgerStore` 在离线回归编译中直接依赖 WatchConnectivity。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchSessionManager.swift`、`WatchLedgerViewModel.swift`、`ContentView.swift`：Watch session 收到最近账单和自定义分类后通知 ViewModel；激活/可达变化和首屏空数据时自动请求最近账单并重试 pending；iPhone 不可达时通过 `transferUserInfo` 排队后台拉取请求。
  - `AutoLedger/AutoLedgerWatch Watch App/QuickAddView.swift`、`WatchCategoryGrid.swift`、`WatchCategoryOption.swift`：快速记账改为金额优先，金额点击打开自定义数字面板，不再弹系统文本输入；分类网格固定高度、移除对勾，用边框/底色表达选中，并合并内置分类和用户自定义分类。
  - `AutoLedger/AutoLedgerWatch Watch App/WatchVoiceConfirmView.swift`、`WatchVoiceRecorderView.swift`：语音确认分类复用同一固定网格并支持自定义分类；语音录入页改为可滚动紧凑布局，减少顶部标题/图标挤压。
  - `AutoLedger/AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`：Watch 快速记账截图改为真实快速记账 UI，不再额外加大标题；截图 fixtures 覆盖自定义分类。
- 未改动范围：未改动 iPhone 主 App 记账 UI；未新增 CloudKit/后台实时同步；未改变 Watch pending 队列的持久化格式；未自动上传 App Store Connect 截图。
- 完成内容：Watch 最近账单和自定义分类可随 iPhone 账单/分类变化同步；Watch 首屏无账单或无自定义分类时会主动触发同步请求，iPhone 不可达时也会排队后台请求；Watch 自定义分类入账不再落到“其他”；快速记账和语音确认分类选择不会因对勾改变 cell 高度；金额录入避免系统文本输入；zh-Hans Watch 截图重新生成并与当前 Watch UI 对齐。
- 未完成内容：未做 Apple Watch 真机端到端同步点验；本轮以 watchOS 构建、Simulator screenshot-mode 和截图人工查看为准。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme 'AutoLedgerWatch Watch App' -destination 'generic/platform=watchOS' build`
  - PASS：`bash tools/appstore-screenshots/scripts/export_watch.sh --locale zh-Hans`
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`find 'AutoLedger/AutoLedgerWatch Watch App' -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
  - PASS：人工查看 Watch 快速记账与旧版确认页截图输出
- 风险与注意事项：快速记账页曾尝试使用 watchOS toolbar 放“确认”，但 screenshot-mode quick_add 会黑屏，已回退为页内提交按钮；最终上架前仍建议用真机 Watch 点验同步延迟与金额输入手感。
- 回滚方式：回退 WatchConnectivityHost / LedgerStore 同步改动、Watch session/view model 状态监听、Watch 快速记账/语音确认 UI 文件和新增的 WatchCategoryGrid / WatchCategoryOption。
- 结论：本轮修复了 Watch 端同步分叉、自定义分类丢失和主要 UI 偏移问题，并让 App Store Watch 截图重新来自当前真实 Watch UI。
- 下一步建议：在真机 Apple Watch + iPhone 上验证四件事：Watch 首屏空数据时是否主动拉取最近账单和自定义分类；iPhone 新增自定义分类后 Watch 是否出现；Watch 选择自定义分类入账后 iPhone 账本分类是否原样保留；断开手机后 pending 队列恢复连接是否自动清空。

### ITER-082 商户别名新入账即时生效修复
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Phase 4 / 发布准备
- 类型：Bugfix / 测试
- 目标：修复用户已在设置中配置商户别名后，新记账记录仍先保存原商户名，必须手动点单条刷新才替换为别名的问题。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/MerchantAliasResolver.swift`：新增纯 Core 别名解析工具，支持精确匹配与首尾空白容错，并提供 `ImportedReceipt` / `Transaction` 两类保存前归一化方法。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`resolveMerchant`、`persistReceipt`、`addTransaction` 统一调用别名解析工具，OCR 导入与手动新增在写入 SQLite 前就替换商户名。
  - `AutoLedger/AutoLedger/Domain/Services/AddTransactionIntent.swift`、`QuickLedgerIntent.swift`、`VoiceLedgerIntent.swift`：快捷指令手动记账、截图快捷记账、语音快捷记账均加载 SQLite 商户别名并在保存前套用。
  - `AutoLedger/ShareExtension/ShareViewController.swift`：分享扩展解析后先套用商户别名，再做重复判断、保存、调试记录与共享结果回写。
  - `scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh`：新增 OCR 新入账别名即时生效、原商户不落库、手动新增别名即时生效断言，并纳入新 Core 文件编译。
- 未改动范围：未改变设置页单条历史刷新按钮；未新增模糊匹配或全局自动重写开关；未修改商户别名学习触发条件；未改变用户手动选择的分类。
- 完成内容：所有当前直写新账单的主要入口都在入库前套用既有商户别名；用户不再需要依赖设置页“刷新”来修正之后新产生的账单。
- 未完成内容：未做真机快捷指令 / Share Extension 端到端点验；本轮以离线逻辑回归和 iOS 全构建为准。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：别名匹配仍按精确商户名为主，仅增加首尾空白容错，避免误改相似商户；历史账单仍需要用户使用既有单条刷新入口主动整理。
- 回滚方式：删除 `MerchantAliasResolver.swift`，回退 LedgerStore、三个 App Intent、Share Extension 和离线回归脚本改动。
- 结论：问题确认为保存路径绕过别名解析导致；本轮已在保存前统一别名归一化并通过门禁。
- 下一步建议：如后续发现 Watch 独立本地保存路径或新增 Extension 入口，需要继续复用 `MerchantAliasResolver`，避免再次分叉。

### ITER-081 辅助功能发布收口
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：能力增强 / 辅助功能
- 目标：继续完善 v1.4.0 主路径辅助功能，让报表、账本和 Watch 轻量记账路径更适合 VoiceOver、大字号、Reduce Motion、增强对比度和非颜色区分场景。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Report/ReportView.swift`：新增 Reduce Motion 条件动画、`accessibilityDifferentiateWithoutColor` / `colorSchemeContrast` 适配、报表摘要 / 分类图 / 趋势图 / Top 商户可读标签。
  - `AutoLedger/AutoLedger/Shared/Components/CategoryBreakdownRow.swift`：分类占比行新增选中勾选态、选中边框、本地化占比文案和 VoiceOver 标签。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`、`DeletedTransactionsView.swift`：隐藏装饰图标，补齐最近删除入口与已删除账单行的辅助功能标签。
  - `AutoLedger/AutoLedgerWatch Watch App/QuickAddView.swift`、`WatchVoiceRecorderView.swift`、`WatchVoiceConfirmView.swift`：Watch 分类网格和语音入口改用动态字体，并为选中分类增加可见勾选态。
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：新增报表辅助功能摘要、分类占比、趋势图和商户排行三语文案。
  - `versions/v1.4.0-RELEASE(draft).md`、`CHANGELOG.md`、`process/iteration-log.md`：同步辅助功能发布口径。
- 未改动范围：未新增字幕 / 口述影像能力；未修改 DebugView；未做真机 VoiceOver、大字号、Switch Control、语音控制实机点验；未改 Core 层或解析逻辑。
- 完成内容：报表图表不再只依赖视觉图形，可被 VoiceOver 读出摘要；分类筛选和 Watch 分类选择增加非颜色选中信号；Watch 小字号固定文本减少；账本和最近删除主路径减少装饰图标噪声。
- 未完成内容：仍需真机验证 VoiceOver rotor 顺序、大字号 200% 布局、语音控制可说名称、增强对比度视觉结果。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`find AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
- 风险与注意事项：本轮以主路径静态代码与编译验证为准，未替代真机辅助功能审核；报表页仍保留一个既有 `plotAreaFrame` deprecation warning，未影响构建。
- 回滚方式：回退本轮 SwiftUI 辅助功能改动、三套 `Localizable.strings` 新增键，以及 RN / CHANGELOG / iteration-log 记录。
- 结论：v1.4.0 主路径辅助功能从“VoiceOver 基础覆盖”推进到“报表可读、状态非颜色化、减动和大字号更友好”，代码门禁通过。
- 下一步建议：进入 TestFlight 前按 App Store Connect 辅助功能项逐项做真机点验，尤其是大字号 200%、语音控制、增强对比度和 Switch Control。

### ITER-080 Watch App Icon 小尺寸优化
- 日期：2026-05-26
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：视觉资产 / 发布门禁
- 目标：基于现有 AutoLedger iPhone App Icon 设计 Apple Watch 小尺寸优化版，并补齐完整 watchOS app icon set。
- 改动范围：
  - `AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset/`：重绘 Watch 专用 `AppIcon.png`，新增 notification、companion settings、app launcher、quick look 等 watchOS 尺寸图，并更新 `Contents.json`。
  - `versions/assets/watch-app-icon/`：新增 1024、128、64、48 小尺寸预览图。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮视觉资产与验证结果。
- 未改动范围：未改动 iPhone 主 App 图标；未改动 Widget / Share Extension 图标；未改动 Watch UI 代码、Bundle ID、签名配置或 App Store 元数据。
- 完成内容：Watch 图标保留白色钱包、金币、闪电、蓝绿渐变背景；去除星星、小圆点和复杂装饰；简化钱包高光、阴影与内部细节；加粗闪电主视觉以提升 48px 下识别度；金币保留为半露辅助元素并使用简化 `￥`。
- 未完成内容：未做真机 Apple Watch 安装后的主屏图标截图确认；本轮以资产编译和 iOS archive 构建为验证口径。
- 测试情况：
  - PASS：`xcrun actool --compile /tmp/AutoLedgerWatchIconCheck --platform watchos --minimum-deployment-target 26.0 --app-icon AppIcon --output-partial-info-plist /tmp/AutoLedgerWatchIconCheck/Info.plist 'AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets'`
  - PASS：`assetutil --info /tmp/AutoLedgerWatchIconCheck/Assets.car` 可见 40/44/50 launcher、86/98/108 quick look、notification、settings 与 1024 marketing 图标。
- 风险与注意事项：watchOS 真机图标仍可能受设备缓存影响，若本机仍显示旧图标需删除 App / Watch companion 后重新安装；最终发布前建议补一次真机截图。
- 回滚方式：回退 `AppIcon.appiconset` 与 `versions/assets/watch-app-icon/`，恢复上一版单张 1024 Watch 图标。
- 结论：Watch App 图标资产已从“复用 iPhone 复杂图”升级为小尺寸优化版，watchOS icon set 编译通过。
- 下一步建议：重新安装到 Apple Watch 真机，确认主屏、通知、Watch App 列表中的图标刷新。

### ITER-079 UI 文案全球化收口
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：能力增强 / 本地化 / 文档
- 目标：补齐 v1.4.x 用户可见主路径的简体中文、繁体中文、英文 UI 文案资源，并更新 RN 中的本地化结论。
- 改动范围：
  - `AutoLedger/AutoLedger/*.lproj/Localizable.strings`：扩展主 App 本地化键至 457 个，覆盖账本筛选、最近删除、月报、分类刷新、商户别名、消费分析、数据管理、订阅管理、问题反馈、反馈邮件预览、OCR / iCloud 用户错误、App Intents 参数摘要等主路径。
  - `AutoLedger/AutoLedger/Features/*` 与 `AutoLedger/AutoLedger/Domain/Services/*Intent.swift`：将新增用户可见文案迁移到本地化 key。
  - `AutoLedger/AutoLedgerWatch Watch App/*.lproj/Localizable.strings`：新增 Watch App 简体中文、繁体中文、英文三套资源。
  - `AutoLedger/AutoLedgerWatch Watch App/*.swift`：将 Watch 首页、快速记账、语音记账、确认页、同步反馈等文案迁移到本地化 key。
  - `versions/v1.4.0-RELEASE(draft).md`、`CHANGELOG.md`、`process/iteration-log.md`：更新本地化状态与验证结论。
- 未改动范围：未本地化 DebugView、调试记录导出文本、日志、解析规则关键词、LLM prompt、OCR 识别标签；未新增真机多语言截图和 App Store 审核材料。
- 完成内容：主 App、Watch App、ControlWidgetExtension、ShareExtension 的 zh-Hans / zh-Hant / en `Localizable.strings` key 集合已对齐；用户可见主路径三语文案补齐；v1.4.0 RN 本地化结论已从“UI 文案未齐全”更新为“主路径已补齐，Debug/开发者工具保留中文”。
- 未完成内容：DebugView 和调试导出记录仍以中文为主；未做真机语言切换、Watch 真机、大字号、VoiceOver 截图验收。
- 测试情况：
  - PASS：`find AutoLedger -path '*lproj/Localizable.strings' -print0 | xargs -0 plutil -lint`
  - PASS：`git diff --check`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
- 风险与注意事项：UI 全球化范围按用户可见主路径收口，不把调试/开发者导出文本纳入本轮；部分日期和金额展示仍依赖系统 Locale，需要真机多语言环境点验。
- 回滚方式：回退本轮 Swift 文案迁移、三套 `Localizable.strings` 新增键、Watch `.lproj` 资源，以及 RN / CHANGELOG / iteration-log 更新。
- 结论：主路径 UI 文案全球化完成，代码门禁通过。
- 下一步建议：进入 TestFlight 前补一轮真机语言切换截图验收，并单独决定是否把 DebugView 做成开发者模式本地化。

### ITER-078 v1.4.0 / v1.4.x RN 草稿与本地化状态核查
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Release Notes / 发布准备
- 类型：文档 / 发布门禁 / 本地化核查
- 目标：汇总 v1.4.x 当前已实现功能，判断简体中文、繁体中文、英文三套本地化是否齐全，并产出可用于 TestFlight / 发布评审的 RN 草稿。
- 改动范围：
  - `versions/v1.4.0-RELEASE(draft).md`：新增 RN 草稿，覆盖功能清单、测试重点、已知限制、本地化结论与 TestFlight 文案。
  - `CHANGELOG.md`：新增 ITER-078 条目。
  - `process/iteration-log.md`：记录本轮文档与本地化核查结果。
- 未改动范围：未修改代码；未补齐本地化资源；未新增 Watch 截图、App Store Review Notes 或真机验证材料。
- 完成内容：确认 v1.4.x 已实现 Watch 伴侣 App、Watch/iPhone 辅助功能主路径、App Intents 三件套、月报历史月份、微信拼多多解析修复、分类/商户别名批量刷新；确认主 App / Widget / ShareExtension 的 `.strings` key 在 zh-Hans、zh-Hant、en 三套资源中对齐。
- 未完成内容：Watch App 尚无独立三语 `.lproj` 资源；v1.4.x 新增 Watch UI、分类刷新弹窗、商户别名刷新入口、月报及部分旧页面仍有硬编码中文，不能声明三语 UI 本地化齐全。
- 测试情况：
  - 本轮为文档整理与静态核查，未重新运行构建。
  - 最近一轮已通过：`bash scripts/run_golden_regression.sh`、`bash scripts/run_offline_regression.sh`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`git diff --check`。
- 风险与注意事项：RN 对外发布时需避免混淆“v1.4.x 内部开发线”和“App Store 对外 v1.3.0”；本地化只能写成 key 对齐，不能写成三语完整体验已完成。
- 回滚方式：删除 `versions/v1.4.0-RELEASE(draft).md`，回退本轮 CHANGELOG 与 iteration-log 条目。
- 结论：RN 草稿完成；本地化结论为“key 对齐，UI 文案未齐全”。
- 下一步建议：补齐 Watch App 与 v1.4.x 新增 UI 的 zh-Hans / zh-Hant / en 本地化资源后，再更新 RN 的发布结论并做真机辅助功能点验。

### ITER-077 分类/商户别名批量刷新交互
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：能力增强 / Bugfix / 测试
- 目标：用户修改单笔账单分类时可选择是否刷新同商户历史账单分类；商户别名设置页支持对单条别名手动刷新历史账单商户名。
- 改动范围：
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`updateTransaction` 新增 `refreshSameMerchantCategory` 参数；新增同商户分类批量更新、单条商户别名刷新方法，并继续写回 SQLite、刷新 Widget、触发自动备份。
  - `AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift`：编辑模式下检测分类变更，保存前弹出"仅保存本笔 / 刷新全部"确认。
  - `AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift`：编辑账单保存时把批量刷新选择传给 `LedgerStore`；新增账单不触发该确认。
  - `AutoLedger/AutoLedger/Features/Settings/MerchantAliasView.swift`：每条商户别名增加刷新按钮，按单条映射更新历史账单商户名。
  - `scripts/OfflineRegression.swift`：新增同商户分类批量刷新和单条商户别名刷新断言。
- 未改动范围：未新增全局设置开关；未改变商户别名自动学习规则；未改变 OCR/LLM 解析流程。
- 完成内容：分类变更可由用户确认是否批量套用；商户别名可在设置页逐条刷新已有账单；批量更新均持久化到 SQLite。
- 未完成内容：未做真机 UI 点按回归；本轮以编译和离线逻辑回归为准。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`（32 case）
  - PASS：`bash scripts/run_offline_regression.sh`（新增同商户分类刷新和单条别名刷新断言通过）
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：批量刷新按最终商户名精确匹配，不做模糊匹配，避免误改相似商户。
- 回滚方式：回退本轮 `LedgerStore.swift`、`TransactionEditorView.swift`、`LedgerView.swift`、`MerchantAliasView.swift` 和离线回归新增断言。
- 结论：本轮完成，代码门禁通过。
- 下一步建议：后续可在设置页增加"分类学习"逐条刷新入口，但本轮先以编辑时确认覆盖主路径。

### ITER-076 微信拼多多先用后付详情页解析修复
- 日期：2026-05-25
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：Bugfix / 测试
- 目标：处理 2026-05-25 导出的单条微信支付调试记录，修复商户被解析为 `• 交易详情` 的问题。
- 改动范围：
  - `AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift`：微信详情页缺少 `商户全称` 时，改为在负数金额上方附近扫描展示商户，并过滤 `交易详情`、`服务`、`小程序`、喜欢数、平台 slogan 等 UI 噪声。
  - `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Enums/TransactionCategory.swift`：将 `拼多多` 纳入购物分类关键词；补齐既有 `羊汤/羊肉汤` 餐饮关键词残留。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 `wechat_pinduoduo_pay_later_detail`，覆盖金额 69.90、商户 `拼多多`、分类 `shopping`、来源 `wechat`。
  - `scripts/run_golden_regression.sh`：修复当前仓库布局下 Golden 脚本仍引用不存在 Core 版 `ReceiptParser.swift` 的问题，改为临时使用 App 版解析器。
- 未改动范围：未调整 LLM / SmartReceiptParser 流程；未改动 QuickLedgerIntent、调试记录 UI、SQLite 入账和商户别名学习逻辑；未处理既有 `AutoLedger.xcodeproj` 未提交显示名改动。
- 完成内容：该调试记录现在可按纯规则解析为 `拼多多 · ¥69.90 · 购物 · 2026-05-25 10:52:44`，不再生成 `• 交易详情` 商户；离线回归中既有"羊汤"分类残差同步修复。
- 未完成内容：未做真实快捷指令端到端截图导入；本轮只覆盖文本回归。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`（32 case，通过新增 `wechat_pinduoduo_pay_later_detail`）
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：该修复通过近邻候选过滤识别顶部展示商户；若后续支付页顶部只有平台 slogan 而无商户名，会继续回退到 `商品` 字段。
- 回滚方式：回退本轮 `ReceiptParser.swift`、`TransactionCategory.swift`、Golden case 和脚本改动。
- 结论：本轮完成，代码门禁通过。
- 下一步建议：将相似"先用后付/先享后付"详情页继续沉淀为 Golden Case。

### ITER-075 Report 月报历史月份浏览
- 日期：2026-05-20
- 所属版本：v1.4.0
- 所属阶段：Phase 4
- 类型：能力增强 / UX
- 目标：月报 Tab 支持翻页查看历史月份，6 个月趋势图正确显示历史数据。
- 改动范围：
  - `AutoLedger/AutoLedger/Features/Report/ReportView.swift`：新增 `@State private var selectedMonth: Date = .now`；新增 `isCurrentMonth`、`stepMonth(by:)` 辅助方法；`store.monthlySnapshot` 改为 `MonthlySnapshot.build(from: store.transactions, referenceDate: selectedMonth)` 动态计算；`anomalyAlerts` 仅在 `isCurrentMonth` 时触发；NavigationBar 新增左右翻页箭头（`chevron.left` / `chevron.right`）；当月时右箭头 disabled；趋势图底部文案改为 `snapshot.monthLabel`；分类为空时提示文案更新。
- 未改动范围：未改动 `MonthlySnapshot.swift`（已原生支持任意 referenceDate）；未改动 `LedgerStore.monthlySnapshot`（保留供其他调用方使用）；未改动 Core 层。
- 完成内容：月份翻页 UI 实现；历史月份分类占比、TOP5 商户、6 个月趋势全部正确展示；切换月份自动清空分类选中状态；带动画翻页。
- 未完成内容：无。
- 测试情况：
  - PASS：`xcodebuild ... build`（无编译错误）
  - PASS：`bash scripts/run_offline_regression.sh`（28/29，唯一失败为预存"羊汤"分类残差）
- 风险与注意事项：异常提醒（AnomalyAlert）基于"当前月 vs 近 3 个月均值"，查看历史月时隐藏，避免误导。
- 回滚方式：还原 `ReportView.swift` 的 `body` 与 `stepMonth` 相关改动。
- 结论：代码门禁通过，月报历史浏览功能上线。

### ITER-073~074 Watch VoiceOver + App Intents 三件套
- 日期：2026-05-20
- 所属版本：v1.4.0
- 所属阶段：Phase 3–4
- 类型：能力增强 / 辅助功能 / App Intents
- 目标：
  - ITER-073：为 Watch app 四个视图补全 VoiceOver 标注，与 iPhone 端无障碍策略对齐。
  - ITER-074：新增 `AddTransactionIntent`、`ParseLedgerTextIntent`、`OpenQuickAddIntent` 三个 App Intent，注册到 `AutoLedgerShortcuts`，补充中英文本地化。
- 改动范围：
  - `AutoLedgerWatch Watch App/ContentView.swift`：交易行 `.accessibilityElement(children: .combine)` + 合并标签；toast 动画 Reduce Motion 降级。
  - `AutoLedgerWatch Watch App/QuickAddView.swift`：分类按钮 icon 隐藏 + 按钮级别 accessibilityLabel/addTraits；TextField accessibilityLabel。
  - `AutoLedgerWatch Watch App/WatchVoiceRecorderView.swift`：mic icon 隐藏；TextField 标签+提示；解析按钮标签。
  - `AutoLedgerWatch Watch App/WatchVoiceConfirmView.swift`：金额+商户组合标签；分类按钮无障碍；保存按钮标签+提示。
  - `AutoLedger/Domain/Services/AddTransactionIntent.swift`（新增）：`CategoryAppEnum: AppEnum`；`AddTransactionIntent: AppIntent`；直写 SQLite，刷新 Widget。
  - `AutoLedger/Domain/Services/ParseLedgerTextIntent.swift`（新增）：`ParseLedgerTextIntent: AppIntent`；调用 `VoiceLedgerParser`；返回结构化摘要。
  - `AutoLedger/Domain/Services/OpenQuickAddIntent.swift`（新增）：`OpenQuickAddIntent: AppIntent`；通过 `QuickLedgerNavigationState` + NotificationCenter 打开快速记账页。
  - `AutoLedger/Domain/Services/QuickLedgerIntent.swift`：`AutoLedgerShortcuts.appShortcuts` 新增三个 Shortcut 条目。
  - `AutoLedger/zh-Hans.lproj/Localizable.strings` + `en.lproj/Localizable.strings`：三个 Intent 的本地化键。
- 未改动范围：未修改现有 `VoiceLedgerIntent`；未修改 iPhone 端 VoiceOver（已在 ITER-072 完成）；未修改 Core 层。
- 完成内容：全部 8 个改动文件（含 3 个新增）完成；三个 Intent 已注册快捷指令短语；中英文本地化齐全。
- 未完成内容：无。
- 测试情况：
  - PASS：`xcodebuild ... build`（无编译错误）
  - PASS：`bash scripts/run_offline_regression.sh`（28/29，唯一失败为预存"羊汤"分类残差）
- 风险与注意事项：`CategoryAppEnum` rawValue 须与 `TransactionCategory` rawValue 严格一一对应；`VoiceLedgerConfidence` 为顶层枚举（非嵌套），`ParseLedgerTextIntent` 中已正确引用。
- 回滚方式：删除三个新 Intent 文件；回滚 `QuickLedgerIntent.swift` 的 Shortcut 新增段；回滚 Localizable.strings 新增段。
- 结论：代码门禁通过，Watch VoiceOver + App Intents 三件套全部上线。
- 下一步建议：TestFlight 验证 Shortcuts 可触发；推进 ITER-075 App Store 截图与 ITER-076 发布门禁。

### ITER-066~072 v1.4.0 Watch Support + iPhone VoiceOver
- 日期：2026-05-19
- 所属版本：v1.4.0
- 所属阶段：Phase 1–2
- 类型：能力增强 / 辅助功能
- 目标：实现 Apple Watch 伴侣应用骨架（快速记账 + 语音记账），iPhone↔Watch 双向同步，以及 iPhone 端 VoiceOver / Reduce Motion 无障碍支持。
- 改动范围：
  - Watch App 骨架：`AutoLedgerWatch Watch App/`（ContentView、QuickAddView、WatchVoiceRecorderView、WatchVoiceConfirmView、WatchLedgerViewModel、WatchSessionManager、AutoLedgerWatchApp）。
  - iPhone 端：`WatchConnectivityHost.swift`（新增）；`AutoLedgerApp.swift`（注入 host）；`LedgerStore.swift`（`handleWatchQuickAdd` 从 Watch 消息创建 Transaction）。
  - iPhone VoiceOver：`LedgerView.swift`（交易行合并标签 + 分类 badge 隐藏）；`InboxView.swift`（识别结果行标签）；`MetricCard.swift`（数值+趋势合并标签）；Reduce Motion：`InboxView.swift` 动画降级。
- 未改动范围：未修改 Core 解析层；未修改 Watch Complications；未修改 App Store 资产。
- 完成内容：Watch target 可独立编译；iPhone↔Watch WatchConnectivity 握手与消息转发；iPhone VoiceOver / Reduce Motion 全量覆盖。
- 测试情况：PASS（构建 + 离线回归 28/29）。
- 结论：v1.4.0 基础 Watch 支持已落地，代码门禁通过。

### ITER-065 商户别名迁移至 SQLite + 自动学习对齐分类学习逻辑
- 日期：2026-05-12
- 所属版本：v1.3.5
- 所属阶段：Phase 6
- 类型：能力增强 / 重构
- 目标：将商户别名持久化从 UserDefaults 迁移至 SQLite，并把自动学习条件与分类学习完全对齐，消除两套学习机制的行为不一致。
- 改动范围：
  - `AutoLedger/AutoLedgerCore/.../SQLiteTransactionStore.swift`：新增 `merchant_aliases` 表；新增 `loadMerchantAliases() / saveMerchantAlias(original:alias:) / deleteMerchantAlias(original:)` 方法；`replaceForRestore` 新增 `merchantAliases` 参数，在事务内原子写入。
  - `AutoLedger/AutoLedger/App/LedgerStore.swift`：`merchantAliases` 改为 `@Published private(set)`；初始化改为调用 `loadInitialMerchantAliases`（含 UserDefaults→SQLite 首次迁移）；新增 `recordMerchantAlias(original:alias:)`；`setMerchantAlias` / `deleteMerchantAliases` 补充 SQLite 写入；`learnMerchantAliasIfNeeded` 移除"必须更短"与"高置信度"两项限制；`refreshFromStore` 从 SQLite 重载别名；`applyBackupBundle` 传入 `merchantAliases` 参数。
  - `scripts/OfflineRegression.swift`：改用 `setMerchantAlias(original:alias:)` 替代直接赋值，移除多余的 `saveMerchantAliases()` 调用。
- 未改动范围：未修改 UI；未修改 `saveMerchantAliases()`（保留 UserDefaults 兼容）；未修改 OCR / LLM 流程。
- 完成内容：SQLite 表与 3 个 CRUD 方法；LedgerStore 全链路对齐；备份/还原原子性；UserDefaults→SQLite 升级迁移路径。
- 未完成内容：无。
- 测试情况：`bash scripts/run_offline_regression.sh` 28 条 PASS（"羊汤"分类残差为预存在问题，与本次改动无关）。
- 风险与注意事项：`isHighConfidenceGeneratedTransaction` 方法可能已无调用方，下一轮可酌情清理。
- 回滚方式：`git revert` 三个改动文件；UserDefaults 旧数据保留，可无损回退。
- 结论：代码门禁通过，商户别名学习行为与分类学习完全对齐。
- 下一步建议：持续观察自动学习质量；可在设置页展示已学习别名条数。

### ITER-059~064 v1.3.5 Worker API 评估 + 核心引擎批量验证
- 日期：2026-04-29
- 所属版本：v1.3.5
- 所属阶段：Phase 0-5
- 类型：能力增强 / 测试 / 工具 / 基础设施评估
- 目标：评估将 `LedgerTextInterpreterCore` 部署到云端运行时的可行性；在 receiptsample 全量样本上建立 core 引擎的真实基线并修复残余失败模式。
- 改动范围：
  - Track A（Worker API 评估）：
    - `AutoLedgerCoreKit/Package.swift` + `Sources/AutoLedgerCoreKit/*.swift`（7 文件）：提取纯 Foundation SwiftPM 包，独立于 Xcode 工程编译。
    - `tools/worker/EVALUATION.md`：评估 Cloudflare Workers (swiftwasm)、Vapor + Linux Docker、SwiftPM CLI、JS port 四个候选运行时；结论 CONDITIONAL GO。
    - 性能基准：712 条 receiptsample 在 7.5s 内解析完成（~105 req/s, ~9.5ms p50）。
  - Track B（核心引擎批量验证）：
    - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：多重修复——extractRMAmounts 新增产品代码 RM20202 排除（无小数 4+ 位数字跳过）、下划线 RM_34.80 支持、TOTAL 关键词附近距离优先策略；`extractFromTotalNextLine` 新增商品代码行/数量行/标识符行/日期行跳过，防止 SubTotal 后商品代码行 061558 被误作金额；`extractLastExplicitAmount` 新增 CHANGE/CASH 行排除、GST/TAX 行排除、商品代码行排除、0.5~10000 金额范围约束；`lineLooksLikeShortCode` 新增短代码 `^[A-Za-z0-9]{2,8}$` 排除、"19." 类型；`lineLooksLikeProductCode` 新增 `^[A-Z][A-Za-z0-9]{1,5}:\d+[A-Za-z]?$` 排除；`lineLooksLikeItemCodeLine` 扩展匹配；`lineLooksLikeRegistrationNumber` 改为整行精确匹配（非包含匹配），修复商户名含注册号后缀误排除；新增 `lineLooksLikeChangeOrCashLine`、`lineLooksLikeGstOrTaxLine`、`lineLooksLikeRoundingLine`、`lineLooksLikeItemCodeLine` 分类器；分类映射从 7 组扩增到 28 组（新增 MR. D.I.Y.、PERNIAGAAN ZHENG HUI、SOON HUAT、INDAH GIFT、TED HENG、FY EAGLE、MYNEWS、PASAR、TESCO、AEON、LOTUS'S、KFC、BURGER KING、PIZZA HUT、STARBUCKS、SUBWAY、GRAB、GOJEK、NETFLIX、SPOTIFY、APPLE ONE、ICLOUD、GOOGLE ONE、CHATGPT 等）。
    - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 5 条 Golden Case，总数 31→36 条。
  - `.tmp/receipt_ocr/scanned_receipts.v{1..5}.report.md`：5 轮迭代批量报告（v1 基线→v5 最终）。
- 未改动范围：未上线生产 Worker API；未修改 App 用户可见主流程；未修改 SQLite schema；未开始 Apple Watch target。
- 完成内容：
  - Track A：CoreKit 独立编译通过；Worker 评估报告完成；性能基准完成。结论 CONDITIONAL GO。
  - Track B：712 样本金额命中率 100%、商户非空率 100%、高置信率 100%。分类非 other 从 14→96（6.6x）。P0 级注册号误作金额、页眉/页脚商户、商品代码金额全部修复。剩余 5 条 <0.5 的微小残差（部分 OCR 截断样本的 GST 值）。
- 未完成内容：swiftwasm NSRegularExpression 兼容性待工具链成熟后重试；全量批量报告中的 5 条 <0.5 残差涉及支付平台特定版式，需后续针对性扩充。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_golden_regression.sh`（36 条）
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
  - PASS：`cd AutoLedgerCoreKit && swift build`（独立包编译）
- 风险与注意事项：批量报告中 5 条 <0.5 残差来自部分 OCR 截断的真实样本，不影响实际使用（完整 OCR 下 TOTAL 行可正确提取）。其余 707 条金额提取全部正确。
- 回滚方式：Track A 的 AutoLedgerCoreKit/ 和 tools/worker/ 为新增目录，不影响 App；Track B 修改集中在 `LedgerTextInterpreterCore.swift`，可通过 git revert 恢复 v1.3.4 行为；Golden Case 新增可按文件独立回滚。
- 结论：v1.3.5 Track A + B 全部完成，代码门禁通过。
- 下一步建议：根据 EVALUATION.md 结论，当前继续使用 SwiftPM CLI 本地批量工具；待 swiftwasm Foundation 完善后重新评估 Worker 部署；推进 v1.4 Apple Watch 端实现。

### ITER-052~058 v1.3.4 规则解析质量提升
- 日期：2026-04-29
- 所属版本：v1.3.4
- 所属阶段：Phase 0-6
- 类型：能力增强 / 解析质量 / 测试 / 工具
- 目标：根据 v1.3.3 批量 OCR/解析报告的失败样本（first10 和 ReceiptDebugTool 差异报告），系统性修复 `LedgerTextInterpreterCore` 的金额提取、商户提取和分类推断缺陷；将 core 引擎从基础规则升级为覆盖主流小票和支付截图。
- 改动范围：
  - `AutoLedgerCore/Models/LedgerInterpretationModels.swift`：新增 `merchantMissing` warning 枚举。
  - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：金额提取重写为合计行优先策略——第一优先 TOTAL/Grand Total/Jumlah 等关键词行，第二优先带货币符号 + 小数的最后金额，第三回退到最后一个合理金额；新增 `RM` 货币前缀专用正则（`rmAmountRegex`）；新增公司注册号/税号排除（`lineLooksLikeRegistrationNumber`），支持 `CO.REG:860671-D`、`JM0517726`、`GST ID` 等格式。商户提取重写——新增非商户黑名单（`tan woon yann`、`Cash Sale`、`TAX INVOICE`、`Thank You` 等 30+ 项）；新增注册号/单据类型行排除；优先从文本上半区提取；无法提取时输出 `merchantMissing` warning。分类推断——新增内置商户→分类映射表（MR D.I.Y.→shopping、McDonald's→dining、NTUC FAIRPRICE→groceries 等 7 组），未知商户回退 `TransactionCategory.infer` 行业关键词。
  - `scripts/OfflineRegression.swift`：新增 7 条 core 引擎回归断言——RM 注册号排除、MR DIY 商户提取、TOTAL 行优先、RM 合计行、商户黑名单（tan woon yann→INDAH GIFT）、INVOICE 头过滤（TAX INVOICE→SOON HUAT）、McDonald's 分类推断。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 6 条 core 引擎 Golden Case——`core_rm_receipt_reg_number`、`core_multi_item_total_priority`、`core_blacklist_header_merchant`、`core_invoice_header_merchant`、`core_mcdonalds_category_dining`、`core_malay_total_rm`。
  - `tools/receipt_ocr/batch_report.swift`：新增 Markdown 解析报告生成工具，输出总样本数、金额命中率、商户非空率、置信度分布、分类分布、警告统计、Top 失败样本和可疑金额。
  - `tools/receipt_ocr/README.md`、`scripts/run_receipt_batch_regression.sh`：同步工具说明和脚本，支持可选报告输出。
  - `versions/v1.3.4-plan.md`：新增版本计划，覆盖失败分析、金额/商户/分类修复、Golden Case 迁移、Markdown 报告和回归门禁。
- 未改动范围：未修改 `SmartReceiptParser`、`LedgerStore`、`Transaction` 等 App 层核心数据模型；未开始 Apple Watch target；未修改 `BillRelevanceGate` 判断逻辑；未做 LLM-driven 规则增强。
- 完成内容：Amount 提取 P0 问题（注册号误作金额、小计误作合计、RM 前缀未覆盖）全部修复；Merchant 提取 P0 问题（页眉/页脚被当作商户）全部修复；新增 6 条 core 引擎 Golden Case、31 条总计、pass 率 100%；新增 Markdown 报告工具；64 条离线回归全部 pass。
- 未完成内容：core 引擎分类映射仍需继续扩充（当前仅覆盖 7 组常见商户）；马来文/日文小票覆盖仍需更多真实样本。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`（64 条断言全部通过）
  - PASS：`bash scripts/run_golden_regression.sh`（31 条 Golden Case 全部通过）
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：金额提取从"取第一个金额"改为"合计行优先"策略后，无 TOTAL 行的小票使用回退策略（最后显示金额），少量样本可能从之前的幸运命中变为回退命中，需在批量报告中持续监控金额命中率变化。商户黑名单只包含已确认的非商户行特征；若后续发现真实商户被误杀，可从黑名单移除。
- 回滚方式：`git revert` `LedgerTextInterpreterCore.swift` 和 `LedgerInterpretationModels.swift` 恢复 v1.3.3 行为；Golden Case 新增条目可按文件独立回滚；`batch_report.swift` 不影响 App 主流程。
- 结论：v1.3.4 核心修复已完成，代码门禁全部通过。
- 下一步建议：在 `receiptsample/` 真实小票上跑一次全量批量报告，验证金额命中率和商户非空率；扩充 core 引擎商户→分类映射表；推进 v1.3.5 Worker API 评估或 v1.4 Apple Watch 端实现。

### ITER-051 Sample Golden Case 扩展
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 6-7
- 类型：测试 / 工具 / 解析质量
- 目标：把当前 `SampleReceiptProvider` 中所有既有样本纳入 Golden Case，防止后续文本转账单规则调整时破坏现有样本解析。
- 改动范围：
  - `tools/receipt_ocr/golden_regression.swift`：新增 `engine`、`sampleTitle`、`receiptSource` 支持，保留 `core` 引擎并新增 `receiptParser` 引擎。
  - `scripts/run_golden_regression.sh`：纳入 `SampleReceipt`、`SampleReceiptProvider`、`ReceiptParser` 和 `AppFormatters` 编译依赖。
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增 20 条内置 Sample 样本 Golden Case。
  - `tests/golden/ledger_text_interpreter/README.md`：补充 `engine`、`sampleTitle` 与 `receiptSource` 字段说明。
- 未改动范围：未提交原始截图；未把大批量 `receiptsample/` OCR 结果直接固化为 Golden Case；未调整解析规则本身。
- 完成内容：Golden runner 现在可直接按 `sampleTitle` 从 `SampleReceiptProvider` 读取文本与来源，并断言金额、商户、分类和来源；现有 Golden Case 总数从 5 条扩展到 25 条。
- 未完成内容：仍需后续从真实小票批量 OCR 结果中挑选脱敏样本，补充复杂纸质小票和失败样本。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`，25 case(s)
- 风险与注意事项：Sample Golden 先锁定当前成熟 `ReceiptParser` 行为，平台无关 `LedgerTextInterpreterCore` 仍只覆盖首批核心用例；后续迁移核心解释器时应逐步把 Sample 用例切换到 core 引擎。
- 回滚方式：移除 `cases.jsonl` 中 `sample_*` 用例，并将 Golden runner 恢复为只调用 `LedgerTextInterpreterCore`。
- 结论：现有 Sample 样本已全部进入 Golden 回归门禁。
- 下一步建议：把 `scripts/run_golden_regression.sh` 接入常规离线回归或 CI，并在修复小票 total 误识别时先补 Golden Case。

### ITER-050 Golden Case 回归门禁
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 6-7
- 类型：测试 / 工具 / 解析质量
- 目标：建立文本转账单规则的 Golden Case 回归脚本，每次调整 `LedgerTextInterpreterCore` 后可跑字段级断言，防止已有识别回退。
- 改动范围：
  - `tests/golden/ledger_text_interpreter/cases.jsonl`：新增首批 5 条 Golden Case。
  - `tests/golden/ledger_text_interpreter/README.md`：说明 JSONL 格式和运行方式。
  - `tools/receipt_ocr/golden_regression.swift`：新增 Golden Case runner，断言草稿存在性、金额、商户、分类、置信度、needsReview 和 warnings。
  - `scripts/run_golden_regression.sh`：新增一键编译并运行 Golden 回归脚本。
  - `LedgerTextInterpreterCore.swift`：补充基础标签提取，优先识别 `金额/Total` 行与 `商户：xxx`。
  - `TransactionCategory.swift`：补充 `fairprice`、`walmart`、`supermarket` 到 groceries。
- 未改动范围：未提交真实图片；未引入大规模 Golden Case；未把 Golden 回归接入 CI。
- 完成内容：Golden Case 回归可独立运行，失败时输出 case id 和字段级差异；首批样本覆盖语音、支付文本、英文小票、非账单文本和空 OCR。
- 未完成内容：还需要从 `receiptsample` 批量 OCR 结果中挑选、脱敏并沉淀更多公共样本；Markdown 报告仍未实现。
- 测试情况：
  - PASS：`bash scripts/run_golden_regression.sh`
  - PASS：`bash scripts/run_receipt_batch_regression.sh .tmp/receipt_ocr/scanned_receipts.first10.ocr.jsonl .tmp/receipt_ocr/scanned_receipts.first10.parse.jsonl`
- 风险与注意事项：Golden Case 应表达期望行为，不应盲目固化明显错误的解析结果；当前 first10 样本仍暴露出部分收据金额误取编号的问题，应通过新增期望样本推动规则修复。
- 回滚方式：移除 Golden 脚本与 `tests/golden` 目录，不影响 App 主流程；分类关键词可单独回滚。
- 结论：文本转账单规则已有最小 Golden 回归门禁。
- 下一步建议：从批量 OCR 前 10 个失败/可疑样本中挑 3-5 个脱敏后加入 Golden Case，并修复小票 total 金额抽取。

### ITER-049 v1.3.3 首轮实现：核心解释器、账单相关性 gate、批量工具骨架
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 1-7
- 类型：重构 / 能力增强 / 测试 / 工具
- 目标：按 v1.3.3 计划落地首轮平台无关解释器核心、OCR 后非账单图片判断、App 提示和本地批量 OCR/解析工具骨架。
- 改动范围：
  - `AutoLedgerCore/Models/LedgerInterpretationModels.swift`：新增 `InterpretInput`、`InterpretResult`、`TransactionDraft`、`LedgerInputSourceType`、`InterpretWarning` 等核心模型。
  - `AutoLedgerCore/Services/BillRelevanceGate.swift`：新增账单相关性判断，低账单信号文本返回 `nonBillImage`。
  - `AutoLedgerCore/Services/LedgerTextInterpreterCore.swift`：新增核心解释器，支持非账单拦截、语音短句草稿、简单账单草稿。
  - `LedgerTextInterpreter.swift`、`LedgerStore.swift`：App 解释器接入 core gate，非账单图片不进入 Smart parser，提示用户图片没有有效账单信息并记录 debug。
  - `Localizable.strings`：新增中英文 `receipt.non_bill_image`。
  - `tools/receipt_ocr/`、`scripts/run_receipt_batch_regression.sh`：新增本地批量 OCR JSONL 与批量解析 smoke 工具。
  - `OfflineRegression.swift`、`run_offline_regression.sh`：新增 core/gate/nonBillImage 回归断言，并纳入离线编译。
- 未改动范围：未提交 `receiptsample/` 原始图片；未提交 Golden Case 样本库；未上线 Worker API；未将 `SmartReceiptParser` 迁入平台无关核心；未改变 SQLite schema。
- 完成内容：App OCR 文本已具备非账单拦截；核心解释器可独立跑基础解释；批量解析脚本可读取 OCR JSONL 并输出 parse JSONL。
- 未完成内容：Golden Case JSONL 和 Markdown 汇总报告仍需后续补齐；当前核心账单草稿提取为基础规则，复杂 OCR 仍由 App adapter 继续使用 `SmartReceiptParser`。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`bash scripts/run_receipt_batch_regression.sh <smoke-ocr-jsonl> /tmp/receipt-parse.jsonl`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：账单相关性 gate 目前保守放行支付/小票信号，避免误拦截弱格式小票；`ReceiptSource.manual` 在 OCR 导入里代表未知来源，因此仍映射到 OCR/payment 路径，只有 `.voice` 走短句分支。
- 回滚方式：在 `LedgerTextInterpreter` 中移除 core gate 调用，恢复所有 OCR 文本直接进入 v1.3.2 的 Smart parser；工具文件可独立删除，不影响 App 主流程。
- 结论：v1.3.3 首轮实现已落地，代码门禁通过。
- 下一步建议：新增 Golden Case JSONL 和 Markdown 报告生成，拿 `receiptsample/scanned_receipts/data` 前 20 张跑一次基线。

### ITER-048 v1.3.3 平台无关解释器核心与批量小票测试规划
- 日期：2026-04-27
- 所属版本：v1.3.3
- 所属阶段：Phase 0
- 类型：文档 / 架构规划 / 测试规划
- 目标：基于根目录 `LedgerTextInterpreter.md` 与 v1.3.2 工程现状，规划下一版本将解释器抽象为平台无关核心，并建立小票图片集批量 OCR、OCR 后账单相关性判断与批量解析回归。
- 改动范围：
  - `versions/v1.3.3-plan.md`：新增版本定位、目标架构、核心类型草案、批量 OCR 工具、Golden Case 设计、阶段拆分、验收标准、风险与回滚。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步规划记录。
- 未改动范围：本轮只做规划，不实现 `LedgerTextInterpreterCore`、批量 OCR CLI、Golden Case runner 或 App adapter 接入。
- 完成内容：明确 v1.3.3 的三条主线：一是抽象 `InterpretInput` / `InterpretResult` / `TransactionDraft` / `LedgerTextInterpreterCore`，二是在 OCR 后增加 `BillRelevanceGate`，对无关图片输出 `nonBillImage` 并提示用户“图片没有有效的账单信息”，三是基于本地 `receiptsample/` 建立 OCR JSONL、解析 JSONL、Markdown 报告和字段级 diff 的批量测试链路。
- 未完成内容：尚未冻结最终 Swift API；尚未决定新建独立 `AutoLedgerInterpreterCore` target 还是先在 `AutoLedgerCore` 中目录隔离。
- 测试情况：
  - PASS：`git diff --check`
- 风险与注意事项：`AutoLedgerCore` 当前仍含 Vision 依赖，若要严格平台无关，应优先考虑拆出更小的纯 Swift target；`receiptsample/` 已被 Git ignore，原始图片不得提交。
- 回滚方式：删除 `versions/v1.3.3-plan.md`，并移除 CHANGELOG / iteration-log 中的 ITER-048 记录即可，不影响代码。
- 结论：v1.3.3 版本规划已形成，可进入接口冻结和工具链实现。
- 下一步建议：先落 `TransactionDraft` 与 `InterpretResult` 的最小可编译模型，再做前 20 张小票的 OCR JSONL smoke test。

### ITER-047 统一文本转账单解析入口
- 日期：2026-04-27
- 所属版本：v1.3.2
- 所属阶段：Phase 0-4
- 类型：重构 / 能力增强 / 测试 / 文档
- 目标：把 OCR、语音转文本和一句话输入之后的账单结构化流程收敛到统一文本解释入口，再由统一新建账单入口写入账本。
- 改动范围：
  - `versions/v1.3.2-plan.md`：新增版本计划、架构边界、阶段拆分、验收标准和回滚方式。
  - `LedgerTextInterpreter.swift`：新增统一解释器，输出订阅、普通账单、多商品总金额缺失、语音短句结果和解析失败。
  - `LedgerStore.swift`：`importRecognizedText` 改为调用统一解释器；新增 `interpretVoiceText` 和 `createTransaction(from:)`；语音/一句话保存复用结构化账单入库链路。
  - `VoiceLedgerQuickEntryView.swift`、`VoiceLedgerConfirmView.swift`、`VoiceLedgerIntent.swift`：语音快捷入口、账本页一句话入口和 Siri 语音入口改为通过统一解释器的 `.voice` 分支生成账单草稿。
  - `OfflineRegression.swift`、`run_offline_regression.sh`：离线编译纳入新解释器，并保留 OCR、语音、备份、商户别名回归断言。
- 未改动范围：不重写 OCR、语音识别或短句解析规则；不合并 `VoiceLedgerParser` 与小票解析器；不做多账单拆分、收入、转账、报销或 SQLite schema 变更。
- 完成内容：图片 OCR/剪切板/分享/订阅邮件/语音/一句话输入/Siri 语音文本均进入统一文本解释层；App 内结构化账单统一通过 `createTransaction(from:)` 进入入库、去重、调试和备份链路。
- 未完成内容：Siri `VoiceLedgerIntent` 的保存仍是 AppIntent 内的轻量直写路径，后续可抽出 AppIntent 可复用的非 UI 入库适配器。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：语音短句接入统一解释器后，UI 解析变为异步任务，需要真机确认连续输入和长按松手自动保存的手感。
- 回滚方式：让语音 UI 恢复直接调用 `VoiceLedgerParser`，并将 `LedgerStore.importRecognizedText` 恢复为原内联解析逻辑。
- 结论：v1.3.2 统一文本转账单架构已落地，代码门禁通过。
- 下一步建议：真机点验 OCR 导入、一句话输入实时解析、首页长按语音自动保存和重复导入提示。

### ITER-046 商户别名自动学习与历史账单回刷
- 日期：2026-04-27
- 所属版本：App Store v1.2.0 补丁
- 所属阶段：商户规范化增强
- 类型：能力增强 / 持久化 / 测试
- 目标：用户把高置信自动入账账单的长商户名改为简称时，自动学习商户别名，并把已有账单中完全匹配的长商户名统一刷新为别名。
- 改动范围：
  - `LedgerStore.swift`：新增 `setMerchantAlias`、`deleteMerchantAliases`、`applyMerchantAliasesToExistingTransactions` 和高置信编辑自动学习逻辑；商户别名保存后回刷当前账单并写回 SQLite。
  - `MerchantAliasView.swift`：新增/删除商户别名改为调用 `LedgerStore` 方法，确保设置页变更也触发历史账单刷新。
  - `OfflineRegression.swift`：新增手动别名刷新历史账单、编辑高置信账单自动学习别名的断言。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步本轮记录。
- 未改动范围：不做模糊匹配；不回滚删除别名后的历史账单名称；不修改分类学习规则。
- 完成内容：别名新增/更新会把所有完全匹配原商户名的当前账单更新为别名；用户编辑高置信自动入账账单并将商户改短名时，会自动记录别名规则。
- 未完成内容：真机 UI 仍需点验设置页新增别名后的刷新提示和账本列表展示。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：当前只做完全匹配，避免把相似但不同的商户误合并；删除别名不会自动恢复历史账单原名。
- 回滚方式：移除 `updateTransaction` 中的自动学习调用，并让设置页恢复直接修改 `merchantAliases` 后保存。
- 结论：商户别名自动学习与历史账单回刷已实现，代码门禁通过。
- 下一步建议：在真机上导入一笔高置信账单，将商户名改短，确认设置页出现别名且历史同名账单被刷新。

### ITER-045 一句话记账交互收敛
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 交互 / 测试
- 目标：收敛语音与文本入口边界，让首页只有圆形麦克风按钮响应长按，账本页改为纯文本“一句话记账”实时解析。
- 改动范围：
  - `VoiceLedgerQuickEntryView.swift`：长按识别手势从整块方框收窄到圆形麦克风按钮。
  - `VoiceLedgerConfirmView.swift`：移除页内麦克风按钮和手动解析按钮；输入框内容变化时实时调用 `VoiceLedgerParser`，同步商户、金额、分类、时间和提示文案。
  - `Localizable.strings`：账本页标题改为“一句话记账” / `One-Line Ledger`。
  - README、v1.3.1 计划、回归基线、发布草稿、CHANGELOG：同步当前入口分工。
- 未改动范围：未改变首页语音识别服务；未改变 Siri `VoiceLedgerIntent`；未改变语音交易保存、去重、备份和调试记录路径。
- 完成内容：首页长按只响应圆形按钮；账本页成为纯文本一句话入口，用户输入后下方账本字段实时生成，保存时继续复用 `LedgerStore.addVoiceTransaction`。
- 未完成内容：真机仍需确认圆形按钮命中区是否符合手感，输入实时解析是否足够顺滑。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`git diff --check`
- 风险与注意事项：实时解析会在用户输入未完成时展示失败/待确认提示，文案需保持温和，避免让用户误以为已保存失败。
- 回滚方式：恢复 `VoiceLedgerConfirmView` 的手动解析按钮；或把 `VoiceLedgerQuickEntryView` 的手势重新挂到更大的容器。
- 结论：交互收敛完成，构建通过。
- 下一步建议：真机验证首页圆形按钮长按、账本页输入 `午饭 28 元` 时字段实时生成并可保存。

### ITER-044 首页按住语音快捷记账
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 交互 / 测试
- 目标：把 App 内语音记账从账本页入口前移到首页，支持打开 App 后按住录音、松手识别，并在高置信场景自动保存。
- 改动范围：
  - `VoiceLedgerQuickEntryView.swift`：新增首页快捷入口，支持按住输入、松手识别、高置信自动保存、低置信展示识别结果与保存按钮。
  - `InboxView.swift`：首页 hero 下方新增语音快捷记账入口。
  - `VoiceSpeechRecognizer.swift`：停止录音时结束音频输入，不直接取消识别任务，降低松手后最终转写丢失风险；新增 `cancel()` 用于页面退出清理。
  - `VoiceLedgerConfirmView.swift`：将原“开始语音”按钮调整为“输入”，重做图标和按钮视觉，避免图标色与背景接近。
  - `Localizable.strings`：补充中英文按住录音、松手识别、处理中、空结果、自动保存提示。
- 未改动范围：未实现 Apple Watch 独立端；未存储音频文件；未放开收入、转账、报销或多金额语句自动保存。
- 完成内容：首页已提供长按录音快捷路径；账本页保留文本一句话记账，输入时实时解析并生成下方账本字段；语音识别、解析、保存仍复用同一套服务与 `LedgerStore.addVoiceTransaction`。
- 未完成内容：真机仍需验证长按手感、松手后的最终转写、自动保存与低置信保存按钮。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - PASS：`bash scripts/run_offline_regression.sh`
- 风险与注意事项：Speech 最终转写回调可能受系统状态影响；当前用短延迟等待松手后的最终结果，真机体验需继续观察。
- 回滚方式：从 `InboxView` 移除 `VoiceLedgerQuickEntryView`，保留账本页 `VoiceLedgerConfirmView` 入口；或恢复 `VoiceSpeechRecognizer.stop()` 为立即取消。
- 结论：代码门禁通过，首页语音快捷入口已落地。
- 下一步建议：真机验证首页首次权限、按住录音、松手识别、高置信自动保存、低置信手动保存，并评估 Apple Watch 端复用同一解析/保存接口。

### ITER-043 App 内麦克风语音输入
- 日期：2026-04-27
- 所属版本：v1.3.1
- 所属阶段：Phase 3-4
- 类型：能力增强 / 前端 / 权限 / 测试
- 目标：在保留文本“一句话记账”的基础上，为 App 内语音记账补充真正的麦克风语音输入。
- 改动范围：
  - `VoiceSpeechRecognizer.swift`：新增 Speech + AVFoundation 语音识别服务，处理语音识别权限、麦克风权限、开始/停止听写、部分识别结果回传。
  - `VoiceLedgerConfirmView.swift`：新增开始/停止语音按钮，识别结果自动写入文本框并复用 `VoiceLedgerParser` 解析，保留手动输入和手动解析按钮。
  - `AutoLedger.xcodeproj/project.pbxproj`：主 App build settings 新增 `NSMicrophoneUsageDescription` 与 `NSSpeechRecognitionUsageDescription`。
  - `Localizable.strings`：补充中英文语音输入状态、权限失败和不可用文案。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步本轮记录。
- 未改动范围：不改变 Siri `VoiceLedgerIntent`；不存储录音文件；不引入云端语音识别；不移除文本一句话记账。
- 完成内容：App 内入口现在支持点击麦克风开始听写，转写文本自动进入原有解析/确认/保存流程。
- 未完成内容：真机麦克风权限弹窗、语音识别可用性、中文听写准确度仍需人工验证。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：Speech 识别可用性受系统语言、网络/系统服务状态和权限影响；权限被拒绝时用户仍可使用文本一句话记账。
- 回滚方式：移除 `VoiceSpeechRecognizer` 和 `VoiceLedgerConfirmView` 中的语音按钮；保留文本输入与 Siri 入口不受影响。
- 结论：代码已实现，代码门禁通过，真机语音输入确认待执行。
- 下一步建议：在真机上首次点击语音按钮，确认麦克风/语音识别权限文案、开始/停止状态、识别文本自动解析和保存链路。

### ITER-038~042 v1.3.1 语音记账实现
- 日期：2026-04-26
- 所属版本：v1.3.1
- 所属阶段：Phase 0-5
- 类型：能力增强 / 前端 / AppIntent / 测试 / 治理
- 目标：按 `v1.3.1-plan.md` 实施语音记账 MVP，覆盖语音来源、规则解析、Siri 入口、App 内确认、本地化、回归基线与发布门禁。
- 改动范围：
  - `ReceiptSource.swift` / `ImportDebugRecord.swift`：新增 `voice` 来源和 `voiceIntent` 调试入口。
  - `VoiceLedgerParser.swift`：新增语音短句规则解析、置信度与失败原因。
  - `VoiceLedgerIntent.swift` / `QuickLedgerIntent.swift`：新增 Siri/AppIntent 入口并注册 AppShortcut。
  - `LedgerStore.swift` / `LedgerView.swift` / `VoiceLedgerConfirmView.swift`：新增 App 内语音/文本确认入口与保存路径。
  - `Localizable.strings`：补充中英文语音记账文案。
  - `OfflineRegression.swift` / `run_offline_regression.sh`：新增语音解析离线回归。
  - `versions/v1.3.1-plan.md`、`versions/v1.3.1-regression-baseline.md`、`versions/v1.3.1-RELEASE(draft).md`、`README.md`、`AutoLedger/README.md`、`CHANGELOG.md`：同步实现与门禁状态。
- 未改动范围：不做收入、转账、报销、多金额拆分；不做自研录音转写或云端语音识别；不做多轮 Siri 对话确认。
- 完成内容：v1.3.1 代码实现完成；语音规则解析、失败边界、Siri Intent metadata、App 内确认入口、语音来源展示和调试记录已接入；离线回归与 generic iOS 构建通过。
- 未完成内容：真机 Siri 发现、Siri 参数输入、高置信后台直写、App 回前台刷新和 App 内确认交互仍待人工验证。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：AppShortcut 固定短语不能直接内嵌 `String` 参数，当前通过无参数短语触发并由 Siri/快捷指令收集 `content`；真机体验可能受 Shortcuts 索引和系统语言影响。
- 回滚方式：移除 `VoiceLedgerIntent` 的 AppShortcut 注册；隐藏账本页 `waveform` 入口；保留已有 `source = voice` 交易作为普通交易继续显示和备份。
- 结论：本轮代码完成，发布判定待真机 Siri 验证。
- 下一步建议：安装到真机后验证 Siri 能发现语音记账、`午饭 28 元` 可高置信直写、失败句式不会保存，以及 App 内确认页可通过系统听写输入并保存。

### ITER-037 v1.3.1 语音记账 + Siri 版本规划
- 日期：2026-04-26
- 所属版本：v1.3.1
- 所属阶段：Phase 0
- 类型：文档 / 治理
- 目标：分析根目录 `autoledger_voice_siri_design.md` 与现有 AppIntent、SQLite、分类和备份恢复能力，建立 v1.3.1 版本计划。
- 改动范围：
  - `versions/v1.3.1-plan.md`：新增版本定位、承接输入、设计约束、In Scope / Out of Scope、Phase 0-5 阶段拆分、ITER-037-042 迭代拆分、验收标准、测试计划、风险与回滚。
  - `CHANGELOG.md`：新增 v1.3.1 / ITER-037 文档规划记录。
  - `process/iteration-log.md`：新增本条迭代日志。
- 未改动范围：未实现 `VoiceLedgerParser`、`VoiceLedgerIntent`、App 内语音入口、本地化文案或回归脚本；未调整既有 Xcode 工程版本号改动。
- 完成内容：明确 v1.3.1 主题为"语音记账 MVP + Siri 快捷入口"；确认本版只做"一句话 → 一笔支出"，Siri 高置信度直接保存，中低置信度失败重试，App 内入口承接确认与修改；将语音来源、规则解析、Siri Intent、App 内确认、调试记录、备份联动和发布门禁拆成可执行迭代。
- 未完成内容：语音解析模型、Siri 真机触发、App 内确认 UI、语音交易回归与 v1.3.1 发布门禁仍待后续 ITER-038+ 执行。
- 测试情况：文档规划迭代，未运行代码测试。
- 风险与注意事项：Siri AppIntent 参数短语需要真机验证；语音误识别可能误存，因此计划限定 Siri 仅 high 置信度保存；当前工作区已有 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 版本号改动，本轮保持不处理。
- 回滚方式：删除 `versions/v1.3.1-plan.md`；移除 `CHANGELOG.md` 和 `process/iteration-log.md` 中 ITER-037 相关条目。
- 结论：本轮完成。v1.3.1 版本计划草稿已建立。
- 下一步建议：进入 ITER-038，新增 `ReceiptSource.voice`、语音调试来源与 `VoiceLedgerParser`，先用离线回归锁住解析边界。

### ITER-031~036 v1.3.0 数据备份与恢复实现
- 日期：2026-04-26
- 所属版本：v1.3.0
- 所属阶段：Phase 0-5
- 类型：能力增强 / 持久化 / 前端 / 测试 / 治理
- 目标：按 `v1.3.0-plan.md` 实施 BackupBundle、手动 JSON 导出/导入、iCloud 单文件自动备份、空库恢复提示、回归基线与发布门禁草稿。
- 改动范围：
  - `BackupBundle.swift`：新增备份 schema、摘要、订阅元数据、低风险设置与校验器。
  - `SQLiteTransactionStore.swift`：新增 `loadBackupTransactions()` 与 `replaceForRestore(...)`，支持含 `deleted_at` 的覆盖恢复；订阅保存保留原始 `createdAt`。
  - `LedgerStore.swift`：新增备份包生成、JSON 导出、JSON 导入、覆盖恢复、iCloud 立即备份、自动备份调度、空库恢复检测。
  - `DataManagementView.swift`：新增设置页数据管理入口，支持当前数据摘要、iCloud 备份开关、立即备份、JSON 导出与 JSON 恢复。
  - `ICloudBackupService.swift`：新增 iCloud Drive `AutoLedgerBackup.json` 读写。
  - `AutoLedgerApp.swift`：App 进入后台触发自动备份，空库启动检测到 iCloud 备份时弹窗提示恢复。
  - `AutoLedger.entitlements`：新增 iCloud Documents 容器声明。
  - `OfflineRegression.swift` / `run_offline_regression.sh`：新增备份导出/恢复离线断言与编译依赖。
  - `versions/v1.3.0-regression-baseline.md`、`versions/v1.3.0-RELEASE(draft).md`、`README.md`、`AutoLedger/README.md`、`CHANGELOG.md`、`versions/v1.3.0-plan.md`：同步实现与门禁状态。
- 未改动范围：不做 CloudKit 结构化同步；不做多设备双向合并；不备份原始截图、OCR 全文、诊断包、反馈附件或 Gemma 模型文件。
- 完成内容：v1.3.0 代码实现完成；手动 JSON 备份/恢复和 SQLite + UserDefaults 混合数据恢复已有离线回归覆盖；iCloud 单文件备份代码和 entitlement 已就绪。
- 未完成内容：真机 iCloud Drive 写入、重装恢复弹窗、share sheet/file importer 人工验证仍待执行。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：iCloud 容器 `iCloud.top.darkrio326.AutoLedger` 需要在 Apple Developer 后台开启并匹配 provisioning profile；若容器未就绪，可发布手动 JSON 备份版并将自动 iCloud 备份延期。
- 回滚方式：隐藏 `DataManagementView` 入口；移除 iCloud entitlement 和 `ICloudBackupService`；回退 `LedgerStore` 备份/恢复扩展与 SQLite 备份 API；保留现有 SQLite 数据不受影响。
- 结论：本轮代码完成，发布判定待真机 iCloud 验证。
- 下一步建议：在真机上开启 iCloud Drive，验证立即备份、后台备份、删除 App 后空库恢复提示，以及 JSON 文件导入导出 UI。

### ITER-030 v1.3.0 版本规划
- 日期：2026-04-26
- 所属版本：v1.3.0
- 所属阶段：Phase 0
- 类型：文档 / 治理
- 目标：读取根目录 `autoledger_icloud_backup_design.md` 和现有工程进展，建立 v1.3.0 版本计划，将 iCloud 轻量备份设计拆成可执行迭代。
- 改动范围：
  - `versions/v1.3.0-plan.md`：新增版本定位、承接输入、In Scope / Out of Scope、Phase 0-5 阶段拆分、ITER-030-036 迭代拆分、依赖清单、验收与回滚、文档同步要求。
  - `CHANGELOG.md`：新增 v1.3.0 / ITER-030 文档规划记录。
  - `process/iteration-log.md`：新增本条迭代日志，并将更新日期调整到 2026-04-26。
- 未改动范围：未实现 `BackupBundle` 代码；未配置 iCloud entitlement；未新增导入导出 UI；未运行构建或回归测试。
- 完成内容：明确 v1.3.0 主题为"数据备份 + 手动迁移 + iCloud 轻量恢复"；确认本版优先做单文件 JSON 备份与恢复，不做 CloudKit 结构化实时同步；将 SQLite 与 UserDefaults 分散数据都纳入备份范围。
- 未完成内容：schema 代码、手动导出/导入、iCloud 自动备份、空库恢复提示和 v1.3.0 回归门禁仍待后续 ITER-031+ 执行。
- 测试情况：文档规划迭代，未运行代码测试。
- 风险与注意事项：当前工程只有 App Group entitlement，未发现 iCloud entitlement；后续 Phase 3 需要真机 Apple ID 和 iCloud Drive 环境验证。若 v1.2.0 真机门禁出现阻断，应先追加 v1.2.0 修复再进入 v1.3.0 实现。
- 回滚方式：删除 `versions/v1.3.0-plan.md`；移除 `CHANGELOG.md` 和 `process/iteration-log.md` 中 ITER-030 相关条目；恢复迭代日志更新日期。
- 结论：本轮完成。v1.3.0 版本计划草稿已建立。
- 下一步建议：进入 ITER-031，定义 `BackupBundle` v1 与 SQLite/UserDefaults 字段映射，并补充导入校验模型。

### ITER-029 回归基线 + 发布门禁
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：文档 / 测试 / 治理
- 目标：建立 v1.2.0 回归基线与发布门禁草稿，覆盖本版新增的端侧 LLM、月报图表、异常消费检测、云闪付 / 银联、订阅管理增强和软删除持久化，并记录真机待验证项。
- 改动范围：
  - `versions/v1.2.0-regression-baseline.md`：新增回归矩阵，覆盖主路径、多渠道导入、端侧 LLM、月报图表、解析平台、订阅管理、软删除、去重/反馈等场景；记录本轮离线回归与 generic iOS 构建 PASS。
  - `versions/v1.2.0-RELEASE(draft).md`：新增发布前检查、门禁判定、发布结论、版本亮点、回滚方案与发布后观察指标。
  - `versions/v1.2.0-plan.md`：将 ITER-028 标记为暂无外测反馈输入而跳过实现，将 ITER-029 标记为完成。
  - `README.md`、`AutoLedger/README.md`：更新最近删除描述为跨会话恢复；根 README 修正 v1.1.0 状态显示。
  - `CHANGELOG.md`、`process/iteration-log.md`：同步 ITER-029 完成记录。
- 未改动范围：未执行真机端到端回归；未上传 TestFlight 构建；未新增代码功能；未处理具体外测 Issue，因为当前没有可执行反馈输入。
- 完成内容：v1.2.0 已具备可追溯回归基线和发布门禁草稿；离线回归与 generic iOS 构建结果已回填；真机待验证项和非阻断限制已明确。
- 未完成内容：真机全链路验证、旧库升级验证、TestFlight 构建上传和最终发布判定仍待执行。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`（在 `AutoLedger/` 目录执行）
- 风险与注意事项：本轮是文档收口，不等价于发布放行；门禁结论仍为待真机验证。Gemma 下载体积、云闪付真实样本覆盖和软删除旧库升级仍需真机确认。
- 回滚方式：删除 `versions/v1.2.0-regression-baseline.md` 与 `versions/v1.2.0-RELEASE(draft).md`；恢复 README、版本计划、CHANGELOG 与迭代日志中 ITER-029 相关文案。
- 结论：本轮完成。v1.2.0 回归基线与发布门禁草稿已建立。
- 下一步建议：执行真机端到端回归，回填 `v1.2.0-regression-baseline.md`；若出现阻断，追加 ITER-030+ 修复；若全部通过，则完成发布判定。

### ITER-028 外测反馈修复坑位
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：Bugfix / 治理
- 目标：承接 v1.1.0 / v1.2.0 TestFlight 外测反馈中的高优紧急修复。
- 改动范围：无代码改动。
- 未改动范围：未处理具体 Issue；未新增回归样本；未调整功能行为。
- 完成内容：确认当前本地文档和工程中没有可执行的外测反馈清单；保留后续 ITER-030+ 坑位承接真实反馈。
- 未完成内容：真实 TestFlight 反馈仍待收集。
- 测试情况：无新增测试；沿用 ITER-029 的离线回归和构建验证。
- 风险与注意事项：若后续收到高优反馈，可能需要打断发布收口并追加修复迭代。
- 回滚方式：无需回滚。
- 结论：本轮跳过实现。原因是缺少具体反馈输入，强行修改会扩大无依据变更。
- 下一步建议：推进 ITER-029 回归基线与发布门禁；后续有反馈再追加迭代。

### ITER-027 软删除持久化 + 最近删除跨会话
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 4
- 类型：能力增强 / 持久化 / 测试
- 目标：按 `v1.2.0-plan.md` 完成 SQLite `deleted_at` 软删除持久化，让 `DeletedTransactionsView` 中的最近删除账单在 App 重启后仍可恢复，并保留彻底删除能力。
- 改动范围：
  - `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：`transactions` 表启动时安全迁移新增 `deleted_at` 列；常规 `loadTransactions()` 过滤 `deleted_at IS NULL`；`delete(transactionID:)` 改为写入 `deleted_at` 与 `updated_at`；新增 `loadDeletedTransactions(limit:)`、`restoreTransaction(id:)`、`permanentlyDeleteTransaction(id:)`。
  - `AutoLedger/App/LedgerStore.swift`：初始化与刷新时加载 SQLite 最近删除列表；删除后内存移动到 `deletedTransactions`；恢复和彻底删除操作写回 SQLite 后再更新内存。
  - `AutoLedger/Features/Ledger/DeletedTransactionsView.swift`：更新空态与底部说明，明确最近删除会跨会话保留。
  - `scripts/OfflineRegression.swift`：新增 SQLite 软删除回归断言，覆盖活动列表隐藏、最近删除列表可见、重开 store 后仍保留、恢复回活动列表、彻底删除后完全移除。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`、`AutoLedger/Features/Settings/SettingsView.swift`：同步 ITER-027 完成状态与版本状态。
- 未改动范围：不新增自动清理最近删除的过期策略；不改变 `TransactionStore` 协议接口；不迁移历史会话内 `deletedTransactions` 内存数据；不新增 UI 筛选/批量恢复。
- 完成内容：账单删除改为 SQLite 软删除；活动账本不会加载已删除行；最近删除可从 SQLite 重新加载；恢复会清空 `deleted_at`；彻底删除仍执行物理删除。
- 未完成内容：软删除保留期限、批量清空与发布门禁文档尚未进入本轮，留给 ITER-028/029 或后续版本收口。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：`deleted_at` 迁移在启动建表流程中执行，已兼容既有库；真实设备升级场景仍建议在 TestFlight 数据上验证一次。最近删除默认加载最近 50 条，极端大量删除记录不会一次性全部展示。
- 回滚方式：将 `delete(transactionID:)` 恢复为物理删除；移除 `deleted_at` 过滤、最近删除加载/恢复/彻底删除 API 与离线回归断言；设置页和版本计划回退到 ITER-026 状态。已添加到现有数据库的 `deleted_at` 列无需回滚，可保留为空列。
- 结论：本轮完成。v1.2.0 Phase 4 的软删除持久化部分已完成。
- 下一步建议：进入 ITER-028/029，处理 TestFlight 外测反馈、建立 v1.2.0 回归基线与发布门禁。

### ITER-026 订阅年度总览 + 费用优化建议 + 订阅编辑
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 3
- 类型：能力增强 / 前端 / 测试
- 目标：按 `v1.2.0-plan.md` 完成订阅管理增强：订阅列表展示年度总览，月付订阅支持年付节省建议，长按订阅可编辑核心字段。
- 改动范围：
  - `AutoLedger/Features/Settings/SubscriptionListView.swift`：新增年度总览卡，展示预估年度订阅开销、月均成本与已知可优化金额；订阅卡支持长按"编辑"；内嵌 `SubscriptionEditView`，可编辑商户、方案名称、周期、金额、最近扣费、下次扣费、年付价格与备注；月付订阅填写年付价后在卡片和编辑页展示节省建议。
  - `AutoLedger/App/LedgerStore.swift`：新增 `updateSubscription(_:)`，更新内存订阅、按下次扣费日期排序、调用 SQLite 更新并重新调度本地扣费提醒。
  - `scripts/OfflineRegression.swift`：新增 SQLite 订阅更新断言，覆盖编辑后字段持久化。
  - `AutoLedger/Features/Settings/SettingsView.swift`：更新版本状态文案，标记订阅管理增强已落地。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-026 完成状态。
- 未改动范围：不改变 `subscriptions` SQLite 表结构；不新增云端价格库；不做自动获取年付定价；不做订阅删除恢复；不新增独立 `SubscriptionEditView.swift` 文件，编辑视图以内嵌私有 View 形式放在订阅列表文件中。
- 完成内容：订阅列表可查看年度开销；月付订阅可录入年付价格并看到节省金额；长按订阅可编辑字段并持久化；年付价格与备注以订阅 id 为 key 存入 UserDefaults 侧表，满足不改表结构约束。
- 未完成内容：年付价格和备注未进入 SQLite 订阅表；若未来需要跨设备同步或更强备份，需要在后续 schema 版本中迁移为正式列。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：年付价与备注依赖订阅 id，若后续删除并重新识别同商户订阅，会生成新 id，旧侧表数据不会自动迁移；这是当前不改 SQLite schema 的取舍。
- 回滚方式：删除 `SubscriptionListView` 中年度总览、编辑 sheet、UserDefaults 侧表与节省建议逻辑；移除 `LedgerStore.updateSubscription(_:)`；移除 OfflineRegression 中订阅更新断言；恢复设置页和版本计划文案。
- 结论：本轮完成。v1.2.0 Phase 3 订阅管理增强已完成。
- 下一步建议：进入 ITER-027，推进 SQLite `deleted_at` 软删除持久化与 `DeletedTransactionsView` 跨会话恢复。

### ITER-025 云闪付 / 银联解析适配
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 2
- 类型：能力增强 / 解析适配 / 测试
- 目标：按 `v1.2.0-plan.md` 完成云闪付 / 银联基础解析适配，新增来源枚举、分享扩展 Bundle ID 映射、专用商户提取逻辑，并补齐离线回归样本。
- 改动范围：
  - `AutoLedgerCore/Enums/ReceiptSource.swift`：新增 `.unionPay`，标题为"云闪付"；来源推断支持"云闪付"，以及"银联"/"UnionPay"与交易详情关键词组合，降低普通广告噪声误判。
  - `AutoLedgerCore/Services/ReceiptParser.swift`：新增 `parseUnionPayVoucher(lines:)`，支持"商户名称"分行展示与"商户名称：XXX"内联展示两种版式；商户优先链新增云闪付/银联专用提取。
  - `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增"云闪付付款成功截图"与"银联二维码支付详情截图"两条回归样本。
  - `AutoLedger/ShareExtension/ShareViewController.swift`：新增 `com.unionpay.chsp` → `unionPay` 来源映射。
  - `AutoLedgerCore/Enums/TransactionCategory.swift`：将"盒马/超市/便利店"分类规则前移到"会员/订阅"之前，避免支付详情页 UI 噪声把便利店消费误归数字服务。
  - `scripts/OfflineRegression.swift`：补齐云闪付/银联 merchant/amount/category 断言，并让分类失败信息输出 got/expected。
  - `scripts/run_offline_regression.sh`：补齐 v1.2.0 离线编译 stub（`LLMProvider`、`OCRTextCleaner`、`SmartReceiptParser.SmartResult` 等），恢复离线回归可运行。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-025 完成状态。
- 未改动范围：未新增联网校验；未修改 SQLite schema；未做多笔账单拆分；未宣称覆盖所有云闪付真实 OCR 版式，仍需外测样本继续扩充。
- 完成内容：云闪付/银联作为正式来源进入枚举和分享扩展映射；基础交易详情页可解析商户、金额、时间和分类；离线回归重新恢复通过。
- 未完成内容：真机云闪付截图和银联 POS 小票样本仍需继续采集；`com.unionpay.chsp` Bundle ID 需真机分享入口实测确认。
- 测试情况：
  - PASS：`bash scripts/run_offline_regression.sh`
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：云闪付/银联 OCR 版式差异较大，本轮只覆盖两类高频交易详情版式；来源推断中 `UnionPay` 需要伴随交易详情关键词才识别为 `.unionPay`，避免误伤通知中心广告噪声。
- 回滚方式：移除 `.unionPay` 枚举与 Share Extension 映射；删除 `parseUnionPayVoucher` 及商户优先链调用；删除两条样本和 OfflineRegression 断言；还原 `TransactionCategory` 分类规则顺序和离线回归 stub 变更。
- 结论：本轮完成。v1.2.0 Phase 2 新支付平台基础适配已完成。
- 下一步建议：进入 ITER-026，推进订阅年度总览、费用优化建议与订阅编辑；同时在外测中继续收集真实云闪付/银联截图扩充回归样本。

### ITER-024 异常消费检测：报告页提示卡 + 设置页阈值
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 1
- 类型：能力增强 / 前端
- 目标：按 `v1.2.0-plan.md` 完成 Phase 1 剩余异常消费检测能力：当月某分类支出超过近 3 个月同分类月均值阈值时，在报告页展示提示卡，并允许用户在设置页调整阈值。
- 改动范围：
  - `AutoLedger/Domain/Services/MonthlyInsightService.swift`：新增 `AnomalyAlert` 与 `MonthlyInsightService.detectAnomalies()`，按当前月分类支出对比过去 3 个完整月份同分类月均值，默认阈值由调用方传入；无历史基线的分类不报异常。
  - `AutoLedger/Features/Report/ReportView.swift`：新增 `@AppStorage("monthlyAnomalyThresholdPercent")`，在月度总览卡下方展示"消费提醒"卡片，最多列出 3 个异常分类，展示当前金额、近 3 月月均与倍率。
  - `AutoLedger/Features/Settings/AnalysisSettingsView.swift`：新增"消费分析"设置页，提供 100%～300% Slider、当前阈值显示与恢复默认按钮。
  - `AutoLedger/Features/Settings/SettingsView.swift`：新增"消费分析"入口，并更新版本状态文案。
  - `AutoLedger/App/AutoLedgerApp.swift`：注册 `monthlyAnomalyThresholdPercent` 默认值 150%。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步 ITER-024 完成状态。
- 未改动范围：不做通知推送；不做预算设定；不新增 SQLite schema；不改变交易分类或月报基础聚合；不修复离线回归脚本 v1.2.0 依赖清单问题。
- 完成内容：报告页可基于真实账本数据展示异常消费提示；用户可在设置页调整阈值并即时影响下次报告页计算；Phase 1 计划项完成。
- 未完成内容：真机视觉回归待补；离线回归脚本仍需后续补齐 v1.2.0 新增依赖清单。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
- 风险与注意事项：当前口径需要过去 3 个完整月份中至少出现过该分类支出；对于历史数据稀疏的用户，异常提示会偏保守。阈值默认 150%，可通过设置页调整。
- 回滚方式：删除 `MonthlyInsightService.swift` 和 `AnalysisSettingsView.swift`；移除 `ReportView` 中异常提示卡与 `SettingsView` 消费分析入口；移除 `AutoLedgerApp` 默认值注册。
- 结论：本轮完成。v1.2.0 Phase 1 月报分析增强已完成。
- 下一步建议：进入 ITER-025，推进云闪付 / 银联解析适配；并在适当时机补齐离线回归脚本依赖清单。

### ITER-023 月报改版：分类占比图 + 月度趋势柱图 + TOP5 商户
- 日期：2026-04-23
- 所属版本：v1.2.0
- 所属阶段：Phase 1
- 类型：能力增强 / 前端
- 目标：按 `v1.2.0-plan.md` 推进月报分析增强，报告页展示分类 Donut 占比、近 6 个月趋势柱图、TOP5 商户排行，并承接 ITER-022 遗留的"自定义分类月报归入其他"问题。
- 改动范围：
  - `AutoLedgerCore/Models/MonthlySnapshot.swift`：新增 `MerchantMetric`、`MonthlyTrendMetric`；`CategoryMetric` 改为稳定 `id/title/category?` 结构；按 `Transaction.category` 原始字符串聚合分类，自定义分类保留原始标题；新增 TOP 商户金额排行与近 6 个月月度趋势聚合。
  - `AutoLedger/Features/Report/ReportView.swift`：接入 Swift Charts，重构为月度总览卡、分类 Donut 图、近 6 月趋势柱图、TOP5 商户排行；分类行点击可高亮对应 Donut 分区。
  - `AutoLedger/Shared/Components/CategoryBreakdownRow.swift`、`AutoLedger/Shared/Extensions/TransactionCategory+UI.swift`：适配新的 `CategoryMetric`，内置分类继续使用原图标/颜色，自定义分类使用 `tag.fill` 与稳定配色。
  - `CHANGELOG.md`、`versions/v1.2.0-plan.md`：同步迭代完成状态。
- 未改动范围：异常消费检测（ITER-024）未做；设置页消费分析阈值未做；SQLite schema 未改；首页商户卡仍沿用 `topMerchants` 字符串列表。
- 完成内容：报告页已具备 Donut 分类占比、近 6 月趋势柱图、TOP5 商户列表；自定义分类在月报中独立展示，不再被合并到"其他"；保持 `topMerchants` 兼容首页现有展示。
- 未完成内容：离线回归脚本 `scripts/run_offline_regression.sh` 目前缺少 v1.2.0 新增的 `OCRTextCleaner`、`LLMProvider` 等依赖清单更新，脚本仍会在编译临时 `LedgerStore.swift` 时失败；本轮未扩大范围修复回归脚本。
- 测试情况：
  - PASS：`xcodebuild -workspace AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`
  - FAIL（既有脚本依赖清单问题）：`bash scripts/run_offline_regression.sh`，错误为 `OCRTextCleaner` / `LLMProvider` 未在离线编译临时上下文中提供。
- 风险与注意事项：Donut/Bar Chart 依赖 Swift Charts，当前工程 iOS 26 target 满足；自定义分类颜色按标题稳定哈希选择，后续若加入分类管理配色字段可替换为用户配置色。
- 回滚方式：还原 `MonthlySnapshot.swift` 的新增 metric 结构与聚合逻辑，`ReportView.swift` 回退到原分类列表页面，`CategoryBreakdownRow.swift` 回退到 `TransactionCategory` 强类型展示。
- 结论：本轮完成。ITER-023 已按 v1.2.0 计划交付，iOS 构建通过。
- 下一步建议：进入 ITER-024，新增 `MonthlyInsightService`、异常消费提示卡与设置页阈值配置；同时补齐离线回归脚本的 v1.2.0 依赖清单。

### ITER-022 编辑器支持自定义分类和来源
- 日期：2026-04-13
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强
- 目标：用户在账本中添加的自定义分类/来源，在编辑账单时无法在 Picker 中选择；根因是 `Transaction.category/source` 为强类型枚举，无法存储自定义字符串。
- 改动范围：
  - `AutoLedgerCore/Models/Transaction.swift`：`category`/`source` 改为 `String`，保留枚举-based init（向后兼容），新增字符串化 init（`categoryLabel:`/`sourceLabel:`），新增 `categoryEnum`/`sourceEnum`/`categoryTitle`/`sourceTitle` 计算属性。
  - `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`：加载时去掉枚举 guard（不再因自定义值跳过行）；bind/update 去掉 `.rawValue`。
  - `AutoLedgerCore/Models/MonthlySnapshot.swift`：groupBy 改为 `\.categoryEnum`（自定义分类归入"其他"支出分布）。
  - `AutoLedger/Features/Ledger/TransactionEditorView.swift`：state 改为 `String`，添加 `@EnvironmentObject store`，Picker 在内置 case 后追加 `store.customCategories`/`store.customSources`，tag 统一为 String。
  - `AutoLedger/Features/Ledger/LedgerView.swift`、`DeletedTransactionsView.swift`、`Features/Settings/DebugView.swift`、`Domain/Services/FeedbackBundleBuilder.swift`：图标/颜色改为 `categoryEnum.*`，文字改为 `categoryTitle`/`sourceTitle`。
  - `AutoLedger/App/LedgerStore.swift`：`updateTransaction` 仅对内置枚举类别触发 `recordCategoryCorrection`。
- 未改动范围：`TransactionCategory`/`ReceiptSource` 枚举本身不变；`CategoryManagementView`/`SourceManagementView` 管理 UI 不变；UserDefaults 持久化配置不变。
- 完成内容：编辑器 Picker 已展示自定义分类/来源；选择后以字符串标签持久化到 SQLite；重新加载后不再因未知 rawValue 跳行；编译通过（修复了 ForEach ArraySlice 泛型推断和嵌套字符串插值两处 build 错误）。
- 未完成内容：月报对自定义分类的统计目前归入"其他"（设计暂定）。
- 测试情况：Xcode 编译通过；功能待真机验证。
- 风险与注意事项：历史数据均为内置 rawValue，升级后读取正常；新存入的自定义标签如同名内置分类 rawValue 会被误识别为内置——但 rawValue 均为英文（如 `dining`），与用户自定义中文标签冲突概率极低。
- 回滚方式：还原 Transaction.swift（改回枚举字段）及 7 处消费点；自定义标签行在旧版加载时仍会被跳过（guard 回滚后未知 rawValue = 空），需清理数据库中自定义标签行。
- 结论：本轮完成。
- 下一步建议：月报后续可按自定义分类单独聚合展示。

### ITER-021 微信代扣凭证（先购后付）+ 地铁全角CN￥商户误识别修复
- 日期：2026-04-13
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：① 微信代扣凭证（先购后付/先乘后付非滴滴场景）解析结果为"•五"等 OCR 噪声而非服务商名称；② 地铁乘车城市卡记录（天津互联互通等）OCR 输出 `CN￥3.60`（全角 ￥ U+FFE5），`isStandaloneAmount` 未识别为金额行，走 (B) 路径将金额文本作为内联站名，商户变为"地铁：CN￥3.60"。
- 改动范围：
  - `AutoLedgerCore/Services/ReceiptParser.swift`：① 新增 `parseWeChatDeductionVoucher(lines:)` 专用方法，检测"扣费凭证"页面，从"扣费内容"标签后提取服务名；新增 `bulletShortNoisePattern` 过滤 fallback 噪声行；`parse()` 商户链新增 `wechatDeductionMerchant`。② `isStandaloneAmount` 正则新增 `CN￥`（U+FFE5）分支。
- 未改动范围：其他解析路径不变；`parseDidiTrip` 不变。
- 完成内容：两项误识别场景修复；OfflineRegression 编译通过。
- 未完成内容：无。
- 测试情况：逻辑验证通过（调试记录回放）；真机验证待完成。
- 风险与注意事项：`parseWeChatDeductionVoucher` 与 `parseDidiTrip` Case C 均检测"扣费凭证"，`parse()` 中 `wechatDeductionMerchant` 在 `didiMerchant` 之后调用，滴滴场景已被前一步拦截，不会误触。
- 回滚方式：移除 `parseWeChatDeductionVoucher` 方法及 `parse()` 中的 `wechatDeductionMerchant` 调用；还原 `isStandaloneAmount` 正则（删除 `CN￥` 分支）。
- 结论：本轮完成。
- 下一步建议：持续积累微信/城市卡等场景调试记录回归用例。

### ITER-020 滴滴出行微信支付扣费凭证商户误识别修复
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复滴滴出行"先乘车后付款"微信支付扣费凭证截图商户误识别问题——OCR 文本无"行程已"和"已支付"关键词，`parseDidiTrip` 两条已有分支均未命中，商户回退为"微信支付"，分类为"其他"；实际应为商户"滴滴出行"、分类"出行"。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-13 05:57:42
  记录时间：2026-04-12 17:44:18
  阶段：已入账
  来源：微信支付
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：微信支付 ¥24.90
  解析结果：
  - 商户：微信支付
  - 金额：¥24.90
  - 分类：其他
  - 时间：2026-04-12 17:44:18
  - 摘要：已记好：微信支付 ¥24.90
  当前账单（用户修改后）：
  - 商户：滴滴出行
  - 金额：¥24.90
  - 分类：出行
  - 时间：2026-04-12 17:44:18
  - 备注：快捷指令自动记账
  OCR 文本：
  17:44
  69
  微信支付
  收支
  查看明细
  日报设置
  17:41
  • 滴滴出行
  扣费凭证
  通过Example Bank Card (1234)扣款
  ¥24.90
  按时支付，记入微信支付分记录
  扣费服务
  扣费内容
  滴滴出行
  先乘车后付款
  查看订单详情
  我的账单
  支付服务
  摇优惠
  ```
- 根因分析：微信支付"扣费凭证"卡片（先乘车后付款场景）的 OCR 文本无"行程已"（无行程结束页）、无"已支付"（无通知推送），`parseDidiTrip` Case A / Case B 均未命中，商户最终回退到 `fallbackMerchant`（来源标题"微信支付"）。
- 改动范围：
  - `AutoLedgerCore/Services/ReceiptParser.swift`：`parseDidiTrip` 新增 Case C，检测 `hasDidi && hasDeductionVoucher`（"扣费凭证"），命中时返回"滴滴出行"。
  - `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例"滴滴出行微信扣费凭证截图"，使用本次调试 OCR 原文。
  - `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言（merchant=滴滴出行, amount=24.90, category=.transport）。
  - `CHANGELOG.md`：新增本次修复条目。
- 未改动范围：SmartReceiptParser、LedgerStore、AppFormatters、UI 层均未改动；现有 Case A / Case B 逻辑不变。
- 完成内容：`parseDidiTrip` Case C 已添加；新样例已加入 SampleReceiptProvider 和 OfflineRegression；本地逻辑验证通过（swift 脚本确认 hasDidi=true, hasDeductionVoucher=true, result=滴滴出行, amount=24.90）。
- 未完成内容：无。
- 测试情况：运行 `/tmp/test_didi.swift` 脚本验证 Case C 逻辑，PASS；`swift build`（AutoLedgerCore）ReceiptParser.swift 和 SampleReceiptProvider.swift 均编译通过（AppIntents 缺失错误为 iOS 专属模块在 Linux 环境的既有问题，与本次改动无关）。
- 风险与注意事项：Case C 依赖"扣费凭证"字样，若微信更新卡片文案需重新添加关键词；当前三条 Case 互斥分支，不会相互影响。
- 回滚方式：移除 `parseDidiTrip` Case C 代码块（4 行）；删除 SampleReceiptProvider 和 OfflineRegression 中"滴滴出行微信扣费凭证截图"相关条目。
- 结论：本轮完成，滴滴出行"先乘车后付款"微信扣费凭证场景已正确识别。
- 下一步建议：继续积累真机回归用例，关注其他先乘车后付款场景变体。

### ITER-019 滴滴出行结束订单页金额误识别修复
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复滴滴出行结束订单页（优享出租车）金额误识别——OCR 文本顶部有无关数字"71"（评价人数），通用 extractAmount 全文兜底先命中该数字，导致车费误识别为 ¥71.00；实际车费 ¥45.00 出现在"费用明细"前，且因 OCR 将"¥"误读为"4"，呈现为"445"。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-12 17:07:33
  记录时间：2026-04-12 15:59:30
  阶段：已入账
  来源：手动录入
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：滴滴出行 ¥71.00
  解析结果：
  - 商户：滴滴出行
  - 金额：¥71.00
  - 分类：其他
  - 时间：2026-04-12 15:59:30
  - 摘要：已记好：滴滴出行 ¥71.00
  当前账单（用户修改后）：
  - 商户：滴滴出行
  - 金额：¥45.00
  - 分类：出行
  - 时间：2026-04-12 15:59:29
  - 备注：快捷指令自动记账
  OCR 文本：
  15:59
  ＜ 行程已给束
  71
  您对我的服务满意吗？
  示例司机 EX-0002 4.5分
  匿名
  发红包
  很糟糕
  一般般
  太赞了
  445
  9.0L
  费用明细〉
  起
  终
  收藏路线
  优享出租车|全程12.3公里 23分钟
  • 15:30 Example Resort Gate
  • 15:54 Example Hotel（步行导航＞
  里程值 +12.3
  平台提供信息技术服务，运输服务提供方为个体出租车
  匿名反馈
  69.6万+人参与中
  本次接驾车辆的车牌号与订单显示是否一致？
  不一致
  一致
  6
  呼叫返程
  联系客服 呼叫司机 功能反馈
  再来一单
  ```
- 对应保存账单条目数据（用户手动修正，可作为预期结果参考）：
  - 商户：滴滴出行
  - 金额：¥45.00
  - 分类：出行
  - 时间：2026-04-12 15:59:29
  - 来源：手动录入
- 改动范围：
  - 修改 `AutoLedgerCore/Services/ReceiptParser.swift`：
    - 新增私有方法 `extractDidiTripAmount(lines:)`：仅在含"行程已"的行程结束页触发；定位"费用明细"行，在其前 5 行内逆序搜索车费；优先匹配 ¥/￥ 前缀金额（标准格式），其次检测 OCR 将"¥"误读为"4"的情形（`^4([1-9][0-9]{1,2}(?:\.[0-9]{1,2})?)$`，如"445"→修正为 45.00；要求修正后金额 ≥10 元，避免误伤极小金额），避免误伤含中文/字母的非金额行（如"9.0L"）。
    - 重构 `parse()`：提前构建 `cleanedLines`，在 `extractAmount` 之前优先尝试 `extractDidiTripAmount`，若有结果则直接使用，否则回退到通用提取器。
  - 修改 `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例 "滴滴出行优享出租车截图"，使用本次调试 OCR 原文。
  - 修改 `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言（merchant=滴滴出行, amount=45.00, category=.transport）。
  - 修改 `CHANGELOG.md`：新增本次修复条目。
- 未改动范围：数据层 schema、UI 层、订阅识别、去重逻辑、通知截图解析路径均无改动。
- 完成内容：
  - 新样本"滴滴出行优享出租车截图"解析正确：merchant="滴滴出行"，amount=45.00，category=transport。
  - 旧样本"滴滴出行结束订单截图"回归通过：amount 仍为 19.60。
  - 旧样本"滴滴出行通知截图"回归通过：amount 仍为 9.70（通知截图无"费用明细"，走通用 extractAmount）。
  - 微信/支付宝等非滴滴样本回归通过（parse() 重构未引入副作用）。
- 未完成内容：完整离线回归脚本在 macOS/Xcode 环境执行；真机验证待补充。
- 测试情况：手动 `swiftc` 单测验证 9 项 PASS（新样本/旧样本/通知截图/微信各项）。
- 风险与注意事项：
  - "4XX" OCR artifact 修正模式：若真实车费为 4XX 元且 OCR 恰好丢失"¥"符号（输出纯数字"4XX"），会被误修正为 XX 元。但实际上 DiDi 界面有"¥"前缀，OCR 能识别时优先走步骤 1（¥ 前缀匹配），仅在 ¥ 丢失时才触发步骤 2，实际误触发概率极低。
  - `extractDidiTripAmount` 只在含"行程已"时触发，不影响其他来源的解析。
- 回滚方式：删除 `extractDidiTripAmount` 方法，将 `parse()` 中的 cleanedLines 构建和专用金额提取逻辑还原为原始结构，删除 SampleReceiptProvider 中的新样例，还原 OfflineRegression 中对应断言。
- 结论：修复完成，滴滴出行结束订单页金额识别问题已修复，同时向后兼容原有所有回归样本。
- 下一步建议：真机以本次 OCR 文本重新触发快捷指令，验证商户 = "滴滴出行"、金额 = ¥45.00、分类 = "出行"。

### ITER-018 账本管理三改进（最近删除 + 手动新增账单 + 去重排除已删除记录）
- 日期：2026-04-12
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / Bugfix
- 目标：① 修复已删除账单被去重逻辑误判为重复导入的 bug（删除后再次扫描同截图应允许入账）；② 新增"最近删除"功能，会话内支持恢复已删除账单；③ 账本右上角新增手动录入入口，支持不依赖截图的手动记账。
- 改动范围：
  - `AutoLedger/App/LedgerStore.swift`：`hasDuplicate` OCR Jaccard 相似度检查排除已删除账单对应的 debugRecord；新增 `deletedTransactions: [Transaction]` Published 属性、`restoreTransaction`/`permanentlyDeleteTransaction` 方法；新增 `addTransaction` 方法（手动录入持久化）。
  - `AutoLedger/Features/Ledger/LedgerView.swift`：工具栏新增"+"按钮，打开 `TransactionEditorView`（新增模式）。
  - `AutoLedger/Features/Ledger/TransactionEditorView.swift`：新增 `isNew` 参数支持"新增"/"编辑"双模式。
  - `AutoLedger/Features/Ledger/DeletedTransactionsView.swift`（新增文件）：最近删除列表，左滑恢复 / 右滑彻底删除。
- 未改动范围：SQLite 删除逻辑不变（硬删）；恢复为会话内内存恢复，不持久化到 SQLite。
- 完成内容：三项功能均已实现并编译通过；去重排除已删除记录验证通过。
- 未完成内容：无。
- 测试情况：逻辑验证通过；真机验证待完成。
- 风险与注意事项：`deletedTransactions` 为会话内变量，App 退出后清空；手动录入的来源默认为"手动录入"，分类默认为"其他"，依赖用户在编辑器中调整。
- 回滚方式：还原 `LedgerStore` 三处改动；移除 `DeletedTransactionsView.swift`；还原 `LedgerView` 工具栏按钮；还原 `TransactionEditorView` `isNew` 参数。
- 结论：本轮完成。
- 下一步建议：后续可考虑将删除记录持久化到 SQLite 软删除列（`deleted_at`），支持跨会话恢复。

### ITER-017A 地铁储值卡CN¥嵌入金额修复
- 日期：2026-04-11
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：Bugfix / 规则
- 目标：修复真机调试发现的地铁储值卡通知解析错误——"地铁：CN¥7.00"（金额嵌入冒号后）被错误当作站点文本，导致商户输出为 "地铁：CN¥7.00"、分类误判为"其他"；同时修复 "ExampleAirport - ExampleEastStation" 格式（空格+连字符分隔）未能正确规范化为 "ExampleAirport → ExampleEastStation" 的问题。
- 触发调试记录（原始，未修正，完整内容）：
  ```
  AutoLedger 单条测试记录
  导出时间：2026-04-11 14:50:30
  记录时间：2026-04-11 14:47:11
  阶段：已入账
  来源：手动录入
  图片来源：快捷指令
  解析模式：纯规则解析
  结论：已记好：地铁：CN¥7.00 ¥7.00
  解析结果：
  - 商户：地铁：CN¥7.00
  - 金额：¥7.00
  - 分类：其他
  - 时间：2026-04-11 14:47:11
  - 摘要：已记好：地铁：CN¥7.00 ¥7.00
  OCR 文本：
  14:47
  63
  现在
  支
  消费成功通知
  你的储值消费成功，查看详情>
  天津互联互通城市卡
  地铁：CN¥7.00
  ExampleAirport - ExampleEastStation
  你的新余额为 CN¥60.75。
  现在
  通知中心
  X
  周六2
  11
  乘坐列车G000次Example East Station..•30分钟后
  交通严重拥堵。经德胜快速路前往
  Example East Station需要19分钟。
  3
  小红书
  PLUS抽签购权益过期提醒
  1分钟前
  您有一份原价飞飞天茅台的抽签权益
  即将过期，请尽快查看，若已参与
  请忽略>
  收获一个新的赞
  【陈槿琪】点赞了你的弹幕，快来看
  看吧>
  1分钟前
  小鸡毛烫不烫啊
  160
  下雨
  20° ＄15°
  可
  ```
- 对应保存账单条目数据（与调试记录生成数据不一致，说明用户已手动修正，可作为预期结果参考）：
  - 商户：地铁：ExampleAirport → ExampleEastStation
  - 金额：¥7.00
  - 分类：出行
  - 时间：2026-04-11 14:47:11
  - 来源：手动录入
- 改动范围：
  - 修改 `AutoLedgerCore/Services/ReceiptParser.swift`：地铁/公交储值卡解析块新增版式 (C)——新增私有方法 `isStandaloneAmount(_:)` 以锚定正则判断整行是否为独立金额（`CN¥`/`¥`/`￥`/`CNY`/`RMB` 前缀 + 数字，避免含数字的站名如"T2航站楼"、"3号线"误判）；当冒号后内联部分是独立金额时（`isStandaloneAmount` 返回 true）回退到 (A)/(C) 路径，向后查找第一个非金额行作为站点行；站名规范化时对各部分执行 `.trimmingCharacters(in: hyphenSet)` 以去掉空格连字符分隔符带来的前导"-"。
  - 修改 `AutoLedgerCore/Services/SampleReceiptProvider.swift`：新增样例 "互联互通城市卡CN¥嵌入格式截图"，使用本次调试 OCR 原文（含通知栏噪声）。
  - 修改 `scripts/OfflineRegression.swift`：为新样例补充 expectedMerchants / expectedAmounts / expectedCategories 断言。
- 未改动范围：数据层 schema、UI 层、订阅识别、去重逻辑均无改动。
- 完成内容：
  - 版式 (C)（`地铁：CN¥X.XX` 单行）现可正确识别，商户输出 "地铁：ExampleAirport → ExampleEastStation"。
  - 版式 (A)（独立 `地铁：` 行 + 金额行 + 站点行）回归通过，输出仍为 "地铁：Example Station A → Example Station B"。
  - 版式 (B)（`地铁：站A 站B` 同行）回归通过，输出不变。
  - 站名含空格+连字符分隔符（如 " -ExampleEastStation"）现可正确规范化，前导"-"被去除。
  - 离线回归（Swift 逻辑单测）5 项全 PASS。
- 未完成内容：完整离线回归脚本（`run_offline_regression.sh`）需在 macOS/Xcode 环境执行；真机验证待补充。
- 测试情况：手动 `swiftc` 单测验证 5 项 PASS（版式 A/B/C、amountCandidate 对 CN¥ 的识别、站名连字符清洗）。
- 风险与注意事项：`.trimmingCharacters(in: "-")` 仅去除站名组件两端的"-"，不影响站名中间的连字符（如"CBD-East"类名称）；若真实场景出现站名本身以"-"开头，可进一步细化为仅去前导"-"。
- 回滚方式：还原 `ReceiptParser.swift` 中地铁块的 `if !inlinePart.isEmpty` 判断与 `map` 清洗步骤，删除 `SampleReceiptProvider.swift` 中的新样例，还原 `OfflineRegression.swift` 中对应断言。
- 结论：修复完成，地铁解析规则覆盖三种常见 OCR 版式。
- 下一步建议：真机以本次 OCR 文本重新触发快捷指令，验证商户 = "地铁：ExampleAirport → ExampleEastStation"、分类 = "出行"。

### ITER-017 去重增强 + 回归基线 + 发布门禁
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 文档
- 目标：去重策略从「60s 窗口 + 同商户同金额」升级为增加 OCR 文本 Jaccard 相似度比对（> 0.8 视为同一来源）；创建 v1.1.0 回归基线与发布门禁草稿。
- 改动范围：
  - 新增 `AutoLedgerCore/Utils/TextSimilarity.swift`（字符级 bigram Jaccard 相似度函数，public，供主 App + Extensions 共用）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`hasDuplicate` 增加 rawText 参数，原有 60s 窗口匹配后追加 Jaccard 比对 debugRecords 最近 30 条 persisted 记录 rawText，相似度 > 0.8 判定重复）
  - 修改 `AutoLedger/Domain/Services/QuickLedgerIntent.swift`（去重逻辑增加 OCR Jaccard 检查，通过 `loadDebugEvents()` 获取历史 rawText）
  - 修改 `ShareExtension/ShareViewController.swift`（同 QuickLedgerIntent 的 OCR Jaccard 检查）
  - 修改 `scripts/OfflineRegression.swift`（新增 3 条测试：Jaccard 相似文本去重、相似度 > 0.8 验证、不相关文本 < 0.5 验证）
  - 新增 `versions/v1.1.0-regression-baseline.md`（9 大类回归矩阵，覆盖主路径/多渠道/解析/去重/订阅/分类/反馈/服务端自动化）
  - 新增 `versions/v1.1.0-RELEASE(draft).md`（发布前检查 + 门禁判定 + 版本亮点 + 回滚方案 + 发布后观察）
- 未改动范围：数据层 schema 无改动；UI 层无改动。
- 完成内容：
  - `TextSimilarity.jaccard(_:_:)`：清洗空白/标点 → 字符级 bigram 集合 → Jaccard 系数（0.0–1.0），两空串返回 1.0，单字符退化为字符集
  - 三处去重站点全部升级：LedgerStore.hasDuplicate + QuickLedgerIntent + ShareViewController
  - 去重拦截消息增强：区分"同日同金额"与"OCR 文本高度相似"两类原因
  - 离线回归新增 Jaccard 测试覆盖
  - v1.1.0 回归基线（含 PENDING 待真机验证条目）
  - v1.1.0 发布门禁草稿（⏳ 待真机验证判定）
- 未完成内容：回归基线中 PENDING 条目需真机端到端验证。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：Jaccard bigram 对极短文本（<10 字符）可能产生偏高相似度；阈值 0.8 需在真实数据上确认合理性。
- 回滚方式：删除 `TextSimilarity.swift`，还原 `LedgerStore.swift`、`QuickLedgerIntent.swift`、`ShareViewController.swift` 中的 Jaccard 增量，还原 `OfflineRegression.swift` 中的新增测试。
- 结论：Phase 4 完成。v1.1.0 全 6 轮迭代（ITER-012~017）均已完成，待真机验证后可发布。
- 下一步建议：分类提交推送 → 真机验证回归基线 → 判定门禁 → 发布 TestFlight。

### ITER-016 用户反馈 C 层（服务端邮件→Issue 自动化）
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 3
- 类型：基础设施 / DevOps
- 目标：打通 App 端邮件反馈 → Gmail → GitHub Issue 自动化链路，实现反馈闭环。
- 改动范围：
  - 新增 `tools/feedback/email_to_issue.py`（~350 行）：Gmail IMAP 拉取未读邮件 → 解析邮件标题（正则提取 level/platform/version/issue_type/summary）→ 解析 AUTOLEDGER_FEEDBACK_META 区块 → 解压 zip bundle（提取 issue_bundle.json/summary.txt/metadata.json/trace.log/redacted_ocr_context.txt，故意跳过 full_ocr_text.txt 和原始截图）→ 服务端二次正则脱敏（邮箱→[EMAIL_MASKED]、手机号→[PHONE_MASKED]、长数字串→[LONG_NUMBER_MASKED]）→ GitHub REST API 创建 Issue（Markdown 格式，含 Environment 表+User Report+Debug Info+Trace Log+Redacted OCR Context+Privacy 声明）→ feedback_id 幂等去重（GitHub Issue search）→ 标记邮件已读
  - 新增 `tools/feedback/requirements.txt`（纯标准库，无外部依赖）
  - 新增 `tools/feedback/test_email_to_issue.py`（6 项 smoke tests：subject 解析、meta 解析、脱敏、labels、坏 zip、有效 zip）
  - 新增 `.github/workflows/feedback-email-to-issue.yml`（每 15 分钟定时触发 + workflow_dispatch 手动触发 + dry_run 开关 + sparse-checkout）
- 未改动范围：iOS 客户端代码无改动。
- 前置条件（已由用户完成）：
  - Cloudflare Email Routing（`support@darkrio326.top` → Gmail）— 已测试通过
  - Gmail App Password — 已生成
  - GitHub Fine-grained PAT（Issues: Read and write）— 已获取
  - GitHub repo Secrets 已配置：`GMAIL_USERNAME`、`GMAIL_APP_PASSWORD`、`GH_PAT_TOKEN`
- 完成内容：
  - `email_to_issue.py` 核心功能：邮件拉取、标题解析、meta 解析、bundle 解压、二次脱敏、Issue 创建、幂等去重、已读标记
  - Issue 自动打 5 个 label：`feedback`、`source/email`、`level/Lx`、`type/xxx`、`status/new`
  - Issue body 结构化 Markdown：Environment 表 + User Report + Debug Info + Trace Log（截断 3000 字符）+ Redacted OCR Context（截断 2000 字符）+ Privacy 声明
  - DRY_RUN 模式支持（不创建 Issue、不标记已读，仅日志输出）
  - feedback_id fallback：无 feedback_id 时使用 Message-ID SHA-256 前 12 位
  - GitHub Actions workflow：15 分钟定时 + 手动 + dry_run 参数
- 未完成内容：无。
- 测试情况：本地 smoke tests 全部通过（parse_subject、parse_meta_block、redact、build_labels、extract_bundle）。端到端验证需推送到 GitHub 后触发 Actions。
- 风险与注意事项：
  - Gmail IMAP 连接可能因网络或凭证问题失败，Actions 日志可排查
  - GitHub search API 有 rate limit（30 req/min for authenticated），高频邮件场景下去重查询可能受限
  - Issue body 中 trace / OCR context 有截断（3000/2000 字符），极长日志可能丢失尾部
  - Secret 名称用 `GH_PAT_TOKEN` 而非 `GITHUB_TOKEN`（GitHub Actions 不允许 GITHUB_ 前缀的自定义 secret）
- 回滚方式：删除 `tools/feedback/` 目录和 `.github/workflows/feedback-email-to-issue.yml`。
- 结论：Phase 3 全部完成（A 层 App 端 + B 层邮件协议 + C 层服务端自动 Issue）。
- 下一步建议：ITER-017 Phase 4（去重增强 + 回归基线 + 发布门禁）。推送代码到 GitHub 后手动触发一次 workflow（DRY_RUN=1）验证端到端。

### ITER-015 用户反馈 A+B 层
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 3
- 类型：能力增强 / UI
- 目标：实现 App 端用户反馈全链路——三级日志分级（L1 脱敏 / L2 增强调试 / L3 完整诊断）、反馈 bundle 组装、邮件发送（含 MFMailComposeViewController + 降级策略）、发送前预览、DebugView 隐藏入口 + 开发者模式内容升级。
- 改动范围：
  - 新增 `Domain/Enums/FeedbackLevel.swift`（L1/L2/L3 枚举，含 Comparable）
  - 新增 `Domain/Enums/FeedbackIssueType.swift`（14 种问题类型枚举）
  - 新增 `Domain/Services/FeedbackBundleBuilder.swift`（Feedback ID 生成、设备信息采集、分级 bundle 组装、正则脱敏、zip 压缩、邮件标题/正文模板生成）
  - 新增 `Domain/Services/FeedbackService.swift`（MFMailComposeViewController 封装 + 剪切板复制降级 + 系统分享降级）
  - 新增 `Features/Feedback/FeedbackComposerView.swift`（问题类型网格选择 + 反馈级别选择 + 描述表单 + L3 二次确认 + 截图开关 + 预览构建）
  - 新增 `Features/Feedback/FeedbackPreviewView.swift`（预览标题/正文/附件包内容 + 确认发送按钮）
  - 修改 `Features/Settings/SettingsView.swift`（新增"问题反馈"入口 sheet；DebugView 入口隐藏为多次点击版本号解锁；新增 `versionTapCount`/`showDebugUnlocked`/`showFeedbackComposer` 状态变量）
  - 修改 `Features/Settings/DebugView.swift`（新增系统信息卡、App Group 容器文件浏览、SQLite 四表分页浏览、内存/磁盘使用概况、一键导出 L3 诊断包 + ShareSheet）
- 未改动范围：AutoLedgerCore 无改动；LedgerStore 无改动。
- 完成内容：
  - `FeedbackBundleBuilder`：Feedback ID `AL-{vendorHash6}-{yyyyMMddHHmmss}-{seq}` 全局唯一；metadata.json / summary.txt / issue_bundle.json 均按协议模板生成；L2+ 追加 trace.log / redacted_ocr_context.txt；L3 追加 full_ocr_text.txt / attachments/screenshot.jpg
  - 脱敏：正则匹配 ¥金额、手机号、邮箱、银行卡号，替换为占位符；L3 不脱敏
  - `FeedbackService`：MFMailComposeViewController 发送邮件（含 zip 附件）；无邮件账户时降级为剪切板复制或系统分享 zip
  - `FeedbackComposerView`：14 种问题类型 LazyVGrid 网格选择；L1/L2/L3 级别选择（L3 需二次确认）；描述/预期/实际/复现/补充 表单；L3 可选附带截图
  - `FeedbackPreviewView`：显示邮件标题、正文全文、zip 文件名/大小、bundle 内文件列表
  - DebugView 隐藏入口：版本号 infoCard 加 onTapGesture，连续点击 5 次后显示"调试与回归"入口
  - DebugView 内容升级：系统信息（版本/Build/iOS/设备/内存/磁盘）、App Group 容器文件列表、SQLite 数据 Segmented Picker 浏览（交易/订阅/分类学习/调试事件）、toolbar 一键导出诊断包
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：`MFMailComposeViewController` 在模拟器上不可用（`canSendMail()` 返回 false），需真机测试邮件发送；zip 附件大小受邮件服务商限制（通常 25MB）；L3 诊断包含完整 OCR 文本，用户需二次确认。
- 回滚方式：删除 `FeedbackLevel.swift`、`FeedbackIssueType.swift`、`FeedbackBundleBuilder.swift`、`FeedbackService.swift`、`FeedbackComposerView.swift`、`FeedbackPreviewView.swift`，还原 `SettingsView.swift` 和 `DebugView.swift` 中的 ITER-015 增量。
- 结论：Phase 3 A+B 层完成（App 端反馈全链路 + 邮件/bundle 协议）。
- 下一步建议：ITER-016 Phase 3 C 层（服务端邮件→Issue 自动处理）。

### ITER-014 分类学习
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 2
- 类型：能力增强 / UI
- 目标：实现分类学习——用户在账本中修改交易分类后，系统自动记录商户→分类偏好，后续导入同一商户时自动应用修正分类；提供管理界面供用户查看与删除已学习记录。
- 改动范围：
  - 修改 `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`（新增 `category_corrections` 表建表 + `loadCategoryCorrections` / `saveCategoryCorrection` / `deleteCategoryCorrection` CRUD）
  - 修改 `AutoLedgerCore/Enums/TransactionCategory.swift`（`infer(from:corrections:)` 增加可选 `corrections` 参数，修正历史优先于关键词规则）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`categoryCorrections` Published 属性、init 加载、`recordCategoryCorrection` / `deleteCategoryCorrection` 方法、`updateTransaction` 自动检测分类变更、`persistReceipt` 两条路径均优先使用修正分类、`refreshFromStore` 同步修正数据）
  - 新增 `Features/Settings/CategoryLearningView.swift`（已学习列表 + 空态引导 + contextMenu 删除）
  - 修改 `Features/Settings/SettingsView.swift`（新增"分类学习"入口 NavigationLink）
- 未改动范围：`ReceiptParser.swift` 无需改动（`infer()` 默认 corrections 为空字典）；交易编辑视图无需改动（已有的 onSave → `updateTransaction` 链路自动触发检测）。
- 完成内容：
  - `category_corrections` 表：merchant TEXT PRIMARY KEY + category TEXT NOT NULL + updated_at TEXT NOT NULL，UPSERT via ON CONFLICT(merchant)
  - `TransactionCategory.infer(from:corrections:)` 先遍历 corrections 字典做 `localizedCaseInsensitiveContains` 匹配，命中则直接返回；未命中则走原有关键词规则
  - `LedgerStore.updateTransaction` 比较改动前后 category，不同则 `recordCategoryCorrection`
  - `persistReceipt` alias 路径 + 非 alias 路径均检查 corrections
  - `CategoryLearningView`：按商户名排序，每项显示商户→分类 icon + 文字，contextMenu 长按删除，空态 `brain.head.profile` 引导
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：`localizedCaseInsensitiveContains` 匹配可能存在模糊匹配（如"星巴克"可匹配"星巴克臻选"），但对于分类学习场景这是预期行为。
- 回滚方式：删除 `CategoryLearningView.swift`，还原 `SQLiteTransactionStore.swift`（移除建表 SQL 和 CRUD）、`TransactionCategory.swift`（移除 corrections 参数）、`LedgerStore.swift`（移除 categoryCorrections 相关代码）、`SettingsView.swift`（移除分类学习入口）。
- 结论：Phase 2 完成（分类学习全链路：数据层→服务层→自动检测→导入应用→管理UI）。
- 下一步建议：ITER-015 Phase 3 用户反馈（A+B 层）。

### ITER-013 扣费提醒
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 1
- 类型：能力增强 / UI
- 目标：实现订阅扣费提醒 UI 层——订阅列表管理、首页即将扣费卡片、本地通知提醒、设置页开关。
- 改动范围：
  - 新增 `Features/Settings/SubscriptionListView.swift`（订阅列表视图：即将扣费高亮、全部订阅列表、预估月均费、空状态引导、长按删除）
  - 新增 `Domain/Services/NotificationService.swift`（`UNUserNotificationCenter` 本地通知，扣费前 1 天提醒，按 `subscriptionReminder` 开关控制）
  - 修改 `Features/Inbox/InboxView.swift`（新增 `upcomingSubscriptions` 计算属性 + `upcomingChargeCard` 卡片，hero 下方展示未来 7 天即将扣费的订阅）
  - 修改 `Features/Settings/SettingsView.swift`（新增"订阅管理" NavigationLink + "订阅扣费提醒" toggleCard，版本信息卡更新至 `v1.1.0-dev`）
  - 修改 `App/AutoLedgerApp.swift`（`UserDefaults.register` 注册 `subscriptionReminder` 默认 true；回前台时触发通知权限 + 调度通知）
  - 修改 `App/LedgerStore.swift`（`upsertSubscription` / `deleteSubscription` 后自动调用 `NotificationService.shared.scheduleUpcomingChargeReminders`）
- 未改动范围：AutoLedgerCore 数据层无改动（ITER-012 已完成）。
- 完成内容：
  - `SubscriptionListView`：分"即将扣费"和"全部订阅"两区，显示商户、方案名、周期、金额、下次扣费日；空状态有引导按钮；长按 contextMenu 删除
  - `upcomingChargeCard`：首页 hero 下方，展示未来 7 天内即将扣费的订阅，显示商户/金额/倒计时
  - `NotificationService`：单例，`requestPermissionIfNeeded` 仅在 `.notDetermined` 时请求权限；`scheduleUpcomingChargeReminders` 先清旧通知再按开关调度；提前 1 天 `UNCalendarNotificationTrigger`
  - 设置页 toggleCard `subscriptionReminder`（默认开启），关闭后不调度通知
  - 订阅增删后自动重新调度通知
- 未完成内容：无。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED。
- 风险与注意事项：通知权限需用户授权，首次触发时弹出系统对话框；通知时间精度为分钟级别。
- 回滚方式：删除 `SubscriptionListView.swift` / `NotificationService.swift`，还原 `InboxView.swift`、`SettingsView.swift`、`AutoLedgerApp.swift`、`LedgerStore.swift` 中的 ITER-013 增量。
- 结论：Phase 1 完成（ITER-012 数据层 + ITER-013 UI 层）。
- 下一步建议：ITER-014 Phase 2 快捷指令增强。

### ITER-012 订阅识别引擎
- 日期：2026-04-10
- 所属版本：v1.1.0
- 所属阶段：Phase 1
- 类型：能力增强
- 目标：实现订阅识别引擎层——支持续期邮件截图导入、高置信自动续期判定、SQLite 持久化、订阅去重。
- 改动范围：
  - 新增 `AutoLedgerCore/Models/Subscription.swift`（`SubscriptionPeriod` 枚举 + `Subscription` 模型）
  - 新增 `AutoLedgerCore/Services/SubscriptionDetector.swift`（OCR 文本高置信检测 + 历史周期探测）
  - 修改 `AutoLedgerCore/Persistence/SQLiteTransactionStore.swift`（新增 `subscriptions` 表建表 + CRUD 方法）
  - 修改 `AutoLedger/App/LedgerStore.swift`（`subscriptions` Published 属性 + `upsertSubscription` + `deleteSubscription` + `detectAndUpsertSubscriptions` + 导入流高置信订阅优先路径）
- 未改动范围：UI 层（订阅列表、首页卡片、设置页开关）属于 ITER-013 范围。
- 完成内容：
  - `SubscriptionPeriod`：weekly/monthly/yearly，包含周期内日历计算下次费日期
  - `Subscription`：包含 merchant / planName / period / amount / lastChargedAt / nextChargedAt / createdAt，支持 `updated()` 更新日期
  - `SubscriptionDetector.detectFromText`：命中中文/英文"自动续期""订阅将以"等强特征时，提取金额/周期/商户/方案名/日期，返回 Subscription 草稿
  - `SubscriptionDetector.detectFromHistory`：按商户聚组，间隔变异系数<20%＋金额波动<5% 则判定为订阅
  - `subscriptions` SQLite 表：CREATE IF NOT EXISTS + `loadSubscriptions` / `saveSubscription` / `updateSubscription` / `deleteSubscription(id:)`
  - `LedgerStore.upsertSubscription`：同商户+同周期命中时更新，否则新增
  - `importRecognizedText` 内 Task 块新增订阅优先路径（高置信命中时设 `lastImportSummary` 提示并跳过交易解析）
- 未完成内容：订阅列表 UI / 首页即将扣费卡片 / 设置页订阅提醒开关（ITER-013 范围）。
- 测试情况：`xcodebuild build` BUILD SUCCEEDED；数据层逻辑待真机连同 ITER-013 UI 一起验证。
- 风险与注意事项：`Subscription` 与 `Combine.Subscription` 同名，在 `LedgerStore.swift` 顶部加入 `typealias Subscription = AutoLedgerCore.Subscription` 消歧义。
- 回滚方式：删除 `Subscription.swift` / `SubscriptionDetector.swift`，还原 `SQLiteTransactionStore.swift`（移除建表 SQL 和 CRUD 方法）和 `LedgerStore.swift` 改动；旧数据库中即便已创建 `subscriptions` 表也不影响已有数据（CREATE IF NOT EXISTS）。
- 结论：数据层完成，编译通过。ITER-013 进入 UI 层展现 + 本地通知。
- 下一步建议：ITER-013 订阅列表视图 + 首页即将扣费卡片 + 设置页提醒开关。

### ITER-011 移除预置样例数据 + 一键记账引导智能折叠
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 4（UX 优化）
- 类型：变更 / UI
- 目标：新安装后账本为空（不再预置样例数据）；首页一键记账引导卡片在已有快捷指令记录时自动折叠为摘要卡。
- 改动范围：`LedgerStore.swift`（`seedTransactions` 清空）；`InboxView.swift`（新增 `quickSetupCollapsed` / `hasShortcutEntries`、条件切换展示）；`CHANGELOG.md`。
- 未改动范围：解析器、持久化层、设置页均未改动。
- 完成内容：`seedTransactions = []`；`quickSetupCollapsed` 摘要卡显示已记录笔数，点击展开完整指引。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS。
- 风险与注意事项：已安装用户若存在旧样例数据，不受此改动影响（已在 SQLite 中持久化）。
- 回滚方式：恢复 `seedTransactions` 数组内容；移除 `quickSetupCollapsed`。
- 结论：本轮完成。
- 下一步建议：继续完善首页信息密度优化。

### ITER-010 商户别名映射 + os_log 解析诊断
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（功能增强）
- 类型：能力增强 / 调试
- 目标：支持商户名别名映射（如"广州骑安科技有限公司 → 青桔单车"），并在 SmartReceiptParser 和 LedgerStore 关键阶段添加 os_log 日志。
- 改动范围：`LedgerStore.swift`（`merchantAliases`、`resolveMerchant`、`saveMerchantAliases`、os_log Logger）；新增 `MerchantAliasView.swift`；`SettingsView.swift`（新增商户别名入口）；`SmartReceiptParser.swift`（os_log Logger）；`CHANGELOG.md`。
- 未改动范围：ReceiptParser 规则层、SQLite 持久化层、AppFormatters 均未改动。
- 完成内容：别名映射存储在 UserDefaults，`persistReceipt` 入账前自动替换并重新推断分类；Logger 输出规则/LLM 结果、别名映射触发到 Xcode Console。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS；真机验证 os_log 输出正常（确认 Foundation Models 在国行设备不可用，纯规则路径运行正常）。
- 风险与注意事项：商户别名仅存 UserDefaults，不随 iCloud 同步。
- 回滚方式：移除 `MerchantAliasView`、`LedgerStore` 别名相关代码、`SmartReceiptParser`/`LedgerStore` 的 Logger 调用。
- 结论：本轮完成，真机调试效率大幅提升。
- 下一步建议：持续积累真机回归用例，利用 os_log 快速定位解析偏差。

### ITER-009 微信支付详情页标签块解析 + 日期秒级支持
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（解析增强）
- 类型：Bugfix / 能力增强
- 目标：修复微信支付详情页 OCR 输出的标签块→值块分列结构无法正确解析的问题（商户误提为页面标题、时间回退为当前时间）。
- 改动范围：`AutoLedgerCore/Services/ReceiptParser.swift`（新增 `parseWeChatDetailBlock`、`extractDate` 增加可选秒段、`parse()` 增加 WeChat detail 优先级）；`AutoLedgerCore/Utils/AppFormatters.swift`（新增 `HH:mm:ss` 格式、Unicode 全角/NBSP 空格归一化）；`CHANGELOG.md`。
- 未改动范围：SmartReceiptParser、LedgerStore、SQLite、UI 层均未改动。
- 完成内容：`parseWeChatDetailBlock` 检测连续已知标签（当前状态/支付时间/商品/商户全称…），找到最长连续标签段后按偏移映射到值行，提取商户全称和支付时间；`extractDate` 正则增加 `(?::[0-9]{2})?`；`parseFlexibleDate` 增加秒级格式和空格归一化。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS；真机测试微信支付详情页截图，商户/时间/分类均正确提取。
- 风险与注意事项：标签块解析依赖标签连续性，若微信更新页面布局可能需要调整。
- 回滚方式：移除 `parseWeChatDetailBlock` 方法并回退 `parse()` 中的调用，恢复 `extractDate` 正则和 `parseFlexibleDate` 格式列表。
- 结论：本轮完成，微信支付详情页最常见布局已覆盖。
- 下一步建议：继续收集不同微信版本和支付场景的 OCR 输出，扩展标签识别列表。

### ITER-008 去重窗口缩小 + 支付宝 NFC 收据解析
- 日期：2026-04-10
- 所属版本：v1.0.0
- 所属阶段：Phase 3（Bugfix）
- 类型：Bugfix
- 目标：去重窗口从 5 分钟缩小到 60 秒，避免同商户同金额不同时间的交易被误判重复；修复支付宝 NFC 收据商户名提取失败的问题。
- 改动范围：`LedgerStore.swift`、`QuickLedgerIntent.swift`、`ShareViewController.swift`（去重窗口 300→60）；`AutoLedgerCore/Services/ReceiptParser.swift`（支付宝 NFC 公司名提取、跳过纯符号行、移除冗余 keyword）；`CHANGELOG.md`。
- 未改动范围：SmartReceiptParser、AppFormatters、UI 层均未改动。
- 完成内容：三处去重逻辑统一为 60 秒窗口；支付宝 NFC 收据可正确提取公司名称；移除 `商业有限` 冗余关键词（已被 `有限公司` 覆盖）。
- 未完成内容：无。
- 测试情况：`xcodebuild build` PASS。
- 风险与注意事项：60 秒窗口可能在极端场景（如连续在同一商户同金额消费）下误判，但概率极低。
- 回滚方式：将三处 `< 60` 改回 `< 300`；回退 ReceiptParser NFC 相关改动。
- 结论：本轮完成。
- 下一步建议：持续收集真机回归用例。

### ITER-007 v1.0.0 多渠道导入 + LLM 混合解析 + 真机调试
- 日期：2026-04-09
- 所属版本：v1.0.0
- 所属阶段：Phase 2–4（全链路）
- 类型：能力增强 / Bugfix / UI / 重构
- 目标：完成 v1.0.0 全部计划功能——多渠道导入（相机/剪切板/Share Extension/快捷指令/ControlWidget）、LLM 混合解析、App Intent 快捷指令、UI 增强，并在真机上完成端到端验证。
- 改动范围：（详见 CHANGELOG.md 2026-04-09 全部条目，此处概述）
  - 重构：抽出 `AutoLedgerCore` 本地 Swift Package，主 App/ShareExt/ControlWidget 共享
  - 新增：Share Extension、QuickLedgerIntent（AppIntent）、SmartReceiptParser（Foundation Models 混合解析）、ClipboardImportIntent、ControlWidgetExtension
  - 新增：相机拍照导入、剪切板导入、回前台自动读取剪切板
  - 新增：LedgerView 时间筛选、商户消费排名 Sheet、跨 Tab 导航
  - 新增：设置页重写（来源/分类管理）、ImportDebugRecord 图片来源追踪
  - 修复：20+ 项解析规则修正（金额优先级、商户名过滤、来源推断、App Store 收据、外卖订单等）
  - 修复：SQLite 迁移、相机权限、App 图标、pbxproj 清理
- 未改动范围：月报页核心逻辑未改动。
- 完成内容：v1.0.0 计划 Phase 2–4 全部功能交付，真机端到端验证通过。
- 未完成内容：v1.0.0 发布门禁文档尚未正式判定。
- 测试情况：`xcodebuild build` PASS；真机验证快捷指令→OCR→入账→返回文本全链路通过；Share Extension 分享图片入账通过；相机/剪切板导入通过；ControlWidget 控制中心触发通过。
- 风险与注意事项：Foundation Models 在国行设备不可用（Apple Intelligence 未上线），SmartReceiptParser 始终走纯规则路径。
- 回滚方式：回退到 v0.1.0 tag 即可。
- 结论：本轮完成，v1.0.0 全部核心功能已交付并通过真机验证。
- 下一步建议：持续收集真机回归用例，完成发布门禁判定。

### ITER-006 TestFlight 邀请链接获取流程文档
- 日期：2026-04-09
- 所属版本：v1.0.0
- 所属阶段：Phase 4（发布与分发）
- 类型：文档
- 目标：补充 TestFlight 分发流程文档，说明构建上传成功后如何获取并分享邀请测试链接（公开链接与指定邮件邀请两种方式）。
- 改动范围：新增 `process/testflight-distribution.md`；更新 `CHANGELOG.md`；更新 `process/iteration-log.md`。
- 未改动范围：未修改任何业务代码、Xcode 工程配置或构建脚本。
- 完成内容：文档已涵盖三种邀请方式（公开链接、指定邮件、README 徽章）、Beta App Review 注意事项，以及常见问题说明。
- 未完成内容：无。
- 测试情况：文档类变更，无需构建验证。
- 风险与注意事项：外部测试公开链接需先通过 Apple Beta App Review（约 1–2 工作日），内部测试无需审核但限 100 人且须为 App Store Connect 团队成员。
- 回滚方式：若文档内容有误，直接修改 `process/testflight-distribution.md` 即可，不影响代码。
- 结论：本轮完成，项目现在有了标准的 TestFlight 分发操作参考文档。
- 下一步建议：在 `README.md` 的 Quick Start 部分嵌入 TestFlight 公开链接，方便外部测试者一键安装。

### ITER-005E 无真机条件下的离线回归脚本
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：测试 / 工具 / 文档
- 目标：在无法进行真机测试的情况下，补一层可重复执行的离线回归脚本，用来验证样例解析、SQLite 读写和 LedgerStore 导入/去重流程。
- 改动范围：为 `SQLiteTransactionStore` 增加临时目录注入能力；新增 `scripts/OfflineRegression.swift` 与 `scripts/run_offline_regression.sh`；更新版本计划、回归基线、发布门禁和 CHANGELOG。
- 未改动范围：未修改真实截图导入主路径、OCR 识别逻辑、Debug 页 UI、账本编辑 UI，也未建立真机端到端人工回归。
- 完成内容：离线回归脚本已可直接在本机运行；样例解析、SQLite save/load/update、LedgerStore 首次 bootstrap、导入唯一样例以及重复跳过均通过；脚本结果可复用，后续无需真机即可重复执行。
- 未完成内容：真实支付截图的可追溯人工回归记录仍未补齐；最终发布门禁仍不能判定通过。
- 测试情况：执行 `./scripts/run_offline_regression.sh`，结果 PASS；脚本内部同时覆盖样例解析、SQLite 回归和 LedgerStore 导入/去重回归。
- 风险与注意事项：离线脚本只能替代开发机上的基础回归，不能替代真实截图端到端验证；若后续补到真机测试，应保留该脚本作为日常回归基线。
- 回滚方式：若离线脚本引入问题，可删除 `scripts/` 下的回归脚本并回退 `SQLiteTransactionStore` 的目录注入参数，主业务链路不受影响。
- 结论：本轮完成，AutoLedger 现在在没有真机的情况下也能持续验证解析与持久化链路。
- 下一步建议：如果真机仍不可用，继续基于离线脚本做样例扩展；一旦可用真机，再补 `ITER-005F` 的真实截图人工回归。

### ITER-005D 调试记录单条复制
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：让调试页支持按单条问题样例复制，避免每次都导出整页调试快照。
- 改动范围：更新 `DebugView`，为每条调试记录增加单独复制动作；更新版本计划、迭代日志和 CHANGELOG。
- 未改动范围：未修改 OCR、解析器、SQLite、账本编辑流程，也未改变整页复制能力。
- 完成内容：每条调试记录新增“拷贝这条”；复制内容会包含该条记录的时间、阶段、来源、结论、解析结果和 OCR 文本；仍保留右上角整页复制能力，适合不同回归场景。
- 未完成内容：真实截图人工回归记录仍待补齐；自动化测试仍未建立；复制结果暂不支持富文本或附件。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：单条复制导出的是当前卡片快照，适合人工记录；如果后续要支持批量筛选导出，可再单开一轮，不在本轮扩展。
- 回滚方式：若单条复制交互影响 Debug 页可读性，可回退 `DebugView` 中对应按钮和导出逻辑，保留整页复制。
- 结论：本轮完成，可疑样例已经可以按条目单独导出。
- 下一步建议：进入 `ITER-005F`，在可用真机上用真实截图回归并只复制异常样例沉淀到版本回归文档，再决定是否修正 `ReceiptParser`；若真机仍不可用，则继续保留离线脚本作为日常回归基线。

### ITER-005C 调试记录一键拷贝
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：让 Debug 页能直接导出当前测试快照，减少手工整理 OCR、解析和入账结果的成本。
- 改动范围：更新 `DebugView`，新增测试记录导出文本与剪贴板复制入口；扩展 `AppFormatters` 提供导出时间格式；更新版本计划、迭代日志和 CHANGELOG。
- 未改动范围：未修改 OCR 识别、解析规则、SQLite 仓库、账本编辑流程和调试记录的数据结构。
- 完成内容：Debug 页右上角新增“拷贝记录”；可将最近状态、解析结果、OCR 文本、最近调试记录和最近账单整合为可读文本后复制到系统剪贴板；复制后会给出提示，便于直接粘贴到回归文档。
- 未完成内容：真实截图的正式人工回归记录仍待沉淀；自动化测试仍未建立；导出结果目前仅支持拷贝，不含文件分享或结构化导出。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前导出格式是面向人工阅读的文本快照，不是稳定 API；如果后续要接 CSV/JSON 导出，应单独设计格式，避免破坏当前拷贝体验。
- 回滚方式：若拷贝功能影响 Debug 页稳定性，可回退 `DebugView` 的复制入口与导出文本逻辑，并恢复到仅查看状态的页面。
- 结论：本轮完成，真机回归后的测试记录已经可以直接复制到外部文档。
- 下一步建议：进入 `ITER-005D`，用真实截图连续回归并把复制出的记录沉淀到版本回归文档里，再决定是否要微调 `ReceiptParser`。

### ITER-005B 真机调试与回归面板
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：能力增强 / 调试 / UI
- 目标：增加一个面向真机调试的 Debug 页，把最近 OCR 原文、解析结果、导入状态和最近账单集中展示出来，方便持续拿真实截图回归。
- 改动范围：新增 `ImportDebugRecord` 与 `DebugView`；扩展 `LedgerStore` 记录最近 OCR/解析/导入调试状态；将 `InboxView` 的最近 OCR 文本改为使用共享状态；在 `SettingsView` 增加调试入口；更新版本文档与 CHANGELOG。
- 未改动范围：未修改 OCR 识别算法、`ReceiptParser` 抽取规则、SQLite 仓库结构、账本编辑流程和真实截图导入主路径。
- 完成内容：应用内已可查看最近 OCR 文本、最近解析结果、最近导入状态、最近调试记录和最近账单；真机调试时不需要切回 Xcode 就能对照导入链路结果；调试记录支持清空，便于分批回归。
- 未完成内容：真实微信/支付宝/App Store 截图的端到端人工回归记录仍待补齐；自动化测试仍未建立；是否需要继续修改 `ReceiptParser` 仍要以真实截图结果为准。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`，结果 PASS。
- 风险与注意事项：调试页展示的是运行时状态快照和最近记录，不替代正式测试结论；若后续需要导出调试数据，再单独增加导出能力，避免把调试页做成复杂子系统。
- 回滚方式：若调试页影响设置页或共享状态，可回退 `DebugView`、`ImportDebugRecord` 以及 `LedgerStore` 的调试字段，保留主导入链路不变。
- 结论：本轮完成，AutoLedger 已具备真机上观察 OCR→解析→入账链路的内置调试能力。
- 下一步建议：进入 `ITER-005C`，用真实截图在真机上连续回归并沉淀记录，再决定是否需要对 `ReceiptParser` 做小范围修正。

### ITER-1700 v1.6.0 第一版推进与 ASC 版本号更新
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：GOAL-1700
- 类型：版本推进 / 文档 / 发布配置
- 目标：将 `v1.6.0` 从规划草稿推进为第一版开发线，并把 App Store / ASC 对外版本推进到 `1.5.0`。
- 改动范围：更新全 target `MARKETING_VERSION`、`versions/v1.6.0-plan.md`、README Roadmap、CHANGELOG、迭代日志和版本读取兜底值。
- 未改动范围：未实现订阅管理、AI 订阅判断、学习缓存、tvOS / visionOS UI；未修改 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：工程版本号已统一到 `1.5.0`；`v1.6.0` 计划文档状态改为第一版推进中；`GOAL-1700` 标记完成；README / README.en Roadmap 同步 App Store 版本映射。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `xcodebuild -list -workspace AutoLedger/AutoLedger.xcworkspace`，结果 PASS。
- 风险与注意事项：本轮只推进版本号与计划，不代表 `v1.6.0` 功能完成；后续每个 GOAL 仍需独立构建、回归和真机 / 平台 smoke。
- 回滚方式：如需回退到上一条发布线，可将 `MARKETING_VERSION` 恢复为 `1.4.0`，并回退 README / v1.6.0 计划 / CHANGELOG / 迭代日志中的本轮状态记录。
- 结论：本轮完成，下一步可进入 `GOAL-1710` 订阅管理基础 CRUD。

### ITER-005A 发布收口前的最小回归证据补齐
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 4
- 类型：测试 / 文档 / 治理
- 目标：在不扩大代码改造范围的前提下，补齐当前版本最小可追溯回归证据，并更新发布门禁文档。
- 改动范围：更新 `versions/v0.1.0-plan.md`、`versions/v0.1.0-regression-baseline.md`、`versions/v0.1.0-RELEASE(draft).md`、`CHANGELOG.md`；新增本条迭代记录。
- 未改动范围：未修改 `ReceiptParser`、`OCRService`、SQLite 持久化实现、账本编辑流和页面结构，也未扩展任何新功能。
- 完成内容：对 3 份内置样例 OCR 文本完成解析回归，结果均能正确抽取金额、商户、时间与建议分类；对 `SQLiteTransactionStore` 完成最小 save/load/update round-trip 回归；再次完成 Debug 模拟器构建；将 `ITER-005` 拆分为 `ITER-005A` 与 `ITER-005B`，明确当前已验证证据与剩余阻断项。
- 未完成内容：仓库内仍缺少可追溯的真实支付截图样例资产，尚未形成真实截图端到端人工回归记录；自动化测试仍未建立；应用重启后的人工恢复验证未记录。
- 测试情况：执行样例解析回归，微信买菜截图 / 支付宝出行截图 / App Store 订阅截图均 PASS；执行 `SQLiteTransactionStore` save/load/update round-trip，结果 PASS；执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前结论建立在样例 OCR 文本和仓库级回归上，不能替代真实截图端到端验证；若后续真实截图回归暴露解析问题，只应做基于证据的小修，避免范围漂移。
- 回滚方式：若本轮文档收口判断有误，可回退本轮计划/回归/发布文档到 ITER-004 状态，并保留回归命令与结果记录，重新按真实截图样例证据修订结论。
- 结论：本轮完成，版本门禁从“模糊阻断”收口为“证据明确但仍未放行”的状态，`ReceiptParser` 在现有样例上暂不需要继续修改。
- 下一步建议：补齐真实微信/支付宝/App Store 截图的人工回归记录，完成 `ITER-005B`，再做最终发布判定。

### ITER-004 SQLite 持久化与账单修正
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 3
- 类型：能力增强 / 数据 / UI
- 目标：把当前账本从内存态升级为真实本地账本，并给用户一个可用的账单修正入口。
- 改动范围：新增 `TransactionStore` 协议与 `SQLiteTransactionStore`；让 `LedgerStore` 在启动时加载并引导种子数据到 SQLite，同时支持更新账单；账本页新增点击编辑弹层 `TransactionEditorView`；更新设置页和版本文档。
- 未改动范围：未建立自动化测试，也未完成应用重启后的人工回归记录和多支付样例识别准确率回归。
- 完成内容：交易数据已可落入本地 SQLite；导入新账单会持久化；账本页支持修正金额、分类和备注；月报继续消费同一份更新后的数据；构建验证通过。
- 未完成内容：发布级人工回归、`ReceiptParser` 规则继续精调和版本门禁收口仍待下一轮完成。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；SQLite 落盘与应用重启恢复未做人工终态回归。
- 风险与注意事项：当前持久化层已可用，但缺少自动化测试和应用重启验证记录；编辑仅开放金额、分类、备注，商户与时间仍保持只读。
- 回滚方式：若 SQLite 落盘导致异常，可暂时回退到 ITER-003 的内存账本链路，同时保留编辑 UI 与仓库代码分支以便继续修复。
- 结论：本轮完成，AutoLedger 已从“可识别”推进到“可本地保存、可修正”的 MVP 状态。
- 下一步建议：集中做发布级人工回归、真实样例规则精调和门禁收口。

### ITER-003 真实截图导入与 Vision OCR 接入
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 2
- 类型：能力增强 / UI
- 目标：将收件箱从样例导入升级为真实截图导入，接入 `PhotosPicker` 与 Vision OCR，并继续复用上一轮已经跑通的解析、入账、账本和月报链路。
- 改动范围：新增 `OCRService`；为 `InboxView` 增加真实截图选择入口、OCR 识别状态与最近 OCR 文本展示；扩展 `LedgerStore` 支持导入 OCR 文本；为 `ReceiptSource` 增加来源推断；更新设置页描述与版本文档。
- 未改动范围：未实现本地持久化、账单手动修正、自动化测试，也未完成多支付样例的人工识别准确率回归。
- 完成内容：真实截图已可从系统相册选择；OCR 文本可进入现有解析器并尝试入账；OCR 失败时保留样例导入作为降级路径；构建验证通过。
- 未完成内容：持久化、账单编辑、OCR 规则精调和发布级回归仍待下一轮继续。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS；真实支付截图人工回归未在本轮完成。
- 风险与注意事项：OCR 识别效果受截图质量和支付页面样式影响；当前 `ReceiptParser` 仍以规则抽取为主，对复杂版式的鲁棒性有限。
- 回滚方式：若真实 OCR 导入影响稳定性，可保留样例导入并暂时隐藏真实截图入口，回退到 ITER-002 已验证链路。
- 结论：本轮完成，AutoLedger 已具备真实截图导入和本地 OCR 能力。
- 下一步建议：优先完成本地持久化与账单修正，再补真实截图人工回归和发布门禁收口。

### ITER-002 MVP 壳层与样例导入闭环
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 1
- 类型：能力增强 / 文档 / UI
- 目标：将工程从占位首页推进为可运行的 MVP 壳层，先用样例 OCR 文本打通“导入→解析→入账→展示”主路径，并同步校准版本文档。
- 改动范围：新增 `LedgerStore`、交易/导入/月报模型、规则解析器、样例数据提供器、主题与格式化工具；实现收件箱、账本、月报、设置页面；更新 backlog、版本计划、回归基线、发布门禁和 CHANGELOG。
- 未改动范围：未接入 PhotosPicker、Vision OCR、SwiftData/SQLite、账单手动编辑和自动化测试。
- 完成内容：将首页升级为四标签结构；支持导入微信/支付宝/App Store 样例文本；完成规则解析、去重、入账和月度汇总展示；修正版本计划与当前工程脱节的问题；完成一次模拟器 Debug 构建验证。
- 未完成内容：真实截图导入与 OCR、本地持久化、账单修正和发布级测试仍待后续迭代。
- 测试情况：执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj -scheme AutoLedger -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build`，结果 PASS。
- 风险与注意事项：当前导入链路仍为样例演示，不能代表真实 OCR 效果；内存账本在应用重启后不会保留数据。
- 回滚方式：若本轮 UI 或数据流影响后续推进，可回退到仅保留 `HomeView` 占位页的初始工程状态；文档侧回退到 ITER-001 版本计划。
- 结论：本轮完成，项目已从文档启动阶段进入可演示的 iOS MVP 壳层阶段。
- 下一步建议：优先推进真实截图导入与 Vision OCR，其次补本地持久化和账单修正。

### ITER-001 初始化项目文档与架构
- 日期：2026-03-27
- 所属版本：v0.1.0
- 所属阶段：Phase 1
- 类型：文档 / 能力增强
- 目标：为 AutoLedger 项目搭建完整的文档目录结构，填充初始想法池和版本计划，并确定项目技术栈及目录结构。
- 改动范围：更新 `README.md`，创建项目简介；填充 `process/iteration-idea-backlog.md`；新增本条迭代日志；编写 `versions/vX.Y.Z-plan.md`、`vX.Y.Z-regression-baseline.md`、`vX.Y.Z-RELEASE.md` 初稿；更新 `CHANGELOG.md`。
- 未改动范围：模板目录和模板文件保持原样，未涉及业务代码实现。
- 完成内容：完成文档框架搭建；制定初始版本计划和回归基线；生成三个 IDEA 条目；明确迭代工作流。
- 未完成内容：业务评审和具体功能实现将在下一轮迭代完成。
- 测试情况：暂无功能代码，故无测试。
- 风险与注意事项：需保证文档模板与实际项目适配；后续迭代需按文档规范持续回填。
- 回滚方式：如目录结构不合适，可恢复到解压前的 `demo.zip` 并重新规划。
- 结论：本轮迭代完成，项目文档框架和初始计划已就绪。
- 下一步建议：启动业务评审，补充版本计划细节，开始实现截图导入与 OCR 服务。
