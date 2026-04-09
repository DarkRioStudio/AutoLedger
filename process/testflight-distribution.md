# TestFlight 分发指南

更新日期：2026-04-09

## 概述

当 Xcode Cloud / GitHub Actions / 手动 Archive 成功上传构建包到 App Store Connect 并收到 TestFlight 的"构建包已准备好测试"邮件之后，可通过以下两种方式邀请测试者。

---

## 方式一：公开链接（Public Link）——最常用

适用于向不特定人群开放内测，最多支持 10,000 名外部测试者。

### 操作步骤

1. 打开 [App Store Connect](https://appstoreconnect.apple.com)，使用 Apple Developer 账号登录。
2. 在"我的 App"中选择 **AutoLedger**。
3. 点击顶部导航 **TestFlight** 标签页。
4. 在左侧边栏找到 **外部测试**（External Testing）→ 点击 **+** 创建一个测试组（如"公开内测"）。
5. 进入该测试组，将当前已审核通过的构建包添加到组里（首次外部测试需提交 Beta 审核，一般 1–2 个工作日通过）。
6. 开启 **"启用公开链接"（Enable Public Link）**，系统生成一条形如：  
   `https://testflight.apple.com/join/XXXXXXXX`  
   的链接。
7. 复制该链接，通过微信群、邮件、GitHub README 等任意渠道分享给测试者。

> **注意**：外部测试组的构建包需要通过 Apple 的 Beta App Review 才能对外发放公开链接。内部测试组（Internal Group）无需审核，但成员须为 App Store Connect 账号下的团队成员，且最多 100 人。

---

## 方式二：指定邮件邀请（Email Invitation）

适用于向固定名单发送邀请。

### 操作步骤（外部测试者）

1. 同上，进入 **TestFlight → 外部测试 → 你的测试组**。
2. 在测试组内选择 **测试员** 标签页，点击 **+** 添加测试者邮件地址。
3. App Store Connect 会向该邮箱发送一封包含安装链接的邀请邮件，测试者点击邮件中的链接即可安装。

### 操作步骤（内部测试者）

1. 进入 **TestFlight → 内部测试 → App Store Connect Users**。
2. 勾选要邀请的团队成员，保存后他们将收到邀请邮件。

---

## 方式三：在 README 中嵌入公开链接

获得公开链接后，可在 `README.md` 中添加 TestFlight 徽章，方便用户一键跳转安装：

```markdown
[![TestFlight](https://img.shields.io/badge/TestFlight-内测中-blue?logo=apple)](https://testflight.apple.com/join/XXXXXXXX)
```

将 `XXXXXXXX` 替换为实际链接中的 Join Code。

---

## 常见问题

| 问题 | 说明 |
|---|---|
| 收到"构建包已准备好测试"邮件但链接还没生成 | 外部测试需等待 Beta App Review 通过；内部测试则直接在内部测试组里即可看到构建包 |
| 公开链接点击后显示"邀请已满或链接已停用" | 检查 App Store Connect 中测试组的"启用公开链接"开关是否仍处于开启状态 |
| 内部测试者看不到新版本 | 确认已将新构建包勾选到内部测试组，并且测试者的 TestFlight App 版本没有过期 |
| 外部 Beta 审核被拒 | 查看 App Store Connect 中的拒绝原因，修复后重新提审；常见原因：缺少测试账号说明、崩溃率过高 |

---

## 参考链接

- [Apple 文档：分发 Beta 版本并收集反馈](https://developer.apple.com/cn/testflight/)
- [App Store Connect Help：TestFlight 测试概述](https://help.apple.com/app-store-connect/#/dev0067a330b)
