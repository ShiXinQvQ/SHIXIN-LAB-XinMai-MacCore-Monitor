# SHIXIN LAB · 「芯脉」
## 版权、源码许可与第三方声明 | Copyright, Source License & Third-Party Notices
版本 0.3.0-beta · 构建 300 · 2026

---

# 中文声明

## 产品身份与版权

Copyright © 2026 SHIXIN LAB / Shixin。SHIXIN LAB · 「芯脉」 MacCore Monitor 由 Shixin 主导设计、开发与维护。本发行包对应版本 0.3.0-beta，构建号 300。

除仓库文件或第三方许可证另有明确说明外，产品名称、品牌视觉、最终 v3 图标、原创界面设计、中文与英文文档、宣传材料及其他 SHIXIN LAB 原创资产均受著作权保护。

## 原创源码许可

项目源码发布于：

https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor

仓库中的 SHIXIN LAB 原创 App 源码和原创资产适用仓库根目录的 **SHIXIN LAB Source-Available Notice**。源码公开用于审查、透明说明、学习参考与安全检查；除非 SHIXIN LAB 另行书面授权，不得复制、再分发、再授权、销售、发布修改版本，或将原创源码与资产用于其他产品。

这是一项 source-available（源码可见）许可，不应被误解为 OSI 定义下的开源许可。仓库根目录 `LICENSE` 是原创源码授权范围与条件的最终依据；第三方组件继续适用各自许可证。

## smartmontools / smartctl

部分构建可能随 App 附带 smartmontools 项目的 smartctl 独立命令行工具，仅用于只读 SMART / NVMe 温度查询。是否附带、具体版本和二进制 SHA-256 以该 App 内 `Contents/Resources/Licenses/smartctl-version.txt` 为准；不存在该文件即表示该构建未附带 smartctl。

- 官方项目：https://github.com/smartmontools/smartmontools
- 版权：smartmontools contributors
- 许可证：GNU General Public License，version 2 or later（GPL-2.0-or-later）
- 完整许可证：DMG 与 App 内的 `smartmontools-COPYING.txt`
- 第三方摘要：DMG 与 App 内的 `THIRD-PARTY-NOTICES.txt`

smartctl 是与「芯脉」分离调用的上游程序，其 GPL 条款不被本项目的 Source-Available Notice 替代。如果发行构建附带 smartctl，DMG 的 `Licenses` 目录会同时提供该二进制对应版本的源码归档。

## 平台、服务与商标

Apple、Mac、macOS、Apple Silicon、Metal 以及相关名称和商标归 Apple Inc. 所有。「芯脉」是独立第三方工具，与 Apple Inc. 不存在隶属、赞助、背书或官方认证关系。

网络测速与诊断可能按用户指令使用 macOS networkQuality、ipify、ipwho.is 与 proxycheck.io。相关平台、服务、商标、数据可用性和结果解释由各自提供方负责；第三方结果可能随时间变化或存在误差。

## 数据、测量与安全边界

App 的硬件功耗、频率、热状态与传感器数据来自 macOS 及当前 Mac 暴露的接口，属于系统估算或 best-effort 观察。不同机型、系统版本、传感器和权限状态可能产生字段差异，结果不能替代外部实验室仪器或专业认证。

压力测试会真实增加设备功耗和温度。用户应保存重要工作、选择合适时长、保持通风并持续观察热状态。App 提供手动停止与热状态保护，但不能消除不当使用、设备差异或外部环境造成的全部风险。

本 Beta 按现状提供。在适用法律允许的最大范围内，SHIXIN LAB 不对第三方服务中断、设备或网络差异、不当操作，或超出软件控制范围的结果作额外保证。

## 隐私与公开反馈

App 不会在后台上传硬件历史或个人内容；用户主动开始网速测试、国际诊断或 IP 分析时会发生对应网络请求。诊断报告可能包含设备与系统环境信息，向公开 Issue 提交前应先检查并移除个人路径、设备标识或其他敏感内容。

## 发行完整性与追溯

