---
name: receipt-regression
description: 'Run AutoLedger receipt parsing regression tests on macOS. Use when modifying ReceiptParser, LedgerTextInterpreterCore, SmartReceiptParser, VoiceLedgerParser, or any parsing logic. Also use after adding golden cases, fixing OCR bugs, or before tagging a release. Triggers: "run regression", "run tests", "check parsing", "verify golden cases", "batch regression".'
argument-hint: 'offline | golden | batch | all'
---

# Receipt Regression

## When to Use

- 修改 `ReceiptParser`、`LedgerTextInterpreterCore`、`SmartReceiptParser`、`VoiceLedgerParser` 后
- 新增或修改 `tests/golden/` 中的 golden case
- 修复 OCR/解析 Bug 后验收
- 版本 Release 前的最终门禁校验

## Procedure

从**仓库根目录**执行（不是 `AutoLedger/` 子目录）：

### 1. 离线回归（最常用）

macOS 本地 `swiftc` 平铺编译 AutoLedgerCore + 运行全部 golden cases：

```bash
bash scripts/run_offline_regression.sh
```

**预期输出**：所有 case PASS，最后打印 `All N tests passed`。

### 2. Golden Case 回归

仅运行 `tests/golden/ledger_text_interpreter/cases.jsonl` 中的 golden cases：

```bash
bash scripts/run_golden_regression.sh
```

### 3. 全量小票批量回归

对 `receiptsample/` 目录下的全量小票样本跑批量报告（耗时较长）：

```bash
bash scripts/run_receipt_batch_regression.sh
```

输出 Markdown 报告，用于建立引擎基线或评估回归影响面。

### 4. 全量（all）

依次执行上面三步：

```bash
bash scripts/run_offline_regression.sh && \
bash scripts/run_golden_regression.sh && \
bash scripts/run_receipt_batch_regression.sh
```

## Interpreting Results

| 输出 | 含义 |
|------|------|
| `PASS` | Case 通过 |
| `FAIL` | Case 失败，输出期望值 vs 实际值 |
| `compile error` | 源码编译失败，需先修复再回归 |

## Gate Rule

**构建或任意 case 失败 → 禁止进入下一轮迭代**（见 [agent-iteration-workflow.md](../../../process/agent-iteration-workflow.md)）。

## Adding Golden Cases

在 `tests/golden/ledger_text_interpreter/cases.jsonl` 末尾追加一行 JSON：

```jsonc
{"input": "...OCR 文本...", "expected": {"merchant": "商户名", "amount": 99.0, "category": "food"}}
```

追加后执行 `bash scripts/run_golden_regression.sh` 验证新 case 通过。
