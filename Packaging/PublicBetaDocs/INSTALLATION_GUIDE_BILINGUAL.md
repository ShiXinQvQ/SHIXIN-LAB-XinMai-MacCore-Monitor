# SHIXIN LAB · 「芯脉」
## 安装与使用说明 | Installation & Usage Guide
版本 0.3.0-beta · 构建 300 · Apple Silicon Mac · macOS 15+

---

# 中文说明

## 欢迎使用「芯脉」

SHIXIN LAB · 「芯脉」 MacCore Monitor 是面向 Apple Silicon Mac 的原生性能控制台。它把实时硬件遥测、受控 CPU 与 Metal GPU 压力负载、六组实时曲线、历史记录、性能热力报告、系统网速测试与分层网络诊断整合在同一套 macOS 工作流中。

功耗、频率与热状态主要来自 macOS powermetrics；温度与风扇来自 AppleSMC / HID；系统盘温度由 smartctl 或 diskutil 只读获取。Session、完整 CSV、报告和诊断历史默认保存在本机。

## 发行包内容

- **SHIXIN LAB · 「芯脉」.app**：主程序，版本 0.3.0-beta，构建 300。
- **Applications**：将 App 拖入此快捷方式即可安装到“应用程序”。
- **安装与使用说明**：本双语文档。
- **版权、开源许可与第三方声明**：GPL-3.0-or-later、版权、品牌资产、商标与责任边界。
- **Licenses**：芯脉 GPLv3 正文、SHIXIN LAB 品牌资产声明，以及 smartmontools / smartctl 的第三方声明与完整 GPL 文本；如本构建内置 smartctl，还会包含版本记录和对应源码归档。
- **Release Manifest**：版本、Helper、源码提交、架构与生成时间。

SHA-256 校验文件与 DMG 一同发布，不在 DMG 内。请始终把两者作为同一发行版本保存和核对。

## 安装前检查

- 支持 **Apple Silicon（arm64）Mac**，最低系统为 **macOS 15.0**。
- 更新旧版前先退出正在运行的「芯脉」；替换 App 不会自动删除已有历史数据。
- 压力测试会真实增加功耗与温度。正式测试前请保存其他工作，保持设备通风，并先用较短时长确认状态正常。
- 完整硬件遥测建议安装 App 随附的本地 Helper；网络测速和诊断仅在用户主动开始后联网。

> 只从 SHIXIN LAB 官网或本项目 GitHub Releases 下载。文件名、版本号和 SHA-256 必须属于同一次发行，不能用旧版本校验值验证新 DMG。

## 安装与首次打开

1. 双击打开 DMG。
2. 将“SHIXIN LAB · 「芯脉」.app”拖到 DMG 内的“Applications”快捷方式。
3. 等待复制完成，再从“应用程序”文件夹打开 App；不要长期直接从 DMG 内运行。
4. 如果 macOS 阻止首次打开，请在 Finder 中按住 Control 点按 App，选择“打开”；也可以前往“系统设置 > 隐私与安全性”，确认打开该 App。

如需在终端核对下载，先把 DMG 与同名 `.sha256` 文件放在同一目录，再运行 `shasum -a 256 -c checksum-file.sha256`（将文件名替换为下载页面提供的实际名称）。结果显示 `OK` 才表示下载内容与发布值一致。

## 安装本地 Helper

首次启动后，进入“设置关于 > 高级权限”，选择“安装 Helper”。macOS 会要求管理员授权，把只读硬件采样 Helper 安装为 LaunchDaemon。App 本身不会以 root 运行，也不会保存管理员密码。

Helper 只接受固定的本机 ping 与 sample 请求，用于读取 powermetrics 与硬件遥测；它不负责联网，不写入用户数据，也不执行磁盘修复、擦除、格式化、挂载或卸载操作。网速测试、国际网络诊断与 IP 分析均由普通 App 进程在用户主动操作后执行。

Helper 组件位置：

- /Library/PrivilegedHelperTools/com.shixinqvq.shixinlab.macstresspower.helper
- /Library/LaunchDaemons/com.shixinqvq.shixinlab.macstresspower.helper.plist
- /var/run/com.shixinqvq.shixinlab.macstresspower.helper.sock

