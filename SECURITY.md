# Security Policy / 安全策略

## Supported Release / 当前支持版本

Security reports are evaluated against the latest published `0.3.0-beta`
source and release package. Older builds may be used for comparison but are not
the primary remediation target.

安全问题以最新公开的 `0.3.0-beta` 源码与发行包为主要修复对象。旧构建可用于
对比，但不作为首要维护目标。

## Reporting a Vulnerability / 报告漏洞

Use GitHub private vulnerability reporting when it is available. If it is not
available, contact SHIXIN LAB through the official website first and provide
only a minimal, redacted summary until a private channel is agreed:

若仓库已开放 GitHub 私密漏洞报告，请优先使用。若暂未开放，请先通过 SHIXIN
LAB 官网联系，并仅提交经过脱敏的最小摘要，待确认私密渠道后再提供完整细节：

- https://shixinqvq.com/

Do not post a working exploit, administrator credentials, diagnostic archives,
full local paths, public or private IP addresses, serial numbers, Provisioning
UDIDs, platform UUIDs, MAC/BSSID/SSID values, or unredacted user data in a
public issue.

请勿在公开 Issue 中发布可直接利用的攻击内容、管理员凭据、诊断压缩包、完整
本机路径、公网或本机 IP、序列号、Provisioning UDID、平台 UUID、MAC/BSSID/
SSID 或未经脱敏的用户数据。

A useful report includes the affected app version/build, Helper version, macOS
version, Mac model, expected and actual behavior, minimal reproduction steps,
and whether the issue crosses a documented local-only, permission, or network
boundary.

有效报告应包含：受影响的 App 版本/build、Helper 版本、macOS 版本、Mac 型号、
预期与实际行为、最小复现步骤，以及问题是否突破本地存储、权限或联网边界。

## Release Integrity / 发布完整性

Official packages are distributed through SHIXIN LAB channels. Verify the DMG
against the SHA-256 file published beside that exact artifact. Never reuse a
checksum from an older or differently timestamped package.

正式安装包仅通过 SHIXIN LAB 官方渠道提供。请使用与目标 DMG 同时发布的
SHA-256 文件核对完整性，不要沿用旧版本或其他时间戳文件的校验值。
