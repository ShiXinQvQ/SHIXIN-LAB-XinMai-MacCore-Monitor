# SHIXIN LAB · 「芯脉」
## 版权、开源许可与第三方声明 | Copyright, Open Source License & Third-Party Notices
版本 0.3.0-beta · 构建 300 · 2026

---

# 中文声明

## 产品身份与版权

Copyright © 2026 SHIXIN LAB / Shixin。SHIXIN LAB · 「芯脉」 MacCore Monitor 由 Shixin 主导设计、开发与维护。本发行包对应版本 0.3.0-beta，构建号 300。

SHIXIN LAB 自有程序源码的著作权仍归 SHIXIN LAB / Shixin 所有，并按 GPL-3.0-or-later 授权。产品名称、品牌视觉、最终 v3 图标、Logo、截图、宣传视觉、中英文文档及其他 SHIXIN LAB 原创品牌资产不因源码开源而失去著作权保护。

## 程序源码许可

项目源码发布于：

https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor

除具体文件另有声明外，仓库中的 SHIXIN LAB 自有程序源码按照 **GNU General Public License 第 3 版或任何后续版本（GPL-3.0-or-later）**开源。完整许可证正文以仓库根目录的 `LICENSE` 为准。

GPL 允许在遵守其条件的前提下使用、研究、修改与再分发程序。对外分发程序或修改版本时，必须保留适用声明、提供对应源码，并明确标记修改。该许可不会转移源码著作权。

## 品牌与原创资产

GPL 对程序源码的授权不包含商标、品牌身份、宣传或官方背书授权。未经 SHIXIN LAB 事先书面许可，不得使用 SHIXIN LAB、「芯脉」、XinMai、MacCore Monitor 等产品标识，或最终 v3 图标、Logo、截图、宣传视觉及其他受保护品牌资产，把修改版或第三方构建包装成官方版本。

公开再分发的 Fork 应使用不同的产品名称并替换上述受保护资产，同时清楚标明其经过修改且并非官方版本。仓库根目录 `NOTICE.md` 是代码许可范围、品牌资产边界与贡献规则的明确说明；第三方组件继续适用各自许可证。

## smartmontools / smartctl

部分构建可能随 App 附带 smartmontools 项目的 smartctl 独立命令行工具，仅用于只读 SMART / NVMe 温度查询。是否附带、具体版本和二进制 SHA-256 以该 App 内 `Contents/Resources/Licenses/smartctl-version.txt` 为准；不存在该文件即表示该构建未附带 smartctl。

- 官方项目：https://github.com/smartmontools/smartmontools
- 版权：smartmontools contributors
- 许可证：GNU General Public License，version 2 or later（GPL-2.0-or-later）
- 完整许可证：DMG 与 App 内的 `smartmontools-COPYING.txt`
- 第三方摘要：DMG 与 App 内的 `THIRD-PARTY-NOTICES.txt`

smartctl 是与「芯脉」分离调用的上游程序，并继续适用其自身的 GPL-2.0-or-later。如果发行构建附带 smartctl，DMG 的 `Licenses` 目录会同时提供该二进制对应版本的源码归档。

## 平台、服务与商标

Apple、Mac、macOS、Apple Silicon、Metal 以及相关名称和商标归 Apple Inc. 所有。「芯脉」是独立第三方工具，与 Apple Inc. 不存在隶属、赞助、背书或官方认证关系。

网络测速与诊断可能按用户指令使用 macOS networkQuality、ipify、ipwho.is 与 proxycheck.io。相关平台、服务、商标、数据可用性和结果解释由各自提供方负责；第三方结果可能随时间变化或存在误差。

## 数据、测量与安全边界

App 的硬件功耗、频率、热状态与传感器数据来自 macOS 及当前 Mac 暴露的接口，属于系统估算或 best-effort 观察。不同机型、系统版本、传感器和权限状态可能产生字段差异，结果不能替代外部实验室仪器或专业认证。

压力测试会真实增加设备功耗和温度。用户应保存重要工作、选择合适时长、保持通风并持续观察热状态。App 提供手动停止与热状态保护，但不能消除不当使用、设备差异或外部环境造成的全部风险。

本发行按现状提供。在适用法律允许的最大范围内，SHIXIN LAB 不对第三方服务中断、设备或网络差异、不当操作，或超出软件控制范围的结果作额外保证。GPL 完整免责声明以仓库与 DMG 内附许可证正文为准。

## 隐私与公开反馈

App 不会在后台上传硬件历史或个人内容；用户主动开始网速测试、国际诊断或 IP 分析时会发生对应网络请求。诊断报告可能包含设备与系统环境信息，向公开 Issue 提交前应先检查并移除个人路径、设备标识或其他敏感内容。

## 发行完整性与追溯

