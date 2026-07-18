# 迭代日志

更新日期：2026-07-18（ITER-435 ASC 1.6.0 发布材料与 build 绑定收口）

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

### ITER-435 ASC 1.6.0 发布材料与 build 绑定收口
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Candidate / App Store Connect
- 类型：ASC 线上操作 / 发布工具 / 文档治理 / 隐私审计 / 测试
- 目标：在不自动提审的边界内继续完成 ASC `1.6.0` 可执行发布门禁；将韩语母语审校改为有记录但不阻断的质量增强，并对主语言 fallback、Review Notes、App Privacy 和最终 build 绑定形成可回读证据。
- 改动范围：同步显式 `en-GB` 元数据与六平台英文截图；增强截图上传终态校验；新增 Review Notes metadata profile、审计 /写入能力与 build 绑定工具；人工查看 ASC App Privacy；更新当前状态、语言矩阵、版本计划、审核说明、CHANGELOG、工具 README、smoke 和本日志；使用官方 App Store Connect API 写入 Review Notes 与四平台 build relationship。
- 未改动范围：未提交审核、未修改发布时机、App Privacy 问卷答案、订阅已审核本地化、审核联系人、App / Worker 业务代码、用户数据、SQLite / CloudKit / D1 schema、StoreKit Product ID、signing、entitlement、版本号、构建号或 Git / Xcode Cloud tag；未在未确认时保存 ASC 网页表单。
- 完成内容：显式 `en-GB` 的版本元数据已从 `en-US` 同步；iPhone、Watch、tvOS、visionOS 截图原已一致，旧 iPad 5 张替换为当前 6 张、旧 Mac 4 张替换为当前 5 张，最终六平台 dry-run 均与本地当前英文资产匹配。`en-GB` 不额外创建 App Preview，继续继承主英语预览。
- 完成内容：`asc_screenshot_upload.rb` 现在遇到数量已完整但仍 processing 的截图集会等待终态，而不是删除并重传；nil `sourceFileChecksum` 不再触发排序崩溃；上传后必须轮询所有 checksum / state 为 `COMPLETE` 并逐文件验证 MD5。
- 完成内容：`metadata.yml` 新增 `main` 与 `readonly` Review Notes profile；iOS / macOS 写入 2783 字符主说明，tvOS / visionOS 写入 1154 字符只读说明。四平台 API 回读长度与 SHA-256 均匹配，`demoAccountRequired=false`，审核联系人字段未被工具修改。
- 完成内容：ASC App Privacy 页面显示 Crash Data、Performance Data、Product Interaction 均仅用于 Analytics，且为 not linked、not tracking，与工程隐私清单一致。取得用户对外部表单提交的明确确认后，Privacy Policy URL 已从旧地址更新并保存为 `https://getautoledger.app/privacy`；关闭弹窗后页面回读新值并显示“已编辑”，说明该变更将随下一版本发布。
- 完成内容：新增 `asc_build_bind.rb`，只接受精确 build number 与完整 source commit；写入前验证 Xcode Cloud run 成功、源码 SHA 完全一致、版本为 `PREPARE_FOR_SUBMISSION`、每平台只有一个符合条件的 build、处理有效、未过期、`APP_STORE_ELIGIBLE` 且 `usesNonExemptEncryption=false`。build `119` 对应提交 `9414b91694d405d3e4c91edbae99d547c1684564`，iOS、macOS、tvOS、visionOS 已绑定并由独立 dry-run 确认 current relationship 等于目标 build ID。
- 完成内容：韩语母语审校因当前找不到合适审校者，按版本负责人决定从硬门禁调整为非阻断质量证据；机器 key / placeholder 检查、离线 / golden 回归、六平台视觉复核、ASC MD5 / 处理终态和已知样本 / 地区缺口继续保留，不将缺少的母语结论标为 Ready。
- 完成内容：用户确认最新 TestFlight 候选的 iCloud 同步 smoke 未发现问题；随后通过 Xcode Cloud API 再次确认最新成功候选仍为 build `119`、源码 `9414b91694d405d3e4c91edbae99d547c1684564`。本轮 Git 改动不含 Swift / App runtime、CloudKit schema、entitlement 或工程构建设置，因此本次推送不触发新 TestFlight build，也不移动 `xcbuild-v1.7.0`。
- 未完成内容：未完成 iPhone / iPad / Mac 最终设备 smoke、iCloud 启动交互与重庆 Moxy 冲突复测、最终 binary 逐镜一致性检查、最终 release-readiness 审计或提审决策。
- 测试情况：Review Notes 四平台线上长度 / SHA-256 回读通过；build binder 二次 dry-run 确认四平台 current build 均为 `119` 对应 build ID；`en-GB` 六平台截图 dry-run 全部匹配。四个 Ruby 工具语法、ASC metadata-as-code smoke（含 Review Notes 长度 / 隐私关键词 / secret marker）、App Preview v003 smoke、本地化发布 smoke、文档真源 smoke、`git diff --check` 与完整 `bash scripts/run_offline_regression.sh` 均 PASS；完整回归仅保留既有 `AppFormatters` `nonisolated(unsafe)` warning。
- 风险与注意事项：App Privacy 页面显示“已编辑”表示新 URL 已保存并等待随下一版本发布，不代表当前线上已发布版本页面立即切换；build 已绑定不等于设备 smoke 或提审完成。韩语母语审校被明确接受为发布后质量风险，任何用户反馈仍应进入本地化修订，不得反向宣称已获母语认可。
- 回滚方式：工具与文档可用 Git 回退；Review Notes 可由保留的 repo profile 再次写入旧文案；build relationship 可在 ASC 仍为可编辑状态时绑定回先前经验证 build。截图替换需使用上传工具和本地 MD5 清单重建；未发生提交审核或发布。
- 结论：ASC `1.6.0` 主语言 fallback、Review Notes、App Privacy URL 与精确 build 绑定门禁已完成可审计收口；韩语母语审校不再阻断本版本。剩余重点是最终设备 / binary smoke 与提审决策。
- 下一步建议：完成 build `119` 的最终设备 / iCloud smoke 与 release-readiness 审计，再单独决定是否提交审核。

### ITER-434 ASC 1.6.0 五语 App Preview poster frame
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Materials / App Store Connect
- 类型：ASC 线上操作 / 发布工具 / 视觉复核 / 测试 / 文档
- 目标：为 ASC `1.6.0` 五语 iPhone App Preview v003 选择统一且稳定的 poster frame，写入后回读帧时间码和 Apple 生成图终态，不改动视频或进入提审。
- 改动范围：从五语 v003 成片抽取候选帧并生成跨语言联系表；扩展 `asc_app_preview_upload.rb` 支持 poster frame dry-run、幂等 PATCH 与生成图轮询；更新工具 README、smoke、项目状态、语言矩阵、版本计划、CHANGELOG 和本日志；使用官方 App Store Connect API 写入五条 preview。
- 未改动范围：未上传、替换或删除 App Preview 视频；未修改截图、`en-GB` fallback、App Privacy、Review Notes、构建绑定、提交审核、发布状态、App / Worker 业务代码、用户数据、schema、StoreKit、签名、entitlement、版本号、构建号或 Xcode Cloud tag。
- 完成内容：在英文成片的 `0.8s` 至 `20.4s` 候选中选定 `1.4s` OCR 首屏；该帧已完全入位、演示数据声明可见、无转场残影，也不展示 Pro 价格或订阅权益。相同时间点在中简、中繁、日、韩成片均完成联系表目检，无截字或布局漂移。
- 完成内容：ASC 回读确认 poster frame 使用 `HH:MM:SS:FF` 帧时间码，现有默认值为 `00:00:05:01`；v003 为 30 fps，因此 `1.4s` 对应 `00:00:01:12`。五次写入均只命中与本地 MD5 一致且 `videoDeliveryState=COMPLETE` 的唯一 preview。
- 完成内容：美英、中简、中繁、日、韩五条 preview 已统一回读 `previewFrameTimeCode=00:00:01:12`，且 `previewFrameImage.state=COMPLETE`；再次 dry-run 二次确认五条视频 checksum、视频终态、时间码和生成图终态一致。
- 未完成内容：未完成人工母语审校、Release artifact 归档、主语言 fallback 复核、与最终提交 binary 的逐镜一致性检查、App Privacy、Review Notes、最终 build 绑定或提审决策。
- 测试情况：五语候选帧与统一时间码联系表目检通过；Ruby 语法、ASC metadata-as-code smoke、App Preview v003 smoke、文档真源 smoke、`git diff --check` 与完整 `bash scripts/run_offline_regression.sh` 均 PASS，仅保留既有 `AppFormatters` warning。ASC 写入前 dry-run、写入处理终态和写入后二次 dry-run 均通过。
- 风险与注意事项：时间码是按当前 30 fps 交付规格计算的帧号；未来如果替换成不同帧率或不同时长的视频，必须重新选帧并计算，不能机械复用 `00:00:01:12`。远端生成图完成不替代合格母语审校或与最终 binary 的逐镜人工核验。
- 回滚方式：工具与文档可用 Git 回退；ASC poster frame 若需回滚，应对同一 preview 显式写回经复核的旧时间码。未发生视频删除、提审或发布。
- 结论：ASC `1.6.0` 五语 iPhone App Preview poster frame 已统一设置并完成双重 API 回读；该发布材料门禁关闭。
- 下一步建议：完成母语 / fallback / 最终 binary 一致性复核，再进入 App Privacy、Review Notes、构建绑定和提审决策。

### ITER-433 ASC 1.6.0 五语截图与 App Preview 替换
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Materials / App Store Connect
- 类型：ASC 线上操作 / 发布工具 / 可靠性 / 测试 / 文档
- 目标：将当前五语六平台截图与五语 iPhone App Preview v003 替换到 ASC `1.6.0`，并以远端 MD5 与 Apple 处理终态完成回读，不绑定构建、不提审。
- 改动范围：使用官方 App Store Connect API 替换 planned 五语截图；新增 `asc_app_preview_upload.rb`；为 ASC API 与二进制上传增加有界瞬时网络重试；更新 metadata 工具默认版本 / planned locale、README、smoke、项目状态、语言矩阵、版本计划、CHANGELOG 和本日志。
- 未改动范围：未修改 `en-GB` fallback 素材、App Privacy、Review Notes、poster frame、构建绑定、提交审核、发布状态、App / Worker 业务代码、用户数据、SQLite / CloudKit / D1 schema、StoreKit Product ID、签名、entitlement、版本号、构建号或 Xcode Cloud tag。
- 完成内容：ASC `1.6.0` 的中简、中繁、美英、日、韩五语在 iPhone、iPad、Mac、Watch、tvOS、visionOS 共 150 张目标截图均与本地 MD5 矩阵匹配；韩语六平台截图集由缺失推进为完整。`en-GB` 保持既有 fallback 状态。
- 完成内容：五语 iPhone `IPHONE_65` App Preview 均为 1 条；五条远端 MD5 与 v003 本地成片一致且 `videoDeliveryState=COMPLETE`。英文和简中的旧视频仅在新视频完成处理后删除；繁中、日语和韩语新建 preview set。
- 完成内容：App Preview 上传工具采用“先上传并等待 COMPLETE、再删除旧片”的安全替换顺序；遇到 `FAILED` 会保留旧片并清理失败的新资源。截图与视频上传共享 429 / 5xx / TLS / timeout 有界重试，支持按 MD5 幂等重跑。
- 未完成内容：未选择 poster frame，未完成人工母语审校、Release artifact 归档或与最终提交 binary 的逐镜一致性复核；这些仍是发布门禁。
- 测试情况：截图本地化 smoke、App Preview v003 smoke、三份 Ruby 脚本语法检查通过；上传前五语 dry-run 通过；上传后 ASC 全平台 audit 确认 planned 五语所有截图集合 `match`，五次 App Preview dry-run 均显示 checksum match / `COMPLETE`；文档真源 smoke、`git diff --check` 与完整 `bash scripts/run_offline_regression.sh` 均 PASS，仅保留既有 `AppFormatters` 四处 `nonisolated(unsafe)` warning。
- 风险与注意事项：ASC 视频转码耗时约数分钟并受本机代理瞬时 TLS 抖动影响，本轮有界重试后全部完成；远端 MD5 / COMPLETE 只证明交付文件一致和 Apple 处理成功，不替代语言质量、poster frame 和最终 binary 一致性。
- 回滚方式：仓库工具与文档可用 Git 回退；ASC 外部素材若需回滚，必须用对应历史资产重新执行上传，不能用 Git 回滚替代。未发生提审或发布。
- 结论：ASC `1.6.0` planned 五语截图与五语 iPhone App Preview 已完成替换并回读确认；商店素材上传门禁关闭，剩余人工审校、poster frame、隐私与最终 build 门禁继续开放。
- 下一步建议：选择五语 poster frame，完成母语 / fallback / 最终 binary 一致性复核，再进入 App Privacy、Review Notes、构建绑定和提审决策。

### ITER-432 ASC 1.6.0 五语 App Preview v003
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Materials / App Preview
- 类型：本地化 / 视觉制作 / 原创音频 / 发布工具 / 测试 / 文档
- 目标：用当前五语截图和统一产品叙事更新 iPhone App Preview，并补一条随六段画面切换变化、可重复生成且不依赖第三方样本的原创背景音乐。
- 改动范围：新增 `tools/appstore-screenshots/app-preview/hyperframes-v003` 五语共享工程、manifest、模板、素材同步、语言选择、批量渲染、原创配乐生成和交付转码脚本；新增 `scripts/check_app_preview_v003_smoke.py` 并接入离线回归；更新 App Preview / 截图 README、i18n 发布矩阵、版本计划、项目状态、CHANGELOG 和本日志。
- 完成内容：一个 22 秒时间轴依次展示 OCR、语音记账、酒店水单复核、Apple Watch、月报和 AutoLedger Pro；五语使用同一布局 / 转场顺序和各自 raw UI capture。Pro 截图中的具体价格由五语“保存前由你确认”卡片替换，同时保留“部分功能需要 AutoLedger Pro”披露。
- 完成内容：新增原创确定性配乐 `Quiet Control`，由仓库脚本合成，不使用第三方样本、旁白或 v002 音乐；在 `3.15 / 6.52 / 9.88 / 13.24 / 16.62` 秒视觉转场点同步改变和弦、主音色与轻提示音，Watch 段稍明亮，Pro 段回到主和弦收束。母带综合响度 `-20.0 LUFS`，48 kHz 立体声，AAC 约 256 kbps。
- 完成内容：本地生成 `en-US / zh-Hans / zh-Hant / ja / ko` 五条最终 MP4；全部为 `886x1920`、30 fps、H.264 High Profile Level 4.0、约 10.9 Mbps、AAC 256 kbps，时长 22.016 秒、约 30.7-30.8 MB。英文恢复为默认活动模板。
- 未完成内容：生成素材与 MP4 按规则 ignored，尚未归档到 Release artifact，未上传 App Store Connect，未选择 poster frame，日语 / 韩语等正式商店文案仍需合格人工审校，也未与最终提交 binary 做人工逐镜一致性核验。
- 测试情况：五语 Hyperframes `validate` 均无 console error 且文本通过 WCAG AA；五语 `inspect --samples 15` 均为 0 issues。日语第一次 validate 遇到一次 10 秒导航超时，单独重跑通过。五语六帧 contact sheet 目检通过；`ffprobe` 规格检查五条均 PASS；音频 `ebur128` 为 `-20.0 LUFS`；`python3 scripts/check_app_preview_v003_smoke.py`、文档真源 smoke 与完整 `bash scripts/run_offline_regression.sh` 均通过，Preview smoke 会在本地成片存在时额外校验五条交付规格。
- 风险与注意事项：Hyperframes 静态 linter 对封装在函数中的动态 GSAP selector 继续给出 `__unresolved__` overlap / Studio edit blocked 提示，属于 v002 同类静态解析限制；浏览器 validate / inspect 与实际渲染均通过。App Preview 可静音自动播放，因此关键信息仍由本地化画面文字承担，音乐不作为理解前提。
- 回滚方式：删除 `hyperframes-v003`、移除新增 smoke 与离线回归入口，并回退本轮发布文档即可；ASC 1.5.0 的 v002 中英文工程和历史视频不受影响。
- 结论：ASC 1.6.0 五语 iPhone App Preview v003 已完成本地视觉、音频和交付规格门禁；下一步是人工语言审校、归档、ASC 上传与 poster frame 选择。

### ITER-431 ASC 1.5.0 元数据归档与 1.6.0 第一版填充
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Metadata / Candidate Preparation
- 类型：发布自动化 / ASC 线上操作 / 文档 / 测试
- 目标：从 ASC 读取并归档当前 `1.5.0` 元数据，建立 `1.6.0` 四平台可编辑版本并填充五语第一版元数据，不绑定构建、不提审。
- 改动范围：扩展 `tools/asc-metadata/asc_metadata.rb` 与 README / smoke；新增 `asc-1.5.0.yml` 和 `asc-1.6.0-first-draft.yml` 线上快照；修正英文副标题长度；更新版本计划、项目状态、CHANGELOG 和本日志；在 ASC 创建及填充新版本。
- 完成内容：实时归档确认 `1.5.0` 的 iOS、macOS、tvOS、visionOS 均为 `READY_FOR_SALE`，四平台均有 `en-GB / en-US / ja / zh-Hans / zh-Hant`；`1.6.0` 四平台均已创建为 `PREPARE_FOR_SUBMISSION`，并具有 `en-GB / en-US / ja / ko / zh-Hans / zh-Hant`，其中 planned 五语版本字段与 repo 配置一致；韩语订阅组、月付和年付本地化已存在。
- 完成内容：用户在 ASC 将 Primary Language 切换为 `English (U.S.)` 后，API 回读确认 `primaryLocale=en-US`；工具修正为优先选择 `PREPARE_FOR_SUBMISSION` App Info，并增加 `--locale` 定点写入。韩语 App Info 已从中文继承值更新为 `AutoLedger - 빠른 가계부` / `스크린샷, 음성, 호텔 명세서 정리`，隐私链接与 Apple TV 隐私正文同步写入并回读一致。
- 未完成内容：ACTIVE 订阅的既有本地化不可覆盖，因此其旧显示名 / 描述按 ASC 已审核现状保留。未绑定 build，未上传截图或 App Preview，未修改 App Privacy，未提交审核或发布。
- 测试情况：`ruby -c tools/asc-metadata/asc_metadata.rb`、`python3 scripts/check_asc_metadata_as_code_smoke.py`、ASC 字段长度校验、三个商店链接 HTTP 200、create-version dry-run / apply、push-config dry-run / apply、Primary Language API 回读、韩语 App Info 精确对账、最终 live export 和完整 `bash scripts/run_offline_regression.sh` 均通过。
- 风险与注意事项：新版本自动保留了 `en-GB` fallback；当前配置 planned locale 为五语，不应把 `en-GB` 误算成发布完成。五语截图与 App Preview、App Privacy 和最终候选构建仍是 P0 门禁。
- 回滚方式：仓库工具与快照可回退；ASC 新版本与已写入本地化属于外部状态，若需撤销应在 ASC 按平台逐项处理，不能用 Git 回滚替代。未发生提审或发布。
- 结论：`1.6.0` 第一版版本文案、`en-US` Primary Language 与韩语 App Info 已完成线上填充并回读确认；最终发布资产仍未完成。
- 下一步建议：在候选冻结后上传五语截图与 App Preview，复核主语言 fallback、App Privacy 与 Review Notes，再绑定最终 build。

### ITER-430 韩语六平台截图管线
- 日期：2026-07-18
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Candidate / Localization Assets
- 类型：能力增强 / 测试 / 文档
- 目标：把当前版本规划中的韩语商店截图从“缺少管线”推进为六平台可重复生成的本地资产，并消除截图画面内回退中文的问题，同时保持 ASC 上传、母语审校与真实样本门禁不被误报为完成。
- 改动范围：更新 `tools/appstore-screenshots` 的 locale 配置、30 个 shot 文案、韩文字体选择、导出帮助、预览文档和截图本地化 smoke；仅为 iOS、Watch、tvOS、visionOS 的 screenshot mode / screenshot Host 增加韩语 copy；更新当前项目状态、v1.7.0 计划、i18n 发布矩阵、CHANGELOG 和本日志。
- 未改动范围：未改变正常 App 启动路径、正式 UI 本地化资源、账本 / OCR / iCloud / 酒店业务逻辑、用户数据、Worker、SQLite / CloudKit / D1 schema、StoreKit Product ID、签名、entitlements、Xcode 工程版本号、构建号、ASC 线上 metadata / Primary Language、Xcode Cloud workflow 或 `xcbuild-v1.7.0` 标签。
- 完成内容：截图配置新增 `ko` / `ko_KR`，iPhone 8 张、iPad 6 张、Mac 5 张、Watch 4 张、tvOS 4 张、visionOS 3 张均补齐韩语营销标题与副标题；渲染器为韩语优先选择 Apple SD Gothic Neo，并保留 Noto Sans Gothic / Apple Gothic fallback。
- 完成内容：首轮全平台导出成功后，视觉复核发现 iOS、Watch、tvOS、visionOS 的营销标题虽为韩语，但画面内仍存在中文 fallback；本轮据此补齐四个平台截图 Host 的韩语 copy 并重新编译导出，最终六平台画面内主文案均使用韩语。
- 完成内容：本地生成 30 张 raw 与 30 张商店成品，商店尺寸分别为 iPhone `1242x2688`、iPad `2732x2048`、Mac `1440x900`、Watch `410x502`、tvOS / visionOS `3840x2160`；预览页包含 30 个韩语引用，输出目录无 `.tmp` 残留。生成物按仓库规则忽略，未纳入提交。
- 未完成内容：未上传 ASC 截图集，未生成或上传韩语 App Preview；韩语原生设备长文本 / 动态字体目检、订阅文案最终状态、母语审校、真实韩国小票 / 支付通知 / 酒店 folio 样本和 Kakao Pay / Naver Pay 地区专项仍未完成，因此 `ko` 继续保持非 Ready。
- 测试情况：屏幕录制权限 preflight 通过；`export.sh --locale ko` 完整构建并导出六平台，修复后再次构建并重导 iOS、Watch、tvOS、visionOS；30 / 30 raw 和 30 / 30 store 数量、平台尺寸、预览引用与临时文件检查通过；六平台成品联系表完成工程视觉复核；Python 脚本编译、`python3 scripts/check_screenshot_localization_smoke.py`、`python3 scripts/check_documentation_truth_smoke.py`、`git diff HEAD --check` 和完整 `bash scripts/run_offline_regression.sh` 均通过。回归仅保留既有 `AppFormatters` `nonisolated(unsafe)` 编译 warning，无失败。
- 风险与注意事项：本地截图成功不能替代 App Store Connect 在线截图状态或韩语母语质量；截图 Host 中保留的英文产品名、示例商户名和货币符号属于演示数据，不应误判为本地化 fallback。Watch 小屏内容仍受原生 viewport 约束，正式上传前应继续按 ASC 预览人工检查。
- 回滚方式：回退截图配置、渲染器、导出文档、静态 smoke 与四个截图 Host 的本轮改动；输出目录为 ignored 生成物，可直接重新导出，不涉及用户数据、schema 或线上回滚。
- 结论：韩语六平台截图管线与本地成品已补齐，截图画面内中文 fallback 已修复；完整韩语发布仍受 ASC、母语审校、真实样本和地区专项门禁约束。
- 下一步建议：在最终候选冻结后上传并逐平台核对 ASC 韩语截图集，完成原生设备与母语审校；同时归档真实韩国样本和 App Preview / 订阅证据，再决定是否把韩语升级为 Ready。

### ITER-429 文档物理分类、语言路线与 v1.8 草案
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0（发布文档收口）；v1.8.0 / ASC 1.7.0（仅规划）
- 所属阶段：Release Documentation / Roadmap Planning / Governance
- 类型：文档 / 治理 / 测试
- 目标：按用户确认将混排的 `docs/` 物理分类，同时保留核心 Roadmap 在 `docs/` 根目录；固定“每个公开功能版本新增一组语言”的跨版本路线，建立 `v1.8.0` 产品与语言草案，并修订当前版本的英语主语言与语言准入门禁。
- 改动范围：将既有文档按 `product / architecture / capabilities / platforms / operations / archive` 六组迁移；重建 `docs/README.md`；更新全仓 Markdown 引用、四语 README、`AGENTS.md`、`PROJECT_STATUS.md`、工具 README、历史版本计划、`versions/v1.7.0-plan.md` 和当前语言矩阵；新增 `docs/product/I18N_ROADMAP.md`、`versions/v1.8.0-plan.md` 与 `versions/v1.8.0-i18n-release-matrix.md`；增强文档真源 smoke；同步 CHANGELOG 和本日志。
- 未改动范围：未修改 Swift / TypeScript 产品实现、App / Worker API、SQLite / CloudKit / D1 schema、StoreKit Product ID、签名、entitlements、Xcode 工程、版本号、构建号、Xcode Cloud tag、ASC 线上 metadata 或 Primary Language，也未构建、部署或提交审核。
- 完成内容：`docs/` 根目录只保留 `README.md` 与核心 `ROADMAP.md`；产品专项、架构合同、用户能力、平台设计、发布运维和历史材料均进入固定目录，索引记录每份文档的生命周期和职责。
- 完成内容：新增跨版本语言路线，固定 `v1.7.0` 韩语、`v1.8.0` 西语 + 巴葡、`v1.9.0` 法语 + 德语、`v2.0` 印尼语 + 越南语，保留 `v2.1` 印地语 + 印度英语 profile 与后续阿拉伯语 / RTL 候选；每组都受商店、UI、识别、样本、地区票据和人工审校六项门禁约束。
- 完成内容：核心 Roadmap 将下一版本定位为 Review & Close；`v1.8.0` Draft 规划持久化待处理、统一复核生命周期、可理解同步状态、月结检查、西语 / 巴葡和有限云端辅助可靠性，不把规则中心、Saved Views 或订阅省钱看板提前扩入 P0。
- 完成内容：当前 `v1.7.0` 计划和语言矩阵明确西语 / 巴葡不进入当前候选，并新增 ASC `1.6.0` 英语主语言门禁。仓库已确认 Xcode `developmentRegion = en`，ASC Primary Language 目标为 `English (U.S.) / en-US`；实际线上切换仍需可编辑性检查、全平台英语截图条件与 ASC 证据，不能由文档或 metadata YAML 代替。
- 完成内容：`scripts/check_documentation_truth_smoke.py` 改为递归检查 `docs/**/*.md`，只允许六类目录及根级 README / ROADMAP 例外，并校验生命周期、索引状态、当前与下一版本真源片段、四语入口和本地 Markdown 断链。
- 未完成内容：`v1.8.0` 尚未进入 Execution Ready，西语 / 巴葡资源、识别包、样本、截图和 ASC locale 均未实施；ASC Primary Language 尚未在线切换或留证；当前 `v1.7.0` 的 TestFlight、iCloud、韩语审校、商店资产和发布门禁仍按 `PROJECT_STATUS.md` 关闭。
- 测试情况：`python3 scripts/check_documentation_truth_smoke.py` PASS；`python3 -m py_compile scripts/check_documentation_truth_smoke.py` PASS；`git diff HEAD --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS，并在完整回归内再次执行文档真源 smoke PASS。仅出现既有 `AppFormatters` 四处 `nonisolated(unsafe)` 编译警告，无失败。
- 风险与注意事项：本轮物理迁移由用户在 ITER-428 的候选期保守策略之后明确授权，旧日志中“发布后再迁移”保留为当时决策；外部书签若直接指向旧文件路径会失效，仓库内引用已全部更新。未来新增文档若绕过分类或漏改索引，离线回归会失败。
- 回滚方式：将分类目录中的文档移回原路径，恢复索引与全仓链接，删除新语言路线、v1.8 草案及对应 smoke 断言即可；无产品代码、线上配置或数据迁移回滚。
- 结论：文档物理结构、核心 Roadmap 例外、跨版本语言节奏、当前版本门禁与下一版本 Draft 已形成清晰真源，并通过完整离线回归。
- 下一步建议：先完成 `v1.7.0` Release Candidate 的设备、iCloud、韩语、ASC 与隐私证据；发布决定归档后，再把 `v1.8.0` Draft 升级为 Execution Ready 并从合同 / 样本阶段启动。

### ITER-428 项目文档真源与路线图治理
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Documentation / Governance
- 类型：文档 / 治理 / 测试
- 目标：在版本发布前建立唯一的当前状态与跨版本产品路线图真源，整理 `docs/` 文档的生命周期和入口，并让根 README、版本计划与专题文档不再争夺“当前状态”解释权。
- 改动范围：新增根目录 `PROJECT_STATUS.md` 与 `docs/ROADMAP.md`；重建 `docs/README.md` 索引；为 `docs/*.md` 补充生命周期元数据；更新四语 README、`AGENTS.md`、Pro 专题文档与 `versions/v1.7.0-plan.md`；新增文档真源 smoke 并接入完整离线回归；同步本日志与 CHANGELOG。
- 未改动范围：未修改 App、AutoLedgerCore、Worker、SQLite / CloudKit / D1 schema、StoreKit、ASC metadata、签名、entitlements、Xcode 工程配置、版本号、构建号、构建 tag 或线上部署；发布候选期不移动既有文档路径。
- 完成内容：`PROJECT_STATUS.md` 成为当前发布阶段、已验证产品代码基线、发布门禁、已知风险和下一动作的唯一真源；`docs/ROADMAP.md` 成为 Now / Next / Later / Not Planned 与产品主线依赖关系的唯一真源；README 和版本计划只保留派生摘要并链接回真源。
- 完成内容：`docs/README.md` 现在完整索引 `docs/*.md`，并以 `Canonical / Active / Reference / Historical` 标记生命周期；所有现有专题文档均在文件头声明状态、事实边界、替代真源或维护触发条件。物理归档推迟到发布后，避免发布候选期产生大规模路径噪音。
- 完成内容：修正 Pro 文档中已经过期的“云端辅助尚未接入 / 只保存授权偏好”口径，记录当前 hash-only 商户别名建议、StoreKit 服务端权益校验、401 续签重试、本地确认和失败降级边界；不使用“零上传”等绝对隐私表述。
- 完成内容：新增 `scripts/check_documentation_truth_smoke.py`，检查真源文件与必需章节、全部 `docs/*.md` 生命周期元数据、文档索引完整性、四语 README 真源链接、关键陈旧表述和本地 Markdown 链接，并纳入 `scripts/run_offline_regression.sh`。
- 未完成内容：既有历史 / 参考文档尚未物理迁移到子目录，待 v1.7 发布后单独执行；当前 TestFlight 精确构建号与外部验收证据没有从本地推断，仍需以 Xcode Cloud / ASC 和真机结果回填；iCloud、四平台构建、商店与隐私等发布门禁仍按状态文档逐项关闭。
- 测试情况：`python3 scripts/check_documentation_truth_smoke.py` PASS；`git diff --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS，且运行中再次执行文档真源 smoke PASS。`git ls-remote` 确认 `origin/main` 与远端 `xcbuild-v1.7.0` 均指向产品代码基线 `9414b91694d4`。回归仅出现既有 `AppFormatters` `nonisolated(unsafe)` 编译警告，无失败。
- 风险与注意事项：产品代码和外部发布证据高于文档描述；旧版本计划中的带日期执行记录作为历史事实保留，不能被当作当前状态；发布门禁或产品方向变化时必须先更新各自真源，再刷新派生摘要。
- 回滚方式：回退本轮新增真源、索引、元数据、README / 版本计划口径、文档 smoke 及日志条目；由于未移动文件和未修改产品代码，不涉及数据迁移或运行时回滚。
- 结论：当前状态、产品路线图和专题文档生命周期已形成单一责任真源，并通过可持续自动门禁约束；本轮未改变发布候选产品行为。
- 下一步建议：发布收口期间只在 `PROJECT_STATUS.md` 回填外部证据和门禁结果；v1.7 发布后再按 `docs/README.md` 的逻辑分类执行物理目录迁移，并单独校验外链和历史引用。

### ITER-427 Dashboard 口径、云收件箱续签与云端别名建议
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：TestFlight Feedback / Observability / Data Cleaning
- 类型：Bugfix / 能力增强 / UI / Worker / 测试 / 部署
- 目标：修复 AL Dashboard“导入完成率”混合任务成功与实时扫描确认漏斗导致数据不可解释的问题；处理新版 TestFlight 云端收件箱 401；修正数据清洗自动化规则指标截断与字号不一致；让已存在的云端辅助合同真正产生可确认的商户别名建议。
- 改动范围：Common API Dashboard 聚合与页面；hotel-folio-inbox Worker token 续签、数据清洗辅助 endpoint 与别名目录；App 云端收件箱 401 重试、数据清洗辅助客户端、建议合并、授权文案、规则指标布局、截图模式；五语本地化与版本记录。
- 未改动范围：未上传原始商户名、精确金额、备注、OCR 原文、交易 ID 或账本行；未自动应用云端建议；未修改 SQLite / CloudKit schema、冲突决策、StoreKit 产品、Bundle ID、entitlements、ASC metadata 或 Xcode Cloud workflow。
- 完成内容：Dashboard 移除语义错误的全局“导入完成率”，改为按非实时扫描终态事件计算“导入任务成功率”，并单独用实时扫描开始数与确认成功数展示“实时扫描确认率”；历史 36.4% 不再被解释成导入失败率。
- 完成内容：云端收件箱候选刷新遇到 401 时，以当前 StoreKit 签名交易向 Worker 续签既有 access token、更新到期时间和 App Store 用户绑定后自动重试；既有 active token 和专属收件地址保持不变，无法迁移时才走新的凭据领取合同。
- 完成内容：数据清洗的三块自动化规则指标统一为图标、等字号数字和单行标签，`商户别名`、`分类修正`、`会更新` 在 iPhone 宽度完整显示。新增 `data_cleaning` 截图场景，并以 iPhone 17 Pro 模拟器完成可视检查。
- 完成内容：云端辅助开启且 Pro / 最小历史条件满足时，App 向 folio Worker 发送商户键哈希及次数、分类、来源、金额区间等聚合特征；Worker 先做 App Store 服务端权益校验，再以首批中英商户别名目录返回 hash-only 建议。App 映射回本地商户并合并到现有待确认列表，网络或服务端失败只显示提示并保留本机建议。
- 未完成内容：云端别名目录当前只覆盖首批常见品牌 / 平台，不是开放词义模型；请求冷却与失败 backoff 仍只存在 Core 合同，尚未持久化成功响应缓存和跨页面配额状态；建议仍需用户真机确认其实际命中质量。
- 测试情况：Common API 51 项 Vitest 与 TypeScript PASS；hotel-folio-inbox 30 项 Vitest 与 TypeScript PASS；完整 `bash scripts/run_offline_regression.sh` PASS；签名 iOS generic workspace build PASS；iPhone 17 Pro / iOS 27 Simulator screenshot build PASS，截图确认三块规则指标无截断且字号一致。Common API staging / production Version ID 为 `2541d6fc-d7dd-4029-bfef-7a915f4b2a73` / `e3adaffd-9269-47c7-a853-e67fb3a8a5d7`；folio staging / production 最终 Version ID 为 `c6bd91fe-4712-40d3-8488-eb15f90129d0` / `2945e1cf-6fe6-419b-96b3-90fb9ec7a0aa`。
- 风险与注意事项：hash-only 聚合会降低云端语义识别范围，首版通过受控别名目录换取可解释性；相同别名组以本地交易次数较多的写法作为目标，用户确认前不会改账。401 自动续签依赖有效 StoreKit 签名交易，权益失效时继续 fail closed。Dashboard 两个比率分母较小时仍应结合 numerator / denominator 解读。
- 回滚方式：Dashboard 可恢复旧 metric ID；收件箱可移除 401 claim-and-retry 而保留手动重新领取；云端辅助可关闭 endpoint 和客户端调用并保留本机规划器；规则指标可恢复原 Label 布局。
- 结论：四个反馈点均已实现并通过本地 / Worker / 可视门禁，线上 Worker 已发布；App 端等待下一 TestFlight 真机验收。
- 下一步建议：下一构建先验证云收件箱原地址刷新不再 401，再用包含 `麦当劳 / McDonald's`、`星巴克 / Starbucks` 等两种写法的测试账本开启云端辅助，确认建议出现、拒绝不改账、接受后反哺后续导入；同时按 Dashboard numerator / denominator 解读新指标。

### ITER-426 启动 iCloud 同步让位 UI
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance Acceptance / Launch Sync
- 类型：性能 / 数据同步 / 并发 / 测试
- 目标：基于 TS 117 相比上一版明显改善的真机反馈，让启动 iCloud 同步在本地账本可交互后继续完成，并减少同步完成时全量 SQLite 解码对 UI actor 的占用。
- 改动范围：`LedgerStore` 启动 CloudKit 同步顺序、同步完成后的 SQLite 快照刷新、持久化状态版本保护、CloudKit 静态门禁、离线回归与版本记录。
- 未改动范围：未提前撤销首次本地 SQLite 水合遮罩；未修改 CloudKit / SQLite schema、冲突合并规则、同步 record、App UI、埋点口径、Worker、StoreKit、ASC metadata 或 Xcode Cloud workflow。
- 完成内容：启动 CloudKit 同步现在先等待既有首次本地 SQLite 水合完成；本地账本成为 UI readiness 的唯一门禁，之后的云端推送 / 拉取继续在不显示启动遮罩的状态下运行。
- 完成内容：CloudKit 全量同步和拉取完成后不再在 UI actor 同步读取全部账单、订阅、酒店记录、草稿、冲突和账本配置，改用独立 SQLite reader 后台生成完整快照，再一次性发布到 UI 状态。
- 完成内容：后台快照加载时记录持久化状态修订号；若用户在此期间新增、编辑或删除账单、订阅、酒店数据、别名或账本配置，则丢弃旧快照并重试一次，避免云端刷新用较旧内存快照覆盖刚发生的交互结果。
- 未完成内容：CloudKit 合并写入仍按既有串行一致性路径执行；尚未取得包含本轮改动的真机启动同步阶段样本，不能宣称 iCloud 同步对 UI 已完全零影响。
- 测试情况：`check_cloudkit_sync_smoke.py` 与长列表性能门禁 PASS；完整 `bash scripts/run_offline_regression.sh` PASS，新增“外部合并写入 SQLite 后通过后台水合发布到 LedgerStore”回归；签名 iOS generic workspace build PASS。首次回归因新增测试误用了不存在的 `.travel` 分类而编译失败，改为内置 `.hotel` 后全量重跑通过；产品代码未因此调整。
- 风险与注意事项：快照因用户交互变更被连续丢弃两次时，本轮不会无限重试，SQLite 中的云端合并结果仍完整保留，并会在下一次前台刷新发布；该边界优先避免后台同步与持续交互争抢。是否仍存在短时同步写入卡顿需结合下一 TestFlight 的启动、Tab settle 和 Instruments 数据判断。
- 回滚方式：恢复 CloudKit 同步后的同步 `refreshFromStore()`，移除 `persistenceStateRevision` / stale snapshot 检查，并取消启动同步前的后台水合等待；首次本地水合逻辑可独立保留。
- 结论：启动 iCloud 同步已调整为“本地账本先可交互、云端随后完成”，并消除同步后主线程全量重载；状态为 `Acceptance Pending`。
- 下一步建议：下一 TestFlight 冷启动后立即往返首页、账本和酒店 Tab，同时观察 iCloud 同步状态是否最终完成；按 source build 对照 `tab_selection_settle` / `tab_surface_appear`，若同步窗口仍出现明显卡顿，再单独把 CloudKit 合并写入拆到专用后台连接。

### ITER-425 账本与酒店 Tab 派生结果复用
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance Acceptance / Tab Switching
- 类型：性能 / 重构 / 测试
- 目标：针对 TS 116 开发者阶段样本中酒店 Tab 集中落入 `1s–3s`、账本仍有卡顿体感的问题，减少 Tab 切换和 SwiftUI 重绘时重复执行的全量内存过滤、排序、格式化与 ID 构造，同时保持现有数据和交互语义。
- 改动范围：`LedgerStore` 当前账本交易与酒店列表 snapshot 缓存、账本选择变更监听、酒店列表派生结果传递、长列表静态门禁、离线回归与版本记录。
- 未改动范围：未修改 SQLite 查询、初始后台水合、CloudKit、酒店 / 账本模型、搜索和排序口径、列表首屏数量、StoreKit、Worker、analytics 事件、ASC metadata 或 Xcode Cloud workflow。
- 完成内容：`visibleTransactions` 现按交易修订号、选中账本与“全部账本”状态复用结果；交易或账本范围变化时修订号自动递增。`LedgerView` 不再在每次 `body` 更新时为 `.onChange` 全量生成 ID，而只在可见交易修订号变化后重建一次选择 ID。
- 完成内容：酒店列表 snapshot 现按酒店记录修订号、账本范围和 Locale 缓存；`HotelStayWorkspaceView` 将缓存 snapshot 传入列表，同一次 SwiftUI 更新只解析一份 snapshot、待处理草稿和记录 ID 索引。酒店记录新增、编辑或删除后修订号变化会自动失效缓存。
- 完成内容：未直接引入 SQLite 分页。当前 Tab 切换使用冷启动时已经后台水合到内存的集合；先消除重复派生计算，可避免分页同时牵连高级搜索、月报、CloudKit 合并和详情选择。是否继续做“首批 N 条 + 增量扩容”由下一 TestFlight 阶段样本和 Instruments 决定。
- 未完成内容：尚未取得包含本轮优化的真机阶段样本，不能以构建和离线回归宣称 Tab 已流畅。
- 测试情况：长列表静态门禁 PASS；完整 `bash scripts/run_offline_regression.sh` PASS，新增酒店 snapshot 重复读取一致与记录更新后缓存失效回归；无签名 iOS generic Debug workspace build PASS。首次编译暴露 Xcode 26 beta Swift 6.4 在 `@ViewBuilder` 中对 `@Binding` 同名可选绑定的编译器断言，改为显式 `selectedID` 局部变量后构建通过。
- 风险与注意事项：缓存保存数组和展示 snapshot，会增加少量内存引用；数组使用 Swift Copy-on-Write，缓存只保留当前范围一份结果。Locale 纳入酒店缓存键，避免地区格式变化继续使用旧金额文本。实际收益仍需按同一设备、同一数据和相同路径比较。
- 回滚方式：移除两个 cache key / cache value / revision，恢复 `visibleTransactions` 直接过滤、酒店列表直接生成 snapshot，以及账本基于完整 ID 数组的 `.onChange`。
- 结论：账本与酒店 Tab 的重复派生计算已完成最小降耗并通过本地门禁，状态为 `Acceptance Pending`，等待下一 TestFlight 真机对照。
- 下一步建议：iPhone 开发者模式下按“首页 → 账本 → 酒店 → 设置”固定顺序往返 10 轮，区分首次进入和重复切回；重点比较 `tab_ledger` / `tab_hotel_stays` 的 `tab_surface_appear` 与 `tab_selection_settle`。若酒店仍两阶段都慢，再用 SwiftUI / Time Profiler 定位 `NavigationSplitView` 建树和行格式化；若账本仅大数据量慢，再设计有搜索兼容的增量窗口。

### ITER-424 性能卡片标题样式统一
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance Acceptance / Dashboard Polish
- 类型：UI / 可观测性 / 测试 / 部署
- 目标：统一现有 AutoLedger Dashboard 性能卡片中“性能操作”和“开发者模式阶段”两个标题的字号、字重、说明文本和间距层级。
- 改动范围：Common API Dashboard 内嵌 HTML / CSS、HTML shell 合同测试、版本记录与 Worker 部署。
- 未改动范围：未修改 App 性能埋点、事件名、耗时 bucket、聚合字段、D1 / SQLite / CloudKit schema、Dashboard 数据接口、Cloudflare Access、App 构建或 Xcode Cloud tag。
- 完成内容：“开发者模式阶段”由无样式的单行文本改为与卡片标题一致的标题加右侧说明结构，使用同一 18px 标题层级和 12px muted 说明，并增加分隔线及窄屏换行，避免标题与首条阶段数据挤在一起。
- 未完成内容：无。
- 测试情况：`git diff --check` PASS；Common API Wrangler types、TypeScript 与 51 项 Vitest 合同测试 PASS。staging 页面壳返回 200 并包含统一标题结构；production `/health` 返回 200，未保护 `/dashboard/data` 返回 403，受 Cloudflare Access 保护的 `getautoledger.app/dashboard/` 未登录返回 302。已部署 staging Version ID `94296390-4950-446c-aadf-00e064cf0a95` 与 production Version ID `5791ada4-b18c-4093-8822-30ce29f4a285`。
- 风险与注意事项：仅改变 Dashboard 静态展示，不影响已经落库和可查询的 TS 116 性能数据；窄屏下说明文本允许换行。
- 回滚方式：恢复 `dashboard.ts` 中原单行开发者阶段标题及对应 CSS / 合同断言，然后重新部署 Worker。
- 结论：两个标题样式已统一并发布到现有 AL Dashboard，TS 116 性能数据查询链路保持不变。
- 下一步建议：刷新现有 AL Dashboard，在桌面和窄窗口分别确认两个标题视觉层级一致；随后只读定位账本与酒店 Tab 的首次进入 / 重复切回链路，分别评估 SwiftUI 首屏懒渲染与 SQLite 分页读取，不能只用 `LazyVStack` 代替数据层减载。

### ITER-423 开发者性能埋点 TestFlight 构建触发
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening / TestFlight Trigger
- 类型：发布 / 构建 / 治理
- 目标：把 ITER-421 iCloud 冲突复活修复与 ITER-422 开发者模式性能阶段埋点推送到主线，并移动现有 `xcbuild-v1.7.0` tag 触发下一次 Xcode Cloud 四平台构建。
- 改动范围：提交当前已验证的 App / Core / Common API / 回归 / 文档变更，推送 `main`，强制更新唯一构建触发 tag，并核对远端 tag 解引用目标。
- 未改动范围：未修改 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`、Bundle ID、签名、entitlement、CloudKit / SQLite / D1 schema、StoreKit、ASC metadata 或 Xcode Cloud workflow；未删除任何 Worker，也未移动内部发布版本 tag。
- 完成内容：实现提交包含“保留本机”后旧冲突标记不再复活、开发者模式 Tab 选择 / surface appear / 主线程 settle 埋点、现有 AutoLedger Dashboard 性能卡片聚合，以及对应离线与 Worker 回归；Common API production 已在上一轮提前部署，App 客户端通过本次构建进入 TestFlight 验收。
- 测试情况：提交前 `git diff --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；无签名 iOS generic Debug workspace build PASS；Common API Wrangler types、TypeScript 与 51 项 Vitest 合同测试 PASS；Worker production health 与 Dashboard Access 边界 smoke PASS。推送后以 `git ls-remote` 验证 `origin/main` 与远端 `xcbuild-v1.7.0` 指向同一最终提交。
- 风险与注意事项：tag 推送只代表 Xcode Cloud 已收到构建触发，不代表四平台 Archive、TestFlight processing 或真机验收已经完成。下一构建仍需先确认 Xcode Cloud 状态，再按 iPhone → iPad / Mac / 性能的既定顺序验证；不能以 Worker 已上线替代 App 埋点客户端进入 TestFlight。
- 回滚方式：若构建失败，保留当前 main 证据并按失败日志做最小修复后再次移动同一 tag；如必须撤销功能，使用新 revert 提交而非重写 main 历史。
- 结论：当前实现已进入主线和 Xcode Cloud 构建触发基线，等待新构建完成后采集真实开发者模式性能阶段样本。
- 下一步建议：先确认四平台 Xcode Cloud 构建结果；新 TestFlight 可用后先在 iPhone 开启开发者模式完成固定 Tab 切换，再在 iPad 复测重庆 Moxy 冲突与相同切换路径，最后补 Mac / Instruments。

### ITER-422 开发者模式性能阶段埋点与 Worker 汇总
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance Acceptance / Observability
- 类型：性能 / 可观测性 / 测试 / 部署
- 目标：在开发者模式开启时补齐 Tab 选择、目标页面出现和主线程短时 settle 的离散耗时证据，通过现有匿名 analytics Worker 聚合，继续分析 TS 115 上“无明显 hang / hitch 但切换仍有 1–2 秒体感”的来源。
- 改动范围：App 开发者诊断开关、首页 Tab 阶段埋点、Core analytics 聚合、Common API dashboard 聚合与合同测试、版本记录；只读盘点 AutoLedger 现有 Cloudflare Worker 职责。
- 未改动范围：普通用户不启用增强阶段埋点；未上传账本、金额、商户、酒店、截图、PDF、OCR、邮箱、Apple ID、设备标识或用户级轨迹；未修改 SQLite / CloudKit / D1 schema、StoreKit、entitlement、ASC metadata、Xcode Cloud workflow 或构建 tag；未删除或修改 `autoledger-hotel-folio-inbox*` 与 `autoledger-bill-parser` Worker。
- 完成内容：设置页连续点击版本号解锁开发者模式时，持久化开启“增强性能诊断”；Debug 页面提供显式开关。开启后，首页 Tab 选择记录 `tab_selection_settle`，目标页面 `onAppear` 记录 `tab_surface_appear`，并在一次主线程 yield 与 120 ms settle 窗口后复用 `al_performance_diagnostic` 上传离散 duration bucket。关闭开发者模式时不产生这些增强事件。
- 完成内容：Core 与 Common API 新增 `developer_performance_sample_count` 和 `developer_performance_breakdown`，按 `surface / operation / duration bucket / app version(build)` 聚合；开发者阶段明细并入现有 AutoLedger Dashboard 的“性能操作”卡片，与常规性能操作共同展示，不建立第二套 Dashboard 或独立性能卡片，也不返回原始事件行或 payload。
- 完成内容：Cloudflare 盘点确认性能 analytics 应继续复用 `darkrio-common-api-production`，而不是图片解析或酒店收件箱 Worker。三个 folio Worker 分别是 dev / staging / production 隔离环境，拥有独立 D1、R2 与 Queue；production 还承载 `folio@getautoledger.app` Email Routing、云候选、Pro entitlement、App Store Server Notifications、APNs Queue 和定时补偿，因此本轮全部保留。`autoledger-bill-parser` 仅有 OpenAI 图片解析 fetch handler，当前 App / 仓库无调用入口，唯一部署已 38 天未更新；Cloudflare 面板过去 24 小时为 8 次调用、0 子请求、0 错误，先列为待下线候选，不在缺少长期零流量证据时直接删除。
- 测试情况：`git diff --check` PASS；`cd tools/worker/common-api && npm run check` PASS，覆盖 Wrangler types、TypeScript 与 51 个 Vitest 合同测试；完整 `bash scripts/run_offline_regression.sh` PASS；无签名 iOS generic Debug workspace build PASS。最终部署 staging Version ID `fc204ddf-3285-4ff6-8f37-015b5b86adc4` 与 production Version ID `9906c708-332a-4abf-bb75-bf9395c3b35c`；staging 合成事件返回 202、D1 可查询，Dashboard 返回 `developer_performance_sample_count=1` 与 `tab_hotel_stays/tab_surface_appear/1s_3s@1.6.0(422)`，页面 smoke 确认只有 1 个现有 `performance-ops` 卡片、0 个独立 `developer-performance` 卡片且开发者阶段子区域存在；production health / manifest 返回 200，未保护 dashboard host 返回 403，受 Access 保护的 dashboard data 未登录返回 302。production / staging folio health 均返回 200。
- 风险与注意事项：`onAppear` 代表目标页面进入视图树，不等同于列表数据完全绘制；`tab_selection_settle` 的 120 ms 窗口用于区分短时主线程忙碌，不是精确帧级 trace。聚合结果必须继续与 Instruments、MetricKit source build 和用户体感对照，不能仅凭 bucket 推断根因。bill-parser 的少量调用可能是公开 workers.dev 探测，也可能来自仓库外旧客户端，删除前仍需更长窗口或先禁用路由观察。
- 回滚方式：关闭或移除 `developerPerformanceDiagnosticsEnabled`、首页 Tab modifier 与两项聚合指标即可；Worker dashboard 回退到上一版本不影响既有 analytics 表和事件写入。三个 folio Worker 与 bill-parser 本轮没有状态变更，无需资源回滚。
- 结论：开发者模式性能阶段埋点和 Common API Worker 聚合已完成代码、测试、staging 落库聚合与 production 发布闭环；folio 三环境继续保留，bill-parser 暂不删除。下一步用下一 TestFlight 的真实开发者模式样本定位 Tab 体感阶段。
- 下一步建议：在 iPhone / iPad 开启开发者模式后按固定顺序各切换 10 轮首页、账本、月报、酒店、设置，再按 source build 对照 `tab_selection_settle` 与 `tab_surface_appear` 分布；如 surface appear 快而 settle 慢，优先查主线程工作，如两者都快但仍有体感延迟，继续用 SwiftUI trace 检查绘制与状态提交。

### ITER-421 iCloud 冲突复活修复与 iPad TS 115 复测
- 日期：2026-07-17
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening / Cloud Sync / Performance Acceptance
- 类型：Bugfix / 真机测试 / 回归
- 目标：修复关联重庆 Moxy 酒店记录的账单在选择“保留本机”后仍反复出现同步冲突，并以已解锁 iPad mini 6 复核 TS 115 Tab 切换体感。
- 改动范围：SQLite 远端批量合并的最近编辑保护、离线同步回归、版本记录；实体 iPad TS 115 的 Time Profiler 与 Animation Hitches 只读采样。
- 未改动范围：未修改重庆 Moxy 的酒店或账单业务字段，未删除本地 / CloudKit 数据，未修改 SQLite / CloudKit schema、同步 record type / field / index、StoreKit、Worker、entitlement、ASC metadata、Xcode Cloud workflow 或构建 tag；未增加“使用 iCloud 版本”冲突候选存储与 UI。
- 完成内容：定位到冲突 UI 实际对应酒店记录关联的 `Transaction`。用户选择保留本机后，本地冲突标记会清理、修订号递增并进入最近编辑保护；但旧保护只比较账单内容和删除时间，当远端账单内容相同而仍携带 `conflictPendingReview` 时，正式推送完成前的一次拉取会把旧冲突标记重新写回本地。
- 完成内容：最近编辑保护窗口内，只要远端记录来自另一设备，就统一保留刚由本机确认的版本，避免内容相同的旧冲突元数据重新污染本地；保护窗口结束后仍继续使用既有时间戳、修订号、设备和冲突决策，不改变普通同步口径。
- 完成内容：离线回归新增“本地冲突已保留并清理、远端同内容但旧 conflict 标记再次到达”的场景，验证结果为 `keptLocal=1`、`conflicts=0` 且本地状态保持 `clean`。完整离线回归通过。
- 完成内容：iPad mini 6 已确认安装 `1.6.0 (115)`。production build 115 匿名数据中酒店 Tab 有 2 次、首页 Tab 有 1 次落入 `1s–3s`；实体 iPad 30 秒 Time Profiler 固定路径没有超过 250 ms 的 potential hang，45 秒 Animation Hitches 两轮切换没有系统 hitch，只有一帧 33.46 ms（render 9.41 ms、GPU 0.11 ms）。SwiftUI 模板按 TS 进程附加失败，全系统采样又因设备断开失败，因此不以当前 trace 宣称 Tab 已流畅。
- 未完成内容：TS 115 仍只有“保留本机”，没有持久化云端候选、字段对比或“使用 iCloud 版本”；冲突复活修复需进入下一 TestFlight 才能用重庆 Moxy 真数据验收。Tab 体感仍卡，需要开发签名包 SwiftUI trace 或补目标页面 ready 埋点，区分首次 View 实例化、TabView 状态提交和数据准备延迟。
- 测试情况：`git diff --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；无签名 iOS generic Debug workspace build PASS；iPad TS 115 Time Profiler 与 Animation Hitches 结果如上。
- 风险与注意事项：保护窗口会暂时忽略来自另一设备的远端版本，这是用户刚明确选择“保留本机”的预期语义；若用户需要保留云端版本，TS 115 不具备安全入口，不应通过删除本地记录或盲覆盖模拟。当前 Instruments 未捕获 hang 不等于用户体感问题不存在。
- 回滚方式：恢复 `applyRemoteSyncRecord` 中仅在内容 / 删除状态不同时保护本地的旧条件，并移除对应回归与文档；不涉及 schema 或远端数据回滚。
- 结论：冲突复活竞态已完成最小代码修复和离线验证；iPad 证据排除了明显主线程 hang / GPU hitch，但没有解释 Tab 的 1–2 秒体感，性能与真数据冲突验收均保持 Acceptance Pending。
- 下一步建议：生成下一 TestFlight，用重庆 Moxy 验证“保留本机 → 推送 → 拉取”不再复活；另以开发签名包采集 SwiftUI trace并结合 ITER-422 页面阶段诊断，再决定 TabView / 页面快照的定点优化。

### ITER-420 账本 SQLite 后台水合
- 日期：2026-07-16
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance / Release Hardening
- 类型：性能 / Bugfix / 测试
- 目标：依据 build 114 的 iPhone / iPad 真机 trace，消除账本首次加载和前台刷新把 SQLite 全量读取、日期解码和 SwiftUI 状态发布堆在主线程上的阻塞。
- 改动范围：`LedgerStore` 的正式 App 根实例初始化与后台刷新、`AutoLedgerRootView` 生命周期协调、`SQLiteTransactionStore` 独立快照 reader、五语加载文案，以及离线性能夹具 / 回归。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、D1 schema、entitlement、定价、ASC metadata、Xcode Cloud workflow、构建 tag 或用户账本数据。
- 完成内容：复核实体 build 114 trace：iPhone 15 Pro 进入账本出现一次约 461.67 ms 主线程 microhang；iPad mini 6 新鲜账本路由出现 5 次约 562-723 ms 主线程 hang。样本调用栈集中在 `sqlite3_step`、`NSISO8601DateFormatter.dateFromString` 和 SwiftUI / ObservableObject 更新，故不再以 iPad 结果替代 iPhone 验收。
- 完成内容：正式根视图改为 `LedgerStore(deferSQLiteStateHydration: true)`；测试、预览和临时 Store 默认保留同步初始化语义。后台 reader 使用已解析的精确 SQLite 文件 URL 建立独立连接，避免与 live store 共用 `db`，读取交易、删除记录、调试记录、订阅、分类修正、商户别名、酒店记录 / 草稿、同步冲突和账本配置后一次性发布到 UI。
- 完成内容：启动、前台、Intent 通知、URL / 酒店 handoff 统一等待 `refreshFromStoreInBackground()`；加载期间显示五语本地化遮罩并禁止空状态交互，iCloud 恢复检查、Watch snapshot、订阅提醒和外部入口处理在水合完成后继续，避免临时空账本被误判为待恢复状态。
- 完成内容：离线回归新增独立 reader 对同一 SQLite 文件的事务、订阅、分类修正、商户别名和账本配置验证，并新增延迟水合 `LedgerStore` 的端到端验证。性能夹具 smoke 同步要求正式根实例启用延迟水合而夹具继续优先使用自身 Store。
- 未完成内容：下一版 TestFlight 仍需在 iPhone 与 iPad 分别采集冷启动、账本 Tab、月报月份切换、数据清洗和 OCR 固定路径 trace；Mac 仍需解锁后补可交互 Time Profiler / SwiftUI / Animation Hitches。当前代码和构建通过不等于真机性能验收完成。
- 测试情况：`git diff --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；无签名 iOS generic Debug workspace build PASS；无签名 Mac Catalyst Debug workspace build PASS。构建仅出现工程既有 Swift 6 迁移、弃用和 MediaPipe Catalyst slice 警告。
- 风险与注意事项：后台读取降低 UI actor 阻塞，但不消除数据量、SQLite I/O 或日期解码的总成本；首次完成前会短暂显示加载状态。若下一版仍出现 slow operation 或 MetricKit hang，须按对应真机路径再次取样，不应继续凭猜测横向重构。
- 回滚方式：将根实例恢复为默认 `LedgerStore()`，并回退后台 snapshot reader / lifecycle await / 加载遮罩与对应回归即可；不涉及用户数据迁移或远端状态回滚。
- 结论：账本全量持久化读取的主线程路径已在正式根实例收口，最小回归与双平台编译通过；下一版已具备进入真机性能验收的条件，Acceptance Pending 保留到 iPhone / iPad / Mac 的实际 trace 完成。
- 下一步建议：以新 TestFlight build 在 iPhone 和 iPad 各自复测同一条固定清单，并将 dashboard 的 source build、慢操作和 MetricKit 诊断与 Instruments trace 对齐后再判断是否移动构建 tag。

### ITER-419 MetricKit 诊断源构建归因
- 日期：2026-07-16
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening / Performance Observability
- 类型：Bugfix / 可观测性 / 测试 / 部署
- 目标：确认 Xcode Cloud 第 114 次构建后的性能状态，并修正 MetricKit 延迟上传诊断被错误归到当前上传构建的问题。
- 改动范围：`AppDiagnosticsAnalyticsMonitor`、`CommonAPIAnalyticsService`、Core analytics allow-list / 聚合、Common API analytics allow-list / Dashboard 聚合、对应测试和发布文档。
- 未改动范围：未修改 SQLite / CloudKit / D1 schema、StoreKit Product ID、Worker API 路径或响应合同、entitlement、签名、定价、ASC metadata、Xcode Cloud workflow、构建 tag 或用户账本数据。
- 完成内容：确认 `xcbuild-v1.7.0` 指向 `8d395c3` 的 Xcode Cloud 第 114 次构建四平台 Archive 与外部 TestFlight 后操作全部成功。production build 114 样本中的 Tab 切换多数低于 1 秒、前台 refresh 均低于 1 秒；另有一条 MetricKit hang，但 Apple 的 payload 会包含前一使用周期诊断，旧事件没有保留每条诊断自己的版本和构建号，因此不能据此判定 build 114 发生挂起。
- 完成内容：MetricKit crash、hang、CPU exception 和 disk write exception 现按每条 `MXDiagnostic.applicationVersion` 与 `metaData.applicationBuildVersion` 分组上报；上传事件仍保留当前 envelope 版本，同时新增 allow-list 字段 `diagnostic_app_version` / `diagnostic_build_number`。Core 与 Worker Dashboard 在诊断类型或操作后显示源版本，例如 `system_hang@1.6.0(109)`，旧事件继续以原有无版本标签展示。
- 完成内容：实体 iPad 已确认在线但安装的仍是 build 109；iPhone 15 Pro 已安装 build 114，但采样时设备由 connected 变为 paired / disconnected；Mac 当时锁屏，无法完成可交互点击。直接启动当前提交的 Mac Catalyst Debug 20,000 条夹具并附加 20.99 秒 Time Profiler，目标路径确认正确，`potential-hangs` 没有超过 250 ms 的记录；该稳态样本不替代 Tab、月份切换和数据清洗的交互 trace。
- 完成内容：Common API staging 已部署 Version ID `cdb33987-e22f-45e2-8476-63ce1e72823d`，staging analytics POST 返回 202，D1 确认同时保留上传 build 114 与诊断源 build 109；production 已部署 Version ID `fadacea8-282e-4849-872d-e52b7176c691`，health 返回 200，受保护 Dashboard 未登录返回 Access 302，未保护 host 返回 403，production D1 读取正常。
- 未完成内容：iPad 需先更新到 build 114，再分别在 iPad 与 iPhone 真机复测冷启动、Tab 切换、月报月份切换、数据清洗和 OCR；Mac 解锁后仍需补可交互 Time Profiler / SwiftUI / Animation Hitches。iPad 结果只作为大屏与大账本参考，不能替代 iPhone 的发布性能门禁。
- 测试情况：`tools/worker/common-api` 执行 `npm run check` PASS（38 tests）；完整 `bash scripts/run_offline_regression.sh` PASS；全新 DerivedData 的 iOS Debug workspace build PASS；全新 DerivedData 的 Mac Catalyst Debug workspace build PASS；`git diff --check` 在提交前最终复核。
- 风险与注意事项：新源版本字段只会出现在新二进制收到并上报的后续 MetricKit payload 中，无法反向补全历史 687 条 production 事件。MetricKit、匿名 duration bucket 和 Instruments 分别回答不同问题，不能只看任一单项宣称性能完全收口。
- 回滚方式：回退两个诊断源字段、MetricKit 分组和 Dashboard key 拼接即可；不涉及数据库迁移或用户数据回滚。
- 结论：构建链路和诊断归因缺陷已收口，现有证据没有证明 build 114 出现系统挂起，但 iPhone / iPad / Mac 的真实交互性能仍保持 Acceptance Pending。
- 下一步建议：iPad 更新至 build 114、iPhone 重新连接且 Mac 解锁后，按设备分别完成固定路径采样；若新 Dashboard 按源构建继续出现慢操作或 hang，再对对应操作做定点优化。

### ITER-418 Release 性能夹具隔离修复
- 日期：2026-07-16
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release / Xcode Cloud
- 类型：Bugfix / 测试
- 目标：修复 Xcode Cloud 第 112 次构建中 iOS 与 macOS Archive 的共同 Release 编译错误，同时保持 Debug 性能夹具行为不变。
- 改动范围：`PerformanceFixtureConfiguration.makeLedgerStoreIfRequested()` 的编译条件，以及长列表静态 smoke 对该 Release 隔离边界的检查。
- 未改动范围：未修改性能夹具数据、正式账本初始化、SQLite / CloudKit schema、StoreKit Product ID、Worker API、entitlement、签名、ASC metadata、定价或 Xcode Cloud workflow。
- 完成内容：通过 ASC API 确认 tvOS 与 visionOS Archive 已成功，iOS 与 macOS 均失败于 `PerformanceFixtureConfiguration.swift:21` 的 `Cannot find 'PerformanceFixtureTransactionStore' in scope`；该 store 仅在 `#if DEBUG` 下声明，但调用点此前仍参与 Release 编译。
- 完成内容：将 Debug-only store 的构造引用纳入同一 `#if DEBUG`，Release 固定返回 `nil`；Debug 的 `--performance-fixture-count` 路径和正式启动逻辑均保持原样。
- 未完成内容：修复提交推送并移动构建标签后，仍需等待 Xcode Cloud 新一轮四平台 Archive 与 TestFlight 后操作结果。
- 测试情况：完整 `bash scripts/run_offline_regression.sh` PASS（含长列表与性能夹具 smoke）；关闭本地签名后，iOS generic Release archive PASS，Mac Catalyst generic Release archive PASS。构建仅出现工程既有的 Swift 6 迁移、弃用和 MediaPipe Catalyst slice 警告。
- 风险与注意事项：Debug-only 工具必须同时隔离声明和所有类型引用；仅跑 Debug build 无法发现此类 Release 编译错误。
- 回滚方式：回退 `makeLedgerStoreIfRequested()` 的编译条件与对应 smoke 即可；不涉及数据或远端状态。
- 结论：iOS / macOS 的共同 Archive 编译 blocker 已在本地 Release 配置收口，可以重新触发 Xcode Cloud。
- 下一步建议：确认新构建的 iOS 与 macOS Archive 越过 `PerformanceFixtureConfiguration.swift`，并继续观察四平台 TestFlight 后操作。

### ITER-417 Xcode Cloud CocoaPods 基线同步
- 日期：2026-07-16
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release / Xcode Cloud
- 类型：Bugfix / 构建治理
- 目标：修复四个平台在 Xcode Cloud `Run ci_post_clone.sh` 阶段同时失败，恢复构建触发链路。
- 改动范围：仅将 `Podfile.lock` 的 CocoaPods 生成器版本从 `1.16.2` 同步到 Xcode Cloud 当前镜像提供的 `1.17.0`。
- 未改动范围：未修改 Pod 依赖版本、spec checksum、Podfile checksum、Swift 业务代码、SQLite / CloudKit schema、StoreKit Product ID、Worker API、entitlement、签名、ASC metadata、定价或 Xcode Cloud workflow。
- 完成内容：确认失败不是性能提交或平台编译造成，而是 CocoaPods `1.17.0` 在 `--deployment` 模式下拒绝使用由 `1.16.2` 生成的锁文件；重试和 `--repo-update` 均无法解决生成器版本元数据差异。
- 未完成内容：修复提交推送并移动构建标签后，仍需等待 Xcode Cloud 四个平台的新一轮 archive 结果。
- 测试情况：本机升级至 CocoaPods `1.17.0` 后重新生成锁文件，Git diff 仅包含 `COCOAPODS` 版本一行；按 Xcode Cloud 的 `CI_PRIMARY_REPOSITORY_PATH` 和脚本路径原样执行 `ci_post_clone.sh` PASS，`pod install --deployment` 报告 `Verifying no changes` 并完成集成。
- 风险与注意事项：未来 Xcode Cloud 再次升级 CocoaPods 时，deployment 模式仍可能要求同步锁文件生成器版本；应先读取首条失败原因，不对确定性版本不匹配进行无效网络重试。
- 回滚方式：回退 `Podfile.lock` 的 `COCOAPODS` 版本即可；不会改变用户数据或依赖版本。
- 结论：本轮根因和最小修复均已验证，可以重新推送 `main` 并移动 `xcbuild-v1.7.0` 触发构建。
- 下一步建议：确认四个平台均越过 `Run ci_post_clone.sh` 后，再判断是否存在真正的 archive 或签名问题。

### ITER-416 iPad / Mac 大账本渲染降耗
- 日期：2026-07-15
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance / Cross-platform QA
- 类型：性能 / 重构 / 测试
- 目标：完成构建前性能代码审计，消除 iPad / Mac 在 20,000 条账本下仍会由 SwiftUI `body` 触发的全量清洗、排序和索引工作。
- 改动范围：`LedgerStore` 数据清洗修订号、iPhone / iPad 数据清洗异步快照、Mac 疑似重复面板、iPad 最近账单与 Mac 默认日期排序、`DataCleaningPreviewPlanner` 重复候选专用入口，以及对应离线回归和静态性能门禁。
- 未改动范围：未修改数据清洗规则、重复判定阈值、免费 / Pro 权益边界、用户数据、SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、entitlement、订阅价格、ASC metadata 或 Xcode Cloud workflow。
- 完成内容：以单调 `dataCleaningRevision` 替代数据清洗页面每次重绘时对全部可见账单、别名、分类修正和忽略项执行的同步 `Hasher`；交易、账本范围和学习配置变化仍会使分析任务失效并刷新。
- 完成内容：iPhone / iPad 数据清洗改为后台构造一次 `DataCleaningPreviewSnapshot`，高级规则直接复用该快照；iPad 受影响账单改为 ID 字典查找。云端辅助关闭或当前非 Pro 时不再构造整份脱敏聚合 payload。
- 完成内容：Mac 账本的疑似重复面板只计算重复候选并在后台刷新，不再为该面板同时构造商户别名、分类和归一化建议；默认日期倒序与 iPad 最近账单复用 `LedgerStore` 已保证的时间顺序，避免重复排序。
- 未完成内容：实体 iPad 当前离线，Mac 主机验证阶段处于锁屏，因而没有补出本轮新的实体 iPad 或可交互 Mac SwiftUI / Animation Hitches trace。该限制保留为 TestFlight 验收项，不把模拟器和构建通过描述为全部真机性能达标。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_long_list_performance_smoke.py` PASS；完整 `bash scripts/run_offline_regression.sh` PASS，包含 20,000 条全量清洗快照与重复候选专用入口；全新 DerivedData 的 iPad Pro 13-inch Simulator Debug workspace build 和 Mac Catalyst Debug workspace build 均 PASS。iPad 以 20,000 条隔离夹具启动后约 3 秒取得首页截图，待处理卡已结束加载。此前同一基线的 Mac Catalyst Time Profiler 已覆盖分析页和连续月份切换，未记录超过 250 ms 的 potential hang；本轮 Mac 进程抽样显示主线程处于空闲事件循环，但锁屏下未把它当作交互验收。
- 风险与注意事项：数据清洗仍需在真实密集导入账本和实体设备上观察 CPU、内存与滚动帧率；后台 detached 分析避免阻塞主线程，但不能消除总计算成本。若 TestFlight dashboard 继续出现 `data_cleaning_open`、`tab_switch` 或 `month_switch` 慢操作，应按对应真实路径补 Time Profiler / SwiftUI / Animation Hitches trace。
- 回滚方式：回退修订号、异步分析状态、重复候选专用入口和排序复用即可；不涉及数据迁移或远端状态。
- 结论：本轮静态性能审计和当前可用的 20,000 条跨平台回归已收口，可以触发下一版 TestFlight 构建；实体 iPad / 解锁 Mac 的交互性能仍需在新构建上完成 Acceptance Pending。
- 下一步建议：新构建先在 iPad 与 Mac 分别复测账本 Tab、数据清洗、月报月份切换和酒店列表；有卡顿再按 dashboard 操作枚举定点采样，不继续无证据横向重构。

### ITER-415 待处理中心大账本降耗
- 日期：2026-07-15
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance / Cross-platform QA
- 类型：性能 / Bugfix / 测试
- 目标：解决 20,000 条隔离账本下 iPhone / iPad 首页待处理摘要持续显示加载、Mac 待处理工作区迟迟没有结果的问题。
- 改动范围：`DataCleaningPreviewPlanner` 的疑似重复候选扫描；`OfflineRegression` 的 20,000 条长列表回归；CHANGELOG、v1.7.0 计划和本日志。
- 未改动范围：未修改重复判定时间窗、文本相似度阈值、待处理分类、用户数据、SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、entitlement、订阅价格、ASC metadata、Xcode Cloud workflow 或构建 tag。
- 完成内容：确认热点来自 `duplicateItems` 对全部交易执行两两比较；20,000 条会形成约 2 亿个组合。交易进入 planner 前已经按时间倒序，现于时间差达到 `max(duplicateWindow, textDuplicateWindow)` 时停止当前内层扫描，因此只检查仍可能命中现有重复规则的邻近时间记录；同时移除每个 pair 只生成一次却仍维护的 `seenPairs` 集合。
- 完成内容：新增 20,000 条、每条相隔 90 分钟的离线回归数据，验证大账本不会产生错误重复候选，也约束后续实现继续按最长重复窗口结束扫描。
- 未完成内容：尚未取得实体 iPad / Mac 的 Time Profiler、SwiftUI 与 Animation Hitches trace；真实账本可能具有密集批量导入、更多唯一商户和附件，仍需在真机专项中分别采样。
- 测试情况：`git diff --check` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；iPad Pro 13-inch Simulator Debug workspace build PASS，以 `--performance-fixture-count 20000` 启动约 2 秒后待处理卡显示无待处理内容；Mac Catalyst Debug workspace build PASS，以同一 20,000 条夹具启动后打开“待处理”，显示“都处理好了”。构建仅出现工程既有并发迁移警告。
- 风险与注意事项：提前停止依赖传入 `duplicateItems` 的交易已按时间倒序，该约束当前由 `buildSnapshot` 固定排序保证；本轮运行态证据证明该热点消失，但不代表 Tab 切换、月报、酒店归档和数据清洗明细在真机上均已达到发布性能目标。
- 回滚方式：回退 `duplicateItems` 的最长时间窗提前停止和 20,000 条离线回归即可；不涉及数据迁移或远端状态。
- 结论：20,000 条下统一待处理中心的持续加载已在 iPad Simulator 与 Mac Catalyst 收口，且不改变重复识别业务口径。
- 下一步建议：使用实体 iPad / Mac 对账本 Tab、月份切换、数据清洗明细、酒店消费和前台刷新执行 Time Profiler / SwiftUI / Animation Hitches 采样；按 trace 结果决定下一处优化，而不是继续凭主观卡顿重构。

### ITER-414 iPad / Mac 隔离性能夹具
- 日期：2026-07-15
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Performance / Cross-platform QA
- 类型：测试基础设施 / 性能验证
- 目标：为 iPad、Mac Catalyst 与真机性能专项提供可重复的 500、5,000、20,000 条脱敏交易数据负载，避免用空账本或用户正式 SQLite 数据判断性能。
- 改动范围：新增 `PerformanceFixtureConfiguration` 与仅 Debug 生效的内存 `TransactionStore`；根视图按启动参数注入夹具账本，并在夹具模式下跳过 CloudKit、Watch、StoreKit、Common API、通知、analytics、剪贴板和外部 handoff 后台流程；新增 `check_performance_fixture_smoke.py` 并纳入离线回归；回填 CHANGELOG 与 v1.7.0 计划。
- 未改动范围：不修改任何 SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、entitlement、定价、ASC metadata、构建 tag 或用户可见业务流程。
- 完成内容：仅在 Debug 启动参数 `--performance-fixture-count 500|5000|20000` 合法时启用确定性内存交易集；夹具不写 SQLite，也不加载 `LedgerStore` 的商户别名、数据清洗历史、账本选择或同步配置，不启动云同步或远端上传，正常启动路径和 Release 构建均保持原行为。
- 未完成内容：尚未获得实体 iPad / Mac Time Profiler、SwiftUI 与 Animation Hitches 的可导出 trace；尚未基于三档数据形成发布级帧率、主线程和内存基线。20,000 条 Simulator 首页截图中的待处理摘要仍显示计算中，需作为下一轮热点单独剖析。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_performance_fixture_smoke.py` PASS；`bash scripts/run_offline_regression.sh` PASS；iPad Pro 13-inch Simulator Debug workspace 单并发完整构建 PASS，并分别以 500 / 5,000 / 20,000 条参数启动到正常首页；Mac Catalyst Debug workspace 单并发完整构建 PASS，并以 5,000 条参数启动运行后主动结束临时进程。Xcode beta 的增量编译曾出现无源码诊断的 `command failed with exit code 0 but produced no further output`，使用全新 DerivedData 完整重编后两平台均取得明确 `BUILD SUCCEEDED`。
- 风险与注意事项：夹具用于性能采样，不代表真实用户账本结构、附件数量或 iCloud 状态；Simulator RSS 波动明显，本轮未把 `ps` 数字作为性能结论。后续结果必须标明数据规模、设备、OS、Instruments 模板和操作路径，不能把 Simulator 可启动性当成真机发布验收。
- 回滚方式：移除 `PerformanceFixtureConfiguration`、根视图的 Debug 注入、`LedgerStore` 的持久配置隔离参数与 smoke 脚本即可；不涉及数据迁移或远端状态。
- 结论：本轮完成，三档隔离负载已可在 iPad 与 Mac 正常 App 界面复用；下一轮直接定位 20,000 条下待处理中心的长时间计算，并补 Time Profiler / SwiftUI / Animation Hitches 证据。

### ITER-413 启动观测纠偏与性能专项第一轮
- 日期：2026-07-15
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening / iPad-Mac-Performance
- 类型：可观测性 / 性能 / 可靠性 / 测试
- 目标：核实 dashboard 显示的 71% 启动成功率是否为真实启动故障，并先消除已经确认的账本刷新和默认搜索冗余，为后续 iPad / Mac Instruments 专项建立可信基线。
- 改动范围：`CommonAPIAnalyticsService`、`AppSessionDiagnosticsService`、Core analytics dashboard snapshot、Common API dashboard 聚合和合同测试；`LedgerStore.refreshFromStore()`、`LedgerAdvancedSearchService`、`LedgerView`；离线回归、CHANGELOG、本日志和 v1.7.0 计划。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、客户端可见 Common API endpoint 合同、entitlement、订阅定价、ASC metadata、Xcode Cloud workflow 或构建 tag；本轮未部署 Worker dashboard，也未改动用户账本数据。
- 完成内容：检查 production D1 聚合样本后确认，旧 dashboard 的 44 次前台启动成功与 18 条 `previous_session_recovery` 事件被同一个“启动成功率”分母混算，才显示 70.967%。这 18 条并非当前启动失败，而是前次 active 会话未写入 background / terminate 标记的恢复提示；同一窗口没有可归类为实际 MetricKit 崩溃的 iOS 诊断信号。
- 完成内容：恢复提示不再伪装为 `al_perf_app_launch` 失败，而保留为 `al_crash_diagnostic` 的 `unclean_active_session/session_marker` 诊断；dashboard 和 Core snapshot 现在分别输出启动完成、异常会话恢复、系统崩溃与挂起。面板明确恢复信号可能来自调试器停止或系统回收，不可当作崩溃率或总启动成功率。
- 完成内容：Debug 与截图模式不再上传 anonymous analytics，避免本机 build、截图管线和 smoke 继续污染 production D1。Release / TestFlight 的正常 upload 路径保持不变。
- 完成内容：`LedgerStore.refreshFromStore()` 对 SQLite store 改为只读取一次 transactions；无关键词且无高级条件的 `LedgerAdvancedSearchService` 直接返回既有已排序数组；账本列表将搜索结果单次计算后复用到 List 和 footer，减少 Tab 切换、前台刷新和 SwiftUI 重绘时的同步工作。
- 未完成内容：尚未完成真实 iPad / Mac Instruments capture，也未建立 500、5,000、20,000 条脱敏数据集的操作基线；因此本轮只能证明观测口径与两处静态热点已修正，不能声称设备级卡顿已完全解决。
- 测试情况：`git diff --check` PASS；`tools/worker/common-api` 执行 `npm run check` PASS（38 tests）；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/autoledger-perf-ios build` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/autoledger-perf-mac build` PASS。
- 风险与注意事项：新的 dashboard 代码尚未部署，线上页面暂时仍会显示旧的 71% 指标；部署后也需要等待新的 Release / TestFlight 样本累积，历史 Debug / legacy recovery 行不会自动消失。会话恢复仍是有价值的稳定性预警，但应结合 MetricKit、用户实际日志和 Instruments 判断，不能独立作为 crash KPI。
- 回滚方式：可分别回退 dashboard metric 映射、Debug analytics guard 和三处本地性能优化；不涉及数据迁移、D1 schema 或远端状态回滚。
- 结论：71% 不是确认的 App 启动成功率问题，而是仪表盘语义错误。专项的下一实际门槛是 iPad / Mac 真机性能采样与大数据量回归，而非根据旧单一百分比继续推断崩溃率。
- 下一步建议：先部署 Common API dashboard 纠偏并等待 Release 样本；同时在 iPhone / iPad 使用 Time Profiler、SwiftUI 和 Animation Hitches，Mac Catalyst 使用 Time Profiler、SwiftUI，分别采集冷启动、账本 Tab、月报月份切换、酒店消费、数据清洗和前台刷新；对 500 / 5,000 / 20,000 条脱敏交易记录建立 p50 / p95 基线后，再决定是否做 debug records 分页或 SQLite 投影优化。

### ITER-412 非 entitlement Debug 构建账本与 CloudKit 启动兜底
- 日期：2026-07-15
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening / Local Debug
- 类型：Bugfix / 可靠性 / 测试
- 目标：修复本地直接启动的 Debug 包在未具备 App Group 或 iCloud entitlement 时，账本打不开并可能在启动后 CloudKit 同步崩溃的问题。
- 改动范围：`SQLiteTransactionStore` 的默认目录选择与可写性验证；`LedgerCloudKitSyncAdapter` 的 macOS / Mac Catalyst iCloud container entitlement 检查；`LedgerStore` 的 CloudKit 创建前 guard；离线回归中的 CloudKit adapter stub；CHANGELOG 与本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、ASC metadata、entitlement 配置、订阅定价、Xcode Cloud workflow 或构建 tag。
- 完成内容：默认 SQLite 目录仍优先使用 App Group；但对于 `containerURL` 可返回、实际 sandbox 写入却被拒绝的未签名 Debug 包，会在文件夹创建或最小写入探测报 `EACCES` / `EPERM` / `ENOENT` 等容器不可用错误时，回退到该包独立的 Application Support 目录。磁盘满、数据库损坏等其他错误不会被静默掩盖。
- 完成内容：macOS / Mac Catalyst 上所有实际创建 `CKContainer.default()` 的账本同步路径均先检查 `com.apple.developer.icloud-container-identifiers` 是否包含默认 container；缺失 entitlement 时仅保留本地账本并跳过 CloudKit，而不是触发 Objective-C exception 导致进程退出。原生 iOS 沿用正常代码签名构建路径，因为 `SecTask` entitlement inspection 不在 iOS SDK 的公开接口中。
- 完成内容：带开发签名的 Mac Catalyst Debug 包继续打开 App Group 中既有 520 条账本数据；未签名 Debug 包可首次启动、等待启动同步超过 7 秒、退出并再次启动，均不再出现数据库提示或崩溃，且使用独立开发账本，不读取或修改正式 App Group 数据。
- 未完成内容：未执行真机 iPhone Debug 运行态验证；应在正常开发签名或下一次 Xcode Cloud 构建中补一条 iOS 实机证据。
- 测试情况：`bash scripts/run_offline_regression.sh` PASS；未签名 Mac Catalyst Debug workspace build PASS，并完成首次与二次启动运行态验证；带开发签名 Mac Catalyst Debug workspace build PASS，并验证 App Group 账本读取；两个 iOS generic 无签名构建最初均在 Xcode beta 的无诊断 `SwiftCompile` exit 65 处失败。将 `SecTask` 限定为 macOS / Mac Catalyst 后，最终 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` PASS；`git diff --check` 待本日志写入后最终复核。
- 风险与注意事项：未签名 Debug 的独立 Application Support 数据不是生产账本迁移目标，也不会自动同步到 iCloud；具备正式 App Group / iCloud entitlement 的 Development、TestFlight 与 App Store 构建继续按原路径运行。若新的目标新增 CloudKit container，需同步更新该 identifier 检查。
- 回滚方式：回退本轮 SQLite 目录探测、CloudKit entitlement guard 与离线 stub 即可；无数据迁移或远端状态需要回滚。
- 结论：本轮已把“本地账本暂不可用”和启动后 CloudKit abort 的两个独立根因收口为可恢复的 Debug 路径，正式签名数据路径保持不变。
- 下一步建议：用户用本轮新的 Debug 包再复测一次账本 tab、设置页与启动后的 iCloud 状态；若仍出现崩溃，保留对应 `.ips` 报告以确认是否为不同调用链。

### ITER-411 云端水单 TestFlight 权益环境修复
- 日期：2026-07-11
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Personal Pro / Cloud Inbox
- 类型：Bugfix / Worker / UI / 部署
- 目标：定位云端水单收件箱已开启但刷新返回 `403 server_entitlement_required` 的原因，修复 TestFlight 权益校验并确认现有专属邮件地址没有失效。
- 改动范围：`hotel-folio-inbox` Worker App Store Server API 环境路由与测试；`HotelFolioInboxClient` 结构化错误；中繁英日韩文案；云收件箱 entitlement smoke；版本计划、CHANGELOG 和本日志。
- 未改动范围：未修改 D1、SQLite 或 CloudKit schema，未修改 StoreKit Product ID、ASC metadata、entitlement、订阅价格、Xcode Cloud workflow 或构建 tag；未开启 production 未验证 token claim。
- 完成内容：确认专属地址记录仍为 active，已有历史候选成功转换，Bearer API 当前返回 200；Cloudflare Email Routing、MX、SPF 和 Worker health 正常。地址本身可继续使用，当前待处理候选为 0。
- 完成内容：确认错误根因是 TestFlight JWS 标记为 Sandbox，而 Worker 固定访问 Production App Store Server API，Apple 返回 404 后被映射为服务端权益不足。Worker 现在按 JWS `environment` 选择 Apple host，旧 payload 只在 404 时回退另一个环境。
- 完成内容：App 不再向终端用户展示 Worker 原始 JSON，服务端暂时无法确认 Pro 时给出可操作的本地化提示；现有地址和手动导入不受该错误影响。
- 未完成内容：没有发送一封新的测试邮件，也无法在命令行伪造用户 TestFlight 的真实 StoreKit signed transaction；最终领取复测需用户在新 App 二进制中恢复购买后重试。
- 测试情况：Worker `npm run typecheck && npx vitest run` PASS（29 tests）；`python3 scripts/check_cloud_inbox_entitlement_smoke.py` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；production health、Email Routing、MX / SPF、现有地址 API smoke PASS；iPhone 17 Pro Simulator与 Mac Catalyst Debug workspace build 均 PASS。staging Version ID `a02365d5-87c6-4e88-9932-f224b291570a`，production Version ID `162ee8c7-db7b-48df-8cfb-3de0024b94a9`。
- 风险与注意事项：线上 App Store Server API 仍要求有效 Apple JWS 和生产 secrets；客户端本地 Pro gate 不是服务端安全边界。旧地址没有独立 access token，但 Worker 保留兼容读取，后续可在用户主动重新领取时迁移。
- 回滚方式：回退 Worker 环境选择 helper、客户端结构化错误和五语 key，再部署上一 Worker version；无数据迁移回滚。
- 结论：截图中的 403 根因已修复并上线，现有专属邮件地址可继续收信和访问；剩余是真实 TestFlight JWS 的用户侧重试证据。
- 下一步建议：新二进制安装后在 TestFlight 恢复购买并刷新一次；若仍失败，记录新的 reason 和 transaction environment，不重新领取或删除现有地址。

### ITER-410 高级搜索交互收口
- 日期：2026-07-11
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Personal Pro / Search
- 类型：UI / 交互 / 测试
- 目标：让高级搜索的每组筛选条件都显式启用，并通过清晰的底部按钮一次性应用，避免调整条件时结果隐式变化。
- 改动范围：`LedgerAdvancedSearchSheet` 草稿状态、金额 / 分类 / 来源 / 账本开关、底部应用按钮、保存条件恢复、中繁英日韩文案、静态 smoke、版本计划、CHANGELOG 和本日志。
- 未改动范围：未修改高级搜索 Core 合同、SQLite / CloudKit schema、StoreKit Product ID、ASC metadata、entitlement、订阅价格、Worker API、Xcode Cloud workflow 或构建 tag。
- 完成内容：金额区间、分类、来源和账本默认关闭并折叠；日期起止继续独立控制；关闭的条件组在应用前清空，不会以不可见状态继续过滤。
- 完成内容：搜索面板使用本地草稿，点击底部“应用搜索条件”后才提交并关闭；取消、返回或手势关闭不影响当前结果，清除只重置面板草稿；载入常用搜索会同步恢复开关。
- 未完成内容：本轮未增加 Mac 专用搜索工具栏、跨设备保存条件或新的筛选字段。
- 测试情况：`python3 scripts/check_advanced_search_ui_smoke.py` PASS；五语本地化覆盖与 `plutil -lint` PASS；完整 `bash scripts/run_offline_regression.sh` PASS；iPhone 17 Pro Simulator与 Mac Catalyst Debug workspace build 均 PASS；`git diff --check` PASS。
- 风险与注意事项：高级搜索继续使用本地 Pro UI gate；基础关键词搜索保持免费并始终可见。
- 回滚方式：回退 `LedgerAdvancedSearchSheet` 草稿 / toggle / apply 改动、五语 key 和 smoke 约束即可；无数据迁移。
- 结论：高级搜索从“修改即生效”收口为显式启用、显式应用的可预期交互。
- 下一步建议：TestFlight 观察常用条件载入、金额区间和分类组合的操作完成率，再决定是否增加 Saved Views 快捷入口。

### ITER-409 统一待处理中心第一版
- 日期：2026-07-11
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Personal Pro / Workflow
- 类型：能力增强 / UI / 测试
- 目标：不新增拥挤的移动端 Tab，把现有导入、复核、去重、订阅异常和智能整理能力串成一个统一待处理入口，同时保留免费版完整手动路径。
- 改动范围：新增 `PendingActionCenterPlanner`、iPhone 记账 Tab 待处理卡片与列表、iPad / Mac 待处理工作区、中繁英日韩文案、离线回归与静态 smoke；更新 v1.7.0 计划、CHANGELOG 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、ASC metadata、entitlement、订阅价格、Xcode Cloud workflow 或构建 tag。
- 完成内容：Core 聚合本机 OCR 待确认、酒店水单待复核、疑似重复、订阅异常和智能整理建议，按优先级与固定业务顺序生成空分类已过滤的快照。
- 完成内容：iPhone 继续复用“记账”Tab，待处理中心本身免费可见并跳转既有手动处理流程；订阅异常和智能整理等自动化分组继续显示 Pro 标记，不把基础导入或历史数据改成付费。
- 完成内容：iPad / Mac 新增独立侧栏工作区，复用同一快照和现有导入、酒店、订阅与数据清洗页面；聚合计算基于状态快照在后台执行，避免 SwiftUI 重绘同步扫描整本账本。
- 未完成内容：云收件箱远端候选、批量邮箱候选和月结缺资料项尚未进入统一队列；OCR 待确认仍是内存单条状态；本轮没有新增自动正式入账。
- 测试情况：`python3 scripts/check_pending_action_center_smoke.py` PASS；五语本地化覆盖与 `plutil -lint` PASS；`bash scripts/run_offline_regression.sh` PASS；`git diff --check` PASS；iOS Simulator、iOS generic 和 Mac Catalyst generic Debug workspace build 均 PASS。验证前从同版本 DerivedData 恢复了被磁盘清理误删的 ignored CocoaPods `MediaPipeTasksGenAIC` simulator binary，源文件与恢复文件 SHA-256 一致；本轮临时 DerivedData 验证后已清理。
- 风险与注意事项：当前 snapshot revision 使用相关集合数量、规则数量和最近导入状态触发刷新；远端队列接入前不能把待处理中心宣传成完整跨设备 Inbox。
- 回滚方式：回退新增 Core planner、Inbox / iPad 工作区入口、五语 key、回归脚本和文档即可；无数据迁移或远端合同回滚。
- 结论：统一待处理中心第一版完成，现有 Pro 能力从分散入口开始形成“导入 → 待确认 → 去重 → 整理 → 异常”的本机处理闭环。
- 下一步建议：先观察 TestFlight 中待处理入口的发现率和处理完成率，再为云收件箱候选与月结检查项设计可持久化队列合同。

### ITER-408 只读审计问题修复
- 日期：2026-07-10
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Hardening
- 类型：Bugfix / 安全 / 性能 / 测试 / 治理
- 目标：修复严格只读代码审计识别出的数据一致性、崩溃、明文传输、令牌暴露、分析事件滥用、主线程计算和产品说明偏差。
- 改动范围：`LedgerStore`、SQLite / CSV / OCR 回归、数据清洗视图与规则计划器、外部识别和邮箱 TLS 合同、云水单收件箱 Worker、Common API analytics、五语 App / InfoPlist 文案、`AGENTS.md`、CHANGELOG 与本日志。
- 未改动范围：未修改 App SQLite / CloudKit schema、StoreKit Product ID、ASC metadata、entitlement、订阅价格、CloudKit Production schema、Xcode Cloud workflow 或构建 tag。
- 完成内容：SQLite 初始化失败会注入明确的不可用 store 并在根界面提示，不再伪装为空账本；手动记账和 OCR 持久化失败不会提前污染内存 / 最近导入状态；CSV 重复规范化列名改为可恢复错误。
- 完成内容：数据清洗建议和高级规则计划改为基于单次快照在后台计算，避免 SwiftUI getter 反复扫描账本；SQLite busy timeout 和退避缩短为有界等待，降低主线程被数据库锁长时间阻塞的风险。
- 完成内容：云收件箱邮件路由 token 与 API access token 分离，API 只接受 Bearer token；analytics 要求客户端 `event_id`，D1 使用 `INSERT OR IGNORE` 幂等写入，并增加 Cloudflare Rate Limiting binding。
- 完成内容：外部识别远端只允许 HTTPS，HTTP 仅允许 loopback 调试；旧 IMAP 配置自动升级为 TLS，UI 不再允许关闭 TLS；麦克风、语音识别权限和账本操作状态补齐中繁英日韩本地化，App 内语言 override 可覆盖动态状态文案。
- 完成内容：非正常会话恢复同时写入失败的 launch performance 事件，修正启动成功率只统计成功样本的问题；工程说明改为真实的 Swift 语言模式边界，未为追求名义 Swift 6 而一次性强切所有 App Intent / Extension。
- 未完成内容：本轮未做真机 UI smoke；主 App / Extension 的 Swift 6 语言模式迁移仍需独立迭代。
- 测试情况：`git diff --check` PASS；`bash scripts/run_offline_regression.sh` PASS；Common API `npm run typecheck && npx vitest run` PASS（38 tests）；hotel-folio-inbox `npx tsc --noEmit && npx vitest run` PASS（28 tests）；iOS Simulator Debug workspace build PASS；Mac Catalyst Debug workspace build PASS。staging / production D1 migration 均成功；production health / manifest / analytics / hotel health smoke PASS，同一 analytics `event_id` 重试后 D1 count 为 1，production 无签名 claim 返回 403，dashboard 未登录返回 Access redirect；production `access_token_hash` 列和唯一索引查询确认存在。
- 风险与注意事项：收件箱 token 分离保留旧记录兼容读取，但新 claim 依赖 migration `0003` 的 `access_token_hash` 列；analytics 幂等与限流依赖 migration `0004` 和 `ANALYTICS_RATE_LIMITER` binding，不能只部署代码。主 App / Extension 仍是 Swift 5 语言模式，后续 Swift 6 迁移应按 target 分批完成并清零并发警告。
- 回滚方式：App 侧可按模块回退持久化提示、后台分析和 TLS / 本地化修改；Worker 侧先回退代码再回退 binding。D1 新列和唯一索引可保留，不需要破坏性回滚。
- 结论：审计中可在当前版本安全收口的问题已完成修复，通过本地门禁并部署到 staging / production。Common API staging Version ID `f2b113c0-6481-497c-9621-574caa1fbe34`、production `825273e1-0fde-4d6d-a318-fb7424e26b45`；酒店收件箱 staging `eaad8de3-b04d-4850-a482-490c468b6d81`、production `c0e329bb-c8d6-42d6-933f-a209ebaa6c7d`。
- 下一步建议：在下一次 App 二进制构建中做真机回归，并另开独立迭代逐 target 推进 Swift 6 语言模式。

### ITER-407 崩溃与性能观测补齐
- 日期：2026-07-09
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Governance / Observability
- 类型：能力增强 / Worker 合同 / 隐私治理
- 目标：在现有产品交互匿名事件基础上，补齐 App 崩溃数据和性能数据埋点，并让 Common API dashboard 能展示崩溃信号、慢操作和性能操作分布，帮助定位真机卡顿与 App Review / TestFlight 崩溃问题。
- 改动范围：新增 `AppDiagnosticsAnalyticsMonitor`；扩展 `CommonAPIAnalyticsService`、`AutoLedgerAnalyticsInstrumentation`、`PrivacyInfo.xcprivacy`、关键 App 生命周期 / Tab / 月报 / 数据清洗 / store refresh 调用点；扩展 `common-api` analytics allow-list、dashboard 聚合、HTML 模块和 Worker 合同测试；更新 `v1.7.0-plan` 与 CHANGELOG。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、ASC metadata、Worker D1 schema、entitlement、订阅价格、Xcode Cloud workflow、截图 / App Preview 或构建 tag。
- 完成内容：App 端通过 MetricKit 订阅崩溃、hang、CPU exception、disk write exception 和每日 metric payload；通过会话状态标记识别上次 active session 未正常进入 background / terminate 的恢复信号。
- 完成内容：Tab 切换、月报月份切换、数据清洗页面打开和前台 / 外部入口 store refresh 记录性能诊断事件，只上传 surface、operation、duration bucket、count bucket、severity、result 和 error code，不上传金额、商户、账单、OCR、PDF 或设备标识。
- 完成内容：Worker allow-list 新增 `al_crash_diagnostic` 和 `al_performance_diagnostic`；dashboard 新增崩溃诊断、慢操作和性能操作分布模块；manifest 继续声明 analytics 只接受匿名 workflow / performance bucket / error code。
- 完成内容：`PrivacyInfo.xcprivacy` 已声明 Crash Data、Performance Data 和 Product Interaction 均用于 Analytics，not linked，not tracking。
- 未完成内容：本轮没有运行 Instruments，也没有做真机性能剖析；dashboard 已登录后的真实数据视觉复核仍需用户在 Cloudflare Access 会话下查看。
- 测试情况：`git diff --check` PASS；`plutil -lint AutoLedger/AutoLedger/PrivacyInfo.xcprivacy` PASS；`cd tools/worker/common-api && npm run check` PASS，覆盖 `wrangler types`、`tsc --noEmit` 和 36 个 Vitest 合同测试；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` PASS。已部署 staging Version ID `fa4beb82-b11d-4092-8a98-8845374376be`、production Version ID `adf28663-7b67-430b-bd21-df0929c52fbe`；线上 smoke 确认 production manifest HTTP 200、新 crash / performance synthetic 事件写入 HTTP 202、production D1 可查到 `al_crash_diagnostic` 和 `al_performance_diagnostic`，`getautoledger.app/dashboard/data` 未登录返回 Cloudflare Access 302，`api.darkrio326.top/dashboard/data` 未保护 host 伪造邮箱头返回 403。
- 风险与注意事项：MetricKit 诊断存在系统延迟，无法替代 Xcode Organizer / Instruments 的精确崩溃和性能分析；当前事件只用于聚合诊断和发布判断，不应用于用户画像、广告追踪、跨 App 识别或自动化决策。
- 回滚方式：回退新增 App 诊断 monitor、App 调用点、Core catalog / tests、Worker allow-list / dashboard / tests、`PrivacyInfo.xcprivacy` 与文档即可；无数据库 schema 或远端数据迁移。
- 结论：本轮完成，AutoLedger dashboard 已能接收并聚合崩溃和性能诊断信号，为后续真机卡顿排查提供最小闭环。
- 下一步建议：在最新 TestFlight build 上复测卡顿路径；如果 dashboard 显示 `month_switch`、`tab_switch` 或 `refresh_from_foreground` 慢操作升高，再用 Instruments 的 Time Profiler / SwiftUI 模板针对性抓样。

### ITER-406 匿名观测事件扩展
- 日期：2026-07-09
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Governance / Observability
- 类型：能力增强 / 治理 / Worker 合同
- 目标：补全隐私安全匿名观测事件，让 dashboard 能判断大家怎么用 App、主要卡点在哪里，并为未来年度总结提供不指向个人的 App 层综合数据。
- 改动范围：`AutoLedgerAnalyticsInstrumentation` 事件目录与指标快照；`CommonAPIAnalyticsService`；首页 / 实时 OCR / 截图导入 / 确认页 / 酒店水单 / 月报 / 账本搜索 / 数据清洗 / Pro 页面 / Pro 与 Support 购买 / iPad PDF 导入等 App 端匿名事件接入；`common-api` analytics allow-list、dashboard 聚合和 Worker 合同测试；`PrivacyInfo.xcprivacy`；README、`v1.7.0-plan`、CHANGELOG。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit Product ID、ASC metadata、Worker D1 schema、entitlement、订阅价格、Xcode Cloud workflow、截图 / App Preview 或构建 tag。
- 完成内容：App 端新增 fire-and-forget 匿名事件：功能入口、导入开始 / 完成、确认页保存 / 放弃、汇率查询、酒店 PDF、Common API 状态、Pro gate、Pro / Support 购买、月结包、月报分享和数据清洗入口；上传失败只写本地 log，不阻断用户流程。
- 完成内容：Worker analytics allow-list 新增 `al_feature_surface_opened`，dashboard 聚合新增 `feature_surface_open_count`、`hotel_pdf_completion_rate`、`common_api_status_top_n` 和 `pro_gate_action_count`，用于定位入口使用、酒店导入完成率、基础设施状态和 Pro gate 行为分布。
- 完成内容：隐私边界继续禁止金额、商户、截图、PDF、邮箱、酒店标识、房号、精确位置、OCR / rawText、交易 ID、StoreKit transaction id、支付数据和任何可还原个人账本的信息；`PrivacyInfo.xcprivacy` 已补充 Product Interaction / Analytics，not linked，not tracking。
- 完成内容：文档明确个人年度总结仍以本机账本和用户主动生成内容为主体；服务端 analytics 只可引用全体匿名聚合口径作为 App 层综合背景，不做个人画像、跨 App 识别或自动化决策输入。
- 未完成内容：本轮没有做已登录 dashboard 人工截图复核；ASC App Privacy、官网隐私政策和 Review Notes 的 Product Interaction / Analytics 文案仍需发布前人工同步确认。
- 测试情况：`git diff --check` PASS；`plutil -lint AutoLedger/AutoLedger/PrivacyInfo.xcprivacy` PASS；`cd tools/worker/common-api && npm run check` PASS，覆盖 `wrangler types`、`tsc --noEmit` 和 36 个 Vitest 合同测试；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` PASS。已部署 staging Version ID `0f1e2505-4116-4c9d-a6f9-8767d7531475`、production Version ID `bad6f789-d8fd-49d2-abf3-5e332a2b2a2c`；线上 smoke 确认 production manifest 200、新 `al_feature_surface_opened` 写入 202、`getautoledger.app/dashboard/data` 未登录被 Cloudflare Access 302 拦截、`api.darkrio326.top/dashboard/data` 未保护 host 返回 403。
- 风险与注意事项：当前事件面已包含 Product Interaction，发布前必须确保 ASC App Privacy、官网隐私政策和 Review Notes 不再只写 Performance Data；dashboard 只应在 Cloudflare Access 保护下查看聚合数据，不导出 raw event rows 或 payload JSON。
- 回滚方式：回退本轮 App 端事件调用、`CommonAPIAnalyticsService` 扩展、Core catalog / tests、Worker allow-list / dashboard 聚合 / tests、`PrivacyInfo.xcprivacy` 与文档即可；无数据库 schema 或远端数据迁移。
- 结论：本轮完成，AutoLedger 已具备第一版匿名 App 层观测闭环，可支撑发布前卡点判断和未来年度总结的综合背景数据。
- 下一步建议：用 Zero Trust 会话查看 dashboard 真实数据；同步 ASC App Privacy / 官网隐私政策 / Review Notes，再决定是否把跨 App 总面板放到 `dashboard.darkrio326.top`。

### ITER-405 Common API dashboard 入口与样式收口
- 日期：2026-07-09
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Governance / Common API
- 类型：Bugfix / Worker 安全 / UI 对齐
- 目标：修复 `getautoledger.app/dashboard` 裸路径没有命中 Cloudflare Zero Trust `dashboard/*` 规则时，面板壳可直接加载但数据接口被 Access 拦截导致“暂不可用”的问题，并把 AutoLedger dashboard 页面风格与 AutoNotice dashboard 统一。
- 改动范围：`tools/worker/common-api` dashboard 路由、dashboard HTML / CSS、manifest dashboard URL、Worker 合同测试、版本计划、CHANGELOG。
- 未改动范围：未修改 App Swift 业务代码、App 端 analytics 采集面、D1 schema、CloudKit schema、StoreKit Product ID、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、entitlement、订阅价格或构建 tag。
- 完成内容：`GET /dashboard` 和 `HEAD /dashboard` 现在返回 302 到 `/dashboard/`；`/dashboard/` 继续服务 HTML shell；manifest `analyticsDashboard.url` 改为 `https://getautoledger.app/dashboard/`。
- 完成内容：dashboard HTML 改为与 AutoNotice 统一的浅色渐变背景、应用图标、顶部工具栏、折叠卡片、总览四卡、最小指标表、版本分布、导入错误、隐私拦截和隐私边界布局；仍只读取既有 `/dashboard/data` 聚合合同。
- 完成内容：测试明确覆盖裸路径跳转、trailing-slash HTML shell 分离和新版页面结构，避免 Access 规则只覆盖 `dashboard/*` 时再次出现裸路径绕过。
- 完成内容：`v1.7.0-plan` 记录后续可在 `dashboard.darkrio326.top` 建立跨 App 总面板，汇总 AutoLedger、AutoNotice 和其他 App 的匿名聚合指标；该方向仍必须沿用 Cloudflare Access、聚合口径和各 App 独立数据边界。
- 未完成内容：本轮没有做已登录浏览器截图复核；需要用户在 Cloudflare Access 会话下人工确认新版页面视觉是否满足预期。
- 测试情况：在 `tools/worker/common-api` 执行 `npm run check` 通过，覆盖 `wrangler types`、`tsc --noEmit` 和 36 个 Vitest 合同测试；执行 `git diff --check` 通过。已部署 staging Version ID `73d1f00f-5c1b-490e-9e8f-83cee91da34b`、production Version ID `8e0aa74b-06ad-4f5e-a1d4-db2a303f5894`。线上 smoke 确认 `https://getautoledger.app/dashboard` 返回 HTTP 302 并跳转 `/dashboard/`，`https://getautoledger.app/dashboard/` 和 `https://getautoledger.app/dashboard/data` 未登录均返回 HTTP 302 到 Cloudflare Access login；`https://api.darkrio326.top/dashboard/data` 即使携带伪造 `cf-access-authenticated-user-email` 也返回 HTTP 403；production manifest 返回 `analyticsDashboard.url=https://getautoledger.app/dashboard/` 和 `retentionDays=90`。
- 风险与注意事项：Cloudflare Access 仍是主防线；裸路径跳转只是让入口路径和 Zero Trust 规则保持一致，不替代 `/dashboard/data` 的 Worker 侧 host guard。跨 App 总面板只是后续方向，本轮不新增跨 App 数据聚合接口。
- 回滚方式：回退本轮 Worker 路由、测试和文档改动即可；无 D1 schema 或远端数据迁移。
- 结论：本轮完成，AutoLedger dashboard 入口、Access 覆盖和页面风格已收口到与 AutoNotice 一致的运营面板形态。
- 下一步建议：用浏览器登录 Cloudflare Access 后查看 `https://getautoledger.app/dashboard/`，确认真实数据下的视觉密度和模块顺序；后续若建设 `dashboard.darkrio326.top`，先设计跨 App manifest / summary 合同，不直接打通 raw event rows。

### ITER-404 Common API analytics dashboard Access 收口
- 日期：2026-07-09
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Governance / Common API
- 类型：治理 / Worker 安全
- 目标：在 Cloudflare Zero Trust Access 已保护 `getautoledger.app/dashboard/*` 的基础上，补齐 Worker 侧防伪造邮箱头和 analytics 数据保留期，收口 `GOAL-2360` 发布门禁。
- 改动范围：`tools/worker/common-api` analytics 写入、dashboard data guard、Cloudflare Access helper、wrangler public vars、Worker 合同测试和 Common API README；同步更新 `versions/v1.7.0-plan.md` 与 CHANGELOG。
- 未改动范围：未修改 App Swift 业务代码、App 端 analytics 采集面、SQLite / CloudKit schema、StoreKit Product ID、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、entitlement、订阅价格或构建 tag。
- 完成内容：production `/dashboard/data` 现在要求 Cloudflare Access 保护 host 上的允许邮箱头或有效 Access JWT；`api.darkrio326.top/dashboard/data` 等未保护 host 即使伪造 `cf-access-authenticated-user-email` 也会被拒绝。
- 完成内容：analytics 写入返回 90 天默认保留期，并在 Worker 运行时通过 `waitUntil` 异步清理过期 `autoledger_analytics_events`；dashboard JSON / manifest 返回 Access 和保留期说明。
- 完成内容：文档明确 dashboard 仍只展示聚合指标，不返回 raw rows、payload JSON、金额、商户、截图、PDF、邮箱、酒店标识、OCR 文本、StoreKit transaction id 或支付数据。
- 未完成内容：本轮没有通过浏览器完成已登录 Cloudflare Access 后的 dashboard 人工查看；ASC App Privacy、官网隐私政策和 Review Notes 的 analytics 口径仍需发布前人工确认。
- 测试情况：在 `tools/worker/common-api` 执行 `npm run check` 通过，覆盖 `wrangler types`、`tsc --noEmit` 和 35 个 Vitest 合同测试；执行 `git diff --check` 通过。远端执行 `npm run d1:migrate:staging` 成功应用 `0002_autoledger_analytics_events.sql`，`npm run d1:migrate:production` 返回无待迁移项。已部署 staging Version ID `36d60c5a-d317-4667-a215-3693b996427e`、production Version ID `8dd2fd62-06e2-46cc-8b64-43deb2cefbbf`。线上 smoke 确认 staging / production manifest HTTP 200 且 `analyticsDashboard.retentionDays=90`；production `POST /v1/analytics/events` 返回 HTTP 202、`accepted=1`、`retentionDays=90`；`https://api.darkrio326.top/dashboard/data` 即使携带伪造 `cf-access-authenticated-user-email` 也返回 HTTP 403；`https://getautoledger.app/dashboard/data` 未登录返回 HTTP 302 到 Cloudflare Access login。
- 风险与注意事项：Cloudflare Access 应继续作为主防线；Worker 侧邮箱头信任只在 `ACCESS_TRUST_EMAIL_HEADER=true` 且请求 host 属于 `ACCESS_PROTECTED_HOSTS` 时生效。若后续要完全依赖 JWT 强校验，需要补充当前 Access application 的 `ACCESS_AUD`。
- 回滚方式：回退本轮 `tools/worker/common-api` 代码和 wrangler vars，以及对应文档 / 日志改动即可；无 D1 schema 迁移。
- 结论：本轮完成，Common API analytics dashboard 已补齐 production Access host guard、防伪造邮箱头和默认保留期。
- 下一步建议：用浏览器登录 Cloudflare Access 后确认 dashboard 数据页可见，并在 ASC App Privacy、官网隐私政策和 Review Notes 中保持 Performance Data / Analytics、not linked、not tracking 的一致口径。

### ITER-403 个人 Pro 文档与产品口径收口
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Docs / Product Positioning
- 类型：文档 / 治理
- 目标：让 repo 中 AutoLedger 个人 Pro 说明与当前实现一致，统一为“本地优先个人账本 + 自动化导入 + 酒店水单归档”和“免费版手动完成，Pro 自动整理”。
- 改动范围：README 顶层定位；`docs/product/autoledger-personal-pro-design.md` 当前 Pro 能力与后续方向；新增 `docs/product/autoledger-personal-pro-roadmap.md`；`docs/operations/pro-access-audit.md` 本地 gate / server-verified 边界；`docs/operations/iap-support.md` Pro / Support Developer 双线说明；`versions/v1.7.0-plan.md` 个人 Pro 后续路线图；CHANGELOG 本轮记录。
- 未改动范围：未修改 Swift 业务代码、SQLite / CloudKit schema、StoreKit Product ID、Worker API 合同、entitlement、Pro 定价策略、ASC 自动提交逻辑或构建 tag。
- 完成内容：免费版完整手动路径、当前 9 项 Pro 自动化能力、Pro 到期不锁历史数据、云端水单收件箱服务端验证和后续 P0 / P1 / P2 路线图已经在文档中对齐。
- 未完成内容：未重新生成 App Store 截图 / App Preview，未提交 ASC 元数据，未做 UI 真机截图。
- 测试情况：`git diff --check` PASS。本轮只改 Markdown / 文案源文件，不运行完整 Xcode build。
- 风险与注意事项：本轮最初在 `/tmp/AutoLedgerRio-docs-work` 临时副本中完成并推送，因为原工作树读取文件时持续返回 `Interrupted system call`；2026-07-09 原目录恢复后已 fast-forward 到远端提交并合并回本地未提交文档更新。
- 回滚方式：回退本轮 Markdown / 文案源文件改动，删除新增 `docs/product/autoledger-personal-pro-roadmap.md` 即可。
- 结论：文档口径完成收口，未引入功能或数据结构变更。
- 下一步建议：后续 Pro 页面、ASC 文案和 v1.7.0 计划变更继续同步回 `docs/product/autoledger-personal-pro-roadmap.md` 和 `docs/operations/pro-access-audit.md`。

### ITER-402 v1.7.0 文档与工程现状对齐
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Documentation / Release Governance
- 类型：文档 / 治理
- 目标：把新的后续方向和当前工程状态回填到当前版本文档，避免 Pro 页面、analytics 代码、数据清洗实现状态和 `v1.7.0-plan` 脱节。
- 改动范围：更新 `versions/v1.7.0-plan.md`、四语 README、`CHANGELOG.md` 和本迭代日志。
- 未改动范围：未修改 App / Worker 代码、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、MARKETING_VERSION、build number、commit tag 或 Cloudflare 配置。
- 完成内容：`v1.7.0-plan` 新增隐私安全发布观测主线和 `GOAL-2360`，补齐 analytics allow-list、Common API D1 写入、聚合 dashboard、PrivacyInfo / ASC 隐私门禁、测试验收和非目标边界。
- 完成内容：数据清洗章节补齐当前状态：本地建议、忽略 / 批量采纳 / 历史记录、脱敏 payload / hash-only response / 请求策略和 iOS 云端辅助授权已完成；真正 Worker 上传仍未接入，当前不上传账本数据。
- 完成内容：Pro 页面里的后续方向同步写回版本计划：云端辅助整理、智能复核队列、高级分享模板和多设备自动化同步均为后续规划，非当前已完成能力。
- 完成内容：执行记录补录 analytics / dashboard 第一版和 TestFlight 数据清洗 hash 冲突崩溃修复；四语 README 将 `v1.6.4` 调整为已完成、`v1.7.0` 调整为开发中，并同步当前 Pro 自动化和后续方向。
- 未完成内容：未补新的截图、ASC metadata、Review Notes、Privacy Policy 正文、Cloudflare production smoke 或 Instruments 性能证据。
- 测试情况：`git diff --check` PASS。本轮为文档对齐，未重新执行 App / Worker 构建。
- 风险与注意事项：analytics dashboard 代码已存在，但生产 D1 migration、面板访问控制、保留周期和真实线上 smoke 仍需在发布流程中确认；文档已明确当前 App 端实际采集面只有匿名启动事件。
- 回滚方式：回退本轮文档文件即可恢复到上一版计划，不涉及数据迁移或运行时代码。
- 结论：本轮完成，当前版本文档已对齐 v1.7.0 最新工程状态和后续方向。
- 下一步建议：发布前按新增 `GOAL-2360` 门禁确认 PrivacyInfo / ASC App Privacy / 官网隐私政策 / Review Notes 是否一致，并执行 Common API analytics dashboard 线上 smoke。

### ITER-401 数据清洗别名 hash 冲突崩溃修复
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Data Cleaning / TestFlight Crash
- 类型：Bugfix / 测试
- 目标：修复 TestFlight 真机点击“数据清洗”时，`DataCleaningAssistPayloadBuilder.hashedAliasTargets(_:)` 构造 Dictionary 因重复归一化 key 触发崩溃的问题。
- 改动范围：`DataCleaningAssistPayloadBuilder` 的商户别名 hash 和分类修正 hash 改为重复 key 稳定合并；`scripts/OfflineRegression.swift` 新增重复归一化商户别名 / 分类修正用例。
- 未改动范围：未修改数据清洗 UI、Pro gate、云端辅助开关语义、Worker endpoint、common-api、SQLite / CloudKit schema、StoreKit、ASC metadata、构建号或 tag。
- 完成内容：真实用户数据中多个原始商户名经大小写、空格、符号清洗后落到同一归一化 key 时，数据清洗页不会因 payload 构造而崩溃；冲突值用稳定字典序规则选择，保证 payload 可重复生成。
- 未完成内容：未做商户别名冲突可视化治理、冲突清理 UI 或云端辅助请求接入。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_data_cleaning_ios_entry_smoke.py` PASS；`bash scripts/run_offline_regression.sh` PASS，新增重复归一化商户别名 / 分类修正用例通过；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` PASS，仍有既有 formatter `nonisolated(unsafe)` 等 warning。
- 风险与注意事项：冲突合并只影响未来云端辅助 payload 的 hash 摘要字段，不会直接修改本地商户别名、交易、分类或已采纳规则。
- 回滚方式：回退 `DataCleaningAssistPayloadBuilder` 的重复 key 合并逻辑和离线回归用例，即可恢复旧行为，但真实重复归一化别名仍会触发崩溃。
- 结论：本轮完成，TestFlight 崩溃栈指向的 `Dictionary(uniqueKeysWithValues:)` 重复 key 崩溃已修复并通过离线回归与 iOS workspace 构建。
- 下一步建议：如果后续要把云端辅助正式接入 Worker，可在 UI 层增加“别名冲突整理”提示，帮助用户清理重复规则。

### ITER-400 永久删除后 OCR 重导入回归修复
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Import Reliability
- 类型：Bugfix / 测试
- 目标：修复离线回归中“账单永久删除后，同一 OCR 文本应允许重新导入”的红灯。
- 改动范围：`SQLiteTransactionStore` 新增按 `transaction_id` 删除 debug event 的方法；`LedgerStore.permanentlyDeleteTransaction` 在永久删除交易后同步清理关联 debug event 和内存 debug 记录。
- 未改动范围：未修改 OCR 解析、相似度算法、软删除 / 恢复流程、legacy 无 transactionID debug event、SQLite schema、CloudKit schema、Pro gate、StoreKit、ASC metadata、构建号或 tag。
- 完成内容：永久删除后的旧 persisted debug 记录不再阻挡同一账单重新导入；无 transactionID 的历史调试记录仍保留用于排查。
- 未完成内容：未做 debug event 清理 UI、批量历史清理或迁移脚本。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_pro_page_copy_smoke.py` PASS；`python3 scripts/check_localization_coverage.py` PASS；五语 `.strings` `plutil -lint` PASS；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` PASS，仍有既有 formatter `nonisolated(unsafe)` 等 warning。
- 风险与注意事项：只清理明确关联到永久删除交易的 debug event，不会清掉 parse failed、duplicate skipped 或旧版本缺 transactionID 的排查记录。
- 回滚方式：回退 `deleteDebugEvents(transactionID:)` 和 `LedgerStore.permanentlyDeleteTransaction` 中的 debug 清理调用，即可恢复旧行为。
- 结论：本轮完成，离线回归和 iOS workspace 构建通过。
- 下一步建议：如果后续用户仍反馈“删除后无法重导入”，再检查同图像 source / idempotency key 或 Share Extension 侧 duplicate path。

### ITER-399 Pro 页面当前权益与路线图收口
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Pro / Review QA
- 类型：UI / 文案 / 文档 / 测试
- 目标：把 Pro 页面从旧预告状态更新到当前 1.7.0 实际能力，并重新规划下一阶段用户可理解的 Pro 自动化方向。
- 改动范围：`SupportAutoLedgerView` 将高级搜索、订阅异常、月结包和高级规则从路线图移入已实现权益；路线图改为云端辅助整理、智能复核队列、高级分享模板和多设备自动化同步；五语 Pro 文案、订阅商品说明、Pro access audit、IAP 支持说明、v1.7.0 计划、CHANGELOG 和离线 smoke 同步更新。
- 未改动范围：未修改 StoreKit 商品 ID、订阅价格、Pro entitlement 判定、服务端 token claim、App Store Server Notifications、SQLite / CloudKit schema、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、MARKETING_VERSION、build number 或构建 tag。
- 完成内容：Pro 页面当前权益与 `ProAccessPolicy` 的 P0 能力保持一致，用户界面不再把已实现功能标为后续版本；路线图不再显示内部版本号。
- 未完成内容：未做真机视觉截图和 TestFlight 订阅页人工 walkthrough；云端辅助整理、智能复核队列、高级分享模板和多设备自动化同步仍只是后续规划。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_pro_page_copy_smoke.py` PASS；`python3 scripts/check_localization_coverage.py` PASS；五语 `.strings` `plutil -lint` PASS；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` PASS，仍有既有 formatter `nonisolated(unsafe)` 等 warning。
- 风险与注意事项：当前 Pro 页权益文案覆盖较多功能，后续若某项能力降级或临时隐藏，必须同步更新页面和 smoke；路线图文案只表达方向，不承诺具体上线时间。
- 回滚方式：回退 `SupportAutoLedgerView` 的 feature / roadmap 数据源、五语 `pro.*` 文案、`check_pro_page_copy_smoke.py`、`run_offline_regression.sh` 和相关文档条目，即可恢复旧 Pro 页面。
- 结论：本轮完成 Pro 页面能力边界收口，并已通过回归验证。
- 下一步建议：在 TestFlight 最新构建中检查 Pro 页面首屏信息密度、已实现权益卡片高度和订阅商品说明是否适合 ASC 审核录屏。

### ITER-398 月报月份下拉与分享入口收口
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Report UI / Share Cards
- 类型：UI / 能力增强 / 测试
- 目标：让月报月份切换更直观，并把月报分享图入口从正文卡片收口到右上角导航栏。
- 改动范围：`ReportView` 移除正文“生成分享图”卡片；导航栏左侧改为月份下拉菜单，右侧新增分享按钮；`LedgerStore` 新增按当前账本范围缓存的月报可选月份；五语补齐 `report.month_picker.*` 文案；更新分享图 smoke、v1.7.0 计划和 CHANGELOG。
- 未改动范围：未修改分享卡 PNG 渲染、分享预览 sheet、酒店入住分享卡、月结包 ZIP 导出、Pro gate、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、MARKETING_VERSION、build number 或构建 tag。
- 完成内容：月报页现在基于当前账本可见流水月份和本月生成下拉选项，选择月份后清空当前分类 / 趋势选中状态；正文不再显示“生成分享图”推广卡片；右上角系统分享图标直接打开当前月度分享图预览。
- 未完成内容：未做真机视觉截图对比、iPad / Mac 月报月份选择统一改造或 Charts 级性能剖析。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_share_cards_smoke.py` PASS；`python3 scripts/check_monthly_export_ui_smoke.py` PASS；`python3 scripts/check_localization_coverage.py` PASS；五语 `.strings` `plutil -lint` PASS；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` PASS，仍有既有 `nonisolated(unsafe)`、`LlmInference` deprecated、`@preconcurrency` 和 actor isolation warning。
- 风险与注意事项：月份菜单来自当前账本范围的实际交易月份和本月；如果用户切换账本或全部账本，菜单会随 `LedgerStore` 缓存失效刷新。正文入口隐藏后，分享功能主要依赖右上角图标的可发现性，后续可按 TestFlight 反馈调整图标可见性。
- 回滚方式：回退 `ReportView` 的 toolbar / 月份下拉 / 正文分享卡片改动、`LedgerStore.reportMonthOptions()`、五语 `report.month_picker.*` 文案、分享图 smoke 和文档条目，即可恢复到左右箭头切月和正文分享卡片。
- 结论：本轮完成，月报月份切换和分享入口已收口并通过最小回归与 iOS workspace 构建。
- 下一步建议：在 TestFlight 上检查月报导航栏左侧月份下拉、右上角分享按钮和正文信息密度；若仍感觉月份选择弱，可再做标题区内嵌 segmented / picker 方案。

### ITER-397 月结包 ZIP 与月报性能第一轮优化
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2330 / Report Performance
- 类型：能力增强 / 性能 / 测试
- 目标：把月结包从多文件分享改为单个压缩包，并降低几百条账单时月报 Tab 切换和月份切换的同步重算压力。
- 改动范围：`LedgerStore.writeMonthlyExportPackage` 外层改为 ZIP；五语月结包文案改为压缩包；`LedgerStore` 新增月报快照和异常提醒缓存；`MonthlySnapshot.build` 改为单次遍历汇总当前月和近 6 个月趋势；`ReportView` 改为读取缓存后的异常提醒；扩展月结包 smoke；更新 v1.7.0 计划和 CHANGELOG。
- 未改动范围：未修改月结包内部四类资料文件、Pro gate、基础 CSV / JSON 免费导出、月结导出筛选合同、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、MARKETING_VERSION、build number 或构建 tag。
- 完成内容：用户分享时只看到一个 `AutoLedger_monthly_export_*.zip`，zip 内部仍保留交易 CSV、月报 PDF、酒店水单附件索引 CSV 和 manifest JSON；月报数据在当前账本和月份维度缓存，交易或账本范围变化时自动失效；当前月异常提醒也按月份 / 账本 / 阈值缓存。
- 未完成内容：未做 Instruments 真机剖析、Charts 渲染专项优化、后台导出任务、导出历史、原生 Excel / Numbers 工作簿或 Mac 大屏月结工作台；这些需要结合 TestFlight / 真机反馈继续拆分。
- 测试情况：`git diff --check` PASS；`python3 scripts/check_monthly_export_ui_smoke.py` PASS；五语 `Localizable.strings` `plutil -lint` PASS；`python3 scripts/check_localization_coverage.py` PASS；`bash scripts/run_offline_regression.sh` PASS；`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` PASS，仍有既有 `nonisolated(unsafe)`、`LlmInference` deprecated 和 `@preconcurrency` warning。
- 风险与注意事项：ZIP 使用系统 `NSFileCoordinator(.forUploading)`，与现有反馈包压缩路径一致；性能优化是代码级确定性优化，不能替代 Instruments 对真实卡顿来源的最终定位。
- 回滚方式：回退 `LedgerStore` ZIP 写入与月报缓存、`MonthlySnapshot` 单次遍历重构、`ReportView` 异常提醒调用、五语月结包文案、smoke 扩展和文档条目，即可恢复到多文件分享和原始月报计算路径。
- 结论：本轮完成，月结包 ZIP 化和月报同步重算第一轮优化已通过最小回归与 iOS workspace 构建。
- 下一步建议：在最新 TestFlight 通过后，用同一份几百条数据做 Release 真机手感对比；若仍卡顿，优先用 Instruments 分别捕获 Tab 切换、月份切换和 Charts 交互。

### ITER-396 酒店旅程回忆文案第一版
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2309 / Promotional Polish
- 类型：能力增强 / UI / 测试
- 目标：把酒店历史天气从单纯摘要卡片推进到可感知的端上旅程回忆文案，让 ASC 1.6.0 主宣传版的酒店模块更有记忆点。
- 改动范围：新增 `HotelStayJourneyMemoryComposer`；酒店消费详情在历史天气加载成功后展示“旅程回忆”卡片；旅程回忆可一键带入“入住分享卡”作为默认评价；补齐中简、繁中、英语、日语、韩语文案；扩展 `check_hotel_weather_ui_smoke.py`。
- 未改动范围：未新增 LLM、未新增网络请求、未上传酒店名称、金额、PDF、rawText、房号、订单号、支付方式或个人备注；未修改 Common API 端点、WeatherKit provider、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview、Xcode Cloud 脚本或构建 tag。
- 完成内容：回忆文案只使用当前本机酒店记录的酒店名、地点、日期和已加载的天气事实，按本地化模板生成一段可读小记；详情页展示隐私说明，分享按钮会打开现有入住卡预览并带入该文案，用户仍可在预览页编辑。
- 未完成内容：未做 AI 叙事生成、用户长期记忆库、天气卡片视觉重构、旅行故事多模板或跨设备同步；这些留给后续更重的体验设计。
- 测试情况：`python3 scripts/check_hotel_weather_ui_smoke.py` PASS；五语 `Localizable.strings` `plutil -lint` PASS；旅程回忆格式化占位符 parity 检查 PASS；XcodeBuildMCP iPhone 17 Pro Max Simulator Debug build-run PASS，构建通过，仅剩既有 warning 和本轮新增 warning 修正后的二次门禁待最终执行。
- 风险与注意事项：回忆文案依赖天气摘要已加载；天气不可用时不会编造当前或未来天气。模板为轻量端上文案，后续如果接入更复杂生成能力，仍需保持服务端不接收酒店内容和个人备注。
- 回滚方式：回退 `HotelStayJourneyMemoryComposer.swift`、酒店详情 `hotelJourneyMemoryCard` / `journeyMemoryText` / 分享卡联动、五语 `hotel_stay.detail.memory.*` 文案和 smoke 扩展，即可恢复到仅显示天气摘要卡片。
- 结论：本轮完成，酒店模块增加了主宣传版可展示的端上旅程回忆能力。
- 下一步建议：继续做 1.7.0 发布前真机 smoke，重点验证实时 OCR、酒店详情天气 / 回忆 / 分享卡、多币种确认和韩语主路径。

### ITER-395 分享图片第一版
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Share Cards / Free Growth
- 类型：能力增强 / UI / 测试
- 目标：让用户可以把月度总结和酒店入住记录生成本地 PNG，并通过系统 Share Sheet 分享出去。
- 改动范围：新增 `Features/ShareCards/` 下的月报分享卡、酒店入住分享卡、导出服务和预览 sheet；`ReportView` 新增“生成分享图”入口；`HotelStayDetailView` 新增“分享入住卡”入口；补齐中简、繁中、英语、日语、韩语本地化；新增分享图 smoke 并接入离线回归。
- 未改动范围：未新增服务器上传、HTML 分享页、公开网页、模板系统、复杂编辑器、Pro gate、StoreKit、SQLite / CloudKit schema、月结导出包合同、ASC metadata、截图 / App Preview、Xcode Cloud 脚本或构建 tag。
- 完成内容：月报分享图展示月份、本月账单数量、分类 Top 3、可选总支出、一句简单总结和 AutoLedger 水印；酒店入住分享图展示酒店名、城市 / 国家和地区、入住 / 退房日期、晚数、房型、可选价格、用户可编辑评价和 AutoLedger 水印。金额 / 房费默认隐藏，PNG 只写入本机临时目录后交给系统分享。
- 未完成内容：第一版没有高级模板、去水印、HTML 分享页、公开访问链接、分享历史或跨设备同步；视觉细节后续可按真实截图反馈再调。
- 测试情况：`python3 scripts/check_share_cards_smoke.py` PASS；五语 `Localizable.strings` `plutil -lint` PASS；`git diff --check` PASS；XcodeBuildMCP iPhone 17 Pro Max Simulator Debug build-run PASS；`bash scripts/run_offline_regression.sh` PASS。
- 风险与注意事项：分享图是用户主动触发的本地导出；酒店分享卡静态检查禁止引用房号、订单号、支付方式、PDF、rawText 或 source PDF 字段，后续改动需要继续保持该隐私边界。
- 回滚方式：回退 `Features/ShareCards/`、`ReportView` 分享入口、`HotelStayArchiveView` 分享入口、五语 `share_card.*` 文案、`check_share_cards_smoke.py` 和离线回归接入，即可恢复到无分享图功能。
- 结论：本轮完成，基础分享图片第一版具备工程闭环，且作为免费传播入口不进入 Pro gate。
- 下一步建议：保留真实用户截图反馈后再做视觉细节调优；高级模板、去水印和 HTML 分享页可单独进入后续 Pro 方案评估。

### ITER-394 Notification History 补偿第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2310 / Entitlement
- 类型：能力增强 / Worker / 测试
- 目标：补齐 App Store Server Notifications 的 History 补偿代码，避免 Worker 短暂不可用或 Apple 投递重试失败后服务端 Pro 状态长期不同步。
- 改动范围：`hotel-folio-inbox` Worker scheduled task 新增 Notification History 补偿；抽出 App Store 通知内部处理函数供 webhook 和 History 复用；新增 History 请求窗口、分页收集和补偿执行 helper；更新 Worker README、`v1.7.0` 计划、CHANGELOG 和 Worker 合同测试。
- 未改动范围：未在 App Store Connect 配置 Server Notifications URL；未执行 production D1 migration；未新增 D1 表或 schema；未修改 App 代码、StoreKit 商品、SQLite / CloudKit schema、Common API、截图 / App Preview、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION`、build number 或构建 tag。
- 完成内容：配置 App Store Server API secrets 后，Worker 会每天请求 Apple `POST /inApps/v1/notifications/history`，默认回看最近 72 小时、`onlyFailures=true`、最多分页 5 页；补回的每个 `signedPayload` 继续走证书链验签、bundle / product / environment 校验、`notificationUUID` 幂等、服务端 entitlement 更新和云收件箱 token 生命周期更新。
- 未完成内容：真实 ASC sandbox 投递和 History 补偿 smoke 需要等 ASC 配置 Server Notifications URL 后执行；production Apple root certificate、App Store Server API secrets 和 D1 migration 仍需发布前确认。
- 测试情况：先新增 Worker RED 用例，确认缺少 History 请求窗口与分页 helper 时 `vitest` 失败；实现后执行 `cd tools/worker/hotel-folio-inbox && npm test -- hotel-folio-inbox.test.ts`，27 个 Worker 合同测试 PASS。
- 风险与注意事项：History 补偿只拉 Apple 记录的失败 / 重试通知，不替代 webhook 正常投递；未配置 App Store Server API secrets 时任务安全跳过；本轮不保存 raw `signedPayload` 或 raw original transaction id。
- 回滚方式：回退 scheduled task 中的 `processAppStoreNotificationHistory`、内部处理函数抽取、History helper、Worker 测试和文档记录，即可恢复到仅 webhook 接收通知。
- 结论：本轮完成，`GOAL-2310` 的 Notification History 工程代码第一版已闭环。
- 下一步建议：执行 Worker typecheck / 全量回归 / App 构建门禁，然后 push main 并移动 `xcbuild-v1.7.0`。

### ITER-393 iOS 数据清洗账本入口补强
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345G / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：修复 iPhone 最新 build 中数据清洗不够可见的问题，让用户在账本页也能直接进入智能整理建议。
- 改动范围：`LedgerView` 右上角更多菜单新增“智能整理建议”入口，打开同一套 `DataCleaningSuggestionsView`；扩展 `scripts/check_data_cleaning_ios_entry_smoke.py`，同时约束设置页入口和账本页入口。
- 未改动范围：未修改数据清洗建议模型、采纳 / 撤销逻辑、商户别名 / 分类学习存储、SQLite / CloudKit schema、Worker endpoint、`common-api` 上传策略、StoreKit、ASC metadata、截图 / App Preview 或构建 tag。
- 完成内容：iPhone 端现在既可以从设置页“智能整理”进入，也可以在账本页更多菜单进入；两个入口共享同一份当前建议、Pro gate、批量采纳、撤销和最近清洗记录。
- 未完成内容：本轮没有新增 Worker 辅助请求、跨设备同步建议队列或云端辅助返回建议 UI。
- 测试情况：先扩展 `python3 scripts/check_data_cleaning_ios_entry_smoke.py` 并确认缺少账本入口时失败；实现后执行同一 smoke，结果 PASS。
- 风险与注意事项：入口放在账本页更多菜单，不改变主工具栏按钮密度；未订阅用户进入后仍看到统一 Pro 自动化说明和免费能力边界。
- 回滚方式：回退 `LedgerView` 的 `isPresentingDataCleaning` sheet 和菜单项，并回退 smoke 中对账本入口的检查，即可恢复到仅设置页入口。
- 结论：本轮完成，iOS 数据清洗入口可见性补强完成。
- 下一步建议：继续收口 `GOAL-2310` Notification History 补偿和最终全量门禁。

### ITER-394 Common API production WeatherKit 开启
- 日期：2026-07-08
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2309 / Common API
- 类型：基础设施 / 运营配置 / 文档
- 目标：把已经在 staging 跑通的 Common API WeatherKit 配置扩展到 production，让正式域名可以为酒店消费详情和后续旅程回忆文案提供历史天气材料。
- 改动范围：`tools/worker/common-api/wrangler.jsonc` production `WEATHER_PROVIDER` 从 `disabled` 改为 `weatherkit`；production Worker secrets 配置 `WEATHERKIT_TEAM_ID`、`WEATHERKIT_SERVICE_ID`、`WEATHERKIT_KEY_ID`、`WEATHERKIT_PRIVATE_KEY`；更新 `common-api` README、`v1.7.0` 计划和 CHANGELOG。
- 未改动范围：未新增天气端点；未修改 App Swift 代码、酒店入账逻辑、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview、Xcode Cloud 脚本、构建 tag 或服务端订阅链路。
- 完成内容：production 使用 Common API 专用 WeatherKit 服务身份，正式域名天气端点只接收坐标、日期、locale、timezone 和 units，不接收酒店名、金额、PDF、OCR 原文、邮箱内容或用户备注。`v1.7.0` 计划同步记录：天气结果不一定作为独立卡片呈现，更长期目标是作为 App 端酒店旅程回忆文案的事实材料，引导用户回想当时出行场景。
- 未完成内容：服务端鉴权、配额策略、多 provider fallback、缓存清理 UI、旅程回忆文案生成和用户交互启发仍留到后续 GOAL。
- 测试情况：`npm run check` PASS，包含 `wrangler types`、`tsc --noEmit` 和 29 个 Vitest 合同测试；`npm run deploy:production` PASS，production Version ID `9e05c657-b0f7-4018-b4bd-202bacdf0a75`；`curl https://api.darkrio326.top/v1/manifest` 返回 HTTP 200 且 `hotelWeather.status=available`、provider 为 `weatherkit`；`curl "https://api.darkrio326.top/v1/weather/hotel-stay-summary?lat=35.69&lon=139.76&checkIn=2026-07-01&checkOut=2026-07-03&locale=ja&timezone=Asia/Tokyo"` 返回 HTTP 200、provider 为 `weatherkit`，包含 2 个入住夜晚；`curl "https://api.darkrio326.top/v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo"` 返回 HTTP 200、provider 为 `weatherkit`。
- 风险与注意事项：WeatherKit production 开启后会消耗正式 Apple WeatherKit 配额；当前端点不需要用户数据，若后续做旅程文案，应继续在 App 端本地组合天气事实和酒店记录。
- 回滚方式：将 production `WEATHER_PROVIDER` 改回 `disabled` 并重新部署，或移除 production WeatherKit secrets，即可让天气端点回到 `weather_provider_not_configured` 降级。
- 结论：本轮完成，Common API production WeatherKit 已开启并通过正式域名 smoke。
- 下一步建议：推进 App 端旅程回忆文案的本地生成原型，让天气从“摘要卡片”变成酒店记录里的轻量回忆线索。

### ITER-392 酒店历史天气 App 展示第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2309 / Common API
- 类型：能力增强 / UI / 测试
- 目标：把 `common-api` 酒店入住历史天气端点接入 App 酒店消费详情页，同时保持酒店名称、金额、PDF、邮箱内容和账单原文不上传。
- 改动范围：新增 `CommonAPIHotelWeatherService`；扩展 `HotelStayLocationCatalog` 保留远端地点目录的经纬度和时区；酒店消费详情新增入住天气卡片；补齐五语 `hotel_stay.detail.weather.*` 文案；新增 `scripts/check_hotel_weather_ui_smoke.py` 并纳入离线回归。
- 未改动范围：本轮当时未开启 production WeatherKit provider，后续已在 ITER-394 作为运营配置开启；未新增 Worker endpoint；未修改酒店入账逻辑、SQLite / CloudKit schema、StoreKit、ASC metadata、截图 / App Preview 管线或构建 tag。
- 完成内容：酒店详情页会按当前城市 / 国家和地区、入住 / 退房日期从地点目录解析经纬度和时区，只向 `common-api` 发送坐标、日期、locale、timezone 和 units；服务端不可用、无坐标、日期无效或无天气日记录时显示“暂无天气摘要”，不会用当前天气或未来天气冒充历史入住天气。
- 未完成内容：production WeatherKit 当时仍保持 `WEATHER_PROVIDER=disabled`，后续已在 ITER-394 开启；服务端鉴权、配额策略、多 provider fallback、天气缓存清理 UI 和真实酒店样例截图仍留到后续发布门禁或运营配置。
- 测试情况：先执行 `python3 scripts/check_hotel_weather_ui_smoke.py` 得到预期失败；实现后执行同一 smoke、`python3 scripts/check_localization_coverage.py`、五语 `plutil -lint`、`git diff --check`、`bash scripts/run_offline_regression.sh` 和 XcodeBuildMCP iPhone 17 Pro Max Debug build-run，结果均 PASS。
- 风险与注意事项：在 production WeatherKit 未开启或服务端不可用时，用户会看到不可用降级；远端地点目录未缓存且内置 fallback 无坐标的城市不会请求天气，避免传错地点。
- 回滚方式：回退 `CommonAPIHotelWeatherService.swift`、酒店详情天气卡片、地点目录坐标扩展、五语天气文案、`check_hotel_weather_ui_smoke.py` 和离线回归接入，即可恢复旧酒店消费详情页。
- 结论：本轮完成，`GOAL-2309` 的 App 端酒店历史天气展示第一版具备工程闭环。
- 下一步建议：继续做最终全量门禁、分类提交汇总和 `xcbuild-v1.7.0` 构建 tag 移动；production WeatherKit 已在 ITER-394 开启，后续继续推进配额、鉴权和旅程回忆文案。

### ITER-391 ASC metadata-as-code 第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2312 / Release Automation
- 类型：发布自动化 / 工具 / 测试
- 目标：把 ASC 1.6.0 的五语 App Info、版本文案、订阅组和订阅商品本地化收敛为 repo 源文件，并提供可审计的 dry-run / apply 工具。
- 改动范围：新增 `tools/asc-metadata/metadata.yml`；扩展 `asc_metadata.rb push-config`；更新 ASC metadata README；新增 `scripts/check_asc_metadata_as_code_smoke.py` 并接入离线回归；更新 v1.7.0 计划和 CHANGELOG。
- 未改动范围：未上传截图或 App Preview；未自动提交审核；未修改 App Privacy nutrition label；未提交 ASC API key、issuer id、key id、p8 或任何 secret；未修改 Xcode Cloud、StoreKit、SQLite / CloudKit schema 或构建 tag。
- 完成内容：`push-config` 可从 YAML 更新或创建 `appInfoLocalizations`、`appStoreVersionLocalizations`、`subscriptionGroupLocalizations` 和 `subscriptionLocalizations`；默认 dry-run 输出字段级 diff，显式 `--apply` 才写入 ASC。配置覆盖中简、繁中、美英、日、韩五语，并静态校验 Pro 订阅描述不超过 55 字符。
- 未完成内容：截图和 App Preview 仍由现有独立上传 / 审计脚本处理；App Privacy 问卷仍需人工确认；五语商店文案发布前仍需人工审校，尤其是日语和韩语。
- 测试情况：执行 `python3 scripts/check_asc_metadata_as_code_smoke.py`、`ruby -c tools/asc-metadata/asc_metadata.rb`、`ruby -c tools/asc-metadata/asc_screenshot_upload.rb` 和 YAML 解析 / 订阅描述长度检查，结果均 PASS。
- 风险与注意事项：`push-config --apply` 会真实写入 ASC，应始终先跑 dry-run 和 audit；当前配置是 ASC 1.6.0 发布线源数据，不应回写到仍在审核或已上线的旧版本。
- 回滚方式：回退 `metadata.yml`、`asc_metadata.rb push-config`、README、`check_asc_metadata_as_code_smoke.py` 和离线回归接入即可恢复到只支持 audit / copy-locale / screenshot upload 的工具状态。
- 结论：本轮完成，GOAL-2312 第一版工程闭环可进入 Worker / ASSN 和最终门禁收口。
- 下一步建议：继续验证 Common API 与 hotel-folio-inbox Worker 的 typecheck / test / deployment 状态，再进入全量 App 回归和构建 tag 移动。

### ITER-390 高级规则自动应用第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2340 / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：把用户已确认的商户别名和分类修正规则聚合成可预览、可一键应用、可撤销的 Pro 自动化入口，同时保持单条编辑和基础规则免费。
- 改动范围：新增 `AdvancedRuleAutomationPlanner`；更新 `AutoLedgerProAccessPolicy`；更新 iPhone `DataCleaningSuggestionsView` 和 iPad / Mac `IPadCleaningPreviewWorkspaceView` 的自动化规则卡片；补齐五语 `ipad.cleaning.rules.*` 文案；新增高级规则 UI smoke 并接入离线回归。
- 未改动范围：未新增 Worker endpoint、未调用 `common-api`、未上传账本数据、未修改 SQLite / CloudKit schema、未修改 StoreKit 商品、未修改截图 / App Preview 管线、未移动构建 tag。
- 完成内容：Core 层计划只包含已保存商户别名和分类修正规则，明确排除疑似重复和云端辅助候选；iPhone 与 iPad / Mac 入口展示规则数、商户别名数、分类修正数和影响账单数；点击应用复用既有 `applyDataCleaningPreviews`，因此继续具备批量撤销和历史记录。
- 未完成内容：本轮没有实现低置信度集中复核队列、跨设备建议队列、Worker 模型辅助解释或服务端规则生成；这些继续归入后续数据清洗增强。
- 测试情况：执行 `python3 scripts/check_advanced_rule_automation_ui_smoke.py`、`python3 scripts/check_localization_coverage.py`、五语 `Localizable.strings` `plutil -lint`、`git diff --check`、iPhone 17 Pro Max Simulator Debug build-run 和 `bash scripts/run_offline_regression.sh`，结果均 PASS。
- 风险与注意事项：该入口只批量应用用户已经确认过的别名和分类规则，不会自动采纳疑似重复，也不会上传账本。规则太少时卡片会显示空态，避免误导用户以为云端自动整理已经启用。
- 回滚方式：回退 `DataCleaningSuggestionsView` / `iPadWorkspaceView` 自动化规则卡片、五语 `ipad.cleaning.rules.*` 文案、`check_advanced_rule_automation_ui_smoke.py`、`AdvancedRuleAutomationPlanner.swift` 和 `ProAccessPolicy` 中 `advancedRuleAutomation` P0 gate，即可恢复旧数据清洗入口。
- 结论：本轮完成，GOAL-2340 第一版工程闭环可进入后续 Common API / ASSN / ASC 工具链收口。
- 下一步建议：继续收口 `v1.7.0` 剩余工程项，优先确认 Common API / ASSN / ASC 自动化是否还有未提交代码，再做全量门禁和构建 tag 移动。

### ITER-389 月结导出包第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2330 / Pro Automation
- 类型：能力增强 / 导出 / UI / 测试
- 目标：让 Pro 用户在月报页一键生成月度资料包，包含账单明细、月报摘要、酒店水单附件索引和脱敏选项，同时保持基础 CSV / JSON 导出免费。
- 改动范围：新增 `MonthlyExportPackageBuilder`、月结包模型和离线回归；更新 `AutoLedgerProAccessPolicy`；更新 `LedgerStore` 月结包写出与 PDF 渲染；更新 `ReportView` 月结包卡片、Pro gate、分享入口和脱敏开关；补齐五语 `report.monthly_export.*` 文案；新增月结包 UI smoke 并接入离线回归。
- 未改动范围：未新增 Worker endpoint、未修改 StoreKit 商品、未修改 SQLite / CloudKit schema、未修改基础 CSV / JSON 备份入口、未修改截图 / App Preview 管线、未移动构建 tag。
- 完成内容：Core 层可按月份、账本、分类、商户和时间范围过滤交易，生成 Excel 兼容 CSV、可打印月报源、酒店水单附件索引和 manifest；App 侧分享时将月报源渲染为 PDF，并同步 manifest 文件名；导出默认开启商户 / 酒店名称脱敏。`monthlyExportPackage` 进入 v1.7.0 P0 Pro 本地 UI gate，未订阅用户进入统一 Pro 页面。
- 未完成内容：本轮没有做 ZIP 打包、Numbers / Excel 原生工作簿、跨设备导出历史、异步后台导出队列或 Mac 专用月结工作台；这些可在真实用户导出文件规模明确后继续扩展。
- 测试情况：执行 `python3 scripts/check_monthly_export_ui_smoke.py`、`python3 scripts/check_localization_coverage.py`、五语 `Localizable.strings` `plutil -lint`、`git diff --check`、iPhone 17 Pro Max Simulator Debug build-run 和 `bash scripts/run_offline_regression.sh`，结果均 PASS。
- 风险与注意事项：分享 sheet 当前直接分享同一临时目录内的多文件 URL，系统目标 App 对多文件接收能力不同；PDF 为 App 侧基础分页渲染，适合审核和普通分享，复杂排版或品牌化报表可后续单独增强。
- 回滚方式：回退 `ReportView` 月结包卡片、`LedgerStore.writeMonthlyExportPackage`、五语 `report.monthly_export.*` 文案、`check_monthly_export_ui_smoke.py`、`MonthlyExportPackageBuilder.swift` 和 `ProAccessPolicy` 中 `monthlyExportPackage` P0 gate，即可恢复旧月报页和基础导出行为。
- 结论：本轮完成，GOAL-2330 第一版工程闭环可进入高级规则自动化。
- 下一步建议：进入 GOAL-2340 高级规则自动应用，复用既有数据清洗预览 / 撤销模型，先固定规则预览合同和单条编辑免费边界。

### ITER-388 订阅异常提醒第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2320 / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：让 Pro 用户在订阅管理页看到价格上涨、疑似重复扣费、扣费周期异常和近期续费压力，同时保持基础订阅记录与手动维护免费。
- 改动范围：新增 `SubscriptionAnomalyDetector`；更新 `AutoLedgerProAccessPolicy`；更新 `SubscriptionListView` 订阅异常分区、Pro gate 和 Pro 页面入口；补齐五语 `subscriptions.anomaly.*` 文案；新增订阅异常 UI smoke 并接入离线回归。
- 未改动范围：未新增 Worker endpoint、未修改 App Store Server Notifications、未修改 StoreKit 商品、未修改 SQLite / CloudKit schema、未修改截图管线、未移动构建 tag。
- 完成内容：Core 检测器可从订阅和账单历史中生成涨价、重复扣费、周期异常和 7 / 30 / 90 天续费压力摘要；`subscriptionAnomalyDetection` 进入 v1.7.0 P0 Pro 本地 UI gate；iOS 订阅管理页展示前三条异常与 7 / 30 天续费压力；未订阅用户看到统一 Pro 自动化说明和订阅入口。
- 未完成内容：本轮没有做后台推送提醒、服务端订阅生命周期主动通知 UI、跨设备异常已读状态或年度订阅成本详情图；这些可在 ASSN / 通知体验稳定后继续扩展。
- 测试情况：执行 `python3 scripts/check_subscription_anomaly_ui_smoke.py`、`python3 scripts/check_localization_coverage.py`、`plutil -lint` 五语 strings、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -configuration Debug build` 和 `bash scripts/run_offline_regression.sh`，结果均 PASS。
- 风险与注意事项：异常检测当前基于本机订阅和交易历史，不代表 Apple 订阅后台事件；数据少或历史账单不完整时可能没有可显示异常。续费压力按本机订阅金额汇总，跨币种年度成本和更复杂汇率口径留到后续。
- 回滚方式：回退 `SubscriptionListView` 异常分区、五语 `subscriptions.anomaly.*` 文案、`check_subscription_anomaly_ui_smoke.py`、`SubscriptionAnomalyDetector.swift` 和 `ProAccessPolicy` 中 `subscriptionAnomalyDetection` P0 gate 即可恢复旧订阅列表。
- 结论：本轮完成，GOAL-2320 第一版工程闭环可进入月结导出包或高级规则自动化。
- 下一步建议：进入 GOAL-2330 月结导出包，优先在 Core 层固定导出资料包合同和脱敏边界。

### ITER-387 高级搜索第一版
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2315 / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：让 Pro 用户在账本页组合金额、日期、分类、来源、账本和酒店水单线索搜索历史记录，同时保持基础关键词搜索免费。
- 改动范围：新增 `LedgerAdvancedSearchQuery`、`LedgerAdvancedSearchService`、`LedgerSavedSearch`；更新 `AutoLedgerProAccessPolicy`；更新 `LedgerView` 高级搜索入口、表单和常用条件本地保存；补齐五语本地化和高级搜索 UI smoke。
- 未改动范围：未新增 Worker endpoint、未修改 SQLite / CloudKit schema、未修改 StoreKit 商品、未修改截图管线、未移动构建 tag。
- 完成内容：Core 搜索服务支持关键字、金额区间、日期区间、分类、来源、账本、酒店水单关联和原始币种线索组合筛选；`advancedSearch` 进入 v1.7.0 P0 Pro 本地 UI gate；基础关键词查询不触发 Pro；iOS 账本页可打开高级搜索表单并保存 / 套用常用条件。
- 未完成内容：高级搜索暂未接入 Mac 专用表格工作台的独立筛选条，后续可复用同一 Core 服务扩展；跨设备同步保存条件暂未做。
- 测试情况：执行 `python3 scripts/check_advanced_search_ui_smoke.py`、`python3 scripts/check_localization_coverage.py`、`plutil -lint` 五语 strings、`bash scripts/run_offline_regression.sh` 和 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -configuration Debug build`，结果均 PASS。
- 风险与注意事项：常用搜索条件目前存于本机 `AppStorage`，不进入 iCloud；未订阅用户如果此前已有高级条件缓存，结果会降级为基础关键词搜索。
- 回滚方式：回退 `LedgerView` 高级搜索 UI、五语 `ledger.advanced_search.*` 文案、`check_advanced_search_ui_smoke.py`、`LedgerAdvancedSearch.swift` 和 `ProAccessPolicy` 中 `advancedSearch` P0 gate 即可恢复旧基础搜索。
- 结论：本轮完成，GOAL-2315 第一版工程闭环可进入下一项 Pro 自动化能力。
- 下一步建议：进入 GOAL-2320 订阅异常提醒，优先固定异常检测 Core 合同和基础 UI 入口。

### ITER-386 iOS 数据清洗入口与云端辅助授权
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345G / Pro Automation
- 类型：能力增强 / UI / 隐私边界 / 测试
- 目标：解决 iOS 最新 build 中用户看不到数据清洗入口的问题，并把上一段 Worker 辅助请求策略接到清晰的端上授权入口，但保持当前版本零上传。
- 改动范围：更新 iOS 设置页入口、`DataCleaningSuggestionsView` 云端辅助授权卡、五语本地化、离线静态 smoke、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未新增网络上传、Worker endpoint、服务端模型建议或跨设备建议队列。
- 完成内容：设置页在 Pro 卡片下新增独立“智能整理”分区，直接进入 `DataCleaningSuggestionsView`；旧“规则”分区里的重复入口已移除，避免入口被埋住。
- 完成内容：`DataCleaningSuggestionsView` 新增“云端辅助建议”授权卡，使用 `@AppStorage("dataCleaningCloudAssistEnabled")` 保存本机偏好，并复用 `DataCleaningAssistRequestPolicy` 展示默认关闭、Pro gate、历史不足、冷却和失败回退状态。
- 完成内容：五语补齐 `settings.section.smart_cleanup` 与 `ipad.cleaning.cloud_assist.*` 文案；文案明确当前版本只保存授权偏好，不发送商户名、金额、备注、OCR 原文或交易 ID。
- 完成内容：新增 `scripts/check_data_cleaning_ios_entry_smoke.py` 并接入离线回归，静态检查 iOS 设置入口位置、云端辅助授权卡、请求策略 wiring 和五语文案。
- 未完成内容：本轮没有真实 Worker 请求、服务端配额、鉴权、失败回退持久化、跨设备授权同步或云端建议结果 UI。
- 测试情况：先执行 `python3 scripts/check_data_cleaning_ios_entry_smoke.py`，确认缺少独立入口和授权卡时失败；实现后同脚本 PASS。执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；五语 `Localizable.strings` `plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增 static smoke 随离线回归运行；执行 iPhone 17 Pro Max Simulator Debug build，结果 PASS。
- 风险与注意事项：`cloudAssistEnabled` 当前只是本机授权偏好，不代表服务端可用；真正接入 Worker 时仍需服务端鉴权、配额、日志最小化、失败回退策略和用户撤销入口。
- 回滚方式：回退 `SettingsView` 新增分区、`DataCleaningSuggestionsView` 授权卡、五语文案和静态 smoke 脚本，并从离线回归移除该脚本；不涉及数据迁移或用户账本。
- 结论：本轮完成；iOS 设置页已有独立可见的数据清洗入口，云端辅助授权偏好已接入端上状态说明，但仍保持零上传。
- 下一步建议：完成验证和提交后，继续接入 Worker 辅助建议的服务端合同或先补 Mac / iPad 大屏数据清洗表格体验。

### ITER-385 Worker 辅助建议请求策略
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345F / Pro Automation
- 类型：能力增强 / 隐私边界 / 测试
- 目标：在真正接入 Worker 之前，先冻结云端辅助数据清洗建议的请求前置策略，确保未来不会在用户未开启、未订阅 Pro、历史不足、冷却期内或失败回退期内静默发起请求。
- 改动范围：更新 `AutoLedgerCore` 数据清洗辅助合同、离线回归、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 App UI、UserDefaults 开关、SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未新增网络上传、Worker endpoint、服务端模型建议、配额、用户授权页面或跨设备建议队列。
- 完成内容：新增 `DataCleaningAssistRequestContext`，显式表达 `userEnabledCloudAssist`、`isProActive`、`lastRequestedAt`、`backoffUntil` 和 `forceRefresh`。
- 完成内容：新增 `DataCleaningAssistRequestDecision` 和 `DataCleaningAssistRequestDecisionReason`，让调用方只拿到 allowed / reason / nextEligibleAt，不暴露账本明细。
- 完成内容：新增 `DataCleaningAssistRequestPolicy`，要求用户显式开启、Pro 有效、payload schema / privacy mode 正确、本地历史足够且不在失败回退期；默认最小交易数为 8，默认冷却 6 小时。
- 完成内容：显式刷新只绕过冷却，不绕过用户开关、Pro 权益、历史不足或失败回退。
- 未完成内容：本轮只完成 Core 请求策略合同，没有 App 设置开关、持久化、Worker 调用或服务端实现；`userEnabledCloudAssist` 后续仍需要接入清晰的用户授权入口。
- 测试情况：先新增离线 RED 断言并执行 `bash scripts/run_offline_regression.sh`，确认缺少 `DataCleaningAssistRequestPolicy` 和 `DataCleaningAssistRequestContext` 时编译失败；实现后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖默认关闭、Pro gate、历史不足、允许请求、冷却、强制刷新和失败回退。
- 风险与注意事项：该策略仍是客户端合同，不是服务端安全边界；真正接入 Worker 时仍需服务端鉴权、配额、日志最小化、威胁建模、用户可撤销授权和 App 侧清晰说明。
- 回滚方式：删除 `DataCleaningAssistRequestContext`、`DataCleaningAssistRequestDecision`、`DataCleaningAssistRequestDecisionReason`、`DataCleaningAssistRequestPolicy` 和对应离线回归断言，并回退文档记录；不涉及数据迁移或用户数据。
- 结论：本轮完成；`GOAL-2345F` 已把 Worker 辅助建议的请求 eligibility 落成可回归代码，但仍保持零上传和零 Worker 调用。
- 下一步建议：继续补 App 侧用户授权开关与本机持久化，或先推进 Mac / iPad 大屏忽略项管理和建议历史表格。

### ITER-384 visionOS review fallback 移植
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Platform Review Follow-up
- 类型：Bugfix / 测试 / 发布治理
- 目标：把 `v1.6.4 / ASC 1.5.0` visionOS review hotfix 的生产代码单独移植到 `main`，避免 1.7 主线在 visionOS 无 CloudKit 看板数据时继续显示空看板。
- 改动范围：更新 `AutoLedger/AutoLedgerVision/ContentView.swift`、新增 `scripts/check_visionos_review_smoke.py`、接入 `scripts/run_offline_regression.sh`，并回填 `CHANGELOG.md` 与本日志。
- 未改动范围：未 merge `codex/macos-ledger-plus-hotfix-v1.6.4` 分支，未带入 1.6.4 的 review notes / 发布文档差异；未修改 SQLite / CloudKit schema、StoreKit 商品 ID、Common API、Worker、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。
- 完成内容：`loadTransactions()` 在 CloudKit snapshot 存在但交易为空时，不再直接返回空数组；只有真实交易非空才使用 CloudKit 数据，否则使用本机 `VisionDashboardSimulatorData` 示例看板数据。
- 完成内容：release / review 环境也可使用示例看板 fallback，不再局限于 DEBUG simulator；示例备注文案从“visionOS simulator demo data”调整为“visionOS sample dashboard data”。
- 完成内容：新增 visionOS review smoke，静态检查 `loadTransactions()` 不直接返回空 snapshot、不回退 `return []`，并检查示例文案使用 sample dashboard data；该脚本已纳入离线回归。
- 未完成内容：本轮没有新增 visionOS 登录 / demo mode，也没有修改 CloudKit dashboard snapshot 生成逻辑；真实用户有 CloudKit 看板数据时仍优先显示真实数据。
- 测试情况：先新增 `scripts/check_visionos_review_smoke.py` 并执行，确认当前 main 缺少空 snapshot fallback 且包含 `return []` / simulator demo 文案时失败；修复后执行同一脚本，结果 PASS。后续收尾需执行完整离线回归、`git diff --check` 和 visionOS generic build。
- 风险与注意事项：示例数据只用于 review / 空数据兜底，不会写入用户账本；如果后续希望在 App 内显式区分“示例数据”和“真实数据”，应另开 UI 标识设计。
- 回滚方式：回退 `ContentView.swift` 中 `loadTransactions()` 的 fallback 逻辑和示例 note 文案，并删除 visionOS review smoke 脚本及离线回归入口。
- 结论：本轮代码移植已完成，等待收尾验证。
- 下一步建议：通过验证后提交到 `main`，不需要再把 1.6.4 hotfix 分支整体 merge。

### ITER-383 Worker 辅助建议响应映射
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345E / Pro Automation
- 类型：能力增强 / 隐私边界 / 测试
- 目标：在 Worker 真实接入前，先冻结 hash-only 响应 schema 和本地映射规则，让服务端未来只返回不可直接展示的 hash 建议，客户端再在本机解析成用户可读预览。
- 改动范围：更新 `AutoLedgerCore` 数据清洗辅助合同、离线回归、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 App UI、SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未新增网络上传、Worker endpoint、服务端模型建议、Pro 网络授权、配额、用户开关或跨设备建议队列。
- 完成内容：新增 `DataCleaningAssistResponse`、`DataCleaningAssistSuggestion` 和 `DataCleaningAssistSuggestionKind`，定义 `hashed_suggestions_v1` 响应只携带 kind、候选商户 hash、目标商户 hash、confidence 和 reason code。
- 完成内容：新增 `DataCleaningAssistSuggestionMapper`，用本机交易重新计算商户 hash，将 Worker 返回的“候选 hash -> 目标 hash”解析为 `.merchantAlias` `DataCleaningPreviewItem`；真实商户名、受影响交易和可采纳动作只在本机产生。
- 完成内容：mapper 过滤未知 hash、低置信度、候选和目标相同、目标交易支撑不足、重复和已忽略建议；输出的 preview id、代表商户名和受影响交易顺序保持稳定。
- 完成内容：离线回归确认响应 JSON 不包含真实商户名或交易 UUID，并覆盖可行动建议映射、unknown hash 过滤、低置信度过滤、confidence 保留和 reason 写入。
- 未完成内容：本轮只完成本地响应合同和 mapper，没有接入 Worker 或 `common-api`；hash 只是稳定分组指纹，不是安全鉴权或匿名化数学证明，真正上传前仍需威胁建模、日志策略和字段复审。
- 测试情况：先新增离线 RED 断言并执行 `bash scripts/run_offline_regression.sh`，确认缺少 `DataCleaningAssistResponse`、`DataCleaningAssistSuggestion` 和 `DataCleaningAssistSuggestionMapper` 时编译失败；实现后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖 hash-only 响应和本地 preview 映射。
- 风险与注意事项：当前 mapper 只处理本地传入的响应对象，不能代表服务端可信执行；后续接入 Worker 时仍需用户显式开启云端 Pro 自动化、服务端鉴权、配额、请求 / 响应日志最小化和客户端可撤销预览。
- 回滚方式：删除 `DataCleaningAssistResponse`、`DataCleaningAssistSuggestion`、`DataCleaningAssistSuggestionMapper` 和对应离线回归断言，并回退文档记录；不涉及数据迁移或用户数据。
- 结论：本轮完成；`GOAL-2345E` 已把 Worker 辅助建议的返回侧合同落成可回归代码，但仍保持零上传和零 Worker 调用。
- 下一步建议：继续补 Worker 辅助建议的用户授权开关 / 请求策略，或转向 Mac / iPad 大屏数据清洗表格与忽略项管理。

### ITER-382 Worker 辅助建议脱敏合同
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345D / Pro Automation
- 类型：能力增强 / 隐私边界 / 测试
- 目标：在真正接入 Worker 辅助建议之前，先冻结本地脱敏 payload 合同，确保后续云端只看到不可还原账本明细的聚合特征。
- 改动范围：新增 `AutoLedgerCore` `DataCleaningAssistPayload` 合同和 builder，更新离线回归和显式编译清单，并回填 `versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 App UI、SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未新增网络上传、Worker endpoint、服务端模型建议、返回建议 schema、Pro 网络授权、配额或用户开关。
- 完成内容：新增 `DataCleaningAssistPayloadBuilder`，将本地交易聚合为 `hashed_aggregate_v1` payload，包含 normalized merchant hash、normalized length、交易数量、分类 / 来源分布、金额区间桶、prefix hash、已存在 alias / category correction 的 hash 或 enum 值。
- 完成内容：payload 不包含真实商户名、备注、OCR 原文、交易 UUID、订单号、手机号、精确金额或账单日期；prefix 只暴露 hash 和长度，未来 Worker 可返回 hash 对 hash 的建议，再由客户端本地映射成用户可读建议。
- 完成内容：离线回归新增 forbidden fragments 检查，确认 JSON 编码结果不会泄漏真实商户名、门店后缀、订单号、手机号、OCR 原文或交易 UUID；同时验证聚合特征、金额区间、prefix hash overlap 和输入顺序确定性。
- 完成内容：`scripts/run_offline_regression.sh` 显式加入新 Core 文件，保证脱敏合同进入离线门禁。
- 未完成内容：本轮只完成本地合同，没有接入 Worker 或 `common-api`；hash 只是稳定分组指纹，不是安全鉴权或匿名化数学证明，真正上传前仍需威胁建模和字段复审。
- 测试情况：先新增离线 RED 断言并执行 `bash scripts/run_offline_regression.sh`，确认缺少 `DataCleaningAssistPayloadBuilder` 时编译失败；实现后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖脱敏 payload schema、聚合特征、金额区间、prefix hash overlap、禁止 raw 数据泄漏和输入顺序确定性。
- 风险与注意事项：如果后续把该 payload 上传到 Worker，仍需要用户显式开启云端 Pro 自动化、服务端鉴权、配额、日志最小化和返回建议 schema；不能因为 payload 已脱敏就默认允许后台静默上传。
- 回滚方式：删除 `DataCleaningAssistPayload.swift`、离线回归新增用例和 `run_offline_regression.sh` 新增源文件，并回退对应文档记录；不涉及数据迁移或用户数据。
- 结论：本轮完成；`GOAL-2345D` 已把 Worker 辅助建议的最小隐私合同落成可回归代码，但仍保持零上传。
- 下一步建议：继续设计 Worker 返回建议 schema 和用户授权开关，或先补 Mac / iPad 大屏历史表格与忽略项管理。

### ITER-381 数据清洗采纳历史与审计
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345C / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：在忽略建议和批量采纳之后，补齐数据清洗采纳历史，让用户采纳建议后仍能看到最近结果、撤销入口和本机审计记录。
- 改动范围：更新 `LedgerStore` 本机历史记录模型与持久化、iPhone `DataCleaningSuggestionsView` 历史区域、五语本地化、离线回归、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未实现跨设备建议队列、忽略项管理列表、Worker 辅助解释、脱敏特征合同或 Mac 专属历史表格 UI。
- 完成内容：新增 `DataCleaningApplicationHistoryEntry` 和 `dataCleaningApplicationHistory`，记录采纳建议 ID、建议类型、建议标题、采纳数量、更新 / 删除 / 跳过数量和采纳时间。
- 完成内容：历史记录使用本机 `UserDefaults` 持久化，最多保留最近 20 条；撤销上次数据清洗时将对应历史项标记为已撤销，保留审计痕迹。
- 完成内容：iPhone“智能整理建议”页把“最近一次结果 / 撤销”从建议列表中拆出，并新增“最近清洗记录”；建议清空后页面不再只显示空状态。
- 完成内容：五语补齐历史标题、统计格式、已应用和已撤销状态文案。
- 未完成内容：历史记录当前不同步到 iCloud / CloudKit，也不会上传到 Worker；如果后续需要跨设备建议队列，应先冻结隐私边界和同步合同。
- 测试情况：先新增离线 RED 断言并执行 `bash scripts/run_offline_regression.sh`，确认缺少 `dataCleaningApplicationHistory` 时编译失败；实现后执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；五语 `Localizable.strings` `plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖采纳历史记录与撤销标记；使用 XcodeBuildMCP 执行 iPhone 17 Pro Max Simulator Debug build/run，结果 PASS，构建日志 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-07T06-44-34-761Z_pid47116_0aee8116.log`，仅保留既有 warning，随后已停止模拟器 App。
- 风险与注意事项：本轮历史是本机轻量审计，不是跨设备事实源；用户换设备或清理 App 数据后历史不会保留，但已采纳的商户别名和规则仍按现有链路继续生效。
- 回滚方式：回退 `LedgerStore` 历史模型 / UserDefaults 持久化、`DataCleaningSuggestionsView` 历史区域和五语文案，并删除离线回归新增断言；不涉及数据迁移或 CloudKit schema。
- 结论：本轮完成；`GOAL-2345C` 形成本地可追溯的建议采纳历史，并让 iPhone 采纳后的页面状态更清楚。
- 下一步建议：继续设计 Worker 辅助建议的脱敏特征合同，或先补 Mac / iPad 大屏历史表格与忽略项管理入口。

### ITER-380 Common API 直辖市区县下钻开关
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2309 / Common API
- 类型：能力增强 / 基础设施 / 测试
- 目标：为共享 `common-api` 地点目录补充直辖市区县级候选，同时避免 AutoLedger 默认城市选择被区县项污染；区县下钻主要供 AutoNotice 等需要更精确地点的 App 显式复用。
- 改动范围：更新 `tools/worker/common-api/src/places-catalog.ts`、`tools/worker/common-api/src/index.ts`、Worker 合同测试、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 AutoLedger App UI、酒店消费编辑页、App 内置地点 fallback、账本数据、SQLite / CloudKit schema、StoreKit、ASC、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。
- 完成内容：地点 catalog 为北京、上海、重庆、天津补充 `administrativeLevel`、`parentId`、`municipality` / `district` tags 和五语区县名称，资源版本推进到 `2026.07.07.1`。
- 完成内容：`GET /v1/locations/cities` 默认过滤 `administrativeLevel=district` 记录，只返回城市级候选；调用方显式传 `includeDistricts=true` 时才返回区县级记录，并在响应中返回 `includeDistricts` 标记。
- 完成内容：合同测试覆盖默认不返回北京海淀区、显式开启后返回北京海淀区和重庆渝中区，并验证简体中文、英文、韩语展示名和区县元数据。
- 未完成内容：本轮未改造 AutoNotice 客户端，也未把区县下钻接入 AutoLedger 酒店消费编辑；若 AutoNotice 需要更多国家 / 城市区县，应在 common-api 继续按轻量常用集追加，不维护全量世界行政区库。
- 测试情况：先新增合同测试并执行 `npm test`，确认默认端点仍返回区县导致预期失败；实现 `includeDistricts` 开关后再次执行 `npm test`，结果 PASS，29 个测试通过。
- 风险与注意事项：区县名称为静态轻量目录，适合常见地点选择，不适合作为完整 GIS 数据源；默认城市端点保持城市级是兼容 AutoLedger 的关键边界。
- 回滚方式：回退 `places-catalog.ts` 的区县记录和 `index.ts` 的 `includeDistricts` 参数处理，并删除对应合同测试与文档记录，即可恢复到纯城市目录。
- 结论：本轮完成；common-api 已具备可选区县下钻能力，同时 AutoLedger 默认调用仍保持城市级。
- 下一步建议：回到 AutoLedger 1.7.0 Pro 自动化主线，继续建议历史 / 审计记录或 Worker 辅助建议的脱敏特征合同设计。

### ITER-379 数据清洗忽略建议与批量采纳
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345B / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：在 `GOAL-2345A` 的本地商户归一化建议基础上，补齐用户可忽略建议和一次性采纳多个建议的闭环，让 iPhone 与 iPad / Mac 数据清洗入口使用同一份建议状态。
- 改动范围：更新 `DataCleaningPreviewPlanner` ignored preview 过滤参数、`LedgerStore` 忽略建议持久化和批量采纳 / 撤销逻辑、iPhone `DataCleaningSuggestionsView`、iPad / Mac `IPadCleaningPreviewWorkspaceView`、五语本地化、离线回归、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit 商品 ID、Worker、Common API、App Store Connect、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未实现建议历史、忽略项管理列表、跨设备建议队列、Worker 辅助解释、更复杂模糊合并或 Mac 专属批量表格 UI。
- 完成内容：`DataCleaningPreviewPlanner.buildSnapshot` 新增默认参数 `ignoredPreviewIDs`，可过滤用户已忽略的建议，并保持旧调用兼容。
- 完成内容：`LedgerStore` 新增 `ignoredDataCleaningPreviewIDs`，使用 `UserDefaults` 做本机持久化；新增 `dataCleaningPreviewSnapshot()`、`ignoreDataCleaningPreview(id:)` 和 `restoreIgnoredDataCleaningPreview(id:)`，让 iPhone 与 iPad / Mac 工作台读取同一份当前账本过滤快照。
- 完成内容：`applyDataCleaningPreview` 保持单条 API，但内部复用新的 `applyDataCleaningPreviews`；批量采纳会按建议 ID 去重并只生成一次撤销快照，撤销会恢复历史账单、最近删除和商户别名状态。
- 完成内容：iPhone“智能整理建议”页新增“全部应用”和单条“忽略”按钮；iPad / Mac 数据清洗工作台新增同样动作。五语补齐 `ipad.cleaning.apply_all` 与 `ipad.cleaning.ignore`。
- 未完成内容：忽略建议目前是本机偏好，不会通过 iCloud / CloudKit 同步；跨设备仍按本地账本重算建议。没有新增审计历史，也没有把建议发送到 Worker。
- 测试情况：先新增离线 RED 断言并运行 `bash scripts/run_offline_regression.sh`，观察到缺少 `ignoredPreviewIDs`、`ignoreDataCleaningPreview`、`dataCleaningPreviewSnapshot`、`restoreIgnoredDataCleaningPreview` 和 `applyDataCleaningPreviews` 的预期编译失败。实现后执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；五语 `Localizable.strings` `plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖忽略过滤、恢复忽略、批量采纳两条商户归一化建议、批量撤销恢复别名和历史账单；使用 XcodeBuildMCP 执行 iPhone 17 Pro Max Simulator Debug build/run，结果 PASS，构建日志 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-07T05-51-19-143Z_pid47116_1dacf729.log`，仅保留既有 warning，随后已停止模拟器 App。
- 风险与注意事项：忽略状态当前只保存在本机 `UserDefaults`，不会随账本数据同步；如果用户在另一台设备打开数据清洗页，仍可能看到同一条建议。批量采纳使用同一撤销快照，但仍是本地 UI gate，不是服务端安全边界。
- 回滚方式：回退 `DataCleaningPreviewPlanner` 的 `ignoredPreviewIDs` 参数、`LedgerStore` 忽略 / 批量采纳 API、两个数据清洗 UI 的按钮和五语文案，并删除离线回归新增断言；不涉及数据迁移。
- 结论：本轮完成；`GOAL-2345B` 已形成本地可用的忽略与批量采纳闭环，且 iPhone 与 iPad / Mac 入口使用同一份建议快照。
- 下一步建议：继续设计建议历史和审计记录，再评估跨设备同步“已采纳规则”与“本机忽略偏好”的边界；Worker 辅助建议应先冻结脱敏特征合同。

### ITER-378 商户归一化建议与 iPhone 智能整理入口
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：GOAL-2345A / Pro Automation
- 类型：能力增强 / Pro 边界治理 / UI
- 目标：优先完成 iOS 和通用平台层面的 Pro 自动化第一段，让 App 可以本地分析账本、提出商户归一化建议，并在 iPhone 上提供可采纳入口。
- 改动范围：更新 `DataCleaningPreviewPlanner`、`AutoLedgerProAccessPolicy`、`LedgerStore` 数据清洗采纳 / 撤销逻辑、新增 `DataCleaningSuggestionsView`、设置页入口、iPad / Mac 清洗原因文案、五语本地化、离线回归、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、StoreKit 商品 ID、App Store Connect、Worker、截图导出、Xcode Cloud 脚本、signing、entitlements、`MARKETING_VERSION` 或 build number。未实现 Worker 辅助建议、忽略建议、建议历史、批量全选、跨设备建议队列、复杂模糊匹配或 Mac 专属新 UI。
- 完成内容：`DataCleaningPreviewPlanner` 新增本地商户归一化建议。规则先保持保守：短商户名在账本中至少出现 2 次，长商户名以该短商户名为前缀并带有额外后缀时，生成 `.merchantAlias` 建议，适合门店、航站楼、分店等常见后缀整理。
- 完成内容：`LedgerStore.applyDataCleaningPreview` 在采纳商户统一建议时会写入商户别名并回刷历史账单；后续 OCR、快捷指令、语音、Share Extension 和手动新增账单继续复用既有别名规则。数据清洗撤销现在会恢复采纳前的商户别名状态，避免撤销后残留自动建议规则。
- 完成内容：新增 `AutoLedgerCapability.merchantNormalizationSuggestions`，归入 `proAutomationP0` 和本地 UI gate；基础商户别名、分类学习、单条编辑和已采纳规则继续免费。
- 完成内容：iPhone 设置页“规则”区域新增“智能整理建议”入口。Pro 用户可查看商户统一、分类修正和疑似重复建议，逐条采纳并撤销上次清洗；未订阅用户看到 Pro 自动化说明和免费能力说明。iPad / Mac 既有数据清洗工作台复用同一 planner，并能显示新的商户归一化原因。
- 测试情况：先新增离线 RED 用例，确认 `DataCleaningPreviewPlanner suggests merchant normalization from ledger history` 和 `LedgerStore can preview merchant normalization suggestions from history` 失败；实现后执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖建议生成、采纳写入别名、历史回刷、撤销恢复别名、后续 OCR 入账应用别名和 Pro policy gate。执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；五语 `Localizable.strings` `plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build/run，结果 PASS，日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-07T04-09-01-879Z_pid26522_a66d0959.log`，仅保留既有 warning，随后已停止模拟器 App。
- 风险与注意事项：第一段只做高置信前缀式归一化，不做任意模糊合并，避免误把不同商户合并。建议队列目前为本地实时计算，不持久化忽略状态；如果用户暂时不想采纳，只能离开页面或手动维护别名。Pro gate 是本地 UI gate，不是服务器安全边界。
- 回滚方式：回退 `DataCleaningPreviewPlanner` 的 `merchantNormalizationItems` 逻辑、`AutoLedgerCapability.merchantNormalizationSuggestions`、`LedgerStore` 别名状态快照恢复、新增 `DataCleaningSuggestionsView`、设置页入口和五语文案，并删除新增离线回归断言；不涉及数据迁移。
- 结论：本轮完成；`GOAL-2345` 已有可运行的本地第一段，iOS 和 iPad / Mac 共用同一套建议引擎，采纳结果会反哺后续识别链路。
- 下一步建议：继续做 `GOAL-2345B`，补“忽略建议 / 建议历史 / 批量采纳 / 更细的置信解释”；随后再评估 Worker 辅助模式的脱敏特征合同。

### ITER-377 OCR 金额差异去重保护与数据清洗计划
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Ledger Import / Data Cleaning Planning
- 类型：Bugfix / 文档 / Pro 边界治理
- 目标：修复同商户、时间接近但金额不同的 OCR 账单被相似文本去重误判为重复的问题，并把 Mac / iOS 商户归一化与数据清洗建议写入 `v1.7.0` 执行计划。
- 改动范围：更新 `ImportDuplicateDetector`、App 内 OCR / 快捷指令 / 语音 / Share Extension 去重调用点、`scripts/OfflineRegression.swift`、`versions/v1.7.0-plan.md`、`docs/operations/pro-access-audit.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite / CloudKit schema、账单解析字段、OCR UI、快捷指令参数、商户别名存储结构、分类学习实现、Common API、Worker、StoreKit、App Store Connect、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`ImportDuplicateDetector.hasOCRTextDuplicate` 新增解析金额保护：当前导入金额和历史 debug record 金额都存在且差异超过 `0.01` 时，该历史 OCR 文本不参与 Jaccard 重复判断；缺少金额的旧 debug record 继续保持兼容，避免破坏旧导入记录。`LedgerStore`、`QuickLedgerIntent`、`VoiceLedgerIntent` 和 Share Extension 传入解析金额，共享同一规则。离线回归新增同商户同时间、OCR 文本高度相似但金额不同的样例，确认 `12.50` 与 `13.50` 两笔都能入账，同时既有相同金额相似 OCR 去重仍通过。
- 完成内容：`v1.7.0` 计划新增 `GOAL-2345` 商户归一化与数据清洗建议，明确 Mac 端继续作为大屏清洗工作台、iOS 端复用同一建议合同提供轻量采纳；基础商户别名、分类学习、单条编辑和已采纳规则后续生效继续免费，Pro 只覆盖全账本自动分析、模型辅助建议、批量预览 / 应用、低置信度集中复核和可选 Worker 辅助。计划要求采纳结果反哺 OCR、快捷指令、语音、Share Extension 和手动记账保存前规则链路。
- 未完成内容：本轮未实现新的商户归一化建议引擎、Mac / iOS 建议 UI、Worker 辅助分析、CloudKit 规则同步变更或新的 Pro policy capability；这些仍属于 `GOAL-2345` 后续实现范围。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增 “LedgerStore does not skip OCR-similar same-merchant receipts when amounts differ” 用例通过；脚本仍输出既有 `AppFormatters` `nonisolated(unsafe)` warning，本轮未处理。后续还需执行 `git diff --check` 作为收尾门禁。
- 风险与注意事项：金额保护只在当前解析金额与历史 debug 金额都存在时排除相似 OCR；如果旧记录没有金额或新解析没识别到金额，仍沿用原相似文本去重策略以防重复导入。数据清洗建议规划涉及 Pro 边界和隐私边界，后续实现前必须先冻结建议合同、脱敏策略、撤销模型和本地 / Worker 模式切换。
- 回滚方式：回退 `ImportDuplicateDetector` 的 `parsedAmount` / `amountTolerance` 参数与过滤逻辑，并移除四个调用点传参和离线回归新增用例；文档层回滚 `GOAL-2345`、Pro audit、CHANGELOG 与本日志条目即可。
- 结论：本轮代码修复已通过离线回归；商户归一化与数据清洗建议已进入 `v1.7.0` 执行计划，但实现仍需单独开 GOAL。
- 下一步建议：进入 `GOAL-2345` 前先设计平台无关 suggestion schema、采纳 / 忽略 / 撤销模型和隐私边界，再分别落 Mac 工作台与 iOS 轻量采纳入口。

### ITER-376 CloudKit Production schema 发布门禁
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release / CloudKit
- 类型：治理 / 发布门禁
- 目标：把 TestFlight 中 `CloudKit rejected record save` 的实际原因沉淀为固定发布检查，避免后续新增 CloudKit 字段后忘记部署 Production schema。
- 改动范围：更新 `process/agent-iteration-workflow.md`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 App 业务代码、CloudKit adapter、SQLite / Backup schema、Common API、StoreKit、App Store Connect 线上元数据、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：确认 TestFlight `767f41d` 在解决 iCloud 冲突后强制刷新报 `CloudKit rejected record save`，执行 CloudKit Console `Deploy Schema Changes` 后同步正常完成。发布工作流新增门禁：凡 CloudKit record type、field 或 index 有新增 / 修改，TestFlight / ASC 前必须把 Development schema deploy 到 Production，并在回归基线或迭代日志中记录证据。`v1.7.0` 计划同步记录本次事故原因和不做代码侧静默降级的结论。
- 未完成内容：本轮未创建自动化 CloudKit schema audit 工具；CloudKit Console 部署动作仍需人工完成并记录证据。
- 测试情况：执行 `git diff --check`，结果 PASS。用户反馈执行 CloudKit Console `Deploy Schema Changes` 后，TestFlight 强制刷新 iCloud 数据已正常完成。
- 风险与注意事项：TestFlight 和 App Store 使用 CloudKit Production 环境；Development 下能保存新字段不代表外测可用。后续如果新增 `LedgerTransaction` 币种字段、酒店同步字段、dashboard snapshot 字段或索引，必须先部署 Production schema。
- 回滚方式：回退本轮文档变更即可；不涉及代码或数据迁移。
- 结论：本轮完成；CloudKit schema 部署从口头提醒变为发布硬门禁。
- 下一步建议：后续可在 ASC metadata-as-code 或 release checklist 中增加一条“CloudKit schema deploy evidence”检查项，必要时再评估 CloudKit schema 自动审计脚本。

### ITER-375 快捷指令 SQLite 写入锁等待
- 日期：2026-07-07
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Persistence / App Intents
- 类型：Bugfix / 可靠性
- 目标：降低快捷指令记账在识别成功后偶发“入账失败”的概率，并让失败 debug 记录包含可定位的 SQLite 错误信息。
- 改动范围：更新 `SQLiteTransactionStore`、`scripts/OfflineRegression.swift`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 SQLite schema、`QuickLedgerIntent` 的 OCR / 解析 / 去重逻辑、快捷指令参数、iCloud 同步策略、Widget / Watch 数据结构、StoreKit、App Store Connect、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`SQLiteTransactionStore` 打开数据库后启用 extended result codes、设置 `busy_timeout`、尝试切换 WAL journal 和 NORMAL synchronous；普通交易 `save(transaction:)` 在 `SQLITE_BUSY` / `SQLITE_LOCKED` 时进行短延迟重试，覆盖 App 本体、快捷指令、Widget / Watch 刷新或 iCloud 同步短暂争用同一 App Group SQLite 的情况。SQLite prepare / execute 失败会把 `sqlite_code`、`sqlite_extended_code` 和 `sqlite_errmsg` 拼进错误描述，让 `QuickLedgerIntent` 的 `persistenceFailed` debug record 后续能看到具体原因。
- 未完成内容：本轮只为正式交易保存路径加短重试；其它 SQLite 写入路径仍主要依赖 connection-level busy timeout。未新增用户可见的失败详情页，也未做真机快捷指令压力测试。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增 busy retry 用例覆盖“原生 SQLite 连接持有 writer lock -> 另一 `SQLiteTransactionStore.save(transaction:)` 等待 -> 释放锁后保存成功 -> 重新打开数据库能读到该笔交易”；执行 `git diff --check`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build/run，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-07T00-58-55-668Z_pid26522_9078c175.log`，仅保留既有 warning；随后已停止模拟器内 App。
- 风险与注意事项：busy timeout 和短重试会在数据库被其它连接短暂占用时多等待一小段时间，换取快捷指令后台写入成功率；如果遇到长期锁、只读库或 schema 错误，仍会失败，但 debug record 会带 SQLite code 和 message。WAL / synchronous 是连接级配置，不改变表结构。
- 回滚方式：回退 `SQLiteTransactionStore` 的连接配置、`save(transaction:)` 重试和错误详情 helper，并删除离线回归 busy retry 用例；无数据库迁移回滚动作。
- 结论：本轮完成；快捷指令识别成功后的本地入账对短暂 SQLite 写锁更耐受，后续若仍出现“入账失败”可根据 debug record 的 SQLite code 继续定位。
- 下一步建议：用户可在真机上连续触发快捷指令、同时打开 App 做 iCloud 同步或 Widget 刷新复测；若仍有失败，再把 `persistenceFailed` 最新 debug record 中的 sqlite code/message 贴出来定位。

### ITER-374 运行时本地化补齐
- 日期：2026-07-06
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / Settings
- 类型：Bugfix / 本地化
- 目标：修复 App 内语言 override 下，部分运行时拼接字符串仍跟随系统语言或默认语言的问题。
- 改动范围：更新 `AppLanguagePreference`、`LanguageSettingsView`、`InboxView`、`TransactionEditorView`、`HotelStayArchiveView`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改本地化 key 文案、App 语言设置入口、币种目录、common-api、SQLite / CloudKit schema、StoreKit、App Store Connect、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：新增 `AppLanguagePreference.localizedString` / `localizedStrings`，按 App 当前语言显式读取对应 `.lproj`。`LanguageSettingsView` 的消费默认币种菜单和副标题、`InboxView` 的快捷记账说明、流程步骤、首页统计、导入按钮和相对日期、`TransactionEditorView` 的标题 / 占位符 / 弹窗动态文案、`HotelStayDetailView` 的标题 / raw text 空状态 / 来源字段 / 保存提示改为使用该 helper。快捷指令记账统计同时匹配五语 `quick_ledger.note`，避免语言切换后历史快捷记录不被计入。
- 未完成内容：本轮未全量替换 App 内所有 `String(localized:)`；酒店消费列表、账本列表等其它页面若继续出现同类运行时本地化问题，后续按同一 helper 逐页收口。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；执行五语 `plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build/run，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-06T05-28-39-920Z_pid57615_e064a3db.log`，仅保留既有 warning；随后将模拟器 App 语言偏好写为 `ja` 并重启，确认 App 语言 override 生效。XcodeBuildMCP UI 快照受当前 Xcode-beta `SimulatorKit.framework` 路径缺失影响未能使用语义点按验证记账首页截图。
- 风险与注意事项：运行时 helper 只影响显式调用路径；用户数据字段如账本名、商户名、酒店名不会也不应被自动翻译。当前模拟器上仍可看到历史账本名为中文，这是数据内容，不属于本轮本地化 key 修复。
- 回滚方式：回退 `AppLanguagePreference` 新增 helper 及上述页面调用，并恢复本轮文档记录即可；无数据迁移回滚动作。
- 结论：本轮完成；截图中记账首页、普通账单编辑和酒店消费详情的动态 UI 文案会跟随 App 内语言设置。
- 下一步建议：后续可继续用 `AppLanguagePreference.localizedString` 专项扫描酒店消费列表、账本列表和其它 `String(localized:)` 运行时路径，逐页消除 App 语言 override 漏项。

### ITER-373 D1 Release Notes 版本映射修正
- 日期：2026-07-06
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Common API / Settings
- 类型：数据治理 / 文案治理
- 目标：修正 `common-api` D1 中 AutoLedger Release Notes 的版本号映射，让当前已上线 / 审核基线文案归属 `1.5.0`，并为正在开发的 `v1.7.0` 主线准备对外 `ASC 1.6.0` 的远端版本说明。
- 改动范围：更新 `tools/worker/common-api` release notes seed、D1 seed 脚本、Worker 合同测试、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Worker 路由实现、App 设置页调用逻辑、SQLite / CloudKit schema、StoreKit、App Store Connect、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number；未创建构建触发 tag。
- 完成内容：将原 `autoledger / 1.6.0` 五语 Pro / 酒店自动化说明移动为 `autoledger / 1.5.0`；新增 `autoledger / 1.6.0` 五语草稿，内容对应当前内部 `v1.7.0` 开发线，面向终端用户说明实时 OCR、韩语界面与识别、多币种、酒店水单复核和后续 Pro 自动化计划。Seed 文件改为 `release_notes_autoledger_versions.sql`，避免文件名继续暗示单版本数据。Worker 单测增加 `1.5.0` / `1.6.0` 并存断言，manifest 预期支持版本更新为两项。
- 未完成内容：本轮未把 ASC metadata、截图说明和 App Preview 文案接入同一数据源；未实现后台管理界面或自动翻译 / 审校流程。
- 测试情况：执行 `git diff --check`，结果 PASS；在 `tools/worker/common-api` 执行 `npx wrangler --version` 确认当前 CLI 为 `4.106.0`；执行 `npm run check`，结果 PASS，覆盖 `wrangler types`、`tsc --noEmit` 和 27 个 Vitest 合同测试。执行 `npm run d1:seed:staging` 与 `npm run d1:seed:production`，两套 D1 均成功 upsert `release_notes_autoledger_versions.sql`。D1 远端查询确认 staging / production 均存在 `autoledger / 1.5.0` 和 `autoledger / 1.6.0`，每个版本 5 个 published locale，resource version 均为 `2026.07.06.2`。线上 smoke 确认 `https://staging-api.darkrio326.top` 和 `https://api.darkrio326.top` 的 `/v1/release-notes` 对 `1.5.0` 返回旧 Pro 自动化文案，对 `1.6.0` 返回实时 OCR / 韩语 / 多币种新文案，`/v1/manifest` 同时列出 `1.5.0`、`1.6.0` 和五语 locale。
- 风险与注意事项：旧 `1.6.0` 行会被 upsert 成新的 ASC 1.6.0 草稿；如果仍有客户端把当前 ASC 1.5.0 内容请求为 `1.6.0`，将看到新开发线说明。当前产品约定以客户端公开版本号为准，请求 `1.5.0` 时才返回 ASC 1.5.0 文案。
- 回滚方式：恢复上一版 seed 和测试，或在 D1 中把 `autoledger / 1.6.0` 行内容重新 upsert 为旧文案；无 schema 迁移回滚动作。
- 结论：本轮完成并已写入 staging / production D1；远端版本说明现在按客户端公开版本号区分 `1.5.0` 与 `1.6.0`。
- 下一步建议：将 release notes 数据纳入后续 ASC metadata-as-code 工具链，避免手工维护多处版本说明。

### ITER-372 酒店复核房晚与入账同步
- 日期：2026-07-06
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Hotel Stay / Review
- 类型：Bugfix
- 目标：修复酒店消费复核时，用户修改入住 / 退房日期后房晚不随之变化，以及确认入账仍可能沿用原始识别 payload 的问题。
- 改动范围：更新 `HotelStayReviewForm`、`HotelStayReviewView`、离线回归、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改酒店 PDF / OCR 解析器、邮箱 / 云收件箱导入、SQLite / CloudKit schema、Common API、StoreKit、截图导出、App Store Connect、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：复核页在 `checkInDate` 或 `checkOutDate` 变化时调用表单方法实时重算房晚；表单重算复用 `AppFormatters.parseFlexibleDate` 和 `normalizedDateString`，可处理已经归一化或 OCR 常见非标准日期。确认时会把复核后的表单值写回 confirmed draft 的 `parsedPayload`，让后续 `HotelStayLedgerPostingService` 读取到用户最终确认的酒店名、退房日期、房晚、支付方式和金额。离线回归新增从日期修改、房晚重算、确认 draft 到正式入账记录 / 关联账单日期的闭环断言。
- 未完成内容：本轮未把入住 / 退房复核控件从文本候选菜单改成 DatePicker；未新增真实酒店水单样本集；未对已发布二进制做 retroactive 修复。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖酒店复核日期修改、房晚重算、确认 draft 和入账记录 / 关联账单使用复核结果；执行 `git diff --check`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-07-06T03-48-31-516Z_pid57615_5afd8970.log`，仅保留既有 warning。
- 风险与注意事项：确认 draft 后 `parsedPayload` 现在代表复核后的入账事实，不再保留一份覆盖入账的原始识别 payload；原始 PDF、raw text 和 OCR 摘要仍保留用于追溯。该行为符合“用户复核后才入账”的当前产品语义。
- 回滚方式：回退 `HotelStayReviewForm` 的 payload 写回与房晚重算方法、`HotelStayReviewView` 的日期 onChange、离线回归和文档记录即可；无数据迁移回滚动作。
- 结论：本轮完成并通过回归验证；酒店消费复核确认后会按用户最后确认的日期、房晚和字段入账。
- 下一步建议：后续可把酒店复核的入住 / 退房控件升级为 DatePicker + 候选值选择组合，并用更多真实酒店 PDF 验证日期候选排序。

### ITER-371 D1 远端版本说明
- 日期：2026-07-06
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Common API / Settings
- 类型：能力增强 / UI 文案治理
- 目标：把设置页“当前版本”和“后续计划”从 App 二进制硬编码主路径迁移到服务端 Worker + Cloudflare D1 维护的版本号对应 Release Notes，让客户端按自己的版本号和语言拉取说明文本。
- 改动范围：新增 `common-api` D1 `release_notes` schema / seed、`/v1/release-notes` 只读端点、manifest `releaseNotes` 能力位、D1 绑定和 Worker 合同测试；新增 App 端 `CommonAPIReleaseNotesService`；调整 `SettingsView` 使用远端 current / upcoming 文案并保留本地 fallback；更新 `CHANGELOG.md`、Worker README 和本日志。
- 未改动范围：未修改 StoreKit、Pro gate、账本 / 酒店 / 订阅数据 schema、CloudKit、App Store Connect、截图导出、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number；未移除本地 Localizable fallback；未上传任何用户账本、账单、酒店水单、订阅或账号数据。
- 完成内容：Worker 现在可通过 `GET /v1/release-notes?app=autoledger&version=1.6.0&locale=<locale>` 从 D1 `release_notes` 表返回 `current` 和 `upcoming` 文案；表主键为 `app_id + app_version + locale`，可同时承载不同 App、不同公开版本和不同语言。未知 app / 缺失版本 / 未配置版本会返回结构化错误；`/v1/manifest` 从 D1 聚合 release notes 能力、资源版本、支持 app、支持版本、支持语言和隐私边界。App 设置页根据 `CFBundleShortVersionString` 和 `AppLanguagePreference.current.catalogLanguageKey` 请求远端文案，先显示 Application Support 缓存，刷新成功后更新 UI；网络失败或 404 时继续显示本地文案。
- 未完成内容：本轮未接入后台 launch 预拉取 release notes；未做 App Store Connect metadata 自动同步；未为其它 App 增加 release notes 数据，只先落地 `autoledger` / `1.6.0` 五语 seed。
- 测试情况：在 `tools/worker/common-api` 执行 `npm run check`，结果 PASS，`wrangler types`、`tsc --noEmit` 和 26 个 Vitest 用例通过；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build/run，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_run_sim_2026-07-06T04-25-19-878Z_pid57615_98c96f6c.log`。已创建并绑定 D1 `darkrio-common-api-staging` / `darkrio-common-api-production`，staging / production 均执行 `0001_release_notes.sql` migration 和初始五语 seed，D1 查询确认 `autoledger / 1.6.0` published locale 数为 5；staging 部署 Version ID `39425a49-bc60-4a3f-914d-5656acd3d8c2`，production 部署 Version ID `9fccd49f-1112-4d68-b411-bc71d42a35f5`；`https://staging-api.darkrio326.top` 与 `https://api.darkrio326.top` 的 `/v1/manifest` 和 `/v1/release-notes?app=autoledger&version=1.6.0&locale=zh-Hans` smoke 均通过。
- 风险与注意事项：设置页文案首次打开时可能先显示本地 fallback，远端返回后再更新；如果服务端没有对应客户端版本，App 会继续显示本地文案。Release notes 是公开文案，存储在 Cloudflare D1 并由 Worker 只读返回，不含 secret。
- 回滚方式：回退 D1 binding / migration / seed、`release-notes-store.ts`、`index.ts`、Worker 测试、`CommonAPIReleaseNotesService.swift`、`SettingsView.swift` 和文档记录即可；App 会恢复只读本地 `Localizable.strings` 文案。远端如需回滚，可将对应 D1 行状态改为 `archived` 或恢复上一版 seed。
- 结论：本轮完成 D1 远端版本说明第一段，后续可以在 D1 中新增或更新版本号文案，不必为了设置页版本说明单独重打 App。
- 下一步建议：后续把 ASC metadata、App Preview / 截图说明和 App 内 release notes 统一到同一份版本文案源，减少多语言维护成本。

### ITER-370 酒店水单 OCR fallback 与确认候选
- 日期：2026-07-05
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Hotel Stay / Import Pipeline
- 类型：Bugfix / 能力增强
- 目标：修复用户拒绝一次酒店水单识别结果后，同一 PDF 被永久拦截的问题；同时处理文本层缺酒店名的 PDF，给用户更清晰的解析进度，并把房号、非标准日期和候选值选择纳入确认表单。
- 改动范围：更新 `LedgerStore` 酒店水单去重判断；新增共享 `HotelFolioPDFTextExtractor`；让手动 PDF、本地邮箱 PDF 和云候选 PDF 复用同一文本层 + OCR fallback 提取链路；更新酒店水单结构化模型、SQLite、CloudKit 映射、确认表单、编辑页、归档展示、截图样例、入账备注、五语文案、离线回归、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 StoreKit、Pro gate、邮箱授权、Cloudflare Worker、App Store Connect、截图导出管线、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number；未把 OCR 结果上传云端；未改变快捷方式记账和普通记账保存语义。
- 完成内容：`duplicateHotelStayDraftState(for:)` 现在遇到相同 fingerprint 但状态为 `.rejected` 的旧草稿时会继续查找其它记录，不再返回 duplicate rejected 状态；待确认草稿仍返回 pending，已确认 / 已入账草稿和正式酒店记录仍返回 posted，避免真正重复入账。PDF 导入先读取文本层，文本过短或缺少酒店信号时渲染前几页执行 Vision OCR，并把文本层与 OCR 行合并去重后交给酒店水单解析。iPad / Mac 手动导入状态会显示读取文本层、执行 OCR、整理文本和生成确认信息等阶段，不再只停在等待解析。酒店水单新增 `roomNumber` 字段，贯通 parsed payload、localized data、review form、record、SQLite、CloudKit sync、归档详情、编辑表单、截图 fixture 和入账备注。酒店到离店日期会把 `07-04-26`、`04/07/2026`、`2026年7月4日` 等格式归一化为 `yyyy-MM-dd`。确认表单的酒店名、到离店日期、房型、房号和确认号支持候选值下拉，同时保留手动输入。
- PDF 诊断：用户提供的 `张先生.pdf` 可由 PDFKit 打开，1 页，文本层包含客人、确认号、房号、到店 / 离店、Tianjin、账单号、房费和总计，但不包含酒店名称；因此本轮补上页面 OCR fallback，专门覆盖图片 Logo / 抬头中才有酒店名的样例。
- 未完成内容：未新增基于真实酒店样本的大规模回归集；未对已发布 `v1.6.4 / ASC 1.5.0` 二进制做 retroactive 修复；OCR fallback 目前最多扫描 PDF 前 3 页，超长水单仍以可控成本优先。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖拒绝草稿可重新导入、房号解析与持久化、非标准日期归一化、酒店水单解析流水线和既有账单 / 同步回归；执行 `bash scripts/run_golden_regression.sh`，结果 PASS，38 个 Golden case 通过；执行 `git diff --check`，结果 PASS；执行五语 `plutil -lint` 和 `python3 scripts/check_localization_coverage.py`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-07-05T13-40-14-598Z_pid86659_37199198.log`，仅保留既有 warning。
- 风险与注意事项：拒绝草稿仍保留在本地历史 / 备份中，只是不再参与去重拦截；如果同一 PDF 同时存在 pending 或 posted 版本，仍会被拦截。OCR fallback 会增加少量本机解析耗时，所以手动导入页现在用分阶段状态提示降低等待不确定性。SQLite 新增 `room_number` 列，旧库打开时会自动迁移。
- 回滚方式：回退 `HotelFolioPDFTextExtractor` 及三个 PDF importer 的调用、`HotelStay` / SQLite / CloudKit / UI / 本地化 / 回归改动，并把 `.rejected` 分支从 `continue` 改回返回 duplicate rejected 状态；如需数据层回滚，需要保留旧库对新增 `room_number` 列的容忍，不做破坏性迁移。
- 结论：本轮完成酒店水单拒绝后重试、PDF 页面 OCR fallback、解析进度可见、房号结构化、非标准日期识别和确认候选值选择，进入 1.7.0 酒店水单主线。
- 下一步建议：把用户样例和更多真实酒店水单脱敏后加入批量回归，继续优化酒店名、城市、税费和多币种字段的候选排序。

### ITER-369 酒店地点目录简繁判断修复
- 日期：2026-07-05
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / Hotel Stay
- 类型：Bugfix / 本地化
- 目标：修复酒店消费详情和城市选择列表在简体中文 UI 下可能显示繁体城市名的问题，并解释 `v1.6.4` 中列表与详情显示不一致的根因。
- 改动范围：更新 `AppLanguagePreference` 的地点目录语言 key 解析；让 `HotelStayLocationCatalog` 和 `CommonAPICatalogService.LocalizedText` 复用同一语言 key；更新 `CHANGELOG.md` 和本日志。
- 未改动范围：未修改酒店记录 schema、SQLite / CloudKit 字段、地点目录数据内容、common-api Worker、截图 / App Preview、App Store Connect、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：地点目录语言选择现在优先识别 `Hans` / `Hant` 脚本，再用 `TW` / `HK` / `MO` 地区兜底；`zh-Hans-HK`、`zh-Hans-MO` 等“简体中文 + 港澳台地区”不再被误判为繁体。酒店内置地点目录和 common-api 缓存目录都走同一套判断，避免详情页和城市列表继续漂移。
- 未完成内容：已发布的 `v1.6.4 / ASC 1.5.0` 二进制无法 retroactively 修复；需要后续 TestFlight / 正式构建携带该修复。
- 测试情况：执行 `git diff --check`，结果 PASS；使用 XcodeBuildMCP 执行 iPhone 17 Simulator Debug build，结果 PASS，构建日志位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-07-05T12-42-11-388Z_pid86659_8e4957f0.log`，仅保留既有 warning。
- 风险与注意事项：系统“跟随系统”模式下仍会根据 App 实际 preferred localization 和 locale 组合决定显示语言；本轮只修正脚本与地区优先级，不改变用户手动选择 App 语言的行为。
- 回滚方式：回退 `AppLanguagePreference.swift`、`HotelStayLocationCatalog.swift`、`CommonAPICatalogService.swift` 以及本轮文档记录即可；无数据迁移回滚动作。
- 结论：本轮完成，后续版本的酒店消费详情、城市列表和远程地点目录本地化会按 App 简繁语言一致显示。
- 下一步建议：在 1.6.0 TestFlight 或后续 1.7.0 smoke 中，用简体中文 + 香港 / 澳门 / 台湾地区设置验证重庆、广州、武汉等城市仍显示简体。

### ITER-368 国家和地区合规与语言设置入口
- 日期：2026-07-05
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / Common API / Settings
- 类型：治理 / UI 调整 / 基础设施
- 目标：统一 AutoLedger、AutoNotice 及后续项目的国家和地区选择口径，并让 AutoLedger 1.7.0 的语言切换入口在设置页中清晰可见。
- 改动范围：更新 AutoLedger App 的酒店地点内置 fallback、五语本地化、设置页分组、`common-api` 地点目录和合同测试；更新 AutoNotice 的位置选择文案与设计说明；更新 `README.md`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 AutoLedger / AutoNotice 的 bundle id、signing、entitlements、StoreKit 商品、App Store Connect 线上元数据、截图成品、App Icon、WeatherKit / APNs secret、SQLite / CloudKit schema 或 Xcode Cloud 脚本。
- 完成内容：AutoLedger 设置页中“区域与语言”从“外观”分组拆出为单独“语言与区域 / Language & Region”分组，继续进入既有 `LanguageSettingsView`，可切换跟随系统、简体中文、繁体中文、English、日本語、한국어，并管理默认消费币种。AutoLedger 酒店消费字段 `hotel_stay.review.country` 五语改为“国家和地区” / `Country/Region` 等。Common API 地点目录和 App 内置 fallback 中，香港、澳门、台湾国家和地区层级展示为“香港（中国）” / `Hong Kong (China)`、“澳门（中国）” / `Macau (China)`、“台湾（中国）” / `Taiwan (China)`，城市层级保持普通城市名；旧写法保留在 alias 中用于历史数据匹配。
- 未完成内容：本轮未新增全量国家 / 省州 / 城市数据库；未重新生成 App Store 截图；未修改历史已保存记录的原始文本，只在打开编辑 / 复核时按目录显示本地化名称。
- 测试情况：执行 `plutil -lint` 覆盖 AutoLedger 五语和 AutoNotice 双语 Localizable，结果 PASS；执行 `swiftc -parse AutoLedger/AutoLedger/Features/Hotel/HotelStayLocationCatalog.swift`，结果 PASS；执行 `npm run check` 于 `tools/worker/common-api`，结果 PASS，23 个 Vitest 用例通过；执行 `git diff --check`，结果 PASS。
- 风险与注意事项：Common API 地点目录资源版本已推进到 `2026.07.05.1`，客户端需通过 manifest 刷新后才能拿到远端目录新名称；App 内置 fallback 已同步，网络不可用时仍能显示新口径。当前 TestFlight 若未包含 1.7.0 代码，设置页可能仍看不到独立语言分组，需要新构建验证。
- 回滚方式：回退本轮 AutoLedger / AutoNotice 文案、`HotelStayLocationCatalog.swift`、`common-api` 地点目录与测试、README / 版本计划 / 日志；Common API 可用 `wrangler rollback --env production` 回退上一版本。
- 结论：本轮完成国家和地区合规口径和 AutoLedger 语言设置入口可见性调整，进入 1.7.0 / ASC 1.6.0 发布线。
- 下一步建议：构建 AutoLedger 1.7.0 TestFlight 后，重点验证设置页顶部是否显示“语言与区域”，以及酒店消费复核 / 编辑页的国家和地区字段是否显示新口径。

### ITER-367 Apple 原生多层图标规划
- 日期：2026-07-05
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Brand Assets / Release Assets
- 类型：文档 / 规划
- 目标：将 AutoLedger 后续 App Icon 升级到 Apple 原生多层图标体系，并与 AutoNotice 形成统一但不混淆的产品家族视觉语言，同时避免影响当前 `ASC 1.5.0` 审核线。
- 改动范围：更新 `versions/v1.7.0-plan.md` 的执行顺序、版本定位、目标范围、品牌资产小节、GOAL 队列、测试验收和非目标；更新 `CHANGELOG.md` 和本日志。
- 未改动范围：未修改 App 图标资源、Icon Composer 源文件、截图 / App Preview 成品、Swift 代码、Xcode 工程配置、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION`、build number 或 App Store Connect 线上元数据。
- 完成内容：新增 `GOAL-2355`，明确 AutoLedger 后续使用 Icon Composer / 多层源文件管理 Default、Dark、Mono 等外观，并导出 App Store 1024 图和各平台 fallback 图；AutoLedger 与 AutoNotice 共享玻璃质感、层次、光照、圆角和品牌色逻辑，但 AutoLedger 保留账本、账单卡片、金额线条和自动整理语义。
- 未完成内容：未实际生成新图标、未接入 Xcode asset catalog、未导出商店图标、未对 AutoNotice 资产做联动设计。
- 测试情况：执行 `git diff --check`，结果 PASS。
- 风险与注意事项：图标更新涉及二进制、商店素材、官网素材和截图联动，不应穿插进当前 `ASC 1.5.0` 审核热修；后续真正落地图标时，需要先完成多层源文件和导出规范，再统一替换各平台资源。
- 回滚方式：回退 `versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志中的本轮文档记录即可；没有代码或资源回滚动作。
- 结论：本轮完成品牌资产规划入列，图标升级进入 `v1.7.0 / ASC 1.6.0`，当前审核线不受影响。
- 下一步建议：待 `ASC 1.5.0` 审核稳定后，再以 `GOAL-2355` 单独开工，先产出 AutoLedger / AutoNotice 并排视觉方向和 Icon Composer 源资产。

### ITER-366 Common API WeatherKit 酒店历史天气 staging
- 日期：2026-07-03
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / WeatherKit
- 类型：能力增强 / 基础设施 / 回归
- 目标：在不影响 production 的前提下，把 `common-api` 的 WeatherKit staging 凭据和酒店入住日期历史天气端点跑通，为后续酒店消费详情展示历史天气摘要做准备。
- 改动范围：更新 `tools/worker/common-api` 的天气类型、provider、route、内存缓存、manifest、staging 环境变量、Worker 合同测试和 README；更新 `versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志；配置 staging WeatherKit secrets 并部署 `darkrio-common-api-staging`。
- 未改动范围：本轮未修改 App Swift 代码、App 酒店消费详情 UI、production WeatherKit secrets、production `WEATHER_PROVIDER`、服务端鉴权、限流、R2 / D1、App Store Connect、StoreKit、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：staging Worker 已配置 WeatherKit Team ID、Services ID、Key ID 和 private key secrets，secret 不进入仓库。`/v1/weather/hotel-stay-summary` 从 planned 端点推进为可用端点，入参只包含经纬度、入住 / 离店日期、locale、timezone 和 units；端点拒绝 2021-08-01 之前、未来日期、超过 31 晚或非 metric 单位制的请求。WeatherKit provider 新增 Daily Summary 调用，并兼容 WeatherKit 返回的数字日序号日期格式；酒店天气结果按坐标和入住 / 离店日期做 6 小时内存缓存。
- staging 状态：`darkrio-common-api-staging` 已部署最终 Version ID `abd1e2f7-6f95-4664-9e0b-81c64a56babd`；`/v1/manifest` 返回 `hotelWeather.status=available`、provider 为 `weatherkit`。production 继续保持 `WEATHER_PROVIDER=disabled`，没有开启 WeatherKit。
- 未完成内容：App 端尚未展示酒店历史天气摘要；production 尚未配置 WeatherKit secrets；未做服务端鉴权、限流、配额提示、多 provider fallback、缓存持久化、forecast 型未来酒店天气或 App 端失败重试 UI。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `npm run check` 于 `tools/worker/common-api`，结果 PASS，包含 `wrangler types`、`tsc --noEmit` 和 22 个 Vitest 合同测试，新增 WeatherKit Daily Summary 数字日序号解析断言。staging smoke：`/v1/manifest` HTTP 200，`/v1/weather/current?lat=35.68&lon=139.76&locale=ja&timezone=Asia/Tokyo` HTTP 200，`/v1/weather/hotel-stay-summary?lat=35.69&lon=139.76&checkIn=2026-07-01&checkOut=2026-07-03&locale=ja&timezone=Asia/Tokyo` HTTP 200，并返回 2 个入住夜晚的高低温、降水和降雪字段。
- 风险与注意事项：WeatherKit Daily Summary 的字段形状与当前天气 API 不同，日期为数字日序号；本轮已补回归，但后续仍需用更多地点 / 日期 smoke。当前 endpoint 只处理历史账单天气，不把当前天气或未来天气展示到历史酒店水单上。
- 回滚方式：将 staging `WEATHER_PROVIDER` 改回 `disabled` 并重新部署，即可让天气端点回到 `weather_provider_not_configured`；代码层可回退 hotel stay route、WeatherKit Daily Summary provider、缓存、manifest 能力位和测试。production 本轮未改动，无 production 回滚动作。
- 结论：本轮完成 `common-api` WeatherKit staging 第一段，真实 WeatherKit 鉴权和酒店入住日期历史天气端点已跑通；可以进入 App 酒店详情展示和 production 策略设计的下一段。
- 下一步建议：下一段在 App 酒店消费详情中读取已知城市坐标和入住日期，展示历史天气摘要；同时补无坐标、provider 失败、网络关闭和缓存命中的 UI 降级。

### ITER-365 App Store Server Notifications 验签与 staging smoke
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Entitlement / Cloud Inbox / App Store Server Notifications
- 类型：能力增强 / 基础设施 / 回归
- 目标：补齐 Apple App Store Server Notifications V2 `signedPayload` 证书链验签，并把第一段 D1 合同部署到 staging 做可验证 smoke。
- 改动范围：更新 `tools/worker/hotel-folio-inbox/src/index.ts`、Worker 单元测试、Worker README、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志；执行 staging D1 远程迁移、staging Worker 部署和 staging 负向 smoke。
- 未改动范围：本轮未修改 App Swift 代码、StoreKit 商品、ASC 线上配置、App Store Connect Server Notifications URL、production Worker secret、production D1 数据、云收件箱现有候选 PDF / APNs 逻辑、R2 对象、common-api Worker、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`hotel-folio-inbox` Worker 在配置 `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` 后，会优先进入证书链验签模式：校验 `signedPayload` protected header 必须为 `ES256`，要求 `x5c` 证书链，解析 DER 证书有效期和签名算法，验证链路签名，锚定到配置的 Apple 根证书，再用 leaf 证书验证 JWS 签名。未配置根证书时，只有显式开启 `ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS=true` 的 dev / staging 才允许 unsigned 合同测试；生产默认拒收。
- staging 状态：staging 远程 D1 已执行 `0002_app_store_notifications.sql`，数据库 `autoledger-hotel-folio-inbox-staging (3723ede1-4ecd-442c-9cac-7f7b91b2ed19)` 已存在 `app_store_notification_events` 和 `app_store_entitlements`。staging Worker 已配置 Apple Root CA - G3 secret，并部署到 Version ID `d66d8f7f-bd57-4264-853a-e62fc73774ba`。
- 未完成内容：production 尚未配置 `APP_STORE_NOTIFICATION_ROOT_CERT_PEM`、尚未执行 production D1 迁移、尚未在 App Store Connect 配置 Server Notifications URL、尚未触发真实 ASC sandbox 通知端到端、尚未实现 Notification History 补偿任务。
- 测试情况：执行 `npm run check` 于 `tools/worker/hotel-folio-inbox`，结果 PASS，包含 `wrangler types`、`tsc --noEmit` 和 25 个 Vitest 合同测试；新增测试覆盖证书链验签成功、错误根证书拒绝、根证书模式下畸形 JWS 返回 `invalid_signed_payload`。staging 负向 smoke：向 `https://staging-folio.getautoledger.app/v1/app-store/notifications` 发送伪造 unsigned payload，返回 `HTTP 400 {"error":"invalid_signed_payload"}`；随后远程 D1 查询确认 `notification_uuid = 'smoke-invalid-header'` 的事件数为 0。
- 风险与注意事项：staging 配置根证书后，伪造 unsigned 通知不再可用于正向 smoke；后续正向端到端必须来自 App Store Connect sandbox 的真实 signedPayload。当前验签实现验证证书链签名、有效期和受信任根锚定；不存储 raw signedPayload 或 raw original transaction id。
- 回滚方式：删除 staging `APP_STORE_NOTIFICATION_ROOT_CERT_PEM` secret 或回退到上一版 Worker 即可恢复 staging unsigned 合同测试；代码层回滚 `verifyAppStoreSignedPayload`、DER 解析 helper、相关测试和 README / 文档记录。production 本轮未改动，无 production 回滚动作。
- 结论：本轮完成 ASSN 第一段的可上线验签能力，并完成 staging D1 迁移、staging 部署和负向验签 smoke；服务端通知链路已具备接 ASC sandbox URL 做真实通知测试的前置条件。
- 下一步建议：下一段在 App Store Connect 配置 sandbox Server Notifications V2 URL，触发真实 sandbox 购买 / 续费 / 过期通知并归档端到端证据；通过后再评估 production D1 迁移、production 根证书 secret 和 Notification History 补偿。

### ITER-364 App Store Server Notifications 服务端合同
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Entitlement / Cloud Inbox / App Store Server Notifications
- 类型：能力增强 / 基础设施 / 回归
- 目标：为 Pro 服务端订阅生命周期建立第一段可验证合同，让 App Store Server Notifications V2 可以幂等落库，并把续费、宽限期、账单重试、过期、退款和撤销映射到服务端 entitlement 与云收件箱 token 生命周期；当前不配置 ASC URL。
- 改动范围：更新 `tools/worker/hotel-folio-inbox/src/index.ts`、`wrangler.jsonc`、新增 `migrations/0002_app_store_notifications.sql`、更新 Worker README、Worker 单元测试、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App Swift 代码、StoreKit 商品、ASC 线上配置、App Store Connect Server Notifications URL、common-api Worker、云收件箱现有候选 PDF / APNs 逻辑、R2 对象、线上 D1 数据、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`hotel-folio-inbox` Worker 新增 `POST /v1/app-store/notifications`。该 endpoint 读取 Apple `signedPayload`，开发 / staging 可在显式 `ALLOW_UNVERIFIED_APP_STORE_NOTIFICATIONS=true` 下解码 V2 payload，用 `notificationUUID` 向 `app_store_notification_events` 做 `INSERT OR IGNORE` 幂等落库；解析 `signedTransactionInfo` / `signedRenewalInfo` 后校验 bundle id、environment 和 Pro product id，并用 raw original transaction id 的 SHA-256 派生 `appstore:<hash>` 服务端 user id。新增 `app_store_entitlements` 保存当前服务端权益状态；active / grace period 会延长或恢复活跃云收件箱 token，billing retry / expired / refunded / revoked 会停用新的云端自动化请求。事件表只保存通知元数据、哈希和处理状态，不保存 raw signedPayload、raw original transaction id、酒店内容、PDF、邮箱正文或账本数据。
- 未完成内容：生产未启用 App Store signedPayload 证书链验签；生产未开启未验签通知解码；未在 App Store Connect 配置 Server Notifications URL；未执行线上 D1 迁移；未实现 Notification History 补偿任务；未做 sandbox 真通知端到端 smoke。
- 测试情况：执行 `npm run check` 于 `tools/worker/hotel-folio-inbox`，结果 PASS，包含 `wrangler types`、`tsc --noEmit` 和 23 个 Vitest 合同测试；新增测试覆盖未配置验签时拒收、开发显式开关解码、通知 scope 不保留 raw original transaction id、environment / product 校验，以及 DID_RENEW、DID_FAIL_TO_RENEW、EXPIRED、REFUND、REVOKE 到 entitlement 状态的映射。
- 风险与注意事项：当前 endpoint 的生产默认状态是安全拒收未验签通知；开发 / staging 的未验签开关只能用于合同测试，不能用于生产。后续实现 Apple 证书链验签前，不应把 ASC Server Notifications URL 指向生产 Worker。
- 回滚方式：回退 `src/index.ts` 中 `/v1/app-store/notifications` 路由、ASSN helper 和 token 更新逻辑；回退 `wrangler.jsonc` 的 dev / staging 测试开关；不执行或回滚 `0002_app_store_notifications.sql` 迁移；删除 README / 版本文档 / CHANGELOG / 测试中的 ASSN 第一段描述。
- 结论：本轮完成 ASSN 服务端生命周期第一段合同和本地回归，具备后续接 Apple signedPayload 证书链验签、D1 线上迁移和 sandbox 通知测试的基础。
- 下一步建议：下一轮优先补生产可用的 Apple signedPayload 证书链验签；通过后再执行 staging D1 迁移、配置 ASC sandbox URL，并用真实 sandbox 订阅通知做端到端 smoke。

### ITER-363 Common API 汇率缓存
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / Exchange Rates
- 类型：能力增强 / 基础设施 / 回归
- 目标：为 `common-api` 汇率端点和 App 端汇率客户端补基础缓存，降低重复请求 Frankfurter 的频率，并让网络失败时可以用最近成功的同币种 / 同日期汇率兜底；手动汇率输入继续暂缓。
- 改动范围：更新 `tools/worker/common-api/src/exchange-rates/` provider / route / type、`src/index.ts`、Worker 合同测试、`CommonAPIExchangeRateService.swift`、`tools/worker/common-api/README.md`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮不新增手动汇率输入 UI，不修改交易 schema、SQLite / CloudKit schema、StoreKit、ASC、截图 / App Preview、WeatherKit secrets、Cloudflare D1 / R2、服务端鉴权、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：Worker 汇率端点会按 provider scope、base、quote 和 date 生成标准化 cache key，优先读取 Cloudflare Cache API；命中返回 `x-common-api-cache: hit`，未命中请求 provider 后用 `ctx.waitUntil` 写入缓存并返回 `miss`，本地测试或无 Cache API 时返回 `bypass`。App 端 `CommonAPIExchangeRateService` 在请求前读取 Application Support `CommonAPI/ExchangeRates` 下的 JSON 缓存，今天汇率缓存 1 小时，历史日期缓存 30 天；网络 / HTTP / 解码失败时，如果同 key 缓存存在，即使已过期也会作为兜底返回。
- 未完成内容：没有展示“使用缓存汇率”的用户可见标签；没有本地缓存清理 UI、手动汇率覆盖、provider 多源 fallback、历史交易批量重算或服务端持久缓存。
- 测试情况：执行 `npm run check`，结果 PASS，包含 `wrangler types`、`tsc --noEmit` 和 19 个 Vitest 合同测试，新增汇率缓存 miss / hit 断言；执行 `swiftc -parse AutoLedger/AutoLedger/Domain/Services/CommonAPIExchangeRateService.swift`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `bash scripts/run_golden_regression.sh`，38 个 case PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS。Golden 仍保留既有 `AppFormatters` `nonisolated(unsafe)` warning，本轮未处理。
- 风险与注意事项：缓存只保存公共汇率字段：源币种、目标币种、请求日期、实际汇率日期、rate、provider、获取时间和过期时间；不保存消费金额、商户、酒店名、OCR 原文、邮箱内容、PDF 或账本数据。过期缓存只在网络失败时使用，正常路径仍优先请求 fresh 数据。
- 回滚方式：回退 Worker 汇率缓存 helper、`x-common-api-cache` header、App 本地缓存读写、Worker 测试和文档；已写入 App Application Support 的缓存文件可安全保留或删除，不影响账本数据。
- 结论：本轮完成，`common-api` 汇率端点和 App 端汇率客户端已有基础缓存和网络失败兜底，手动汇率输入继续留到后续 GOAL。
- 下一步建议：后续再做手动汇率输入 / 覆盖入口，并评估设置页 Debug 信息展示最近汇率缓存状态。

### ITER-362 OCR 导入确认页
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Live OCR / Inbox Capture
- 类型：能力增强 / UI / 回归
- 目标：让首页实时 OCR、拍照识别、相册导入和剪贴板图片识别在解析出单笔账单后先进入确认页，用户复核字段后再保存，同时不影响现有快捷方式记账默认逻辑。
- 改动范围：新增 `ReceiptImportConfirmView`；更新 `LedgerStore.importRecognizedText` 的可选确认参数、确认草稿状态和保存方法；更新 `InboxView` 的 App 内导入入口；补齐主 App 五语确认页文案；更新离线回归、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮不修改 `QuickLedgerIntent`、`VoiceLedgerIntent` 的保存语义，不修改 App 启动剪贴板自动导入、订阅截图识别、iPad 工作台导入、StoreKit、Worker、SQLite / CloudKit schema、ASC、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`LedgerStore.importRecognizedText` 新增默认关闭的 `requiresConfirmation` 参数。只有 `InboxView` 中的实时扫描、拍照识别、相册导入和剪贴板图片导入显式传入 `true`；解析为普通交易后会生成 `ReceiptImportReviewDraft` 并弹出确认页，不会立即写入交易。确认页可编辑商户、金额、币种、来源、分类、时间和备注，并展示 OCR 原文；源币种不同于目标账本币种时复用汇率预估卡片，保存时用可用汇率写入换算后的账本金额并保留原始金额 / 原始币种 / 汇率 metadata。
- 未完成内容：确认页当前覆盖 App 内首页图片 / OCR 导入，不覆盖 App Intents、订阅识别、非账单失败、订阅识别结果或多笔账单拆分；真实设备上的实时取景 + 确认页串联仍需要 TestFlight smoke 补证据。
- 测试情况：执行 `git diff --check`，结果 PASS；执行五语 `plutil -lint`，结果 PASS；执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增“确认前不入账、确认保存后写入”的 LedgerStore 断言，并保留 App Intents smoke；执行 `bash scripts/run_golden_regression.sh`，38 个 case PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'id=FE9F7A44-8567-458E-AFE0-5104C8301CF2' build`，结果 PASS。XcodeBuildMCP `build_run_sim` 超过 300s 工具超时，手动 `simctl install` 也长时间无输出后中断，因此本轮未拿到启动后 UI snapshot。
- 风险与注意事项：新增确认页只通过显式参数启用；默认值为 `false`，因此旧调用如果没有显式接入，不会被强制改成待确认。确认页保存仍复用原 `persistReceipt` 重复检测和调试记录逻辑，重复账单会按已处理返回并清理待确认状态。
- 回滚方式：回退 `ReceiptImportConfirmView.swift`、`LedgerStore.swift` 中的 `ReceiptImportReviewDraft` / `pendingReceiptReview` / `requiresConfirmation` / `saveReceiptReview` 相关改动、`InboxView` 的 sheet 和显式确认参数、五语 `receipt_confirm.*` 文案，以及离线回归新增断言。
- 结论：本轮完成，首页 OCR 导入已从“确认 OCR 文本后可能直接入账”推进为“确认字段后保存”，且快捷方式记账仍保持原路径。
- 下一步建议：真机验证相机权限、实时 OCR 识别、确认页保存、跨币种预估失败重试和重复账单提示；后续再评估订阅识别结果是否也需要独立确认页。

### ITER-361 首页实时 OCR 票据扫描主线
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Live OCR / Inbox Capture
- 类型：能力增强 / UI / 回归
- 目标：完成 `GOAL-2305` 的首页“票据扫描”实时 OCR 主线，让支持 VisionKit 实时扫描的 iPhone 优先进入取景框识别；不支持时继续保留拍照识别照片和相册导入兜底。
- 改动范围：新增 `LiveReceiptScannerView`；更新 `InboxView` 的票据扫描入口、相册 / 拍照 OCR 共用导入 helper 和全屏 scanner presentation；补齐主 App 五语实时扫描文案；更新 `versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮不重构 `LedgerStore.importRecognizedText` 的既有解析后保存 / 确认策略，不新增独立 OCR 字段确认页，不修改 Pro gate、StoreKit、Worker、SQLite / CloudKit schema、ASC、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：首页“票据扫描”现在打开实时 OCR 全屏页；支持环境下使用 VisionKit `DataScannerViewController` 识别多行文字，并对每帧结果做 550ms 稳定 / 去抖后显示预览和识别行数。用户点击确认后，稳定 OCR 文本进入既有导入链路。实时扫描不可用、Mac Catalyst 或系统报告不支持时，页面显示同一套 fallback 操作；拍照按钮继续走 `CameraPicker`，相册按钮继续走 `PhotosPicker`，两者复用同一个 `OCRService.recognizeTextWithConfidence` helper。
- 未完成内容：扫描后的账单字段统一确认页仍未在本轮落地；当前确认按钮确认的是“稳定 OCR 文本”，之后仍沿用现有 OCR 导入策略，高置信结果可能直接生成交易，低置信 / 失败结果进入现有摘要和调试记录。真实设备相机权限 / 拒绝态仍需 TestFlight 或真机 smoke 补截图证据。
- 测试情况：执行 `git diff --check`，结果 PASS；执行五语 `plutil -lint`，结果 PASS；执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `bash scripts/run_golden_regression.sh`，38 个 case PASS；执行 XcodeBuildMCP iOS 26.5 iPhone 17 Simulator `AutoLedger` Debug build，结果 PASS。构建仍保留既有 `AppFormatters` / App Intents / Gemma / CloudKit 等 warning，本轮未处理。
- 风险与注意事项：VisionKit 实时扫描依赖设备、系统、相机权限和 Apple 当前可用状态；模拟器和 Mac Catalyst 会自然进入 fallback。实时文本只保存在当前 scanner 页面状态中，确认后才交给既有导入 / 调试链路；如果后续要严格做到“解析后必须确认字段再入账”，需要单独拆一个确认流 GOAL。
- 回滚方式：回退 `LiveReceiptScannerView.swift`、`InboxView.swift` 中的 `isPresentingReceiptScanner` / `receiptScannerSheet` / `startReceiptScan` / 共用 OCR helper 改动，以及新增 `live_receipt_scan.*` 五语文案；原拍照和相册导入链路可恢复到上一轮状态。
- 结论：本轮完成，`GOAL-2305` 实时 OCR 主入口和 fallback 主线已落地并通过本地回归与 iOS 构建。
- 下一步建议：用真机 TestFlight 验证相机授权、权限拒绝、弱光长票据和屏幕反光场景；后续单独规划 OCR 解析字段确认页，让实时扫描、拍照和相册导入都走同一确认体验。

### ITER-360 确认页汇率预估与失败处理
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Multi-currency Ledger / Confirmation UX
- 类型：能力增强 / UI / 回归
- 目标：在结构化账单确认和酒店消费确认中，保存前展示跨币种换算后的目标账本金额、汇率日期和 provider；汇率查询失败时提供用户可见重试，并保证不阻断保存。
- 改动范围：更新 `CurrencyConversionPreviewCard`、`StructuredLedgerJSONConfirmView`、`HotelStayReviewView`、`HotelStayLedgerPostingService`、五语主 App 本地化、`scripts/OfflineRegression.swift`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未实现手动输入汇率、汇率本地缓存、历史交易批量重算、Common API provider 多源 fallback、实时 OCR 取景框、StoreKit、ASC、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：跨币种确认页会在金额有效时按当前源币种、目标账本币种和账单日期调用 `CommonAPIExchangeRateService`，显示 loading、预计入账金额、`source -> target` 汇率、汇率日期、provider 和失败重试状态。用户修改金额、币种或日期后会自动刷新预估；失败时可以重试，也可以继续保存，保存链路仍会保留原始金额并在后续后台换算。结构化 JSON 确认页在预估成功时直接保存换算后的目标账本金额和汇率 metadata；酒店确认页会把预估汇率写回 `HotelStayLocalizedData`，入账服务在已有汇率时直接生成换算后交易金额，同时保留原始水单金额、原始币种、汇率日期和 provider。
- 未完成内容：仍没有手动汇率输入 / 覆盖入口，也没有本地汇率缓存命中展示或历史失败记录重试队列 UI；provider 不可用时只给出预估失败提示，保存后的后台重试仍沿用既有日志路径。
- 测试情况：执行 `git diff --check`，结果 PASS；执行五语 `plutil -lint`，结果 PASS；执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增酒店汇率入账断言；执行 `bash scripts/run_golden_regression.sh`，38 个 case PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS。构建仍保留既有 `AppFormatters` / App Intents `nonisolated(unsafe)` warning、`ProEntitlementManager` actor isolation warning 和 Watch deprecation warning。
- 风险与注意事项：确认页会在用户编辑金额时触发 250ms 去抖后的汇率请求；如果 provider 慢或不可用，UI 会显示失败但不会阻断保存。酒店服务端已有 `localizedData.exchangeRate` 时会直接换算金额，因此后续如果模型或外部来源写入了错误汇率，也会被作为已确认汇率使用；真实样本回归需要继续关注汇率来源可信度。
- 回滚方式：回退 `CurrencyConversionPreviewCard` 的状态化 UI、两张确认页的 `.task(id:)` 汇率请求、酒店确认回填汇率、`HotelStayLedgerPostingService` 使用 exchangeRate 换算金额的逻辑，以及新增本地化和离线回归断言；上一轮 OCR 币种识别和交易币种 metadata 可独立保留。
- 结论：本轮完成，账单 / 酒店确认页已经从“只提示会换算”推进到“保存前展示预计目标金额与汇率来源”，失败时也有可见重试和不阻断保存的兜底。
- 下一步建议：补汇率本地缓存和手动汇率覆盖入口；把实时 OCR 主线接入同一 `ImportedReceipt.currencyCode` 输出；后续再评估 provider fallback 和历史交易批量重算。

### ITER-359 OCR 币种识别与区域语言设置
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Multi-currency Ledger / Confirmation UX
- 类型：能力增强 / UI / 回归
- 目标：让普通 OCR 截图 / 拍照识别输出明确币种；在未识别币种时使用用户可配置的默认消费币种；并在账单确认、酒店确认中按源币种和目标账本币种决定是否展示换算提示。
- 改动范围：新增 `ReceiptCurrencyDetector`、`ImportedReceipt.currencyCode` 和消费默认币种设置；更新 `ReceiptParser`、`SmartReceiptMergePolicy`、`MerchantAliasResolver`、`VoiceLedgerParser`、`LedgerTextInterpreter` 与 `LedgerStore` 的币种传递 / 回退 / 保存链路；更新 `LanguageSettingsView`、`StructuredLedgerJSONConfirmView`、`HotelStayReviewView` 和共享 `CurrencyConversionPreviewCard`；补齐五语本地化、离线 / Golden / 批量回归脚本和离线回归样例。
- 未改动范围：本轮未实现保存前精确目标金额预估、确认页直接展示汇率日期和 provider、汇率失败重试 UI、历史 OCR 数据回填、实时 OCR 取景框、Worker provider、StoreKit、ASC、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：OCR 文本可识别 `CNY` / `RMB` / `CN¥`、`USD` / `US$` / `$`、`JPY`、`KRW`、`SGD`、`EUR`、`GBP` 等常见币种信号，并写入 `ImportedReceipt.currencyCode`。App 设置页从“语言”升级为“区域与语言”，新增“消费默认币种”，默认跟随系统区域币种，用户可固定到常用货币目录中的任一币种。普通 OCR 保存时若识别不到币种，会使用消费默认币种作为源币种；源币种与默认写入账本币种不一致时，继续保留原始金额并触发已有后台汇率换算。结构化 JSON 确认页新增币种下拉；酒店确认页币种改为下拉；两者仅在源币种与目标账本币种不同的时候显示换算提示，用户改回同币种后提示会隐藏。
- 未完成内容：确认页当前只展示原始金额和目标账本币种提示，尚未在保存前调用汇率接口显示精确换算后金额、rate date 和 provider；汇率不可用时仍依赖保存后的后台失败路径，没有用户可见重试或手动汇率入口。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `python3 scripts/check_localization_coverage.py`，结果 PASS；执行五语 `plutil -lint`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，新增币种探测和 OCR 币种写入样例；执行 `bash scripts/run_golden_regression.sh`，38 个 case PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS。构建仍保留既有 `AppFormatters` `nonisolated(unsafe)`、Watch `NavigationLink` / `WKExtension` deprecation 等 warning。
- 风险与注意事项：裸 `$` 默认按 USD、裸 `¥` 默认按 CNY；如后续真实样本发现日元 / 美元地区误判，需要结合系统区域、OCR 语言和商户 / 地点上下文继续提高置信度。本轮新增偏好只影响没有识别到币种的新导入账单，不会改动已保存交易。
- 回滚方式：回退新增币种探测器、`ImportedReceipt.currencyCode`、消费默认币种设置、确认页币种下拉 / 换算提示、`LedgerStore` OCR 保存回退逻辑、本地化和回归脚本；已有交易币种元数据 schema 来自 ITER-358，可独立保留。
- 结论：本轮完成，普通 OCR / 拍照识别已具备基础币种输出和默认消费币种回退，账单 / 酒店确认页已按源币种与目标账本币种差异显示或隐藏换算提示。
- 下一步建议：在确认页保存前请求汇率预估并显示目标金额、汇率日期和 provider；为 provider 失败提供手动确认 / 重试路径；把实时 OCR 主线接入同一币种输出。

### ITER-358 App 多币种入账与订阅币种
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Multi-currency Ledger
- 类型：能力增强 / 数据模型 / UI
- 目标：让订阅录入可选择金额币种，并为识别账单、酒店水单和订阅在币种不同于写入账本币种时保留原始金额、按账单发生日汇率换算入账打基础。
- 改动范围：更新 `Transaction`、`Subscription`、`BackupTransaction`、`LedgerTransactionSyncPayload`、SQLite schema / 读写、CloudKit 映射、`LedgerStore` 入账准备逻辑、酒店水单入账、结构化 JSON 确认、订阅新增 / 编辑 UI、订阅展示 / 通知金额格式、离线 regression stub 与备份恢复回归；新增 `CommonAPIExchangeRateService`。
- 未改动范围：本轮未修改普通 OCR 解析器输出币种、账单确认页汇率明细 UI、汇率本地缓存、手动选择汇率、历史交易批量回填、Worker provider、StoreKit、ASC、截图 / App Preview、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：交易模型新增账本币种、原始金额、原始币种、汇率、汇率日期和 provider；SQLite 自动补列，备份、恢复、CloudKit payload 和 merchant alias / 分类 / 账本移动路径保留这些字段。订阅模型新增 `currencyCode`，订阅新增 / 编辑 sheet 加入币种下拉，列表、提醒和续费候选金额按订阅币种展示。`LedgerStore` 在新增、编辑、移动、酒店水单确认和结构化 JSON 确认时按目标账本默认币种准备交易；如果原始币种与目标账本币种不同，会请求 `common-api` 汇率端点并后台更新入账金额，同时保留原始金额、原始币种、汇率日期和 provider。App Intent 结构化 JSON 自动保存路径也会读取默认写入账本币种，并在保存前尽量完成汇率换算。
- 未完成内容：普通 OCR 截图 / 拍照识别目前仍不产出明确币种，因此多数国内支付截图仍按目标账本币种保存；账单确认页还没有把“原始金额 -> 账本金额”的换算明细显示给用户；汇率失败时当前只跳过后台换算并保留原始元数据，尚未提供用户可见重试入口；离线 regression 环境会禁用后台汇率任务，避免测试 runner 竞态。
- 测试情况：执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS，覆盖前置 smoke、SQLite / CloudKit / Backup / LedgerStore 回归，并新增跨币种备份恢复的原始币种元数据检查。构建和离线回归仍保留既有 `AppFormatters` `nonisolated(unsafe)` warning。
- 风险与注意事项：当前换算是保存后后台更新，网络或 provider 失败不会阻塞用户入账，但也意味着首次保存瞬间可能短暂显示未换算金额；后续确认页需要显示换算状态并允许用户保存前复核。`common-api` 汇率端点不接收金额、商户、酒店名、PDF 或 OCR 原文，只接收币种和日期。
- 回滚方式：回退本轮模型字段、SQLite 补列 / SQL 读写、CloudKit 映射、`CommonAPIExchangeRateService`、`LedgerStore` 入账准备逻辑、订阅 UI / 展示改动和回归脚本；已有 SQLite 新列可保留为空，不影响旧字段读取。
- 结论：本轮完成 App 端多币种入账基础闭环和订阅币种录入，已能保留跨币种原始金额并按目标账本币种后台换算。
- 下一步建议：把普通 OCR / 实时 OCR 识别结果也接入币种输出；在账单确认页展示原始金额、换算金额、汇率日期和 provider；为汇率失败提供手动确认 / 重试路径。

### ITER-357 Common API 汇率端点第一版
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / Exchange Rates
- 类型：能力增强 / 基础设施
- 目标：将 `common-api` 汇率端点从 planned 响应推进到可用只读合同，为后续多币种消费按账本默认币种换算做准备。
- 改动范围：新增 `tools/worker/common-api/src/exchange-rates/` provider、route 和类型模块；更新 `tools/worker/common-api/src/index.ts`、`wrangler.jsonc`、Worker 合同测试、README、`versions/v1.7.0-plan.md`、CHANGELOG 和本日志。
- 未改动范围：本轮未实现 App 端金额换算、原始金额 / 目标金额 / 汇率日期持久化 schema、账单确认页换算 UI、汇率本地缓存、商业 provider fallback、R2、D1、服务端鉴权、天气历史摘要、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`GET /v1/exchange-rates/rate?base=USD&quote=CNY&date=2026-07-01` 现在校验 `base`、`quote` 和可选 `date`，只返回汇率相关字段，不接收消费金额。生产 / staging 默认使用免 secret 的 Frankfurter API；测试环境使用 mock provider，避免测试依赖外网。同币种转换在 Worker 内返回 identity rate 1。manifest 中 `exchangeRates.status` 改为 `available`，声明 endpoint、provider、支持币种和 required / optional query；service resource version bump 到 `2026.07.02.4`。
- 未完成内容：App 尚未调用该端点；汇率换算结果、原始币种、汇率日期和 provider 尚未进入交易模型或待确认 UI；provider 不可用时的 App fallback 文案和手动换算流程仍待后续实现。
- 测试情况：执行 `npm run check`，结果 PASS，包含 `wrangler types`、`tsc --noEmit` 和 18 个 Vitest 合同测试；测试覆盖 manifest `exchangeRates` available、mock 汇率成功响应、同币种 identity rate、缺失 / 不支持币种、无效日期、未来日期和 provider disabled。执行前按 Cloudflare Workers skill 拉取了最新 Workers best practices 文档和 `@cloudflare/workers-types@4.20260702.1` 临时类型包作为实现参照。
- 风险与注意事项：Frankfurter 是公开第三方汇率源，无 secret、适合第一版低成本合同，但 SLA 和历史覆盖仍需后续评估；Worker 端不接收金额，因此不会把消费数据上传给第三方。后续 App 真正换算时必须保存 rate date 和 provider，避免 provider 使用最近可用工作日时被误认为账单当天实时汇率。
- 回滚方式：回退 `tools/worker/common-api/src/exchange-rates/`、`src/index.ts`、`wrangler.jsonc`、Worker 测试、README 和文档变更；线上如已部署，可用 Wrangler 回滚到 manifest `2026.07.02.3` 对应版本。
- 结论：本轮完成，`common-api` 已具备第一版可用汇率查询合同，后续可以进入 App 端换算准备。
- 下一步建议：App 端新增 `CommonAPIExchangeRateService`，只在识别币种与账本默认币种不同时请求 rate，并把原始金额、目标金额、rate date 和 provider 放入待确认上下文，不直接静默覆盖金额。

### ITER-356 App 接入 Common API manifest 缓存
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / App Cache
- 类型：能力增强 / 基础设施
- 目标：让 App 端真正消费 `common-api` manifest，在后台静默更新地点 / 货币目录，并在失败时继续使用内置 fallback。
- 改动范围：新增 `AutoLedger/AutoLedger/Domain/Services/CommonAPICatalogService.swift`；更新 `AutoLedgerApp` 启动任务；更新 `HotelStayLocationCatalog`、`LedgerCurrencyCatalog` 和 `AppLanguagePreference`；更新 `versions/v1.7.0-plan.md`、CHANGELOG 和本日志。
- 未改动范围：本轮未实现汇率 provider、金额换算、汇率持久化 schema、账单确认页换算 UI、酒店历史天气、远程识别规则、R2、D1、服务端鉴权、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：App 启动后后台读取 `https://api.darkrio326.top/v1/manifest`，按 manifest 中的 catalog URL 下载地点 / 货币目录，校验 sha256 后原子写入 Application Support `CommonAPI` 目录；HTTP、网络、解码或 sha256 校验失败时仅记录日志，不阻塞 App。酒店地点目录和多账本币种下拉现在优先读取缓存 catalog；缓存不存在或不可解码时，继续使用内置 fallback。地点和货币展示语言同步改为跟随 App 的语言 override。
- 未完成内容：刷新间隔当前固定为 6 小时，没有 UI 状态展示或调试页可视化；地点 / 货币目录仍只更新公共目录，不会热更新识别规则；汇率端点仍未接 provider。
- 测试情况：执行 `swiftc -parse AutoLedger/AutoLedger/Domain/Services/CommonAPICatalogService.swift AutoLedger/AutoLedger/Shared/Constants/AppLanguagePreference.swift AutoLedger/AutoLedger/Shared/Constants/LedgerCurrencyCatalog.swift AutoLedger/AutoLedger/Features/Hotel/HotelStayLocationCatalog.swift`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS。构建日志确认 `CommonAPICatalogService.swift` 已进入主 App target，且没有新增 Common API 相关 warning；日志仍保留既有 AppIntent Logger、LiteRT deprecation 和 entitlement verifier actor isolation warning。
- 风险与注意事项：catalog 缓存是公共数据，不包含用户账单、酒店名、金额、邮箱或 OCR 原文；如果远端返回损坏内容，sha256 和 JSON decode 会阻止替换缓存。当前 UI 读取缓存为同步小文件读取，目录规模继续保持 curated 小集合；未来如目录变大，应改为内存缓存或异步注入。
- 回滚方式：回退 `CommonAPICatalogService.swift`、`AutoLedgerApp.swift`、`HotelStayLocationCatalog.swift`、`LedgerCurrencyCatalog.swift` 和 `AppLanguagePreference.swift`；缓存文件留在 Application Support 不影响内置 fallback，可在后续清理。
- 结论：本轮 App 端已把 Common API 从远端合同接入到实际目录数据源，Common API 主线不再停留在“Worker 已部署但 App 未消费”的状态。
- 下一步建议：补一个 Debug / 设置页只读状态入口显示 Common API manifest 版本、地点 / 货币缓存版本和最近刷新时间；随后进入汇率 provider 或实时 OCR 主线。

### ITER-355 Common API 货币目录与 App 币种目录复用
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / Multi-ledger Currency
- 类型：能力增强 / 基础设施 / 重构
- 目标：在 `common-api` 中补齐货币目录合同，并把 App 多账本默认币种下拉从页面私有数组抽成共享目录，为后续汇率换算和多币种入账做准备。
- 改动范围：新增 `tools/worker/common-api/src/currencies-catalog.ts`；更新 `tools/worker/common-api/src/index.ts`、Worker 合同测试和 README；新增 `AutoLedger/AutoLedger/Shared/Constants/LedgerCurrencyCatalog.swift`；更新 `LedgerProfileManagementView`、`versions/v1.7.0-plan.md`、CHANGELOG 和本日志。
- 未改动范围：本轮未实现真实汇率 provider、汇率缓存、App 端 manifest 下载、远程货币目录缓存替换、交易原始币种 / 汇率 schema、账单确认页换算 UI、酒店天气、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：Worker 新增 `/v1/currencies/catalog` 和 `/v1/currencies`，返回 20 个常用旅行 / 酒店币种的代码、符号、`zh-Hans` / `zh-Hant` / `en` / `ja` / `ko` 五语名称和小数位；manifest 新增 `currencyCatalog` 能力位，并在 `exchangeRates` planned 能力中声明第一批支持币种。App 侧新增共享 `LedgerCurrencyOption`，多账本新增 / 编辑 sheet 继续使用同样的固定币种下拉，但不再把选项定义在页面内部。
- 未完成内容：线上汇率端点仍按计划返回 `501 exchange_rates_not_implemented`；App 端还未在启动时读取 manifest，也不会自动替换内置货币目录；当前货币名称仍需后续抽样审校。
- 测试情况：执行 `npm run check`，结果 PASS（`wrangler types`、`tsc --noEmit`、14 个 Vitest 用例）；执行 `swiftc -parse AutoLedger/AutoLedger/Shared/Constants/LedgerCurrencyCatalog.swift`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS，只有既有 Logger / LiteRT / actor isolation warning。已部署 `darkrio-common-api-staging` version `34ca4d26-3710-4b07-bfb7-45804f4d603a` 与 production version `6406d5be-db75-47c6-8691-9d63ca55995e`；线上验证 `/v1/manifest` 返回 `resourceVersion = 2026.07.02.3`、`currencyCatalog.currencyCount = 20`、`exchangeRates.supportedCurrencyCodes.length = 20`，`/v1/currencies/catalog` 返回 `CNY.names.ko = 중국 위안`、`JPY.decimalDigits = 0`。
- 风险与注意事项：本轮只冻结公共目录和 UI 下拉数据，不做金额换算，因此不会改变现有账本金额口径；后续接汇率前需要明确原始金额 / 目标金额 / 汇率日期 / provider 的本地保存位置，避免只覆盖最终金额。
- 回滚方式：回退 `currencies-catalog.ts`、`index.ts`、Worker 测试、`LedgerCurrencyCatalog.swift` 和 `LedgerProfileManagementView.swift`；如线上 Worker 需要回退，可用 Wrangler 回滚 staging / production 到上一 version。
- 结论：本轮完成，`common-api` 已具备货币目录能力，App 多账本币种下拉也已改为共享内置 fallback。
- 下一步建议：实现 App 启动后台读取 `common-api` manifest、sha256 校验和地点 / 货币目录缓存替换；随后接入 Frankfurter 或等价 provider 的只取 rate 合同。

### ITER-354 酒店地点目录复用与 Common API catalog 修正
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API / Hotel UI
- 类型：能力增强 / UI / 基础设施
- 目标：让酒店消费国家 / 城市选择先用 App 内置同形 catalog 收口，避免城市 / 国家继续混用中英文，并同步修正线上 `common-api` 地点目录的韩语国家名。
- 改动范围：新增 `AutoLedger/AutoLedger/Features/Hotel/HotelStayLocationCatalog.swift`；从 `HotelStayArchiveView` 移出旧内嵌地点目录；`HotelStayReviewView` 的国家 / 城市字段改为可输入 + 下拉选择，国家先选、城市按国家过滤；更新 `tools/worker/common-api/src/places-catalog.ts` 的 catalog resource version 与 `CN` 韩语名；更新 CHANGELOG 与本日志。
- 未改动范围：本轮未实现 App 启动读取 `/v1/manifest`、sha256 校验、后台静默更新、地点目录缓存替换、汇率换算、WeatherKit 新凭据、酒店历史天气展示、SQLite / CloudKit schema、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：酒店消费正式详情编辑和待复核草稿页现在复用同一套内置地点目录；地点目录内置 `zh-Hans`、`zh-Hant`、`en`、`ja`、`ko` 五语城市名，与线上 `common-api` catalog 形状对齐；复核页初始化会把已有 Tokyo / Japan 等解析值本地化到当前语言，并在选择国家时清理不属于该国家的城市。Common API `placeCatalogResourceVersion` bump 到 `2026.07.02.2`，中国国家名韩语展示修正为 `중국`，staging 与 production 已重新部署。
- 未完成内容：App 端仍未从 `https://api.darkrio326.top/v1/manifest` 静默更新地点目录；当前目录仍是 curated 大城市 / 旅游城市集，不是全量世界城市库；韩语地点名仍需后续母语抽样审校。
- 测试情况：执行 `swiftc -parse AutoLedger/AutoLedger/Features/Hotel/HotelStayLocationCatalog.swift`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS；执行 `npm run check`，结果 PASS（`wrangler types`、`tsc --noEmit`、12 个 Vitest 用例）。已部署 `darkrio-common-api-staging` version `db1a994b-3908-4de5-ad1e-6953a1d459ae` 与 production version `a5319a9c-5e77-4b1a-a4a4-140ec0bcb12e`；线上验证 `/v1/manifest` 和 `/v1/locations/catalog` 返回 `resourceVersion = 2026.07.02.2`，`CN.names.ko = 중국`。
- 风险与注意事项：新增 Swift 文件依赖 Xcode 文件夹同步 target 自动收录，当前 iOS workspace build 已证明主 App target 能编入该文件；后续如拆分到独立 package，需要显式处理 target membership。地点目录与线上 catalog 目前由代码生成 / 人工同步维持，下一步应接入 manifest 下载和 sha256 校验，减少双写风险。
- 回滚方式：回退 `HotelStayLocationCatalog.swift`、`HotelStayArchiveView.swift`、`HotelStayReviewView.swift` 和 `places-catalog.ts`；如线上 catalog 需要回退，可用 Wrangler 回滚 production / staging 到上一 Worker deployment。
- 结论：本轮完成，酒店国家 / 城市下拉已在 App 内置 fallback 层五语收口，并且线上 Common API catalog 已同步小版本修正。
- 下一步建议：实现 App 启动后台读取 `common-api` manifest、缓存地点目录并按 resource version 静默替换；随后接入汇率 provider 的只取 rate 合同。

### ITER-353 common-api 通用化与天气 API 迁移
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API
- 类型：能力增强 / 基础设施
- 目标：将 `common-api` 从 AutoLedger 专属命名调整为可供多个 darkrio App 复用的通用 Worker，并把旧 `MyWeatherLine/Api` 中可复用的天气 API 代码迁移进来。
- 改动范围：更新 `tools/worker/common-api` 的 wrangler 名称、package 名称、README、manifest service 名、测试期望和生产 / staging 自定义域；新增天气 provider、WeatherKit JWT、OpenWeatherMap fallback、mock provider、坐标缓存、`/v1/weather/current` 与 `/v1/weather/forecast` 路由；更新版本计划、CHANGELOG 和本日志。
- 未改动范围：本轮未修改 App Swift 代码、酒店消费 UI、账本默认币种 UI、截图管线、现有酒店水单收件箱 Worker、SQLite / CloudKit schema、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number；未迁移旧 WeatherKit key，也未读取旧 `.dev.vars`。
- 完成内容：Worker 名改为 `darkrio-common-api`，npm package 改为 `@darkrio/common-api-worker`，manifest service 改为 `darkrio-common-api`；生产域名改为 `https://api.darkrio326.top`，staging 域名改为 `https://staging-api.darkrio326.top`；旧 `MyWeatherLine/Api` 的 current / forecast API、WeatherKit JWT、OpenWeatherMap 当前天气、mock provider 和 5 分钟坐标缓存迁入新 Worker。默认 `WEATHER_PROVIDER=disabled`，没有新 provider secret 时天气端点返回结构化 `503 weather_provider_not_configured`。已部署 `darkrio-common-api-staging` 与 `darkrio-common-api-production`，删除旧 `base-api`、`autoledger-common-api-staging`、`autoledger-common-api-production` Worker，并删除本机旧 `MyWeatherLine` repo 目录。
- 未完成内容：尚未配置新 WeatherKit key；尚未实现 WeatherKit Daily Summary 历史天气；尚未删除 GitHub 远端 `darkrio326/MyWeatherLine` repo，因为当前 `gh` token 缺少 `delete_repo` scope；尚未实现汇率 provider、R2 static assets、服务端鉴权、Cloudflare 托管限流或 App 端调用。
- 测试情况：执行 `npm install` 完成并显示 0 vulnerabilities；执行 `npm run check` 通过，包含 `wrangler types`、`tsc --noEmit` 和 12 个 Vitest 合同测试，覆盖通用 manifest、HEAD 探测、五语地点目录、天气 provider disabled、坐标校验和 mock current / forecast 合同。线上验证 `https://api.darkrio326.top/health`、`/v1/manifest`、`HEAD /v1/locations/catalog` 和 staging `/health` 均正常；`/v1/weather/current` 在 provider disabled 状态下按预期返回 503。
- 风险与注意事项：旧 WeatherKit key 已 revoke，新 Worker 不会读取旧 secret；正式启用天气前需要重新申请 WeatherKit key，并通过 `wrangler secret put` 配置 `WEATHERKIT_TEAM_ID`、`WEATHERKIT_SERVICE_ID`、`WEATHERKIT_KEY_ID`、`WEATHERKIT_PRIVATE_KEY`，再把 `WEATHER_PROVIDER` 改为 `weatherkit` 后重新部署。当前天气 API 只接收坐标、locale 和 timezone，不接收酒店名、账单金额或用户数据。
- 回滚方式：回退本轮 `tools/worker/common-api` 改动和文档即可；若已部署，可用 Wrangler 回滚到上一版 `autoledger-common-api-*` deployment 或重新部署上一 commit。
- 结论：`common-api` 已从 AutoLedger 专属 Worker 变成 darkrio 通用 Worker 基础，并保留旧 MyWeatherLine 天气 API 的主要代码资产；后续只需新 WeatherKit 凭据即可继续接真实天气。
- 下一步建议：执行 `gh auth refresh -h github.com -s delete_repo` 后删除 GitHub 远端 `darkrio326/MyWeatherLine` repo；随后申请新 WeatherKit key，并用 `wrangler secret put` 配置到 `darkrio-common-api`。

### ITER-352 common-api Worker 第一段
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Infrastructure / Common API
- 类型：能力增强 / 基础设施
- 目标：切换到 `GOAL-2309` 主线，先建立可复用 `common-api` Cloudflare Worker 的最小可运行合同，为地点目录热更新、汇率和酒店历史天气后续接入打基础。
- 改动范围：新增 `tools/worker/common-api` 工作区、wrangler 配置、TypeScript Worker、五语地点目录、Vitest 合同测试和 README；更新 `versions/v1.7.0-plan.md`、CHANGELOG 和本日志。
- 未改动范围：本轮未修改 App 代码、酒店消费 UI、账本默认币种 UI、截图管线、现有酒店水单收件箱 Worker、Cloudflare 线上资源、WeatherKit、汇率 provider、R2、D1、服务端鉴权、SQLite / CloudKit schema、StoreKit、ASC、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`common-api` 新增 `/health`、`/v1/manifest`、`/v1/locations/catalog`、`/v1/locations/countries`、`/v1/locations/cities`；manifest 返回地点目录 URL、sha256、etag、五语 locale、国家 / 城市数量和隐私边界；地点目录覆盖常用国家 / 地区、较大城市和旅游 / 酒店城市，每条国家 / 城市记录都含 `zh-Hans`、`zh-Hant`、`en`、`ja`、`ko` 五语名称；汇率和酒店天气端点先返回结构化 `501` planned 响应，避免误用未接入 provider 的能力。
- 未完成内容：尚未把地点目录放到 R2 或 static asset；尚未实现 App 启动读取 manifest、sha256 校验、后台静默更新和内置 fallback 替换；尚未接入真实 Frankfurter / WeatherKit provider；尚未增加服务端鉴权、限流、缓存策略和生产部署；酒店编辑页仍未改成远程目录来源。
- 测试情况：执行 `npm install` 完成并显示 0 vulnerabilities；执行 `npm run check` 通过，包含 `wrangler types`、`tsc --noEmit` 和 8 个 Vitest 合同测试，覆盖 manifest、目录 etag、五语名称完整性、locale fallback、国家后城市过滤、planned 汇率 / 天气响应和 CORS / read-only 边界。
- 风险与注意事项：当前目录是 curated 第一版，不是全量世界城市库；五语名称为工程可用草稿，后续上线前仍应抽样审校。本条最初使用 `common.getautoledger.app` / `staging-common.getautoledger.app` 作为路由占位，后续已在 ITER-353 改为 `api.darkrio326.top` / `staging-api.darkrio326.top`。
- 回滚方式：删除 `tools/worker/common-api` 并回退本轮文档即可；本轮没有线上部署、数据迁移或 App 运行时依赖。
- 结论：`GOAL-2309` 第一段已具备独立 Worker 合同、五语地点目录和自动门禁，可以作为 App 端 manifest/cache 接入和后续 WeatherKit / 汇率 provider 的基础。
- 下一步建议：先让 App 端酒店国家 / 城市选择读取内置同形 catalog，并预留从 `/v1/manifest` 静默更新；随后再接入汇率 provider 和 WeatherKit provider。

### ITER-351 韩语 UI 资源第一段
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / App UI
- 类型：能力增强 / 本地化
- 目标：在现有 App 语言 override 和多端本地化结构上加入韩语 UI 资源，让韩语系统或手动选择韩语时不再缺失 key 或 fallback 到中文 / 英文。
- 改动范围：新增主 App、Watch App、Watch Widget、Control Widget、Share Extension 的 `ko.lproj` 资源；更新 `AppLanguagePreference`、Xcode `knownRegions`、四语既有 `Localizable.strings` 的韩语选项、`scripts/check_localization_coverage.py`、`versions/v1.7.0-plan.md`、`versions/v1.7.0-i18n-release-matrix.md`、README、CHANGELOG 和本日志。
- 未改动范围：本轮未新增 ASC 韩语商店元数据、韩语截图 / App Preview、真实韩国票据样本、韩语 StoreKit 商品本地化、common-api、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`knownRegions` 新增 `ko`；App 语言设置新增 `한국어`；5 组资源集新增 `ko.lproj/Localizable.strings`，主 App、Control Widget 和 Share Extension 补齐 `ko.lproj/InfoPlist.strings`；本地化覆盖脚本将 `ko` 纳入必备语言；韩语文案以机器翻译草稿生成，并手工修正高频按钮、商户 / 来源术语、Pro 首屏、酒店消费详情和格式化文案中的明显误译。
- 未完成内容：韩语文案尚未经过母语审校；截图模式韩语成品、ASC 韩语 metadata、订阅本地化、真实样本回归和韩国地区支付 / 票据格式专项优化仍未完成，不能把韩语标成公开 Ready 状态。
- 测试情况：执行全量 `.strings` `plutil -lint` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行自定义占位符 parity 检查通过，确认 `en` 与 `ko` 的 `%@` / `%d` / `%.0f` 等格式参数集合一致；执行 token 残留检索未发现生成脚本保护 token。
- 风险与注意事项：机器翻译草稿能解决 key 覆盖和基础可读，但术语、语气和长句仍需要韩语母语审校；截图导出前应重点复核 Pro、设置、酒店消费、账本编辑、订阅管理和 Watch 文案。
- 回滚方式：删除新增 `ko.lproj` 目录并回退本轮对 `AppLanguagePreference`、Xcode project、coverage 脚本、既有四语文案和版本文档的修改即可；不涉及数据迁移、ASC 远端状态或用户数据回滚。
- 结论：本轮完成韩语 UI 资源第一段，App 已具备 `ko` 资源覆盖门禁和手动语言选项，但完整韩语发布仍需 ASC、截图、母语审校和真实样本后续补齐。
- 下一步建议：补韩语真实票据 / 支付通知 / 酒店 folio golden cases，并开始 ASC 韩语 metadata 与截图导出准备。

### ITER-350 韩语识别包第一段
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / Recognition
- 类型：能力增强 / 测试
- 目标：先把韩语账单识别包落入 `AutoLedgerCore`，让金额、商户、日期、分类和账单相关性链路具备第一版韩语基础能力，并为后续 `ko.lproj` UI 与 ASC 韩语材料准备回归基线。
- 改动范围：更新 `LedgerRecognitionLanguagePack.swift`、`PaymentAmountExtractor.swift`、`MerchantResolver.swift`、`BillRelevanceGate.swift`、`scripts/OfflineRegression.swift`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未新增 `ko.lproj`、主 App / Watch / Widget / Share Extension 韩语 UI 文案、ASC 韩语元数据、截图成品、App Preview 视频、真实韩文样本库、common-api、StoreKit 商品、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`LedgerRecognitionLanguagePackSet.builtIn` 新增 `ko` / `ko-KR` 内置识别包，覆盖韩文账单关键词、金额标签、商户标签、非商户字段、餐饮 / 咖啡 / 便利店 / 交通 / 地铁 / 公交 / 酒店 / 购物 / 订阅等分类关键词、韩元金额格式、韩文日期格式和 `ko-KR + en-US` OCR hint；金额、商户和账单相关性正则补充 `₩`、`원`、`KRW`；离线回归新增韩语金额、商户、分类、日期、账单相关性和完整解释器样例。
- 未完成内容：韩语 UI、韩语 App 语言 override 选项、韩语 ASC 商店语言、韩语截图 / App Preview、真实韩国票据样本和地区支付 / 票据格式专项优化仍未完成，不能对外宣传为完整韩语支持。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，覆盖新增韩语识别断言和既有离线回归；输出中仍有既有 `AppFormatters.swift` `nonisolated(unsafe)` warning，本轮未处理。
- 风险与注意事项：当前只是 Core 识别包第一段，样例仍是合成回归；真实韩国收据、支付通知、酒店 folio 和 OCR 噪声仍需要样本补齐后再升级判断。UI 语言和 ASC 韩语没有同步上线前，`ko` 应保持发布矩阵中的 Build 状态。
- 回滚方式：回退本轮四个 Core 服务文件、`scripts/OfflineRegression.swift`、`versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志即可；不涉及数据迁移、ASC 远端状态或用户数据回滚。
- 结论：本轮完成 `GOAL-2308` 的识别包第一段，韩语金额 / 商户 / 分类 / 日期 / 相关性已有自动回归保护，但完整韩语发布仍需 UI、ASC、截图和真实样本后续补齐。
- 下一步建议：继续推进 `ko.lproj` UI 与 App 语言设置选项，再补真实韩文小票 / 支付通知 / 酒店 folio golden cases 和 ASC 韩语元数据。

### ITER-349 ASC 订阅元数据审计
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Automation / Metadata-as-Code
- 类型：能力增强 / 治理
- 目标：把订阅组、月付和年付 subscription localizations 纳入 ASC metadata audit，避免订阅商品描述、本地化缺失或 stale locale 在提交前才暴露。
- 改动范围：更新 `tools/asc-metadata/asc_metadata.rb` 和 `tools/asc-metadata/README.md`，同步回填 `CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 代码、本地化资源、识别代码、截图成品、App Preview 视频、ASC 线上数据、StoreKit 商品、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`asc_metadata.rb audit` 新增 `Subscription Matrix`；读取 `subscriptionGroups`、`subscriptionGroupLocalizations`、组内 `subscriptions` 和每个商品的 `subscriptionLocalizations`；按 planned / future / stale locale 标记覆盖状态；输出商品周期、审核状态、family sharing、group level、订阅本地化 state、名称字段和描述长度，并标记超过 55 字符限制的描述。
- 未完成内容：本轮没有实现订阅本地化写入 / copy、订阅价格 / 价格点 audit、订阅图片 checksum audit、metadata YAML 源文件或自动提交审核。
- 测试情况：执行 `ruby -c tools/asc-metadata/asc_metadata.rb` 通过；执行真实 ASC 只读 `audit --platform IOS --exclude-shot 04_workspace_cleaning` 通过，确认 Pro 订阅组、月付和年付商品均有 `zh-Hans`、`zh-Hant`、`en-US`、`ja` 四语本地化；英文订阅描述为 `55/55`，简体 / 繁体为 `38/55`，日文为 `29/55`，均未超限；本轮未写入 ASC。
- 风险与注意事项：audit 只检查订阅本地化覆盖和描述长度，不代表 ASC 订阅图片、价格、宽限期、审核状态或 promoted IAP 图片一定可编辑；当前月付 / 年付商品仍处于 ASC `IN_REVIEW` 状态时，图片替换仍可能被 ASC API 拒绝。
- 回滚方式：回退 `tools/asc-metadata/asc_metadata.rb`、`tools/asc-metadata/README.md`、`CHANGELOG.md` 和本日志即可；不涉及 App、ASC 远端状态或用户数据回滚。
- 结论：本轮完成 ASC 订阅元数据只读审计能力，`GOAL-2312` 的提交前 audit 已覆盖版本文案、截图 / App Preview 和订阅本地化三类核心发布材料。
- 下一步建议：继续补 metadata source 文件和 dry-run diff，或进入 `GOAL-2308` 韩语 UI / 识别包第一段。

### ITER-348 ASC metadata 资产矩阵审计
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Release Automation / Metadata-as-Code
- 类型：能力增强 / 治理
- 目标：把 ASC metadata audit 从文字本地化扩展到语言、截图和 App Preview 资产矩阵，提前发现 stale locale、截图缺失、远端截图和本地成品不一致，以及新增语言截图未准备的问题。
- 改动范围：更新 `tools/asc-metadata/asc_metadata.rb` 和 `tools/asc-metadata/README.md`，同步回填 `CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 代码、本地化资源、识别代码、截图成品、App Preview 视频、ASC 线上数据、StoreKit 商品、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：`asc_metadata.rb audit` 新增 planned / future / stale locale 状态输出；默认 planned 为 `zh-Hans`、`zh-Hant`、`en-US`、`ja`，`ko` 为 future；支持通过 `--planned-locale` 和 `--future-locale` 覆盖矩阵；新增 `--screenshot-root` 和 `--exclude-shot`；审计会按平台读取 `appScreenshotSets` / `appScreenshots`、按 locale 统计 App Preview set，并把远端截图 checksum 与本地 `tools/appstore-screenshots/output/store` 成品对齐。
- 未完成内容：本轮没有实现 metadata YAML / JSON 源文件、订阅本地化 audit、App Preview 视频上传、截图自动重传、App Privacy nutrition label 问卷自动化或自动提交审核。
- 测试情况：执行 `ruby -c tools/asc-metadata/asc_metadata.rb` 通过；执行 `ruby -c tools/asc-metadata/asc_screenshot_upload.rb` 通过；执行真实 ASC 只读 `audit --platform IOS --exclude-shot 04_workspace_cleaning` 通过，确认 iOS 版本能标记 `en-GB` stale、`ko` 本地截图为 0，且 en-GB iPhone / iPad / Watch 截图在排除 QA 跳过项后均为 match；本轮未写入 ASC。
- 风险与注意事项：checksum mismatch 表示远端截图和本地当前成品不同，不一定代表线上截图错误；若某张截图经人工 QA 决定不上传，必须在 audit 和 upload 中使用相同 `--exclude-shot`，否则会产生合理但噪声较大的 mismatch。
- 回滚方式：回退 `tools/asc-metadata/asc_metadata.rb`、`tools/asc-metadata/README.md`、`CHANGELOG.md` 和本日志即可；不涉及 App、ASC 远端状态或用户数据回滚。
- 结论：本轮完成 ASC 资产矩阵只读审计能力，`GOAL-2312` 已具备在提交前发现 stale locale 和截图 fallback 风险的基础工具。
- 下一步建议：继续补订阅本地化 audit 与 metadata source 文件，或转入 `GOAL-2308` 韩语 UI / 识别包第一段。

### ITER-347 App i18n 发布专项计划
- 日期：2026-07-02
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Localization / Release Planning
- 类型：文档 / 治理
- 目标：为 App 多语言差异化建立专项发布计划，让每个语言按 ASC 商店可见、App 界面可读、识别包可用、真实样本回归和地区支付 / 票据格式专项优化五项门禁推进。
- 改动范围：新增 `versions/v1.7.0-i18n-release-matrix.md`，更新 `versions/v1.7.0-plan.md`、`README.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 代码、本地化资源、识别代码、ASC 线上配置、截图成品、App Preview 视频、StoreKit 商品、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：新增 i18n 发布矩阵文档，定义 Ready / Build / Audit / Candidate / Later 状态；把简体中文、繁体中文、英文、日文、韩语作为 P0 / v1.7.0 主线逐项列出 ASC、App、识别包、样本和地区专项状态；将西班牙语、巴西葡语、法语、德语、印度支付专项、印尼语、泰语、越南语、马来语和阿拉伯语列为后续候选；在 `v1.7.0-plan.md` 中新增 `GOAL-2302`，明确 ASC 新增语言前必须先有 UI、识别包、样本和截图 / metadata 门禁。
- 未完成内容：本轮没有实现韩语 `ko.lproj`、韩语识别包、ASC metadata-as-code、截图导出、样本 fixture、common-api 或任何真实语言包代码。
- 测试情况：本轮为文档变更，执行 `git diff --check` 作为最小回归；未运行 Xcode 构建、离线回归或截图导出。
- 风险与注意事项：矩阵是准入规则，不代表所有候选语言已经支持；对外宣传时只能使用 Ready / Build 完成后的语言，Candidate / Later 只能保留为路线图。
- 回滚方式：删除 `versions/v1.7.0-i18n-release-matrix.md` 并回退本轮对 `versions/v1.7.0-plan.md`、`README.md`、`CHANGELOG.md` 和本日志的修改即可；无 App、ASC、Worker 或用户数据回滚。
- 结论：本轮完成 App i18n 专项计划落档，可作为 `v1.7.0` 后续韩语和更多语言扩展的发布准入依据。
- 下一步建议：进入 `GOAL-2302` 时先把矩阵接入 ASC audit、截图语言清单和本地化覆盖检查；随后推进 `GOAL-2308` 韩语 UI 与识别包。

### ITER-346 App 语言 override 设置
- 日期：2026-07-02
- 所属版本：v1.6.4
- 所属阶段：Settings Polish / Localization
- 类型：能力增强 / UI
- 目标：在 App 设置中新增语言 override，默认跟随系统，允许用户手动切换 App 界面语言。
- 改动范围：新增 `AppLanguagePreference`、`LanguageSettingsView`，更新 `AutoLedgerApp` 顶层 locale 注入、`SettingsView` 设置入口、`SettingsNavigationTarget`、`ScreenshotModeConfig`、四语 `Localizable.strings`、CHANGELOG 和本日志。
- 未改动范围：本轮未修改账本数据模型、识别逻辑、同步逻辑、StoreKit 商品、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 build number。
- 完成内容：设置页外观分组新增“语言”入口；语言页提供跟随系统、简体中文、繁体中文、English、日本語五个选项；根 App 读取 `appLanguagePreference` 并通过 SwiftUI `locale` environment 注入，使主要 `Text` 本地化文案随设置实时切换；截图模式启动时把语言偏好重置为 system，避免商店截图导出被本机手动 override 污染。
- 未完成内容：代码中仍有少量 `String(localized:)` 动态拼接文本，这些文本第一版不保证全部实时跟随 override；后续如需 100% 覆盖，可逐步迁到统一 localizer 或显式 locale API。韩语选项未加入，因为主 App 当前尚无 `ko.lproj`。
- 测试情况：执行四语 `plutil -lint` 通过；执行 `python3 scripts/check_localization_coverage.py`、`python3 scripts/check_accessibility_smoke.py`、`python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 通过。构建仍保留既有 Swift 6 / MediaPipe deprecation warning，本轮未新增处理。
- 风险与注意事项：语言 override 只影响本机 App 界面，不改变系统 sheet、App Store 订阅弹窗、账本数据、识别结果或同步内容。若用户选择 system，仍跟随设备语言和商店截图管线传入的系统语言。
- 回滚方式：回退本轮新增 / 修改的 Swift、本地化和文档文件即可；如果已有用户写入 `appLanguagePreference`，回滚后该 UserDefaults key 会被忽略，不影响数据。
- 结论：本轮完成并通过本地验证；按用户要求不 push。
- 下一步建议：验证通过后先保留本地改动，待用户确认与其他调整一起提交 / 推送。

### ITER-345 ASC 1.5.0 iOS 订阅 EULA 复审修复
- 日期：2026-07-02
- 所属版本：v1.6.4 / ASC 1.5.0
- 所属阶段：App Review Follow-up
- 类型：Bugfix / 审核材料
- 目标：处理 ASC 1.5.0 iOS / iPadOS 复审反馈中自动续期订阅购买流程缺少可见 EULA 链接的问题。
- 改动范围：更新 `AutoLedgerProView` 的订阅选择区、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 StoreKit 商品 ID / 价格 / 订阅组、购买 / 恢复 / 管理订阅逻辑、Pro entitlement、Worker、CloudKit / SQLite schema、Cloudflare 配置、Xcode Cloud workflow、signing、entitlements、`MARKETING_VERSION` 或 build number。
- 完成内容：`AutoLedger Pro` 页面的隐私政策和 Apple 标准 EULA 链接从商品区后方移动到“选择订阅”购买流程内，位于月付 / 年付商品卡之前；月付 / 年付商品卡从整卡点击改为信息卡 + 独立购买按钮，避免条款链接与购买按钮形成嵌套交互，同时让审核录屏能在点击购买前直接看到标题、周期、价格、取消说明、隐私政策和使用条款。
- 未完成内容：未在本轮通过 ASC API 重新提交或回复 Resolution Center；需要等待新 binary 产出后选择构建并附录屏说明。
- 测试情况：执行四语 `plutil -lint` 通过；执行 `git diff --check` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 与 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 通过。构建仍保留既有 Swift 6 / MediaPipe deprecation 等 warning，本轮未新增处理。
- 风险与注意事项：购买按钮从整卡点击改为底部独立 CTA 后，用户必须点击明确的“选择月度 / 选择年度”按钮才会触发 App Store 订阅确认；这是为了让条款链接保持可点击，也更利于审核确认订阅信息。
- 回滚方式：回退 `SupportAutoLedgerView.swift`、`CHANGELOG.md` 和本条日志即可；不涉及远端订阅商品、用户 entitlement 或账本数据回滚。
- 结论：本轮完成，订阅购买流程内已直接展示可点击隐私政策和 EULA 链接，并通过 iOS / Mac Catalyst 构建验证。
- 下一步建议：验证通过后推送新 commit，等待 Xcode Cloud 生成 1.5.0 新构建；在 iOS / macOS 审核备注中附上 Pro 页录屏并说明 EULA 链接位于 Settings > AutoLedger Pro > Choose a plan。

### ITER-344 ASC 1.5.0 macOS 复审修复
- 日期：2026-07-02
- 所属版本：v1.6.4 / ASC 1.5.0
- 所属阶段：App Review Follow-up
- 类型：Bugfix / 审核材料
- 目标：处理 ASC 1.5.0 macOS 复审反馈中的 entitlement、Mac 相机入口、App 内 EULA 链接和订阅推广图重复问题。
- 改动范围：更新主 App target Mac sandbox build settings、`InboxView`、`IPadBatchImportWorkspaceView`、`AutoLedgerProView`、`SettingsView`、四语 `Localizable.strings`、CHANGELOG、本日志，并新增月付 / 年付 1024 订阅推广图版本资产。
- 未改动范围：本轮未修改 StoreKit 商品 ID / 价格 / 订阅组、购买 / 恢复 / 管理订阅逻辑、Worker、CloudKit / SQLite schema、Cloudflare 配置、Xcode Cloud workflow、`MARKETING_VERSION` 或 build number。
- 完成内容：Mac Catalyst 不再展示或触发相机导入入口，避免审核设备点击 camera / receipt scan 后没有 modal；主 App Mac sandbox 不再申请 `com.apple.security.assets.pictures.read-only` 和 `com.apple.security.files.downloads.read-write`，签名产物只保留 `com.apple.security.files.user-selected.read-write`；Pro 购买页新增四语“订阅条款”卡片，提供隐私政策和 Apple 标准 EULA 链接；设置页隐私链接同步到 `https://getautoledger.app/privacy`；新增 `versions/assets/asc-subscription/autoledger-pro-monthly-1024.png` 与 `autoledger-pro-yearly-1024.png`，用于替换重复的 ASC promoted IAP 图。
- 未完成内容：ASC API 读取确认两个订阅的 `subscriptionImages` checksum 仍是重复的旧图；由于月付 / 年付订阅商品当前为 `IN_REVIEW`，ASC API 拒绝删除或新建 `subscriptionImages`，需要在 ASC 可编辑状态下手动替换，或 Developer Reject 后连同新 binary 一起重新提交。
- 测试情况：执行四语 `plutil -lint` 与 entitlements plist lint 通过；执行 Mac Catalyst build settings 检查，确认 `ENABLE_FILE_ACCESS_DOWNLOADS_FOLDER` / `ENABLE_FILE_ACCESS_PICTURE_FOLDER` 不再出现；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 通过；对签名后的 Debug Mac Catalyst app 执行 `codesign -d --entitlements :-`，确认 Apple 点名的两个 entitlement 已移除；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过。
- 风险与注意事项：Mac Catalyst 不再提供相机导入入口，Mac 用户仍可通过相册 / 文件选择 / 剪贴板 / 酒店 PDF 导入完成识别；iPhone / iPad 相机入口仍保留真实相机可用性判断。订阅推广图远端替换需要 ASC 进入可编辑状态后人工完成，API 在 `IN_REVIEW` 状态下不可改。
- 回滚方式：如需恢复 Mac 相机入口，可回退 `InboxView` / `iPadWorkspaceView` 的 `targetEnvironment(macCatalyst)` gate；如需恢复文件夹 entitlement，可重新添加 `ENABLE_FILE_ACCESS_DOWNLOADS_FOLDER` 与 `ENABLE_FILE_ACCESS_PICTURE_FOLDER` build setting；EULA 链接与版本资产回滚不影响用户数据。
- 结论：App 侧复审问题已修复并通过本地构建；剩余动作是上传新 binary，并在 ASC 可编辑状态下替换月付 / 年付 promoted IAP 图后回复审核。
- 下一步建议：Developer Reject 当前 macOS submission，等待 Xcode Cloud 产出新 build 后选择新构建；在 ASC 订阅商品页面分别上传 `versions/assets/asc-subscription/autoledger-pro-monthly-1024.png` 和 `versions/assets/asc-subscription/autoledger-pro-yearly-1024.png`，再在 Resolution Center 回复修复说明。

### ITER-343 v1.7.0 计划推进执行版
- 日期：2026-07-01
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Planning / Execution Readiness
- 类型：文档 / 治理
- 目标：把 `v1.7.0-plan.md` 从草稿计划推进为可执行版本，明确后续 GOAL 的启动顺序、门禁和回滚要求。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 功能代码、Worker、ASC 线上配置、截图成品、StoreKit 商品、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0-plan.md` 的文档状态从 `Draft` 改为 `执行版 / Execution Ready`；新增执行版总控，固定先做 `GOAL-2300` Free / Pro 与隐私边界冻结，再优先推进 ASC metadata-as-code 和 `common-api` 基础设施，随后进入 App Store Server Notifications、实时 OCR、韩语 UI / 识别包、Pro 自动化能力和 ASC 1.6.0 审核材料；补充每个 GOAL 必须独立回归、独立提交、可回滚，以及 ASC dry-run、Worker secret 不入库、common-api 最小数据字段和 Pro gate 变更审计要求。
- 未完成内容：本轮没有执行任何 `v1.7.0` 功能实现，也没有创建新 Worker、修改 ASC 远端数据、运行截图导出或提交审核。
- 测试情况：执行 `git diff --check` 通过；执行 `rg -n "文档状态：Draft" versions/v1.7.0-plan.md` 确认不再保留 Draft 状态。未运行 Xcode 构建或离线回归，因为本轮新增改动仅为文档；同一提交中的 Pro 价格展示代码此前已通过本地化 lint、覆盖检查、固定价格检索、`git diff --check` 和 `.xcworkspace` iOS generic build。
- 风险与注意事项：执行版只是固定工作顺序和门禁，不代表 `v1.7.0` 功能已经落地；对外文案仍应以当前 ASC 1.5.0 已实现能力为准。
- 回滚方式：回退本轮三个文档文件即可恢复到草稿状态；无 App、Worker、ASC 或用户数据回滚。
- 结论：本轮完成，`v1.7.0 / ASC 1.6.0` 已进入执行版，可按 GOAL 队列拆分开工。
- 下一步建议：下一轮进入 `v1.7.0` 时先执行 `GOAL-2300`，冻结 Free / Pro、隐私和跨端权益边界，再启动 `GOAL-2312` ASC audit 与 `GOAL-2309` common-api 合同。

### ITER-342 Pro 订阅价格展示改用 StoreKit displayPrice
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：ASC 1.5.0 Release Polish
- 类型：Bugfix
- 目标：移除 Pro 订阅页和设置页入口中用户可见的固定美元价格展示，改为使用 App Store / StoreKit 返回的本地化商店价格。
- 改动范围：更新 `ProEntitlementManager`、`SettingsView`、`AutoLedgerProView` 和四语 `Localizable.strings` 的 Pro 价格文案。
- 未改动范围：本轮未修改 StoreKit 商品配置、ASC 订阅价格、购买 / 恢复 / 管理订阅流程、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`ProEntitlementManager` 新增按 `AutoLedgerProProduct` 查询 `Product` 与 `displayPrice` 的 helper；设置页 AutoLedger Pro 高亮卡在进入设置时加载商品，并用 `displayPrice` 格式化月付 / 年付价格行；Pro 详情页 hero 价格行、订阅区副标题和商品说明改为运行时填入 `Product.displayPrice`；四语价格文案从固定 `$2.99` / `$19.99` 改为 `%@` 模板，并补充价格加载态。
- 未完成内容：未新增商店价格缓存、离线 fallback 价格或 ASC price schedule 同步；商品未加载时只显示加载态，不展示旧固定价格。
- 测试情况：执行 `plutil -lint AutoLedger/AutoLedger/*.lproj/Localizable.strings` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `rg` 确认 App target / TV / Vision / Widget / Extension 用户可见资源中不再包含 `$2.99`、`$19.99`、`US$2.99`、`US$19.99`，仅 `AutoLedgerSupport.storekit` 保留本地测试价格；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过。
- 风险与注意事项：设置页初次进入时如果 StoreKit 商品尚未返回，会短暂显示“价格加载中”；这是为了避免继续展示错误固定价格。实际购买按钮仍以 StoreKit 商品卡和系统订阅 sheet 为准。
- 回滚方式：回退本轮 Swift 与四语本地化改动即可恢复旧固定价格展示；不涉及远端价格、订阅商品或用户数据回滚。
- 结论：本轮完成，Pro 订阅价格展示已改为商店本地化价格源。
- 下一步建议：若后续需要在截图模式中完全固定演示价格，可在截图配置中显式注入 mock StoreKit 商品，而不是在生产文案里写死金额。

### ITER-341 ASC metadata-as-code 纳入 v1.7.0
- 日期：2026-07-01
- 所属版本：v1.7.0
- 所属阶段：Release Automation / ASC Metadata
- 类型：文档 / 治理
- 目标：把 ASC 商店信息、推广文本、描述、新增功能、隐私文本、订阅本地化、截图和 App Preview 自动化纳入 `v1.7.0 / ASC 1.6.0` 计划，降低多平台多语言发布维护成本。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`README.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 代码、截图脚本、截图成品、App Preview 视频、App Store Connect 线上配置、App Privacy 问卷、StoreKit 商品、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` 计划新增 ASC 发布材料自动化主线和 `GOAL-2312`，明确后续建立 `tools/asc-metadata/`，用 repo 内 YAML / JSON 管理 `appInfoLocalizations`、`appStoreVersionLocalizations`、订阅 / IAP 本地化、截图 manifest 和 App Preview manifest；第一版提供 `audit`、`dry-run` 和显式 `--apply`，用于发现 stale locale、缺失隐私文本、缺失版本元数据、缺失截图 / 视频和订阅描述重复维护问题。
- 未完成内容：本轮没有实现 App Store Connect API 客户端、JWT 生成、metadata schema、截图上传、App Preview 上传、订阅本地化同步或自动提审；没有尝试绕过当前 ASC 1.5.0 的 Apple TV 隐私政策校验。
- 测试情况：文档变更后执行 `git diff --check` 通过；未运行 Xcode / Worker 构建，因为本轮只改规划与发布说明。
- 风险与注意事项：官方 App Store Connect API 能覆盖 App 信息、版本本地化、截图、App Preview、IAP 和订阅本地化，但 App Privacy nutrition label 问卷本体官方 API 覆盖不完整；第一版不做无人值守自动提审，发布前仍保留人工确认。真实 API key / p8 只能放本机安全位置或 CI secret，不进入 repo。
- 回滚方式：回退本轮四个文档文件即可；无代码、数据、ASC 远端配置或构建产物回滚。
- 结论：本轮完成，ASC metadata-as-code 已纳入 `v1.7.0 / ASC 1.6.0`，后续可从 audit 脚本开始，先解决多语言残留和提交前缺失项可见性。
- 下一步建议：等待当前 ASC 1.5.0 提审问题收口后，优先实现 `audit_metadata.py` 读取真实 ASC locale / privacy / subscription / screenshot 状态，确认是否存在 `en-GB` stale localization。

### ITER-340 App Store Server Notifications 顺延到 v1.7.0
- 日期：2026-07-01
- 所属版本：v1.6.4 / v1.7.0
- 所属阶段：Release Planning / Entitlement Infrastructure
- 类型：文档 / 治理
- 目标：把 App Store Server Notifications 写入 `v1.7.0 / ASC 1.6.0` 计划，并明确当前 `ASC 1.5.0` 提审不配置服务器通知。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`versions/v1.6.4-regression-baseline.md`、`versions/v1.6.4-plan.md`、`README.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：本轮未修改 App 代码、Worker 代码、App Store Connect 配置、StoreKit 商品、Cloudflare secret、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图素材、App Preview 或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` 计划新增 Pro 服务端订阅生命周期章节，明确后续接收并验签 Apple V2 `signedPayload`，用 `notificationUUID` 幂等处理续费、过期、退款、撤销、账单重试和宽限期，并联动服务端 Pro entitlement 与云收件箱 token 状态；`v1.6.4` 回归基线同步记录当前 ASC 1.5.0 不配置 App Store Server Notifications，主动生命周期同步顺延到 `v1.7.0`，当前版本继续依赖端上 StoreKit entitlement、Worker 按需 JWS 核验和 token 过期控制。
- 未完成内容：本轮没有实现通知 endpoint、JWS 证书链验签、Notification History 补偿任务、D1 entitlement 表或 ASC URL 配置。
- 测试情况：文档变更后执行 `git diff --check` 通过；未运行 Xcode / Worker 构建，因为本轮只改规划与发布基线。
- 风险与注意事项：当前 ASC 1.5.0 没有服务器通知时，云端订阅状态不会主动收到续费 / 退款 / 撤销事件；安全边界仍依赖领取 token 时的服务端 JWS 核验和 token `pro_expires_at`，并不会让历史数据被锁。若 App Review 对订阅生命周期材料提出要求，需要补 Review Notes 或截图，不在本轮临时接 ASSN。
- 回滚方式：回退本轮六个文档文件即可；无代码、数据或远端配置回滚。
- 结论：本轮完成，App Store Server Notifications 已作为 `v1.7.0 / ASC 1.6.0` 基础设施规划项，当前 `ASC 1.5.0` 可继续按现有版本提审口径推进。
- 下一步建议：ASC 1.5.0 提审前优先复核订阅组元数据、隐私政策链接、英文审核备注、订阅截图 / 录屏和全平台截图素材；`v1.7.0` 开始时先冻结 entitlement Worker schema 和 notification idempotency 合同。

### ITER-339 外观主题自定义选项 Pro 标识与免费 gate
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App UI Polish / Pro Gate
- 类型：Bugfix / UI
- 目标：让外观与主题下拉菜单里的“自定义”明确展示 Pro 标签，并保证免费版本不能直接选择自定义主题。
- 改动范围：更新 `AppearanceSettingsView.swift` 的主题下拉菜单 label 和 `scripts/check_adaptive_layout_rules.py` 静态门禁；同步更新 CHANGELOG 和本日志。
- 未改动范围：本轮未修改 StoreKit 商品、订阅购买 / 恢复逻辑、主题 preset raw value、用户主题偏好、AppTheme 配色、SQLite / CloudKit schema、Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：主题下拉中 `custom` 选项改为复合菜单项：已选中时保留 checkmark，免费状态下显示锁图标，且“自定义”旁展示 `Pro` badge；点击免费状态下的自定义项只打开 `AutoLedgerProView`，不会写入 `AppThemePreset.custom`。既有 `selectTheme(_:)` 和 `enforceThemeAvailability()` 保留，继续防止免费用户或 Pro 到期后停留在自定义主题。
- 未完成内容：本轮未做运行态截图目检；该改动已通过编译覆盖 SwiftUI `Menu` label 语法，但不同系统版本中 `Menu` 对复合 label 的视觉细节仍建议 TestFlight 手动看一眼。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过，结尾为 `BUILD SUCCEEDED`；执行 `bash scripts/run_offline_regression.sh` 通过。
- 风险与注意事项：免费用户仍能看到“自定义 Pro”项，这是为了明确该能力存在但未解锁；点击后不会改主题，只展示 Pro 页。若未来把更多主题纳入 Pro，需要把同样的锁定逻辑从 `isCustom` 扩展为 capability 判断。
- 回滚方式：回退 `AppearanceSettingsView.swift`、`scripts/check_adaptive_layout_rules.py` 和本轮文档记录即可；无数据或后端回滚。
- 结论：本轮完成，自定义主题下拉项已有 Pro 标识，免费版本不可直接选用自定义主题。
- 下一步建议：用免费状态 TestFlight 打开外观与主题，确认菜单中“自定义 Pro”带锁且点击进入 Pro 页面；用已订阅状态确认仍可选择并编辑自定义颜色。

### ITER-338 Pro 恢复购买后云端收件箱状态刷新修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：Pro Entitlement / Cloud Folio Inbox
- 类型：Bugfix
- 目标：修复用户在 Pro 页面恢复购买后，云端酒店水单收件箱仍停留在“需要验证”或旧 access 状态的问题；同时让一个平台开通 / 恢复 Pro 后，其他平台在回到前台时尽快刷新 StoreKit entitlement。
- 改动范围：更新 `AutoLedgerApp.swift` 的前台激活逻辑，以及 `HotelFolioInboxImportView.swift` 的 Pro 状态监听、购买页关闭刷新和云端收件箱本地 access 展示。
- 未改动范围：本轮未修改 StoreKit 商品 ID、订阅组、购买 / 恢复购买 API、Worker API、服务端 App Store Server API 校验、APNs、SQLite / CloudKit schema、真实用户数据、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：App 回到前台时会调用 `ProEntitlementManager.refreshEntitlements()`，让跨设备 / 跨平台订阅状态在重新激活 App 时刷新；云端水单收件箱页监听 `activeProductIDs`、`activeSubscriptions` 和 Pro sheet 关闭事件，恢复购买后会重新刷新 access 并尝试登记远程推送 token。页面展示上，已开通 Pro 时不再把 `/v1/pro-entitlements/verify` 的预检查失败直接显示成未解锁，收件箱入口按本地 App Store entitlement 显示为可用；领取专属地址时仍会把当前 StoreKit signed transaction JWS 传给 Worker，由 Worker 做最终服务端校验。
- 未完成内容：本轮没有改 Worker 的真实生产配置。如果领取地址时 Worker 返回 `app_store_server_api_unconfigured`、`missing_signed_transaction` 或其它 403，仍需要检查 Cloudflare production secret / App Store Server API 环境 / ASC 订阅状态；客户端不会绕过服务端发 token。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，结尾为 `Offline regression passed.`；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过，结尾为 `BUILD SUCCEEDED`。XcodeBuildMCP 本轮先检查过 session defaults，但当前未配置 workspace / scheme / simulator，且暴露工具里没有设置入口，因此按项目规范回退到 `.xcworkspace` 命令验证。
- 风险与注意事项：本轮将“本地 Pro 是否已生效”和“Worker 是否最终允许领取 token”分开处理，体验上避免恢复购买后 UI 卡在旧提示，安全边界仍在 Worker token claim。若某平台的 StoreKit current entitlement 本身还未同步，用户仍可能需要进入 Pro 页面手动恢复购买；App 回到前台刷新只能拉取当前设备已可见的 App Store entitlement。
- 回滚方式：回退 `AutoLedgerApp.swift` 和 `HotelFolioInboxImportView.swift` 的本轮改动，并移除 CHANGELOG / 本日志条目；无数据迁移或后端回滚。
- 结论：本轮完成，恢复购买后的云端水单收件箱会跟随 Pro entitlement 变化实时刷新，跨平台打开 App 时也会主动刷新本地 Pro 状态。
- 下一步建议：用 TestFlight 在 iPhone 开通 / 恢复 Pro 后，切到 iPad / Mac 前台打开云端水单收件箱验证入口状态；如果领取地址仍返回 403，把错误 reason 带回来，下一步查 Worker production App Store Server API 配置。

### ITER-337 全平台商店截图本地化与酒店样例重导出
- 日期：2026-07-01
- 所属版本：v1.6.4 / ASC 1.5.0
- 所属阶段：Release Screenshot Pipeline
- 类型：Bugfix / 截图 / 测试
- 目标：修复 iPad / Mac 酒店消费商店截图缺少样例数据，以及 tvOS、visionOS、Watch 非中文截图仍出现中文或未完全本地化的问题，并在程序侧确认后重新导出全平台四语截图。
- 改动范围：更新 `LedgerStore` 的 DEBUG 截图样例注入入口、`ScreenshotHostView` 的截图 store 构造和酒店样例数据、`AutoLedgerTV/ContentView.swift`、`AutoLedgerVision/ContentView.swift`、`AutoLedgerWatch Watch App/Screenshots/WatchScreenshotHostView.swift`、CHANGELOG 和本日志；重新生成 `tools/appstore-screenshots/output/` 下 ignored 的 raw / store / preview 产物。
- 未改动范围：本轮未修改生产 StoreKit 商品、订阅权益逻辑、Worker、APNs、SQLite / CloudKit schema、真实用户数据、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`；截图输出目录仍不进入普通 Git 历史。
- 完成内容：截图模式创建 `LedgerStore` 时会在 DEBUG 下安装酒店正式记录、待确认水单和关联酒店交易，iPad / Mac 酒店工作台不再截到空态；酒店截图样例统一为 `Sample Harbor Hotel` / `Sample Bay Hotel` 等脱敏英文数据。tvOS 和 visionOS 截图 host 新增四语 copy、分类显示、日期 / 指标格式和酒店样例交易；Watch 截图 host 补齐日文文案、示例商户与分类名称。重新执行 `bash tools/appstore-screenshots/scripts/export.sh`，生成 iPhone、iPad、Mac、Watch、tvOS、visionOS 的简中 / 繁中 / 英文 / 日文截图，并重建 `preview.html`。
- 未完成内容：模拟器系统状态栏的日期语言仍由当前模拟器系统语言决定；例如 iPad 英文成品中的页面和 App 文案已是英文，但状态栏日期仍可能显示为中文格式。若后续 ASC 明确要求系统状态栏也随语言切换，需要为截图管线新增按 locale 切换 / 重启模拟器系统语言，或在截图模式隐藏 / 替换系统状态栏。
- 测试情况：执行 `git diff --check` 通过；执行 `bash tools/appstore-screenshots/scripts/export.sh` 成功，`output/store` 和 `output/raw` 均为 120 张，平台 / 语言矩阵为 iPhone 8×4、iPad 6×4、Mac 5×4、Watch 4×4、tvOS 4×4、visionOS 3×4；抽看 `ipad/en/05_workspace_hotel.png` 确认酒店样例数据存在，抽看 `tvos/ja/00_tvos_overview.png`、`visionos/ja/00_vision_dashboard.png`、`watch/ja/00_watch_quick_add.png` 确认非中文平台截图本地化生效；执行 `bash scripts/run_offline_regression.sh` 通过。全量导出期间各平台 Debug 构建均成功，仍保留既有 Logger `nonisolated(unsafe)`、Swift 6 actor isolation、CloudKit deprecation 和 Gemma LiteRT deprecation warnings。
- 风险与注意事项：酒店样例注入入口只在 DEBUG 下可用，正式 App 数据流不受影响；tvOS / visionOS 本轮使用截图 host 内部 copy，后续如果正式产品页扩展新字段，需要同步补四语 copy，避免截图模式再次落回中文默认值。截图输出 ignored，提交代码后仍需通过本机产物或独立 artifact 交付 ASC。
- 回滚方式：回退本轮 Swift 和文档改动，再重新运行截图导出即可恢复旧截图行为；无数据迁移、CloudKit 或 StoreKit 回滚。
- 结论：本轮完成，酒店消费截图不再空态，tvOS / visionOS / Watch 非中文截图已按当前四语管线重新导出并通过数量与抽样验证。
- 下一步建议：上传 ASC 前用 `tools/appstore-screenshots/output/preview.html` 做一次人工总览；如果决定把商店截图成品留档到 GitHub，建议打包 `output/store/` 作为 Release artifact，而不是提交整个 ignored 输出目录。

### ITER-336 商户别名删除 tombstone 同步修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App Sync / Release Closeout
- 类型：Bugfix / iCloud 同步
- 目标：修复 iPhone 删除商户别名并强制同步后，Mac 打开 App 默认同步仍显示旧商户别名的问题。
- 改动范围：更新 `LedgerCloudKitSyncAdapter.swift`、`scripts/check_cloudkit_sync_smoke.py`、CHANGELOG 和本日志。
- 未改动范围：本轮未修改商户别名 UI、SQLite schema、CloudKit record type 名称、真实 CloudKit 数据、交易同步、酒店同步、StoreKit、Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 根因：`LedgerConfigurationSyncPayload` 已有 `merchantAliasDeletedKeys` 删除墓碑，Core 合并策略也会用 tombstone 阻止旧别名复活；但 CloudKit adapter 在拉取配置时，如果 CKRecord 顶层 `updatedAt` 与 JSON payload 内的 `updatedAt` 不完全一致，会重建 payload 并用 CKRecord 时间覆盖。该重建路径漏传 `payload.merchantAliasDeletedKeys`，因此远端删除墓碑在 Mac 拉取时被清空，Mac 本地旧 alias 又被当作本地配置参与合并并可能回推远端。
- 完成内容：`mapConfigurationPayload(from:)` 重建 `LedgerConfigurationSyncPayload` 时现在保留 `merchantAliasDeletedKeys: payload.merchantAliasDeletedKeys`；`scripts/check_cloudkit_sync_smoke.py` 新增静态门禁，要求 CloudKit adapter 在配置重建路径保留商户别名删除墓碑。
- 未完成内容：本轮未直接操作用户 iCloud private database；如果旧 Mac 版本已经把删除墓碑丢失后的旧别名重新推回远端，需要在修复版上再次从 iPhone 删除 / 强制同步一次，让 tombstone 重新写入远端配置。
- 测试情况：先执行新增的 `python3 scripts/check_cloudkit_sync_smoke.py`，确认修复前失败并提示缺少 `merchantAliasDeletedKeys: payload.merchantAliasDeletedKeys`；修复后再次执行该脚本通过。随后执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 设置 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator 后执行 Debug `build_sim -quiet` 通过。构建仍保留既有 CloudKit adapter deprecation、Logger `nonisolated(unsafe)`、Gemma LiteRT deprecation 和 ProEntitlementManager actor isolation warning。
- 风险与注意事项：该修复只保证后续拉取不会丢失远端 tombstone；已经被旧版本回推污染的远端配置不会凭空恢复，需要用户在任一保留 tombstone 的设备上再次删除并同步。后续如配置 payload 新增字段，应优先避免在 adapter 中手写全量重建，或继续用静态门禁覆盖关键字段。
- 回滚方式：回退 `LedgerCloudKitSyncAdapter.swift` 和 `scripts/check_cloudkit_sync_smoke.py` 的本轮改动，并移除 CHANGELOG / 本日志条目；无 schema 或数据迁移回滚。
- 结论：本轮完成，商户别名删除墓碑在 CloudKit 配置拉取重建路径中不再丢失，后续 iPhone 删除别名后可通过 iCloud 同步阻止 Mac 旧别名复活。
- 下一步建议：用户侧更新到修复版后，在 iPhone 重新删除目标别名并执行一次强制同步，再打开 Mac 端同步验证；如仍复活，下一步导出两端同步日志和远端配置 payload 时间戳继续查是否有旧客户端回推。

### ITER-335 common-api 五语地点目录边界
- 日期：2026-07-01
- 所属版本：v1.6.4 / v1.7.0
- 所属阶段：Planning / Infrastructure / Localization
- 类型：文档 / Cloudflare 基础设施规划 / 本地化
- 目标：把 `common-api` 第一版多语言边界从泛泛的本地化名称收紧为中简、中繁、英文、日文、韩文五语地点目录，避免后续实现时先做四语或单语 fallback。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语路线图、CHANGELOG 和本日志。
- 未改动范围：本轮未修改 App Swift 代码、Cloudflare Worker 代码、地点资源 JSON、汇率或天气 provider、StoreKit、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` `common-api` 规划新增 `manifest.supportedLocales` 边界，地点目录第一版必须覆盖 `zh-Hans`、`zh-Hant`、`en`、`ja`、`ko`；国家 / 地区和城市记录需包含五语展示名、稳定 id、国家 / 地区代码、经纬度、时区和 tags。未知 locale fallback 顺序固定为 App 当前语言 -> `en` -> `zh-Hans`，不允许向用户显示 raw id 或空名称。验收、自动回归和人工 smoke 增加五语地点名称检查；`v1.6.4` 计划和 README 四语路线图同步标注 `common-api` 地点目录从第一版开始就是五语资源。
- 未完成内容：尚未创建真实 `common-api` Worker、manifest 响应、地点目录 JSON、资源校验脚本或 App 端五语显示实现；这些属于 `v1.7.0` 实施阶段。
- 测试情况：执行 `git diff --check` 通过；执行关键词检索确认 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语、CHANGELOG 和本日志均包含 `zh-Hans` / `zh-Hant` / `en` / `ja` / `ko` 或五语地点目录边界。本轮仅文档变更，未运行构建、离线回归、Worker check 或部署命令。
- 风险与注意事项：五语地点目录会增加首版地点资源整理量；实施时应先做小而可靠的国家 / 大城市 / 旅游酒店城市集合，并用资源校验脚本阻止缺失名称进入发布。地点目录热更新只能更新公共地点元数据，不能远程替换账单识别语言包、Pro gate 或 StoreKit 权益判断。
- 回滚方式：回退上述文档文件即可移除五语地点目录边界；无代码、资源或 schema 回滚。
- 结论：本轮完成，`common-api` 第一版地点目录已固定为中简、中繁、英文、日文、韩文五语资源合同。
- 下一步建议：进入 `v1.7.0` 实施时，先定义地点目录 JSON schema 和校验脚本，再补首批国家 / 城市样例数据与 Worker manifest。

### ITER-334 common-api 汇率规划与账本币种下拉
- 日期：2026-07-01
- 所属版本：v1.6.4 / v1.7.0
- 所属阶段：App UI Polish / Planning / Infrastructure
- 类型：UI / 文档 / Cloudflare 基础设施规划
- 目标：把汇率 API 纳入 `v1.7.0` `common-api` 规划，并先把多账本管理中的默认币种编辑从自由文本改为货币下拉，为后续不同币种消费按当前账本默认币种换算入账做准备。
- 改动范围：更新 `LedgerProfileManagementView`、四语 `Localizable.strings`、`scripts/check_adaptive_layout_rules.py`、`versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语路线图、CHANGELOG 和本日志。
- 未改动范围：本轮未实现真实汇率请求、金额换算、交易 schema 扩展、原始币种 / 汇率落库、Cloudflare Worker 代码、真实 Cloudflare 资源、StoreKit、SQLite / CloudKit schema migration、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` `common-api` 规划从地点目录 / 酒店历史天气扩展到汇率服务，计划新增按 `base / quote / date` 查询汇率的 rate endpoint，响应包含 provider、rate date、是否使用最近可用工作日、缓存时间和 attribution；AutoLedger 第一版优先只请求汇率并在 App 本地换算金额，避免上传具体消费金额。Provider 方向优先评估 Frankfurter，因其无 API key、开源 / 可自托管，并支持当前和历史汇率；Open Exchange Rates、ExchangeRate-API 等商业源保留为 fallback / SLA 升级。App UI 侧将多账本新增 / 编辑从 alert 文本输入改为 sheet 表单，默认币种使用固定货币下拉，覆盖 CNY、USD、EUR、JPY、GBP、HKD、MOP、TWD、SGD、KRW、THB、MYR、IDR、PHP、VND、AUD、CAD、CHF、NZD、AED；新增账本和旧账本未设置币种时编辑默认选择 `CNY`，列表也以 `CNY` 作为未设置时的显示 fallback。
- 未完成内容：尚未实现 `common-api` 汇率 Worker、provider adapter、App 端汇率客户端、待确认页换算展示、原始金额 / 原始币种 / 汇率日期 / provider 持久化或正式入账换算；这些属于 `v1.7.0` 实施阶段。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过，并确认 `LedgerProfileManagementView` 已由门禁要求 `.sheet(item: $editorMode)`、`Picker("ledger_profiles.currency.label"` 和 `LedgerCurrencyOption.common`；执行旧入口检索确认 `showAddAlert`、`newLedgerCurrency`、`renameLedgerCurrency`、账本币种 `TextField` 和新增 / 编辑 alert 均已不存在；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 使用 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator 执行 `build_sim -quiet` 通过，构建仅保留既有 Logger `nonisolated(unsafe)`、FeedbackService `@preconcurrency`、Gemma LiteRT deprecation 和 ProEntitlementManager actor isolation warning。
- 风险与注意事项：当前只改变账本编辑 UI 和规划，不改变现有交易金额语义；现有交易仍按原金额展示，不自动换算。后续换算实现时必须保留原始金额 / 原始币种 / 汇率日期 / provider，并在 provider 失败时停止自动换算而不是静默使用错误汇率。汇率只用于个人账本统计准备，不应作为投资、结算、报税或交易依据。
- 回滚方式：回退上述 Swift、四语本地化、脚本和文档文件即可；无数据迁移或 schema 回滚。
- 结论：本轮完成，汇率 API 已进入 `v1.7.0 common-api` 规划，多账本默认币种编辑已改为货币下拉，并通过本地门禁、离线回归和 iOS 模拟器构建。
- 下一步建议：验证通过后，把 `common-api` Worker 第一阶段拆成地点目录、汇率、历史天气三个 provider adapter，并优先确定汇率响应合同和 App 端原始币种保留策略。

### ITER-333 v1.7.0 common-api 与酒店历史天气规划
- 日期：2026-07-01
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Planning / Infrastructure
- 类型：文档 / 规划 / Cloudflare 基础设施
- 目标：把常用国家 / 城市目录热更新和酒店入住日期历史天气摘要纳入 `v1.7.0` 设计，并明确它们通过可复用 `common-api` Worker 承载，而不是混在酒店水单专属收件箱 Worker 或 App 内硬编码中。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语路线图、CHANGELOG 和本日志。
- 未改动范围：本轮未修改 App Swift 代码、Cloudflare Worker 代码、`MyWeatherLine/Api` 源码、真实 Cloudflare 资源、WeatherKit secret、StoreKit、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` 从三条主线扩展为四条主线，新增 `common-api` Cloudflare 基础设施。计划第一版提供 `/v1/manifest`、地点目录静态资源或 `/v1/locations/catalog`、以及 `/v1/weather/hotel-stay-summary`；地点目录只维护常用国家 / 地区、大城市、旅游城市和酒店常见城市，不追求全量世界城市集；App 启动后后台检查 manifest，发现版本更新后静默下载、校验 sha256 并替换本地缓存，失败时继续使用内置 fallback。酒店天气明确使用入住 / 离店日期对应的历史天气摘要，不能用当前城市天气或未来入住天气替代历史账单天气。当前调研确认 WeatherKit 可用 Daily Summary 查询 2021-08-01 之后的每日摘要，适合作为优先 provider；更早历史日期或 provider 不可用时只保留 fallback 适配层和“暂无天气摘要”状态，后续再评估 Open-Meteo Archive、OpenWeather One Call / Daily Aggregation 或 Visual Crossing。
- 未完成内容：尚未创建 `common-api` Worker、迁移 `MyWeatherLine/Api`、生成地点目录 JSON、实现 App 端 manifest 客户端、实现酒店历史天气 UI 或部署 Cloudflare 资源；这些属于 `v1.7.0` 实施阶段。
- 测试情况：执行 `git diff --check` 通过；执行关键词检索确认 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语、CHANGELOG 和本日志均包含 `common-api` / manifest / 地点目录 / 历史天气规划。本轮仅文档变更，未运行构建、离线回归、Worker check 或部署命令。
- 风险与注意事项：WeatherKit Daily Summary 的历史覆盖从 2021-08-01 开始，不能覆盖更早酒店账单；因此 App 必须能展示无天气状态，不能把当前天气或未来天气误挂到历史酒店消费上。地点目录热更新只能更新公共元数据，不能远程替换识别规则、语言包、Pro gate 或 StoreKit 权益判断。天气请求只允许发送经纬度、日期、locale 和单位制，不得上传酒店名、金额、PDF、水单原文、邮箱内容或个人备注。
- 回滚方式：回退上述文档文件即可移除 `common-api` / 地点目录 / 酒店历史天气规划；无代码、资源或 schema 回滚。
- 结论：本轮完成，`v1.7.0 / ASC 1.6.0` 已纳入 common-api 基础设施建设和酒店历史天气增强，并保持本地优先、隐私最小化和失败无感边界。
- 下一步建议：实施阶段先从 `MyWeatherLine/Api` 提取 WeatherKit provider / JWT / cache 到 `common-api` Worker，再做 manifest + 地点目录静态资源，最后接 AutoLedger App 端缓存和酒店详情天气展示。

### ITER-332 一句话记账 / 月报统计 / 酒店地点编辑 polish
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App UI Polish / Hotel Stay Editor
- 类型：UI / Bugfix / 数据目录
- 目标：按真机截图反馈去掉一句话记账页多余示例说明，统一月报摘要三块尺寸，并让酒店消费编辑中的国家 / 城市选择按本地化语言和“先国家、后城市”的层级展示。
- 改动范围：更新 `VoiceLedgerConfirmView`、`ReportView`、`HotelStayArchiveView`、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志。
- 未改动范围：未修改一句话记账解析规则、语音识别实现、酒店水单解析流水线、酒店记录模型、账单保存业务、SQLite / CloudKit schema、StoreKit、Worker、APNs、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：一句话记账页去掉输入框下方重复的“例如” footer，初始状态只保留输入框 placeholder，识别中 / 失败 / 保存状态仍正常显示；月报主卡中的账单数、TOP1、商户数三块改为等宽 `HStack`，统一最小高度，避免中间 TOP1 块比左右小且文本过早截断；酒店消费编辑页把国家字段移动到城市字段之前，国家选项使用系统 `Locale` 的本地化区域名，城市选项按当前语言展示，并在选择国家后筛选该国家下的常用酒店城市。旧记录中已保存的英文 / 中文国家城市会在打开编辑表单时尽量归一化为当前语言展示。
- 未完成内容：当前 App 仍使用内置常用旅行 / 酒店城市目录，没有在运行时接入完整全球城市数据库或网络 API；完整国家 / 省州 / 城市数据源适合后续作为生成脚本或离线资源包接入。
- 测试情况：执行 `git diff --check` 通过；通过 XcodeBuildMCP 设置 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator 后执行 `build_sim -quiet` 通过；首次执行 `bash scripts/run_offline_regression.sh` 因月报自适应布局静态门禁仍要求旧 `LazyVGrid` 失败，更新门禁为新的等宽摘要块规则后重新执行 `bash scripts/run_offline_regression.sh` 通过；再次执行 `build_sim -quiet` 通过，构建仅保留既有 Swift 6 actor isolation / MediaPipe deprecation / formatter warning。
- 风险与注意事项：内置城市目录已经比原来扩展，但仍不是全球完整数据；如果后续要支持大范围酒店城市搜索，建议优先走离线可打包的数据源并在构建期生成精简 JSON / SQLite，避免酒店编辑页依赖网络和第三方 API 可用性。若选择 ODbL 数据源，需要处理 attribution 和衍生数据 share-alike 义务。
- 回滚方式：回退上述三个 Swift 文件、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮完成，A / B / C 三个界面细节已落实，并通过离线回归和 iOS 模拟器构建。
- 下一步建议：真机 TestFlight 回归时重点打开一句话记账、月报页和酒店消费编辑页，确认中文 / 英文 / 日文环境下国家城市展示一致；若后续要扩充地点库，先定数据源许可证和打包策略。

### ITER-331 v1.7.0 韩语 UI 与识别包规划
- 日期：2026-07-01
- 所属版本：v1.7.0 / ASC 1.6.0
- 所属阶段：Planning / Localization
- 类型：文档 / 规划
- 目标：将韩语从后续候选语言提升为 v1.7.0 明确版本目标，并把范围固定为韩语 App UI 与 `AutoLedgerCore` 韩语账单识别包两层能力。
- 改动范围：更新 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语路线图和 Localization & Recognition Packs 说明、CHANGELOG 和本日志。
- 未改动范围：本轮未修改 App Swift 代码、`ko.lproj` 本地化资源、`AutoLedgerCore` 识别代码、golden case 文件、截图配置、ASC 上传材料、StoreKit、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` 计划从两条主线扩展为三条主线：首页实时 OCR、韩语多语言与 Pro 自动化扩展。新增 `1.2 韩语 App 本地化与韩语识别包`，明确后续实现要新增 `ko.lproj`，覆盖主 App、Watch、Widget、Control Widget、Share Extension、App Intents / Shortcuts、截图模式和 ASC 韩语发布材料；`AutoLedgerCore` 新增 `ko` 识别包，覆盖 `₩` / `원` / `KRW` 金额格式、韩文总额 / 支付金额 / 税费 / 折扣标签、商户 / 订单线索、基础分类关键词、`ko-KR + en-US` OCR hint 和韩语 golden cases。GOAL 队列新增 `GOAL-2308`，并把韩语 UI 与识别包明确为免费基础能力，不进入 Pro gate。
- 未完成内容：尚未实现 `ko.lproj`、韩语识别语言包、韩语 golden cases、韩语 ASC 文案或韩语截图输出；这些属于 v1.7.0 实施阶段。
- 测试情况：执行 `git diff --check` 通过；执行关键词检索确认 `versions/v1.7.0-plan.md`、`versions/v1.6.4-plan.md`、README 四语和 CHANGELOG 均可检索到韩语 / Korean / `ko.lproj` / `ko` 识别包相关规划，且旧的“承接两条主线”已替换为“承接三条主线”。本轮仅文档变更，未运行构建、离线回归或 golden 回归。
- 风险与注意事项：当前只是规划收口，不代表 App 已支持韩语；发布或对外文案中不能提前把 `ko` 写成当前已支持语言。后续实现时需要同时补 UI key 覆盖、Core 识别 pack、OCR hint、golden cases、截图 / ASC 元数据和人工母语审校。
- 回滚方式：回退上述文档文件即可恢复到 `v1.7.0` 仅包含实时 OCR 与 Pro 自动化扩展的规划；无代码、数据或 schema 回滚。
- 结论：本轮完成，`v1.7.0 / ASC 1.6.0` 已明确纳入韩语 App UI 和韩语识别包，并保持免费基础能力边界。
- 下一步建议：实施阶段先审计现有 `ja.lproj` 和识别语言包结构，复用同一覆盖门禁新增 `ko.lproj` 与 `ko` recognition pack，再补韩语 golden cases 和 ASC 韩语材料。

### ITER-330 ASC 1.5.0 全平台四语商店截图补齐
- 日期：2026-07-01
- 所属版本：v1.6.4 / ASC 1.5.0
- 所属阶段：Release Materials / App Store Screenshots
- 类型：营销素材 / 渲染 / 测试
- 目标：补齐所有平台、所有已配置语言的 App Store 商店截图成品，让 ASC 1.5.0 可以进入全平台全语言截图上传阶段。
- 改动范围：重新导出并重渲染 `tools/appstore-screenshots/output/raw/` 与 `tools/appstore-screenshots/output/store/` 下的 iPhone、iPad、Mac、Apple Watch、tvOS、visionOS 四语截图；更新 `tools/appstore-screenshots/output/preview.html`；同步更新 CHANGELOG 和本日志。
- 未改动范围：未修改 App Swift 代码、截图配置 JSON、截图导出脚本、App Preview 视频、StoreKit 商品、Worker、APNs、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`；截图输出目录仍为 ignored，不进入普通 Git 历史。
- 完成内容：根据当前 `screenshots.json` 的四语配置补齐 store 成品矩阵：iPhone 8 张 × 4 语，包含新增 `06_hotel_stays` 与 `07_autoledger_pro`；iPad 6 张 × 4 语，包含 `05_workspace_hotel`；Mac 5 张 × 4 语，包含 `04_mac_hotel`；Watch 4 张 × 4 语；tvOS 4 张 × 4 语；visionOS 3 张 × 4 语。最终 `raw/` 与 `store/` 均为 120 张 PNG，`preview.html` 引用 120 张 store 图全部命中。导出过程中清理了 Mac 简中旧 raw `01_mac_ledger.png`，并在 Mac 简中 `04_mac_hotel` 首次脚本捕获因 LaunchServices 激活偶发失败后，使用同一 Catalyst screenshot-mode 场景直接通过 `CGWindowList` 补抓窗口 raw，再重渲染成 `1440x900` store 图。
- 未完成内容：本轮未上传 App Store Connect，也未生成日语 / 繁中 App Preview 视频；商店截图成品仍未打包为 GitHub Release artifact 或版本化 zip。
- 测试情况：执行 `bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hant --locale ja`、`--ipad-only --locale zh-Hans --locale zh-Hant --locale en --locale ja`、`--mac-only --locale en --locale zh-Hant --locale ja`、`--watch-only --locale ja`、`--tvos-only --locale en --locale zh-Hant --locale ja`、`--visionos-only --locale en --locale zh-Hant --locale ja` 均完成；额外补抓 Mac 简中 `04_mac_hotel` raw 后执行 `python3 tools/appstore-screenshots/scripts/render_marketing.py --platform mac zh-Hans` 和 `python3 tools/appstore-screenshots/scripts/build_preview.py`。最终严格校验通过：`raw_png_count=120`、`store_png_count=120`、`preview_refs_checked=120`、`final_screenshot_matrix=OK`；尺寸校验通过：iPhone `1242x2688`、iPad `2732x2048`、Mac `1440x900`、Watch `410x502`、tvOS `3840x2160`、visionOS `3840x2160`。
- 风险与注意事项：Mac Catalyst 窗口捕获仍依赖本机 Accessibility / WindowServer 状态，若后续再全量重跑 Mac 简中可能需要同样等待窗口或直接按窗口层捕获。Watch 黑底图在均值亮度检查中可能被误判为过暗，本轮已目检 `watch/en/03_watch_sync.png`，确认是有效黑底同步页。截图输出目录为 ignored，换机或清理 `output/` 后需要重新导出或从 release artifact 恢复。
- 回滚方式：删除 `tools/appstore-screenshots/output/raw/`、`tools/appstore-screenshots/output/store/` 和 `preview.html` 中本轮生成物即可回到需要重新导出的状态；回退 CHANGELOG 和本日志即可移除记录。无代码、数据、schema 或配置回滚。
- 结论：ASC 1.5.0 全平台四语商店截图成品已补齐并通过本地矩阵 / 尺寸 / 预览引用校验，可以进入 ASC 上传和人工最终目检。
- 下一步建议：上传 ASC 前按平台打开 `tools/appstore-screenshots/output/preview.html` 快速扫一遍标题换行和图像内容；若需要长期留存成品，生成 `asc-1.5.0-store-screenshots.zip` 并作为 GitHub Release artifact 保存。

### ITER-329 ASC 1.5.0 App Preview v002
- 日期：2026-07-01
- 所属版本：v1.6.4 / ASC 1.5.0
- 所属阶段：Release Materials / App Preview
- 类型：文档 / 营销素材 / 渲染
- 目标：结合当前版本实际功能重做 iPhone App Preview 视频，并将原有视频作为 ASC 1.4.0 素材留存；同时评估商店截图成品是否应随视频一起进入 GitHub。
- 改动范围：新增 `tools/appstore-screenshots/app-preview/hyperframes-v002` 和 `hyperframes-v002-en` Hyperframes 源工程、ASC 1.5.0 中文 / 英文 MP4、关键帧和 contact sheet；复制原 v001 MP4 / keyframes 到 `tools/appstore-screenshots/app-preview/archive/asc-1.4.0`；更新 App Preview README、中文 / 英文脚本、shotlist、brief、导出要求、CHANGELOG 和本日志。
- 未改动范围：未修改 App Swift 代码、截图导出脚本、截图 fixture、StoreKit 商品、Worker、APNs、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`hyperframes-v002` / `hyperframes-v002-en` 以 ASC 1.5.0 作为当前宣传视频口径，镜头从 v001 的截图识别 / 语音 / Watch / 月报调整为“待确认账单模型、快速记账、酒店消费、AutoLedger Pro 自动化、月报回看”；视频使用当前 `00_ocr_bill`、`01_voice_entry`、`03_monthly_report`、`06_hotel_stays`、`07_autoledger_pro` 商店图和虚构演示卡片，不包含真实账单或个人数据。最终输出为 `tools/appstore-screenshots/app-preview/hyperframes-v002/renders/app_preview_iphone_zh-Hans_asc1.5.0_v002.mp4` 和 `tools/appstore-screenshots/app-preview/hyperframes-v002-en/renders/app_preview_iphone_en_asc1.5.0_v002.mp4`。商店截图成品评估结果：补齐前 `store/` PNG 为 74 张约 68MB，`raw/` 为 75 张约 142MB；正式补齐后以 ITER-330 的 120 张 store PNG 为准；建议不要把整个 `output/` 目录直接进 Git 历史，优先作为 GitHub Release artifact 或版本化 zip/checksum 留存；如必须入库，仅入 ASC 对应 `store/` 成品，不入 `raw/`。
- 未完成内容：本轮只生成 zh-Hans 和 en iPhone App Preview；未生成日语 / 繁中视频，也未上传 App Store Connect；未把商店截图成品目录加入 Git。
- 测试情况：在 `hyperframes-v002` 和 `hyperframes-v002-en` 分别执行 `npm run check` 通过，包含 lint、validate 和 inspect；lint 仅保留 GSAP timeline overlap / Studio edit blocked 提示类 warning，validate 显示 80 个文本元素通过 WCAG AA，inspect 显示 0 layout issues；中文 / 英文分别执行 `npm run render -- --output ... --fps 30 --quality standard` 渲染成功；`ffprobe` 确认两版 MP4 均为 H.264 + AAC、`886x1920`、30fps、22.021029 秒，中文约 5.0MB，英文约 5.3MB；两版均抽取 6 张关键帧并生成 `renders/keyframes/contact_sheet.png`，目检酒店消费、AutoLedger Pro、月报和 final lockup 正常。
- 风险与注意事项：ASC 上传前仍需人工在 App Store Connect 预览播放器中确认平台接受度、音量和首帧观感；商店截图成品若后续改为入 Git，应避免提交被忽略的整包 `output/`，否则会把 raw 截图和历史多平台生成物长期写进仓库。
- 回滚方式：删除 `hyperframes-v002`、`hyperframes-v002-en` 和 `archive/asc-1.4.0` 新增归档副本，回退 App Preview 文档、CHANGELOG 和本日志即可；原 `hyperframes-v001` 源工程和原 MP4 仍保留。
- 结论：ASC 1.5.0 iPhone 中文 / 英文 App Preview v002 已生成并完成本地规格 / 关键帧验证，原 v001 视频已作为 ASC 1.4.0 素材留存；商店截图成品建议走 Release artifact / zip 留存，不建议整体进普通 Git 历史。
- 下一步建议：在 ASC 上传前用本地播放器完整看一遍两版 MP4；若需要留存商店截图成品，优先生成 `asc-1.5.0-store-screenshots.zip` 并随 GitHub Release 上传。

### ITER-328 Dependabot Wrangler 安全依赖修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：Security / Tooling
- 类型：Bugfix / 治理
- 目标：修复 GitHub Dependabot 默认分支 high alert `GHSA-36p8-mvp6-cv38 / CVE-2026-0933`，移除酒店水单 Worker npm 依赖树中的 vulnerable `wrangler`。
- 改动范围：更新 `tools/worker/hotel-folio-inbox/package.json`、`tools/worker/hotel-folio-inbox/package-lock.json`、CHANGELOG 和本日志。
- 未改动范围：未修改 Worker 业务代码、`wrangler.jsonc`、D1 migration、Cloudflare 资源 / secret、App Swift 代码、StoreKit、APNs、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：通过 GitHub Dependabot API 确认 alert 来自 `tools/worker/hotel-folio-inbox/package-lock.json` 中 `@cloudflare/vitest-pool-workers` 嵌套的 `wrangler 4.35.0`；将 `@cloudflare/vitest-pool-workers` 升级到 `^0.17.0`、`vitest` 升级到 `^4.1.9`、顶层 `wrangler` 升级到 `^4.106.0`，依赖树收敛为单个 patched `wrangler 4.106.0`，同时更新 lockfile。
- 未完成内容：本轮未重新部署 Cloudflare Worker；该修复只影响本地 / CI 开发测试工具链，不改变线上 Worker runtime。
- 测试情况：执行 `npm ls wrangler @cloudflare/vitest-pool-workers vitest` 确认 `@cloudflare/vitest-pool-workers@0.17.0`、`vitest@4.1.9`、`wrangler@4.106.0`；执行 `npm audit --json` 返回 0 vulnerabilities；执行 `npm run check` 通过，包含 `wrangler types`、`tsc --noEmit` 和 19 个 Vitest 用例；执行 `git diff --check` 通过；推送后需要等待 GitHub 重新评估 Dependabot alert 状态。
- 风险与注意事项：`@cloudflare/vitest-pool-workers` 与 `vitest` 跨 major 升级，后续如果 Cloudflare Workers 测试 API 有行为差异，应优先在 Worker 单测层修正；当前现有 19 个 Worker 合同测试已通过。
- 回滚方式：回退 Worker `package.json` / `package-lock.json`、CHANGELOG 和本日志即可；若回滚会重新暴露 Dependabot alert。
- 结论：本地依赖和 Worker 检查已修复，默认分支推送后由 GitHub Dependabot 重新评估 alert 状态。
- 下一步建议：推送到 `origin/main` 后重新查询 Dependabot alert，确认默认分支关闭或进入 fixed 状态。

### ITER-327 v1.7.0 实时 OCR 票据扫描规划
- 日期：2026-07-01
- 所属版本：v1.7.0
- 所属阶段：Planning
- 类型：文档 / 规划
- 目标：将首页“票据扫描”从当前拍照后识别规划为 v1.7.0 的实时 OCR 扫描体验，并明确不支持实时扫描时回退到拍照识别照片 / 相册导入。
- 改动范围：更新 `versions/v1.7.0-plan.md`、README 路线图、CHANGELOG 和本日志。
- 未改动范围：本轮不修改 `InboxView`、`CameraPicker`、`OCRService`、`LedgerTextInterpreter`、StoreKit、Worker、APNs、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.7.0` 计划新增 P0“首页实时 OCR 票据扫描”主线，规定首页“票据扫描”优先进入实时 OCR 取景框，识别文本经短时间稳定后进入既有待确认账单流程；实时扫描不可用、相机权限拒绝、无相机、Mac Catalyst、模拟器能力缺失或系统报告不可用时，回退到当前拍照识别照片 / 相册导入路径。该能力明确属于免费基础体验，不进入 Pro gate；原高级搜索、订阅异常提醒、月结导出包和高级规则自动应用仍作为 v1.7.0 Pro 自动化扩展保留。
- 未完成内容：尚未实现 `LiveReceiptScannerView`、实时 OCR capability 探测、VisionKit 集成或真机扫描 smoke；这些属于 v1.7.0 实施阶段。
- 测试情况：执行 `git diff --check` 通过；执行关键词检索确认 `versions/v1.7.0-plan.md`、README、CHANGELOG 和本日志均已覆盖“实时 OCR”“不支持时回退拍照识别照片 / 相册导入”“不进入 Pro gate”和 `GOAL-2305`。
- 风险与注意事项：实时 OCR 依赖系统实时扫描能力、相机权限、设备性能和光线环境，计划中保留现有拍照 / 相册路径作为稳定 fallback；扫描结果仍需用户确认，避免误识别自动入账。
- 回滚方式：回退上述四个文档文件即可；无代码、数据或 schema 回滚。
- 结论：本轮完成，`v1.7.0` 已明确新增首页实时 OCR 票据扫描主线，并保留原 Pro 自动化扩展范围。
- 下一步建议：实现阶段先做 capability wrapper 和 fallback sheet，再接实时 OCR 文本稳定 / 去抖与待确认账单流。

### ITER-326 语音入口与编辑操作统一
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App UI Polish
- 类型：UI / Bugfix
- 目标：恢复一句话记账页的语音入口，并将账本账单编辑与酒店消费详情编辑的顶部操作体验统一。
- 改动范围：更新 `VoiceLedgerConfirmView`、`TransactionEditorView`、`HotelStayArchiveView`、CHANGELOG 和本日志。
- 未改动范围：未修改语音解析规则、账单保存业务、酒店消费数据模型、SQLite / CloudKit schema、StoreKit、Worker、APNs、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：一句话记账页新增按住说话入口，复用既有 `VoiceSpeechRecognizer`，语音识别结果回填到一句话文本，并继续走原来的解析、复核和保存流程；账本账单编辑页的保存按钮和省略号菜单收进同一个顶部 primary action 按钮组，样式与酒店消费详情的浅色操作按钮保持一致；酒店消费详情页右上角保留保存和省略号删除菜单，但删除入口直接出现，不再经过“更多操作”二级菜单。
- 未完成内容：本轮未重新导出 App Store 截图，也未在真机上重新授权麦克风 / 语音识别权限；若权限首次弹窗文案需要审核，仍需 TestFlight 真机目检。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；执行旧交互模式检索确认目标文件不再包含 `ToolbarItem(placement: .secondaryAction)`、`Label("common.more_actions"`、`ellipsis.circle` 或中文“更多操作”二级入口；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO -quiet` 通过，构建只输出既有 Swift 6 actor isolation / MediaPipe deprecated / formatter warning。
- 风险与注意事项：语音入口复用系统语音识别权限和原有一句话解析链路，首次使用仍受系统权限、设备语言和网络 / 离线识别能力影响；本轮只把入口恢复到一句话记账页，不把语音识别结果自动入账。
- 回滚方式：回退上述三个 Swift 文件、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮完成，语音入口已回到一句话记账页，两个编辑页顶部操作已统一为同组浅色按钮并移除二级“更多操作”层级。
- 下一步建议：下一版 TestFlight 真机验证时，重点点开一句话记账页首次授权语音 / 麦克风，再检查账单编辑与酒店消费编辑右上角按钮组的视觉一致性。

### ITER-325 设置页版本说明用户化
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App UI Copy / Release Metadata
- 类型：UI / 文案
- 目标：将设置页“当前版本”和“后续计划”两段说明从工程发布口径改为终端用户能理解的产品口吻。
- 改动范围：更新简中 / 繁中 / 英文 / 日文 `settings.version.body` 和 `settings.release_status.body`，同步更新 CHANGELOG 和本日志。
- 未改动范围：未修改设置页结构、Pro gate、StoreKit、订阅商品、Worker、APNs、账本数据、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：当前版本说明改为解释 Pro 第一批自动化会先进入待确认、确认后再入账，并明确日常记账、截图识别、手动酒店 PDF、多账本和历史数据编辑仍可免费使用；后续计划改为说明会继续打磨 Pro 订阅体验和酒店水单流程，再加入搜索、订阅异常提醒、月结导出和自动规则整理。四语文案不再向终端用户展示 Cloudflare、APNs secret、Review Notes、审核截图等内部发布材料词汇。
- 未完成内容：本轮未重新跑模拟器截图；后续如更新 ASC 截图，可顺手目检设置页文本换行。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行关键词检查确认四语设置页版本说明不再包含 `Cloudflare`、`APNs`、`secret`、`Review Notes`、`smoke`、`metadata`、`审核截图` 等内部词；执行 `git diff --check` 通过。
- 风险与注意事项：文案仍保留后续功能方向，但仅作为用户可理解的计划描述，不承诺具体发布时间。
- 回滚方式：回退四语 `Localizable.strings`、CHANGELOG 和本日志即可；无数据迁移。
- 结论：设置页版本说明已改为终端用户口吻。
- 下一步建议：下一次截图导出时检查设置页卡片高度和多语言换行。

### ITER-324 外观主题下拉短名称与排序
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：App UI Theme
- 类型：UI / Bugfix
- 目标：将外观与主题页的主题下拉改成更短、更稳定的展示名称，并让经典主题排在第一位。
- 改动范围：更新 `AppThemePreset.selectableCases`、简中 / 繁中 / 英文 / 日文 `appearance.theme.*` 标题、CHANGELOG 和本日志。
- 未改动范围：未修改 `AppThemePreset` raw value、具体主题 palette、外观模式、自定义主题颜色存储、Pro gate、StoreKit、账本数据、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：主题下拉当前可选顺序固定为 `经典 / 薄荷 / 石墨 / 墨青 / 海湾 / 自定义`；简中标题完全按该短名称展示，繁中 / 英文 / 日文同步改为短标题。`nightFolio` 和 `sunrise` palette 仍保留在代码中，但不出现在当前 `selectableCases` 下拉列表。
- 未完成内容：本轮未重新跑模拟器截图；视觉验证留到下一轮需要进入外观页时一起做。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；执行关键词检查确认 `隐私薄荷 / 石墨工作台 / 墨青账本` 不再作为当前简中主题标题出现。
- 风险与注意事项：已保存为 `fresh / graphite / ledgerInk` 的用户偏好仍会按原 raw value 命中，只是 UI 展示名变短；当前默认主题仍保持既有逻辑，没有强制把已有用户切到经典。
- 回滚方式：回退 `AppTheme.swift`、四语 `Localizable.strings`、CHANGELOG 和本日志即可；无数据迁移。
- 结论：主题下拉展示已收敛为六个短名称，并按经典优先排序。
- 下一步建议：下一次运行模拟器时顺手目检外观页下拉、主题预览卡和首页主题即时刷新。

### ITER-323 截图管线酒店消费与 Pro 路线图修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：Screenshot Pipeline / Pro Subscription UI
- 类型：Bugfix / UI / 工具 / 测试
- 目标：让截图管线覆盖新功能酒店消费模块和独立 AutoLedger Pro 介绍图，并去掉 Pro 路线图预告中总说明层面的 `1.6.0` 展示。
- 改动范围：更新 `AutoLedgerProView`、四语 `Localizable.strings`、`ScreenshotHostView`、`tools/appstore-screenshots/config/screenshots.json`、截图 README、CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、订阅购买 / 恢复 / 管理核心流程、Pro entitlement server verifier、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Pro 路线图预告标题右上角的总 `1.6.0` badge 已移除，四语说明文案改为“计划在后续版本作为 Pro 自动化扩展实现”的语义，不再出现“后续版本 1.6.0 / version 1.6.0 / バージョン 1.6.0”，只保留每个功能块上的 `pro.roadmap.item_badge`；路线图卡片最小高度提高到 170，让四个功能块视觉尺寸统一。截图管线 iPhone `iosShots` 从 6 张扩展到 8 张，新增 `06_hotel_stays` 和 `07_autoledger_pro`；iPad `ipadShots` 新增 `05_workspace_hotel`；Mac `macShots` 新增 `04_mac_hotel`。`ScreenshotHostView` 新增 `workspace_hotel` / `mac_hotel` 到 `.hotelStays` 的映射，Pro 截图 host 固定关闭本机 debug Pro override，避免导出受本机订阅调试状态影响；酒店消费截图 fixture 从 Moxy / Marriott 和真实城市改为 `示例海湾酒店`、`示例城市酒店`、`示例酒店集团`、`SAMPLE-*` 订单号和 `Sample Card`，README 同步 iPhone / iPad / Mac scene 列表。
- 未完成内容：本轮只导出 zh-Hans iPhone 截图验证新增场景，没有重新导出全语言 / 全平台正式素材；iPad / Mac 酒店消费场景已配置并映射，但仍需后续全平台导出时实际生成和目检。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `python3 -m json.tool tools/appstore-screenshots/config/screenshots.json` 通过；执行截图相关 shell 脚本 `bash -n` 通过；执行 `git diff --check` 通过；通过 XcodeBuildMCP 在 iPhone 17 Simulator 运行 `hotel_stays` screenshot scene 和 `pro_subscription` screenshot scene 均成功，并截图目检；执行 `bash tools/appstore-screenshots/scripts/export.sh --ios-only --locale zh-Hans` 通过，生成 8 张 iPhone store 图，新增 `tools/appstore-screenshots/output/store/ios/zh-Hans/06_hotel_stays.png` 和 `07_autoledger_pro.png` 均为 `1242x2688`，目检新图正常。
- 风险与注意事项：截图输出目录在 `.gitignore` 下，不随代码提交；正式补 ASC 素材前还需要重新跑全语言 / 全平台导出。Pro 路线图的功能块版本 badge 仍保留为用户要求的功能版本提示，后续若版本口径变化，需要同步 `pro.roadmap.item_badge`。
- 回滚方式：回退上述 Swift 文件、四语本地化、截图配置 / README、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成截图管线新功能覆盖和 Pro 路线图展示细节修复，zh-Hans iPhone 截图管线已验证新增酒店消费和 Pro 独立图可生成。
- 下一步建议：后续正式截图阶段执行全语言 / 全平台导出，重点目检 iPad / Mac 的酒店消费工作台和四语 Pro 独立图标题长度。

### ITER-322 Mac 工作台导航与多账本主题修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：Mac Catalyst / App UI Theme
- 类型：Bugfix / UI / 测试
- 目标：修复 Mac Catalyst 首次打开设置页标题被遮挡、多账本管理未复用主题色、分析页标题与月份箭头重合，以及 TestFlight Mac 偶发 SwiftUI Navigation 崩溃的风险点。
- 改动范围：更新 `SettingsView`、`IPadWorkspaceView`、`LedgerProfileManagementView`、CHANGELOG 和本日志；读取本机 TestFlight 崩溃日志并纳入判断。
- 未改动范围：未修改账单 SQLite / CloudKit schema、StoreKit 商品和订阅逻辑、Worker、APNs 配置、截图导出脚本、App Group identifier、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`SettingsView` 支持传入内容顶部间距，Mac Catalyst 工作台打开设置页时使用更大的顶部 padding，避免 `AutoLedgerPageTitle` 被窗口顶部 chrome 遮住；工作台详情列移除全局随机 `.id(UUID())` 重建，只在离开设置页时重置设置子导航栈，降低 SwiftUI split detail 导航状态频繁重建导致的 `NavigationColumnState.boundPathChange` 崩溃风险；多账本管理接入 `autoLedgerListChrome()`、`autoLedgerNavigationBarChrome()`、`AppTheme.accent` tint、主题刷新动画和卡片行背景，iOS / Mac 均跟随当前主题色；分析页月份切换按钮从导航栏 toolbar 移入标题卡片，避免 Mac 上导航标题与左右箭头重叠。
- 未完成内容：本轮没有重签 / 安装新的 Mac TestFlight 包，也没有通过 Mac UI 自动化复现崩溃前后的同一路径；Catalyst compile-only 仍打印既有 MediaPipe Catalyst slice warning 和 Swift 6 warning，需要在正式 Mac TestFlight 上再次人工走设置、账本、酒店消费、分析四个 tab。
- 测试情况：本机确认 `~/Library/Logs/DiagnosticReports/Retired/AutoLedger-2026-07-01-085114.ips` 和 `AutoLedger-2026-07-01-085329.ips` 存在，均为 `EXC_BREAKPOINT / SIGTRAP`，faulting thread 为 `com.apple.main-thread`，顶部栈为 `swift_unexpectedError -> SwiftUI.NavigationColumnState.boundPathChange`；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；通过 XcodeBuildMCP 执行 iPhone 17 Simulator `build_sim -quiet` 通过，随后执行 `build_run_sim -quiet` 通过并成功截图 `/var/folders/k4/xvd6k70j3397km1slbw4y6v40000gn/T/screenshot_optimized_efdd33d6-18d6-4c5c-aca8-c3ab57b058c5.jpg`；运行日志未出现 `EXC_`、`SIGTRAP` 或 `NavigationColumnState` 崩溃字样；执行 Mac Catalyst compile-only 命令 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' -configuration Debug build CODE_SIGNING_ALLOWED=NO -quiet` 以 exit code 0 结束。
- 风险与注意事项：TestFlight Mac 崩溃日志来自 release 包，缺少可直接落回 Swift 文件的完整符号，但两份日志的 SwiftUI Navigation 栈一致，和工作台 detail column 强制重建的风险点匹配。XcodeBuildMCP 的 runtime UI snapshot 当前因本机 `/Applications/Xcode-beta.app/Contents/Developer/Library/PrivateFrameworks/SimulatorKit.framework` 缺失而失败，未能自动点进设置里的多账本页面；已用 build/run/screenshot 和日志检索替代。
- 回滚方式：回退上述三个 Swift 文件、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成 Mac 工作台设置标题遮挡、分析标题冲突、多账本主题接入和 SwiftUI Navigation 崩溃风险点修复，iPhone 模拟器 build/run 与 Mac Catalyst compile-only 已通过。
- 下一步建议：下一版 TestFlight Mac 安装后，优先从首次启动进入设置，再连续切换账本、酒店消费、分析、设置并打开多账本管理，确认标题不遮挡、tab 不消失、主题色即时生效且不再产生新的 `AutoLedger-*.ips`。

### ITER-321 Watch 同步与自定义主题预览修复
- 日期：2026-07-01
- 所属版本：v1.6.4
- 所属阶段：Watch Sync / App UI Theme
- 类型：Bugfix / 测试
- 目标：修复 Watch 端数据仍依赖打开手表 App 才刷新，以及 iPhone 自定义主题三段颜色变化后主题预览不实时生效的问题。
- 改动范围：更新 `WatchConnectivityHost`、`WatchSessionManager`、Watch 同步调用点、`AppTheme`、`AppearanceSettingsView`、自适应布局门禁、离线回归时间敏感断言、CHANGELOG 和本日志。
- 未改动范围：未修改账单 SQLite / CloudKit schema、StoreKit 商品和订阅逻辑、Worker、APNs 配置、Watch UI 布局、App Group identifier、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：iPhone 侧新增 `publishLatestLedgerSnapshot()` 作为 Watch 数据发布入口，账单变化、App 回前台、App Intent 入账和 Watch fetch 请求都会生成同一份 `syncTransactions` 快照；快照写入 `snapshotUpdatedAt` / `syncID`，并同时走 application context、前台 `sendMessage`、后台 `transferUserInfo` 和 complication transfer。后台传输会取消未完成的旧 `syncTransactions` 队列并按快照指纹去重，减少旧数据晚到。Watch 侧激活后先应用 `receivedApplicationContext`，并按 `snapshotUpdatedAt` 丢弃比当前内存态更旧的 payload，避免 Watch App / Widget 快照回滚。外观页自定义主题预览改为显式接收表面色、强调色、辅助色，主题下拉色块、当前主题卡和预览卡都通过同一组实时颜色渲染。离线回归中 `LocalEmailFolioImportAllowance` 的同月免费额度断言固定测试日期，避免跨月日期导致误判。
- 未完成内容：本轮未做真机 Apple Watch 后台投递耗时测试；watchOS 后台交付仍受系统调度、蓝牙 / Wi-Fi 状态和 complication 额度影响，TestFlight 真机回归时仍需观察表盘 / Watch App 是否能在不手动打开 App 的情况下收到下一次账单快照。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_widget_smoke.py` 通过；执行 `git diff --check` 通过；通过 XcodeBuildMCP 设置 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator 后执行 `build_sim -quiet` 通过，status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-07-01T00-56-21-932Z_pid3926_8a508bcd.log`；首次执行 `bash scripts/run_offline_regression.sh` 失败于 2026-07-01 跨月触发的 `LocalEmailFolioImportAllowance blocks second free import in same month` 时间敏感断言，固定测试日期后重新执行 `bash scripts/run_offline_regression.sh` 通过。
- 风险与注意事项：后台 WatchConnectivity 传输只能保证排队和最终交付机会，无法强制 watchOS 立即唤醒；实际刷新速度需以真机 TestFlight 和当前 Watch / iPhone 连接状态为准。自定义主题预览现在直接跟随 AppStorage 三段颜色，未来新增自定义色维度时需要同步扩展 `resolvedPreviewStyle` 和门禁脚本。
- 回滚方式：回退上述 Swift 文件、`scripts/OfflineRegression.swift`、自适应布局门禁、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成 Watch 最新账单快照发布链路加固、自定义主题预览实时刷新和 7 月 1 日离线回归时间抖动修复，静态门禁、离线回归和模拟器 Debug build 均通过。
- 下一步建议：TestFlight 真机安装后，先在 iPhone 新增一笔账单并保持 Watch App 未手动打开，观察表盘 complication / Watch 首页快照是否在系统后台调度后更新；随后在外观页选择自定义主题，连续改三段颜色确认下拉色块和预览卡即时变化。

### ITER-320 Pro 展示与 iPhone 截图管线调整
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Pro Subscription / Screenshot Pipeline
- 类型：Bugfix / UI / 工具 / 测试
- 目标：按当前工程现状收口 Pro 订阅页展示、多账本币种编辑，并让 iPhone 全语言截图管线固定经典主题。
- 改动范围：更新 `AutoLedgerProView`、`LedgerProfileManagementView`、`LedgerStore`、`ScreenshotModeConfig`、`ScreenshotHostView`、`AutoLedgerApp`、四语 `Localizable.strings`、`tools/appstore-screenshots` 配置 / 脚本 / README、CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、订阅购买 / 恢复 / 管理核心流程、Pro entitlement server verifier、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Pro 路线图文案移除开发用 `v1.6.4` / `v1.7.0` 和 `ASC` 字样，用户侧只显示公开版本 `1.6.0`；Pro 深色模式下推荐年付卡和预览面板改用深色友好的填充与文字颜色，已订阅时商品卡不再被 SwiftUI disabled opacity 整体压暗；多账本编辑入口从仅重命名升级为编辑名称和默认币种，并通过 `saveLedgerProfile` 持久化币种；iPhone 截图配置新增 `themePreset=classic`、`colorScheme=light`，`export_ios.sh` 启动截图模式时传入 `--screenshot-theme` 与 `--screenshot-color-scheme`，App 仅在 `--screenshot-mode` 下写入对应偏好。截图 fixture 的月报样例日期改为当前月份，避免商店图出现空账本；自绘 iPhone 截图场景补齐日文 copy；`render_marketing.py` 新增 `--platform` 过滤，各平台导出脚本只渲染自己的平台。
- 未完成内容：设置页版本说明里的后续计划仍保留 `v1.7.0` 研发口径，本轮仅按要求收口 Pro 订阅页文案；本轮未重新导出 iPad / Mac / Apple TV / visionOS 全语言截图。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；执行 `python3 -m json.tool tools/appstore-screenshots/config/screenshots.json` 与各截图 shell 脚本 `bash -n` 通过；通过 XcodeBuildMCP 执行 iPhone 17 Simulator `build_sim -quiet` 通过，最新 status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-06-30T13-24-00-491Z_pid28622_8085b568.log`；执行 `bash tools/appstore-screenshots/scripts/export.sh --ios-only` 通过，脚本打印 `theme: classic / light`，生成 zh-Hans / zh-Hant / en / ja 共 24 张 iPhone 商店图，尺寸均为 `1242x2688`；执行 `python3 tools/appstore-screenshots/scripts/render_marketing.py --platform ios` 通过且不再出现其它平台缺图 warning；目检 zh-Hans 月报 raw 图确认有本月数据，目检 ja OCR raw 图确认自绘场景已显示日文。
- 风险与注意事项：输出目录未被 git 跟踪；四语言 iPhone 图已生成在 `tools/appstore-screenshots/output/store/ios/`，正式上传前仍建议打开 `tools/appstore-screenshots/output/preview.html` 做逐张目检。
- 回滚方式：回退上述 Swift 文件、四语本地化、截图工具配置 / 脚本 / README、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成 Pro 订阅页用户展示收口、深色模式可读性修正、多账本币种编辑和 iPhone 经典主题截图管线调整，静态门禁、模拟器编译和四语言 iPhone 经典主题导出均通过。
- 下一步建议：打开 `tools/appstore-screenshots/output/preview.html` 逐张目检后，将 `output/store/ios/{zh-Hans,zh-Hant,en,ja}` 的 24 张图用于 iPhone 端 ASC 截图补齐。

### ITER-319 月报 Widget 分类与 CTA 修复
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Widget UI / Monthly Report
- 类型：Bugfix / UI / 测试
- 目标：修复用户截图中月报 Widget 的 Top 分类显示 raw `hotel`，并增强右上角 `快速记一笔` 入口的按钮辨识度。
- 改动范围：更新 `AutoLedgerWidgets.swift`、CHANGELOG 和本日志。
- 未改动范围：未修改主 App 月报页、账本数据、分类 schema、SQLite / CloudKit schema、StoreKit、Pro entitlement、Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Widget 分类标题映射从只识别少量内建 raw value，扩展为先 trim/lowercase 后归一化，补齐 `hotel`、`hotels`、`lodging`、`accommodation`、`住宿`、`酒店住宿`、`酒店`、`ホテル`、`宿泊` 等酒店住宿别名，避免月报 Widget 直接展示 raw key。月报 Widget 右上角 `快速记一笔` 从小号文字胶囊改为带实心 `+` 圆标、chevron、描边和轻阴影的 CTA，保持尺寸克制但更像可点击按钮。
- 未完成内容：本轮未在真实桌面 Widget 面板中截图复核，因为当前可用验证路径是 XcodeBuildMCP / simctl；正式截图前仍建议在真机或系统 Widget 预览里目检中 / 英 / 日三语文案和截断情况。
- 测试情况：执行 `git diff --check` 通过；通过 XcodeBuildMCP 重新设置 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator defaults 后执行 `build_sim` 通过，status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-06-30T12-28-15-057Z_pid28622_0ee4c5ae.log`，本次 diagnostics 无 warning / error。
- 风险与注意事项：Widget 侧是独立 SQLite 读取与本地化映射，不能自动复用 Core 的 `TransactionCategory.title`；后续新增分类 raw value 时需要同步补 Widget 显示映射，或再做共享展示层抽取。
- 回滚方式：回退 `AutoLedgerWidgets.swift`、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已修复月报 Widget 的 `hotel` raw key 暴露，并提升 `快速记一笔` 入口的按钮感，模拟器 Debug build 通过。
- 下一步建议：TestFlight 或真机 Widget 刷新后，优先截图确认 Top 分类显示“酒店”，并看 `快速记一笔` 在当前壁纸背景上是否足够醒目。

### ITER-318 主题实时刷新修复
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Theme Refresh / Tab Chrome
- 类型：Bugfix / 测试
- 目标：修复外观主题切换后多数 tab 仍保持旧配色，必须关闭并重新打开 App 才完整生效的问题。
- 改动范围：更新 `AutoLedgerApp.swift`、`AppTheme.swift`、`HomeView.swift`、`InboxView.swift`、`LedgerView.swift`、`ReportView.swift`、`SettingsView.swift`、`iPadWorkspaceView.swift`、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志。
- 未改动范围：未修改主题 preset 配方、主题选择 UI、StoreKit、Pro entitlement、识别 / 记账 / 同步业务逻辑、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：根视图把主题 preset、外观模式和 Pro 自定义色组合为 `themeRefreshID` 后注入 `autoLedgerThemeRefreshID` environment；`HomeView`、记账、账本、月报、设置、酒店消费工作区和 iPad 工作区读取该环境值并触发主题动效更新；通用背景、页面标题、卡片、Hero、选中行和导航栏 chrome modifier 也读取同一个刷新值，避免页面继续停留在切换前的静态 `AppTheme.*` 颜色。自适应布局门禁新增根注入、主题环境 key 和各主 tab 刷新依赖检查，避免回归为只在外观页或首页局部刷新。
- 未完成内容：本轮未增加新的可见主题，也未重新导出全平台截图矩阵；Xcode-beta 当前缺少 `SimulatorKit.framework` / `Simulator.app`，XcodeBuildMCP runtime UI snapshot 无法使用，手动点击级验证改用 `simctl` 截图和 App 运行态偏好变化验证。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；通过 XcodeBuildMCP 确认 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator defaults 后执行 `build_sim` 通过，随后执行 `build_run_sim` 通过并启动 `top.darkrio326.AutoLedger`。iPhone 17 Simulator 运行态截图验证：App 未终止时将 `appThemePreset` 从 fresh 改为 classic 后，首页背景、主卡渐变、票据扫描图标实时变色，截图保存为 `/tmp/autoledger-theme-before.png` 和 `/tmp/autoledger-theme-after-defaults.png`；通过 pending deep link 进入账本 tab 后，账本页保持 classic 背景，截图保存为 `/tmp/autoledger-theme-ledger-clean.png`。
- 风险与注意事项：本轮通过 environment 依赖触发 SwiftUI 重算，不使用 `.id(...)` 重建 tab，因此不会主动清空导航栈；如果未来新增独立页面直接大量使用 `AppTheme.*` 且不套通用 chrome，应继续读取 `autoLedgerThemeRefreshID` 或复用现有 modifier。
- 回滚方式：回退上述 Swift 文件、自适应布局门禁、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已修复主题切换必须重启才完整生效的问题，并在 iPhone 17 Simulator 运行态确认首页实时换色和账本 tab 新主题背景。
- 下一步建议：继续处理月报分类 raw key `hotel` 显示，以及月报卡片中 `快速记一笔` 按钮辨识度不足的问题。

### ITER-317 标题与主题下拉回归修复
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Tab Chrome / Appearance
- 类型：Bugfix / 测试
- 目标：修复 TestFlight 截图中记账 tab 和设置 tab 顶部标题再次消失的问题，并调整外观主题下拉，让主题选择成为整张卡片可点击的大号下拉。
- 改动范围：更新 `InboxView.swift`、`SettingsView.swift`、`AppearanceSettingsView.swift`、`AppTheme.swift`、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志。
- 未改动范围：未修改账本 / 酒店消费 / 月报业务逻辑，未修改 StoreKit、Pro entitlement、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：确认标题回归根因是 ITER-316 为了统一样式移除了 `AutoLedgerPageTitle`，只保留系统 `.navigationTitle`，但当前自定义背景和 safe area 顶部结构下，大标题没有稳定渲染。`InboxView` 与 `SettingsView` 已恢复内容区 `AutoLedgerPageTitle`，并继续使用 `autoLedgerContentTitleNavigation` 在滚动后显示导航栏 inline 标题。外观主题从 4 个可见项调整为 6 个可见项：`fresh`、`classic`、`graphite`、`ledgerInk`、`harbor`、`custom`，隐藏 `nightFolio` / `sunrise` 以控制数量；主题选择从小号 `Picker` 改为整张卡片可点击的 `Menu`，卡片内展示当前主题名称、说明、色块和下拉指示。自适应布局门禁改为要求这两个页面必须同时包含内容区标题和滚动标题 modifier，并要求主题选择保留 6 个可见项和整卡下拉。
- 未完成内容：本轮未重新导出 TestFlight 真机截图；视觉确认仍建议在下一版 TestFlight 中看记账 / 设置两个 tab 的顶部标题，以及外观页主题整卡下拉是否符合手感。
- 测试情况：修改门禁后执行 `python3 scripts/check_adaptive_layout_rules.py`，先后预期失败并命中 `InboxView.swift` / `SettingsView.swift` 缺少 `AutoLedgerPageTitle` / `autoLedgerContentTitleNavigation`，以及主题数量和小号 `Picker` 不符合要求；恢复页面标题并改造主题整卡下拉后再次执行通过。
- 风险与注意事项：内容区标题恢复后，顶部会重新占据一行大标题高度，这是当前 `ReportView` / `AppearanceSettingsView` 已采用的稳定模式；滚动后的导航栏标题仍由同一 modifier 控制，不依赖系统大标题渲染。旧的 `nightFolio` / `sunrise` 偏好仍保留 enum 兼容，但因不在可见选择集合中会回落到默认主题。
- 回滚方式：回退 `InboxView.swift`、`SettingsView.swift`、`AppearanceSettingsView.swift`、`AppTheme.swift`、自适应布局门禁、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已修复记账与设置 tab 标题消失回归，并将主题选择改为 6 选项整卡下拉，同时用静态门禁固定该结构。
- 下一步建议：下一次 TestFlight 安装后，优先截图检查记账 / 设置 / 月报三个 ScrollView tab 的初始顶部标题和滚动后 inline 标题，再检查外观页整卡下拉和主题切换预览。

### ITER-316 v1.6.4 UI 细节与发布证据口径收口
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Release Smoke / Personal Pro
- 类型：Bugfix / 文档 / 测试
- 目标：承接用户反馈继续落实 `v1.6.4`，修复账单编辑、设置 Pro 卡、多账本、订阅管理、标题样式和当前版本说明等细节，并把 APNs / 云收件箱 / 订阅真实 smoke 的发布证据口径更新到最新状态。
- 改动范围：更新 `TransactionEditorView.swift`、`SettingsView.swift`、`LedgerProfileManagementView.swift`、`SubscriptionListView.swift`、`InboxView.swift`、四语 `Localizable.strings`、`scripts/check_adaptive_layout_rules.py`、`versions/v1.6.4-plan.md`、`versions/v1.6.4-regression-baseline.md`、README 四语路线图、CHANGELOG 和本日志；前置批次已提交为 `c3c2114d 收口 v1.6.4 回归基线与主题切换`。
- 未改动范围：未修改 StoreKit 商品 ID、购买 / 恢复 / 管理订阅核心流程、Worker runtime 代码、SQLite / CloudKit schema、酒店水单解析管线、云端 API 合同、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：账单编辑页右上角保存 / 更多操作从彩色圆形 icon-only 按钮改回常规 `Label` 样式，与酒店消费详情编辑按钮对齐；“酒店消费详情”四语标题改为“编辑消费详情”；设置页 AutoLedger Pro 高亮卡把月付 / 年付价格移动到独立左对齐栈，避免“首发年付”被 CTA 挤压；多账本管理为默认本地账本补显式重命名按钮；订阅管理右上角 `+` 改为菜单，支持手动新增订阅和上传订阅邮件截图，隐藏暂未稳定的“扫描历史账单自动识别订阅”入口，并让空状态按钮图标和底色跟随主题色；记账 tab 和设置 tab 当时改为系统导航标题，后续在 ITER-317 中修正为稳定内容区标题。设置页当前版本 / 后续计划文案扩展为当前 `v1.6.4` 实际状态。Cloudflare production 已通过 `wrangler secret list --env production` 验证存在 `APP_STORE_CONNECT_ISSUER_ID`、`APP_STORE_CONNECT_KEY_ID`、`APP_STORE_CONNECT_PRIVATE_KEY`、`APNS_KEY_ID`、`APNS_TEAM_ID`、`APNS_PRIVATE_KEY` 六个 secret 名称，未读取 secret 值；按用户 2026-06-30 补充，2026-06-29 人工 smoke 已测通订阅开通、APNs 推送、Worker 云收件箱、云候选转酒店消费并最终入账，价格和宽限期已配置，剩余项收缩为订阅元数据、审核材料、生命周期截图和证据归档。
- 未完成内容：本轮未补 App Store Connect 订阅元数据；未归档 2026-06-29 人工 smoke 的设备截图 / 日志片段；未补完整恢复、取消、过期、宽限期、账单重试和管理订阅截图；未做真机多主题 / 多字号截图矩阵。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行四语 `plutil -lint` 通过；执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 确认 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator defaults 后执行 `build_sim` 通过，status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-06-30T09-02-54-101Z_pid47757_e5d0fe23.log`，本次 build diagnostics 未返回 warning / error。
- 风险与注意事项：2026-06-29 端到端 smoke 是用户侧人工证据，不来自本机自动门禁；发布归档前仍建议保存设备截图、Cloudflare / APNs 日志片段和订阅状态截图。隐藏历史扫描订阅入口只是 UI 暂停，底层 `detectAndUpsertSubscriptions()` 保留给后续修复，不影响已有订阅列表和手动新增订阅。
- 回滚方式：回退上述 Swift UI 文件、四语本地化、自适应布局门禁、README / 版本计划 / 回归基线 / CHANGELOG / 本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成用户反馈的 `v1.6.4` UI 细节修复、设置页版本说明扩展和发布证据口径收缩；本地静态门禁、离线回归和 iOS Simulator 编译均通过。
- 下一步建议：补齐 App Store Connect 订阅元数据和商品本地化，归档 2026-06-29 云收件箱端到端 smoke 证据，再补订阅生命周期截图与 Review Notes / 隐私政策链接。

### ITER-315 外观主题切换与预览收敛
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System / Settings
- 类型：Bugfix / UI / 测试
- 目标：修复“外观与主题”切换后界面配色没有明显变化、主题预览也不随选择变化的问题，并按反馈把主题选择从多卡片网格收敛为下拉选择。
- 改动范围：更新 `AppThemePreset` 的可见选择集合和预览色 token；更新 `AppearanceSettingsView.swift` 的主题入口、选择绑定、Pro 自定义访问兜底和预览卡渲染；更新 `AutoLedgerApp.swift` 根视图主题刷新信号；更新 `scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志。
- 未改动范围：未删除旧主题 enum / 本地化文案以保留已写入偏好的兼容路径；未修改 StoreKit 商品、Pro entitlement、识别 / 记账 / 同步业务逻辑、SQLite / CloudKit schema、Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：主题设置入口改为 `.pickerStyle(.menu)` 的下拉式 `Picker`；可见选项收敛为 `fresh` / `classic` / `graphite` / `custom`，旧的 `ledgerInk` / `nightFolio` / `harbor` / `sunrise` 保留代码兼容但不会再出现在设置页，读取到这些旧值时回落到 `fresh`。外观预览卡改为直接接收 `selectedPreset`，并用该 preset 的画布、卡片、描边、文字与强调色渲染小账本样张；App 根视图观察主题、外观模式与自定义色偏好，触发已有 `AppTheme.*` 颜色重新求值且不重建 `LedgerStore` / 导航状态。自适应布局门禁新增规则，禁止回退到主题网格或未绑定 preset 的预览。
- 未完成内容：本轮未做真机 / 模拟器手动点击截图矩阵，也未导出所有主题的浅色 / 深色对照图。
- 测试情况：先修改 `scripts/check_adaptive_layout_rules.py` 后执行 `python3 scripts/check_adaptive_layout_rules.py`，预期失败并命中缺少 `selectableCases`、`themeMenuCard`、菜单式 `Picker`、`AppearancePreviewCard(preset: selectedPreset)` 以及旧 `themePickerGrid` / `AppearanceThemeOptionCard` 残留；实现后再次执行通过。执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；通过 XcodeBuildMCP 确认 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator defaults 后执行 `build_sim` 通过，status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-06-30T08-31-40-572Z_pid47757_a9c4fbca.log`；执行 `bash scripts/run_offline_regression.sh` 通过。构建仍有既有 Swift 6 actor isolation / Gemma deprecated / CloudKit deprecated 等 warning，无新增 error。
- 风险与注意事项：曾选择旧隐藏主题的用户升级后会显示 / 读取为默认 `fresh`，这是本轮“减少可选项”的有意收敛；Pro 自定义主题仍按既有 entitlement gate 控制，未订阅用户选择自定义会保留在 Pro 引导流程。
- 回滚方式：回退 `AppThemePreset.selectableCases` / 预览色 token、`AppearanceSettingsView.swift` 的 `themeMenuCard` 与 preset 预览、`AutoLedgerRootView.themeRefreshID`、自适应布局门禁、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：本轮已完成外观主题切换的 UI 收敛和预览修复，自动门禁、模拟器构建和离线回归均通过。
- 下一步建议：发布截图前补一次主题切换的真机 / 模拟器手动录屏或截图矩阵，确认浅色 / 深色下默认、经典、石墨和 Pro 自定义的视觉差异。

### ITER-314 v1.6.4 回归基线与发布证据清单
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Release Smoke / Personal Pro / StoreKit QA
- 类型：文档 / 治理 / 测试
- 目标：把 `v1.6.4` 从零散迭代记录推进到可发布收口视角，建立独立回归基线，并把本地自动门禁、ASC / TestFlight / Cloudflare production 外部证据和 `v1.7.0` 顺延项拆开。
- 改动范围：新增 `versions/v1.6.4-regression-baseline.md`；更新 `versions/v1.6.4-plan.md` 的状态、关联文档和 `GOAL-2219`；更新 README 四语路线图；更新 CHANGELOG 和本日志。
- 未改动范围：未修改 Swift / TypeScript 业务代码、StoreKit 商品 ID / 价格、Worker runtime 逻辑、SQLite / CloudKit schema、Cloudflare production secrets、APNs secrets、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`v1.6.4` baseline 已记录 Personal Pro、Free / Pro 边界、本地邮箱月度免费额度、批量候选 gate、高级去重 gate、云端专属水单收件箱、StoreKit 本地配置、Worker 服务端 entitlement P0 和 Pro 路线图预告的专项回归；同时把不能由 CLI 伪造的外部证据列为人工 / 外部环境边界，包括 ASC sandbox 购买、Review Notes、隐私政策、Cloudflare App Store Server API secrets、APNs secrets、真实 token claim smoke、真实邮箱 provider smoke 和截图矩阵。README 四语路线图不再把 Pro 页面 / 恢复购买 / 邮箱 gate 写成后续未落地项，并修正 `APNs secrets` 的完成口径为 production secrets 待配置。
- 未完成内容：本轮不配置外部密钥、不访问 App Store Connect、不执行 TestFlight / ASC sandbox 真购买；Cloudflare production App Store Server API secrets、APNs secrets、真实 token claim smoke、Review Notes / 隐私政策链接和截图矩阵继续后续收口。
- 测试情况：执行 `git diff --check` 通过；执行 `ruby -rjson -e 'JSON.parse(File.read("AutoLedger/AutoLedgerSupport.storekit"))'` 通过并输出 `storekit-json-ok`；执行 StoreKitTest session 加载命令通过并输出 `storekit-session-loaded`，系统打印保存配置 warning 但退出码为 0；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `cd tools/worker/hotel-folio-inbox && npm run check` 通过，typecheck 成功且 Vitest 19 tests passed；执行 `bash scripts/run_golden_regression.sh` 通过，38 cases；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 设置 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator defaults 后执行 `build_sim` 通过，status `SUCCEEDED`，build log 位于 `/Users/darkrio/Library/Developer/XcodeBuildMCP/workspaces/AutoLedgerRio-f8282a3b23c4/logs/build_sim_2026-06-30T08-20-23-363Z_pid47757_e41db963.log`。构建仍有既有 Swift 6 actor isolation / Gemma deprecated / CloudKit deprecated 等 warning，无 error。
- 风险与注意事项：当前 `v1.6.4` 仍沿用 ASC / App Store `1.5.0` 版本号；baseline 是发布收口证据，不代表外部账号、生产密钥或真实购买已完成。
- 回滚方式：删除 `versions/v1.6.4-regression-baseline.md`，回退 `versions/v1.6.4-plan.md` 的 `GOAL-2219` 和文档状态，回退 README 四语路线图、CHANGELOG 和本日志条目即可；无代码或数据迁移需要回滚。
- 结论：本轮已完成 `v1.6.4` 回归基线与本地自动门禁第一轮收口；发布前剩余项集中在外部账号 / 生产密钥 / 真实购买 / 审核截图材料。
- 下一步建议：继续配置 Cloudflare production App Store Server API / APNs secrets，并用 ASC sandbox / TestFlight 订阅 JWS 做真实 token claim smoke。

### ITER-313 外观主题配方与 Pro 自定义外观
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System / Pro UI
- 类型：UI / 能力增强 / 文案 / 文档 / 测试
- 目标：在不再启动新 OpenDesign 生成的前提下，使用已经生成的 `theme-palettes.html` 主题配方扩展 App 外观选择，修正外观页客户-facing 文案，并为 Pro 用户补充自定义外观主题入口。
- 改动范围：更新 `AppTheme.swift` 的主题 preset、配色 token 和自定义主题存储；更新 `AutoLedgerApp.swift` 注册自定义主题默认值与主题刷新动效；重写 `AppearanceSettingsView.swift` 的主题网格、外观模式和 Pro 自定义色控制；更新 `SupportAutoLedgerView.swift` Pro 功能展示；补齐四语外观 / Pro 文案；更新 UI 静态门禁脚本、CHANGELOG 和本日志。
- 未改动范围：未启动新的 OpenDesign run；未修改导入、记账、酒店水单、月报统计、CloudKit / SQLite schema、Cloudflare Worker、StoreKit 商品 ID / 价格、购买 / 恢复 / 管理订阅流程、既有 Pro 自动化 gate、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：外观页现在展示 `fresh` / `classic` / `graphite` / `ledgerInk` / `nightFolio` / `harbor` / `sunrise` / `custom` 多套主题；`fresh` 使用隐私薄荷配方，`graphite` 改为更明显的冷灰蓝工作台配方，`ledgerInk` 和 `nightFolio` 采用 OpenDesign 生成的新配方。每套 preset 都继续提供 light / dark token 并支持跟随系统。设置入口描述改为“多套App视觉风格，随时切换你喜欢的样式”，外观模式不再展示说明文字。Pro 用户可在自定义主题里选择表面色、强调色和辅助色；未订阅用户看到客户-facing 的 Pro 自定义外观说明和查看 Pro 入口。
- 未完成内容：未导出所有主题 × 浅色 / 深色截图矩阵；自定义外观偏好仍只保存在本机 `UserDefaults`，不参与多设备同步。
- 测试情况：执行 `plutil -lint` 检查四语 `Localizable.strings` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run 通过。构建仍有既有 Swift 6 actor isolation / Gemma deprecated / CloudKit deprecated 等 warning，无新增 error。
- 风险与注意事项：自定义主题使用用户选择的颜色推导浅深色 token，极端颜色组合仍可能需要后续截图目检；当前 Pro 自定义外观是本机 UI 权益，不影响基础主题 preset，也不锁定免费用户已有记账能力。
- 回滚方式：回退 `AppThemePreset` 新增主题 / `AppThemeCustomTheme`、`AppearanceSettingsView.swift` 的自定义外观区域、四语 `appearance.custom.*` / `pro.feature.appearance.*` 文案和本轮门禁脚本修改即可恢复到上一版多主题选择。
- 结论：本轮已把 OpenDesign 生成的多主题配方落地到 App，并把自定义外观作为 Pro 视觉权益补齐。
- 下一步建议：进入发布截图前，基于 screenshot mode 增加主题参数，批量导出默认主题、石墨、墨青账本、午夜票夹和自定义主题的浅深色对照图。

### ITER-312 Pro 路线图与 v1.7.0 规划预告
- 日期：2026-06-30
- 所属版本：v1.6.4 / v1.7.0
- 所属阶段：Personal Pro / Roadmap
- 类型：UI / 文案 / 文档 / 规划
- 目标：根据本轮决策，将当前 Pro 页面继续限定在酒店消费与邮箱自动化模块；把其他待实现的 Pro 能力先在 Pro 路线图预告，并明确放到 `v1.7.0 / ASC 1.6.0` 实现。
- 改动范围：更新 `AutoLedgerProView` 新增 Pro 路线图区；补齐四语 `pro.roadmap.*` 与 `pro.feature.rules.*` 文案；更新 `versions/v1.6.4-plan.md`、新增 `versions/v1.7.0-plan.md`；同步 README 四语路线图、CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、价格、购买 / 恢复 / 管理订阅流程、`ProEntitlementManager`、Pro gate、邮箱扫描 / 云端收件箱业务逻辑、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Pro 页面当前权益仍聚焦本地邮箱扫描、专属水单收件箱、批量候选和高级去重；高级搜索、订阅异常提醒、月结导出包和高级规则自动应用移动到独立路线图区，并用 `v1.7.0 / ASC 1.6.0` 与 `v1.7.0` badge 明确区分当前可用能力。`v1.6.4` 计划文档把 `GOAL-2220` 至 `GOAL-2223` 改为顺延项；`v1.7.0` 计划文档建立对应 GOAL-2300 至 GOAL-2350 队列和免费能力边界。
- 未完成内容：未实现 `v1.7.0` 高级搜索、订阅异常提醒、月结导出包或高级规则自动应用；未做 ASC 1.6.0 审核材料和截图矩阵。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run 通过，并以 `--screenshot-mode --screenshot-scene pro_subscription --screenshot-free-pro` 截图检查 Pro 首屏文案正常。构建仍有既有 Swift 6 actor isolation / Gemma deprecated / CloudKit deprecated 等 warning，无新增 error。
- 风险与注意事项：路线图区是预告展示，不接入功能入口或 gate；后续实现 `v1.7.0` 时需要避免把基础搜索、基础订阅、基础导出或历史数据查看误放入 Pro gate。
- 回滚方式：回退 `AutoLedgerProView` 的 `roadmapSection` / `roadmapItems`、四语 `pro.roadmap.*` / `pro.feature.rules.*` 文案、`versions/v1.7.0-plan.md` 和 README / `v1.6.4` 计划中的路线图描述即可恢复到仅展示当前 Pro 权益。
- 结论：本轮已把非酒店模块 Pro 能力从当前交付面移入路线图预告，并建立 `v1.7.0 / ASC 1.6.0` 的承接计划。
- 下一步建议：在 `v1.7.0` 开始前，先冻结高级搜索、订阅异常、月结包和高级规则的 Free / Pro gate 合同，再分别进入实现。

### ITER-311 Pro 页面展示文案收敛
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / StoreKit UI
- 类型：UI / 文案 / 文档 / 测试
- 目标：对比当前 Pro 页面展示文案后，选择一个更贴近当前可交付边界的方向推进：从宽泛“省时间工具清单”收敛为“免费记账不变，Pro 自动整理”。
- 改动范围：更新 `AutoLedgerProView` 功能卡清单；更新简体中文、繁体中文、英文和日文 `pro.*` / `settings.pro.subtitle` 文案；更新 CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、价格、购买 / 恢复 / 管理订阅流程、`ProEntitlementManager`、Pro gate、邮箱扫描 / 云端收件箱业务逻辑、Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：设计对比后选择当前 P0 自动化能力优先方案；Pro 首屏标题改为强调免费基础能力不变、Pro 负责自动整理；功能卡从“本地邮箱 / 批量 / 去重 / 高级搜索 / 订阅异常 / 月结包”收敛为“本地邮箱扫描 / 专属水单收件箱 / 批量候选 / 高级去重”；状态卡、订阅商品说明和设置页 Pro 入口同步改为当前能力口径；四语文案补齐 `pro.feature.cloud_inbox.*`。
- 未完成内容：未做真实 ASC sandbox 购买态截图矩阵；未处理后续路线图能力的独立“Coming soon”展示。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run 通过，并以 `--screenshot-mode --screenshot-scene pro_subscription --screenshot-free-pro` 截图检查 Pro 首屏文案无明显遮挡；执行 `bash scripts/run_offline_regression.sh` 通过。
- 风险与注意事项：未使用的后续路线图本地化 key 仍保留在 strings 中，避免本轮扩大删除范围；Pro 页面不再把高级搜索、订阅异常和月结包作为当前展示卖点，后续若这些能力实际 gate 落地，可再单独恢复或加路线图区。
- 回滚方式：回退 `AutoLedgerProView` 的 `featureItems` 列表和四语 `pro.*` / `settings.pro.subtitle` 文案即可恢复上一版 Pro 页面展示；购买与权益逻辑不受影响。
- 结论：本轮完成 Pro 页面展示文案收敛，当前页面更贴合 `v1.6.4` P0 Pro 自动化边界。
- 下一步建议：继续用 StoreKit / TestFlight 验证未订阅、已订阅、恢复购买和过期状态下 Pro 页面与各 Pro gate 入口的真实文案一致性。

### ITER-310 ScrollView Tab 顶部 chrome 与标题阈值修复
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System
- 类型：Bugfix / UI / 文档 / 测试
- 目标：修复用户反馈的记账、月报、设置三个 tab 顶部出现白色样式缺失块，以及记账 / 设置自绘页面标题消失时机与账本、酒店消费 tab 不一致的问题。
- 改动范围：更新 `AppTheme.swift` 的导航栏 chrome 和自绘页面标题阈值；更新 `InboxView.swift` 移除记账 tab 的 `toolbarRevealOffset: -56` 特殊值；更新 `scripts/check_adaptive_layout_rules.py` 固化新规则；更新 CHANGELOG 和本日志。
- 未改动范围：未修改导入、记账、酒店水单、月报统计、设置项、主题 preset、Pro gate、StoreKit、SQLite / CloudKit schema、Cloudflare Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`autoLedgerSolidNavigationBarChrome` 从单色 `AppTheme.canvas` 改为与账本 / 酒店消费 split/list 页面一致的 `.regularMaterial` 导航栏背景，避免 ScrollView tab 顶部被单色白块覆盖；`autoLedgerContentTitleNavigation` 默认阈值从 `-12` 调整为 `0`，让 inline 标题在页面大标题抵达顶部边缘时再切换；记账 tab 不再使用 `-56` 特殊阈值，改走统一默认逻辑；自适应布局门禁同步要求新调用并禁止旧阈值。
- 未完成内容：本轮未新增自动截图矩阵；视觉修正仍建议用 iPhone Simulator 在记账、月报、设置三个 tab 顶部和滚动临界点人工目检。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run 通过。构建仍有既有 Swift 6 actor isolation / Gemma deprecated / CloudKit deprecated 等 warning，无新增 error。
- 风险与注意事项：`autoLedgerSolidNavigationBarChrome` 是共享 modifier，除主 tab 外也会影响少量使用该 modifier 的导入 / 外观设置页面；由于目标是统一到账本 / 酒店消费的 material 语义，行为风险集中在视觉层。
- 回滚方式：回退 `autoLedgerSolidNavigationBarChrome` 的 `.regularMaterial`、`autoLedgerContentTitleNavigation` 默认阈值和 `InboxView` 调用即可恢复上一版表现。
- 结论：本轮将 ScrollView tab 顶部 chrome 和标题切换时机对齐到账本 / 酒店消费 tab 的系统感。
- 下一步建议：验证通过后，用 Simulator 截记账、月报、设置顶部静止和滚动临界两组图，确认无白块且标题切换自然。

### ITER-309 Motion 基础设施与主题切换微动效
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System
- 类型：UI / 能力增强 / 文档 / 测试
- 目标：回答“App 需要音频和动画吗”后的落地选择：不新增自定义音频，先补一套克制、统一、可关闭的动效基础设施，用于增强产品感而不打扰记账工具场景。
- 改动范围：更新 `AppTheme.swift`，新增 `AppMotion` quick / standard / theme / emphasis token、`autoLedgerMotion` modifier 和减少动态效果支持；更新根 App 主题 / 外观模式过渡；更新外观页主题 / 模式切换、预览卡片和系统 selection 触觉反馈；更新 CHANGELOG 和本日志。
- 未改动范围：未新增音频资源、提示音或后台播放能力；未修改导入、记账、酒店水单、批量候选、Pro gate、StoreKit、购买 / 恢复 / 管理订阅流程、SQLite / CloudKit schema、Cloudflare Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`autoLedgerMotion` 读取 `accessibilityReduceMotion`，当用户开启减少动态效果时自动禁用 SwiftUI animation；主题切换、外观模式切换、背景渐变、设置页标题显隐和 selected row 背景使用统一动效节奏；外观页切换主题 / 模式时使用系统 selection sensory feedback，避免自定义音频打扰用户。
- 未完成内容：本轮未为导入识别进度、保存成功、账单插入 / 删除和扫描状态建立完整 motion matrix；未做三主题 × 浅色 / 深色的录屏或截图矩阵。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run，结果 SUCCEEDED，构建警告为既有 Swift 6 actor / Gemma deprecated / CloudKit deprecated 等警告。
- 风险与注意事项：动效集中在主题和共享 UI chrome，行为风险低；`sensoryFeedback` 使用系统 selection feedback，不引入音频文件。后续若扩展到导入 / 保存状态，应继续尊重减少动态效果，并避免让记账流程依赖动画完成。
- 回滚方式：回退 `AppMotion` / `autoLedgerMotion`、根 App theme animation、外观页 transition / sensory feedback 和本轮文档即可恢复到无共享 motion token 状态；业务数据不受影响。
- 结论：AutoLedger 当前更适合微动画和触觉反馈，而不是自定义音频；本轮已建立最小可复用 motion 基础。
- 下一步建议：后续页面级 polish 可优先补导入识别、保存成功、账单行变更和 Pro gate 展开的状态动效。

### ITER-308 多主题与浅深色外观模式
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System
- 类型：UI / 能力增强 / 文档 / 测试
- 目标：在保留 OpenDesign polish 方向的同时，不把 App 固定为唯一视觉；支持保留多套 App 样式主题，并确保每套主题都支持 iOS 浅色、深色和跟随系统。
- 改动范围：更新 `AppTheme.swift`，新增 `AppThemePreset` 和 `AppColorSchemePreference`；更新 App 入口默认值和根视图外观模式；设置页新增“外观与主题”入口；新增 `AppearanceSettingsView`，支持主题选择、外观模式选择、色板和账单预览；补齐四语文案；更新 CHANGELOG 和本日志。
- 未改动范围：未修改导入、记账、酒店水单、批量候选、Pro gate、StoreKit、购买 / 恢复 / 管理订阅流程、SQLite / CloudKit schema、Cloudflare Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`fresh` 保留本轮 OpenDesign 清爽产品感；`classic` 保留上一版暖米色 AutoLedger 风格；`graphite` 预留偏专业工作台的冷灰蓝风格。三套主题均提供 light / dark palette，现有 `AppTheme.canvas/card/ink/mutedInk/accent/accentSecondary/heroGradient/screenGradient` 调用名保持不变。外观模式新增 `system/light/dark`，通过根 View `.preferredColorScheme` 生效；默认值为 `fresh + system`。
- 未完成内容：本轮未增加截图模式专用主题场景；外观页已可在模拟器构建运行，但尚未逐一导出三主题 × 三模式的截图矩阵。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build-run，结果 SUCCEEDED，新增外观页已编入 target；构建警告为既有 Swift 6 actor / Gemma deprecated / CloudKit deprecated 等警告。
- 风险与注意事项：主题偏好和外观模式均保存到本机 `UserDefaults`，不参与 iCloud 同步，不影响账本数据。若未来需要把主题同步到多设备，需要单独评估配置同步合同。
- 回滚方式：回退 `AppearanceSettingsView.swift`、设置页外观入口、`AppThemePreset` / `AppColorSchemePreference`、App 默认值和四语 `appearance.*` 文案即可恢复到单主题 token 模式；业务数据不受影响。
- 结论：AutoLedger 现在可以保留多套 App 主题，并且每套主题都支持 iOS 浅色 / 深色 token 与跟随系统外观。
- 下一步建议：如果进入发布截图阶段，可基于 screenshot mode 增加主题 / 外观参数，批量导出 `fresh` 与 `classic` 的浅色、深色对照图用于人工目检。

### ITER-307 OpenDesign MCP 全局视觉 token polish
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：App UI / Design System
- 类型：UI / 设计 / 工具链 / 文档
- 目标：按“使用 OpenDesign MCP 做一轮整体 UI polish，美化 UI、增强产品感”的要求，先修复本机 OpenDesign MCP 可用性，再用 OD 生成 AutoLedger 视觉参考，并将可回滚的全局主题 token 落到 SwiftUI `AppTheme`。
- 改动范围：修复本机 OpenDesign daemon 启动链路；新增 OD 项目 `autoledger-ui-polish` 并生成 `index.html` 视觉参考；更新 `AutoLedger/AutoLedger/Shared/Constants/AppTheme.swift` 的 canvas、card、cardStroke、softShadow、ink、mutedInk、accent、accentSecondary、screenGradient、heroGradient、surface background、card / hero surface；更新 CHANGELOG 和本日志。
- 未改动范围：未修改导入、记账、酒店水单、批量候选、Pro gate、StoreKit、购买 / 恢复 / 管理订阅流程、SQLite / CloudKit schema、Cloudflare Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`；未覆盖已有未提交的 `InboxView`、`SupportAutoLedgerView`、`iPadWorkspaceView`、本地化、脚本和 Pro audit 改动。
- 完成内容：OpenDesign 不能使用的原因已定位并修复：全局 `pnpm 11.7.0` 不满足 OpenDesign `pnpm@10.33.2`，Node `25.9.0` 不满足 `~24`，且 `tools-dev` 默认随机端口而 MCP 固定访问 `127.0.0.1:7456`。本轮安装 / 切换 Node `24.18.0`，用 `npx pnpm@10.33.2` 重建依赖和 `better-sqlite3`，并以 `--daemon-port 7456 --web-port 7457` 启动 OD。OD 生成的设计参考位于 `http://127.0.0.1:7456/api/projects/autoledger-ui-polish/raw/index.html`，Studio 位于 `http://127.0.0.1:7457/projects/autoledger-ui-polish/conversations/3f3cf378-9eed-4e26-9b07-e3cd62305917/files/index.html`。SwiftUI 侧按 OD 方向从暖米色体系调整为 fresh neutral + deep ink + green / restrained blue + 少量暖色高光，统一卡片、背景和 Hero 表面产品感。
- 未完成内容：OD 内部 render wrapper 命令在当前 daemon build 中不可用，OD 子 agent 未能完成工具内 rendered screenshot check；本轮只完成静态 HTML 检查和 SwiftUI 构建级验证，不包含真机 / 模拟器截图目检。
- 测试情况：OD 子 agent 对 `index.html` 完成静态检查：HTML parse、viewport、`data-od-id`、无 filler marker、无 `scrollIntoView` 均通过；本轮 Codex 执行 `git diff --check` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；通过 XcodeBuildMCP 执行 `.xcworkspace` / `AutoLedger` / iPhone 17 Simulator Debug build，结果 SUCCEEDED；执行 `bash scripts/run_offline_regression.sh` 通过。
- 风险与注意事项：本轮是全局主题 token polish，覆盖面广但行为风险低；视觉观感仍需后续通过模拟器截图或 TestFlight 人工目检确认。OpenDesign daemon 依赖 Node 24 / pnpm 10.33.2 / 7456 固定端口，后续若再次“用不上 OD”，优先检查这三项。
- 回滚方式：回退 `AppTheme.swift` 中本轮主题 token、背景、card / hero surface 修改即可恢复上一版暖色主题；OD 项目 `autoledger-ui-polish` 可保留为参考，不影响 App 编译或运行。
- 结论：本轮 OpenDesign MCP 已恢复可用，并完成一轮可落地的全局视觉 token polish。
- 下一步建议：基于 OD 参考继续做页面级 polish 时，优先处理 Inbox quick capture、Ledger row anatomy、Report cards 和 iPad inspector，避免一次性改动业务流。

### ITER-306 v1.6.4 UI polish 与批量候选 Pro Gate
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / App UI / Automation Gate
- 类型：能力增强 / UI / 文档 / 测试
- 目标：按 Pro 文案继续推进实际 Pro 功能边界，补上已定义为 P0 的“批量候选导入”门禁，同时收尾记账首页和 Pro 页面两个 UI polish 点。
- 改动范围：更新 `InboxView`、`SupportAutoLedgerView`、`IPadWorkspaceView`、四语本地化、`docs/operations/pro-access-audit.md`、`scripts/check_accessibility_smoke.py`、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、购买 / 恢复 / 管理订阅流程、手动记账、单张截图识别、手动酒店水单导入、邮箱水单扫描、云端收件箱 Worker、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、Cloudflare secrets、Cloudflare Worker 部署或 `MARKETING_VERSION`；本轮未提交、未推送，避免触发 ASC 构建。
- 完成内容：记账 tab 一键记账折叠态下，“相册截图”和“票据扫描”改为一行一个按钮；一键记账展开态保持一行两个按钮。`AutoLedgerProView` 首行移除“专享 / Member / 特典”标识，并给 `AutoLedger` 品牌文字增加单行缩放保护，避免折行。`IPadBatchImportWorkspaceView` 接入 `ProEntitlementManager.canUse(.batchCandidateImport)`，gate 新的多文件批量导入、拖放导入、Mac 导入文件命令、重试和识别执行；未订阅时展示“批量候选是 Pro 自动化”提示并打开 Pro 页。已有候选队列、候选复核、历史数据、CSV / JSON 数据交换、单张截图识别和手动酒店水单导入保持可用。
- 未完成内容：当前 Codex 会话没有暴露可直接调用的 OpenDesign MCP 工具，因此未能通过 OpenDesign 工具自动审阅全 App；本轮按现有 SwiftUI 组件、截图模式和静态门禁完成本地 polish。真实 StoreKit 沙盒订阅状态下的批量候选门禁切换仍需后续 TestFlight / Sandbox smoke。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `.xcworkspace` iOS generic Debug build 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 iPad Pro 13 Simulator Debug build / install / launch 通过，截图 `/tmp/autoledger-pro-gate-workspace-review-ipad.png` 检查批量候选免费态 Pro 提示、队列和详情占位无遮挡；执行 iPhone 17 Simulator screenshot mode，截图 `/tmp/autoledger-pro-gate-quick-capture-iphone-2.png` 检查折叠态“相册截图 / 票据扫描”一行一个按钮，截图 `/tmp/autoledger-pro-gate-pro-iphone.png` 检查 Pro 页无“专享”且 `AutoLedger` 不折行。
- 风险与注意事项：`batchCandidateImport` 是客户端 `localUIGate`，用于本地自动化体验边界，不应被视为服务端安全授权；服务端成本能力仍只通过 `cloudFolioInbox` 的 server-verified path 授权。批量候选门禁只阻止新的批量自动化处理，不锁既有候选和历史账本。
- 回滚方式：回退 `IPadBatchImportWorkspaceView` 中的 batch Pro gate / Pro sheet / gate banner，四语 `ipad.batch_import.pro.*` 文案、Pro audit 和静态门禁脚本即可恢复旧批量导入行为；回退 `InboxView` 与 `SupportAutoLedgerView` 可恢复上一版首页按钮布局和 Pro 页头部。
- 结论：本轮完成 UI polish 和批量候选 P0 Pro gate；免费路径仍保留单张识别、手动酒店水单导入、既有候选复核和历史数据访问。
- 下一步建议：完成本轮 build / smoke 后，用 ASC sandbox 或 TestFlight 验证未订阅、已订阅、恢复购买和订阅过期四种状态下批量候选入口的按钮、提示和执行行为。

### ITER-305 v1.6.4 云端收件箱体验与 entitlement P0
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / Cloud Inbox / Server Entitlement
- 类型：能力增强 / 安全 / UI / 文档 / 测试
- 目标：在不影响手动 PDF 和本地邮箱扫描的前提下，让云端水单收件箱在服务端 entitlement 未配置或校验失败时有自然 fallback，并补上生产 token claim 的最小 App Store Server API 授权链路。
- 改动范围：更新 `ProEntitlementManager`、`ServerEntitlementVerifier`、`HotelFolioInboxClient` 和 `HotelFolioInboxImportView`；补齐四语 cloud inbox 文案；更新 Worker `src/index.ts`、tests、`wrangler.jsonc` 和 README；更新 `docs/operations/pro-access-audit.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、购买 / 恢复 / 管理订阅 UI、手动酒店 PDF 导入、本地邮箱扫描免费月度额度、邮箱授权保存、酒店水单解析流水线、SQLite / CloudKit schema、APNs secrets、Cloudflare 生产部署、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：App 侧保存 StoreKit verified transaction 的 `jwsRepresentation`，云端水单 capability 通过 Worker `/v1/pro-entitlements/verify` 校验；未订阅时只展示 Pro 方案入口，服务端未配置或校验失败时展示服务端校验说明和手动 PDF / 本地邮箱扫描 fallback，领取/刷新云端地址保持禁用但不影响本地入口。token claim 发送同一 signed transaction JWS，Worker 生产默认调用 App Store Server API `GET /inApps/v1/transactions/{transactionId}`，校验 Bundle ID、Pro 商品、撤销状态和订阅到期后才创建 token；token `pro_expires_at` 来自服务端验证结果，`user_id` 使用原始交易号 hash，避免直接落库 Apple 原始 transaction id。`wrangler.jsonc` 增加 App Store bundle/environment 非密变量，README 记录 production secrets 配置方式。
- 未完成内容：生产 Cloudflare secrets 尚未由本轮写入；生产 Worker 尚未部署；订阅续期 / 退款 / 到期后的既有 token 停用或续期同步、运营面板和 APNs secrets 仍需后续上线配置或定时校验补强。
- 测试情况：执行 Worker `npm run check`，typecheck 通过、Vitest 19 tests passed；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `git diff --check` 通过。
- 风险与注意事项：App Store Server API production 需要配置 `APP_STORE_CONNECT_ISSUER_ID`、`APP_STORE_CONNECT_KEY_ID`、`APP_STORE_CONNECT_PRIVATE_KEY` 和 production environment；未配置时生产 token claim 会继续返回 `server_entitlement_required`，这是安全默认而不是 App 本地导入阻断。dev/staging 若依赖 bootstrap，仍需显式设置 `ALLOW_UNVERIFIED_TOKEN_CLAIM=true`，并避免带入 production。
- 回滚方式：如生产 App Store Server API 临时不可用，可回退 `CloudFolioInboxEntitlementVerifier` 默认接入、token claim signed transaction 参数和 Worker App Store 校验分支，恢复上一轮的默认禁止领取状态；手动 PDF、本地邮箱扫描和已保存酒店数据不受本轮回滚影响。
- 结论：本轮完成云端水单收件箱的 App fallback 体验和生产 token claim 的最小服务端授权链路；剩余上线项集中在 Cloudflare production secrets / deploy 和 token 生命周期运维同步。
- 下一步建议：在 Cloudflare production 写入 App Store Connect secrets 后部署 Worker，使用 ASC sandbox / TestFlight 订阅 JWS 做一次真实 token claim smoke，并补退款 / 到期 token 停用策略。

### ITER-304 v1.6.4 Pro 权益安全边界与开源发布风险控制
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / Cloud Inbox / Governance
- 类型：能力增强 / 安全 / 文档 / 治理 / 测试
- 目标：在不重写现有 IAP 的前提下，明确客户端 Pro gate 与服务端安全边界，收紧云端水单 token claim，并降低 public repo + 宽松许可证带来的换皮发布风险。
- 改动范围：更新 `AutoLedgerProAccessPolicy`、`ProEntitlementManager`、新增 `ServerEntitlementVerifier`，调整云端水单收件箱 UI 提示和四语文案；更新 Worker token claim、wrangler vars、Worker tests / README；替换根 `LICENSE`，更新 README 四语许可说明；新增 `docs/operations/pro-access-audit.md`、`docs/operations/brand-assets-notice.md`；补充外部酒店解析 debug 响应脱敏；更新 CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品 ID、购买 / 恢复 / 管理订阅流程、手动记账、单张截图、手动酒店水单导入、酒店历史查看、SQLite / CloudKit schema、APNs secrets、真实 App Store receipt 后端、Cloudflare 生产部署、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增 `ProSecurityBoundary`，将本地邮箱扫描、批量候选导入和高级去重归为 `localUIGate`，将 `cloudFolioInbox` 归为 `serverVerified`，将高级搜索、订阅异常检测、月结导出包和高级规则自动化归为 `planned`；`ProEntitlementManager.resolveAccess(_:)` 返回 free / allowed / requires purchase / planned / requires server verification / verification failed 等状态，旧 `canUse(_:)` 保留为同步 UI gate 且不再允许云端能力；云端水单收件箱在服务端 verifier 未接入时禁用领取 token 并显示服务端校验提示。Worker token claim 默认关闭，未开启时返回 `403 server_entitlement_required` 且不创建 token；dev/staging 显式 `ALLOW_UNVERIFIED_TOKEN_CLAIM=true` 时写入短期 `pro_expires_at`，TTL 默认 7 天并封顶 30 天。根许可证从 MIT 改为 source-available 非商业许可证，README 四语声明未授权不得换皮上架 / 商业使用 / 绕过 Pro gate 后分发，品牌资产不随源码授权。密钥扫描未发现真实 secret；外部解析 API key 仍走 Keychain / 环境变量，酒店外部解析 debug 响应新增 Authorization / api key / token 脱敏。
- 未完成内容：完整 App Store Server API / receipt / transaction 后端未实现；生产 Worker 尚未部署本轮配置；生产 `pro_inbox_tokens` 的续期 / 停用同步、运营面板和 APNs secrets 配置仍需后续完成；`npm install` 报告现有依赖审计问题 1 moderate / 3 high，未在本轮升级依赖以避免破坏 Worker。
- 测试情况：执行 `npm install && npm run check`，Worker typecheck 通过、Vitest 15 tests passed；执行 `xcodebuild -project AutoLedger/AutoLedger.xcodeproj ... build` 失败于主 App SwiftDriver，符合当前工程必须使用 `.xcworkspace` 的约束；改用 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 `git diff --check` 通过；执行密钥关键词扫描，未发现真实密钥，命中项为文档、变量名、placeholder、token hash / 配置说明和代码中的 Keychain / Header 使用。
- 风险与注意事项：本轮把云端 token claim 从“可裸领”改为默认禁止，因此未接入服务端 entitlement 的生产环境不能再由 App 领取新 token；已有 token 仍由 Worker 的 `status` 和 `pro_expires_at` 决定是否可用。dev/staging 仍显式允许 bootstrap，需避免把该变量带到 production。旧 MIT commit 的既有授权不能被本 commit 自动撤回，许可证防护从本 commit 起生效。
- 回滚方式：若需要临时恢复旧云端领取，可回退 Worker `ALLOW_UNVERIFIED_TOKEN_CLAIM` gate / `pro_expires_at` TTL 改动和 App `cloudFolioInbox` server verification UI；若需要恢复 MIT，可回退 `LICENSE` 与 README / brand notice / audit 文档。本轮未改 StoreKit 购买链路和核心免费功能。
- 结论：本轮完成 Pro 权益安全边界、Worker token claim 安全默认关闭、source-available 许可和品牌资产声明的最小闭环；当前剩余硬依赖是服务端 entitlement 后端与 Cloudflare 生产配置。
- 下一步建议：实现 App Store Server API / signed entitlement token 后端，把生产 Worker `POST /v1/cloud-hotel-folio-token` 接到真实订阅验证；在 Cloudflare production 确认不设置 `ALLOW_UNVERIFIED_TOKEN_CLAIM`，并补 `pro_expires_at` 续期 / 停用同步。

### ITER-303 v1.6.4 记账首页 Open Design 首屏 polish
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / SDK Polish
- 类型：UI / 文档 / 测试
- 目标：把记账 tab 首屏从偏干的入口堆叠，调整为更有产品感的一键记账捕捉中心，同时保留相册截图和票据扫描两个高频入口。
- 改动范围：更新 `InboxView` 首页结构、`AppTheme` 标题滚动阈值支持、四语本地化、`scripts/check_adaptive_layout_rules.py`、CHANGELOG 和本日志；通过 `codex mcp add` 安装 `open-design` MCP 配置。
- 未改动范围：未修改截图 OCR、票据扫描、剪贴板导入、语音记账、快捷指令、交易保存、SQLite / CloudKit schema、StoreKit 商品、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：首页改为“一键记账”主卡，展示长按 -> 自动截图 -> 记账流程、本月支出和 Top 商户轻统计；相册截图和票据扫描保持同一行按钮并完整露出；语音记账、手动记账、相册、相机和剪贴板入口统一进入右上角更多菜单；一键记账步骤默认折叠，点击主卡 chevron 后展开为纵向整行操作；记账页内容增加最大宽度约束，避免 iPad / 宽窗口横向摊开；`open-design` Codex MCP 已写入全局配置，当前会话不热加载新工具。
- 未完成内容：Open Design daemon 源仓库当前是 partial checkout，`od` wrapper 仍依赖尚未构建的 daemon `dist/cli.js`；后续如需直接调用 Open Design MCP 工具，需要先启动 / 构建 Open Design daemon 或使用桌面版服务。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `python3 scripts/check_accessibility_smoke.py` 通过；执行 `git diff --check` 通过；执行 iOS generic Debug build 通过；执行 iOS 27 iPhone 17 Simulator Debug build / install / launch 通过；最终截图 `/tmp/autoledger-open-design-iphone-final.png` 检查主卡、两个导入按钮和底部 tab 无遮挡。
- 风险与注意事项：截图中的本月支出 / Top 商户会随本机账本数据变化；新安装无快捷指令记录时主卡默认折叠，用户需要点击 chevron 才展开快捷指令设置步骤。
- 回滚方式：回退 `InboxView` 的主卡 / 快捷入口 / toolbar menu 调整、`AppTheme` 标题阈值参数、四语新增文案、布局门禁脚本和文档记录即可；业务导入链路不受影响。
- 结论：记账首页首屏已从功能堆叠调整为更完整的捕捉中心，满足“首屏聚焦一键记账、相册截图和票据扫描同排、语音入口隐藏到更多菜单”的当前目标。
- 下一步建议：用真实 TestFlight 数据再看一张有快捷指令记录和真实月度统计的截图，确认主卡轻统计在非空数据下仍不挤压。

### ITER-302 v1.6.4 邮箱水单免费月度额度
- 日期：2026-06-30
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / Hotel Email
- 类型：能力增强 / UI / 文档 / 测试
- 目标：调整本地邮箱水单导入的 Free / Pro 边界，让免费用户可以真实测试邮箱水单端到端流程，同时把无限导入继续作为 AutoLedger Pro 自动化能力。
- 改动范围：更新 `AutoLedgerProAccessPolicy` 平台无关额度合同、`HotelFolioEmailImportView` 邮箱导入页 gate、四语本地化、邮箱导入截图模式免费态覆盖、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 IMAP 登录 / mailbox 选择 / MIME 解析 / 候选召回规则 / PDFKit / 酒店水单解析 / SQLite / CloudKit schema、StoreKit 商品、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：免费用户可继续进入邮箱配置、手动扫描并预览候选水单；成功生成待确认酒店水单草稿后，每月消耗 1 次免费本地邮箱导入额度；失败导入、连接测试、扫描和候选预览不消耗额度；额度按自然月自动刷新；Pro 用户不限制本地邮箱导入次数。额度状态本地保存，已用完时导入按钮转为查看 Pro，并提示仍可手动扫描 / 预览候选。
- 未完成内容：真实 ASC 沙盒订阅状态下的额度 UI 切换仍需 TestFlight / Sandbox 继续 smoke；多设备间免费额度同步当前不作为本轮目标，避免把本地邮箱导入额度变成云端用户账户系统。
- 测试情况：先在离线回归中加入 `LocalEmailFolioImportAllowanceState` 断言，确认 RED 失败为缺少类型；实现后执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行主 App iOS generic Debug build 通过；执行 iOS 27 iPhone 17 Simulator Debug build 通过；安装并以 `email_folio_import --screenshot-free-pro` screenshot mode 启动，截图 `/tmp/autoledger-email-folio-free-quota-ipad-fresh.png` 检查“本月可免费导入一次”、`查看 Pro`、`扫描邮箱水单` 无明显遮挡 / 重叠 / 折行。
- 风险与注意事项：额度保存在本机 `UserDefaults`，卸载重装会重置；这是当前免费试用口径的轻量实现，不替代未来订阅后端或账户系统。导入成功后才消耗额度，避免邮箱服务异常让用户损失试用机会。
- 回滚方式：回退 `LocalEmailFolioImportAllowanceState`、邮箱导入页额度 gate / 本地存储、四语新增文案、截图模式免费态覆盖和版本文档记录即可；既有邮箱候选召回、手动 PDF 导入和 Pro 页面不受影响。
- 结论：本地邮箱水单导入已从“免费直接被 Pro 阻断”调整为“免费每月 1 次成功导入、Pro 不限”，可以支持 TestFlight 真实体验后再触发订阅转化。
- 下一步建议：结合真实沙盒订阅验证未订阅、已订阅、恢复购买和订阅过期四种状态下邮箱导入页的按钮 / 文案 / 额度显示。

### ITER-301 v1.6.4 数据清洗 Pro Gate
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / Automation Gate
- 类型：能力增强 / UI / 文档 / 测试
- 目标：收口 `GOAL-2211` 中“高级去重继续接入实际 Pro gate”的剩余工程缺口。
- 改动范围：更新 `IPadWorkspaceView` 的数据清洗工作区、四语本地化、截图模式免费态开关、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 `DataCleaningPreviewPlanner`、账单去重算法、商户别名 / 分类修正规则、SQLite / CloudKit schema、StoreKit 商品、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：iPad / Mac 数据清洗与疑似重复处理工作区在展示预览和执行清理前调用 `ProEntitlementManager.canUse(.advancedDeduplication)`；未订阅时展示 Pro 自动化说明、免费边界和查看 Pro 方案入口；已订阅或 DEBUG override 状态继续进入原清理界面。免费用户仍可手动查看、编辑和删除所有历史账单。
- 未完成内容：真实 StoreKit 购买 / 到期状态下的界面切换仍需结合 `GOAL-2216` 生命周期 smoke 验证。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行主 App iOS generic Debug build，结果 PASS；执行 iOS 27 iPad Simulator Debug 构建通过；安装并以 `workspace_cleaning` screenshot mode 启动通过；新增 `--screenshot-free-pro` 覆盖 Debug override 后，截图 `/tmp/autoledger-cleaning-pro-gate-ipad-free.png` 检查左侧选中态、右侧 Pro gate 卡片、按钮和文案无明显遮挡 / 折行；截图模式已避开通知权限弹窗对 UI 回归的干扰。
- 风险与注意事项：本轮只 gate 批量自动清理工作区，不 gate 单笔账单编辑、历史查看、删除或恢复。
- 回滚方式：回退 `IPadCleaningPreviewWorkspaceView` 中的 Pro 判断 / Pro sheet / gate card，以及四语 `ipad.cleaning.pro.*` 文案；数据清理底层算法和历史账本不受影响。
- 结论：`GOAL-2211` 的 P0 自动化 gate 已覆盖 C1 专属收件箱、本地邮箱扫描、批量候选导入和高级去重 / 数据清洗工作区。
- 下一步建议：把 `GOAL-2216` 的 StoreKit 生命周期和 ASC 沙盒购买作为提审前 QA 项继续验证。

### ITER-300 v1.6.4 邮箱授权引导第一版
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Email / Pro Automation
- 类型：能力增强 / UI / 文档 / 测试
- 目标：推进 `GOAL-2214` 第一版，把本地邮箱水单导入页从纯配置表单调整为面向公众用户的授权引导和隐私说明入口。
- 改动范围：更新 `HotelFolioEmailImportView`、`HotelEmailAccountSettings.Provider`、四语本地化、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 IMAP 登录 / mailbox 选择 / 候选扫描 / PDF 导入 / 酒店水单解析 / Keychain 写入逻辑；未修改 StoreKit 商品、Pro gate、SQLite / CloudKit schema、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：邮箱水单导入页在账号配置前新增导入说明，明确会优先寻找 Folio、账单、电子账单和酒店品牌线索；新增隐私边界说明，强调授权码只保存在本机 Keychain、完整邮件内容不会上传；新增保存前仍需确认说明；授权指引会随 QQ、网易 163 / 126、Gmail、Outlook / Hotmail、iCloud Mail、Yahoo Mail 和自定义 IMAP provider 切换，提示使用授权码或应用专用密码。
- 未完成内容：真实 provider 连接测试、逐步式授权向导、错误码到操作建议的细分文案和更多邮箱服务商截图说明继续后续收口。
- 测试情况：执行 iOS 27 iPhone 17 Simulator Debug 构建通过；安装并以 `email_folio_import` screenshot mode 启动通过；截图 `/tmp/autoledger-email-folio-guide.png` 检查标题、导入说明、授权指引和配置区无明显遮挡 / 重叠 / 按钮折行；本轮最终统一执行 `git diff --check`、`bash scripts/run_offline_regression.sh` 和 iOS generic build，均通过。
- 风险与注意事项：本轮只改用户引导和 provider 文案，不改变真实邮箱扫描策略；若后续 provider 授权页面或 IMAP 策略变化，需要继续更新文案和错误提示。
- 回滚方式：回退邮箱导入页新增的 `introSection` / `providerGuideSection`、`authorizationGuideKey` 和四语新增文案即可；既有邮箱配置、手动扫描、候选列表和批量导入逻辑不受影响。
- 结论：`GOAL-2214` 邮箱授权引导第一版已完成，可以继续做真实邮箱连接错误分流和分步授权向导。
- 下一步建议：结合真实 QQ / Gmail / Outlook smoke，把 login / select mailbox / MIME parse 等错误转成用户可操作的检查项。

### ITER-299 v1.6.4 StoreKit Pro 本地订阅配置
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / StoreKit QA
- 类型：配置 / 文档 / 测试
- 目标：推进 `GOAL-2216` 第一段，为 `AutoLedger Pro` 补齐本地 StoreKit 订阅配置和审核 / 测试文档口径。
- 改动范围：更新 `AutoLedger/AutoLedgerSupport.storekit`、`docs/operations/iap-support.md`、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 `Support Developer` 赞助商品 ID、Pro 商品 ID、Swift 购买逻辑、SQLite / CloudKit schema、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`AutoLedgerSupport.storekit` 新增 `AutoLedger Pro` subscription group，补齐月付 `top.darkrio326.AutoLedger.pro.monthly`、年付 `top.darkrio326.AutoLedger.pro.yearly`、本地价格 `$2.99` / `$19.99`、`P1M` / `P1Y` 周期和英文 / 简体中文 / 繁体中文 / 日文展示名与说明；`docs/operations/iap-support.md` 从旧的 Support Developer-only 文档更新为 Support Developer consumables + AutoLedger Pro subscriptions 双轨说明，明确 Pro 只 gate 自动化入口，不锁基础记账、历史数据、手动水单、导入导出或编辑删除。
- 未完成内容：订阅生命周期截图、真实 ASC 沙盒购买、隐私政策 URL 最终检查、App Review Notes 最终提交文案和服务端订阅 entitlement 校验继续后续收口。
- 测试情况：执行 `ruby -rjson -e 'JSON.parse(File.read("AutoLedger/AutoLedgerSupport.storekit"))'` 通过；执行 `swift -F /Applications/Xcode-beta.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks -e 'import StoreKitTest; import Foundation; _ = try SKTestSession(contentsOf: URL(fileURLWithPath: "AutoLedger/AutoLedgerSupport.storekit")); print("storekit-session-loaded")'` 通过并输出 `storekit-session-loaded`；执行结构读取确认月付为 `P1M / 2.99 / RecurringSubscription`，年付为 `P1Y / 19.99 / RecurringSubscription`。
- 风险与注意事项：`.storekit` 本地配置不能替代 App Store Connect 真商品和沙盒购买；真实价格、本地化展示和订阅状态仍以 ASC / StoreKit 运行环境为准。仓库中不写 APNs 私钥、StoreKit 私钥或任何真实订阅用户 token。
- 回滚方式：回退 `AutoLedgerSupport.storekit` 中新增的 subscription group，回退 `docs/operations/iap-support.md`、`v1.6.4` 计划、CHANGELOG 和本日志中的 Pro subscription 说明即可；既有 `Support Developer` 消耗型内购和 Pro 页面代码不受影响。
- 结论：`GOAL-2216` 本地 StoreKit 配置第一段已完成，可以继续做订阅生命周期截图和 ASC 沙盒购买 smoke。
- 下一步建议：用 Xcode StoreKit 测试面板模拟购买 / 取消 / 过期 / 恢复，补齐 Review Notes 和隐私政策链接检查。

### ITER-298 v1.6.4 Pro 页面订阅状态与管理入口
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / StoreKit UI
- 类型：能力增强 / UI / 文档 / 测试
- 目标：把 `GOAL-2212 / GOAL-2215` 推进到第一版可运行实现，让 Pro 页面展示订阅状态、恢复购买、管理订阅和到期不锁历史数据的公众文案。
- 改动范围：更新 `ProEntitlementManager`、`AutoLedgerProView` / `SupportAutoLedgerView`、四语本地化、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改 `Support Developer` 赞助内购、StoreKit 商品 ID、SQLite / CloudKit schema、Worker、Cloudflare 配置、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`ProEntitlementManager` 新增 active subscription snapshot、恢复购买 loading、管理订阅 loading 和系统订阅管理入口；Pro 页面新增未订阅 / 已订阅 / DEBUG override 状态卡，展示当前 product、到期时间和最近校验时间；恢复购买与管理订阅使用统一操作区；未订阅和到期文案明确免费基础记账、手动酒店水单导入、历史账本 / 酒店记录和基础导出继续可用，Pro 只暂停新的自动化能力。
- 未完成内容：本地 StoreKit configuration、订阅生命周期截图、审核说明和隐私政策最终材料继续由 `GOAL-2216` 收口；高级去重 / 数据清洗 gate 已由 `ITER-301` 收口。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 iOS 27 iPhone 17 Simulator Debug 构建、安装和 `pro_subscription` screenshot mode 启动通过，截图 `/tmp/autoledger-pro-subscription.png` 与裁图 `/tmp/autoledger-pro-subscription-bottom.png` 检查 Pro 首屏和状态卡无明显遮挡 / 重叠。XcodeBuildMCP UI snapshot 在当前 Xcode beta 上因 `SimulatorKit.framework` 路径缺失不可用，未能用 CLI 滚动截取首屏以下按钮区。
- 风险与注意事项：当前真购买能力依赖 App Store Connect 商品和 StoreKit 运行环境；本轮只把 App 内状态展示、恢复购买和系统管理订阅入口接上。订阅生命周期仍需要 StoreKit 测试面板和 ASC 沙盒购买继续验证。
- 回滚方式：回退 `ProEntitlementManager` 新增订阅状态 / 管理入口、`AutoLedgerProView` 状态卡 / 操作区、四语 Pro 状态文案以及版本计划 / CHANGELOG / 本日志记录即可；既有免费记账、手动水单导入、C1 云候选和本地 IMAP 候选召回不受影响。
- 结论：`GOAL-2212 / GOAL-2215` 第一版工程闭环已完成；Pro 页面已能表达当前状态和免费边界。
- 下一步建议：进入 `GOAL-2216`，补 StoreKit 本地订阅配置、过期 / 恢复 / 管理订阅截图、App Review 说明和隐私政策链接。

### ITER-297 v1.6.4 本地 IMAP 水单候选召回落地
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Email / Pro Automation
- 类型：能力增强 / UI / 测试
- 目标：把 `GOAL-2218` 从规划推进到第一版可运行实现，降低本地 IMAP 扫描把普通附件邮件误判为酒店水单候选的概率。
- 改动范围：更新 `HotelFolioEmailImportPlanning` 候选分层与打分合同；更新 `HotelFolioEmailImportService` 本地 IMAP 候选过滤；更新 `HotelFolioEmailImportView` Pro gate、候选命中原因展示和默认勾选策略；补齐四语文案、screenshot mode 邮箱水单导入场景和离线回归样例；更新 `v1.6.4` 计划、CHANGELOG 和本日志。
- 未改动范围：未修改邮箱授权码 Keychain 保存规则、IMAP 登录 / mailbox 选择底层实现、PDFKit / LLM 酒店水单解析、SQLite / CloudKit schema、StoreKit 商品、Worker、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：本地邮箱候选现在按 `pdfFolioSignal`、`pdfHotelSignal`、`bodySubjectSignal` 分层；候选保留命中原因、关键词、得分和是否默认勾选；Xcode Cloud、TestFlight、Apple Developer、WWDC、航旅凭证、构建通知等明显非水单邮件即使带 PDF 附件也会被排除；真实酒店水单主题 / 附件 / 发件人信号会进入候选；无附件但主题命中水单关键词的正文邮件可进入候选但不默认勾选；非 Pro 用户点击本地邮箱扫描或批量导入时会先看到 `AutoLedger Pro` 说明，手动 PDF 导入仍保持免费。
- 未完成内容：Provider-safe 的两阶段 header fetch / MIME 轻量预筛仍可继续深化；真实 QQ / Gmail / Outlook 邮箱还需要下一版 TestFlight 用高频邮箱做人工 smoke。
- 测试情况：执行 `bash scripts/run_offline_regression.sh` 通过，覆盖普通附件噪音排除、Marriott / Moxy / Na Lotus / Crowne Plaza 等酒店水单召回、正文水单候选和默认勾选策略；执行 iOS 27 iPhone 17 Simulator Debug build + run 通过；新增 `email_folio_import` screenshot scene 并截图检查邮箱导入页 Pro 提示区域，当前 headless 模拟器仍出现系统“在 AutoLedger 中打开？”确认弹窗，页面本体已可见但截图被系统层部分遮挡；执行 `git diff --check` 通过。
- 风险与注意事项：当前第一版优先解决“所有附件都进候选”的误触发问题，真实 provider 的 `SEARCH` 差异和中文主题编码仍需在后续高频邮箱 smoke 中继续收紧；正文候选只进入待确认流程，不会自动入账。
- 回滚方式：可回退 `HotelFolioEmailImportPlanning` 候选合同、`HotelFolioEmailImportService` 过滤接入、邮箱导入 UI Pro gate / 命中原因展示、四语文案和离线回归新增样例。
- 结论：本地 IMAP 水单候选召回已具备第一版工程闭环，普通附件邮件不再默认污染候选列表。
- 下一步建议：用 TestFlight 真实 QQ 邮箱继续验证 6 月 20-23 日酒店水单召回，并根据漏召 / 误召样例微调关键词和 provider-safe 拉取策略。

### ITER-296 v1.6.4 设置页 Pro 入口置顶高亮
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Pro UI / Settings Polish
- 类型：UI / 变更 / 测试
- 目标：把 `AutoLedger Pro` 放在设置页最上方，并用更突出的底色展示。
- 改动范围：更新 `SettingsView`，在页面标题下新增 Pro 高亮渐变卡片，继续跳转现有 `AutoLedgerProView`；从“支持”分组移除重复的 Pro 普通列表入口；更新 CHANGELOG 和本日志。
- 未改动范围：未修改 StoreKit 商品、订阅状态判断、购买 / 恢复购买流程、Pro entitlement、设置页其他入口、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：设置页顶部现在首先展示 `AutoLedger Pro` 卡片，包含皇冠图标、Pro badge、Pro 功能摘要、价格说明和“查看 Pro”按钮；窄屏下价格文案可完整显示，不被 CTA 挤断。
- 未完成内容：未做 iPad / Mac 截图；本轮聚焦 iPhone 设置页首屏。
- 测试情况：执行 iOS 27 iPhone 17 Simulator Debug build + run 通过；使用 screenshot mode 打开 `settings_management` 场景并截图检查顶部 Pro 卡片位置和文字折行；执行 `git diff --check` 通过。截图时模拟器仍残留系统“打开 AutoLedger”确认框，但未遮挡顶部 Pro 卡片。
- 风险与注意事项：Pro 卡片使用设置页现有本地化文案和现有 `AutoLedgerProView`，不会新增订阅逻辑风险；后续如果设置页继续重排，可把该卡片抽成共享组件。
- 回滚方式：删除 `SettingsView.proHighlightCard()` 与标题下的 `NavigationLink`，恢复“支持”分组里的 Pro 普通列表入口即可。
- 结论：`AutoLedger Pro` 已在设置页首屏形成明确的优先入口。
- 下一步建议：后续整体 UI 美化时同步检查 iPad / Mac 设置页宽屏排版。

### ITER-295 v1.6.4 本地 IMAP 水单候选召回规划
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Email / Pro Automation Planning
- 类型：文档 / 规划
- 目标：把本地 IMAP 导入候选过多的问题整理成独立开发 GOAL，明确附件邮件优先、无附件但主题包含水单关键词也应纳入的召回策略。
- 改动范围：更新 `versions/v1.6.4-plan.md`，新增 `GOAL-2218` 本地 IMAP 水单候选召回规则重审；补充候选分层、排除 / 降权规则、命中原因展示、自动回归和人工 smoke 验收；更新 CHANGELOG 和本日志。
- 未改动范围：未修改 App Swift 代码、Worker 代码、IMAP 实现、邮箱授权、PDFKit 流程、酒店水单解析、StoreKit、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：规划要求本地邮箱扫描不再把近期全部附件邮件直接展示为候选；PDF 附件与水单主题优先；无附件但主题包含 `folio`、`账单`、`电子账单`、酒店品牌或酒店名的邮件进入正文水单候选；普通构建通知、TestFlight、Apple Developer、验证码和非水单行程邮件应排除或降权；候选需要展示命中原因并限制默认勾选。
- 未完成内容：本轮不实现召回算法、不改 UI、不新增测试 fixtures、不调整真实 IMAP 拉取行为。
- 测试情况：文档-only 变更；执行 `git diff --check` 作为格式检查。
- 风险与注意事项：后续实现时需兼容不同 IMAP provider 对 `SEARCH`、中文主题、附件标记和 mailbox 选择的差异；正文邮件只能在用户主动选择后继续本地处理，仍不得上传完整邮箱内容。
- 回滚方式：回退 `versions/v1.6.4-plan.md`、`CHANGELOG.md` 和本日志中本次新增的 `GOAL-2218` 记录即可。
- 结论：本地 IMAP 水单候选召回已从临时修补项提升为独立 P0 开发任务。
- 下一步建议：进入实现时先做 fixture 驱动的候选打分器，再接入真实 IMAP header fetch / MIME 拉取路径。

### ITER-294 v1.6.4 酒店列表换行与已处理候选过滤
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Folio / Cloud Inbox Polish
- 类型：Bugfix / UI / Worker / 测试
- 目标：修复酒店消费列表长中文酒店名挤压金额，以及云端水单收件箱刷新仍显示已处理候选的问题。
- 改动范围：更新 `HotelStayArchiveView` 酒店记录行布局；更新 `CloudHotelFolioCandidateStatus` 待导入可见性合同、`HotelFolioInboxClient` 本地过滤、Worker 候选列表查询和 Worker contract tests；更新 CHANGELOG 和本日志。
- 未改动范围：未改变酒店消费数据模型、SQLite / CloudKit schema、StoreKit 商品、邮箱授权、PDF 识别管线、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：酒店名称中汉字数超过 8 个时允许两行展示，金额文本保持更高 layout priority；云端候选列表只返回 / 展示 `stored` 和 `notified`，导入成功后的 `converted`、下载过的 `downloaded`、失败 / 删除 / 过期状态不再显示在“待导入水单”中；生产 Worker 已部署版本 `3f1ff627-f5d0-4df1-bbe9-b612c2573350`。
- 未完成内容：模拟器因本地没有真实酒店消费数据，未能目检长酒店名的真实数据行；已完成 iOS Simulator 构建、安装和截图尝试，最终仍需 TestFlight / 真机带真实酒店数据确认一次视觉效果。
- 测试情况：执行 `bash scripts/run_offline_regression.sh` 通过；执行 `npm run check` 于 `tools/worker/hotel-folio-inbox` 通过，13 个 Vitest contract tests 通过；执行 iOS generic Debug build 通过；执行 iOS 27 Simulator Debug build 通过；执行 `git diff --check` 通过；执行 `npx wrangler deploy --env production --dry-run` 和 `npx wrangler deploy --env production` 通过。
- 风险与注意事项：App 侧也过滤非待处理状态，以兼容旧服务或异常响应；如果未来需要展示“已下载 / 已处理历史”，应单独设计历史列表，不混入待导入列表。
- 回滚方式：可回退酒店行 lineLimit / layout priority、Core 可见性合同、App 过滤和 Worker `listCandidates` 查询；Worker 可回滚到上一版本。
- 结论：长酒店名不会优先挤掉金额，已处理云候选不会在刷新后继续作为待导入项出现。
- 下一步建议：下一版 TestFlight 中用超过 8 个汉字的酒店名称和已导入云候选各做一次真机复核。

### ITER-293 v1.6.4 酒店水单币种归一与正文水单导入
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Folio / Cloud Inbox / Local Email Import
- 类型：能力增强 / Bugfix / Worker / 测试
- 目标：让酒店水单解析后的币种落成现有编辑选择器一致的英文币种代码，并让无 PDF 附件但正文即水单的邮件也能进入既有 PDFKit 复核流程。
- 改动范围：新增 `HotelCurrencyCodeNormalizer` 和 `HotelFolioTextPDFBuilder`；更新 `HotelFolioParsePipeline`、`HotelStayReviewForm`、酒店正式记录编辑、酒店关联账本入账、本地 IMAP 导入、邮件 MIME 正文解析、Worker 云端候选生成、Worker README、离线回归和 Worker contract tests。
- 未改动范围：未让 Worker 识别 PDF、调用 LLM、生成正式账单或自动入账；未改变邮箱授权码本地 Keychain 规则；未修改 SQLite / CloudKit schema、StoreKit 商品、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：酒店水单解析、复核、正式记录编辑和关联普通流水入账会将 `人民币`、`美元`、`日元`、`Australian Dollar`、货币符号等归一为 `CNY`、`USD`、`JPY`、`AUD` 等代码；本地 IMAP 解析邮件正文并在无 PDF 附件时生成 `email-body-folio.pdf` 候选；Worker 对专属收件箱邮件优先使用真实 PDF 附件，无 PDF 时将正文生成短期 PDF 对象并创建云候选；生产 Worker 已部署版本 `cf316422-b71f-4e2b-be5a-5ccc205a6e6c`。
- 未完成内容：TestFlight 端需要下次 App 构建后才能验证本地 IMAP 正文水单和币种 UI；云端正文水单候选已在线上 Worker 生效，但 App 端新币种归一仍需随下一次推送 / TestFlight 发布进入用户设备。
- 测试情况：执行 `bash scripts/run_offline_regression.sh` 通过，覆盖币种归一、正文水单 MIME 解析、正文 PDF 生成和既有酒店 / 同步 / 备份回归；执行 `npm run check` 于 `tools/worker/hotel-folio-inbox` 通过，覆盖 Wrangler types、TypeScript 和 12 个 Vitest contract tests；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 `git diff --check` 通过；执行 `npx wrangler deploy --env production --dry-run` 和 `npx wrangler deploy --env production` 通过。
- 风险与注意事项：正文转 PDF 是为了复用既有 PDFKit / 复核链路，不代表云端会识别或自动入账；专属收件箱如果收到非水单正文也可能生成候选，仍需要用户在 App 中确认或删除。
- 回滚方式：可回退 Worker `candidatePDFInputs` / 正文 PDF 生成、本地 IMAP `hotelFolioCandidateMessage` 正文兜底、币种 normalizer 接入和相关测试；已部署 Worker 可回滚到上一版本，现有 PDF 附件候选链路仍保持可用。
- 结论：酒店水单币种落库口径已和编辑选择器统一，正文型水单邮件已能作为 PDF 候选进入同一复核流程。
- 下一步建议：推送下一版 TestFlight 后，用无附件正文水单、美元 / 日元 / 人民币水单各做一次真机端到端复核。

### ITER-292 v1.6.4 酒店水单收件箱 token 自动领取
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Cloud Inbox / Token Provisioning
- 类型：能力增强 / Worker / UI / 文档
- 目标：让用户在 App 内自动向服务器领取或轮换专属酒店水单收件箱 token，并获得可复制的 `folio+<token>@getautoledger.app` 地址。
- 改动范围：更新 `tools/worker/hotel-folio-inbox` Worker token provisioning API、Swift `HotelFolioInboxClient`、`HotelFolioInboxImportView`、四语本地化、Worker README、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未实现 StoreKit 购买页、恢复购买、服务端订阅 entitlement 校验、token 停用运营面板、APNs secrets 配置、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Worker 新增 `POST /v1/cloud-hotel-folio-token` bootstrap provisioning API，接收 App 本机稳定 client id，生成随机 raw token，写入 `pro_inbox_tokens` 时只保存 SHA-256 token hash 和专属邮箱地址，并将同一 `client:<clientID>` 旧 active token 标记为 rotated；App 新增本机 `hotelFolioInboxClientID`、token claim client、收件箱页面“领取/轮换专属地址”按钮，领取成功后自动保存 token 到 Keychain、展示专属地址、请求通知权限并尝试登记 APNs device token；保留手工 token 输入作为调试兜底。
- 未完成内容：APNs `APNS_KEY_ID`、`APNS_TEAM_ID`、`APNS_PRIVATE_KEY` 仍需用户提供 Apple Developer key 后用 `wrangler secret put` 配置；服务端订阅 entitlement 校验、token 停用 / 到期同步、后台运营面板和 StoreKit Pro 页面继续后续推进。
- 测试情况：执行 `npm run check` 于 `tools/worker/hotel-folio-inbox` 通过，覆盖 Wrangler types、TypeScript 和 9 个 Vitest contract tests；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `curl -X POST https://folio.getautoledger.app/v1/cloud-hotel-folio-token ...` 验证 production token claim 返回 201 与 `folio+...@getautoledger.app` 地址；随后将 smoke token 在 production D1 标记为 `rotated`，未保留可用测试地址；执行 `git diff --check` 通过。
- 风险与注意事项：当前 token claim 是订阅后端接入前的 bootstrap provisioning，App UI 仍由本地 Pro entitlement gate 控制；服务端还未根据 App Store 订阅状态拒绝非订阅用户。真实公开前需要补上服务端 entitlement 校验、token 停用 / 到期同步和运营面板。
- 回滚方式：可回退 Worker token claim 路由、App claim 按钮 / clientID / 本地化和文档记录；已有候选列表、PDF 下载、状态回写和手动 token 输入链路仍可按上一轮部署方式使用。
- 结论：用户已可在 App 内领取或轮换专属酒店水单邮箱地址，真实邮件端到端测试不再需要手动写入 `pro_inbox_tokens`。
- 下一步建议：配置 APNs secrets 后，用 TestFlight 领取地址、向该地址转发真实 / 虚构水单 PDF，验证 Email Routing -> R2 / D1 -> App 手动刷新 / 通知唤醒。

### ITER-291 v1.6.4 酒店水单收件箱 Cloudflare 部署
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Cloud Inbox / Cloudflare Deployment
- 类型：部署 / 配置 / 文档
- 目标：在不影响既有 Cloudflare 资源的前提下，为酒店水单专属收件箱创建并部署独立 R2、D1、Queue、Worker、自定义域和 Email Routing。
- 改动范围：创建 `autoledger-hotel-folio-*` 前缀的 Cloudflare 资源；更新 `tools/worker/hotel-folio-inbox/wrangler.jsonc` 的真实 D1 ID 和 custom domain；更新 Worker README、`versions/v1.6.4-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未修改或删除 `autoledger-models`、`ebc-audio-drops`、`ebc-audio-jobs`、`ebc-audio-jobs-dlq` 等既有资源；未配置 APNs secrets；未插入真实用户 `pro_inbox_tokens`；未修改 App 代码、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：创建 dev / staging / production 三套 R2 bucket、D1 database 和 APNs Queue；对三套远端 D1 执行 `migrations/0001_hotel_folio_inbox.sql`；部署 `autoledger-hotel-folio-inbox`、`autoledger-hotel-folio-inbox-staging`、`autoledger-hotel-folio-inbox-production`；绑定 `https://folio.getautoledger.app` 和 `https://staging-folio.getautoledger.app`；启用并确认 `getautoledger.app` Email Routing ready；创建 `folio@getautoledger.app -> autoledger-hotel-folio-inbox-production` 路由规则，catch-all 保持 disabled / drop。
- 未完成内容：APNs `APNS_KEY_ID`、`APNS_TEAM_ID`、`APNS_PRIVATE_KEY` 仍需用户提供 Apple Developer key 后用 `wrangler secret put` 配置；订阅用户 token 生成 / 轮换 / 停用和 `pro_inbox_tokens` active row provisioning 仍需后续接入。
- 测试情况：执行 production / staging `/health` curl 均返回 `{"ok":true,"service":"autoledger-hotel-folio-inbox"}`；执行 `npm run check` 通过，覆盖 Wrangler types、TypeScript 和 7 个 Vitest contract tests；执行 `wrangler email routing rules list getautoledger.app` 确认规则存在并启用；执行远端 D1 表查询确认 production schema 包含 `pro_inbox_tokens`、`cloud_hotel_folio_candidates`、`apns_devices` 和 `notification_outbox`。
- 风险与注意事项：Cloudflare Email Routing 能把 `folio+token@getautoledger.app` 投递到 Worker，但没有 active token 时 Worker 会拒收；APNs secrets 缺失时通知 outbox 会进入等待配置，App 仍可通过手动刷新候选测试邮件导入。
- 回滚方式：可删除 `folio@getautoledger.app` Email Routing rule、移除 Worker custom domain、删除新建的 `autoledger-hotel-folio-*` R2 / D1 / Queue / Worker 资源，并回退 `wrangler.jsonc` 中的真实 D1 ID / routes。
- 结论：Cloudflare 侧基础设施已部署完成，下一步应配置 APNs secrets，并插入一个测试 inbox token 做真实邮件端到端 smoke。
- 下一步建议：生成 staging / production 测试 token，写入 `pro_inbox_tokens`，向 `folio+<token>@getautoledger.app` 转发虚构水单 PDF，验证 R2 / D1 / App 手动刷新链路。

### ITER-290 v1.6.4 C1 专属收件箱与 Pro gate 主链路
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Hotel Cloud Inbox / Personal Pro Gate
- 类型：能力增强 / Worker / UI / 文档
- 目标：结合 Personal Pro gate，把 `v1.6.3` 顺延的酒店水单 C1 专属收件箱真实 Worker、云候选 API、App 云候选下载和 APNs 唤醒代码主链路补齐。
- 改动范围：新增 `tools/worker/hotel-folio-inbox` Cloudflare Worker；新增 `ProEntitlementManager`、`HotelFolioInboxClient`、`HotelFolioInboxImportView`；调整 AppDelegate / NotificationService / NavigationState / HotelStayWorkspace / HotelStayArchiveView；补齐四语文案；更新 `versions/v1.6.3-plan.md`、`versions/v1.6.4-plan.md`、README、tools README、CHANGELOG 和本日志。
- 未改动范围：未让 Worker 登录用户邮箱；未在 Worker 识别 PDF、调用酒店 LLM、生成正式酒店记录或自动入账；未保存邮箱授权码到云端；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、`MARKETING_VERSION` 或 `Support Developer` 赞助内购。
- 完成内容：Worker 通过 Cloudflare Email Routing 接收 `folio+<token>@getautoledger.app` 邮件，使用 D1 `pro_inbox_tokens` 做服务端 Pro gate，解析 MIME、筛选 PDF 附件、计算 hash、写入 R2、创建 D1 云候选，提供候选列表 / PDF 下载 / 状态回写 / APNs device 登记 API，并通过 Queue consumer 发送只含隐私安全文案和 deep link 的 APNs。App 侧通过 `AutoLedgerCapability.cloudFolioInbox` / `ProEntitlementManager.canUse(_:)` gate 云端酒店水单收件箱入口，支持保存 endpoint / token、展示专属地址、登记 APNs device token、刷新候选、下载 PDF、复用 PDFKit 和现有酒店水单解析复核链路生成 `HotelStayDraft(sourceType: .cloudWorker)`；通知点击复用 deep link handoff 打开酒店消费候选导入页。程序目录、包名、Worker 名、API、变量和表名均使用稳定业务域命名，不使用版本号、`C1` 或 GOAL 号。
- 未完成内容：真实 Cloudflare D1 / R2 / Queue / Email Routing / route / custom domain 绑定、APNs secrets、订阅用户 token 生成 / 轮换 / 到期同步、StoreKit 购买页、恢复购买 UI、订阅状态摘要、审核截图和隐私政策仍属于部署 / 后续收口。
- 测试情况：执行 `npm run check` 于 `tools/worker/hotel-folio-inbox` 通过，覆盖 Wrangler runtime types、TypeScript 和 7 个 Vitest contract tests；执行 `npm audit --omit=dev` 通过，生产依赖 0 vulnerabilities；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `git diff --check` 通过。
- 风险与注意事项：C1 代码主链路已具备可部署形态，但真实线上可用还依赖 Cloudflare 资源 ID、Email Routing rule、APNs key / team / private key、订阅 token provisioning 和 App Store Connect Pro 商品配置。APNs payload 已避免携带酒店名、金额、订单号、附件名和 token hash；云端 PDF 默认短期暂存，App 成功转换后优先删除。
- 回滚方式：可回退新增 Worker 目录、App 云收件箱入口 / client / entitlement manager / APNs token 登记和对应文档；保留 `v1.6.3` 的 App/Core skeleton 时，手动 PDF 导入、酒店消费历史、普通记账和本地邮箱导入不受影响。
- 结论：C1 专属收件箱代码主链路已结合 Pro gate 补齐；下一步应优先做真实 Cloudflare / APNs 部署配置和 StoreKit Pro 页面 / 恢复购买 / 审核材料。
- 下一步建议：建立真实 Cloudflare staging 资源并写入 D1 token fixture，使用测试专属地址转发虚构水单邮件做端到端 smoke；并继续 `GOAL-2212` Pro 页面与恢复购买。

### ITER-289 v1.6.4 GOAL-2200 Free / Pro 边界冻结
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Personal Pro / Access Policy
- 类型：能力增强 / 架构 / 测试
- 目标：完成 `GOAL-2200`，将 Personal Pro 的 Free / Pro 边界从产品规划落到平台无关层合同，并固定“到期不锁历史数据”的第一版回归口径。
- 改动范围：新增 `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/ProAccessPolicy.swift`；更新 `scripts/OfflineRegression.swift` 和 `scripts/run_offline_regression.sh`；更新 `versions/v1.6.4-plan.md`、根 README 四语路线图、`CHANGELOG.md` 和本日志。
- 未改动范围：未实现 StoreKit 订阅商品、购买、恢复购买、交易监听、Pro 页面、UI 付费墙、邮箱扫描实际 gate、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未改动既有 `Support Developer` 赞助内购。
- 完成内容：新增 `AutoLedgerCapability`，覆盖免费基础能力、P0 Pro 自动化能力和后续 Pro 自动化能力；新增 `ProAccessTier` 区分 `freeCore`、`proAutomationP0`、`proAutomationLater`；新增 `AutoLedgerProAccessPolicy.current`，提供 `isAvailableWithoutPro`、`requiresActiveProInCurrentRelease`、`isPlannedProAutomation`、`remainsAvailableAfterProExpiration` 和 `manualFallbacks`。离线回归固定手动记账、单张截图识别、手动酒店水单导入、历史查看编辑删除、基础导出备份和 `Support Developer` 不被 Pro gate；固定本地邮箱水单扫描、批量候选导入、高级去重和 C1 专属收件箱属于 P0 Pro 自动化；固定高级搜索、订阅异常提醒、月结导出包和高级规则自动应用不进入当前 P0 gate。
- 未完成内容：`ProEntitlementManager`、`ProFeature` 实际 gate、StoreKit 商品拉取 / 恢复购买、Pro 页面、邮箱授权引导和 App Review 订阅材料仍按后续 GOAL 推进。
- 测试情况：执行 `bash scripts/run_offline_regression.sh` 通过，新增 ProAccessPolicy 断言随离线回归通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData-v164-goal2200 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：当前策略模型是边界合同，不会自行限制 UI；后续接入 `ProFeature` gate 时必须复用该口径，避免把手动 PDF 导入、历史数据查看编辑、基础导出备份或 `Support Developer` 误放进订阅墙。
- 回滚方式：回退 `ProAccessPolicy.swift`、离线回归接入、`v1.6.4` 计划 / README / CHANGELOG / 本日志即可；无数据迁移、StoreKit 配置或 schema 回滚。
- 结论：`GOAL-2200` 已完成，`v1.6.4` 从规划进入开发中；下一步可进入 `GOAL-2210` 的独立 `ProEntitlementManager` 第一版。
- 下一步建议：先实现 StoreKit 独立订阅管理器和本地测试配置，再把邮箱扫描与批量候选导入接入实际 gate。

### ITER-288 v1.6.3 GOAL-2015 release smoke 与版本完成收口
- 日期：2026-06-29
- 所属版本：v1.6.3
- 所属阶段：Hotel C1 / Privacy Review / Release Smoke
- 类型：文档 / 测试 / 版本收口
- 目标：完成 `GOAL-2015`，把酒店水单 C1 第一版 App/Core 工程骨架的隐私说明、审核材料、回归 baseline 和版本状态收口。
- 改动范围：新增 `versions/v1.6.3-review-notes.md` 和 `versions/v1.6.3-regression-baseline.md`；更新 `versions/v1.6.3-plan.md`、根 README 四语路线图、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 业务逻辑、真实 Worker、对象存储、APNs、云候选 API / UI、订阅后端、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：`v1.6.3` 标记为 Completed；审核说明明确当前版本不是公开 C1 云服务上线，审核员不需要登录真实邮箱或向真实专属地址发送邮件；隐私边界明确 Worker 不登录用户邮箱、不保存邮箱授权码、不扫描私人邮箱，raw token / raw Message-ID / 敏感身份与支付信息不得进入日志；回归 baseline 记录 C1 cloud inbox Core 合同、deep link 和 App 本地转换入口的验证范围。
- 未完成内容：真实 Worker inbound email、对象存储、签名下载 URL、过期删除、APNs、云候选 API / UI、专属收件地址管理 UI、订阅后端和端到端测试专属地址仍留后续版本；当前完成口径是 App/Core 第一版骨架和 release smoke 文档。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_deep_link_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，覆盖 CloudKit sync、CloudKit hotel PDF asset、酒店邮箱导入、App Intents、Widget、可靠性、长列表性能、L10N release smoke 和 C1 cloud inbox 合同；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData-v163-release-smoke CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：`v1.6.3` 不是 C1 公共云服务上线版本；若后续启用 Worker，需要单独验证对象存储权限、日志脱敏、PDF 过期删除、用户删除、APNs 隐私文案、订阅 gating 和测试专属地址。
- 回滚方式：回退新增 v1.6.3 review / regression 文档，以及 `versions/v1.6.3-plan.md`、README 四语路线图、`CHANGELOG.md`、本日志中的状态和记录即可；无代码、schema 或构建配置回滚。
- 结论：`GOAL-2015` 完成，`v1.6.3` 当前规划范围已收口；可以把后续真实云端收件箱实现放到后续版本或专门 Worker 主线。
- 下一步建议：按 `versions/v1.6.4-plan.md` 进入 Personal Pro 基础设施，或另开真实 C1 Worker / cloud candidate API 端到端目标。

### ITER-287 Personal Pro 设计归档与 v1.6.4 规划
- 日期：2026-06-29
- 所属版本：v1.6.4
- 所属阶段：Planning
- 类型：文档 / 产品规划 / 订阅设计
- 目标：分析 Personal Pro 订阅设计文档，将其归档到 `docs/`，并规划 `v1.6.4` 的可执行版本范围。
- 改动范围：新增 `docs/product/autoledger-personal-pro-design.md`；新增 `versions/v1.6.4-plan.md`；更新 `docs/README.md`、根 README 四语路线图、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、StoreKit 商品配置、订阅状态逻辑、邮箱扫描业务逻辑、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：将 Pro 设计结论收敛为“免费版手动完成，Pro 自动整理”的产品边界；明确既有手动记账、截图识别、手动 PDF 导入、历史数据查看编辑、基础导出和备份恢复不应被回收；规划 `v1.6.4` P0 为 `ProEntitlementManager`、`ProFeature` gate、Pro 页面、恢复购买、邮箱自动化 gate、邮箱授权引导、Pro 到期不锁数据和 StoreKit / App Review 验收；将高级搜索、订阅异常、月结导出包和高级规则放入 P1。
- 未完成内容：未实现任何订阅代码；未创建 App Store Connect subscription group / product；未更新隐私政策正文、Review Notes 或 Pro 截图资产；未执行 StoreKit 本地测试。
- 测试情况：执行 `git diff --check` 通过；本轮为文档规划，无 Swift 构建或离线回归需求。
- 风险与注意事项：`v1.6.4` 进入实现时需要非常小心 Pro gate 边界，不能误伤手动 PDF 导入、历史数据访问、基础导出和 Support Developer 赞助线；StoreKit 商品上线前必须补隐私政策、审核说明和本地订阅状态回归。
- 回滚方式：回退新增 `docs/product/autoledger-personal-pro-design.md`、`versions/v1.6.4-plan.md` 以及 `docs/README.md`、`CHANGELOG.md`、本日志的索引和记录即可；无代码或数据迁移回滚。
- 结论：Personal Pro 设计已归档，`v1.6.4` 可作为 Pro 订阅基础设施与邮箱自动化付费边界的下一条规划线。
- 下一步建议：先做 `GOAL-2200` 冻结 Free / Pro gate 清单，再进入 StoreKit configuration 与 `ProEntitlementManager` 实现。

### ITER-286 GOAL-2000 至 GOAL-2014 酒店 C1 第一版工程骨架
- 日期：2026-06-29
- 所属版本：v1.6.3
- 所属阶段：Hotel C1 / Cloud Inbox Skeleton
- 类型：能力增强 / 架构 / 测试
- 目标：处理 `GOAL-2000` 至 `GOAL-2014` 第一版，先冻结 AutoLedger 专属收件箱 C1 合同，并让 App 能把未来云端候选 PDF 接回本地酒店水单识别、复核和入账链路。
- 改动范围：新增 `HotelFolioCloudInboxPlanning.swift` 定义 `HotelCloudFolioInboxAddress`、`CloudHotelFolioCandidate`、候选状态、候选工厂和 cloud candidate -> `HotelStayDraft` 工厂；扩展 `HotelFolioEmailFingerprint` 支持 token hash；新增 App 侧 `HotelFolioCloudCandidatePDFImporter`；扩展 `AutoLedgerDeepLinkParser` / `AutoLedgerNavigationState` 支持 `autoledger://hotel-cloud-candidate/{candidateID}` 与候选队列 deep link；更新 `versions/v1.6.3-plan.md`、`CHANGELOG.md`、离线回归脚本和 deep link smoke。
- 未改动范围：未实现真实 Worker inbound email、对象存储、APNs、订阅后端、云候选列表 UI、手动刷新云候选 API、Worker 状态回写或云端 PDF 清理；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：C1 地址 / token hash / 对象前缀合同已落地；云候选 metadata 覆盖脱敏来源、Message-ID hash、附件 hash、对象 key、PDF 大小、MIME、状态和过期时间；状态 helper 覆盖 downloaded / converted / deleted / failed；App 已具备“已下载 PDF data -> PDFKit 提取文本 -> `HotelStayDraft(sourceType: .cloudWorker)`”服务；新 deep link 可切到酒店消费 tab 并记录待处理候选 ID。
- 未完成内容：C1 还不能接收真实邮件或推送；App 还没有云候选列表 / 下载 UI；确认入账后的 Worker 状态更新和云端 PDF 删除仍待后续 GOAL；隐私审核材料和测试专属地址仍待 `GOAL-2015`。
- 测试情况：先新增失败用例并确认 `bash scripts/run_offline_regression.sh` 因缺少 `HotelCloudFolioInboxAddress`、`CloudHotelFolioCandidateFactory`、`HotelCloudFolioDraftFactory` 失败；新增 deep link smoke 期望并确认 `python3 scripts/check_deep_link_smoke.py` 因缺少 cloud candidate 路由失败。实现后执行 `python3 scripts/check_deep_link_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，覆盖 cloud inbox 地址、hash / 脱敏、候选状态转换和 `.cloudWorker` Draft 生成；执行 `git diff --check` 通过。
- 风险与注意事项：`sourceEmailUID` 暂用 cloud candidate id 字符串承载候选关联，避免本轮引入 SQLite / CloudKit schema 迁移；后续若需要独立 `cloudCandidateID` 字段，应作为 schema 版本升级单独处理。当前 token hash 使用现有稳定非加密 fingerprint，适合去重 / key 隔离，不应作为安全签名；真实 Worker 仍需要服务端级别的 token 校验、订阅校验、rate limit、对象存储权限和日志脱敏。
- 回滚方式：回退新增 cloud inbox Core 文件、App cloud candidate importer、`HotelFolioEmailFingerprint.tokenHash`、deep link 新分支、离线回归 / smoke 脚本和文档记录即可；无数据库、CloudKit 或签名配置迁移。
- 结论：`GOAL-2000` 至 `GOAL-2014` 第一版工程骨架完成，C1 已有可回归的数据合同和 App 接入点；下一步应进入 `GOAL-2015` 隐私 / 审核材料，或继续真实 Worker / 云候选 API 的后续实现。
- 下一步建议：优先补 C1 测试专属地址 / 示例 PDF / 隐私说明，再实现 Worker inbound email 与 App 云候选列表下载闭环。

### ITER-285 GOAL-1960 release smoke 与 v1.6.3 酒店 C 阶段规划
- 日期：2026-06-29
- 所属版本：v1.6.2 / v1.6.3
- 所属阶段：Release Smoke / Hotel C Planning
- 类型：测试 / 文档 / 规划
- 目标：完成 `GOAL-1960` v1.6.2 回归基线与 release smoke 收口，并规划 `v1.6.3` 酒店水单 C 阶段主线。
- 改动范围：`versions/v1.6.2-plan.md` 标记为完成态并更新 `GOAL-1960` 结果；`versions/v1.6.2-regression-baseline.md` 记录本轮自动门禁、Xcode 27 构建结果和人工证据边界；新增 `versions/v1.6.3-plan.md`，将酒店 C 阶段拆为 C1 AutoLedger 专属收件箱自动导入和 C2 Worker 登录用户邮箱实验路线；同步更新 `README.md`、`README.en.md`、`README.zh-Hant.md`、`README.ja.md` 路线图；更新 `CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、Worker 实现、业务逻辑、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：`v1.6.2` 当前规划范围标记为已完成；`GOAL-1960` 自动 release smoke 记录可追溯；`v1.6.3` 计划明确 C1 的公开订阅主线是 `folio+<token>@getautoledger.app` 专属收件箱、Worker 只解析入站邮件和暂存 PDF、App 本地下载后识别并由用户确认入账；C2 Worker 登录用户邮箱自动扫描只保留为个人自用或未来实验能力。
- 未完成内容：Device Hub Resize Mode、iPhone Mirroring 连续拖拽、真实 Widget / App Intents、酒店水单手动 PDF / Share Extension、真实测试邮箱、日文截图 / ASC 文案和平台素材最终目检仍需要人工截图或视频证据；本轮没有也不应在 CLI 中伪造这些结论。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_localization_coverage.py`、`python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_deep_link_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，覆盖 CloudKit sync、CloudKit hotel PDF asset、酒店邮箱导入、App Intents、Widget、可靠性、长列表性能和 L10N release smoke；执行 `bash scripts/run_golden_regression.sh` 通过 38 个 case；确认 `xcodebuild -version` 为 Xcode 27.0 / 27A5194q；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData-release-smoke CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：`v1.6.3` C1 将引入云端 inbound email、对象存储、APNs、订阅 gating 和短期 PDF 暂存，需要在实现前再次确认隐私说明、对象过期、token 轮换、日志脱敏和审核材料；C2 不应混入公开订阅主线。
- 回滚方式：回退本轮文档改动即可；无代码、schema 或构建配置回滚。
- 结论：`GOAL-1960` 工程侧 release smoke 已完成，`v1.6.2` 规划范围收口；可以进入 `v1.6.3` 酒店 C1 专属收件箱主线。
- 下一步建议：从 `GOAL-2000` 开始冻结 C1 / C2 边界，再按 `GOAL-2010` 至 `GOAL-2015` 推进专属收件地址、Worker 入站邮件、APNs、App 云端候选、本地识别和隐私审核材料。

### ITER-284 账本与酒店列表操作模型统一
- 日期：2026-06-29
- 所属版本：v1.6.2
- 所属阶段：SDK UI Polish / Adaptive Layout
- 类型：能力增强 / UI / Bugfix
- 目标：让账本账单数据列表和酒店消费数据列表采用一致的“滑动、长按、详情右上角菜单”操作模型，并把账本详情保存按钮从文字改成对勾。
- 改动范围：`TransactionEditorView` 新增已有账单的右上角操作菜单，保存按钮改为 icon-only 对勾；`LedgerView` 列表新增复制账单，左侧滑动复制、右侧滑动删除，长按菜单与详情菜单共享复制 / 移动 / 删除；`LedgerStore` 新增 `duplicateTransaction`，复制时保留账本归属、不继承酒店关联 ID，并复用正式新增账单保存路径。`HotelStayListView` 补齐酒店记录行的滑动 / 长按删除入口并复用详情删除确认；旧 iPad / Mac 工作台的紧凑账单列表同步接入复制 / 删除入口；四语补齐复制账单文案。
- 未改动范围：未修改 `Transaction` / `HotelStayRecord` 数据模型结构，未改 SQLite / CloudKit schema、酒店识别、邮箱导入、同步 schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：账本列表、账本详情和 iPad / Mac 紧凑账单列表的核心操作入口对齐；酒店消费列表不再只能进详情删除，列表行也能通过滑动或长按进入删除确认；`···` 点击即为系统菜单，不再引入额外展开层。
- 未完成内容：未做真机手势目检；复制账单当前是立即生成一笔同内容账单并选中新账单，不会先弹出二次确认。
- 测试情况：执行 `git diff --check`、`python3 scripts/check_localization_coverage.py`、`python3 scripts/check_adaptive_layout_rules.py`、`bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：复制账单会复用原账单日期、金额、商户、分类、来源和备注，适合复制后再编辑；如果用户希望复制时默认改为当前时间，可在后续单独调整。酒店删除仍需要确认，避免误触删除关联普通流水。
- 回滚方式：回退 `LedgerStore.duplicateTransaction`、`TransactionEditorView` 菜单回调、`LedgerView` / `HotelStayArchiveView` / `iPadWorkspaceView` 的滑动与 context menu、四语复制文案、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：账本账单和酒店消费的主要列表操作模型已统一，宽屏双栏和移动端列表都能通过同类入口完成常用操作。
- 下一步建议：在 TestFlight 真机上检查账本列表左 / 右滑、长按菜单、详情 `···`，以及酒店消费列表滑动 / 长按删除确认。

### ITER-283 宽屏列表选中态增强
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：SDK UI Polish / Adaptive Layout
- 类型：Bugfix / UI
- 目标：修复宽屏 split view 后列表中已选中和未选中数据行视觉区别不明显的问题。
- 改动范围：新增统一 `autoLedgerSelectableRowBackground`，在选中时显示 tint 背景、accent 描边和左侧色条；账本列表、酒店消费列表、订阅列表和 iPad / Mac 紧凑账单列表接入该背景，避免自定义卡片背景盖住系统默认 selection highlight。
- 未改动范围：未修改账单、酒店消费、订阅的数据模型或业务逻辑，未改 SQLite / CloudKit schema、同步、酒店识别、邮箱导入、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：宽屏双栏里当前选中行会比普通卡片行更明确，列表切换选择时能保留既有卡片风格，同时给出足够明显的 selection 状态。
- 未完成内容：本轮未做真机 / 模拟器截图目检；最终视觉仍建议在 iPhone Mirroring 宽窗口、iPad 和 Mac Catalyst 下人工看一遍。
- 测试情况：执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：这是数据列表的选中态增强，sidebar 本身的系统选择样式未纳入本轮；如果后续有更多 `List(selection:)` 使用自绘背景，应继续接入统一 helper。
- 回滚方式：回退 `AppTheme.swift` 中的 selectable row background helper，以及账本、酒店消费、订阅和 iPad 工作台列表的调用即可；无数据迁移或 schema 回滚。
- 结论：宽屏主数据列表的选中 / 未选中状态已统一增强，可继续随 SDK 阶段二界面 polish 做真机目检。
- 下一步建议：在 iPhone Mirroring 从窄拉宽、iPad 横屏和 Mac Catalyst 宽窗口下检查账本、酒店消费和订阅列表的选中态。

### ITER-282 CloudKit 同步清单与按 ID 拉取
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Data Reliability / iCloud Sync
- 类型：Bugfix / 数据同步 / 真机回归
- 目标：修复 iPhone / iPad 两端强制同步均显示成功但数据仍不一致，以及开发环境真机提示 `recordName is not marked queryable` 的问题。
- 改动范围：`LedgerCloudKitSyncAdapter` 的远端拉取从 `CKFetchRecordZoneChangesOperation` / `CKQueryOperation` 切换为“同步清单 + 按 ID 拉取”：推送时在既有 `LedgerConfiguration` record type 下保存固定 `ledger-sync-manifest-default` 清单，记录 `LedgerTransaction`、`LedgerHotelStayRecord` 和 `LedgerHotelStayDraft` 的 CloudKit record name；拉取时先用固定 record ID 读取清单，再通过 `CKFetchRecordsOperation(recordIDs:)` 分批拉取具体记录。`LedgerStore` 的强制同步、启动拉取和增量推送都会更新 / 使用该清单；若同步入口瞬态未持有 `SQLiteTransactionStore`，会重新打开默认 SQLite 账本并刷新内存状态，不再以“iCloud 同步需要 SQLite 账本”作为终态失败。`scripts/check_cloudkit_sync_smoke.py` 改为禁止 query / default zone changes，并要求 manifest + fetch-by-ID 和 SQLite 自愈入口。
- 未改动范围：未新增 CloudKit record type / 字段名，未依赖 `recordName` queryable，未修改 `Transaction`、`HotelStayRecord`、`HotelStayDraft` 数据模型，未改 SQLite schema、邮箱导入、酒店解析、PDF asset fallback、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：强制同步的 pull 阶段不再调用 default zone `getChanges`，也不再按 record type 做 query；普通账单、酒店正式记录和酒店草稿都会从同步清单里的已知 record IDs 拉取，避开 Development Schema / Production Schema 中 `recordName` queryable 配置差异导致的失败。推送会先合并远端已有清单，避免单端增量推送直接覆盖另一端已知记录列表。真机回填确认 iPhone 记录的酒店消费已可在 iPad 展示；重开 App 后同步也可恢复，代码侧同步补上现场重新打开 SQLite 的自愈路径。
- 未完成内容：这是 default zone 下的可靠全量索引方案，不是 server change token 增量；历史云端已有记录如果从未被新 build 写入同步清单，另一台新设备无法自动发现，需要先在数据完整的一端安装新 build 并强制同步一次生成清单。
- 测试情况：先更新 `scripts/check_cloudkit_sync_smoke.py`，观察到 query / zone changes 实现会触发 RED；实现同步清单与 fetch-by-ID 后 `python3 scripts/check_cloudkit_sync_smoke.py` 通过；补充同步清单去重 / 合并离线断言与 SQLite 自愈静态门禁后，执行 `python3 scripts/check_cloudkit_sync_smoke.py`、`bash scripts/run_offline_regression.sh`、`git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：首次使用该版本时，需要先让数据完整的一端完成一次强制同步，使 `ledger-sync-manifest-default` 写入 CloudKit；之后另一端强制同步才能按清单拉取全部账单 / 酒店数据。若某次同步日志出现“重新打开默认本地账本”，说明当次 LedgerStore 未持有 SQLite 实例但已自愈；仍应继续观察是否有重复出现。若未来迁移 custom zone，可重新引入 server change token 增量拉取。
- 回滚方式：回退 `LedgerCloudKitSyncAdapter` 的同步清单 / fetch-by-ID 拉取、`LedgerStore` 的清单推拉接入、`LedgerSyncPlan` 的 `LedgerCloudSyncManifest`、`scripts/check_cloudkit_sync_smoke.py`、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：当前 default zone 同步路径应使用固定同步清单和按 ID 拉取，避免同时踩中 default zone 不支持 `getChanges` 与 `recordName` 未标记 queryable 两类 CloudKit 限制。

### ITER-281 酒店消费 iCloud PDF asset 降级同步
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Data Reliability / iCloud Sync
- 类型：Bugfix / 数据同步 / 测试
- 目标：修复 TestFlight 中 iPhone 与 iPad 酒店消费数据不同步，强制刷新时在酒店消费全量推送阶段出现 `CloudKit rejected record save hotel-stay-*` 的问题。
- 改动范围：`LedgerCloudKitSyncAdapter.pushHotelStayArchive` 在保存酒店记录 / 草稿失败时补充最小保存诊断，并在错误属于 CloudKit schema / asset / quota / limit / partial failure 且记录包含 `sourcePDFAsset` 时，自动移除 PDF asset 字段重试同一批酒店结构化数据；`LedgerCloudKitPushResult` 新增 `assetFallbackRecordNames` 标记本次降级的记录。`LedgerStore` 在发生 asset fallback 时提示用户“结构化酒店数据已先同步、PDF 后续继续重试”，并清空 push checkpoint，避免把 PDF 同步误标记为完成；远端拉取酒店记录 / 草稿时新增 merge helper，远端无 PDF 不覆盖本机已有 PDF。
- 未改动范围：未取消酒店 PDF 同步目标，未修改 `HotelStayRecord` / `HotelStayDraft` 数据模型，未改 SQLite schema、CloudKit record type 名称、邮箱授权、酒店解析管线、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：CloudKit 生产环境即使暂时拒绝某条酒店 PDF asset，也不会阻塞 iPhone / iPad / Mac 同步酒店结构化记录；日志会保留具体 `CKError` 描述、字段摘要和 minimal-save probe，便于继续判断是否是 schema 字段类型、生产传播、单条 asset 或账号配额问题。本机已有酒店 PDF 在下一次拉取无 PDF 云端记录时会被保留。
- 未完成内容：真实 CloudKit 生产环境是否已完全接受 `sourcePDFAsset` 仍需要 TestFlight 真机确认；若日志继续显示 asset fallback，需要检查 Production schema 中 `LedgerHotelStayRecord.sourcePDFAsset` 与 `LedgerHotelStayDraft.sourcePDFAsset` 是否均为 Asset 类型并已部署。
- 测试情况：先更新 `scripts/check_cloudkit_hotel_pdf_asset_smoke.py`，观察到缺少 fallback / PDF 保留 helper 的 RED 失败；实现后执行 `python3 scripts/check_cloudkit_hotel_pdf_asset_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：asset fallback 是兼容降级，不是最终 PDF 同步成功信号；如果 CloudKit 仍拒绝 PDF，结构化数据会先同步，但原始 PDF 仍需等 schema / 字段类型 / 配额问题解除后通过后续全量推送补上。
- 回滚方式：回退 `LedgerCloudKitSyncAdapter` 的酒店归档 fallback、`LedgerStore` 的 asset fallback 日志和 PDF 保留 merge、`scripts/check_cloudkit_hotel_pdf_asset_smoke.py`、`scripts/run_offline_regression.sh`、CHANGELOG 和本日志即可；无数据迁移或 schema 回滚。
- 结论：酒店消费 iCloud 同步不再被 PDF asset 单点阻断，iPhone / iPad 可以先完成结构化酒店数据对齐，PDF asset 继续按后续同步重试。

### ITER-280 酒店邮箱真实扫描与标题体系修复
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Hotel / Email B + SDK UI Polish
- 类型：能力增强 / Bugfix / UI / 测试
- 目标：移除邮箱水单导入页 Demo Mode，修复手动扫描卡在扫描中且无日志的问题，让扫描结果以候选水单勾选后批量导入；同时把首页、月报、设置和邮箱导入页的标题消失 / 遮挡问题按“本地账本”“酒店消费”tab 的系统标题结构统一。
- 改动范围：邮箱导入页删除 Demo 入口并改为候选 PDF 勾选 + 批量导入；IMAP 扫描增加连接、登录、选邮箱、搜索、读取、候选命中、跳过和完成阶段回调，并写入“调试与回归”的酒店邮箱扫描记录；IMAP 连接 / 发送 / 接收加超时保护。首页、月报和设置页移除内容区重复大标题，只保留系统 `navigationTitle`，并改用不透明导航栏背景避免 material 蒙版压住标题；邮箱导入 modal 改为 inline/principal 标题并同样使用 solid navigation chrome；自适应布局静态门禁新增隐藏导航栏、空标题和主 tab 重复 `pageTitle` 检查。版本计划、回归 baseline、日文发布 checklist 和审核说明同步改为无 Demo Mode 口径。
- 未改动范围：未实现邮箱后台自动扫描、Worker 云端代拉、云端保存邮箱授权、自动正式入账、SQLite / CloudKit schema 迁移、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：邮箱扫描不会再依赖 Demo Mode；用户主动扫描后可以看到阶段性状态和调试日志，扫描成功后候选 PDF 默认勾选并支持批量导入为待确认酒店水单草稿。首页 / 月报 / 设置不再同时存在系统标题和内容内大标题，且滚动页标题区不再被 material 蒙版覆盖；邮箱导入页在 sheet presentation 下稳定显示“邮箱水单导入”标题。
- 未完成内容：真实 QQ / Gmail / Outlook 等邮箱端到端扫描、候选邮件勾选批量导入和 iPhone 真机标题目检仍留给 release smoke；本轮没有新增 OAuth 或 provider 专属授权帮助页。
- 测试情况：执行 `git diff --check` 通过；执行 `python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_hotel_email_import_smoke.py`、`python3 scripts/check_l10n_release_smoke.py`、`python3 scripts/check_localization_coverage.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -quiet -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-title-email-fix CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：真实邮箱 IMAP 服务可能因授权码、IMAP 开关、网络代理或 provider 风控失败；当前会进入可恢复错误态并记录扫描阶段。邮箱导入页改为批量导入后，多附件场景不会自动打开每一个复核页，而是把多草稿保存到待确认队列。
- 回滚方式：回退 `HotelFolioEmailImportView`、`HotelFolioEmailImportService`、`HotelFolioEmailImportPlanning`、`ImportDebugRecord`、`HotelFolioDebugTraceBuilder`、`iPadWorkspaceView`、标题相关视图、自适应 / 邮箱 smoke 脚本、本轮版本文档和日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1937` 已完成工程闭环，邮箱 B 阶段公共用户主链路回到真实主动扫描，并完成主 tab 标题体系修复。
- 下一步建议：用真实测试邮箱检查 QQ 授权码、扫描阶段日志、候选 PDF 勾选、批量导入待确认队列；在 iPhone 真机上检查首页、月报、设置、酒店消费、账本和邮箱导入页标题位置。

### ITER-279 酒店保存返回列表与分享扩展间距
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Hotel / UI Polish
- 类型：Bugfix / UI / 测试
- 目标：修正酒店消费详情保存后的返回语义，放宽酒店列表名称展示空间，并收紧 Share Extension 成功状态中对勾图标与文本的间距。
- 改动范围：`HotelStayDetailView` 保存成功后触发列表选择清空并调用 `dismiss()`；`HotelStayRowView` 提高酒店名称布局优先级、收窄图标和标题区间距，并让金额在拥挤空间下适度缩放；`ShareViewController` 将成功状态改为水平 `UIStackView`，成功时显示对勾图标并把图标与文本间距收紧到 6pt；`versions/v1.6.2-plan.md`、CHANGELOG 和本日志同步 `GOAL-1936` 状态。
- 未改动范围：未修改 `HotelStayRecord` / `HotelStayDraft` / `Transaction` 数据模型、SQLite / CloudKit schema、酒店水单解析管线、邮箱后台自动扫描、Worker 云端自动化、Keychain、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：酒店正式记录详情保存后，compact 导航会回到列表，regular 双栏会清掉当前详情选择；酒店消费列表中短酒店名更容易完整显示；Share Extension 保存成功和酒店 PDF 保存成功状态的对勾与文字距离更紧凑。
- 未完成内容：真实设备上从分享面板进入 Share Extension、保存成功后自动唤醒主 App、以及 iPhone / iPad / Mac 不同宽度下酒店列表行的最终目检仍留给 release smoke。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-hotel-save-list CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：保存成功后会立即离开详情页，因此原详情头部的保存成功提示通常不会再被用户停留查看；这是本轮按“保存后回到列表”的交互要求调整。酒店名仍保持单行 tail 省略，极长名称仍需要进详情查看完整内容。
- 回滚方式：回退 `HotelStayArchiveView` 的保存回调和行布局、`ShareViewController` 的成功状态 stack、版本文档 / CHANGELOG / 本日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1936` 已完成工程闭环，酒店消费保存后的导航语义和分享扩展成功态更贴近当前交互预期。
- 下一步建议：release smoke 中重点检查酒店详情保存后列表返回、短酒店名完整显示、长酒店名省略、分享扩展成功态和自动唤醒主 App。

### ITER-278 酒店详情编辑表单 polish
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Hotel / UI Polish
- 类型：能力增强 / UI / 测试
- 目标：优化酒店消费详情编辑页的字段输入方式和保存反馈，并改善酒店消费列表、账本列表中过长文本和图标间距的展示。
- 改动范围：`HotelStayDetailView` 的城市 / 国家字段保留可编辑文本并新增下拉建议菜单；入住 / 退房改为 `DatePicker`，日期变更时自动刷新房晚；币种改为菜单；费用字段和关联账单金额增加数字键盘 hint；关联账单备注改为多行折行输入；保存成功反馈改为更醒目的图标提示，且同 ID 记录刷新不会立即清除提示。酒店消费列表和待确认草稿列表收紧图标与文本间距，长酒店名、地点、品牌 / 集团和来源状态改为 tail 省略；账本列表长商户名改为单行省略。`scripts/check_accessibility_smoke.py` 从旧的 `lineLimit(2)` 门禁更新为 `truncationMode(.tail)` 门禁；`versions/v1.6.2-plan.md`、CHANGELOG 和本日志同步 `GOAL-1935` 状态。
- 未改动范围：未修改 `HotelStayRecord` / `Transaction` 数据模型、SQLite / CloudKit schema、酒店水单解析管线、邮箱后台自动扫描、Worker 云端自动化、Keychain、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：酒店详情编辑页现在使用更贴合字段类型的控件，金额输入在 iOS 上会给出 decimal pad hint；备注可多行输入；保存后的“已保存”反馈会留在详情头部。酒店消费列表和账本列表在长文本场景下优先保持金额 / 日期可见，标题和元信息以省略号收尾。
- 未完成内容：城市 / 国家下拉仍是本地建议列表，不是完整全球地理库；真实设备键盘、长备注输入和不同 Dynamic Type 档位下的最终目检仍留给 release smoke。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：城市 / 国家建议列表只覆盖常见目的地并保留手输兜底，后续如果需要完整选择器，应引入独立地区数据源或系统地区代码映射。长文本改为单行省略后，列表更稳定，但完整内容需要进入详情查看。
- 回滚方式：回退 `HotelStayArchiveView` 表单控件与列表布局、`LedgerView` 列表省略策略、`check_accessibility_smoke.py` smoke 更新和版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1935` 已完成工程闭环，酒店消费详情编辑和列表展示更接近正式可测试状态。
- 下一步建议：真机 smoke 中重点检查酒店详情保存反馈、长备注输入、中文 / 英文酒店名省略、金额数字键盘和大字体下的列表行高度。

### ITER-277 酒店水单分享唤醒与详情编辑
- 日期：2026-06-28
- 所属版本：v1.6.2
- 所属阶段：Hotel / Share Extension
- 类型：能力增强 / Bugfix / 数据
- 目标：修正分享 PDF 给 App 后不会主动唤醒并定位到酒店消费复核的问题，同时让正式酒店消费记录可再次编辑，关联普通账单默认时间为退房日期 16:00 且可编辑。
- 改动范围：Share Extension 在酒店水单 PDF 处理完成后写入待复核 handoff，并调用 `extensionContext.open` 打开 `autoledger://hotel-stays/review?draftID=...`，失败时使用 responder chain fallback；`HotelStayDetailView` 从只读详情改为可编辑表单，右上角对勾保存酒店字段、费用字段和关联普通账单；`LedgerStore` 新增正式酒店记录更新 API，落盘到 SQLite 后刷新内存状态、Widget、自动备份和 CloudKit 待推送；`HotelStayLedgerPostingService` 将酒店关联普通账单默认时间改为退房日 16:00；四语补齐保存提示；`versions/v1.6.2-plan.md`、CHANGELOG 和本日志同步 `GOAL-1934` 状态。
- 未改动范围：未修改 SQLite / CloudKit schema、邮箱后台自动扫描、Worker 云端自动化、酒店解析 schema、Keychain 授权码保存逻辑、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：用户从系统分享面板分享酒店水单 PDF 后，Share Extension 保存草稿并主动唤醒主 App；主 App 消费 handoff 后切到酒店消费 tab 并打开对应待确认草稿。已确认的酒店消费详情可编辑酒店名称、本地化展示字段、入住退房信息、费用拆分、支付方式、关联账单商户、金额、日期、分类和备注；保存后关联账单固定归入内置酒店分类。
- 未完成内容：真实设备从 Mail / Files / Safari 分享 PDF 到 App 的端到端人工截图或录屏仍留给 release smoke；本轮没有新增批量编辑、酒店记录历史版本、云端 Worker 分享链路或自动正式入账。
- 测试情况：执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过，新增断言覆盖退房日 16:00 和酒店记录编辑持久化；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift warning。
- 风险与注意事项：Share Extension 主动打开宿主 App 依赖系统允许 extension 打开自定义 URL；已提供 `extensionContext.open` 和 responder chain fallback，但真实设备上仍需要从多个来源 App 验证。酒店详情编辑会同步更新关联普通账单，用户若手动改账单日期，会以用户编辑值为准。
- 回滚方式：回退 Share Extension 唤醒逻辑、`HotelStayDetailView` 编辑表单、`LedgerStore.updateHotelStayRecord`、`HotelStayLedgerPostingService` 默认时间调整、离线回归新增断言和版本文档 / 日志即可；无 schema 迁移回滚。
- 结论：`GOAL-1934` 已完成工程闭环，酒店水单分享入口可以唤醒复核，正式酒店消费也恢复为可编辑可保存状态。
- 下一步建议：在真机 release smoke 中覆盖 Files / Mail 分享酒店 PDF、App 冷启动唤醒、待确认 sheet 打开、保存后酒店详情和账本普通流水同步更新。

### ITER-276 酒店邮箱常用 provider 默认设置
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Hotel / Email B
- 类型：能力增强 / 本地化 / 治理
- 目标：降低酒店邮箱 B 阶段手动 IMAP 配置成本，为常见邮箱提供默认连接参数，同时保留自定义邮箱入口。
- 改动范围：`HotelEmailAccountSettings.Provider` 从 QQ / 自定义扩展为 QQ、网易 163、网易 126、Gmail、Outlook / Hotmail、iCloud Mail、Yahoo Mail 和自定义；新增统一 `preset(provider:emailAddress:)` 默认参数工厂；邮箱导入配置页 provider Picker 改为遍历 `allCases` 并使用四语本地化名称；离线回归补齐常用 provider host、993 端口、TLS 和自定义空 host 断言；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1933` 状态。
- 未改动范围：未新增邮箱后台自动扫描、Worker 云端代拉、云端邮箱授权保存、Keychain 授权码保存逻辑、邮箱正文上传、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：用户选择常用邮箱 provider 时会自动填充对应 IMAP host、端口 993 和 TLS，并保留已输入邮箱地址；自定义 provider 仍保持手动填写，避免误覆盖私有邮箱服务器配置；四语新增 provider 名称，选择器不会因为新增 provider 漏文案。
- 未完成内容：真实 Gmail / Outlook / iCloud / Yahoo / 网易账号登录 smoke、不同 provider 的授权码引导说明和公共用户帮助文档仍留给后续人工测试或产品说明；本轮没有引入 OAuth 或自动探测 MX / IMAP 能力。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `python3 scripts/check_hotel_email_demo_privacy.py` 通过；执行 `python3 scripts/check_l10n_release_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-email-presets CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，仍保留项目既有 Swift / API deprecated warning。
- 风险与注意事项：常用 provider host 是默认建议值，不保证覆盖所有企业邮箱、自定义域名或地区性账号策略；部分 provider 可能要求应用专用密码、IMAP 开关或额外安全设置，后续应在 UI 文案或帮助文档补充。
- 回滚方式：回退 `HotelFolioEmailImportPlanning.swift` provider / preset 扩展、邮箱导入页 provider Picker、本地化 provider key、离线回归新增断言和版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1933` 已完成工程闭环，酒店邮箱导入的手动配置门槛下降，同时仍保持用户主动扫描、本机 Keychain 授权和待确认入账边界。
- 下一步建议：后续 release smoke 中使用测试邮箱分别验证至少 QQ / 网易 / Gmail 或 Outlook 的真实登录提示和失败态展示。

### ITER-275 Widget 预算占位移除
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Widget / Deep Link
- 类型：Bugfix / 治理
- 目标：移除 iPhone / iOS Widget 中尚未实现的预算剩余占位，避免 App 没有预算功能但 Widget 暗示存在预算设置。
- 改动范围：`AutoLedgerWidgets.swift` 删除 `budgetRemaining`、`monthlyBudgetAmount` 和预算文案，`MonthlyReportWidget` 的第一张小指标改为真实可用的 Top 分类；`scripts/check_widget_smoke.py` 增加预算占位 forbidden snippets；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、`versions/v1.6.2-ja-release-review-checklist.md`、CHANGELOG 和本日志同步 Widget 当前展示口径。
- 未改动范围：未新增预算模型、预算设置 UI、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：Widget 不再读取 App Group `monthlyBudgetAmount`，不再显示“预算剩余 / 未设置 / Budget Left / 予算残高”；本月概览继续展示默认写入账本、本月支出、Top 分类、最近账单、即将续费和 quick-add 链接。
- 未完成内容：真实设备 Widget 添加 / 刷新 / deep link 点击截图、iOS 27 大尺寸 Widget 目检和 release smoke evidence 仍留给后续发布前人工验证。
- 测试情况：执行 `python3 scripts/check_widget_smoke.py` 通过；执行 `python3 scripts/check_l10n_release_smoke.py` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-widget-budget-removal CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：Widget 的即将续费仍按全局订阅展示，因为订阅模型尚无 `ledgerID`；Top 分类来自当前默认写入账本的月度交易聚合，若本月无有效分类会显示 fallback。
- 回滚方式：回退 `AutoLedgerWidgets.swift`、`scripts/check_widget_smoke.py` 和相关版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：Widget 当前展示能力与 App 已实现功能保持一致，不再出现未实现预算功能的 UI 暗示。
- 下一步建议：继续 release smoke 中的真机 Widget 截图、deep link 点击和 iOS 27 大尺寸 Widget 目检。

### ITER-274 日文审校与多语言 golden cases
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：L10N / Recognition
- 类型：本地化 / 测试 / 治理
- 目标：完成 `GOAL-1950`，把日文 Widget / App Intents 文案、多语言识别 golden cases 和发布前日文审校清单固化为可回归工程闭环。
- 改动范围：`AutoLedgerWidgets.swift` 的 Widget 文案从中英二分扩展为中 / 日 / 英 fallback；`AutoLedgerShortcuts` 现有 10 个推荐短语补齐日文表达；golden regression runner 支持 `localeIdentifier`；`tests/golden/ledger_text_interpreter/cases.jsonl` 新增日文小票金额 / 商户 / 餐饮分类 cases；新增 `scripts/check_l10n_release_smoke.py` 并纳入离线回归；新增 `versions/v1.6.2-ja-release-review-checklist.md`；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1950` 状态。
- 未改动范围：未新增远程语言包热更新、社区语言包上传后台、用户纠错共享入口、Widget 写库能力、自动入账、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：Widget 日文环境会显示今日支出、月报、本地账本、默认写入账本、Top 分类、最近账单、即将续费、快速记一笔、分类、来源、待确认和 stale snapshot 等核心文案；Shortcuts 的推荐短语保留 10 个上限并补齐日文；日文小票可通过 `ja-JP` locale hint 进入对应识别语言包；日文发布审校清单覆盖术语表、App Intents、Widget、识别语言包、截图 / ASC / TestFlight、Review Notes 和 Demo Mode。
- 未完成内容：日文母语人工审校、日文截图最终目检、ASC metadata / TestFlight notes 最终提交文案、Xcode 27 Device Hub Resize Mode 和 iPhone Mirroring 录屏证据仍留给 `GOAL-1960` release smoke；本轮不宣称远程语言包分发或社区共享流程已经实现。
- 测试情况：执行 `python3 scripts/check_l10n_release_smoke.py` 通过；执行 `bash scripts/run_golden_regression.sh` 通过，当前 38 个 golden cases 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1950 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过，AppIntents metadata / SSU training 已接受日文推荐短语。
- 风险与注意事项：Widget 文案仍使用轻量 locale fallback，不等同于完整 `.strings` 本地化；日文术语已经有工程清单但仍需人工审校；新增 golden cases 覆盖典型日文小票，不代表所有日本零售 / 餐饮 / 发票格式已经覆盖。
- 回滚方式：回退 Widget 文案 fallback、Shortcuts 日文短语、golden runner locale hint、日文 golden cases、`scripts/check_l10n_release_smoke.py`、离线回归入口、日文审校清单和版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1950` 已完成工程闭环；除按用户要求排除的 `GOAL-1960` release smoke 外，`v1.6.2` 开发型 GOAL 已收口。
- 下一步建议：等待用户确认后再进入 `GOAL-1960`，集中补发布前人工证据、真机 / 可拉伸布局 smoke、Widget / App Intents 真机验证、日文截图 / ASC 文案和平台素材最终目检。

### ITER-273 长列表性能与加载检查
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Reliability
- 类型：性能 / 测试 / 治理
- 目标：完成 `GOAL-1941`，覆盖账本列表、数据清洗预览、酒店消费列表、订阅列表和最近删除列表的滚动与加载 smoke。
- 改动范围：`HotelStayArchiveView` 新增 `recordByID` 字典索引，正式酒店记录列表按 `recordsByID[row.id]` 查找；新增 `scripts/check_long_list_performance_smoke.py`，静态检查账本列表、最近删除、酒店消费、订阅列表和 iPad 数据清洗预览的 `List` / `LazyVStack` 容器、选择状态 reconcile、refreshable、批量删除快照和酒店列表索引；`scripts/run_offline_regression.sh` 纳入长列表 smoke；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1941` 状态。
- 未改动范围：未引入分页 schema、数据库查询分页、异步增量加载、CloudKit 行为变更、业务逻辑改动、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：酒店消费长列表避免在 `ForEach(snapshot.rows)` 中对 `records` 做逐行线性搜索；长列表 smoke 将账本列表、最近删除、酒店消费列表、订阅列表和数据清洗预览的懒加载 / 系统列表容器选择纳入默认离线回归。
- 未完成内容：真实设备滚动 FPS、Instruments traces、海量 SQLite 数据分页和发布前人工录屏证据仍留给 release smoke 或后续性能专项；本轮没有改变任何列表的数据源大小和加载策略。
- 测试情况：执行 `python3 scripts/check_long_list_performance_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1941 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：`recordByID` 每次视图重算会按当前记录数组构建字典，换来列表渲染时 O(1) 查找；如果未来酒店记录规模继续增长，可再把 snapshot 和索引提升到 presenter 或 store 层缓存。
- 回滚方式：回退 `HotelStayArchiveView` 的 `recordByID` 索引、`scripts/check_long_list_performance_smoke.py`、离线回归入口和版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1941` 已完成工程闭环，长列表关键界面的容器与加载检查进入默认离线回归。
- 下一步建议：继续 `GOAL-1950` 日文审校与多语言 golden cases；继续排除 `GOAL-1960`。

### ITER-272 CSV / JSON 与备份恢复 smoke
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Reliability
- 类型：测试 / 治理
- 目标：完成 `GOAL-1940`，把 CSV / JSON 与备份恢复可靠性覆盖固化为可重复执行的回归门禁。
- 改动范围：`scripts/OfflineRegression.swift` 的 `verifyBackupRoundTrip` 增加 active / deleted 交易 sync metadata、删除 tombstone、idempotency key 和订阅 notes metadata 的导出 / 恢复断言；新增 `scripts/check_reliability_smoke.py`，静态检查 CSV、结构化 JSON、BackupBundle、SQLite restore、LedgerStore 备份入口、sync metadata 和 tombstone 覆盖面；`scripts/run_offline_regression.sh` 纳入 reliability smoke；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1940` 状态。
- 未改动范围：未修改 BackupBundle schema、CSV 字段、结构化 JSON schema、SQLite / CloudKit schema、导入导出 UI、iCloud / CloudKit 同步行为、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：备份恢复回归现在明确验证多账本 `ledgerID`、酒店消费 `hotelStayRecordID`、active 交易 sync metadata、deleted 交易 tombstone / sync tombstone、恢复后的 sync revision / idempotency key、订阅、订阅 notes metadata、自定义分类 / 来源、商户别名和分类修正；静态 reliability smoke 防止后续误删这些覆盖点。
- 未完成内容：真实 UI 菜单触发 CSV 导出 / JSON 恢复、文件选择器人工回归、CloudKit 真机同步后备份恢复和 release smoke evidence 仍留给后续发布节点；本轮没有新增新的备份格式能力。
- 测试情况：执行 `python3 scripts/check_reliability_smoke.py` 通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `git diff --check` 通过。
- 风险与注意事项：这是测试覆盖增强，不改变用户可见导入导出行为；`BackupBundle` 当前仍是 schema v1，新增断言依赖既有 SQLite `loadBackupTransactions()` 对 sync metadata 的导出能力。
- 回滚方式：回退 `verifyBackupRoundTrip` 新断言、`scripts/check_reliability_smoke.py`、离线回归入口和版本文档 / 日志即可；无数据迁移或 schema 回滚。
- 结论：`GOAL-1940` 已完成工程闭环，CSV / JSON 与备份恢复关键可靠性覆盖进入默认离线回归。
- 下一步建议：继续 `GOAL-1941` 长列表性能与加载检查，随后推进 `GOAL-1950` 日文审校与多语言 golden cases；继续排除 `GOAL-1960`。

### ITER-271 Widget 第一段
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Widget / Deep Link
- 类型：能力增强 / 系统入口 / 治理
- 目标：完成 `GOAL-1922`，补齐本月支出、Top 分类、最近账单、即将续费和快速记一笔入口，并明确 Widget 的多账本展示口径。
- 改动范围：`AutoLedgerWidgets.swift` 扩展 Widget metrics、默认写入账本 scope、只读交易过滤、Top 分类、最近账单和即将续费订阅；`MonthlyReportWidget` 展示本月概览并支持 medium / large family，`DailyExpenseWidget` 保留今日支出入口；`AutoLedgerNavigationState` 新增 `autoledger://quick-add` deep link；`LedgerStore` 将默认写入账本 ID 同步到 App Group defaults；新增 `scripts/check_widget_smoke.py` 并纳入离线回归；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1922` 状态。
- 未改动范围：未新增正式预算数据模型或预算设置 UI；未让 Widget 直接新增、编辑或删除账单；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：Widget 默认按“默认写入账本”过滤 `transactions.ledger_id`，默认本地账本会兼容旧数据 `ledger_id IS NULL`；本月概览显示账本口径、本月支出、Top 分类、最近账单、未来 14 天内的即将续费订阅和 quick-add 链接；`autoledger://quick-add` 会打开账本 tab 并拉起新增账单 sheet；Widget SQLite 访问保持 `SQLITE_OPEN_READONLY`，静态 smoke 防止写库语句进入扩展。
- 未完成内容：真实设备 Widget 添加 / 刷新 / deep link 点击截图、Widget 日文人工审校和 iOS 27 大尺寸 Widget 视觉证据仍留给后续 `GOAL-1950` / release smoke；预算正式模型不在本版本范围；订阅模型当前没有 ledgerID，Widget 的即将续费仍按全局订阅展示。
- 测试情况：先执行 `python3 scripts/check_widget_smoke.py` 观察到红测，缺少默认写入账本口径、Top 分类、最近账单、即将续费、quick-add route 和 App Group 配置同步；实现后执行 `python3 scripts/check_widget_smoke.py`、`python3 scripts/check_deep_link_smoke.py`、`git diff --check` 均通过；执行 `bash scripts/run_offline_regression.sh` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1922 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：Widget 的订阅数据暂不按账本过滤，因为订阅模型尚无 `ledgerID`；`autoledger://quick-add` 需要真实安装后用 Widget / `simctl openurl` 做人工 evidence。
- 回滚方式：回退 Widget metrics / UI / SQL 过滤、quick-add deep link、默认写入账本 App Group 同步、`scripts/check_widget_smoke.py`、离线回归入口和版本文档 / 日志即可；无 schema 迁移需要回滚。
- 结论：`GOAL-1922` 已完成工程闭环，Widget 第一段具备默认账本口径、只读数据展示和快速入口。
- 下一步建议：继续 `GOAL-1940 / GOAL-1941 / GOAL-1950`，推进可靠性与多语言收口；继续排除 `GOAL-1960`。

### ITER-270 App Intents 第一段
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：App Intents / Deep Link
- 类型：能力增强 / 系统入口 / 治理
- 目标：完成 `GOAL-1921`，在既有快捷记账 intents 之外补齐打开本月统计、打开某一账本、启动收据扫描和酒店待确认入口，并复用 `GOAL-1920` 的统一导航状态。
- 改动范围：新增 `AutoLedgerNavigationIntents.swift`，包含 `LedgerProfileEntity`、`LedgerProfileEntityQuery`、导航 destination / request / handoff、`OpenMonthlyReportIntent`、`OpenLedgerProfileIntent`、`StartReceiptScanIntent` 和 `OpenHotelReviewQueueIntent`；`AutoLedgerApp` 在启动和回到 active 时消费 handoff 并切换 tab / 账本；`AutoLedgerShortcuts` 新增本月统计、指定账本和收据扫描推荐短语；四语本地化新增导航 intent 文案；新增 `scripts/check_app_intents_smoke.py` 并纳入离线回归；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1921` 状态。
- 未改动范围：未实现 Widget、Widget 深层数据展示、自然语言账本问答、自动入账、酒店待确认推荐短语、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：系统 intent 可把用户带回月报、指定账本、收据导入入口或酒店消费待确认上下文；账本参数从本地 SQLite active profiles 提供候选，默认优先本地默认账本；主 App 使用统一 `AutoLedgerNavigationState` 切 tab，指定账本会先切换当前账本；新增静态 smoke 固化 intent 存在、主 App handoff 消费、本地化 key、`AddTransactionIntent` 不强制打开 App，以及 AppShortcut 推荐短语总数不超过 10 个。
- 未完成内容：`GOAL-1922` Widget 第一段仍待后续；酒店待确认入口暂不注册为 AppShortcut 推荐短语，因为真实构建验证到系统 metadata export 最多允许 10 个 AppShortcut；真机 Shortcuts / Spotlight 端到端触发仍保留为 release smoke evidence。
- 测试情况：先执行 `bash scripts/run_offline_regression.sh` 观察到新增红测因缺少 `AutoLedgerNavigationIntents.swift`、handoff 接线和本地化 key 失败；实现后执行 `bash scripts/run_offline_regression.sh` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；首次主 App iOS generic build 失败于 `ExtractAppIntentsMetadata`，报错 `Found 11 App Shortcuts, but each app may have at most 10`，已移除酒店待确认推荐短语并在 smoke 中增加上限检查；重新执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1921 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：AppIntent handoff 使用本地 `UserDefaults` / App Group 双写，若后续调整 App Group identifier 需同步更新；酒店待确认 intent 当前可被 metadata 导出但不是推荐 shortcut，后续若要放入 Shortcuts 推荐列表，需要替换低频旧 shortcut 或合并导航入口；收据扫描第一段只落到主 App 导入入口，不直接启动后台识别或自动入账。
- 回滚方式：回退 `AutoLedgerNavigationIntents.swift`、`AutoLedgerApp` handoff 消费、`AutoLedgerShortcuts` 新推荐短语、四语本地化 key、`scripts/check_app_intents_smoke.py`、离线回归入口和版本文档 / 日志即可；无数据迁移或 schema 变更需要回滚。
- 结论：`GOAL-1921` 已完成工程闭环，Deep link / App Intents 主线具备可编译、可回归的系统入口基线。
- 下一步建议：继续 `GOAL-1922` Widget 第一段，围绕本月支出、Top 分类、最近账单、即将续费和快速记一笔入口做最小可测闭环；继续排除 `GOAL-1960`。

### ITER-269 酒店邮箱 Demo Mode 与审核材料
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Hotel / Email B
- 类型：能力增强 / 隐私治理 / 文档
- 目标：完成 `GOAL-1932`，让酒店邮箱导入主线具备不依赖真实邮箱的 Demo Mode、审核说明和静态隐私门禁。
- 改动范围：`HotelFolioEmailDemoFixture` 新增虚构酒店水单邮件、PDF 附件和文本 fixture；`HotelFolioEmailImportService` 新增 `HotelFolioEmailDemoMode`，在本机生成虚构 PDF 并提供集中开关；`HotelFolioEmailImportView` 新增 Demo section，加载虚构候选邮件并复用既有附件选择和复核链路；四语本地化新增 Demo 文案；新增 `scripts/check_hotel_email_demo_privacy.py` 并纳入离线回归；新增 `versions/v1.6.2-hotel-email-review-notes.md`；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1932` 状态。
- 未改动范围：未实现后台邮箱扫描、Worker 云端自动化、云端邮箱授权保存、自动正式入账、真实邮箱测试账号、CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：审核员可在“酒店消费 -> 右上角 + -> 邮箱水单导入 -> Demo Mode -> 加载示例水单”进入虚构候选邮件，选择 `autoledger-demo-hotel-folio.pdf` 后打开酒店水单复核页；Demo 使用 `example.test` 保留域名、`Demo Bay Hotel`、`DEMO-2026-0618` 和遮蔽卡号，不连接 IMAP、不读取 Keychain；审核说明草稿提供 ASC / TestFlight 可用操作步骤和隐私边界。
- 未完成内容：真实 IMAP 沙盒账号人工测试、真实审核截图 / 录屏和 `GOAL-1960` release smoke 仍待后续节点；Worker 云端自动化继续不作为公共主链路。
- 测试情况：先执行 `bash scripts/run_offline_regression.sh` 观察到新增红测因缺少 `HotelFolioEmailDemoFixture` 编译失败；实现后首次回归发现隐私脚本误把正常 Swift 参数名 `password: credential` 识别为泄露，已收窄为只扫描 Demo fixture / Review Notes；重新执行 `bash scripts/run_offline_regression.sh` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1932 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：Demo Mode 默认通过 `HotelFolioEmailDemoMode.isAvailable` 保留在公共版本，目的是审核和无邮箱演示；Demo 仍会生成本地草稿和可确认入账的示例记录，测试后可按普通酒店记录删除；真实 IMAP 扫描仍需要用户主动点击并提供本机 Keychain 授权码。
- 回滚方式：回退 Demo fixture、Demo PDF 生成、邮箱导入页 Demo section、四语 Demo 文案、静态隐私脚本、审核说明文档和版本文档 / 日志即可；无新增持久化 schema 或 CloudKit schema 需要回滚。
- 结论：`GOAL-1932` 已完成工程闭环，酒店邮箱 B 阶段公共用户测试主线具备草稿队列、去重、拒绝 / 重试基础、Demo Mode 和审核说明。
- 下一步建议：继续 `GOAL-1921 / GOAL-1922`，推进基础 App Intents 与 Widget 第一段；继续排除 `GOAL-1960`，等待 release smoke 节点再处理。

### ITER-268 酒店邮箱水单去重与重试基础
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Hotel / Email B
- 类型：能力增强 / 数据持久化 / 回归
- 目标：完成 `GOAL-1931`，让本地邮箱导入的酒店水单具备稳定去重指纹，并避免 pending、rejected、posted 三类重复水单反复进入待确认队列。
- 改动范围：`HotelStayDraft` 新增本地邮箱 UID、邮件日期、Message-ID hash 和附件 hash 字段；`HotelFolioEmailDraftFactory` 生成稳定指纹；`SQLiteTransactionStore` 扩展 `hotel_stay_drafts` 表、读写和兼容补列；`LedgerStore.saveHotelStayDraft` 增加重复检测，覆盖同一附件 hash、同一 Message-ID hash、同一原始 PDF 数据和已入账酒店记录；四语本地化、离线回归、`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1931` 状态。
- 未改动范围：未实现 Demo Mode、Review Notes、公共版本开关、日志脱敏审计、后台邮箱扫描、Worker 云端自动化或自动正式入账；未修改 CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声；本轮按用户要求不推进 `GOAL-1960`。
- 完成内容：本地邮箱草稿会保存来源 UID、邮件日期、脱敏后的 Message-ID hash 和附件 hash；重复 pending 草稿会被拦截，rejected 草稿在未清理前不会重复打扰，清理 rejected stale draft 后可重新导入，已经确认入账的同一水单不会再次生成待确认草稿；缺授权码、IMAP 错误、连接失败、附件不支持和 PDFKit 空文本继续走现有可恢复错误态。
- 未完成内容：`GOAL-1932` 的虚构邮箱 / 虚构 PDF Demo Mode、审核操作说明、日志脱敏检查和公共版本开关仍待后续 goal；`GOAL-1960` release smoke 暂不执行。
- 测试情况：先执行 `bash scripts/run_offline_regression.sh` 观察到新增红测因缺少邮箱 UID / 日期 / hash 字段编译失败；实现后重新执行 `bash scripts/run_offline_regression.sh` 通过；执行 `python3 scripts/check_localization_coverage.py` 通过；执行 `git diff --check` 通过；执行 `bash scripts/run_golden_regression.sh` 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1931 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：本轮新增的是本地 SQLite 可选列，旧库通过 `ALTER TABLE ... ADD COLUMN` 补列兼容；Message-ID 和附件仅保存稳定 hash，不保存原始 Message-ID；若用户确实需要重新导入已拒绝水单，需要先清理 rejected stale draft；已入账的同一 PDF 会被拦截，避免重复酒店记录和重复普通支出流水。
- 回滚方式：回退 `HotelStayDraft` 新字段、邮箱草稿工厂指纹、SQLite 补列和读写、`LedgerStore` 重复检测、四语 duplicate 文案、离线回归和版本文档 / 日志即可；本地已补的 SQLite 可选列可被旧代码忽略。
- 结论：`GOAL-1931` 已完成工程闭环，酒店邮箱公共用户链路具备待确认队列后的去重、拒绝防打扰和重试基础。
- 下一步建议：继续 `GOAL-1932`，补 Demo Mode、审核材料、日志脱敏检查和公共版本开关；继续排除 `GOAL-1960`，等待 release smoke 节点再处理。

### ITER-267 酒店待确认草稿队列持久化
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Hotel / Email B
- 类型：能力增强 / 数据持久化 / UI 集成
- 目标：完成 `GOAL-1930`，让酒店水单手动 PDF / 本地邮箱导入产生的 `HotelStayDraft` 可跨 App 会话保留，并在酒店消费列表中区分待确认草稿和正式记录。
- 改动范围：`SQLiteTransactionStore` 新增 `hotel_stay_drafts` 表与 `load/save/delete/prune` API；`LedgerStore` 新增 `hotelStayDrafts` 状态、启动 / 刷新加载、保存 / 拒绝 / 删除 / stale 清理方法，并在确认入账成功后移除对应草稿；`HotelStayWorkspaceView` 在导入解析后保存草稿并支持从列表重新打开复核 sheet；`HotelStayListView` 新增待确认草稿 section 和草稿行；四语本地化、离线回归、`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1930` 状态。
- 未改动范围：未实现 Message-ID hash / 附件 hash 去重、拒绝候选后不重复打扰、失败重试策略、Demo Mode、Review Notes、后台邮箱扫描、Worker 云端自动化或自动正式入账；未修改 CloudKit schema、signing、entitlements、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：待确认酒店草稿会完整保留 source type、目标账本、来源文件、原始 PDF、邮件主题 / 发件人、原始文本、结构化 payload、置信度、状态和时间戳；酒店消费列表会展示待确认草稿分区，点击草稿重新进入 `HotelStayReviewView`；确认入账后生成正式 `HotelStayRecord + Transaction` 并清理对应草稿；新增离线回归覆盖 SQLite 跨会话保存、PDF 数据保留、`LedgerStore` 重启加载和确认后删除草稿。
- 未完成内容：`GOAL-1931 / GOAL-1932` 的邮箱去重、拒绝 / 重试闭环、授权失效细化状态、Demo Mode 和审核材料仍待后续 goal。
- 测试情况：先执行 `bash scripts/run_offline_regression.sh` 观察到新红测因缺少 `saveHotelStayDraft`、`hotelStayDrafts`、`loadHotelStayDrafts` API 编译失败；实现后重新执行 `bash scripts/run_offline_regression.sh` 通过；执行主 App `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData-GOAL1930 CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build` 通过。
- 风险与注意事项：`hotel_stay_drafts` 为新增本地 SQLite 表，旧库通过 `CREATE TABLE IF NOT EXISTS` 兼容迁移；当前草稿队列仅本机持久化，不进入 CloudKit / Widget 快照 / 备份导出；拒绝状态已经可保存但“拒绝后去重不再打扰”留给 `GOAL-1931`。
- 回滚方式：回退 `SQLiteTransactionStore` 草稿表和 API、`LedgerStore` 草稿状态与方法、酒店列表草稿 section、工作台保存 / 复核接线、四语文案、离线回归和版本文档 / 日志即可；若本地已生成 `hotel_stay_drafts` 表，旧版本忽略该表即可。
- 结论：`GOAL-1930` 已完成工程闭环，酒店邮箱公共用户链路具备跨会话待确认队列基础。
- 下一步建议：继续 `GOAL-1931`，补邮箱 Message-ID / 附件 hash 去重、拒绝记录和失败重试。

### ITER-266 Deep link Router 基线
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：Deep Link
- 类型：能力增强 / 导航 / 治理
- 目标：完成 `GOAL-1920`，为 Widget 和 App Intents 第一段提供稳定的 `autoledger://` 路由基线。
- 改动范围：`AutoLedgerNavigationState` 新增集中 deep link destination / parser / router；`AutoLedgerApp` 根级 `.onOpenURL` 改为委托导航状态；主 App target 注册 `autoledger` URL scheme；酒店消费列表改为共享选择状态的 `NavigationSplitView` 并支持指定酒店详情；设置页订阅列表改为可路由 destination；Mac Catalyst 工作台响应共享 tab 状态；新增 `scripts/check_deep_link_smoke.py` 并接入离线回归；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1920` 状态。
- 未改动范围：未实现 Widget、App Intents、Shortcuts 参数入口或自然语言问答；未新增自动入账、自动删除或后台同步行为；未修改业务数据模型、SQLite / CloudKit schema、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`。
- 完成内容：`autoledger://ledger`、`autoledger://ledger/today`、`autoledger://transaction/{id}`、`autoledger://hotel-stay/{id}`、`autoledger://subscriptions`、`autoledger://settings/ledger-profiles` 和 `autoledger://scan` 均具备统一解析和状态落点；交易 / 酒店深链会尝试切换到记录所在账本；无效 ID 保留恢复性空状态；`GOAL-1920` 在版本计划中标记为 DONE。
- 未完成内容：带真实记录 ID 的 `xcrun simctl openurl` 端到端截图 / 录屏仍作为 release smoke 人工 evidence；Widget 和 App Intents 使用这些路由的入口留给 `GOAL-1921 / GOAL-1922`。
- 测试情况：执行 `python3 scripts/check_deep_link_smoke.py`、`python3 scripts/check_localization_coverage.py`、`python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_accessibility_smoke.py`、`git diff --check`、主 App `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' ... build`、生成 App 包 `Info.plist` 检查、`bash scripts/run_offline_regression.sh` 和 `bash scripts/run_golden_regression.sh` 均通过。
- 风险与注意事项：URL scheme 属于主 App generated Info.plist build setting，后续若拆分独立 Info.plist 需要同步迁移；静态 smoke 只能防止路由代码和注册项丢失，不能替代真实安装后的 `simctl openurl`。
- 回滚方式：回退 deep link parser / router、URL scheme build setting、酒店列表选择态改造、设置订阅 destination、Mac 工作台 tab 同步、`scripts/check_deep_link_smoke.py` 和版本文档 / 日志即可；无数据迁移需要回滚。
- 结论：`GOAL-1920` 的 deep link Router 工程基线已收口，可供后续 Widget / App Intents 复用。
- 下一步建议：验证通过后进入 `GOAL-1930` 酒店邮箱待确认草稿队列持久化。

### ITER-265 辅助功能与大字体 smoke
- 日期：2026-06-27
- 所属版本：v1.6.2
- 所属阶段：SDK Adaptation / Phase 2
- 类型：测试 / 治理 / 辅助功能
- 目标：完成 `GOAL-1912` 工程侧 smoke，固化 Dynamic Type、VoiceOver、Reduce Motion、深色 / Material 和宽屏文本截断的最小自动门禁。
- 改动范围：新增 `scripts/check_accessibility_smoke.py`；离线回归入口 `scripts/run_offline_regression.sh` 纳入该门禁；`LedgerView` 搜索结果滚动在 Reduce Motion 开启时不再使用动画；`versions/v1.6.2-plan.md`、`versions/v1.6.2-regression-baseline.md`、CHANGELOG 和本日志同步 `GOAL-1912` 状态。
- 未改动范围：未修改业务逻辑、识别链路、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：辅助功能 smoke 脚本检查生产视图不锁 Dynamic Type、主路径 VoiceOver 文案 key、Reduce Motion 入口、列表 / 表单自适应包装、酒店 PDF 可访问标签和关键大字号收缩策略；`GOAL-1912` 在版本计划中标记为 DONE。
- 未完成内容：Xcode 27 Device Hub Resize Mode、macOS 27 iPhone Mirroring 连续拖拽截图或视频、真机 VoiceOver rotor 顺序、大字体极限字号和深色模式视觉目检仍属于 release smoke 人工 evidence。
- 测试情况：执行 `python3 scripts/check_accessibility_smoke.py`、`python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_localization_coverage.py`、`git diff --check`、主 App iOS generic build、`bash scripts/run_offline_regression.sh` 和 `bash scripts/run_golden_regression.sh` 均通过。
- 风险与注意事项：静态 smoke 只能防止工程约束回归，不能替代真实可调整尺寸窗口和辅助功能开关下的视觉 / 读屏体验；发布前仍需补人工 evidence。
- 回滚方式：回退 `scripts/check_accessibility_smoke.py`、`scripts/run_offline_regression.sh`、`LedgerView` Reduce Motion 修正和版本文档 / 日志即可；无数据迁移需要回滚。
- 结论：`GOAL-1912` 的工程侧 smoke 已收口，SDK 阶段二剩余 resize / 辅助功能人工 evidence 归入 release smoke。
- 下一步建议：进入 `GOAL-1920` Deep link Router 基线，为 Widget 和 App Intents 铺路。

### ITER-264 SDK 阶段二主界面 polish
- 日期：2026-06-26
- 所属版本：v1.6.2
- 所属阶段：SDK Adaptation / Phase 2
- 类型：能力增强 / UI polish
- 目标：完成 `GOAL-1910 / GOAL-1911`，在阶段一可拉伸布局基础上继续收口系统导航、toolbar、Material、表单宽度、列表操作和 iOS 27 availability 包装。
- 改动范围：新增共享 SwiftUI chrome modifier；`HomeView` 使用统一 iOS 27 Tab availability 包装；首页、统计、设置、账本、周期账单、酒店消费、交易编辑和邮箱导入配置接入 Material 背景 / 导航栏背景 / 列表或表单宽度约束；账本 toolbar 主操作常驻，语音记账、多账本、最近删除进入 overflow；账本列表新增编辑侧滑和 context menu，并在宽 iPhone / iPhone Mirroring 双栏布局下提高列表列宽；`LedgerView` 在 iPhone / iPad / Mac 账本主线复用，regular 保存后保留右侧详情，compact 保留返回语义；周期账单 toolbar 低频扫描进入 overflow；酒店消费内容区移除重复导入按钮，仅保留右上角 `+`；邮箱保存配置 / 删除授权码按钮改为显式图标并避免换行。
- 未改动范围：未修改业务逻辑、识别链路、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：`GOAL-1910` 和 `GOAL-1911` 在 `versions/v1.6.2-plan.md` 标记为 DONE；主界面 Material / toolbar / 表单宽屏策略集中到共享 modifier；Mac / iPad 工作台账本入口改为复用通用 `LedgerView`；酒店邮箱配置按钮和酒店消费导入入口按本轮反馈调整。
- 未完成内容：Device Hub Resize Mode、iPhone Mirroring 连续 resize、Dynamic Type、VoiceOver、深色模式和大字体截断仍属于 `GOAL-1912` 人工 / 辅助功能 smoke。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_localization_coverage.py`、`git diff --check`、主 App `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' ... build`、`bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh` 均通过。
- 风险与注意事项：`toolbarBackground(.regularMaterial, for: .navigationBar)` 与 iOS 27 Tab modifier 依赖当前 Xcode 27 SDK；若后续 SDK beta 调整命名，应优先修共享包装点。真实连续 resize 和大字体视觉仍需人工验收。
- 回滚方式：回退本轮 UI 文件、四语 `common.more_actions` 文案、`scripts/check_adaptive_layout_rules.py` 和版本文档 / 日志即可；无数据迁移需要回滚。
- 结论：SDK 阶段二主界面 polish 工程侧已收口，可继续进入 `GOAL-1912` 辅助功能 smoke 或 `GOAL-1920` deep link Router。
- 下一步建议：如果继续按最顺主线推进，优先做 `GOAL-1912` 的 Dynamic Type / VoiceOver / 深色模式 / resize evidence；如果转功能能力，则进入 `GOAL-1920`。

### ITER-263 文档目录归档与 README 补齐
- 日期：2026-06-26
- 所属版本：v1.6.2
- 所属阶段：文档 / 仓库结构
- 类型：文档 / 目录整理
- 目标：把根目录散落的设计文档整理回 `docs/`，并为 `docs/`、`ReceiptDebugTool/`、`AutoLedgerCoreKit/`、`tools/` 补齐目录 README。
- 改动范围：移动 6 个根目录设计文档到 `docs/`；更新历史版本计划、CHANGELOG 和迭代日志中的旧文档路径；新增 `docs/README.md`、`ReceiptDebugTool/README.md`、`AutoLedgerCoreKit/README.md`、`tools/README.md`。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：根目录现在只保留入口类 Markdown；产品设计、解析设计、备份、语音、Watch 和 ReceiptDebugTool 草案集中到 `docs/`；四个目录 README 明确目录用途、边界、常用命令、隐私要求和相关文档。
- 测试情况：本轮为文档结构整理，执行 `git diff --check` 作为最小格式门禁，并用 `rg` 检查旧根目录设计文档路径、`docs/docs` 误替换和 README 覆盖情况。
- 风险与注意事项：历史日志中的语义不重写，只修正文件路径；GitHub 旧根路径链接会随本次移动失效，应以后续 `docs/` 路径为准。
- 回滚方式：将 6 个设计文档移回根目录，删除新增 README，回退路径引用、CHANGELOG 和本日志条目即可；无代码或数据迁移需要回滚。
- 结论：文档目录结构已收口，GitHub 上 `docs`、`ReceiptDebugTool`、`AutoLedgerCoreKit` 和 `tools` 均具备入口说明。
- 下一步建议：继续 `v1.6.2` 功能开发主线。

### ITER-262 App Store 1.4.0 发布状态回填
- 日期：2026-06-26
- 所属版本：v1.5.1 / App Store 1.4.0
- 所属阶段：版本收口
- 类型：文档 / 发布状态
- 目标：把对外 App Store `1.4.0` 明确标记为已发布，并保留内部 `v1.5.0` / `v1.5.1` 的版本线关系。
- 改动范围：更新 `README.md`、`README.en.md`、`README.zh-Hant.md`、`README.ja.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：README 路线图已说明 App Store `1.4.0` 已发布；内部 `v1.5.1` 标记为该发布线最终收口版本，内部 `v1.5.0` 标记为并入 `1.4.0` 发布的实现基线；`versions/v1.5.1-plan.md` 文档状态改为 Released，并回填发布状态结论。
- 测试情况：本轮为文档状态更新，执行 `git diff --check` 作为最小格式门禁，并用 `rg` 检查 `1.4.0`、`已发布` / `Released` 和 `v1.5.1` 关键口径。
- 风险与注意事项：这是发布状态回填，不代表重新修改 App Store Connect 版本号、构建号或二进制。
- 回滚方式：回退本轮 README、`versions/v1.5.1-plan.md`、`CHANGELOG.md` 和本日志条目即可；无代码或数据迁移需要回滚。
- 结论：App Store `1.4.0` 已在仓库文档中标记为已发布。
- 下一步建议：继续 `v1.6.2` 开发主线。

### ITER-261 README 多语言与架构整理
- 日期：2026-06-26
- 所属版本：v1.6.2
- 所属阶段：文档 / README
- 类型：文档 / 多语言 / 架构说明
- 目标：让 GitHub README 准确反映当前开发进度、语言覆盖、账单识别语言包和真实工程结构，并补齐繁体中文与日文 README。
- 改动范围：更新 `README.md`、`README.en.md`、`AutoLedger/README.md`、`CHANGELOG.md` 和本日志；新增 `README.zh-Hant.md`、`README.ja.md`。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：根 `README.md` 的 section 标题统一为英文；README 语言入口覆盖简体中文、繁体中文、英文、日文；繁体和日文 README 提供完整功能、语言包、架构、构建与路线图说明；工程架构树更新到当前主 App、AutoLedgerCore、Watch、Widget、Share Extension、tvOS、visionOS、截图 / 图标工具和回归脚本结构；`AutoLedger/README.md` 的标题和系统要求同步更新。
- 测试情况：本轮为文档整理，执行 `git diff --check` 作为最小格式门禁，并用 `rg` 检查 README 语言入口、`zh-Hant` / `ja`、`Localization & Recognition Packs` 和架构树关键字段。
- 风险与注意事项：新增繁体和日文 README 为开发文档翻译，商店 metadata 与正式截图文案仍需人工审校后再提交。
- 回滚方式：删除 `README.zh-Hant.md`、`README.ja.md`，回退 README、`CHANGELOG.md` 和本日志条目即可；无代码或数据迁移需要回滚。
- 结论：README 多语言与架构说明已更新，可作为 GitHub 首页当前状态说明。
- 下一步建议：进入 `v1.6.2` 功能开发，优先从 `GOAL-1910 / GOAL-1911` 或 `GOAL-1930` 开始。

### ITER-260 v1.6.2 进入开发阶段
- 日期：2026-06-26
- 所属版本：v1.6.2
- 所属阶段：GOAL-1900
- 类型：规划 / 文档 / 开发启动
- 目标：根据 `v1.6.0` / `v1.6.1` 已完成的收口结论，将 `v1.6.2` 从 Draft 切入 Active 开发阶段，并回答剩余项目中哪些是测试 / 人工证据、哪些是 `v1.6.2` 开发内容；同时更新 GitHub README，让公开页面反映真实开发进度和路线图。
- 改动范围：更新 `versions/v1.6.2-plan.md`、新增 `versions/v1.6.2-regression-baseline.md`、更新 `README.md`、`README.en.md`、`AutoLedger/README.md`、`tools/appstore-screenshots/README.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：`v1.6.2` 文档状态改为 Active；新增“开发阶段状态”表，将 Device Hub / iPhone Mirroring evidence、visionOS 真机、日文审校归为测试 / 人工证据，将 SDK 阶段二、酒店邮箱草稿队列 / 去重 / Demo Mode、Deep link、Widget、App Intents 和可靠性归为开发内容；新增 `v1.6.2` 固定自动回归和功能专项回归基线；根 README 中英文路线图已更新为 `v1.6.0 / v1.6.1` 完成、`v1.6.2` 开发中，并补充简体中文 / 繁体中文 / 英文 / 日文 UI 覆盖、平台无关账单识别语言包、日文 OCR hint 和社区语言包扩展边界；子 README 同步 iOS 17 最低系统要求和日文截图输出。
- 测试情况：本轮为文档启动，执行 `git diff --check` 作为最小格式门禁。
- 风险与注意事项：`v1.6.2` 后续每个功能 goal 仍需独立回归和提交；如果先做酒店邮箱草稿队列，可能涉及新增持久化表，需要单独设计迁移和回滚。
- 回滚方式：回退 `versions/v1.6.2-plan.md` 的状态与 GOAL-1900 修改，删除 `versions/v1.6.2-regression-baseline.md`，回退 README、`CHANGELOG.md` 和本日志条目即可；无代码或数据迁移需要回滚。
- 结论：`v1.6.2` 已进入开发阶段，可从 `GOAL-1910 / GOAL-1911` 或 `GOAL-1930` 开始实施。
- 下一步建议：优先执行 `GOAL-1910 / GOAL-1911` 完成 SDK 阶段二主界面 polish；若更关心酒店邮箱公共用户测试，则改从 `GOAL-1930` 开始。

### ITER-259 v1.6.0 / v1.6.1 版本收口
- 日期：2026-06-26
- 所属版本：v1.6.0 / v1.6.1
- 所属阶段：版本收口 / 文档
- 类型：规划 / 文档 / 发布收口
- 目标：根据当前 Xcode Cloud、ASC、TestFlight、schema、截图和平台 smoke 状态，将 `v1.6.0` 与 `v1.6.1` 标记为完成，并整理剩余未收口项目，供用户做最终收尾。
- 改动范围：更新 `versions/v1.6.0-plan.md`、`versions/v1.6.0-regression-baseline.md`、`versions/v1.6.1-plan.md`、`CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：`v1.6.0` 文档状态改为 Completed，`GOAL-1770` 改为 DONE，regression baseline 人工发布结论改为 PASS / COMPLETED；`v1.6.1` 文档状态改为 Completed，GOAL 表中阶段一和基础功能改为完成态，阶段二 / Widget / deep link / 数据可靠性等改为 handoff，并新增“收口结论与未收口项目”清单。
- 测试情况：本轮为文档收口，执行 `git diff --check` 作为最小格式门禁。
- 风险与注意事项：剩余尾项主要是人工 evidence 或下一版本能力，不应继续作为 `v1.6.0` / `v1.6.1` blocker；visionOS 真机因无设备仍无法验证，应在未来有设备时补 smoke。
- 回滚方式：回退上述文档中的状态修改、收口清单和本日志 / CHANGELOG 条目即可；无代码或数据迁移需要回滚。
- 结论：`v1.6.0` 和 `v1.6.1` 已完成文档收口；后续收尾集中进入 `v1.6.2`。
- 下一步建议：优先做 `v1.6.2` 的 release smoke baseline、酒店邮箱 Demo Mode / 去重 / 草稿队列，以及 iOS 27 连续 resize evidence。

### ITER-258 GOAL-1900 v1.6.2 版本计划
- 日期：2026-06-26
- 所属版本：v1.6.2
- 所属阶段：GOAL-1900
- 类型：规划 / 文档
- 目标：在 `v1.6.1` 后延项基础上，先规划下一条 `v1.6.2` 开发线，明确当前版本要优先承接哪些主线、哪些只作为后续路线记录。
- 改动范围：新增 `versions/v1.6.2-plan.md`；更新 `CHANGELOG.md` 和本日志。
- 未改动范围：未修改 Swift 代码、业务逻辑、数据模型、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本、截图资产或 `MARKETING_VERSION`；未处理当前工作区中既有的 `AutoLedger/AutoLedger.xcodeproj/project.pbxproj` 排序噪声。
- 完成内容：`v1.6.2` 文档已明确版本定位、P0 / P1 / Later 边界、SDK 适配阶段二、酒店水单 B 阶段收口、Deep link / Widget / App Intents 第一段、数据可靠性、多语言审校、GOAL-1900 至 GOAL-1960 队列、数据迁移边界、测试计划、发布审核材料和非目标。
- 测试情况：本轮为文档规划，执行 `git diff --check` 作为最小格式门禁。
- 风险与注意事项：`v1.6.2` 的 P0 / P1 边界仍需用户确认；Widget 多账本展示口径、酒店草稿持久化 schema、ASC 对外版本号和真实 iOS 27 resize smoke 需要在后续 goal 中继续细化。
- 回滚方式：删除 `versions/v1.6.2-plan.md`，回退 `CHANGELOG.md` 和本日志中的本轮条目即可；无代码或数据迁移需要回滚。
- 结论：`v1.6.2` 第一版版本计划已建立，可作为后续 goal 拆分和实施顺序的起点。
- 下一步建议：先确认 `v1.6.2` P0 范围，再建立 `v1.6.2-regression-baseline.md`，随后从 `GOAL-1910 / GOAL-1911` SDK 适配阶段二开始推进。

### ITER-257 GOAL-1872 新版本 SDK 适配阶段一可拉伸布局
- 日期：2026-06-26
- 所属版本：v1.6.1
- 所属阶段：GOAL-1872
- 类型：UI / 适配 / 测试 / 治理
- 目标：在保持 iOS Deployment Target 17.0、现有业务逻辑和数据模型不变的前提下，用 Xcode 27 / iOS 27 SDK 推进新版本 SDK 适配主线阶段一，让主 App 先具备按当前容器尺寸连续适配的可拉伸布局。
- 改动范围：iOS / iPadOS 根视图统一到 `HomeView`；iOS 27 根 `TabView` 增加 `.sidebarAdaptable` 与 `.defaultTabBarPlacement(.sidebar)` 可用性包装；账本页和周期账单页改为共享选择状态的 `NavigationSplitView`；首页和统计页摘要区改为 adaptive `LazyVGrid`；设置页、交易编辑表单和周期账单编辑表单限制最大宽度；新增根级 `AutoLedgerNavigationState`，统一当前 Tab、账本选择、周期账单选择、设置导航路径和主要 sheet 状态；新增四语空详情文案；新增 `scripts/check_adaptive_layout_rules.py` 并纳入离线回归；更新版本计划、CHANGELOG 和本日志。
- 未改动范围：未修改记账解析、酒店消费、订阅、多账本、同步、备份或持久化业务逻辑；未修改 `Transaction` / `Subscription` 等数据模型；未修改 SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`；未改 Watch / Widget / tvOS / visionOS 现有 UI。
- 完成内容：主 App 不再按 iPhone / iPad idiom 分出两套 iOS 根视图；iOS 27 及以上可在空间足够时进入 sidebar tab 行为，iOS 17-26 继续使用原底部 Tab Bar；账本和周期账单在窄屏折叠、宽屏双栏时共享同一选择状态；首页和统计页可随容器宽度从单列扩展到多列；设置和编辑表单在宽屏下保持合理可读宽度；`AutoLedgerNavigationState` 已由根视图注入并统一持有阶段一要求的导航和 sheet 状态；静态门禁覆盖禁用的 idiom / screen / 方向布局分支和关键自适应结构。
- 未完成内容：Xcode 27 Device Hub Resize Mode 的连续拖拽、macOS 27 iPhone Mirroring 的拉伸状态保持和真实设备视觉验收仍需作为 release smoke 人工执行并保存截图或视频；当前 CLI 只完成 iOS 27 iPhone / iPad 模拟器安装启动截图冒烟。阶段二新版界面交互、阶段三 Widget / deep link、阶段四可靠性工程均已写入版本计划，但顺序后延。
- 测试情况：执行 `python3 scripts/check_adaptive_layout_rules.py`、`python3 scripts/check_localization_coverage.py`、`bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`git diff --check` 均通过；确认 `xcodebuild -version` 为 Xcode 27.0 / 27A5194q；执行主 App iOS generic build、iPad (A16) iOS 27 simulator build 和 Mac Catalyst generic build 均通过；在 iOS 27 iPhone 17 / iPad (A16) 模拟器安装启动并截图确认主界面可见、自适应 tab / grid 入口可用；追加统一 NavigationState 后再次通过自适应静态门禁、本地化覆盖、离线回归、Golden 回归、iOS generic build、iPad (A16) iOS 27 simulator build 和 Mac Catalyst generic build。
- 风险与注意事项：iOS 27 专属 Tab API 目前通过 availability 包装隔离，后续若 Apple 在 SDK beta 中调整 API 名称，需要优先修正包装点；Device Hub / iPhone Mirroring 的连续尺寸变化还需要人工 smoke 来确认文本截断、split view 选择状态和 sidebar 切换体验。
- 回滚方式：回退 `HomeView` Tab availability 包装、`AutoLedgerApp` 根视图调整、`LedgerView` / `SubscriptionListView` split view 改造、编辑表单嵌入参数、首页 / 统计 adaptive grid、设置宽度约束、本地化新增 key、`check_adaptive_layout_rules.py` 和离线回归接入，以及版本计划 / CHANGELOG / 本日志即可；无 schema 或数据迁移需要回滚。
- 结论：新版本 SDK 适配阶段一工程侧已收口，主 App 仍保持 iOS 17 最低系统要求和 iOS 17-26 兼容 fallback；阶段二、三、四不阻塞当前阶段一。
- 下一步建议：在 release smoke 中补 Device Hub Resize Mode、iPad 宽屏和 macOS 27 iPhone Mirroring 的连续拖拽视频 / 截图，并针对发现的文本截断或状态保持问题单独开后续 UI polish goal。

### ITER-256 GOAL-1871 酒店原 PDF 预览与默认写入账本收口
- 日期：2026-06-26
- 所属版本：v1.6.1
- 所属阶段：GOAL-1871
- 类型：能力增强 / UI / 数据 / 测试
- 目标：让酒店消费详情打开后既展示结构化数据，也展示原始酒店水单 PDF；同时把账本 tab 的账本按钮收口为跳转设置，并在多账本管理中提供独立“默认写入账本”选项，默认是“本地账本”。
- 改动范围：`HotelStayDraft` / `HotelStayRecord` 新增原始 PDF 数据字段；手动 PDF 导入和本地邮箱 PDF 附件导入保留源 PDF；确认入账后 `HotelStayRecord` 保存 PDF 数据；SQLite `hotel_stay_records` 新增 `source_pdf_data` BLOB 列和安全迁移；酒店消费详情页新增 PDFKit 预览区；`LedgerStore` 新增默认写入账本偏好；设置页“多账本管理”支持选择默认写入账本；账本 tab 右上角按钮在主 Tab 中跳转设置并打开多账本管理；补齐四语文案、离线回归、版本计划、CHANGELOG 和本日志。
- 未改动范围：不上传原始 PDF；不把原始 PDF 放入 CloudKit / BackupBundle / 外部模型 payload；不实现后台邮箱自动读取、Worker 云端自动同步、邮箱水单去重、跨会话待确认草稿队列或公共版本 Demo Mode；不修改 signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：酒店消费从手动 PDF / 本地邮箱附件导入后会在本机保留原 PDF，用户确认后正式酒店消费详情可展示 PDF 预览和原始识别文本；旧酒店记录没有 PDF 时显示空提示。新账单写入目标从“当前筛选账本”拆为独立默认写入账本，初始为“本地账本”，归档当前默认写入账本时自动回退本地账本。账本 tab 右上角账本按钮不再弹出本页 sheet，而是在主 Tab 中切到设置并打开“多账本管理”。
- 未完成内容：未做真机手动打开酒店 PDF 的视觉验收；未做真实邮箱附件 PDF 重复导入去重；未把原始 PDF 纳入备份 / 同步策略，后续若需要必须重新做隐私与存储评审。
- 测试情况：先新增 PDF 数据保留和默认写入账本离线断言，运行 `bash scripts/run_offline_regression.sh` 观察到缺少 `sourcePDFData` / 默认写入 API 的 RED 编译失败；实现后执行 `bash scripts/run_offline_regression.sh`、`python3 scripts/check_localization_coverage.py`、`bash scripts/run_golden_regression.sh`、`git diff --check`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。Mac Catalyst 仍有既有 MediaPipe xcframework slice warning。
- 风险与注意事项：PDF BLOB 会增加本机 SQLite 体积，当前仅保存用户主动导入或主动选择的酒店水单 PDF；旧记录没有 PDF 不影响详情打开。默认写入账本与当前列表筛选解耦后，用户切换到某个账本查看时，新账单仍会写入“默认写入账本”，这是本轮新增选项的核心行为，需要在后续 UI / 文案中保持一致。
- 回滚方式：回退 `HotelStayDraft` / `HotelStayRecord` PDF 字段、SQLite `source_pdf_data` 列读写、导入器 PDF 数据保留、详情页 PDF 预览、`LedgerStore` 默认写入账本偏好、Settings 路由 / 多账本管理 UI、本地化新增 key、离线回归新增断言以及版本计划 / CHANGELOG / 本日志即可；已迁移数据库中的 `source_pdf_data` 列可保留为空，不影响旧代码读取其他列。
- 结论：酒店消费详情已具备原始 PDF 对照能力，多账本写入目标也从浏览筛选口径中拆出，当前默认写入为“本地账本”。
- 下一步建议：后续优先补酒店水单 Demo Mode / 示例 PDF，以及邮箱候选去重和待确认草稿队列持久化。

### ITER-255 GOAL-1821 / 1822 / 1824 酒店消费本地邮箱导入首版
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1821 / GOAL-1822 / GOAL-1824
- 类型：能力增强 / UI / 隐私 / 测试
- 目标：落地酒店消费 B 阶段第一版本地邮箱手动扫描导入，让用户配置邮箱参数和本机授权码，主动扫描候选水单邮件，并选择 PDF 附件进入现有酒店水单复核入账链路。
- 改动范围：`AutoLedgerCore` 新增邮箱设置、邮件候选、PDF 附件、MIME parser、候选过滤和 `localEmailIMAP` 草稿工厂；App 层新增 IMAP 参数持久化、Keychain 授权码存取 / 删除、PDFKit 附件文本提取、IMAP 扫描客户端和 `HotelFolioEmailImportView`；`HotelStayListView` 增加邮箱导入入口，iPad / Mac 工作台接回已有解析 / 复核链路；补齐四语本地化、离线回归、版本计划、CHANGELOG 和本日志。
- 未改动范围：不做自动持续读取、后台任务、Worker 云端代拉邮箱、云端邮箱授权保存、自动入账、`HotelStayDraft` 跨会话队列、邮箱水单去重、拒绝候选记忆、Demo Mode、公共版本开关、Review Notes 邮箱审核说明、SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION` 修改。
- 完成内容：用户可在酒店消费页打开“扫描邮箱水单”，配置 QQ 邮箱或自定义 IMAP 参数；授权码只写入本机 Keychain；扫描必须由按钮触发；候选邮件显示主题、发件人、日期和 PDF 附件；选择附件后本地 PDFKit 提取文本，生成 `HotelStayDraft(sourceType: .localEmailIMAP, status: .textExtracted)`，随后复用现有外部模型解析、酒店水单复核 sheet 和确认入账路径。
- 未完成内容：真实 IMAP 沙盒账号人工测试、附件级下载优化、Message-ID / 附件 hash 去重、草稿队列持久化、Demo Mode、Review Notes 和日志脱敏专项审计仍留给后续 B 阶段 goal。
- 测试情况：先新增邮箱导入规划离线断言并运行 `bash scripts/run_offline_regression.sh`，观察到缺少新类型的 RED 编译失败；实现后执行 `bash scripts/run_offline_regression.sh`、`python3 scripts/check_localization_coverage.py`、`bash scripts/run_golden_regression.sh`、`git diff --check`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：首版 IMAP 扫描为用户触发的本地一次性读取，仍需要真实 QQ / IMAP 邮箱和虚构酒店水单 PDF 做人工验证；当前没有跨会话草稿队列和去重，重复扫描可能再次看到同一候选邮件；公共版本开放前必须补 Demo Mode 和审核说明。
- 回滚方式：回退新增邮箱导入 Core 服务、App 层 IMAP / Keychain / PDFKit 服务、`HotelFolioEmailImportView`、酒店消费列表邮箱入口、iPad / Mac 工作台接入、本地化新增 key、离线回归新增断言和版本文档 / CHANGELOG / 本日志即可；本轮无 schema 变更。
- 结论：酒店消费 B 阶段已具备第一版手动邮箱扫描导入闭环，但仍严格保持“用户主动触发、结果待确认、确认后才入账”，不进入自动邮箱或云端同步路线。
- 下一步建议：后续 B 阶段优先补 `HotelStayDraft` 待确认队列持久化、邮箱候选去重和 Demo Mode，再考虑公共版本审核材料。

### ITER-254 GOAL-1845 账本 tab 多账本 UI 收口
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1845
- 类型：能力增强 / UI / 多账本 / 测试
- 目标：按当前产品取向收口账本 tab 的多账本入口，用标题显示当前账本名称，并把账本选择和管理集中到右上角弹窗，减少列表区额外控件和行内冗余信息。
- 改动范围：`LedgerStore` 新增 `currentLedgerTitle` 与 `showSelectedLedgerOnly()`；`LedgerView` 移除内容区账本范围菜单、导航标题改为当前账本名、右上角新增账本管理按钮、sheet 接入可选择模式的 `LedgerProfileManagementView`、账单行移除账本归属和备注展示；`LedgerProfileManagementView` 增加可选选择模式和完成按钮；扩展离线回归；更新 `versions/v1.6.1-plan.md`、CHANGELOG 和本日志。
- 未改动范围：未删除 iPad / Mac 工作台中的全部账本聚合口径；未新增批量移动、账本删除、账本 Profile 备份 / CloudKit 同步 payload 或旧交易物理回填；未修改 Watch / Widget / tvOS / visionOS 展示口径；未修改 SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：账本 tab 标题显示当前账本名称，默认仍为“本地账本”；右上角账本按钮打开账本管理弹窗，弹窗中可以选择账本并继续新增、重命名、设默认、归档；账本 tab 进入时恢复当前账本模式，列表只展示当前账本数据；交易行不再额外显示账本归属和备注。
- 未完成内容：账本删除、账本 Profile 跨设备同步、批量移动账本、订阅实体级 `ledgerID` 和桌面端单笔移动入口仍作为后续独立事项。
- 测试情况：先新增 `currentLedgerTitle` / `showSelectedLedgerOnly()` 离线断言并运行 `bash scripts/run_offline_regression.sh`，观察到缺少对应 API 的 RED 编译失败；实现后执行 `bash scripts/run_offline_regression.sh`、`python3 scripts/check_localization_coverage.py`、`bash scripts/run_golden_regression.sh`、`git diff --check`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过；Mac Catalyst 仍有既有 MediaPipe xcframework slice warning。
- 风险与注意事项：iPhone 账本 tab 现在会从历史保存的“全部账本”状态恢复到当前账本口径；iPad / Mac 工作台仍保留全部账本切换，因此同一个用户在不同入口可能有不同的账本范围控制方式，这是本轮按产品要求刻意收口的结果。
- 回滚方式：回退 `LedgerStore` 新增标题 / 当前账本恢复 API、`LedgerView` 标题与 toolbar / sheet / 行展示改动、`LedgerProfileManagementView` 选择模式、离线回归新增断言以及版本计划 / CHANGELOG / 本日志条目即可；本轮无 schema 变更。
- 结论：账本 tab 多账本入口已从“列表区范围菜单”收口为“标题 + 右上管理弹窗”，当前账本数据浏览路径更干净。
- 下一步建议：如后续继续多账本，优先补账本 Profile 备份 / CloudKit 同步和桌面端单笔移动账本入口，而不是再往 iPhone 账本 tab 增加更多筛选控件。

### ITER-253 GOAL-1820 酒店消费 B 阶段规划
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1820
- 类型：文档 / 产品规划 / 隐私设计
- 目标：把酒店消费 B 阶段从路线记录扩展为可执行的本地邮箱半自动导入主线规划，为后续公共用户能力拆分实现 goal。
- 改动范围：更新 `versions/v1.6.1-plan.md` 的 B 阶段用户流程、模块边界、邮箱来源 metadata、去重策略、错误降级、隐私原则、审核说明、Demo Mode、前置条件和 B 阶段回归验收点；将 B 阶段拆为 `GOAL-1821` 至 `GOAL-1825`；回填 CHANGELOG 和本日志。
- 未改动范围：未实现 IMAP 客户端、Keychain 凭据读写、邮箱设置 UI、连接测试、PDF 附件下载、邮箱扫描任务、`HotelStayDraft` 跨会话持久化、待确认草稿队列、邮箱来源模型解析、后台自动扫描、Worker 代拉邮箱或自动入账；未修改 SQLite / CloudKit schema、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：B 阶段被定义为用户主动触发的一次性本地扫描；授权码只保存在本机 Keychain；App 本地连接 QQ 邮箱 / 通用 IMAP；只下载候选 PDF；PDFKit 本地提取文本；脱敏后复用现有解析管线；所有结果进入待确认，用户确认后才写入 `HotelStayRecord + Transaction`。
- 未完成内容：B 阶段所有代码实现和真实邮箱测试留给后续 `GOAL-1821` 起的实现轮次。
- 测试情况：本轮只更新文档；执行 `git diff --check` 通过。
- 风险与注意事项：B 阶段涉及邮箱授权、IMAP 风控和隐私审核，后续实现必须先完成 Keychain / 日志脱敏 / Demo Mode / 草稿持久化，不应直接从 IMAP 扫描结果自动入账。
- 回滚方式：回退 `versions/v1.6.1-plan.md` 中 B 阶段扩展规划、GOAL 表拆分、回归验收点，以及 CHANGELOG / 本日志条目即可；本轮无代码和 schema 变更。
- 结论：酒店消费 B 阶段已经具备可拆解的实施路线，但仍明确不属于当前 `v1.6.1` 实现范围。
- 下一步建议：进入 `GOAL-1821` 前，先决定是否把 `HotelStayDraft` 持久化队列作为 B 阶段前置 blocker 单独拆出。

### ITER-252 GOAL-1817 酒店消费删除闭环
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1817
- 类型：能力增强 / 酒店消费 / 持久化 / UI
- 目标：补齐正式酒店消费的用户可见删除闭环，删除酒店消费时同步处理关联普通支出流水，避免列表和账本状态不一致。
- 改动范围：`SQLiteTransactionStore.deleteHotelStayRecord(id:)` 改为事务化删除并软删除关联普通流水；`LedgerStore` 新增 `deleteHotelStayRecord(_:)` 并同步内存状态、最近删除、Widget、自动备份和 CloudKit push 调度；酒店消费详情页新增删除按钮和确认弹窗；iPad / Mac 酒店消费工作台传入删除回调；主 App 四语删除文案补齐；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未持久化 `HotelStayDraft` 草稿队列；未实现草稿删除列表；未实现酒店消费详情跳转普通账单详情 / 编辑页；未新增 `HotelStayRecord` 备份 / CloudKit 同步 payload；未新增邮箱 / Worker 自动化；未修改 signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：SQLite 删除酒店消费时会先读取 `linked_transaction_id`，同一事务内把关联普通支出流水软删除为 tombstone，再删除正式酒店消费记录；`LedgerStore` 删除成功后从 `hotelStayRecords` 和 active `transactions` 移除相关对象，并把关联普通流水放入 `deletedTransactions`；详情页删除需二次确认，成功后返回列表并展示状态消息。
- 未完成内容：酒店消费详情到普通账单详情的导航、酒店草稿队列持久化 / 删除、酒店记录备份 / CloudKit 同步留给后续 goal。
- 测试情况：先新增 SQLite 删除关联流水回归并运行 `bash scripts/run_offline_regression.sh`，观察到“关联普通流水仍在 active ledger、没有 tombstone”的 RED 失败；实现 SQLite 事务化删除后同一回归通过。随后新增 `LedgerStore.deleteHotelStayRecord(_:)` 行为回归，观察到方法缺失的 RED 编译失败；实现状态层和 UI 回调后执行 `bash scripts/run_offline_regression.sh` 通过。执行 `bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 均通过；首次并行运行 Mac Catalyst build 时命中 DerivedData `build.db` locked，待 iOS build 结束后单独执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 通过。
- 风险与注意事项：当前删除酒店消费会把确认时自动生成 / 关联的普通支出移入最近删除；如果未来支持一个酒店消费关联多条普通流水，需要扩展关联模型和删除确认文案。当前 `HotelStayRecord` 本身仍未进入备份 / CloudKit payload，跨设备酒店归档同步仍未完成。
- 回滚方式：回退 `SQLiteTransactionStore.deleteHotelStayRecord(id:)` 的事务化删除、移除 `LedgerStore.deleteHotelStayRecord(_:)`、撤销酒店详情删除按钮 / 工作台回调 / 四语文案，并删除离线回归新增断言与版本文档记录即可；本轮无 schema 迁移。
- 结论：酒店消费 A 阶段已具备用户可见的正式记录删除闭环，删除后普通账本不会残留孤立酒店支出。
- 下一步建议：继续补酒店消费详情到普通账单详情 / 编辑页跳转，或推进 `HotelStayRecord` 备份 / CloudKit 同步 payload。

### ITER-251 GOAL-1863 日期格式候选解析
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1863
- 类型：能力增强 / 识别链路 / 本地化
- 目标：让语言包中的 `dateFormats` 成为平台无关层可消费的日期候选解析能力，同时不直接改变普通记账正式入账日期。
- 改动范围：新增 `LedgerDateCandidateExtractor`、`LedgerDateCandidate` 和 `LedgerDateCandidateConfidence`；离线回归新增日文 / 英文日期候选解析与主解释链路不自动套用候选日期断言；`run_offline_regression.sh`、`run_golden_regression.sh`、`run_receipt_batch_regression.sh` 手动 swiftc 文件清单加入新 Core 服务；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未修改 `LedgerTextInterpreterCore` 的 `TransactionDraft.occurredAt` 决策；未把日期候选写入 SQLite / CloudKit / Backup；未新增日期冲突复核 UI、用户账单语言选择 UI、用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`LedgerDateCandidateExtractor` 可按 locale 读取语言包 `dateFormats`，从文本行中提取日期候选；命中 `dateLabels` 的日期行标记为高置信，否则为中置信；候选记录包含标准化 `Date`、原始文本、命中 pattern、标签、置信度和行号；日文 `取引日時: 2026年6月25日` 和英文 `Invoice Date: 06/25/2026` 已纳入离线回归。
- 未完成内容：正式账单日期策略、候选日期冲突复核 UI、外部辅助识别 prompt 携带日期候选、用户本地纠错覆盖包和社区语言包导入 / 导出留给后续 goal。
- 测试情况：先新增日期候选回归并运行 `bash scripts/run_offline_regression.sh`，观察到 `LedgerDateCandidateExtractor` 缺失的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。仓库内当前没有正式 OCR JSONL fixture，因此未跑完整批量 fixture 回归；已用 `/tmp` 临时 OCR JSONL 运行 `bash scripts/run_receipt_batch_regression.sh <ocr.jsonl> <output.jsonl>` 完成最小编译和执行烟测。
- 风险与注意事项：日期格式候选能力进入 Core 后，未来若直接接管 `occurredAt` 需要处理地区歧义，例如 `06/07/2026` 在 `MM/dd/yyyy` 与 `dd/MM/yyyy` 间的冲突；当前只产出候选，避免低置信误入账。
- 回滚方式：删除 `LedgerDateCandidateExtractor.swift`，移除三个回归脚本的文件清单新增项和离线日期候选断言，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：语言包的日期配置已经具备可测试的消费点，后续可以在复核页或外部辅助 prompt 中展示日期候选，而不是直接修改正式账本日期。
- 下一步建议：接入外部辅助识别 prompt 或候选复核 UI，先展示日期候选和冲突提示，再评估是否在高置信单候选时自动填入草稿日期。

### ITER-250 GOAL-1862 App OCR 语言 hint 接入
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1862
- 类型：能力增强 / 识别链路 / 本地化
- 目标：让主 App OCR 服务实际消费语言包中的 `ocrRecognitionLanguages`，使日文账单 OCR 可优先使用 `ja-JP + en-US`，同时保持无匹配语言包时的旧默认行为。
- 改动范围：`LedgerRecognitionLanguagePack` 文件中新增 `LedgerOCRLanguageHintResolver`；`OCRService` 初始化和 Vision `recognitionLanguages` 接入 resolver；离线回归新增日文 OCR hint 与未知 locale 默认 hint 断言；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未修改 `ReceiptParser` 的滴滴车费局部 OCR 专用请求；未新增日期解析器或正式入账日期策略；未新增用户语言选择 UI；未实现用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增平台无关 `LedgerOCRLanguageHintResolver`，按 locale 匹配主语言包并返回去重后的 OCR language hints；日文 locale 返回 `["ja-JP", "en-US"]`，未知 locale 返回旧默认 `["zh-Hans", "en-US"]`；`OCRService` 默认读取 `Locale.autoupdatingCurrent` 对应 resolver 结果，也支持通过初始化参数显式注入 `recognitionLanguages`。
- 未完成内容：日期格式 `dateFormats` 的正式 parser 消费、用户手动选择账单语言、用户本地纠错覆盖包和社区语言包导入 / 导出留给后续 goal。
- 测试情况：先新增 `LedgerOCRLanguageHintResolver` 回归并运行 `bash scripts/run_offline_regression.sh`，观察到 resolver 缺失的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：Vision OCR 语言提示会影响真实截图识别结果；本轮只对当前 locale 已有语言包启用 hint，并为未知 locale 保留旧默认，降低公共主链路突变风险。日文真实截图仍需要 TestFlight / 真机样例补充人工回归。
- 回滚方式：恢复 `OCRService` 硬编码 `["zh-Hans", "en-US"]`，移除 `LedgerOCRLanguageHintResolver` 和对应离线回归，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：语言包的 OCR hint 已从 schema 进入 App 主 OCR 链路，后续新增语言包时可通过数据配置影响 OCR 基础识别，不需要改 Vision 调用代码。
- 下一步建议：继续以独立 goal 接入 `dateFormats` 的平台无关日期解析，优先只产出候选日期和置信提示，不直接改变低置信账单的正式入账。

### ITER-249 GOAL-1861 语言包高级配置 schema
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1861
- 类型：能力增强 / 识别链路 / 本地化
- 目标：把金额格式、日期格式、金额标签分层、非商户排除词增强和 OCR 语言 hint 纳入语言包 schema，并让金额提取器先消费金额格式配置。
- 改动范围：`LedgerRecognitionLanguagePack` schema、内置中 / 英 / 日语言包数据、`LedgerRecognitionLanguagePackSet` 合并逻辑、`PaymentAmountExtractor` 金额格式与分层标签消费、离线回归、版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未修改 App 层 `OCRService` 的 Vision `recognitionLanguages`；未新增独立日期解析器或正式入账日期策略；未实现用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增 `LedgerAmountFormat`、`LedgerAmountLabelSet`、`LedgerDateFormat` 和 `ocrRecognitionLanguages`；内置语言包 schema version 升级为 2；日文包暴露 `¥` 金额格式、`yyyy/MM/dd` 等日期格式和 `["ja-JP", "en-US"]` OCR hint；非商户排除词覆盖发票号、终端号、房号、收银员、税号和会员号；`PaymentAmountExtractor` 可按语言包解析 `€1.234,56` 并区分押金 / 退款 / 找零等非入账角色。
- 未完成内容：App OCR 按语言包 hint 调整 Vision request、日期解析器消费 `dateFormats`、用户本地纠错覆盖包和社区语言包导入 / 导出留给后续 goal。
- 测试情况：先新增高级配置和欧洲金额格式回归并运行 `bash scripts/run_offline_regression.sh`，观察到 `LedgerAmountFormat` / `LedgerAmountLabelSet` / `dateFormats` / `ocrRecognitionLanguages` 缺失的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：金额格式配置开始影响解析器行为，后续新增地区包时必须配套金额格式 golden case，避免千分位和小数位互换造成金额放大或缩小；OCR hint 目前只暴露在 Core，不会改变现有 OCR 行为。
- 回滚方式：恢复语言包 schema version 1 和旧字段集合，恢复 `PaymentAmountExtractor` 的旧金额正则 / normalize / 标签判断，移除新增高级配置回归，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：语言包已经具备继续扩语言的核心配置面，后续新增语言优先补数据和回归，不需要改主解析架构；App OCR hint 和日期解析可作为独立小步消费这些配置。
- 下一步建议：接入 App 层 `OCRService` 的 `recognitionLanguages`，让当前 locale 或用户选择语言包驱动 Vision OCR hint，但保持默认 fallback 到 `zh-Hans + en-US`。

### ITER-248 GOAL-1859 分类 resolver 语言包接入
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1859
- 类型：能力增强 / 识别链路 / 本地化
- 目标：继续落地多语言账单识别语言包，将 `CategoryResolver` 从静态分类关键词推进到 locale-aware `categoryKeywordMap`，并优先补日文餐饮 / 日用品分类样例。
- 改动范围：`CategoryResolver` locale / language pack 注入、分类关键词读取 `LedgerRecognitionLanguagePack.categoryKeywordMap`；`LedgerTextInterpreterCore` 将 `InterpretInput.localeIdentifier` 传给分类 resolver；离线回归新增日文分类样例；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未修改 `TransactionCategory` 枚举、分类 UI 文案、用户自定义分类体系；未实现用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`CategoryResolver` 新增 `localeIdentifier` 与 `languagePackSet` 初始化参数，并保持无参数调用兼容；语言包分类关键词命中时输出 `language_pack_keyword` debug trace，再回落既有静态商户关键词和 `TransactionCategory.infer`；日文 `東京カフェ` 可推断为 `dining`，`駅前コンビニ` 可推断为 `groceries`，完整日文小票可在 Core 主链路生成餐饮分类。
- 未完成内容：用户本地纠错覆盖包、社区包导入 / 导出、外部辅助 prompt 携带 language pack ID、更多日文分类词条和母语审校仍留给后续 goal。
- 测试情况：先新增日文分类回归并运行 `bash scripts/run_offline_regression.sh`，观察到 `CategoryResolver(localeIdentifier:)` 尚不存在的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：分类语言包命中优先于静态规则，未来社区包若加入过宽泛关键词可能提高误分类风险；社区包仍应通过 reviewed provenance、脱敏样例和 golden case 门禁进入。
- 回滚方式：恢复 `CategoryResolver` 无语言包状态和旧初始化方式，恢复 `LedgerTextInterpreterCore` 对 `CategoryResolver()` 的无 locale 调用，移除新增日文分类回归，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：平台无关普通记账解析链路已完成账单相关性、金额、商户、分类四段语言包接入，日文小票从相关性判断到结构化草稿已具备第一条完整本地回归路径。
- 下一步建议：继续补用户本地纠错覆盖包或外部辅助 prompt 的语言上下文，优先保持所有共享 / 上传能力默认关闭和用户 opt-in。

### ITER-247 GOAL-1858 商户提取器语言包接入
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1858
- 类型：能力增强 / 识别链路 / 本地化
- 目标：继续落地多语言账单识别语言包，将 `RuleMerchantExtractor` 从静态商户标签推进到 locale-aware 语言包标签，并优先补日文 `店舗` / 非商户字段排除路径。
- 改动范围：`RuleMerchantExtractor` locale / language pack 注入、`MerchantNormalizer` 语言包标签前缀剥离、商户标签与非商户关键词读取语言包；`LedgerTextInterpreterCore` 将 `InterpretInput.localeIdentifier` 传给商户提取器；离线回归新增日文商户样例；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未迁移 `CategoryResolver` / `TransactionCategory.resolve` 到语言包；未实现用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 SQLite / CloudKit schema、UI 本地化 key、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`RuleMerchantExtractor` 新增 `localeIdentifier` 与 `languagePackSet` 初始化参数，并保持无参数调用兼容；商户标签读取 `LedgerRecognitionLanguagePack.merchantLabels`，非商户识别读取 `nonMerchantKeywords`；日文 `店舗: Demo Cafe` 可解析为商户 `Demo Cafe`，`注文番号` 不会成为商户候选；Core 主解释链路的 locale hint 已贯穿到账单相关性、金额提取和商户提取三段。
- 未完成内容：分类关键词语言包接入、更多日文商户形态、用户本地纠错覆盖包、社区包导入 / 导出仍留给后续 goal。
- 测试情况：先新增日文商户回归并运行 `bash scripts/run_offline_regression.sh`，观察到 `RuleMerchantExtractor(localeIdentifier:)` 尚不存在的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过；并行执行 iOS / Mac Catalyst build 时 iOS 曾因 DerivedData `build.db` locked 失败，串行重跑 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过。
- 风险与注意事项：商户标签更可扩展后，错误语言包标签可能把非商户字段提升为高置信候选；本轮已把 `nonMerchantKeywords` 合并进 identifier / blacklist 过滤，但后续社区包仍需要 reviewed provenance 和回归样例约束。
- 回滚方式：恢复 `RuleMerchantExtractor` 无语言包状态、恢复 `MerchantNormalizer.normalize(_:)` 单参数调用、恢复 `LedgerTextInterpreterCore` 对 `RuleMerchantExtractor()` 的无 locale 调用，移除新增日文商户回归，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：平台无关解析主链路已完成账单相关性、金额和商户三段语言包接入，日文小票可从 `領収書 / 合計 / 店舗` 形成第一条可回归的结构化草稿路径。
- 下一步建议：继续迁移 `CategoryResolver` 到语言包，优先让日文 `カフェ` / `コンビニ` / `スーパー` / `電車` 等分类关键词参与当前分类推断，同时保持既有中文 / 英文分类回归不变。

### ITER-246 GOAL-1857 金额提取器语言包接入
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1857
- 类型：能力增强 / 识别链路 / 本地化
- 目标：继续落地多语言账单识别语言包，将 `PaymentAmountExtractor` 从静态金额标签推进到 locale-aware 语言包标签，并优先补日文总额和千位金额格式。
- 改动范围：`PaymentAmountExtractor` locale / language pack 注入、金额正则千位分隔支持、total / actual paid / subtotal / tax / discount 标签读取语言包；`LedgerTextInterpreterCore` 将 `InterpretInput.localeIdentifier` 传给金额提取器；离线回归新增日文金额样例；版本计划、CHANGELOG 和本日志回填。
- 未改动范围：未迁移 `RuleMerchantExtractor`、`MerchantResolver`、`CategoryResolver` 到语言包；未实现用户纠错上传、社区包导入 / 导出、远程语言包热更新或服务端收集通道；未修改 SQLite / CloudKit schema、UI 本地化 key、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`PaymentAmountExtractor` 新增 `localeIdentifier` 与 `languagePackSet` 初始化参数，并保持无参数调用兼容；金额正则支持 `¥1,080` / `1,234.56` 这类千位分隔金额，同时保留 `12,30` 逗号小数兼容；角色判断可读取语言包中的 `amountLabels`、`totalLabels`、`discountLabels`、`taxLabels`；`LedgerTextInterpreterCore(localeIdentifier: "ja-JP")` 可以解析日文 `合計 ¥1,080` 为 1080。
- 未完成内容：日文商户标签、日文分类关键词、更多地区货币格式、用户本地纠错覆盖包和社区包导入 / 导出仍留给后续 goal。
- 测试情况：先新增日文金额回归并运行 `bash scripts/run_offline_regression.sh`，观察到 `PaymentAmountExtractor(localeIdentifier:)` 尚不存在的 RED 编译失败；实现后同一回归通过。随后执行 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`git diff --check`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：金额正则新增千位分隔支持，已保留逗号小数路径；后续如支持更多地区格式，应继续用语言包和 golden case 约束，避免把订单号、日期或数量误识别为金额。Xcode build 仍可能输出既有 Swift 6 actor / deprecated API warning，本轮不处理。
- 回滚方式：恢复 `PaymentAmountExtractor` 无语言包状态和旧金额正则，恢复 `LedgerTextInterpreterCore` 对 `PaymentAmountExtractor()` 的无 locale 调用，移除新增日文金额回归，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：金额提取器已进入语言包链路，日文总额与千位金额格式具备第一条可回归路径。
- 下一步建议：继续迁移商户标签和 `MerchantResolver` 到语言包，优先覆盖日文 `店舗` / `加盟店` / `店名` 和英文 / 中文既有标签行为不变。

### ITER-245 GOAL-1856 Core 语言包骨架与账单相关性门控接入
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1856
- 类型：能力增强 / 识别链路 / 本地化
- 目标：开始落地多语言账单识别语言包设计，在平台无关层新增语言包数据结构和内置语言包，并先把账单相关性门控接入语言包与 App locale hint。
- 改动范围：`AutoLedgerCore` 新增 `LedgerRecognitionLanguagePack` / `LedgerRecognitionLanguagePackSet`；`BillRelevanceGate` 增加语言包依赖和 locale-aware evaluate；`LedgerTextInterpreterCore` 将 `InterpretInput.localeIdentifier` 传入门控；App `LedgerTextInterpreter` 输入模型支持显式 locale，并默认传 `Locale.autoupdatingCurrent.identifier`；离线 / golden / batch flat swiftc 脚本纳入新增 Core 文件；版本计划与 CHANGELOG 回填。
- 未改动范围：未实现用户纠错上传、社区包远程分发、远程语言包热更新或服务端收集通道；未迁移 `PaymentAmountExtractor`、`RuleMerchantExtractor`、`MerchantResolver`、`CategoryResolver` 到语言包；未修改 SQLite / CloudKit schema、UI 本地化 key、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增 `schemaVersion`、`packVersion`、`provenance`、locale identifiers、账单关键词、支付关键词、金额 / total / 折扣 / 税费 / 日期 / 商户标签、非商户关键词和分类关键词 map；内置 `zh-Hans` / `zh-Hant` / `en` / `ja` 包；PackSet 支持 locale 匹配、fallback 和 merged pack；`BillRelevanceGate` 继续保留旧关键词兼容，同时读取语言包关键词；App 主链路可把显式 `ja-JP` 或当前系统 locale 传给 Core 非账单门控。
- 未完成内容：日文金额千位逗号、日文商户标签、日文分类关键词、用户本地纠错覆盖包、社区包导入 / 导出和外部辅助 prompt 语言包 ID 尚未实现。
- 测试情况：先新增 Core 语言包回归并运行 `bash scripts/run_offline_regression.sh`，观察到缺少 `LedgerRecognitionLanguagePackSet` / `LedgerRecognitionLanguagePack` / `BillRelevanceGate(languagePackSet:)` 的 RED 编译失败；实现后回归通过。随后新增 App locale hint 回归，再次观察到 `LedgerTextInterpretationInput` 缺少 `localeIdentifier` 的 RED 编译失败；实现后回归通过。最终验证 `bash scripts/run_offline_regression.sh`、`bash scripts/run_golden_regression.sh`、`git diff --check`、`python3 scripts/check_localization_coverage.py`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'platform=macOS,variant=Mac Catalyst' build` 均通过。
- 风险与注意事项：当前只把语言包接入非账单门控，尚不代表日文账单可以完整解析金额 / 商户 / 分类；日文 `¥1,080` 等格式后续需要在金额迁移时补专门回归。Xcode build 仍有既有 Swift 6 actor / deprecated API warning，本轮未处理。
- 回滚方式：删除 `LedgerRecognitionLanguagePack.swift`，恢复 `BillRelevanceGate` 构造器和 `evaluate` 签名、恢复 `LedgerTextInterpreterCore` / App `LedgerTextInterpreter` locale 参数传递、移除新增回归与脚本编译项，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：多语言识别语言包已经从文档进入 Core 第一段可运行代码，日文和社区审核包关键词可以参与账单相关性判断，App 主链路已经具备 locale hint 传递。
- 下一步建议：继续按小步迁移金额标签和 total 规则到语言包，优先补 `ja` 金额格式与 `PaymentAmountExtractor` 回归，再迁移商户 / 分类 resolver。

### ITER-244 GOAL-1855 语言包扩展与社区共享设计
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1855
- 类型：设计 / 识别链路 / 本地化 / 隐私
- 目标：在多语言账单识别语言包设计中补齐可扩展性和社区协作边界，确保后续可以支持内置包、用户本地纠错覆盖包、社区审核包和 opt-in 脱敏纠错共享。
- 改动范围：`versions/v1.6.1-plan.md` 的 11.5 语言包设计、GOAL 表和当前落地切片；`CHANGELOG.md` 与本迭代日志。
- 未改动范围：不实现 `LedgerRecognitionLanguagePack` 代码；不新增上传通道；不实现远程语言包热更新；不修改 SQLite / CloudKit schema、App 隐私文案、UI 本地化 key、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：语言包模型规划新增 `schemaVersion`、`packVersion` 和 provenance；补充纯数据包、fallback、冲突合并、社区包 code review / 回归 / 许可检查原则；规划用户本地 `UserRecognitionOverridePack` 和 opt-in 纠错共享入口；明确共享 payload 最小化、脱敏、用户预览确认和人工审核要求。
- 未完成内容：未实现本地纠错覆盖包、社区包导入 / 导出、纠错共享 UI、服务端收集通道或社区审核工作台。
- 隐私边界：公共版本默认不上传；用户纠错共享必须显式 opt-in、可预览、可取消；不共享完整截图、完整 PDF、完整 OCR、完整邮件内容、订单号、会员号、邮箱、手机号、银行卡号、证件号或精确住址。金额 / 日期 / 商户真实值默认不共享，除非未来提供单独确认和人工审核入口。
- 测试情况：文档-only 改动，执行 `git diff --check` 验证 Markdown patch 无空白错误。
- 风险与注意事项：社区语言包会提升覆盖面，但也可能引入误识别；后续实现必须用 golden cases、权重回滚和人工审核控制质量。若未来要启用纠错共享，需要先更新隐私说明、Review Notes 和设置页开关。
- 回滚方式：移除 `versions/v1.6.1-plan.md` 中 GOAL-1855、语言包扩展 / 社区共享段落，并删除 `CHANGELOG.md` 与本日志条目即可；本轮无代码和数据迁移。
- 结论：语言包设计已具备从内置包扩展到用户本地纠错和社区协作的路线，但当前版本仍不实现上传或远程更新。
- 下一步建议：实现语言包代码时，先落内置包和本地纠错覆盖包，再评估社区包导入 / 导出；纠错上传应等隐私合规和审核说明准备完成后再灰度。

### ITER-243 GOAL-1870 / GOAL-1854 识别链路误提示收敛与多语言识别语言包设计
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1870 / GOAL-1854
- 类型：Bugfix / 设计 / 识别链路 / 本地化
- 目标：暂时移除主链路中的多笔账单误触发提示，降低重复金额行、优惠行或支付渠道金额行导致的用户干扰；同时规划平台无关层和 App 主链路后续的多语言账单识别语言包设计。
- 改动范围：`LedgerTextInterpreter`、`QuickLedgerIntent`、`ShareViewController` 的 `detectMultipleReceipts` 调用点；离线回归新增误触发保护断言；`versions/v1.6.1-plan.md` 新增多语言账单识别语言包设计和 GOAL；CHANGELOG 与本迭代日志。
- 未改动范围：未删除 `ReceiptParser.detectMultipleReceipts` 函数；未实现多笔账单自动拆分；未修改多商品纸质小票 total 缺失拦截；未实现 `LedgerRecognitionLanguagePack` 代码；未修改 UI 本地化 key、SQLite / CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：App 主链路不再计算或追加 `multiReceiptDetected` warning；QuickLedgerIntent 不再计算 `multiReceipt` 或追加 `quick_ledger.multi_receipt_warning`；Share Extension 不再计算 `multiReceipt` 或追加 `share.multi_receipt_warning`；新增离线回归样例覆盖重复金额行文本仍能正常解析且不再标记多笔账单；版本计划新增 `LedgerRecognitionLanguagePack` / PackSet 设计，明确 Core 语言包字段、App locale / OCR hint 传递、外部辅助 prompt 语言上下文和多语言 golden cases。
- 未完成内容：多语言识别语言包代码、现有中文 / 英文关键词迁移、日文识别包、OCR 语言 hint 接入和多语言 golden cases 尚未实现；多笔账单拆分后续如需恢复，应改为独立待确认队列，不再用高误触发 warning。
- 测试情况：先执行 `bash scripts/run_offline_regression.sh` 观察到新增 RED 用例失败，失败点为 `LedgerTextInterpreter suppresses multiple receipt warning while feature is paused`；实现暂停调用后再次执行同一命令通过。
- 风险与注意事项：暂停多笔账单提示后，极少数真正包含多笔独立账单的截图不会再提醒用户裁剪；当前保留多商品小票 total 保护，避免纸质小票金额取错。语言包设计目前只写入计划，后续实现需要分阶段迁移，避免一次性改动普通 OCR 主链路。
- 回滚方式：恢复 `LedgerTextInterpreter`、`QuickLedgerIntent`、`ShareViewController` 中对 `detectMultipleReceipts` 的调用和提示拼接，移除新增离线回归断言，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：多笔账单误触发提示已从主路径暂停；多语言账单识别语言包的后续架构方向已记录在 v1.6.1 计划中。
- 下一步建议：下一轮若推进识别多语言化，先新增 `LedgerRecognitionLanguagePack` 模型和中英文内置包，用回归保证结果不变，再补 `ja` 日文包。

### ITER-242 GOAL-1816 Mac 酒店消费 A 阶段可测试闭环
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1816
- 类型：能力增强 / macOS / 酒店消费
- 目标：把 Mac 端“酒店消费”从可见入口推进到可人工测试的 A 阶段闭环：手动导入本地酒店水单 PDF，提取文本，进入模型解析或人工复核，用户确认后生成正式酒店消费记录和关联普通支出流水。
- 改动范围：`SQLiteTransactionStore` 酒店记录持久化；`LedgerStore` 酒店消费状态与确认入账 API；Mac / iPad 工作台酒店消费页 PDF 导入、解析状态和复核 sheet；App 层 OpenAI-compatible 酒店水单解析 client；主 App 四语导入 / 入账提示文案；离线回归；版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未持久化 `HotelStayDraft` 草稿队列；未实现本地邮箱 / IMAP 扫描、Worker 云端自动化、酒店消费删除 UI、酒店详情跳普通账单详情、酒店记录备份 / CloudKit 同步；未修改 signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增 `hotel_stay_records` SQLite 表，支持 `HotelStayRecord` 保存 / 读取 / 删除；新增原子保存 `HotelStayRecord + Transaction` 路径；`LedgerStore` 启动和刷新时加载酒店消费记录，确认草稿后写入正式酒店记录与普通流水并刷新列表；Mac / iPad “酒店消费”页支持选择 PDF、PDFKit 文本提取、外部辅助识别解析、复核 sheet、确认入账和状态提示；外部识别未启用、缺 key / endpoint 或请求失败时仍打开带原始文本的人工复核草稿。
- 未完成内容：待确认草稿列表、删除 UI、酒店记录备份 / CloudKit 同步、详情页跳转普通账单、邮箱半自动导入和 Worker 自动化仍留给后续 GOAL。
- 测试情况：执行 `bash scripts/run_offline_regression.sh` 通过，新增覆盖酒店记录 SQLite 持久化和 `LedgerStore` 确认酒店草稿后生成 `HotelStayRecord + Transaction`；执行 `bash scripts/run_hotel_pdf_import_smoke.sh`、`python3 scripts/check_localization_coverage.py`、`git diff --check`、Mac Catalyst build 和 iOS generic build 均通过。
- 风险与注意事项：外部模型解析复用现有外部辅助识别设置，未配置时不会自动解析，只进入人工复核；当前没有草稿队列，关闭复核 sheet 后需重新导入；酒店记录尚未进入备份 / CloudKit 同步，跨设备展示仍需后续补齐。
- 回滚方式：回退 `SQLiteTransactionStore` 酒店记录表和 API、`LedgerStore` 酒店记录状态 / 入账 API、酒店消费页 PDF 导入串接、`HotelFolioExternalParseClient`、新增本地化 key、离线回归断言以及版本计划 / CHANGELOG / 本日志条目；已创建的本地 `hotel_stay_records` 表可保留为空兼容表。
- 结论：Mac 端酒店消费 A 阶段已经具备手动 PDF 导入、复核确认、正式归档和关联普通流水的最小可测闭环。
- 下一步建议：用真实或 Demo 酒店水单 PDF 在 Mac App 上做人工验收；若体验稳定，下一轮优先补酒店记录删除 UI 和酒店记录备份 / CloudKit 同步边界。

### ITER-241 GOAL-1815 Mac 酒店消费入口修复
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1815
- 类型：Bugfix / macOS / 导航
- 目标：修复本地编译后 Mac 端看不到“酒店消费”tab / 侧边栏入口的问题，让已完成的酒店消费列表组件能在 Mac Catalyst 工作台中被发现。
- 改动范围：`AutoLedgerRootView` 的 Mac Catalyst 根视图选择；`IPadWorkspaceSection` 与 `IPadWorkspaceView` 侧边栏 / detail switch；版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `HotelStayRecord` 独立持久化表；未持久化 `HotelStayDraft`；未串接 PDF 导入、解析或确认页到真实酒店消费数据源；未实现删除酒店记录或列表跳转普通账单详情；未修改 SQLite schema、CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：Mac Catalyst 显式使用 `IPadWorkspaceView`，避免在 Mac 上落回 iPhone `HomeView`；iPad / Mac 工作台侧边栏新增“酒店消费”入口，使用 `bed.double.fill` 图标和已有四语 `hotel_stay.list.title` 文案；入口展示 `HotelStayListView`，并把当前账本 / 全部账本口径传入酒店归档展示组件。
- 未完成内容：酒店列表当前仍没有独立持久化数据源，真实记录进入列表需要后续补 `HotelStayRecord` 存储和 PDF 导入 / 确认页数据流；列表到普通账单详情的真实跳转仍未实现。
- 测试情况：执行 Mac Catalyst build 通过；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 通过；后续仍建议在本机 Mac App 实际启动后目检侧边栏入口和空状态。
- 风险与注意事项：本轮修复的是入口可见性，不代表酒店 PDF 导入后的数据已经进入列表；用户当前在 Mac 端应能看到“酒店消费”入口，但列表可能为空，这是现阶段缺少独立酒店记录持久化的预期行为。
- 回滚方式：回退 `AutoLedgerRootView` 的 Mac Catalyst root 选择、`IPadWorkspaceSection` 的 `hotelStays` 入口和 `IPadHotelStayWorkspaceView`，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：Mac 端“酒店消费”入口不可见的问题已定位并修复，可继续后续酒店消费持久化和导入数据流 GOAL。
- 下一步建议：下一轮若继续酒店主线，优先补 `HotelStayRecord` 独立持久化与 PDF 导入 / 确认页到列表的数据串接。

### ITER-240 GOAL-1860 跨平台 App Icon 重绘
- 日期：2026-06-25
- 所属版本：v1.6.1
- 所属阶段：GOAL-1860
- 类型：发布资产 / 图标 / 工具
- 目标：解决 iOS AppIcon 的细长闪电同步到 tvOS / visionOS 等平台后被压成细线的问题，保留现有钱包、金币、闪电和蓝绿背景元素，但为各平台生成专用图标资产。
- 改动范围：新增 `tools/app-icons` 生成 / 验证 / 平台形状预览脚本与 README；替换主 App iOS AppIcon light / dark / tinted PNG；替换 Apple Watch 多尺寸 AppIcon PNG；替换 tvOS App Icon 与 App Store image stack 的 Back / Middle / Front 图层；替换 visionOS solid image stack 的 Back / Middle / Front 图层；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未修改 Top Shelf Image / Top Shelf Wide Image；未修改 Bundle ID、signing、entitlements、App Group、iCloud Container、SQLite schema、CloudKit schema、Xcode Cloud 脚本或 `MARKETING_VERSION`；未提交 ASC 线上素材。
- 完成内容：`generate_app_icons.py` 可重跑生成平台专用 PNG；`validate_app_icons.py` 固化尺寸检查和 tvOS / visionOS 前景闪电 alpha 覆盖率门禁；`preview_app_icons.py` 可生成 iOS / Mac Catalyst 圆角矩形、Watch / visionOS 圆形、tvOS 横向矩形的完整合成预览；新图标保留钱包 / 金币 / 闪电元素，闪电改为尖角尾部和平台专用比例，避免前景闪电细线化。
- 未完成内容：ASC / TestFlight / 真机上的最终图标显示仍需人工目检；Top Shelf 资产如需同步新视觉，可作为后续独立 GOAL。
- 测试情况：先执行 `python3 tools/app-icons/validate_app_icons.py`，旧图标因 tvOS / visionOS 前景覆盖率不足失败；生成新资产后再次执行同一命令通过。执行 `python3 tools/app-icons/preview_app_icons.py` 生成平台形状预览，并目检 iOS / Mac Catalyst 圆角矩形、Watch / visionOS 圆形、tvOS 横向矩形版本。执行 `python3 -m py_compile tools/app-icons/generate_app_icons.py tools/app-icons/validate_app_icons.py tools/app-icons/preview_app_icons.py`、`git diff --check`、iOS / tvOS / visionOS generic build，均通过。
- 风险与注意事项：图标是发布资产，最终效果仍受 Apple 平台蒙版、圆角、视差和 ASC 渲染影响；提交前建议在 TestFlight / ASC 页面做一次实际显示目检。
- 回滚方式：回退 `tools/app-icons` 新增文件、恢复被替换的 AppIcon PNG，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮无数据迁移。
- 结论：GOAL-1860 已完成代码库内资产替换、可重复生成门禁和平台形状预览，可进入 Xcode Cloud / TestFlight / ASC 实际图标目检。
- 下一步建议：在 Xcode Cloud / TestFlight / ASC 平台素材页做实际图标目检；Top Shelf 如需同视觉重绘，可另开独立 GOAL。

### ITER-239 GOAL-1852 日文支持发布素材
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1852
- 类型：本地化 / 发布素材 / 文档
- 目标：补齐日文支持的发布素材第二段，包括截图配置、术语表、ASC metadata、TestFlight notes、Review Notes 边界和人工审校清单。
- 改动范围：`tools/appstore-screenshots/config/screenshots.json` 新增 `ja` locale 和现有 26 个截图场景日文 copy；新增 `versions/v1.6.1-ja-release-materials.md`；版本计划、CHANGELOG 与本迭代日志回填 GOAL-1852 状态。
- 未改动范围：未提交或修改 App Store Connect 线上元数据；未导出正式日文截图；未新增日文母语人工审校结论；未把邮箱自动扫描或 Worker 自动化写成公共用户已开放能力；未修改业务逻辑、SQLite schema、CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：截图管线配置具备 `ja_JP` locale；iPhone、iPad、Mac、Apple Watch、tvOS、visionOS 现有截图场景均有日文标题和副标题草稿；日文发布材料文档覆盖 `台帳`、`ホテル明細`、`ホテル滞在` 等术语，提供 ASC / TestFlight / Review Notes 草稿，并明确内部 `v1.6.1` 继续映射外部 ASC `1.5.0`。
- 未完成内容：日文截图真实导出、逐平台目检、ASC 页面粘贴和日文母语审校仍需人工执行；App Intents / Shortcuts 的日文显示仍建议在 TestFlight 真机上复查。
- 测试情况：执行 `python3 -m json.tool tools/appstore-screenshots/config/screenshots.json` 通过；执行脚本检查所有截图场景 `title` / `subtitle` 均含 `ja`；后续仍需执行日文截图导出命令并人工目检。
- 风险与注意事项：当前日文 copy 是草稿，不应跳过人工审校直接提交；Review Notes 和 What's New 需要按实际 ASC `1.5.0` 构建内容删减，避免描述未开放的酒店、邮箱或 Worker 能力。
- 回滚方式：回退截图配置新增 `ja` locale / copy、删除 `versions/v1.6.1-ja-release-materials.md`，并回退版本计划 / CHANGELOG / 本日志条目即可；本轮不涉及数据迁移。
- 结论：GOAL-1852 的日文发布素材第二段已完成，可进入后续人工日文审校 / 截图导出，或转入下一个功能 GOAL。
- 下一步建议：按平台执行 `--locale ja` 截图导出，打开 preview 目检，再由人工确认 ASC metadata 与 Review Notes。

### ITER-238 GOAL-1851 硬编码字符串审计
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1851
- 类型：本地化 / 治理 / 文档
- 目标：审计 `v1.6.1` 新增路径和主路径中的硬编码用户可见字符串，先收口本轮新增多账本移动提示，并把剩余硬编码按风险分类记录。
- 改动范围：`LedgerStore.moveTransaction(_:toLedgerID:)` 多账本移动结果提示；主 App 四语 `Localizable.strings`；`scripts/check_localization_coverage.py` 必备 key；新增 `versions/v1.6.1-hardcoded-string-audit.md`；版本计划、CHANGELOG 与本迭代日志回填 GOAL-1851 状态。
- 未改动范围：未批量迁移所有历史 `lastImportSummary`；未本地化 OCR / 支付截图解析关键词；未修改默认账本持久化名称；未改变 Debug / diagnostics 导出策略；未新增截图文案、ASC metadata、TestFlight notes、Review Notes 或日文术语表；未修改业务逻辑、SQLite schema、CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：多账本移动成功、目标账本不可用、找不到账单和持久化失败四类提示改为 `ledger.move.*` 本地化 key；四语资源补齐；本地化覆盖检查新增对应必备 key；审计文档记录解析规则、Debug / 诊断、历史导入摘要、默认账本名和截图模式文案的残留分类与后续建议。
- 未完成内容：`LedgerStore` 中删除 / 恢复、手动记账、批量编辑、数据清洗、备份恢复和 iCloud 同步等历史用户提示仍需后续按组迁移；日文截图 / ASC / Review Notes 草稿仍留给 `GOAL-1852`。
- 测试情况：先扩展 `scripts/check_localization_coverage.py` 后执行 `python3 scripts/check_localization_coverage.py`，确认缺少 4 个 `ledger.move.*` key 时失败；补齐 Swift 和四语资源后再次执行同一命令通过。
- 风险与注意事项：解析规则中的中文关键词是识别逻辑，不应作为 UI 文案盲目本地化；默认账本名是持久化数据，迁移策略需单独设计；历史 `lastImportSummary` 用户提示数量较多，建议后续小步拆分。
- 回滚方式：回退 `LedgerStore.moveTransaction` 的本地化改动、四语新增 `ledger.move.*` key、覆盖检查新增必备 key、审计文档以及版本计划 / CHANGELOG / 本日志条目即可；本轮不涉及数据迁移。
- 结论：GOAL-1851 第一版硬编码字符串审计完成，可进入 `GOAL-1852` 日文发布素材与术语表补齐。
- 下一步建议：优先为日文支持整理术语表、截图文案、ASC metadata、TestFlight notes 和 Review Notes 草稿，并标明人工审校要求。

### ITER-237 GOAL-1850 新功能文案覆盖门禁
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1850
- 类型：本地化 / 测试门禁 / 文档
- 目标：把酒店消费、多账本、错误提示和设置说明的新功能文案覆盖从人工检查固化为可重复执行的本地化门禁。
- 改动范围：`scripts/check_localization_coverage.py` 新增主 App `v1.6.1` 必备 key 和 prefix count 检查；版本计划、CHANGELOG 与本迭代日志回填 GOAL-1850 状态。
- 未改动范围：未新增或重写具体 `.strings` 文案；未做硬编码字符串审计；未新增截图文案、ASC metadata、TestFlight notes、Review Notes 或日文术语表；未修改业务逻辑、SQLite schema、CloudKit schema、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：覆盖检查继续验证主 App、Watch App、Watch Widgets、Control Widget Extension 和 Share Extension 的 `zh-Hans` / `zh-Hant` / `en` / `ja` key 集合一致；主 App 新增酒店水单 PDF 错误、酒店消费复核 / 列表 / 详情、多账本设置入口、账本管理动作、账本范围切换和移动账本的必备 key 检查；新增 `hotel_stay.`、`hotel_folio.import.error.` 和 `ledger_profiles.` prefix 数量下限检查。
- 未完成内容：日文文案人工审校、截图 / ASC / TestFlight / Review Notes 草稿和术语表仍留给 `GOAL-1852`；SwiftUI / AppIntents / Debug 的硬编码字符串审计仍留给 `GOAL-1851`。
- 测试情况：执行 `python3 scripts/check_localization_coverage.py` 通过，确认当前四语资源满足新增必备 key / prefix count 门禁。
- 风险与注意事项：本轮保证“关键 key 存在且四语对齐”，不保证日文译文已达到商店发布质量；文案质量和截断风险仍需人工审校。
- 回滚方式：回退 `scripts/check_localization_coverage.py` 新增必备 key / prefix count 检查以及版本计划 / CHANGELOG / 本日志条目即可；不会影响 App 运行时代码。
- 结论：GOAL-1850 的 App 内新功能四语文案覆盖门禁已完成，可进入 `GOAL-1851` 硬编码字符串审计。
- 下一步建议：用脚本先锁定 `AutoLedger/AutoLedger` 中用户可见硬编码中文 / 英文，按“新功能和主路径优先、调试导出可豁免”的规则收口。

### ITER-236 GOAL-1844 统计、订阅与展示口径
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1844
- 类型：能力增强 / LedgerStore / UI / 统计口径 / 测试
- 目标：统一主 App 中当前账本 / 全部账本的统计、订阅、导入展示和酒店归档展示口径，避免账单列表已经分账本但报表或首页仍显示全量数据。
- 改动范围：`LedgerStore` 月报、今日摘要、订阅过滤和订阅历史扫描 helper；iPhone `ReportView` / `InboxView`；iPad / Mac 工作台 overview、报告、数据清洗预览和重复账单预览；`SubscriptionListView`；`HotelStayArchivePresenter` 与酒店列表 / 详情组件；离线回归、版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `Subscription.ledgerID` 或订阅 SQLite / Backup / CloudKit schema；未新增批量导入队列项的 `targetLedgerID` 持久化字段；未修改 Watch / Widget / tvOS / visionOS 展示口径；未新增账本 Profile 的 CloudKit / BackupBundle 同步 payload；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`LedgerStore.monthlySnapshot` / `monthlySnapshot(for:)` 与 `todaySpendingSummary` 基于 `visibleTransactions` 生成；当前账本模式只统计当前账本，全部账本模式聚合全部活跃交易；订阅扫描与列表首版按当前账本相关交易商户匹配过滤；iPhone 首页、报表、Top 商户、快捷指令计数、即将扣费订阅，iPad / Mac overview、报告和数据清洗预览均跟随当前账本 / 全部账本；酒店归档展示 presenter 支持可选 `ledgerID` 过滤。
- 未完成内容：无历史交易的手动订阅暂时无法表达归属账本；批量导入队列仍未持久化目标账本；Watch / Widget / tvOS / visionOS 仍保持既有全量 / 只读展示策略；账本 Profile 仍未进入备份或 CloudKit 同步。
- 测试情况：先新增 `verifyLedgerScopedSurfaces` 离线回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `monthlySnapshot(for:)`、订阅 helper 和酒店归档 `ledgerID` 参数而失败；实现后再次执行离线回归 PASS。随后执行 `python3 scripts/check_localization_coverage.py`、`find AutoLedger -path '*/build' -prune -o -path '*lproj/*.strings' -exec plutil -lint {} +`、`git diff --check` 和 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果均通过。
- 风险与注意事项：订阅过滤目前是交易派生口径，不是订阅实体级账本归属；如果用户手动创建一个没有历史交易的订阅，它在当前账本过滤下无法稳定归属，后续需要单独设计 `Subscription.ledgerID` 迁移。大屏端继续展示全部账本聚合，若未来需要多账本切换，需要扩展 dashboard snapshot。
- 回滚方式：回退 `LedgerStore` 新增统计 / 订阅 helper、Report / Inbox / iPadWorkspace / SubscriptionList / HotelStayArchive 口径改动、离线回归新增断言以及版本计划 / CHANGELOG / 本日志条目即可；本轮不新增数据库 schema。
- 结论：GOAL-1844 的主 App 当前账本 / 全部账本展示口径已完成，可进入 `GOAL-1850` 新功能多语言文案覆盖或继续补订阅实体账本迁移设计。
- 下一步建议：先做 `GOAL-1850 / GOAL-1851` 的文案覆盖和硬编码字符串审计，把多账本与酒店消费新增入口的四语文案收齐；订阅实体 `ledgerID` 建议作为独立后续 GOAL，不并入当前提交。

### ITER-235 GOAL-1843 账本切换与账单移动
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1843
- 类型：能力增强 / LedgerStore / UI / 本地化 / 测试
- 目标：提供第一版当前账本 / 全部账本切换，并允许用户把单笔普通账单移动到其他账本。
- 改动范围：`LedgerStore` 新增当前账本、全部账本、可见交易过滤、新流水目标账本和单笔移动账本 API；iPhone 账单列表新增账本范围菜单、行级账本名称和移动账本操作；iPad / Mac 工作台账单列表改用同一可见账本口径并提供账本菜单；补齐主 App 四语文案；更新离线回归、版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未实现批量移动账本；未改统计、订阅、导入和酒店消费的账本过滤口径；未修改 Watch / Widget / tvOS / visionOS 展示口径；未新增账本 Profile 的 CloudKit / BackupBundle 同步 payload；未对旧 SQLite 交易行执行物理账本回填；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：当前选中账本和全部账本状态保存在本机 `UserDefaults`；`visibleTransactions` 会按当前账本过滤，全部账本视图展示所有活跃交易；新建普通流水默认写入当前账本，全部账本视图回落默认账本；单笔移动账本复用既有更新路径并触发本地持久化、Widget / Backup 刷新和 CloudKit 推送安排；iPhone、iPad 和 Mac 的账单列表可以切换账本范围，iPhone 账单行可以移动到其他活跃账本。
- 未完成内容：统计、订阅、导入、酒店消费和展示端聚合仍按旧全量口径，统一留给 `GOAL-1844`；iPad / Mac 本轮只落地账本范围切换，单笔移动入口先在 iPhone 账单列表提供；账本 Profile 尚未进入备份或 CloudKit 同步。
- 测试情况：先新增 `verifyLedgerSelectionAndTransactionMoves` 离线回归并执行 `bash scripts/run_offline_regression.sh`，先因缺少 `LedgerStore` 账本选择 / 移动 API 失败；实现后离线回归 PASS。随后执行 `python3 scripts/check_localization_coverage.py`、`find AutoLedger -path '*/build' -prune -o -path '*lproj/*.strings' -exec plutil -lint {} +` 和 `git diff --check`，结果均通过。第一次 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build` 因 `ledgerScopeMenu` 被包在 Mac Catalyst 条件编译内导致 iPad 编译不可见而失败，修正作用域后重跑同一命令通过。
- 风险与注意事项：用户已经可以切换账本列表并移动单笔账单，但报表、订阅、导入和酒店消费若继续展示全量数据，体验上会出现“列表已分账本、统计还未分账本”的阶段性不一致；后续 `GOAL-1844` 需要统一聚合口径并决定 Watch / Widget / tvOS / visionOS 是否继续保持全量。
- 回滚方式：回退 `LedgerStore` 账本选择 / 可见交易 / 单笔移动 API、`LedgerView` 和 `iPadWorkspaceView` 的账本范围 UI、四语本地化新增 key、离线回归断言以及版本计划 / CHANGELOG / 本日志条目即可；本轮不新增 SQLite schema。
- 结论：GOAL-1843 的账本切换与 iPhone 单笔移动账本第一版已完成，可进入 `GOAL-1844` 统计、订阅、导入与展示端口径统一。
- 下一步建议：优先梳理月报 / 今日摘要 / 订阅 / 导入 / 酒店消费的 current ledger 与 all ledgers 口径，避免同一版本内各入口看到的数据范围不一致。

### ITER-234 GOAL-1842 账本管理基础 UI
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1842
- 类型：能力增强 / SQLite / LedgerStore / UI / 本地化 / 测试
- 目标：为多账本提供第一版真实账本 Profile 持久化和设置页基础管理入口，支持新建、重命名、归档和设置默认账本。
- 改动范围：SQLite 新增 `ledger_profiles` 表；`SQLiteTransactionStore` 新增账本 Profile 读取、保存、重命名、归档和默认账本切换；`LedgerStore` 新增账本状态与管理 API；新增 `LedgerProfileManagementView` 并接入 `SettingsView`；补齐主 App 四语文案；更新离线回归、版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未实现当前账本 / 全部账本筛选；未实现单笔或批量移动账本；未改月报、订阅、导入、酒店消费和 Watch / Widget / tvOS / visionOS 展示口径；未新增账本 Profile 的 CloudKit / BackupBundle 同步 payload；未做旧 SQLite 交易行物理回填；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：空库会自动初始化默认本地账本；自定义账本可保存币种、图标、颜色和排序；账本可重命名、归档、设置默认，且同一时间只有一个活跃默认账本；`LedgerStore` 发布 `ledgerProfiles` / `activeLedgerProfiles` / `defaultLedgerProfile` 并提供 UI 可调用操作；设置页新增账本管理入口，管理页支持新增、重命名、设为默认和归档。
- 未完成内容：账单列表仍未按当前账本过滤；账单详情和编辑页还不能选择或移动账本；统计、订阅、导入、酒店消费尚未切换到当前账本 / 全部账本口径；账本 Profile 尚未进入备份或 CloudKit 同步。
- 测试情况：先新增 `verifyLedgerProfileManagement` 离线回归并执行 `bash scripts/run_offline_regression.sh`，先后因缺少 `SQLiteTransactionStore` 账本 Profile API 和 `LedgerStore` 账本管理 API 失败；实现后离线回归 PASS。随后执行 `python3 scripts/check_localization_coverage.py`、`find AutoLedger -path '*/build' -prune -o -path '*lproj/*.strings' -exec plutil -lint {} +` 和 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果均通过。
- 风险与注意事项：当前设置页已经可以创建账本，但正式交易列表仍未按账本筛选，用户看到的账单仍是全量；账本 Profile 尚未同步到 CloudKit 或备份，后续 `GOAL-1843 / GOAL-1844` 需要补迁移和同步策略。
- 回滚方式：回退 `SQLiteTransactionStore` 的 `ledger_profiles` 表和相关 API、`LedgerStore` 账本 Profile 状态与操作、`LedgerProfileManagementView`、`SettingsView` 入口、四语文案、离线回归断言以及版本计划 / CHANGELOG / 本日志条目；若本地数据库已创建 `ledger_profiles` 表，回滚代码后该表会被旧代码忽略。
- 结论：GOAL-1842 的账本管理基础 UI 已完成，可进入 `GOAL-1843` 当前账本 / 全部账本切换与单笔移动账本。
- 下一步建议：先实现当前账本状态和账单列表过滤，再实现账单详情 / 编辑页的移动账本，最后统一统计、订阅、导入和酒店消费的账本口径。

### ITER-233 GOAL-1841 默认账本兼容读取
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1841
- 类型：能力增强 / Core 策略 / LedgerStore / 测试
- 目标：让旧流水缺失 `ledgerID` 时可解释为默认账本，并让 App 新增和编辑正式流水时保留或补齐账本归属。
- 改动范围：`Transaction` 新增 `resolvedLedgerID` 与 `assigningLedgerIDIfMissing`；`LedgerStore` 手动新增、OCR / 语音 / 分享入账、账单编辑、批量编辑、数据清洗、商户别名和分类刷新路径保留或补齐默认账本；更新离线回归断言；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `LedgerProfile` 独立持久化表；未对既有 SQLite 数据执行物理批量回填；未新增当前账本状态、账本选择器、账本管理 UI、账本切换、单笔移动账本或统计筛选；未修改 Watch / Widget / tvOS / visionOS 展示口径；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：旧 `Transaction.ledgerID == nil` 可通过 `resolvedLedgerID()` 解释为 `TodaySpendingSummary.defaultLedgerID`；新手动入账、OCR / 文本 / 语音导入入账默认写入默认账本；编辑 payload 没有 `ledgerID` 时继承原交易的账本归属；批量编辑、数据清洗、商户别名刷新和分类刷新不再丢失既有 `ledgerID` 与 `hotelStayRecordID`。
- 未完成内容：旧数据库中已经存在的 nil `ledger_id` 不会在本轮被物理更新；读取列表按账本过滤、全部账本聚合、默认账本设置和账本迁移 UI 留给后续 GOAL。
- 测试情况：先新增默认账本回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `Transaction.resolvedLedgerID` 和 `assigningLedgerIDIfMissing` 失败；实现后回归发现备份恢复删除账单测试仍按旧 nil 语义比较，调整为默认账本语义后再次执行离线回归，结果 PASS。
- 风险与注意事项：当前兼容策略主要在 App 写入路径补齐默认账本，底层 SQLite 仍允许 nil，以便兼容旧设备、旧备份和旧 CloudKit payload；后续做账本筛选时必须统一使用 `resolvedLedgerID()` 或先执行明确迁移。
- 回滚方式：回退 `Transaction` 默认账本 helper、`LedgerStore` 写入 / 编辑 / 清洗路径的默认账本补齐、离线回归新增断言和版本文档 / CHANGELOG / 本日志条目即可；不涉及新数据库列之外的额外数据迁移。
- 结论：GOAL-1841 的默认账本兼容读取和新流水默认归属已完成，可进入 `GOAL-1842` 账本管理基础 UI 或先补 `LedgerProfile` 持久化。
- 下一步建议：先落最小 `LedgerProfile` 持久化与账本管理入口，再做当前账本 / 全部账本筛选和移动账本，避免 UI 没有真实账本来源。

### ITER-232 GOAL-1840 多账本 schema 基线
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1840
- 类型：能力增强 / Core 模型 / SQLite / 同步 / 备份 / 测试
- 目标：建立多账本基础 schema，使正式流水具备可选账本归属字段，并为后续默认账本迁移、账本管理 UI 和账单移动提供兼容基线。
- 改动范围：新增 Core 层 `LedgerProfile`；`Transaction` 新增可选 `ledgerID`；SQLite `transactions` 新增 nullable `ledger_id`；`BackupTransaction`、`LedgerTransactionSyncPayload` 和 App 层 CloudKit 交易 payload 映射保留 `ledgerID`；酒店消费入账和商户别名刷新保留账本字段；更新离线回归断言和编译清单；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `LedgerProfile` 独立持久化表；未实现旧账单默认账本回填；未实现账本创建 / 重命名 / 归档 / 默认账本 UI；未实现当前账本筛选、全部账本聚合切换或单笔移动账本；未新增 Watch / Widget / tvOS / visionOS 账本切换；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`LedgerProfile.defaultLocal()` 与 `TodaySpendingSummary.defaultLedgerID/defaultLedgerName` 对齐；`Transaction.ledgerID` 以可选字段兼容旧 JSON；SQLite 新库和旧库迁移都会具备 `ledger_id TEXT`；本地保存、更新、远端同步插入 / 更新、备份导出 / 恢复和 sync payload round-trip 均保留账本归属；酒店消费确认生成的普通支出流水继承目标账本。
- 未完成内容：旧数据中 `ledgerID == nil` 仍只作为兼容状态保留，后续 `GOAL-1841` 需要实现读取时视为默认账本和新增账单写明确账本的策略；CloudKit Production schema 需要在发布前部署新增 `ledgerID` 可选字段。
- 测试情况：先新增 `verifyMultiLedgerSchema` 与回归编译清单，执行 `bash scripts/run_offline_regression.sh` 因缺少 `LedgerProfile.swift` 失败；实现后离线回归通过。随后补充 SQLite、Backup、Sync、酒店入账的 `ledgerID` 保留断言并再次执行离线回归，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 `** BUILD SUCCEEDED **`。
- 风险与注意事项：当前只是 schema 基线，未引入真实账本列表存储，因此 UI 侧仍无法创建或切换账本；CloudKit 新字段为可选字段，发布前需部署 Production schema；后续编辑账单和批量操作继续接入账本字段时，需要避免重建 `Transaction` 时丢失 `ledgerID`。
- 回滚方式：移除 `LedgerProfile.swift`，回退 `Transaction.ledgerID`、SQLite `ledger_id` 读写 / 迁移、Backup / sync payload / CloudKit 映射字段、酒店入账与商户别名保留逻辑、离线回归新增断言和编译清单，并回退版本文档、CHANGELOG 与本日志条目；若数据库已创建 nullable `ledger_id` 列，回滚代码后该列会被旧代码忽略。
- 结论：GOAL-1840 的多账本 schema 基线已完成，可进入 `GOAL-1841` 默认账本迁移与兼容读取。
- 下一步建议：实现默认账本持久化与读取口径，让旧账单 `ledgerID == nil` 在展示和统计中视为默认账本，新账单写入明确 `ledgerID`。

### ITER-231 GOAL-1815 酒店消费列表与详情页
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1815
- 类型：能力增强 / UI / Core 展示模型 / 测试 / 本地化
- 目标：为已确认的酒店消费记录提供列表与详情页展示模型，覆盖来源、原始文本和关联普通流水状态。
- 改动范围：新增 Core 层 `HotelStayArchivePresenter`；新增 App 层 `HotelStayListView` 与 `HotelStayDetailView`；补齐主 App 四语酒店消费归档文案；更新离线回归断言和编译清单；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `HotelStayRecord` 独立持久化表；未持久化 `HotelStayDraft`；未串接 PDF 导入、确认页、侧边栏或 App 根导航；未实现删除酒店草稿或正式酒店记录；未新增邮箱 / Worker 自动化；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`HotelStayArchivePresenter` 可按退房日期倒序生成列表快照，计算记录数、总晚数、总金额和平均每晚价格，展示酒店、城市 / 国家、品牌 / 集团、日期范围、晚数、金额、来源和关联状态；详情快照可展示身份、入住、费用、来源、置信度、原始文本，并解析关联普通 `Transaction`。`HotelStayListView` / `HotelStayDetailView` 提供可复用 SwiftUI 组件，包含空状态、摘要、列表行、费用明细、来源信息、原始文本和关联账单区块。
- 未完成内容：当前 UI 组件尚未接入真实 App 导航和数据 store；正式酒店消费记录仍无独立数据库表；删除酒店记录、删除草稿、列表跳转账单详情和账单详情跳回酒店消费记录留给后续 GOAL。
- 测试情况：先新增 `verifyHotelStayArchivePresentation` 离线回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `HotelStayArchivePresenter`、列表状态和详情字段失败；实现后离线回归通过。随后补齐四语 `.strings` 并执行本地化覆盖检查、plist lint、diff whitespace 检查和主 App iOS generic build。
- 风险与注意事项：列表 / 详情当前依赖调用方传入内存中的 `HotelStayRecord` 和 `Transaction`；后续接入真实 store 时需决定 `HotelStayRecord` 的持久化、删除策略、与普通流水的级联关系以及 CloudKit / BackupBundle 同步策略。
- 回滚方式：移除 `HotelStayArchivePresenter.swift`、`HotelStayArchiveView.swift`、离线回归新增断言和编译清单改动，并回退四语本地化、版本文档、CHANGELOG 与本日志条目即可；当前未新增数据迁移。
- 结论：GOAL-1815 的酒店消费列表与详情展示第一版已完成，可进入多账本基础能力 GOAL 或继续补酒店消费持久化 / 导航串接。
- 下一步建议：若继续酒店主线，优先补 `HotelStayRecord` 独立持久化、列表入口接入和删除策略；若切换到版本计划主线，可进入 `GOAL-1840` 多账本 schema 与迁移设计。

### ITER-230 GOAL-1814 酒店消费归档与流水关联
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1814
- 类型：能力增强 / Core 归档 / SQLite / 同步 / 测试
- 目标：让用户确认后的酒店水单草稿能够生成正式酒店消费记录和一条关联的普通支出流水。
- 改动范围：新增 Core 层 `HotelStayLedgerPostingService`；`Transaction` 新增可选 `hotelStayRecordID`；`SQLiteTransactionStore` 新增 nullable `transactions.hotel_stay_record_id` 并支持读写 / 更新 / 远端同步 / 备份恢复；`BackupTransaction` 与 `LedgerTransactionSyncPayload` 保留酒店关联；CloudKit 交易 payload 映射预留 `hotelStayRecordID` 可选字段；更新离线回归断言和编译清单；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增 `HotelStayRecord` 独立持久化表；未新增酒店草稿持久化；未串接 PDF 导入后的实际导航入口；未新增酒店消费列表 / 详情页；未新增删除酒店记录流程；未新增邮箱 / Worker 自动化；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`HotelStayLedgerPostingService` 只接受 `.confirmed` 草稿，生成 `.postedToLedger` 草稿、`HotelStayRecord` 和普通 `Transaction`；普通流水使用酒店名作为 merchant、酒店总额作为 amount、退房日期作为 occurredAt、`酒店住宿` 作为自定义分类、`manual` 作为来源，并在 note 写入入住日期、退房日期、晚数、房型、订单号和支付方式摘要；`HotelStayRecord.linkedTransactionID` 与 `Transaction.hotelStayRecordID` 双向关联；SQLite、备份、Core sync payload 和 CloudKit payload 映射均保留普通流水的酒店关联字段。
- 未完成内容：正式 `HotelStayRecord` 仍只作为服务输出对象，尚未进入独立数据库表或列表 / 详情页面；CloudKit Production schema 尚需在发布前部署新增的 `hotelStayRecordID` 可选字段；当前仍不自动入账，必须先由用户确认草稿。
- 测试情况：先新增 `verifyHotelStayLedgerPosting`，因缺少 `Transaction.hotelStayRecordID` 与 `HotelStayLedgerPostingService` 失败；实现后离线回归通过。随后补充 SQLite、Backup 和 sync payload 的关联字段持久化断言，先因 `BackupTransaction.hotelStayRecordID` 缺失失败；补齐模型、SQLite 迁移、读写、备份和 sync payload 映射后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS。
- 风险与注意事项：`transactions.hotel_stay_record_id` 是 nullable 兼容列，老账单默认 nil；CloudKit 新可选字段需要在 1.6.1 发布前部署 Production schema，否则带酒店关联的交易同步可能无法保存或会丢失该关联；`HotelStayRecord` 尚无独立持久化，后续列表 / 详情页需要继续补存储设计。
- 回滚方式：移除 `HotelStayLedgerPostingService.swift`，回退 `Transaction.hotelStayRecordID`、SQLite 新列读写 / 迁移、Backup / sync payload 字段、CloudKit payload 映射、离线回归新增断言和编译清单，并回退版本文档、CHANGELOG 与本日志条目；若数据库已在本机创建新列，回滚代码后该 nullable 列会被旧代码忽略。
- 结论：GOAL-1814 的确认后归档对象生成与普通流水关联已完成第一版，可进入 `GOAL-1815` 酒店消费列表与详情页。
- 下一步建议：实现酒店消费列表 / 详情页和 `HotelStayRecord` 持久化策略，并补删除记录与来源追溯路径。

### ITER-229 GOAL-1813 酒店水单确认页
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1813
- 类型：能力增强 / UI / Core 表单 / 测试
- 目标：为酒店水单解析结果建立用户确认前的可编辑复核表单，确保正式入账前仍由用户确认。
- 改动范围：新增 Core 层 `HotelStayReviewForm` 与金额平衡状态；新增 App 层 `HotelStayReviewView`；更新离线回归断言和编译清单；补齐四语确认页文案；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未新增持久化；未写 SQLite schema、CloudKit schema、BackupBundle 或 iCloud 同步；未生成 `HotelStayRecord`；未生成或关联普通 `Transaction`；未串接 PDF 导入后的实际导航入口；未新增酒店消费列表 / 详情页；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`HotelStayReviewForm` 可从 `HotelStayDraft` 初始化酒店、入住、房型、订单号、币种、金额拆分、支付方式、来源、置信度和原始文本；金额拆分支持与总额做平衡复核；确认会回填 `.confirmed` 草稿并刷新编辑后的 parsed payload；拒绝会回填 `.rejected` 草稿；`HotelStayReviewView` 展示酒店、入住、费用、来源、置信度和原始文本，提供确认 / 拒绝动作；四语本地化 key 已补齐。
- 未完成内容：确认后的正式归档、普通支出流水生成、草稿持久化、导入流程导航、列表页和详情页留给后续 GOAL；当前仍不会自动正式入账。
- 测试情况：先新增 `verifyHotelStayReviewForm` 离线回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `HotelStayReviewForm` 和金额平衡枚举失败；实现表单后再次执行离线回归通过。随后执行主 App iOS generic build，首次因 `Section` header / footer 重载推断失败报错，修正为显式 header / footer 后再次构建通过。
- 风险与注意事项：当前确认页是可复用 SwiftUI 组件，尚未接入真实 PDF 导入导航和持久化链路；金额字段先复用文本输入解析，后续正式入账时还需要在归档层再次校验总额、日期和账本归属。
- 回滚方式：移除 `HotelStayReviewForm.swift`、`HotelStayReviewView.swift`、离线回归新增断言和编译清单改动，并回退四语本地化、版本文档、CHANGELOG 与本日志条目即可；当前无数据迁移。
- 结论：GOAL-1813 的识别结果确认页第一版已完成，可进入 `GOAL-1814` 正式归档与普通 `Transaction` 关联。
- 下一步建议：实现确认后创建 `HotelStayRecord` 并生成或关联普通支出流水，继续保持用户确认后才写正式账本。

### ITER-228 GOAL-1812 酒店水单解析管线
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1812
- 类型：能力增强 / Core 解析 / 测试
- 目标：建立来源无关的酒店水单解析管线，把 PDFKit 或后续邮箱 / Worker 传入的文本转换为结构化酒店水单 payload，并进入用户复核状态。
- 改动范围：新增 Core 层 `HotelFolioParsePayloadBuilder`、`HotelFolioOpenAICompatibleCodec`、`HotelFolioParsePipeline`；更新离线回归断言和编译清单；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未接真实网络请求或 API key；未新增设置入口、确认页、列表页、详情页或侧边栏入口；未持久化 `HotelStayDraft`；未生成 `HotelStayRecord` 或普通 `Transaction`；未写 SQLite schema、CloudKit schema、BackupBundle、iCloud 同步；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`HotelFolioParsePayloadBuilder` 支持从任意 `HotelFolioSourceType` 的原文生成脱敏 payload，并保留酒店名、确认号等解析所需信息；脱敏覆盖邮箱、手机号、会员号 / 身份证 / 护照类编号和银行卡号；`HotelFolioOpenAICompatibleCodec` 生成 OpenAI-compatible JSON request，prompt 约束酒店水单 schema，并能解码 direct JSON 或 chat completion content；`HotelFolioParsePipeline` 可将解析 payload 回填到原 draft，状态推进为 `.needsReview`，同时保留来源、原文、目标账本和置信度。
- 未完成内容：外部模型调用仍需 App 层 client 接入；金额平衡校验、字段编辑、拒绝草稿、正式归档和普通流水关联留给后续 GOAL；当前不自动入账。
- 测试情况：先新增 `verifyHotelFolioParsePipeline` 离线回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `HotelFolioParsePayloadBuilder`、`HotelFolioOpenAICompatibleCodec`、`HotelFolioParsePipeline` 失败；实现后第一次回归暴露全可选 schema 会把 chat wrapper 误解为空 payload，修正为必须包含至少一个酒店字段后再次执行，结果 PASS。
- 风险与注意事项：当前脱敏规则覆盖常见敏感字段，但不同酒店 PDF 的会员号、证件号和支付卡号格式差异较大，后续真实样例进入前需要继续扩充脱敏回归；Core 只生成外部模型 payload 和解析结果，不负责网络请求、API key、持久化或 UI。
- 回滚方式：移除 `HotelFolioParsePipeline.swift`、离线回归新增断言和编译清单改动，并回退版本文档、CHANGELOG 与本日志条目即可；当前无数据迁移。
- 结论：GOAL-1812 的来源无关解析管线已完成第一版，后续可进入 `GOAL-1813` 识别结果确认页。
- 下一步建议：实现酒店水单确认页，展示可编辑字段、置信度、原始文本摘要和拒绝 / 继续复核动作，仍保持用户确认前不写正式账本。

### ITER-227 GOAL-1811 酒店水单 PDF 文本提取
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1811
- 类型：能力增强 / macOS 导入 / 测试
- 目标：建立酒店水单手动 PDF 导入的本地适配层，使用 PDFKit 提取文本并生成待处理草稿。
- 改动范围：新增 App 层 `HotelFolioManualPDFImporter`；新增 PDF 导入 smoke 脚本和临时 PDF 生成测试；补齐四语错误提示；回填版本计划、CHANGELOG 与本迭代日志。
- 未改动范围：未接外部模型；未实现 `HotelFolioParsePipeline`；未新增确认页、列表页、详情页或侧边栏入口；未写 SQLite schema、CloudKit schema、BackupBundle、iCloud 同步或普通 `Transaction` 生成逻辑；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：`HotelFolioManualPDFImporter` 支持安全作用域 URL 读取、本地 PDF 类型校验、PDFKit 文本提取、`HotelStayDraft(status: .textExtracted)` 生成、来源文件名和目标账本 ID 保留；错误态覆盖非 PDF、无法打开 PDF 和 PDF 无可读文本；四语错误文案已补齐。
- 未完成内容：酒店消费可视化入口仍未实现；PDF 文本尚未进入模型解析；草稿尚未持久化；用户确认和正式入账仍留给后续 GOAL。
- 测试情况：先新增 `scripts/run_hotel_pdf_import_smoke.sh` 和 smoke 断言，执行后因缺少 `HotelFolioManualPDFImporter` / `HotelFolioManualPDFImportError` 失败；实现 importer 后再次执行 `bash scripts/run_hotel_pdf_import_smoke.sh`，结果 PASS。
- 风险与注意事项：PDFKit 只能提取文本型 PDF；扫描图片型水单仍会进入无可读文本错误，后续如要支持扫描 PDF 需要单独 OCR 设计。当前 importer 只生成内存草稿，不承担持久化和入账。
- 回滚方式：移除 `HotelFolioManualPDFImporter.swift`、PDF smoke 脚本、四语错误文案和版本文档 / CHANGELOG / 本日志条目即可；当前无数据迁移。
- 结论：GOAL-1811 的 PDFKit 文本提取适配层已完成，后续可进入 `GOAL-1812` 解析管线。
- 下一步建议：实现 `HotelFolioParsePipeline`，让来源无关的文本输入转换为结构化酒店水单 payload，并继续保持用户确认前不入账。

### ITER-226 GOAL-1810 酒店消费模型与 schema
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1810
- 类型：能力增强 / Core 模型 / 测试
- 目标：为酒店水单 A 阶段建立来源类型、解析 schema、待确认草稿和正式酒店消费记录模型。
- 改动范围：新增 `AutoLedgerCore` 酒店消费模型文件；更新离线回归编译清单和断言；回填 `versions/v1.6.1-plan.md`、CHANGELOG 与本迭代日志。
- 未改动范围：未接 PDFKit；未接外部模型解析管线；未新增 macOS UI；未写 SQLite schema、CloudKit schema、BackupBundle、iCloud 同步或普通 `Transaction` 生成逻辑；未修改 signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：新增 `HotelFolioSourceType`、`HotelStayDraftStatus`、`HotelFolioParsedPayload`、`HotelStayDraft`、`HotelStayRecord`；解析 payload 支持酒店水单 snake_case schema；草稿模型保留来源、目标账本、原始文本、解析结果、置信度和状态；正式记录保留酒店、入住、金额拆分、来源和关联流水 ID。
- 未完成内容：模型尚未持久化；`Transaction.hotelStayRecordId` 仍未落地；酒店消费列表 / 详情 / 确认页、PDF 手动导入、PDFKit 文本提取和外部模型解析均留给后续 GOAL。
- 测试情况：先新增酒店模型离线回归并执行 `bash scripts/run_offline_regression.sh`，因缺少 `HotelFolioParsedPayload`、`HotelStayDraft`、`HotelStayRecord` 等类型而失败；实现模型后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS。
- 风险与注意事项：日期字段当前先按水单 schema 的字符串保留，后续确认页或持久化层需要再决定标准化 Date 存储策略；金额拆分当前只建模，不做平衡校验或自动入账。
- 回滚方式：移除 `HotelStay.swift`、离线回归新增断言和编译清单改动，并回退版本文档、CHANGELOG 与本日志条目即可；当前无数据迁移。
- 结论：GOAL-1810 已完成第一版 Core 模型与 schema 基线。
- 下一步建议：进入 `GOAL-1811`，在 macOS 路径实现手动 PDF 导入与 PDFKit 文本提取，并只生成待处理输入，不直接入账。

### ITER-225 GOAL-1852 日文支持基线落地
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：GOAL-1852
- 类型：能力增强 / 本地化 / 测试
- 目标：在不修改业务逻辑和对外商店版本号的前提下，落地日文支持第一段基线。
- 改动范围：新增主 App、Watch App、Watch Widgets、Control Widget Extension、Share Extension 的 `ja.lproj` 字符串资源；Xcode project `knownRegions` 新增 `ja`；新增 `scripts/check_localization_coverage.py`；更新 `versions/v1.6.1-plan.md`、README / README.en Roadmap、CHANGELOG 与本迭代日志。
- 未改动范围：未修改 OCR、账本、订阅、酒店水单业务逻辑；未修改 SQLite schema、CloudKit schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、signing、entitlements、Xcode Cloud 脚本或 `MARKETING_VERSION`。
- 完成内容：五组资源集均已具备 `ja.lproj`；主 App、Watch App、Watch Widgets、Control Widget Extension、Share Extension 的日文 `.strings` 文件通过 plist lint；新增覆盖检查脚本可验证 `zh-Hans` / `zh-Hant` / `en` / `ja` 的 `.strings` 文件存在性和 key 集合一致性；`v1.6.1` 计划明确内部开发线继续映射 ASC `1.5.0`。
- 未完成内容：酒店消费和多账本新功能文案需随功能实现继续补齐；日文截图文案、ASC metadata、TestFlight notes、Review Notes、术语表和人工审校尚未完成；未做真机日文 UI 截断目检。
- 测试情况：先执行 `python3 scripts/check_localization_coverage.py`，确认缺少 `ja.lproj` 时脚本失败；补齐资源后再次执行该脚本，结果 PASS；执行 `find AutoLedger -path '*/build' -prune -o -path '*lproj/*.strings' -print0 | xargs -0 plutil -lint`，结果 PASS；执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -destination 'generic/platform=iOS' build`，结果 PASS；构建产物中抽查到 5 个 `ja.lproj` 目录，覆盖主 App、Watch App、Watch Widget、Control Widget 和 Share Extension。
- 风险与注意事项：日文文案是发布前基线，仍需人工审校和多设备目检；App Store 元数据和截图不得使用未经审校的日文；后续新增字符串必须同步更新四语资源并跑覆盖检查。
- 回滚方式：移除新增 `ja.lproj` 资源、覆盖检查脚本和 `knownRegions` 中的 `ja`，并回退版本文档、README、CHANGELOG 与本日志条目即可；不涉及数据迁移。
- 结论：GOAL-1852 第一段日文资源基线已落地，对外版本仍保持 ASC `1.5.0`。
- 下一步建议：把覆盖检查接入本地回归清单；随后按 GOAL-1810 / GOAL-1840 推进酒店水单和多账本时同步补新增 key 的日文文案。

### ITER-224 v1.6.1 日文支持纳入范围
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：规划 / 本地化
- 类型：文档 / 产品设计 / 本地化规划
- 目标：将 `ja` 从新增语言候选调整为 `v1.6.1` 明确落地的日文支持，并更新 Roadmap 与版本计划。
- 改动范围：更新 `versions/v1.6.1-plan.md`、`README.md`、`README.en.md`、`CHANGELOG.md` 与本迭代日志。
- 未改动范围：未新增 `ja.lproj`；未修改 App 源码、本地化字符串文件、截图管线配置、ASC 元数据文件、业务逻辑、SQLite schema、CloudKit schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：`v1.6.1` 多语言目标明确包含日文支持；范围覆盖 `ja.lproj`、App 内关键路径、酒店消费、多账本、设置、错误提示、App Intents / Shortcuts、截图文案、ASC 元数据、TestFlight notes、Review Notes、术语表和人工审校清单；`ko` 保留为后续候选；`GOAL-1852` 从候选准备调整为 P0 的日文支持落地。
- 未完成内容：本轮不落日文实际 strings、不做截图导出、不提交 ASC 日文元数据、不做人工审校。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `rg -n "日文支持|ja\\.lproj|ja|Japanese|GOAL-1852|ko|候选新增语言|新增语言候选|待本轮文档校验" versions/v1.6.1-plan.md README.md README.en.md CHANGELOG.md process/iteration-log.md`，确认 `ja` 已作为日文支持范围落入版本计划、Roadmap、CHANGELOG 和 GOAL 队列，`ko` 仅保留为后续候选；本轮仅文档变更，未运行构建或业务回归。
- 风险与注意事项：日文发布前必须人工审校，尤其是酒店水单、账本、默认账本、归档账本、外部辅助识别等术语；未审校日文不应进入 App Store 元数据。
- 回滚方式：如日文支持需要推迟，可把 `GOAL-1852` 恢复为候选评估，并将 README / CHANGELOG / 本日志中的“日文支持”改回“新增语言候选评估”。
- 结论：日文支持已纳入 `v1.6.1` 规划范围，但实现仍需后续 GOAL 落地。
- 下一步建议：实现前先建立日文术语表和 key 命名清单，再新增 `ja.lproj`，避免后续翻译反复替换 key。

### ITER-223 v1.6.1 三主线规划扩展
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：规划 / 版本设计
- 类型：文档 / 产品设计 / 架构规划
- 目标：在既有酒店水单规划基础上，补齐 `v1.6.1` 遗留的多账本基础能力和新一轮多语言支持规划，明确本版本三条主线。
- 改动范围：扩展 `versions/v1.6.1-plan.md`；更新 `README.md`、`README.en.md` Roadmap；更新 `CHANGELOG.md` 与本迭代日志。
- 未改动范围：未实现代码；未修改业务逻辑、SQLite schema、CloudKit schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：`v1.6.1` 文档从单一酒店水单规划扩展为酒店水单识别、多账本基础和多语言支持三条主线；补充 `LedgerProfile`、默认账本迁移、`Transaction.ledgerId`、账本创建 / 重命名 / 归档 / 默认账本 / 账单移动、酒店消费账本归属、统计 / 导入 / 订阅 / 展示端账本口径；补充三语文案覆盖、硬编码字符串审计、Review Notes / 截图文案维护、`ja` 新语言候选和对应 GOAL 队列。
- 未完成内容：本轮不实现多账本 schema、迁移、UI、本地化文件或新增语言；酒店水单 B/C 阶段仍只作为后续路线记录。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `rg -n "酒店水单 A 阶段|多账本基础|新一轮多语言|LedgerProfile|Transaction\\.ledgerId|targetLedgerId|HotelStayRecord\\.ledgerId|ja|GOAL-1840|GOAL-1850|待本轮文档校验" versions/v1.6.1-plan.md README.md README.en.md CHANGELOG.md process/iteration-log.md`，确认三主线、模型字段、GOAL 队列和 Roadmap / 变更记录均可检索；本轮仅文档变更，未运行构建或业务回归。
- 风险与注意事项：多账本后续实现会涉及 SQLite / CloudKit / BackupBundle / Widget / Watch / 展示端口径，需要按 GOAL 拆小后逐步验证；新增语言不得使用未经审校的机器翻译直接发布。
- 回滚方式：如 `v1.6.1` 需要重新收窄，可回退本轮对 `versions/v1.6.1-plan.md`、README Roadmap、CHANGELOG 和本日志条目的文档变更；不涉及代码和数据迁移。
- 结论：`v1.6.1` 已调整为三主线规划，`v1.6.0 / ASC 1.5.0` 发布线不再阻碍新版本文档设计。
- 下一步建议：实现前优先冻结 `LedgerProfile` / `Transaction.ledgerId` 迁移策略，再启动酒店水单模型与本地化 key 设计，避免三条主线在数据模型层反复返工。

### ITER-222 v1.6.1 酒店水单识别规划
- 日期：2026-06-24
- 所属版本：v1.6.1
- 所属阶段：规划 / A 阶段设计
- 类型：文档 / 产品设计 / 架构规划
- 目标：在版本规划和 roadmap 中补充 macOS 酒店水单识别与酒店消费归档设计，并明确当前版本只规划 A 阶段手动 PDF 导入识别。
- 改动范围：新增 `versions/v1.6.1-plan.md`；更新 `README.md`、`README.en.md` Roadmap；更新 `CHANGELOG.md` 与本迭代日志。
- 未改动范围：未实现代码；未修改业务逻辑、SQLite schema、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements 或 Xcode Cloud 脚本。
- 完成内容：新增酒店消费模块版本设计，覆盖 A/B/C 三阶段路线、来源无关识别管线、`HotelFolioSourceType`、`HotelStayDraft`、`HotelStayRecord`、`Transaction` 关联、酒店水单 schema、macOS 列表 / 详情 / 确认页建议、隐私安全要求和当前版本 A 阶段 GOAL 拆分。
- 未完成内容：B 阶段本地邮箱半自动导入和 C 阶段 Worker 云端自动化仅作为后续路线记录；本轮不做实现、不新增测试样例、不接 PDFKit 或外部模型运行时。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `rg -n "v1\\.6\\.1|HotelStayDraft|HotelFolioSourceType|待本轮" versions/v1.6.1-plan.md README.md README.en.md CHANGELOG.md process/iteration-log.md`，确认新版本规划、数据模型和 roadmap 入口可检索；本轮仅文档变更，未运行构建或业务回归。
- 风险与注意事项：后续实现时必须保持所有识别结果默认待确认，邮箱授权码不得上传云端，云模型调用前需要尽量脱敏；App Review 需要示例 PDF 或 Demo Mode，避免审核员必须登录真实邮箱。
- 回滚方式：如暂不进入 v1.6.1 路线，可回退 `versions/v1.6.1-plan.md`、README Roadmap、CHANGELOG 和本日志条目；不涉及代码和数据迁移。
- 结论：v1.6.1 酒店水单识别设计已进入文档规划，当前实现范围限定为 A 阶段手动 PDF 导入。
- 下一步建议：进入实现前先冻结 A 阶段字段 schema、Demo PDF、隐私脱敏规则和 `Transaction` 关联策略，再拆分最小实现 GOAL。

### ITER-221 GOAL-1770E ASC 出口合规与平台元数据修正
- 日期：2026-06-24
- 所属版本：v1.6.0
- 所属阶段：GOAL-1770
- 类型：发布配置 / 文档 / ASC 元数据
- 目标：补齐 tvOS / visionOS 新平台的出口合规标志，并修正 ASC 1.5.0 元数据口径，避免把 tvOS / visionOS 写成版本新增功能。
- 改动范围：`AutoLedgerTV` 与 `AutoLedgerVision` 的 Info.plist / build settings；`versions/v1.6.0-review-notes.md` 的 ASC 元数据草稿；`CHANGELOG.md` 与本迭代日志。
- 未改动范围：未修改 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、CloudKit schema、业务代码、截图管线、Xcode Cloud 脚本或 App Store Connect 线上配置。
- 完成内容：`AutoLedgerTV` 和 `AutoLedgerVision` 均新增 `ITSAppUsesNonExemptEncryption = false`；ASC 元数据草稿增加 App Description、平台描述、What’s New 和 Export Compliance 口径；tvOS / visionOS 被描述为只读展示平台，而不是 1.5.0 的新增功能条目。
- 未完成内容：ASC 页面仍需人工根据本草稿复制粘贴并最终确认；出口合规最终选择仍以 App Store Connect 表单为准。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `plutil -lint AutoLedger/AutoLedgerTV/Info.plist AutoLedger/AutoLedgerVision/Info.plist`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-tv-export-check -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-vision-export-check -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`，结果 PASS；产物检查确认 `AutoLedgerTV.app/Info.plist` 与 `AutoLedgerVision.app/Info.plist` 均包含 `ITSAppUsesNonExemptEncryption => false`。
- 风险与注意事项：当前口径基于 App 不提供 VPN、加密通信、端到端通信工具或通用加密能力，只使用系统平台能力、iCloud 和 HTTPS；如后续引入自研加密或新的安全通信能力，需要重新评估出口合规。
- 回滚方式：如 ASC 要求改用人工出口合规问卷或合规文档，可移除 tvOS / visionOS 的 `ITSAppUsesNonExemptEncryption` 标志，并按 ASC 要求提交文档；元数据文案可回退到上一版草稿。
- 结论：代码侧标志与元数据草稿已补齐，下一步重新验证 tvOS / visionOS 产物 Info.plist。
- 下一步建议：Xcode Cloud archive 后抽查上传包 Info.plist 中的 `ITSAppUsesNonExemptEncryption`，并在 ASC 页面将 tvOS / visionOS 放入 App 描述，不放入版本更新说明。

### ITER-220 GOAL-1770D tvOS / visionOS ASC 资产与 entitlement 修复
- 日期：2026-06-24
- 所属版本：v1.6.0
- 所属阶段：GOAL-1770
- 类型：Bugfix / 发布资产 / ASC 上传
- 目标：修复 tvOS / visionOS 新平台上传时的 App Icon、Top Shelf、Info.plist 和 tvOS push entitlement 校验问题。
- 改动范围：补齐 `AutoLedgerVision` visionOS `AppIcon.solidimagestack` 三层 PNG；补齐 `AutoLedgerTV` tvOS 分层 App Icon、App Store Icon、Top Shelf Image 和 Top Shelf Wide Image；新增 `AutoLedgerTV/Info.plist`；补充 `AutoLedgerTV` 的 `aps-environment` entitlement 与 build setting；调整 `project.pbxproj` 排除 tvOS `Info.plist` 资源复制；更新 `CHANGELOG.md` 和 `versions/v1.6.0-plan.md`。
- 未改动范围：未修改主 App Bundle ID、DEVELOPMENT_TEAM、主 App App Group、主 App iCloud Container、CloudKit schema、业务代码、账本数据、截图管线脚本或 App Store Connect 线上配置。
- 完成内容：visionOS App Icon 不再套用 iOS 方形外壳，改为平台专用 Back / Middle / Front 分层素材；tvOS App Icon 和 Top Shelf 资产均有对应 PNG；tvOS 产物内包含 `CFBundleIcons.CFBundlePrimaryIcon`、`TVTopShelfImage.TVTopShelfPrimaryImageWide`、`aps-environment` 和 `Assets.car`；visionOS 产物内包含 `CFBundleIcons.CFBundlePrimaryIcon = AppIcon`，`Assets.car` 中可查到 `AppIcon / Back / Middle / Front`。
- 未完成内容：尚未重新跑 Xcode Cloud archive / ASC 上传验证；tvOS / visionOS signing profile 是否已刷新到包含 iCloud + push entitlement 仍需云端或 Xcode 上传确认。
- 测试情况：执行 `find AutoLedger/AutoLedgerTV/Assets.xcassets AutoLedger/AutoLedgerVision/Assets.xcassets -name Contents.json -print0 | xargs -0 -n1 python3 -m json.tool >/dev/null`，结果 PASS；执行 `plutil -lint AutoLedger/AutoLedgerTV/Info.plist AutoLedger/AutoLedgerTV/AutoLedgerTV.entitlements AutoLedger/AutoLedgerVision/Info.plist`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-tv-asset-check -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-vision-asset-check -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`，结果 PASS；产物 Info.plist / entitlements / Assets.car 检查均 PASS。
- 风险与注意事项：本轮是 Debug generic build 级别验证，最终是否完全消除 ITMS 报错仍以 Xcode Cloud archive 上传结果为准；tvOS 带 CloudKit entitlement 时要求 `aps-environment`，因此发布 profile 也必须刷新；图标为首版平台适配素材，仍建议在 ASC / TestFlight 中目检。
- 回滚方式：如需要回退，可移除新增 tvOS / visionOS 平台资产 PNG、`AutoLedgerTV/Info.plist`、tvOS `aps-environment` 设置与 project exception；但回退后 ASC 新平台上传会再次触发相同校验问题。
- 结论：代码侧和本地产物结构已修复，可以重新触发 Xcode Cloud archive / ASC 上传验证。
- 下一步建议：推送后重新跑 Xcode Cloud 新平台 archive；若 ASC 仍报图标或 entitlement，再对 archive 产物执行同样的 Info.plist / entitlements / `assetutil --info Assets.car` 检查。

### ITER-219 GOAL-1770C ASC 新平台 Bundle ID 与 visionOS 图标修复
- 日期：2026-06-24
- 所属版本：v1.6.0
- 所属阶段：GOAL-1770
- 类型：Bugfix / 发布配置 / ASC 上传
- 目标：修复 ASC 上传 tvOS / visionOS 新平台构建时出现的 `ITMS-90055` Bundle ID 不一致和 `ITMS-90970` visionOS App Icon Info.plist 缺失问题。
- 改动范围：调整 `AutoLedgerTV` / `AutoLedgerVision` target 的 `PRODUCT_BUNDLE_IDENTIFIER`；补充 `AutoLedgerVision/Info.plist` 的 visionOS App Icon 声明；同步截图管线配置、README、v1.6.0 计划和 CHANGELOG。
- 未改动范围：未修改主 App Bundle ID、DEVELOPMENT_TEAM、主 App App Group、主 App iCloud Container、CloudKit schema、业务代码、账本数据、Xcode Cloud 脚本或 App Store Connect 线上配置。
- 完成内容：tvOS / visionOS 新平台 target 均对齐现有 ASC App 记录的 Bundle ID `top.darkrio326.AutoLedger`；visionOS 包显式声明 `CFBundleIcons -> CFBundlePrimaryIcon = AppIcon`。
- 未完成内容：尚未重新跑 Xcode Cloud archive / Transporter 上传验证；签名 profile 可能需要 Xcode 或 Xcode Cloud 重新刷新。
- 测试情况：待本轮构建验证补记。
- 风险与注意事项：如果未来要把 tvOS / visionOS 做成独立 ASC App，才应使用 `.tv` / `.vision` 这类独立 Bundle ID；当前路线是加入现有 AutoLedger App 记录，因此必须保持 Bundle ID 一致。重新上传前需要确认主 App ID `top.darkrio326.AutoLedger` 的 iCloud / CloudKit capability 和 provisioning profile 已覆盖新平台。
- 回滚方式：如决定创建独立 tvOS / visionOS ASC App，可恢复 `.tv` / `.vision` Bundle ID，并在 App Store Connect 创建独立应用记录；否则不建议回滚。
- 结论：代码侧修复完成，下一步重新构建 archive 并上传验证 ASC 校验结果。
- 下一步建议：跑 tvOS / visionOS Release archive 或 Xcode Cloud workflow；如果 ASC 仍报图标问题，再检查 archive 内 `Info.plist` 的 `CFBundleIcons.CFBundlePrimaryIcon` 实际值。

### ITER-218 GOAL-1770B tvOS / visionOS 截图管线扩展
- 日期：2026-06-24
- 所属版本：v1.6.0
- 所属阶段：GOAL-1770
- 类型：能力增强 / 发布资产 / 截图管线
- 目标：在现有 `tools/appstore-screenshots` 管线内补齐 tvOS 和 visionOS 平台截图导出，不新建平行 marketing 目录，不影响真实 App 功能和 Xcode Cloud 发布链。
- 改动范围：扩展 `screenshots.json` 的 app / target / shot 配置；新增 `export_tvos.sh`、`export_visionos.sh`；扩展 `export.sh`、`render_marketing.py`、`build_preview.py`、README 和截图管线审计文档；为 `AutoLedgerTV` / `AutoLedgerVision` 增加 screenshot mode scene 参数入口。
- 未改动范围：未上传 App Store Connect；未引入真实用户数据；未修改 Bundle ID、DEVELOPMENT_TEAM、主 App App Group、主 App iCloud Container、CloudKit schema、entitlements、Xcode Cloud 脚本或生产账本读写链路。
- 完成内容：Apple TV 支持 `overview / categories / trends / summary` 4 张截图；visionOS 支持 `dashboard / categories / timeline` 3 张截图；`preview.html` 增加 Apple TV 和 visionOS 分组；截图模式使用 DEBUG simulator 虚构数据，可直接落到对应展示页。
- 未完成内容：本轮只验证 `zh-Hans` 导出；`zh-Hant` / `en` 仍需发布前按相同命令导出和目检。tvOS / visionOS 真机或 TestFlight 下的 iCloud private database 读取仍不由截图管线验证替代。
- 测试情况：执行 `python3 -m json.tool tools/appstore-screenshots/config/screenshots.json`，结果 PASS；执行 `python3 -m py_compile tools/appstore-screenshots/scripts/render_marketing.py tools/appstore-screenshots/scripts/build_preview.py`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-shot-tv-build -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`，结果 PASS；执行 `xcodebuild -quiet -derivedDataPath /tmp/autoledger-shot-vision-build -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`，结果 PASS；执行 `bash tools/appstore-screenshots/scripts/export.sh --tvos-only --locale zh-Hans`，结果 PASS，生成 4 张 `3840x2160` store PNG；执行 `bash tools/appstore-screenshots/scripts/export.sh --visionos-only --locale zh-Hans`，结果 PASS，生成 3 张 `3840x2160` store PNG。
- 风险与注意事项：visionOS 模拟器截图是窗口在模拟器环境中的合成画面，用于 ASC 平台素材首版和视觉验证，不能代表真机空间交互 smoke；tvOS / visionOS 仍需在 ASC 新平台提交前做人工文案、裁切、截图顺序和真实 TestFlight 数据读取确认。
- 回滚方式：回退本轮截图配置、两个新增导出脚本、`export.sh` / `render_marketing.py` / `build_preview.py` 扩展，以及 tvOS / visionOS screenshot scene 参数入口即可；输出目录下 PNG 不纳入版本控制。
- 结论：本轮完成，截图管线已经覆盖 iPhone / iPad / Mac / Apple Watch / Apple TV / visionOS 的首版平台分组；tvOS / visionOS `zh-Hans` 输出可进入人工目检。
- 下一步建议：发布前运行 `--tvos-only` / `--visionos-only` 的 `zh-Hant` 和 `en` 导出，打开 `tools/appstore-screenshots/output/preview.html` 逐张目检；随后再决定是否直接上传 ASC 新平台素材。

### ITER-217 GOAL-1770 v1.6.0 发布资产与 smoke 基线
- 日期：2026-06-24
- 所属版本：v1.6.0
- 所属阶段：GOAL-1770
- 类型：测试 / 文档 / 发布治理
- 目标：为 App Store / ASC 1.5.0 建立 v1.6.0 发布前命令级 smoke baseline、审核说明草稿和人工门禁清单。
- 改动范围：新增 `versions/v1.6.0-regression-baseline.md`、`versions/v1.6.0-review-notes.md`；更新 `versions/v1.6.0-plan.md` 的 GOAL 状态和执行记录；同步 `CHANGELOG.md` 与本迭代日志。
- 未改动范围：未修改业务代码、Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置；未上传真实支付截图或真实用户数据。
- 完成内容：`GOAL-1760` 标记为代码侧完成，`GOAL-1770` 标记为进行中；记录本地命令级构建矩阵、既有 warning、平台 smoke 边界、CloudKit Production schema 门禁和 ASC Review Notes 草稿。
- 未完成内容：Xcode Cloud archive、TestFlight 多平台安装 smoke、ASC 截图 / App Preview / 平台元数据最终检查仍需人工执行；tvOS / visionOS 真机或 TestFlight iCloud private database 读取仍需实测。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `bash scripts/run_golden_regression.sh`，结果 PASS，36 个 case 通过；执行 `xcodebuild -list -workspace AutoLedger/AutoLedger.xcworkspace`，结果 PASS；执行 iOS generic、Mac Catalyst、watchOS generic、tvOS generic、visionOS generic Debug build，结果均 PASS。首次并行跑 iOS / Mac 时遇到 DerivedData `build.db` 锁，已改用独立 `-derivedDataPath` 顺序构建并通过。
- 风险与注意事项：当前只是本地命令级 smoke，不替代 Xcode Cloud archive 和 TestFlight 真机 / 安装验证。tvOS / visionOS simulator DEBUG 演示数据不能证明 CloudKit 真实同步成功；如果随本版开放，需要先确认 `LedgerDashboardSnapshot` Production schema、平台 App ID capability、provisioning profile 和 ASC 素材。
- 回滚方式：删除新增的两份 `versions/v1.6.0-*` 文档，并恢复 `versions/v1.6.0-plan.md`、`CHANGELOG.md` 和本日志本轮改动即可；本轮无代码或 schema 迁移。
- 结论：本轮完成命令级发布基线文档，主发布线可进入 Xcode Cloud / TestFlight 人工验证；tvOS / visionOS 是否随 ASC 1.5.0 正式开放仍需人工决策。
- 下一步建议：先跑 Xcode Cloud archive 和 TestFlight 多平台安装；确认 CloudKit Production schema；若 tvOS / visionOS 平台素材不足，可把它们继续作为内部预览，不阻塞 iPhone / iPad / Watch / Mac 主平台提交。

### ITER-216 GOAL-1760D tvOS / visionOS 多端 polish 收口
- 日期：2026-06-22
- 所属版本：v1.6.0
- 所属阶段：GOAL-1760
- 类型：UI / 多平台展示 / 调试体验
- 目标：收口 Apple TV 和 visionOS 展示版在模拟器与大屏场景下的第一版体验，减少空数据、布局错位和操作反馈不明确的问题。
- 改动范围：调整 tvOS 看板 header、按钮、内容区固定高度、四个 tab 顶部对齐、右侧列宽和遥控器左右切换；为 tvOS 增加 CloudKit 账号状态、dashboard snapshot、远端账本兜底读取诊断和 DEBUG simulator 演示数据；调整 visionOS 隐私按钮文案，增加宽屏三栏空间布局、轻量 3D 倾斜层次和 DEBUG simulator 演示数据；新增 tvOS / visionOS shared scheme，便于 `xcodebuild -scheme AutoLedgerTV` / `AutoLedgerVision` 稳定构建。
- 未改动范围：未让 tvOS / visionOS 写入正式账本；未新增导入、编辑、删除、清洗或多账本；未修改 Bundle ID、DEVELOPMENT_TEAM、主 App App Group、主 App iCloud Container、CloudKit schema 或 Xcode Cloud 脚本；未把模拟器样例数据带入 Release。
- 完成内容：Apple TV 模拟器在未登录 iCloud 或无快照时可通过 DEBUG simulator 数据继续验证视觉和焦点；tvOS 四个 tab 的内容顶部更一致，隐私 / 刷新按钮可读性更明确；visionOS 在宽屏窗口下展示为月度看板、时间线 / 最近账单和分类卡片三栏空间布局，紧凑窗口继续使用原有布局。
- 未完成内容：tvOS / visionOS 真机或 TestFlight 上的 iCloud private database 读取仍需人工 smoke；tvOS 分类页右侧卡片与最近账单的视觉距离还可继续微调；tvOS / visionOS App Store 平台素材和截图管线尚未进入 `GOAL-1770`。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build`，结果 PASS，仅有 tvOS target 不依赖 AppIntents 时的 metadata extraction skipped warning；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`，结果 PASS。真机 / TestFlight 数据读取不由模拟器结果替代。
- 风险与注意事项：Apple TV / visionOS 模拟器可能无法稳定登录 iCloud，因此 DEBUG simulator 数据只用于视觉和焦点验证，不能作为 CloudKit 同步成功证据。发布前仍需确认 `LedgerDashboardSnapshot` Production schema、平台 App ID 的 iCloud CloudKit capability 和 provisioning profile。
- 回滚方式：如新平台 polish 影响构建或交互，可回退 `AutoLedgerTV/ContentView.swift`、`AutoLedgerVision/ContentView.swift` 和新增 shared scheme，保留 `GOAL-1755` 主 App 快照发布链路独立验证。
- 结论：本轮完成后可将 `GOAL-1760` 视为代码侧基本收尾，下一步进入 `GOAL-1770` 发布资产与 smoke。
- 下一步建议：跑完整构建门禁后提交本轮；随后补 `v1.6.0` 发布前 smoke 清单，决定 tvOS / visionOS 是否随 ASC 1.5.0 作为正式平台推进，或先作为内部预览保留。

### ITER-215 GOAL-1760C 交易编辑页输入提交修复
- 日期：2026-06-21
- 所属版本：v1.6.0
- 所属阶段：GOAL-1760
- 类型：Bugfix / UI / 真机诊断
- 目标：修复用户在商户输入框补全中文终点站后，输入框失焦即丢失新输入内容，导致保存仍使用旧商户名的问题。
- 改动范围：`TransactionEditorView` 将商户输入框替换为 UIKit-backed `CompositionSafeTextField`，通过 `UITextFieldDelegate` 在编辑变化和选区变化时同步当前文本；失焦时避免系统取消 marked text 后覆盖已同步绑定值；保存按钮结束输入会话并等待一个主线程 tick 后再读取 `editedTransaction()`；同步更新 `CHANGELOG.md` 和 `versions/v1.6.0-plan.md`。
- 未改动范围：未修改 iCloud 同步策略、SQLite / CloudKit schema、地铁识别、金额计算、外部模型链路、Bundle ID、entitlements 或 Xcode Cloud 脚本。
- 完成内容：根据 Debug 导出确认本次不是远端覆盖：iCloud 启动拉取、编辑后增量推送均成功；失败点在保存前，`LedgerStore.updateTransaction` 收到的 before / after 均为旧商户。商户输入框改为更稳的 UIKit 文本桥接，专门处理中文输入法组合文本在失焦时回退的问题。
- 未完成内容：尚未做用户真机复测；若仍复现，需要进一步确认对应输入法的 marked text 是否进入 `UITextField.text`，再考虑 `shouldChangeCharactersIn` 草稿缓冲或显式完成输入按钮。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedger -configuration Debug -destination 'generic/platform=iOS' build`，结果 PASS。
- 风险与注意事项：本轮只把商户字段切到 UIKit-backed 输入框，金额 / 备注仍使用 SwiftUI TextField。UIKit bridge 需要真机输入法复测，尤其是第三方中文键盘。
- 回滚方式：恢复 `TransactionEditorView` 商户字段为 SwiftUI `TextField`，移除 `CompositionSafeTextField` 和保存前 resign / yield 逻辑，并恢复本轮文档记录。
- 结论：本轮代码侧完成，商户字段中文组合文本失焦丢失问题已针对性修复。
- 下一步建议：真机编辑 `地铁：埌西→`，输入 `万象城` 后先失焦观察文本是否保留，再保存并导出 Debug 记录确认 `账单编辑开始` 中的新商户为完整文本。

### ITER-214 GOAL-1760B 最近本机编辑保护窗口与同步日志导出
- 日期：2026-06-20
- 所属版本：v1.6.0
- 所属阶段：GOAL-1760
- 类型：Bugfix / 数据同步 / 真机诊断
- 目标：继续修复真机上 `地铁：埌西 →` 补全终点站保存后仍可能回退的问题，并让 Debug 导出包含足够的 App 内部保存 / 同步证据。
- 改动范围：`SQLiteTransactionStore.applyRemoteSyncRecords` 新增默认关闭的最近本机编辑保护参数；`LedgerStore.updateTransaction` 保存前后记录 sync metadata 摘要并标记 10 分钟保护窗口；`pullRemoteLedgerChanges` 批量拉取时传入最近编辑 ID 并记录保护结果；`DebugView` 整页和单条导出追加 iCloud 同步日志；`scripts/OfflineRegression.swift` 新增 `地铁：埌西 →` 编辑为 `地铁：埌西→万象城` 后不被同秒旧远端批量拉取覆盖的回归；同步更新 `CHANGELOG.md` 和 `versions/v1.6.0-plan.md`。
- 未改动范围：未修改地铁 / 南宁地铁解析规则、金额计算、CloudKit record schema、SQLite schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：先新增回归并确认缺少 `protectedLocalTransactionIDs` 参数导致失败；随后实现 Core 默认兼容保护入口、App 层最近编辑 ID 标记、远端拉取保护和 Debug 可导出同步日志。
- 未完成内容：尚未在用户真机上复测新 build；若仍复现，需要用本轮新增 Debug 日志判断是本地保存失败、自动推送未触发，还是保护窗口外被远端更新覆盖。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，修复前因 `extra argument 'protectedLocalTransactionIDs'` 预期失败；修复后再次执行 `bash scripts/run_offline_regression.sh`，结果 PASS。
- 风险与注意事项：保护窗口只针对本机刚编辑过的同 ID 账单，可能在 10 分钟内优先保留本机修改；这是为了避免用户刚保存的内容被旧远端静默覆盖。跨设备真实同时编辑仍可能进入冲突保护，后续需通过同步日志观察。
- 回滚方式：回退 `SQLiteTransactionStore.applyRemoteSyncRecords` 参数、`LedgerStore` 最近编辑保护与日志、`DebugView` 日志导出和新增离线回归，并恢复本轮文档记录。
- 结论：本轮代码侧完成，账本编辑后的本机保护窗口和可导出同步证据已补上。
- 下一步建议：打一个真机 build，复测 `地铁：埌西 →` 补全保存；若失败，复制 Debug 导出文本继续定位。

### ITER-213 GOAL-1750 visionOS 展示版第一版
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 2 / visionOS 展示端
- 类型：能力增强 / UI / 平台扩展
- 目标：把 `AutoLedgerVision` 从模板入口推进为可构建、可运行的只读空间展示窗口第一版。
- 改动范围：`AutoLedgerVision` target 显式链接 `AutoLedgerCore`；`AutoLedger/AutoLedgerVision/ContentView.swift` 替换模板 `Model3D + Hello, world!`；新增 SwiftUI 月度空间看板、分类支出卡片、年度消费时间线墙、最近账单悬浮列表、隐私模式、刷新入口和 loading / empty / unavailable 状态；同步更新 `versions/v1.6.0-plan.md`、`docs/archive/visionos-implementation-assessment.md` 和 `CHANGELOG.md`。
- 未改动范围：未修改主 App / Watch / Extension 的 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、scheme 或 Xcode Cloud 脚本；未启用 immersive space 或 Volume；未新增导入、编辑、删除、数据清洗、多账本、CloudKit schema、SQLite schema 或真实样例数据。
- 完成内容：Vision 首版保持 `WindowGroup`，读取本机正式账本并复用 `MonthlySnapshot`、`TodaySpendingSummary` 派生展示；模拟器无账本数据时展示 empty 状态，不注入假数据；按钮样式改为自绘胶囊，避免 visionOS 默认 bordered 样式造成文字不可见。
- 未完成内容：visionOS 仍未接 CloudKit 只读拉取或 dashboard snapshot；未做 Vision Pro 真机 smoke；未接 visionOS App Store 素材和截图管线；有真实账本数据后的四区展示仍需后续环境复测。
- 测试情况：执行 `xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'generic/platform=visionOS' build`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerVision -configuration Debug -destination 'platform=visionOS Simulator,name=Apple Vision Pro' build`、`xcrun simctl install`、`xcrun simctl launch top.darkrio326.AutoLedger.vision` 和 `xcrun simctl io ... screenshot`，结果 PASS；仅保留已知 AppIntents metadata extraction warning / Core formatter warning。
- 风险与注意事项：当前 Vision 端有产品 UI 和本地只读数据入口，但还不是跨设备空间看板最终数据链路；如果要让 Vision Pro 直接看到 iPhone / iPad 账本，需要后续单独实现 CloudKit dashboard snapshot 或只读拉取，并补能力配置、真机 smoke 和素材。
- 回滚方式：回退 `AutoLedgerVision` target 的 `AutoLedgerCore` 依赖与 `ContentView.swift`，并恢复本轮文档记录；本轮没有 schema 迁移或 entitlements 变更。
- 结论：本轮完成，`GOAL-1750` 已具备可构建运行的 visionOS 展示版第一版。
- 下一步建议：进入 `GOAL-1760`，集中处理 Mac / iPad / Watch 多端 polish 与已知刷新、布局、真机体验问题。

### ITER-212 账单编辑同步冲突修复
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 2 / 数据同步稳定性
- 类型：Bugfix / 同步 / 测试
- 目标：修复账单编辑保存后可能被 iCloud 旧远端记录覆盖，导致商户名补全看起来不生效的问题。
- 改动范围：调整 `TransactionSyncConflictResolver` 的同一账单冲突判断顺序；新增离线回归覆盖本地手动补全地铁站名后，旧远端记录即使 `syncRevision` 更高也不会覆盖本地编辑；同步更新 `CHANGELOG.md` 和 `versions/v1.6.0-plan.md`。
- 未改动范围：未修改地铁 / 南宁地铁解析规则、金额计算、CloudKit schema、SQLite schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：同一账单合并优先比较 `updatedAt`，只在更新时间相同后再比较设备本地 `syncRevision`；补充 resolver 层和 SQLite apply 层两组回归，覆盖 `地铁：琅西 →` 手动修改为 `地铁：琅西→金湖广场` 后不被旧远端覆盖。
- 未完成内容：未做真机双设备重放验证；如果后续发现设备时钟严重偏移导致误判，需要再引入更明确的 CloudKit server change token / server timestamp 策略。
- 测试情况：执行 `bash scripts/run_offline_regression.sh`，结果 PASS。
- 风险与注意事项：`syncRevision` 是设备本地递增值，不应作为跨设备全局新旧判断的首要依据；本轮改为本地优先保护最近用户编辑，但仍保留同时间戳下 revision 次级判断。
- 回滚方式：回退 `SyncMetadata.swift` 中冲突判断顺序和 `scripts/OfflineRegression.swift` 新增用例，并恢复本轮文档记录。
- 结论：本轮完成，账单编辑保存后的本地新内容不会再被更新时间更早的远端记录覆盖。
- 下一步建议：真机上复测同一条地铁账单，编辑补全箭头后的终点站，等待 iCloud 同步后确认 iPhone / iPad 均保留编辑后的商户名。

### ITER-211 GOAL-1740 tvOS 只读看板第一版
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 2 / tvOS 展示端
- 类型：能力增强 / UI / 平台扩展
- 目标：把 `AutoLedgerTV` 从模板入口推进为可构建运行的只读账本看板第一版。
- 改动范围：`AutoLedgerTV` target 显式链接 `AutoLedgerCore`；`AutoLedger/AutoLedgerTV/ContentView.swift` 替换为 tvOS dashboard 根页面；`versions/v1.6.0-plan.md`、`docs/archive/tvos-implementation-assessment.md` 和 `CHANGELOG.md` 回填状态。
- 未改动范围：未修改主 App / Watch / Extension 的 Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、scheme 或 Xcode Cloud 脚本；未新增 tvOS iCloud / CloudKit capability；未接 App Store Connect 平台；未加入导入、编辑、删除、数据清洗、多账本或真实样例数据。
- 完成内容：新增 `总览 / 分类 / 趋势 / 摘要` 四页只读 dashboard；复用 `MonthlySnapshot` 和 `TodaySpendingSummary` 计算本月总览、分类占比、最近 7 天趋势、近 6 个月趋势、年度累计、Top 商户和最近账单；提供 loading、empty、unavailable 状态、刷新入口和隐私隐藏切换。
- 未完成内容：tvOS 仍未接 CloudKit 只读正式账本拉取或 dashboard snapshot；当前 Apple TV 只读取 tvOS 本机正式账本 SQLite；未做 tvOS 真机 smoke、截图管线或 ASC 平台素材。
- 测试情况：执行 `git diff --check`、`xcodebuild -workspace AutoLedger/AutoLedger.xcworkspace -scheme AutoLedgerTV -configuration Debug -destination 'generic/platform=tvOS' build` 和主 App iOS generic Debug build，结果 PASS。tvOS build 仅保留 AppIntents metadata extraction warning，因为 target 不依赖 AppIntents，不影响构建。
- 风险与注意事项：tvOS 当前有 UI 骨架和本地只读统计，但还不是跨设备家庭大屏最终数据链路；如果要在 Apple TV 上看到 iPhone / iPad 账本，需要后续单独实现 CloudKit dashboard snapshot 或只读拉取，并补能力配置与真机 smoke。
- 回滚方式：回退 `feat(tvos): add read-only ledger dashboard` 提交，并恢复本轮文档记录；本轮没有 schema 迁移或 entitlements 变更。
- 结论：本轮完成，`GOAL-1740` 已具备可构建运行的 tvOS 只读看板第一版。
- 下一步建议：进入 `GOAL-1750` visionOS 展示版第一版；tvOS 跨设备数据入口另立后续小目标。

### ITER-210 GOAL-1735 外部辅助识别短期结果缓存
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：能力增强 / 性能优化 / 隐私回归
- 目标：为外部辅助识别增加本机短期缓存，避免同一脱敏 OCR 在短时间内重复请求外部 provider。
- 改动范围：新增 `ExternalReceiptAssistCache.swift` 作为 Core 层缓存策略；`ExternalReceiptAssistClient` 在请求前读取短期缓存，网络成功后写入缓存；provider / endpoint / model / API key 变化时清理缓存；离线回归新增缓存 key、TTL、prune 和隐私断言；版本计划与 CHANGELOG 回填。
- 未改动范围：未缓存原始 OCR、截图、脱敏 OCR 原文、金额、日期、订单号、卡号、手机号或地址；未新增 SQLite 正式 schema；未把短期缓存写入 iCloud 配置快照或 JSON 备份；未改变金额 / 日期解析权重；未自动保存账单或自动创建订阅；未修改 Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：缓存 key 由脱敏 OCR 文本 SHA-256 指纹、来源、provider、model 和 endpoint 指纹组成；缓存值只保存模型候选结果；默认 TTL 24 小时，最多保留 80 条；过期记录会 prune；配置变化会清理。
- 未完成内容：未实现 L2 商户级画像、订阅 hint 入账后用户提示、负向订阅学习或“清除识别学习数据”统一入口。
- 测试情况：执行 `git diff --check`、`bash scripts/run_offline_regression.sh` 和主 App iOS generic Debug build，结果 PASS。
- 风险与注意事项：缓存命中会复用外部模型候选，但仍只参与商户 / 分类 / 订阅 hint 增强，不参与金额、日期或自动保存；后续若要展示缓存命中状态，需要扩展 trace 结构。
- 回滚方式：恢复 `ExternalReceiptAssistCache.swift`、`ExternalReceiptAssistClient.swift`、`scripts/OfflineRegression.swift`、`scripts/run_offline_regression.sh` 与本轮文档记录；缓存保存在 `externalReceiptAssistShortTermCache.v1`，回滚时可删除该 UserDefaults key。
- 结论：本轮完成，外部辅助识别已具备本机短期缓存与隐私回归。
- 下一步建议：根据产品优先级决定先补订阅 hint 用户确认提示，或按队列进入 `GOAL-1740` tvOS 只读看板第一版。

### ITER-209 GOAL-1730 商户 / 分类 / 订阅倾向学习缓存设计
- 日期：2026-06-19
- 所属版本：v1.6.0
- 所属阶段：Phase 1 / 订阅管理补强
- 类型：文档 / 架构设计 / 隐私边界
- 目标：冻结商户、分类和订阅倾向学习缓存的安全边界，明确不缓存原始 OCR 和敏感字段。
- 改动范围：新增 `docs/architecture/recognition-learning-cache-design.md`；`versions/v1.6.0-plan.md` 标记 `GOAL-1730` 完成并补充设计记录；`CHANGELOG.md` 回填本轮变更。
- 未改动范围：未实现运行时代码；未新增 SQLite schema；未改变 iCloud 同步 schema；未修改 Xcode project / workspace / scheme / target、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：学习缓存分层为 L1 用户确认规则、L2 商户级低风险画像、L3 短期脱敏 OCR hash 缓存；明确 L1 复用现有商户别名、分类修正和用户确认订阅；L2 只保存低风险商户级统计；L3 顺延到 `GOAL-1735`，不进入 iCloud 或 JSON 备份。
- 未完成内容：短期脱敏 OCR hash 缓存、商户画像运行时代码、订阅提示负向学习和清除识别学习数据入口继续后续推进。
- 测试情况：执行 `git diff --check`，结果 PASS。本轮仅文档设计，无需构建。
- 风险与注意事项：后续实现必须继续遵守“缓存只增强候选，不覆盖金额和日期，不自动创建订阅”的边界；任何进入 iCloud 的学习数据都必须保持商户级低风险粒度。
- 回滚方式：删除 `docs/architecture/recognition-learning-cache-design.md`，并恢复 `versions/v1.6.0-plan.md`、`CHANGELOG.md` 和本条 iteration log。
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
  - `docs/archive/minimum-platform-baseline-reduction-plan.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md`：回填实施结果。
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
  - `docs/archive/autoledgercore-platform-dependency-audit.md`：新增 Core 平台依赖审计结论。
  - `docs/archive/minimum-platform-baseline-reduction-plan.md`：补充 GOAL-1601 审计结论，收紧 Phase B 顺序。
  - `versions/v1.5.1-plan.md`：将 `GOAL-1601` 标记为已完成，并补充最低系统实施结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录本轮审计。
- 未改动范围：未修改 Swift 源码、Xcode target、deployment target、Bundle ID、entitlements、CloudKit 配置、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：确认 `AutoLedgerCore` 主要源码仍是 `Foundation` / `SQLite3` 级别；当前唯一高层平台依赖命中是 `AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Intents/ClipboardImportIntent.swift` 中的 `AppIntents`；结论是不需要先大规模拆 `CoreBase`，应先把 `ClipboardImportIntent` 迁出为 App / Extension 层 Intent Adapter，再下调 `AutoLedgerCore/Package.swift`。
- 未完成内容：尚未迁移 `ClipboardImportIntent`；尚未修改 `AutoLedgerCore/Package.swift`；尚未下调任何 Xcode target 的 deployment target；尚未运行低系统构建验证。
- 测试情况：未运行测试。本轮仅做依赖审计与文档回填，不涉及源码或工程配置修改。
- 风险与注意事项：`ClipboardImportIntent` 当前被 `ControlWidgetExtension/ClipboardImportControl.swift` 使用，后续迁移时必须保持 Control Widget 和剪贴板导入入口行为不变；迁移后如果 Core 仍出现低系统编译阻塞，再重新评估是否需要独立 `CoreBase`。
- 回滚方式：删除 `docs/archive/autoledgercore-platform-dependency-audit.md`，回退 `docs/archive/minimum-platform-baseline-reduction-plan.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md` 和本条日志即可。
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
  - `docs/capabilities/shortcuts-json-ledger-import.md`、`versions/v1.5.1-plan.md`、`CHANGELOG.md`：补充功能说明与版本记录。
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
  - `docs/archive/minimum-platform-baseline-reduction-plan.md`：将承接版本改为 `v1.5.1`，并补充 `AutoLedgerCore -> CoreBase + Intent Adapter` 的拆分判断。
  - `README.md`：Roadmap 将 `v1.5.0` 标记为“基线完成”，新增 `v1.5.1` 当前开发线条目。
  - `CHANGELOG.md`、`process/iteration-log.md`：回填本轮版本接管记录。
- 未改动范围：未修改任何 Swift 源码、Xcode target、deployment target、Bundle ID、entitlements、CloudKit 配置、截图脚本实现或 App Store Connect 线上配置。
- 完成内容：将最终 smoke / Xcode Cloud / ASC 提交门禁整体后移到 `v1.5.1`；明确 `v1.5.1` 承接 tvOS / visionOS 第一版落代码与最低系统需求优化；明确多账本继续 delay，不进入当前执行范围；固定新的目标版本矩阵：`iOS 17 / macOS 14 line / watchOS 10 / tvOS 17 / visionOS 1 / ControlWidget iOS 18 / Apple FM iOS 26+ optional enhancement`。
- 未完成内容：尚未实际下调 deployment target；尚未拆分 `AutoLedgerCore`；尚未落 tvOS / visionOS 产品代码；尚未执行 `v1.5.1` 的最终 smoke / Xcode Cloud / ASC 收口。
- 测试情况：
  - PASS：`git diff --check`
  - PASS：文档自检，`README`、`v1.5.0-plan.md`、`v1.5.1-plan.md` 与最低系统规划口径一致。
- 风险与注意事项：当前只是版本与平台规划调整，不代表最低系统已经下调成功，也不代表 tvOS / visionOS 已有可发布代码；后续真正实施时必须按 target 分层处理，不允许用全局 `@available(iOS 26.0, *)` 包裹主链路来“假降版本”。
- 回滚方式：删除 `versions/v1.5.1-plan.md`，回退 `versions/v1.5.0-plan.md`、`docs/archive/minimum-platform-baseline-reduction-plan.md`、`README.md`、`CHANGELOG.md` 和本条日志即可恢复到 `v1.5.0` 收口口径。
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
  - `docs/operations/all-platform-screenshot-pipeline-design.md`：新增全平台截图设计稿，覆盖配置扩展、CLI flag、输出目录、preview 分组、平台场景和 `GOAL-1591` 实施顺序。
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
- 回滚方式：删除 `docs/operations/all-platform-screenshot-pipeline-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1590` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1590` 设计完成，下一步可直接实现截图管线扩展，而不需要继续讨论总体方案。
- 下一步建议：进入 `GOAL-1591`，先做配置 / flag / preview 的骨架扩展，再按 iPad / Mac → tvOS / visionOS 的顺序接入 capture。

### ITER-165 GOAL-1583 visionOS 展示实现评估
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 10 / visionOS 空间展示版本
- 类型：文档 / 实现评估 / 平台扩展
- 目标：确认 `AutoLedgerVision` target / simulator 是否已可用，收敛首版 scene 选择、数据入口边界和最小 smoke 定义，避免直接把范围膨胀到 immersive 空间实现。
- 改动范围：
  - `docs/archive/visionos-implementation-assessment.md`：新增实现评估文档，记录 target 现状、build smoke、scene 方案对比、RealityKit 模板判断、推荐实现路径和最小 smoke 定义。
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
- 回滚方式：删除 `docs/archive/visionos-implementation-assessment.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1583` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1583` 评估完成，visionOS target / simulator 已可继续推进；下一步应实现首版只读骨架，或转入 `GOAL-1590` 统一规划全平台截图管线。
- 下一步建议：如果继续按“第三批后段”推进，可直接进入 `GOAL-1590`；如果希望 visionOS 先落一个可见结果，也可以单开一轮仅做 `WindowGroup` 四区静态骨架，不接真实数据。

### ITER-164 GOAL-1582 visionOS 空间展示设计
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 10 / visionOS 空间展示版本
- 类型：文档 / 设计 / 平台扩展
- 目标：为 `AutoLedgerVision` 首版输出可直接交接到实现评估阶段的空间展示设计，明确入口 scene、空间层次、数据口径、交互密度和隐私边界。
- 改动范围：
  - `docs/platforms/visionos-spatial-design.md`：新增 visionOS 设计稿，覆盖平台定位、入口形态、四个展示区、空间布局原则、轻交互模型、隐私模式和 `GOAL-1583` 交接问题。
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
- 回滚方式：删除 `docs/platforms/visionos-spatial-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1582` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1582` 设计完成，visionOS 首版展示口径已定型，下一步进入 `GOAL-1583` 回答 scene / 数据入口 / 最小 smoke 的实现问题。
- 下一步建议：继续按顺序推进 `GOAL-1583`，先把 `WindowGroup / Volume / RealityKit / 只读数据入口` 的最小实现路径评估清楚，再决定是否开始写 visionOS 骨架界面。

### ITER-163 GOAL-1581 tvOS 看板实现评估
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 9 / tvOS 只读大屏看板
- 类型：文档 / 实现评估 / 平台扩展
- 目标：确认 `AutoLedgerTV` target / simulator 是否可用，明确 tvOS 首版 dashboard 的最小实现面和正确数据入口。
- 改动范围：
  - `docs/archive/tvos-implementation-assessment.md`：新增实现评估文档，记录 target 现状、build smoke、数据入口方案对比、推荐路径、主要缺口和下一步建议。
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
- 回滚方式：删除 `docs/archive/tvos-implementation-assessment.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1581` 恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
- 结论：`GOAL-1581` 评估完成，tvOS target 和 simulator 已不是 blocker；下一步可直接开始 tvOS 最小骨架实现，或按顺序进入 `GOAL-1582` 完成 visionOS 设计。
- 下一步建议：若继续沿第七批推进，进入 `GOAL-1582`；若希望 tvOS 先落一个可见成果，可单开一轮仅实现总览页 smoke，不扩到四页完整 UI。

### ITER-162 GOAL-1580 tvOS 只读看板设计
- 日期：2026-06-06
- 所属版本：v1.5.0
- 所属阶段：Phase 9 / tvOS 只读大屏看板
- 类型：文档 / 设计 / 平台扩展
- 目标：为 tvOS 首版输出可直接交接到实现评估阶段的信息架构，明确只读边界、页面结构、遥控器焦点模型、隐私模式和同步口径。
- 改动范围：
  - `docs/platforms/tvos-dashboard-design.md`：新增 tvOS 设计稿，覆盖目标、页面职责、布局草案、焦点导航、隐私模式、快照状态和 `GOAL-1581` 交接建议。
  - `versions/v1.5.0-plan.md`：将 `GOAL-1580` 状态改为已完成，并新增 `13.60` 记录本轮设计结论。
  - `CHANGELOG.md`、`process/iteration-log.md`：记录 `GOAL-1580` 文档完成范围。
- 未改动范围：未修改 `AutoLedgerTV` target 模板代码、Bundle ID、signing、entitlements、App Group、iCloud Container、Xcode Cloud 脚本；未实现 tvOS UI、未做 tvOS build smoke、未接 App Store Connect 平台。
- 完成内容：tvOS 首版定位收口为“家庭大屏只读账本看板”，一级导航固定为 `总览 / 分类 / 趋势 / 摘要` 四页；明确只读展示单一正式账本稳定快照，隐私模式作为一等能力；遥控器焦点模型保持极简，不把 iPad / Mac 工作台交互照搬到 tvOS。
- 未完成内容：未实现 tvOS SwiftUI 页面或 scene；未决定最终技术接入方式，只明确 `GOAL-1581` 应优先评估只读展示快照或共享读模型。
- 测试情况：
  - PASS：`git diff --check`。
  - PASS：文档自检，设计稿与 `6.6 tvOS 只读大屏看板`、`10.4 tvOS`、`13.4 推荐推进顺序` 保持一致。
- 风险与注意事项：当前本机缺 tvOS runtime，下一轮实现评估前仍需先补 Xcode Components；设计稿已明确 tvOS 不应承接导入、清洗或写入链路，后续若新增功能应单独立项，避免再次扩张范围。
- 回滚方式：删除 `docs/platforms/tvos-dashboard-design.md`，将 `versions/v1.5.0-plan.md` 中 `GOAL-1580` 状态恢复为未完成，并移除对应 CHANGELOG / iteration-log 条目。
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
  - `docs/operations/iap-support.md`：新增本地测试、App Store Connect 配置、三语内购说明和 Review Notes 文档。
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
- 回滚方式：删除 `SupportPurchaseManager.swift`、`SupportAutoLedgerView.swift`、`AutoLedgerSupport.storekit` 和 `docs/operations/iap-support.md`，回退设置页入口、App 启动监听、scheme/project 配置、本地化 key、CHANGELOG 与迭代日志。
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
- 目标：基于 `docs/architecture/LedgerTextInterpreter.md` 与 v1.3.2 工程现状，规划下一版本将解释器抽象为平台无关核心，并建立小票图片集批量 OCR、OCR 后账单相关性判断与批量解析回归。
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
- 目标：分析 `docs/capabilities/autoledger_voice_siri_design.md` 与现有 AppIntent、SQLite、分类和备份恢复能力，建立 v1.3.1 版本计划。
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
- 目标：读取 `docs/architecture/autoledger_icloud_backup_design.md` 和现有工程进展，建立 v1.3.0 版本计划，将 iCloud 轻量备份设计拆成可执行迭代。
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

### ITER-1755 tvOS / visionOS 只读看板同步入口
- 日期：2026-06-20
- 所属版本：v1.6.0
- 所属阶段：GOAL-1755
- 类型：能力增强 / 数据同步 / 多平台展示
- 目标：让 tvOS / visionOS 首版展示页可以读取 iPhone / iPad / Mac 主 App 发布的 CloudKit 只读看板快照，而不是只能依赖本机 SQLite 空数据。
- 改动范围：新增 `LedgerDashboardCloudSnapshot` 展示快照模型；扩展 `CloudLedgerSyncSchema` 增加 `LedgerDashboardSnapshot` record type；扩展 `LedgerCloudKitSyncAdapter` 支持发布快照；`LedgerStore` 在 iCloud 同步 / 拉取 / 推送后发布大屏快照；tvOS / visionOS 看板加载时优先拉取 CloudKit 快照并回退本机 SQLite；为 tvOS / visionOS target 增加 CloudKit entitlements；更新 v1.6.0 计划、CHANGELOG 与离线回归脚本。
- 未改动范围：未让 tvOS / visionOS 写入账本；未同步原始截图、支付截图、小票图片、OCR 原文、调试记录、`syncRevision`、`idempotencyKey` 或冲突状态；未修改 Bundle ID、DEVELOPMENT_TEAM、App Group、主 App iCloud Container、Xcode Cloud 脚本或 App Store Connect。
- 完成内容：主 App 发布一份面向大屏只读展示的 dashboard snapshot；tvOS / visionOS 可优先读取同一 Apple ID private database 中的快照展示月度看板、分类、趋势、摘要和最近账单；没有快照时仍保留本机 SQLite fallback。
- 测试情况：执行 `git diff --check`，结果 PASS；执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `bash scripts/run_golden_regression.sh`，结果 PASS；执行主 App iOS generic build，结果 PASS；执行 tvOS / visionOS `CODE_SIGNING_ALLOWED=NO` generic build，结果 PASS。tvOS / visionOS signed generic build 当前因 provisioning profile 尚未包含 iCloud capability / `iCloud.top.darkrio326.AutoLedger` container 而失败，归为人工配置项。
- 风险与注意事项：签名构建 tvOS / visionOS 前，需要在 Apple Developer Portal 为 `top.darkrio326.AutoLedger.tv` 和 `top.darkrio326.AutoLedger.vision` 的 App ID 启用 iCloud / CloudKit 并包含 `iCloud.top.darkrio326.AutoLedger`，随后刷新 Xcode managed provisioning profile。CloudKit Console Development schema 会新增 `LedgerDashboardSnapshot`，进入 TestFlight / App Store 前需确认并部署 Production schema。快照发布失败不会阻断主账本同步，但 tvOS / visionOS 会看到旧快照或空状态。
- 回滚方式：如新平台签名或 CloudKit schema 阻塞发布，可回退 tvOS / visionOS entitlement 与 CloudKit snapshot 拉取入口，保留首版本机 SQLite 只读看板；主账本 iCloud 同步链路可独立保留。
- 结论：本轮完成，tvOS / visionOS 已具备只读跨设备数据入口；下一步进入 `GOAL-1760` 多端 polish 与真机 / 模拟器 smoke。

### ITER-1760A 同秒账单编辑同步保护补强
- 日期：2026-06-20
- 所属版本：v1.6.0
- 所属阶段：GOAL-1760
- 类型：Bugfix / 数据同步 / 账本编辑
- 目标：修复真机上个别地铁账单编辑补全站名后仍可能回退的问题，尤其是 `地铁：埌西 →` 这类同金额、相近时间、连续编辑场景。
- 改动范围：调整 `TransactionSyncConflictResolver` 的同时间戳决策；调整 `LedgerSyncPlanner` 的增量推送 checkpoint 边界；新增离线回归覆盖跨设备同秒旧远端高 revision 不覆盖本地编辑，以及 checkpoint 秒内变更仍进入增量推送。
- 未改动范围：不修改地铁 / 南宁地铁解析规则；不修改金额计算；不修改 SQLite schema、CloudKit record schema、Bundle ID、DEVELOPMENT_TEAM、App Group、iCloud Container、entitlements、Xcode Cloud 脚本或 App Store Connect 配置。
- 完成内容：`syncRevision` 只在同一设备内作为同一时间戳下的次级排序依据；跨设备同秒分歧进入冲突保护，不再靠远端高 revision 覆盖本地商户编辑；增量推送包含 `updatedAt == checkpoint` 的边界记录，降低刚保存编辑漏推风险。
- 测试情况：先新增两个失败回归并确认 `run_offline_regression.sh` 出现 2 个预期失败；修复后执行 `bash scripts/run_offline_regression.sh`，结果 PASS；执行 `bash scripts/run_golden_regression.sh`，结果 PASS；执行主 App iOS generic build，结果 PASS。
- 风险与注意事项：跨设备同秒不同内容现在会进入冲突保护，可能让同步摘要里的冲突数增加，但比静默覆盖用户编辑更安全。若真机仍复现，需要导出保存后的 Debug 记录和 iCloud 同步日志，确认是本地保存失败、自动推送未触发，还是远端已有更新仍被判为更新。
- 回滚方式：如该策略导致误报冲突过多，可回退 `SyncMetadata.swift` 和 `LedgerSyncPlan.swift` 的本轮改动，并保留新增回归作为后续设计参考。
- 结论：本轮完成，账本编辑后的同秒跨设备同步覆盖风险已补强；下一步继续 `GOAL-1760` 的 Mac / iPad / Watch polish。

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
