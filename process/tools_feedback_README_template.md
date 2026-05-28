# AutoLedger Feedback Processor

本目录用于处理用户通过邮件发送的反馈日志，并将其自动转换为 GitHub Issue，供后续人工分诊、Copilot 辅助修复和代码迭代使用。

当前目标是打通以下链路：

```text
用户 App 内反馈
→ 邮件发送到 support@darkrio326.top
→ Cloudflare Email Routing 转发到 Gmail
→ GitHub Actions 定时拉取 Gmail 未读邮件
→ 解析反馈邮件与附件
→ 自动创建 GitHub Issue
→ 人工筛选 issue
→ 交给 Copilot / Agent 分析和修复
→ 人工 review + merge
```

---

## 1. 目录说明

```text
tools/feedback/
├─ README.md                # 当前说明文档
├─ requirements.txt         # Python 依赖
├─ email_to_issue.py        # 主处理脚本：邮件 -> GitHub Issue
└─ templates/
   └─ issue_body.md.j2      # （可选）未来用于渲染 issue 模板
```

---

## 2. 当前设计目标

当前版本只做到：

- 从 Gmail 收件箱读取未读反馈邮件
- 解析邮件主题、正文、附件
- 提取 `issue_bundle.json`、`summary.txt`、`metadata.json`
- 对正文和部分内容做二次脱敏
- 自动创建 GitHub Issue
- 给邮件打上“已处理”状态（通过标记已读）

当前版本 **不做**：

- 自动上传原始截图到 GitHub
- 自动让 AI 改代码
- 自动创建 Pull Request
- 自动合并修复

这些后续可以在 issue 流程稳定后再逐步增加。

---

## 3. 邮件输入约定

反馈邮件建议由 App 内反馈功能统一生成。

### 3.1 邮件主题约定

建议统一格式：

```text
[AutoLedger][L1][iOS][1.0.0(5)][feedback] 问题反馈
[AutoLedger][L2][iOS][1.0.0(5)][ocr_parse_wrong] 金额识别错误
[AutoLedger][L3][iOS][1.0.0(5)][full_diagnostic] 完整诊断包
```

脚本会优先读取主题中包含的前缀，例如：

```text
[AutoLedger]
```

该前缀可通过环境变量 `FEEDBACK_SUBJECT_PREFIX` 覆盖。

### 3.2 邮件正文约定

正文建议包含：

- 用户描述
- 预期结果
- 实际结果
- 可复现性
- 发生时间
- 结构化的 `AUTOLEDGER_FEEDBACK_META` 区块

---

## 4. 附件 bundle 约定

反馈邮件推荐附带一个 zip 文件，内部结构如下：

### L1 标准反馈

```text
AutoLedger_Feedback_L1_AL-20260410-0001.zip
└── feedback_bundle/
    ├── issue_bundle.json
    ├── summary.txt
    └── metadata.json
```

### L2 增强调试

```text
AutoLedger_Feedback_L2_AL-20260410-0002.zip
└── feedback_bundle/
    ├── issue_bundle.json
    ├── summary.txt
    ├── metadata.json
    ├── trace.log
    └── redacted_ocr_context.txt
```

### L3 完整诊断

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

## 5. 环境依赖

当前脚本使用：

- Python 3.11
- Gmail IMAP
- GitHub REST API

依赖安装：

```bash
pip install -r tools/feedback/requirements.txt
```

---

## 6. 环境变量

运行脚本前需要以下环境变量：

### 必填

- `GMAIL_USERNAME`
- `GMAIL_APP_PASSWORD`
- `GITHUB_TOKEN`
- `GITHUB_REPOSITORY`

### 可选

- `FEEDBACK_SUBJECT_PREFIX`
  - 默认值：`[AutoLedger]`

---

## 7. 本地运行方式

```bash
export GMAIL_USERNAME="user@example.com"
export GMAIL_APP_PASSWORD="your-app-password"
export FEEDBACK_SUBJECT_PREFIX="[AutoLedger]"
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
export GITHUB_REPOSITORY="darkrio326/AutoLedger"

python tools/feedback/email_to_issue.py
```