安装成功后，权限页应显示 Helper 版本 `0.3.0-helper`。若提示版本不一致，请使用同一页面的更新功能。

## 使用要点

- **实时监测**：查看功耗、温度、频率、风扇、热状态与采样健康。
- **压力测试**：选择 CPU、GPU 或 CPU + GPU 模式；运行中可随时手动停止，系统进入危险热状态时 App 会执行保护停止。
- **数据概览与实时曲线**：集中查看关键指标，并观察功耗、温度、频率、负载、模块温度与风扇的连续变化。
- **历史记录**：查看 Session、完整 CSV、性能热力报告、A/B 对比与高清分享图。
- **网速与网络诊断**：使用 macOS networkQuality 测速，并按需执行国际链路诊断与 IP 分析。

传感器数量会随 Mac 型号和系统版本变化；功耗、频率与温度适合观察当前设备的趋势和相对变化，不能替代外部实验室仪器。

## 本地数据、隐私与联网

压力测试历史、完整 CSV、测速历史、网络诊断历史和运行日志保存在：

`~/Library/Application Support/SHIXIN LAB Mac Stress & Power Monitor/`

该目录沿用早期内部名称，以保证已有用户数据兼容。App 不会在后台上传硬件数据、历史文件或个人内容。

标准网速测试会产生真实下载与上传流量。国际网络诊断会访问测试目标；主动 IP 分析会向 ipify、ipwho.is 与 proxycheck.io 查询当前公网出口与信誉信号。只有用户明确开始对应功能时才会发生这些网络请求。

诊断报告用于排错，可能包含系统版本、Mac 型号、Helper 状态和经过处理的本机环境信息。提交公开 Issue 前仍建议先检查文件内容，不要公开个人路径、设备标识或其他不希望披露的信息。

## 更新、卸载与支持

更新时退出旧版 App，将新版拖入“Applications”并替换即可；已有本机历史不会因替换 App 自动删除。若“设置关于”提示 Helper 版本不一致，请同步更新 Helper。

卸载时先在“设置关于”中选择“卸载 Helper”，再将 App 移入废纸篓。历史数据会继续保留，除非用户另外确认并处理上述 Application Support 目录。

遇到问题时，请在“设置关于”中生成诊断报告，并附上 App 版本/构建、macOS 版本、Mac 型号、复现步骤和预期结果。公开提交前请先检查并脱敏。

- 官网：https://shixinqvq.com/lab/maccore/
- 源码与问题反馈：https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor

<!-- PAGEBREAK -->

# English Guide

## Welcome to XinMai

SHIXIN LAB · 「芯脉」 MacCore Monitor is a native performance console for Apple Silicon Mac. It brings live hardware telemetry, controlled CPU and Metal GPU stress loads, six groups of live charts, session history, thermal performance reports, macOS network-quality testing, and layered network diagnostics into one macOS workflow.

Power, frequency, and thermal state are primarily provided by macOS powermetrics. AppleSMC / HID provide temperature and fan signals, while smartctl or diskutil reads the system-drive temperature in read-only mode. Sessions, complete CSV files, reports, and diagnostic history remain on this Mac by default.

## What Is Included

- **SHIXIN LAB · 「芯脉」.app**: the main app, version 0.3.0-beta, build 300.
- **Applications**: drag the app onto this shortcut to install it in Applications.
- **Installation & Usage Guide**: this bilingual document.
- **Copyright, Open Source License & Third-Party Notices**: GPL-3.0-or-later, copyright, protected brand assets, trademarks, and responsibility terms.
- **Licenses**: the XinMai GPLv3 text, SHIXIN LAB brand-asset notice, and smartmontools / smartctl notices and GPL text. If this build bundles smartctl, it also includes the version record and corresponding source archive.
- **Release Manifest**: product, Helper, source commit, architecture, and generation details.

The SHA-256 checksum file is published beside the DMG, not inside it. Keep and verify both files as one release set.

## Before Installation