请只从 SHIXIN LAB 官网或项目 GitHub Releases 获取安装包，并使用与目标 DMG 同时发布的 SHA-256 文件验证。本发行对应 Helper `0.3.0-helper`；DMG 内的 Release Manifest 记录产品版本、构建号、Helper 版本、源码提交、架构与生成时间。不同时间戳的发行文件不得混用校验值。

<!-- PAGEBREAK -->

# English Notice

## Product Identity and Copyright

Copyright © 2026 SHIXIN LAB / Shixin. SHIXIN LAB · 「芯脉」 MacCore Monitor is designed, developed, and maintained by Shixin. This distribution contains version 0.3.0-beta, build 300.

Copyright in SHIXIN LAB-owned program source remains with SHIXIN LAB / Shixin and is licensed under GPL-3.0-or-later. The product name, brand visuals, final v3 icon, logos, screenshots, promotional artwork, bilingual documentation, and other original SHIXIN LAB brand assets remain protected by copyright even though the source code is open source.

## Program Source License

Project source is published at:

https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor

Unless a specific file states otherwise, SHIXIN LAB-owned program source in the repository is free software licensed under the **GNU General Public License, version 3 or any later version (GPL-3.0-or-later)**. The complete license text in the root `LICENSE` file is authoritative.

The GPL permits use, study, modification, and redistribution under its conditions. A distribution of the program or a modified version must preserve applicable notices, provide corresponding source, and clearly identify modifications. The license does not transfer ownership of the source copyright.

## Brand and Original Assets

The GPL source-code grant does not include a trademark, brand-identity, publicity, or endorsement license. Without prior written permission from SHIXIN LAB, SHIXIN LAB, XinMai, MacCore Monitor, the final v3 icon, logos, screenshots, promotional artwork, and other protected brand assets may not be used to present a modified or third-party build as an official release.

A publicly redistributed fork should use a distinct product name, replace the protected assets above, and clearly identify itself as modified and unofficial. The root `NOTICE.md` defines the code-license scope, brand-asset boundary, and contribution terms. Third-party components remain governed by their own licenses.

## smartmontools / smartctl

Some builds may bundle the standalone smartctl command-line tool from smartmontools for read-only SMART / NVMe temperature queries. Inclusion, exact version, and binary SHA-256 are recorded in `Contents/Resources/Licenses/smartctl-version.txt` inside the app. If that file is absent, the build does not bundle smartctl.

- Official project: https://github.com/smartmontools/smartmontools
- Copyright: smartmontools contributors
- License: GNU General Public License, version 2 or later (GPL-2.0-or-later)
- Complete license: `smartmontools-COPYING.txt` in the DMG and app
- Third-party summary: `THIRD-PARTY-NOTICES.txt` in the DMG and app

smartctl is an independently invoked upstream program and remains under its own GPL-2.0-or-later terms. If a release bundles smartctl, the DMG `Licenses` directory also provides the corresponding source archive for that exact binary version.

## Platforms, Services, and Trademarks

Apple, Mac, macOS, Apple Silicon, Metal, and related names or marks belong to Apple Inc. XinMai is an independent third-party utility and is not affiliated with, sponsored by, endorsed by, or officially certified by Apple Inc.

At the user’s request, network testing and diagnostics may use macOS networkQuality, ipify, ipwho.is, and proxycheck.io. Each provider remains responsible for its own platform, service, marks, data availability, and result interpretation. Third-party results may change over time or contain errors.

## Data, Measurement, and Safety Boundaries

Hardware power, frequency, thermal state, and sensor data come from interfaces exposed by macOS and the current Mac. They are system estimates or best-effort observations. Fields can vary by model, operating-system release, available sensors, and permission state, and the results do not replace external laboratory instruments or professional certification.

Stress tests create real heat and power use. Users should save important work, choose an appropriate duration, keep the Mac ventilated, and observe thermal status. The app provides manual stopping and thermal protections, but it cannot remove every risk created by misuse, device variation, or the surrounding environment.

This release is provided as is. To the maximum extent permitted by applicable law, SHIXIN LAB makes no additional warranty for third-party service interruption, hardware or network differences, misuse, or outcomes beyond the software’s control. The complete GPL warranty disclaimer is provided in the license text included with the repository and DMG.

## Privacy and Public Reports

The app does not upload hardware history or personal content in the background. Speed tests, international diagnostics, and IP analysis make their corresponding network requests only after the user starts them. Diagnostic reports can contain device and system-environment details; review and remove personal paths, device identifiers, or other sensitive content before posting to a public issue.

## Release Integrity and Traceability

Obtain packages only from the SHIXIN LAB website or project GitHub Releases. Verify the target DMG with the SHA-256 file published beside that exact artifact. This release expects Helper `0.3.0-helper`; the Release Manifest inside the DMG records the product version, build number, Helper version, source commit, architecture, and generation time. Never reuse a checksum from a differently timestamped package.
