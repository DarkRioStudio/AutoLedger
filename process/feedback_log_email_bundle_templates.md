# AutoLedger 反馈日志邮件与附件 Bundle 模板

本文档定义 AutoLedger 的反馈日志协议，包含：

- 不同分级下的邮件标题模板
- 不同分级下的邮件正文模板
- 不同分级下的附件 bundle 模板
- 推荐的文件命名和字段约定

---

## 1. 分级定义

### L1 标准反馈
用途：
- 普通问题反馈
- UI 问题
- 轻度 OCR 错误
- 非崩溃类问题

特点：
- 默认脱敏
- 不带原始截图
- 不带完整 OCR 原文
- 用户心理负担最低

### L2 增强调试
用途：
- 金额识别错误
- 商户识别错误
- 时间解析错误
- 快捷指令链路异常
- 需要更多上下文才能复现的问题

特点：
- 带更多解析上下文
- 仍然脱敏
- 可选附加“局部 OCR 原文”
- 不默认附原图

### L3 完整诊断包
用途：
- 长期难解的疑难问题
- 内部测试
- 高级测试者明确同意后发送
- 明确需要原图或完整识别文本时

特点：
- 高风险
- 必须二次确认
- 默认不开放给普通用户

---

## 2. 邮件标题模板

统一格式：

```text
[AutoLedger][级别][平台][版本(Build)][问题类型] 简短摘要
```

### 2.1 L1 标准反馈标题模板

```text
[AutoLedger][L1][iOS][1.0.0(5)][feedback] 问题反馈
```

可变体：

```text
[AutoLedger][L1][iOS][1.0.0(5)][ocr] 识别结果不准确
[AutoLedger][L1][iOS][1.0.0(5)][ui] 页面显示异常
[AutoLedger][L1][iOS][1.0.0(5)][shortcut] 一键记账未触发
```

### 2.2 L2 增强调试标题模板

```text
[AutoLedger][L2][iOS][1.0.0(5)][ocr_parse_wrong] 金额识别错误
```

可变体：

```text
[AutoLedger][L2][iOS][1.0.0(5)][merchant_parse_wrong] 商户识别错误
[AutoLedger][L2][iOS][1.0.0(5)][time_parse_wrong] 时间解析错误
[AutoLedger][L2][iOS][1.0.0(5)][shortcut_flow] 快捷指令链路异常
```

### 2.3 L3 完整诊断包标题模板

```text
[AutoLedger][L3][iOS][1.0.0(5)][full_diagnostic] 完整诊断包
```

---

## 3. 邮件正文模板

建议正文分为两层：

1. 上半部分：用户和开发者都容易阅读的自然语言描述
2. 下半部分：机器可解析的 `AUTOLEDGER_FEEDBACK_META` 区块

### 3.1 L1 标准反馈正文模板

```text
你好，我在使用 AutoLedger 时遇到了问题，已附带标准反馈日志。

【问题描述】
{{user_description}}

【预期结果】
{{expected_result}}

【实际结果】
{{actual_result}}

【是否可复现】
{{reproducible}}

【发生时间】
{{event_time_local}}

【补充说明】
{{extra_note}}

--------------------------------
AUTOLEDGER_FEEDBACK_META
feedback_level=L1
issue_type={{issue_type}}
app_version={{app_version}}
build={{build_number}}
platform=iOS
ios_version={{ios_version}}
device_model={{device_model}}
entry_point={{entry_point}}
has_attachment_bundle=true
has_screenshot=false
contains_redacted_ocr=false
contains_raw_image=false
feedback_id={{feedback_id}}
--------------------------------
```

### 3.2 L2 增强调试正文模板

```text
你好，我在使用 AutoLedger 时遇到了需要进一步排查的问题，已附带增强调试日志。

【问题描述】
{{user_description}}

【预期结果】
{{expected_result}}

【实际结果】
{{actual_result}}

【是否可复现】
{{reproducible}}

【发生时间】
{{event_time_local}}

【本次已附加内容】
- 增强调试日志
- 脱敏后的识别上下文
- 解析结果摘要
- 流程轨迹

【补充说明】
{{extra_note}}

--------------------------------
AUTOLEDGER_FEEDBACK_META
feedback_level=L2
issue_type={{issue_type}}
app_version={{app_version}}
build={{build_number}}
platform=iOS
ios_version={{ios_version}}
device_model={{device_model}}
entry_point={{entry_point}}
has_attachment_bundle=true
has_screenshot={{has_screenshot}}
contains_redacted_ocr=true
contains_raw_image=false
feedback_id={{feedback_id}}
--------------------------------
```

### 3.3 L3 完整诊断包正文模板