---

## 8. GitHub Actions 运行方式

GitHub Actions workflow 文件位于：

```text
.github/workflows/feedback-email-to-issue.yml
```

当前支持两种触发方式：

- 手动触发：`workflow_dispatch`
- 定时触发：`schedule`

推荐保留：

```yaml
schedule:
  - cron: "*/15 * * * *"
```

---

## 9. Gmail 配置说明

推荐使用：

### Gmail + 两步验证 + App Password

操作步骤：

1. 开启 Gmail 两步验证
2. 生成一个 App Password
3. 将该密码填入 `GMAIL_APP_PASSWORD`

---

## 10. GitHub Issue 生成规则

脚本会自动生成类似如下标题的 issue：

```text
[iOS 1.0.0][ocr_parse_wrong][L2] 金额识别错误
```

并自动附加 labels，例如：

- `feedback`
- `source/email`
- `level/L2`
- `type/ocr_parse_wrong`
- `status/new`

---

## 11. 去重策略

为了避免重复创建 issue，脚本会优先使用以下字段去重：

1. `issue_bundle.json.feedback_id`
2. 邮件正文中的 `feedback_id`
3. Gmail Message-ID 的哈希 fallback

创建 issue 前会搜索：

```text
Feedback-ID: {feedback_id}
```

如果 issue 已存在，则不会重复创建。

---

## 12. 服务端脱敏策略

即使客户端已经做过脱敏，服务端仍会进行二次脱敏。

当前默认规则包括：

- 邮箱地址 -> `[EMAIL_MASKED]`
- 手机号 -> `[PHONE_MASKED]`
- 长数字串（8 位以上）-> `[LONG_NUMBER_MASKED]`

---

## 13. 当前建议的人工处理流程

自动化目前只做到 issue 阶段。  
建议的后续人工处理流程如下：

1. 查看新 issue
2. 判断是否需要处理
3. 给需要修复的 issue 打标签：
   - `ready-for-fix`
4. 将 issue 内容交给 Copilot / Agent
5. 让 AI 先分析 root cause
6. 再决定是否改代码
7. 本地测试
8. 人工 review + merge

---

## 14. 为什么当前不自动创建 PR

当前阶段不建议做：

```text
邮件 -> issue -> AI 自动改代码 -> 自动 PR -> 自动 merge
```

原因：

- 用户邮件描述天然不稳定
- OCR / 解析问题容易误判
- 自动 PR 风险较高
- 目前更适合“自动建 issue + 人工挑选 + AI 辅助修复”

---

## 15. 后续扩展方向

未来可以考虑增加：

- Web 反馈入口
- issue triage 自动化
- issue -> PR 自动化

---

## 16. 常见问题

### Q1：为什么不用 GitHub Issue 让用户直接提？
因为当前 repo 是 private，而且普通测试用户使用 GitHub issue 的门槛较高。邮件反馈更符合 TestFlight 用户习惯。

### Q2：为什么不用 Gmail API？
当前版本优先使用 Gmail IMAP + App Password，是为了降低接入复杂度。以后如需更复杂的标签和搜索能力，可升级到 Gmail API。

### Q3：为什么不把原始截图直接上传到 Issue？
因为截图可能包含个人信息或支付信息。当前默认只保留结构化摘要和脱敏上下文。

### Q4：issue 创建成功后还需要做什么？
需要人工看一遍，确认问题是否真实、是否可复现，再决定是否交给 Copilot / Agent 修复。

---

## 17. 当前维护建议

- 每次调整客户端反馈格式时，同步更新本 README
- 保持 `issue_bundle.json` 字段兼容
- 不要在 issue 正文里写入未脱敏的原始敏感信息
- 对高风险附件（如原图）保持“默认不上传，显式选择才发送”

---

## 18. 当前状态

当前反馈自动化链路目标：

```text
已规划：
邮件 -> issue

暂不自动化：
issue -> PR
```