请只从 SHIXIN LAB 官网或项目 GitHub Releases 获取安装包，并使用与目标 DMG 同时发布的 SHA-256 文件验证。本发行对应 Helper `0.3.0-helper`；DMG 内的 Release Manifest 记录产品版本、构建号、Helper 版本、源码提交、架构与生成时间。不同时间戳的发行文件不得混用校验值。

<!-- PAGEBREAK -->

# English Notice

## Product Identity and Copyright

Copyright © 2026 SHIXIN LAB / Shixin. SHIXIN LAB · 「芯脉」 MacCore Monitor is designed, developed, and maintained by Shixin. This distribution contains version 0.3.0-beta, build 300.

Unless a repository file or third-party license explicitly states otherwise, the product name, brand visuals, final v3 icon, original interface design, Chinese and English documentation, promotional materials, and other original SHIXIN LAB assets are protected by copyright.

## Original Source License

Project source is published at:

https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor

Original SHIXIN LAB app source and assets in the repository are governed by the **SHIXIN LAB Source-Available Notice** at the repository root. They are published for review, transparency, learning, and security inspection. Unless SHIXIN LAB gives separate written permission, they may not be copied, redistributed, sublicensed, sold, published in modified form, or used in another product.

This is a source-available license and must not be represented as an OSI-approved open-source license. The root `LICENSE` file is authoritative for original project code. Third-party components remain governed by their own licenses.

## smartmontools / smartctl

Some builds may bundle the standalone smartctl command-line tool from smartmontools for read-only SMART / NVMe temperature queries. Inclusion, exact version, and binary SHA-256 are recorded in `Contents/Resources/Licenses/smartctl-version.txt` inside the app. If that file is absent, the build does not bundle smartctl.

- Official project: https://github.com/smartmontools/smartmontools
- Copyright: smartmontools contributors
- License: GNU General Public License, version 2 or later (GPL-2.0-or-later)
- Complete license: `smartmontools-COPYING.txt` in the DMG and app
- Third-party summary: `THIRD-PARTY-NOTICES.txt` in the DMG and app

smartctl is an independently invoked upstream program. Its GPL terms are not replaced by the project’s Source-Available Notice. If a release bundles smartctl, the DMG `Licenses` directory also provides the corresponding source archive for that exact binary version.

## Platforms, Services, and Trademarks

Apple, Mac, macOS, Apple Silicon, Metal, and related names or marks belong to Apple Inc. XinMai is an independent third-party utility and is not affiliated with, sponsored by, endorsed by, or officially certified by Apple Inc.

At the user’s request, network testing and diagnostics may use macOS networkQuality, ipify, ipwho.is, and proxycheck.io. Each provider remains responsible for its own platform, service, marks, data availability, and result interpretation. Third-party results may change over time or contain errors.

## Data, Measurement, and Safety Boundaries

Hardware power, frequency, thermal state, and sensor data come from interfaces exposed by macOS and the current Mac. They are system estimates or best-effort observations. Fields can vary by model, operating-system release, available sensors, and permission state, and the results do not replace external laboratory instruments or professional certification.

Stress tests create real heat and power use. Users should save important work, choose an appropriate duration, keep the Mac ventilated, and observe thermal status. The app provides manual stopping and thermal protections, but it cannot remove every risk created by misuse, device variation, or the surrounding environment.

This Beta is provided as is. To the maximum extent permitted by applicable law, SHIXIN LAB makes no additional warranty for third-party service interruption, hardware or network differences, misuse, or outcomes beyond the software’s control.

## Privacy and Public Reports

The app does not upload hardware history or personal content in the background. Speed tests, international diagnostics, and IP analysis make their corresponding network requests only after the user starts them. Diagnostic reports can contain device and system-environment details; review and remove personal paths, device identifiers, or other sensitive content before posting to a public issue.

## Release Integrity and Traceability

Obtain packages only from the SHIXIN LAB website or project GitHub Releases. Verify the target DMG with the SHA-256 file published beside that exact artifact. This release expects Helper `0.3.0-helper`; the Release Manifest inside the DMG records the product version, build number, Helper version, source commit, architecture, and generation time. Never reuse a checksum from a differently timestamped package.