```text
你好，我在使用 AutoLedger 时遇到了严重或持续性问题。本次邮件附带完整诊断包，用于协助进一步排查。

【问题描述】
{{user_description}}

【预期结果】
{{expected_result}}

【实际结果】
{{actual_result}}

【是否可复现】
{{reproducible}}

【发生时间】
{{event_time_local}}

【本次已附加内容】
- 完整调试日志
- 解析轨迹
- 可选原始截图/图片
- 识别原文（如已勾选）

【重要提示】
本次诊断包可能包含更多账单上下文信息，仅建议在你明确知情并同意的情况下发送。

【补充说明】
{{extra_note}}

--------------------------------
AUTOLEDGER_FEEDBACK_META
feedback_level=L3
issue_type={{issue_type}}
app_version={{app_version}}
build={{build_number}}
platform=iOS
ios_version={{ios_version}}
device_model={{device_model}}
entry_point={{entry_point}}
has_attachment_bundle=true
has_screenshot={{has_screenshot}}
contains_redacted_ocr=true
contains_raw_image={{contains_raw_image}}
feedback_id={{feedback_id}}
--------------------------------
```

---

## 4. 附件 bundle 模板

建议统一成一个 zip 包，名称固定。

### 4.1 附件命名规则

```text
AutoLedger_Feedback_{level}_{feedback_id}.zip
```

Feedback ID 格式：`AL-{vendorID_short6}-{yyyyMMddHHmmss}-{seq}`

- `vendorID_short6`：`UIDevice.current.identifierForVendor` 的 SHA-256 前 6 位 hex
- `yyyyMMddHHmmss`：本地时间戳
- `seq`：当天同设备自增序号（从 0001 起）
- 全局唯一；服务端以 `feedback_id` 为幂等键去重

例如：

```text
AutoLedger_Feedback_L1_AL-3f8a2c-20260410143025-0001.zip
AutoLedger_Feedback_L2_AL-3f8a2c-20260410150312-0002.zip
AutoLedger_Feedback_L3_AL-3f8a2c-20260410161500-0003.zip
```

### 4.2 L1 标准反馈 bundle 模板

```text
AutoLedger_Feedback_L1_AL-20260410-0001.zip
└── feedback_bundle/
    ├── issue_bundle.json
    ├── summary.txt
    └── metadata.json
```

### 4.3 L2 增强调试 bundle 模板

```text
AutoLedger_Feedback_L2_AL-20260410-0002.zip
└── feedback_bundle/
    ├── issue_bundle.json
    ├── summary.txt
    ├── metadata.json
    ├── trace.log
    └── redacted_ocr_context.txt
```

### 4.4 L3 完整诊断 bundle 模板

```text
AutoLedger_Feedback_L3_AL-20260410-0003.zip
└── feedback_bundle/
    ├── issue_bundle.json
    ├── summary.txt
    ├── metadata.json
    ├── trace.log
    ├── redacted_ocr_context.txt
    ├── full_ocr_text.txt
    └── attachments/
        └── screenshot_redacted_or_raw.jpg
```

---

## 5. bundle 内文件模板

### 5.1 `summary.txt` 模板

```text
AutoLedger Feedback Summary
===========================

Feedback ID: {{feedback_id}}
Level: {{feedback_level}}
Issue Type: {{issue_type}}

App Version: {{app_version}}
Build: {{build_number}}
Platform: iOS
iOS Version: {{ios_version}}
Device Model: {{device_model}}

Entry Point: {{entry_point}}
Event Time: {{event_time_local}}

User Description:
{{user_description}}

Expected Result:
{{expected_result}}

Actual Result:
{{actual_result}}

Reproducible:
{{reproducible}}

Redaction:
{{redaction_summary}}

Attachments:
{{attachment_summary}}
```

### 5.2 `metadata.json` 模板

```json
{
  "bundle_version": "1.0",
  "feedback_id": "{{feedback_id}}",
  "feedback_level": "{{feedback_level}}",
  "generated_at": "{{generated_at_iso}}",
  "app_name": "AutoLedger",
  "app_version": "{{app_version}}",
  "build_number": "{{build_number}}",
  "platform": "iOS",
  "ios_version": "{{ios_version}}",
  "device_model": "{{device_model}}",
  "entry_point": "{{entry_point}}",
  "redaction_profile": "{{redaction_profile}}",
  "contains_raw_image": {{contains_raw_image}},
  "contains_full_ocr_text": {{contains_full_ocr_text}}
}
```

### 5.3 `issue_bundle.json` 模板（L1）

```json
{
  "feedback_id": "{{feedback_id}}",
  "feedback_level": "L1",
  "issue_type": "{{issue_type}}",
  "user_description": "{{user_description}}",
  "expected_result": "{{expected_result}}",
  "actual_result": "{{actual_result}}",
  "reproducible": "{{reproducible}}",
  "app": {
    "name": "AutoLedger",
    "version": "{{app_version}}",
    "build": "{{build_number}}",
    "platform": "iOS",
    "ios_version": "{{ios_version}}",
    "device_model": "{{device_model}}"
  },
  "event": {
    "time_local": "{{event_time_local}}",
    "time_iso": "{{event_time_iso}}",
    "entry_point": "{{entry_point}}"
  },
  "debug": {
    "ocr_status": "{{ocr_status}}",
    "parse_status": "{{parse_status}}",
    "save_status": "{{save_status}}",
    "parsed_result": {
      "amount": "{{parsed_amount}}",
      "merchant": "{{parsed_merchant}}",
      "time": "{{parsed_time}}"
    }
  },
  "privacy": {
    "redacted": true,
    "contains_full_ocr_text": false,
    "contains_raw_image": false
  }
}
```