- Requires an **Apple Silicon (arm64) Mac** running **macOS 15.0 or later**.
- Quit any running copy of XinMai before replacing an older version. Replacing the app does not automatically remove existing history.
- Stress tests create real heat and power use. Save other work, keep the Mac ventilated, and begin with a short run to confirm normal behavior.
- Install the bundled local Helper for complete hardware telemetry. Speed tests and diagnostics connect only after the user starts them.

> Download only from the SHIXIN LAB website or this project’s GitHub Releases. The filename, version, and SHA-256 must come from the same release; never verify a new DMG with an older checksum.

<!-- PAGEBREAK -->

## Install and Open the App

1. Double-click the DMG to open it.
2. Drag “SHIXIN LAB · 「芯脉」.app” onto the “Applications” shortcut.
3. Wait for copying to finish, then open the app from Applications. Do not use the copy inside the DMG as a permanent installation.
4. If macOS blocks the first launch, Control-click the app in Finder and choose “Open”, or confirm it under “System Settings > Privacy & Security”.

To verify the download in Terminal, place the DMG and its matching `.sha256` file in the same folder, then run `shasum -a 256 -c checksum-file.sha256`. Continue only when the result reports `OK`.

## Install the Local Helper

Open “Settings & About > Advanced Permissions” and choose “Install Helper”. macOS requests administrator authorization to install the read-only telemetry Helper as a LaunchDaemon. The app itself does not run as root and never stores the administrator password.

The Helper accepts only fixed local ping and sample requests for powermetrics and hardware telemetry. It does not access the network, write user data, or perform disk repair, erase, format, mount, or unmount operations. Speed tests, international diagnostics, and IP analysis run in the normal app process only after an explicit user action.

Installed Helper components:

- /Library/PrivilegedHelperTools/com.shixinqvq.shixinlab.macstresspower.helper
- /Library/LaunchDaemons/com.shixinqvq.shixinlab.macstresspower.helper.plist
- /var/run/com.shixinqvq.shixinlab.macstresspower.helper.sock

After installation, Advanced Permissions should report Helper version `0.3.0-helper`. Use the update action on the same page if the versions differ.

## Essential Workflows

- **Live Monitor** shows power, temperature, frequency, fans, thermal state, and sampling health.
- **Stress Test** offers CPU, GPU, and CPU + GPU modes. A run can be stopped at any time, and the app performs a protective stop when the system reaches a dangerous thermal state.
- **Data Overview and Live Curves** summarize key readings and show continuous power, temperature, frequency, load, module-temperature, and fan behavior.
- **History** provides sessions, complete CSV files, thermal reports, A/B comparison, and high-resolution share images.
- **Speed and Network Diagnostics** use macOS networkQuality and provide on-demand international-route checks and IP analysis.

Sensor availability varies by Mac model and macOS release. Power, frequency, and temperature readings are best used for trends and relative comparison on the current device; they do not replace external laboratory instruments.

<!-- PAGEBREAK -->

## Local Data, Privacy, and Network Access

Stress-test history, complete CSV files, speed-test history, network-diagnostic history, and logs are stored under:

`~/Library/Application Support/SHIXIN LAB Mac Stress & Power Monitor/`

The directory retains an earlier internal name to preserve compatibility with existing user data. The app does not upload hardware data, history files, or personal content in the background.

The standard speed test transfers real download and upload traffic. International diagnostics connect to test targets. On-demand IP analysis queries ipify, ipwho.is, and proxycheck.io for the current public egress and reputation signals. These requests occur only after the user starts the relevant feature.

A diagnostic report can contain the macOS version, Mac model, Helper state, and processed local-environment details. Review it before posting to a public issue, and remove personal paths, device identifiers, or anything else you do not intend to disclose.

## Update, Uninstall, and Support

Quit the old version, drag the new app into Applications, and replace the existing copy. Existing local history remains in place. If Settings & About reports a Helper version mismatch, update the Helper as well.

To uninstall, first choose “Uninstall Helper” in Settings & About, then move the app to Trash. Local history is intentionally preserved unless the user separately confirms removal of the Application Support folder above.

For support, generate a diagnostic report under Settings & About and include the app version/build, macOS version, Mac model, reproduction steps, and expected result. Review and redact the report before public submission.

- Website: https://shixinqvq.com/lab/maccore/
- Source and issues: https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor
