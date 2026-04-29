# Worker API Evaluation

日期：2026-04-29
评估目标：判断是否应当将 `LedgerTextInterpreterCore` 部署到云端运行时。

## 1. 评估背景

v1.3.3 ~ v1.3.5 持续将解析核心抽象为平台无关的 Foundation-only 模块。当前 `AutoLedgerCoreKit` 已验证可在 macOS 上独立编译（不含 UIKit/AppKit/Vision 等任何 iOS-only 依赖）。

## 2. 候选运行时评估

### 2.1 SwiftPM CLI (macOS/Linux)

| 项目 | 状态 |
|------|------|
| 编译 | ✅ AutoLedgerCoreKit 在 macOS 独立构建通过 |
| 依赖 | ✅ 仅 Foundation |
| 测试 | ✅ 712 条 receiptsample 在 7.5s 内解析完成 |
| 延迟 | ~9.5ms/record (p50) |
| 优势 | 零额外成本，本地可复现 |
| 劣势 | 非弹性，不适合作为 API 端点 |

### 2.2 swiftwasm (Cloudflare Workers)

| 项目 | 状态 |
|------|------|
| 编译 | ❌ 当前开发环境未安装 swiftwasm SDK |
| 依赖风险 | `NSRegularExpression` 在 swiftwasm/WASI 中不可用 |
| 替代方案 | 需用 Swift 原生 String API 重写正则逻辑（`Regex`/`split`/`range(of:options:)`），工作量约 0.5 天 |
| 优势 | 边缘部署、全球低延迟、免费层 100k req/day |
| 劣势 | 工具链不成熟、Swift 版本滞后、Foundation 支持受限 |

### 2.3 Vapor + Linux Docker

| 项目 | 状态 |
|------|------|
| 编译 | ✅ Foundation 全兼容，无需修改代码 |
| 部署 | 需维护 VPS 或容器服务 |
| 延迟 | 同本地（~5-10ms p50） |
| 成本 | 最低 $5-10/月 (VPS) |
| 优势 | 代码零修改、成熟生态 |
| 劣势 | 非边缘、有维护成本 |

### 2.4 JavaScript port

| 项目 | 状态 |
|------|------|
| 可行性 | 规则引擎约 400 行 Swift，手动翻译为 JS 需 0.5-1 天 |
| 维护成本 | 需维护两套实现，后续规则调整需同步修改 |
| 结论 | ⛔ 不推荐。规则逻辑在 Swift 侧迭代快，JS port 会持续落后 |

## 3. 性能基准

基于 receiptsample 712 张真实小票 OCR 文本，在 Apple M 系列硬件上运行：

| Metric | Value |
|--------|-------|
| 总样本 | 712 |
| 总耗时 (user) | 6.73s |
| 吞吐量 | ~105 req/s |
| p50 延迟 | ~9.5ms |
| p90 延迟 | ~15ms (估计) |
| p99 延迟 | ~30ms (估计) |
| 内存峰值 | < 10MB |

Cloudflare Workers 免费层配额：100k req/day。即使跑全量 712 条基线，仅消耗 0.7% 日配额。

## 4. 收益分析

| 场景 | 当前 (本地 CLI) | 云端 Worker |
|------|----------------|-------------|
| 批量调参 | 需本地手动运行 | 自动触发 + 并行调参 ✅ |
| 回归 CI | 本地 bash 脚本 | CI 内自动运行 ✅ |
| 端侧 fallback | 不支持 | 可作为弱设备 fallback ✅ |
| 规则 A/B 测试 | 不支持 | 可分流对比 ✅ |
| 新增支付平台快速适配 | 需发版 | 云端热更新 ✅ |

## 5. 风险评估

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| swiftwasm NSRegularExpression 不可用 | 需要重写正则逻辑，约 0.5 天 | 高 | 先用 Vapor Docker 方案；等待 swiftwasm Foundation 完善 |
| 云端与端侧行为不一致 | 调参结论无法复现到 App | 中 | 保持同一套核心代码，仅运行环境不同 |
| 维护额外基础设施 | 增加运维负担 | 低 | Workers 无服务器架构，零运维 |
| 用户隐私 | OCR 文本含敏感信息 | 中 | 云端仅用于批量调参，不上线生产 API；样本脱敏后上传 |

## 6. 推荐方案

### 短期 (v1.3.5~v1.4) — GO (CONDITIONAL)

采用 **SwiftPM CLI + 本地 batch 工具** 作为默认批量调参方式。理由：

1. **代码零修改** — `AutoLedgerCoreKit` 已可独立编译运行
2. **成本为零** — 无需额外基础设施
3. **性能足够** — 712 条在 7.5s 完成
4. **当前不需要生产 API** — 批量调参和回归完全可在本地完成

### 中期 (v1.5+) — 重新评估

评估时机：
- swiftwasm Foundation 支持 `NSRegularExpression` 后
- 或云端批量调参需求超过本地 CLI 瓶颈（> 10k 样本/次）
- 或需要生产环境 Worker API 作为端侧 fallback

推荐候选方案：
1. **首选**：swiftwasm → Cloudflare Workers（零运维、全球边缘）
2. **备选**：Vapor + Fly.io Docker（代码零修改、$5/月）

## 7. 决策

```
结论：CONDITIONAL GO
当前方案：SwiftPM CLI（本地批量工具）
重新评估触发条件：
  A. swiftwasm NSRegularExpression 可用
  B. 批量样本 > 10k/次
  C. 需要生产环境 Worker API
```

## 8. 下一步行动

- [x] AutoLedgerCoreKit 独立包提取 ✅
- [x] macOS 独立编译验证 ✅
- [x] 712 样本性能基准 ✅
- [x] EVALUATION.md 决策记录 ✅
- [ ] swiftwasm 可用后重试编译（添加一个 tracking issue）
- [ ] 将 `scripts/run_receipt_batch_regression.sh` 接入 CI