### 5.4 `issue_bundle.json` 模板（L2）

```json
{
  "feedback_id": "{{feedback_id}}",
  "feedback_level": "L2",
  "issue_type": "{{issue_type}}",
  "user_description": "{{user_description}}",
  "expected_result": "{{expected_result}}",
  "actual_result": "{{actual_result}}",
  "reproducible": "{{reproducible}}",
  "app": {
    "name": "AutoLedger",
    "version": "{{app_version}}",
    "build": "{{build_number}}",
    "platform": "iOS",
    "ios_version": "{{ios_version}}",
    "device_model": "{{device_model}}"
  },
  "event": {
    "time_local": "{{event_time_local}}",
    "time_iso": "{{event_time_iso}}",
    "entry_point": "{{entry_point}}"
  },
  "debug": {
    "ocr_status": "{{ocr_status}}",
    "parse_status": "{{parse_status}}",
    "save_status": "{{save_status}}",
    "ocr_text_redacted": "{{ocr_text_redacted}}",
    "parsed_result": {
      "amount": "{{parsed_amount}}",
      "merchant": "{{parsed_merchant}}",
      "time": "{{parsed_time}}",
      "confidence": "{{parse_confidence}}"
    },
    "trace": [
      "capture_received",
      "ocr_started",
      "ocr_completed",
      "parse_started",
      "parse_completed",
      "save_succeeded"
    ]
  },
  "privacy": {
    "redacted": true,
    "contains_full_ocr_text": false,
    "contains_raw_image": false
  }
}
```

### 5.5 `issue_bundle.json` 模板（L3）

```json
{
  "feedback_id": "{{feedback_id}}",
  "feedback_level": "L3",
  "issue_type": "{{issue_type}}",
  "user_description": "{{user_description}}",
  "expected_result": "{{expected_result}}",
  "actual_result": "{{actual_result}}",
  "reproducible": "{{reproducible}}",
  "app": {
    "name": "AutoLedger",
    "version": "{{app_version}}",
    "build": "{{build_number}}",
    "platform": "iOS",
    "ios_version": "{{ios_version}}",
    "device_model": "{{device_model}}"
  },
  "event": {
    "time_local": "{{event_time_local}}",
    "time_iso": "{{event_time_iso}}",
    "entry_point": "{{entry_point}}"
  },
  "debug": {
    "ocr_status": "{{ocr_status}}",
    "parse_status": "{{parse_status}}",
    "save_status": "{{save_status}}",
    "ocr_text_redacted": "{{ocr_text_redacted}}",
    "ocr_text_full_file": "full_ocr_text.txt",
    "parsed_result": {
      "amount": "{{parsed_amount}}",
      "merchant": "{{parsed_merchant}}",
      "time": "{{parsed_time}}",
      "confidence": "{{parse_confidence}}"
    },
    "trace_file": "trace.log"
  },
  "attachments": {
    "has_screenshot": {{has_screenshot}},
    "screenshot_file": "{{screenshot_file_name}}"
  },
  "privacy": {
    "redacted": true,
    "contains_full_ocr_text": true,
    "contains_raw_image": {{contains_raw_image}}
  }
}
```

---

## 6. 建议的问题类型枚举

```text
feedback
ocr_parse_wrong
merchant_parse_wrong
amount_parse_wrong
time_parse_wrong
save_failed
shortcut_flow
share_extension
camera_import
clipboard_import
ui_bug
performance
crash
other
```

---

## 7. 建议的脱敏标记模板

### 文本版

```text
transaction_id: masked
merchant_full_name: masked
card_number: masked
long_numeric_string: masked
email: masked
phone: masked
```

### JSON 版

```json
{
  "redaction_summary": [
    "transaction_id_masked",
    "merchant_full_name_masked",
    "long_numeric_string_masked"
  ]
}
```

---

## 8. 建议的落地顺序

### 第一阶段
- L1 标准反馈
- L2 增强调试

### 第二阶段
- 邮件发送前预览
- 选择是否附加增强日志
- issue_bundle.json 结构稳定

### 第三阶段
- L3 完整诊断
- 可选截图附加
- 高级测试者反馈流程

---

## 9. 当前建议

当前产品阶段不建议一开始就让普通用户发送 L3 完整诊断包。  
建议：

- L1：默认入口
- L2：高级反馈入口
- L3：仅内部或高级测试者开启
