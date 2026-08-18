<p align="center">
  <img src="Packaging/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="SHIXIN LAB XinMai final v3 app icon">
</p>

<h1 align="center">SHIXIN LAB · 「芯脉」 MacCore Monitor</h1>

<p align="center">
  让 Mac 的性能脉络，一目了然。<br>
  Your Mac’s performance, clearly in view.
</p>

<p align="center">
  <a href="#download"><strong>Download / 下载</strong></a> ·
  <a href="https://shixinqvq.com/lab/maccore/">Product Page / 产品官网</a> ·
  <a href="SECURITY.md">Security / 安全</a> ·
  <a href="#project-structure">Architecture / 架构</a> ·
  <a href="CONTRIBUTING.md">Contributing / 参与贡献</a>
</p>

<p align="center">
  <a href="https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/tag/v0.3.0-beta"><img alt="release v0.3.0-beta" src="https://img.shields.io/badge/release-v0.3.0--beta-0A84FF?style=flat-square"></a>
  <img alt="source GPL-3.0-or-later" src="https://img.shields.io/badge/source-GPL--3.0--or--later-2EA44F?style=flat-square">
  <img alt="macOS 15 or later" src="https://img.shields.io/badge/macOS-15%2B-555555?style=flat-square">
  <img alt="Apple Silicon arm64" src="https://img.shields.io/badge/Apple%20Silicon-arm64-555555?style=flat-square">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square">
</p>

<a id="english"></a>

## English

`SHIXIN LAB · 「芯脉」 MacCore Monitor` is a native, local-first performance
console for Apple Silicon Macs. It connects live hardware telemetry, controlled
CPU and Metal GPU stress, continuous curves, session history, thermal reports,
macOS network-quality testing, and layered on-demand network diagnostics in one
coherent workspace.

XinMai is designed and maintained by Shixin (`失心` / `ShiXinQvQ`) as an
official SHIXIN LAB project. SHIXIN LAB is Shixin's independent technology lab
and product identity for software, hardware, creator tools, and digital
experiments.

- Product page: [https://shixinqvq.com/lab/maccore/](https://shixinqvq.com/lab/maccore/)
- SHIXIN LAB: [https://shixinqvq.com/](https://shixinqvq.com/)
- Current release: `v0.3.0 Beta` (build `300`)
- Helper: `0.3.0-helper`
- Minimum system: macOS `15.0+`
- Architecture: Apple Silicon / `arm64`
- Source license: GNU GPL v3 or later (`GPL-3.0-or-later`)

[中文说明见下方](#简体中文)

### Download

`v0.3.0 Beta` is the current published release. Download the DMG and its
matching checksum from the same GitHub Release:

- [Download the v0.3.0 Beta DMG](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/download/v0.3.0-beta/SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg)
- [Download the matching SHA-256 file](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/download/v0.3.0-beta/SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg.sha256)
- [Release notes and source archive](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/tag/v0.3.0-beta)
- [Official product page](https://shixinqvq.com/lab/maccore/)

Verify the DMG before opening it:

```bash
shasum -a 256 -c SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg.sha256
```

Continue only when the result reports `OK`.

### Install

1. Open the DMG.
2. Drag `SHIXIN LAB · 「芯脉」.app` onto the `Applications` shortcut.
3. Launch XinMai from Applications.
4. Open **Settings & About > Advanced Permissions** and install the local Helper for
   complete hardware telemetry.

The DMG includes a bilingual installation guide, copyright and open-source
license notice, third-party notices, and a release manifest. Replacing the app
does not automatically remove existing local history.

### One Console, One Complete Performance Story

XinMai follows the whole performance event instead of reducing a Mac to one
peak number. Live state flows into controlled load, continuous curves, local
history, reports, and network evidence, so you can see how the machine ramps
up, sustains work, throttles, recovers, and reconnects.

#### Live telemetry

- Power, CPU/GPU/SoC temperature, frequency, load, fan speed, thermal state,
  storage context, and sampling health.
- Approximately 0.5-second source sampling with high-frequency metric updates
  and six curve groups presented at an efficient visual cadence.
- Layered read-only data paths using macOS `powermetrics`, AppleSMC / HID, and
  `smartctl` or `diskutil` when available.
- Explicit freshness and sequence checks so a running process is not mistaken
  for healthy telemetry.

#### Controlled stress

- CPU, Metal GPU, and combined CPU + GPU modes.
- Manual stop, duration stop, process-exit cleanup, and thermal protection.
- Serious thermal-state grace handling and immediate protection at critical
  thermal state.
- Real-time readings remain visible throughout the run.

#### History and reports

- Session summaries, stop reasons, complete CSV samples, and lightweight
  full-duration curves.
- Performance thermal reports covering sustained and peak power, estimated
  energy, temperatures, fans, thermal state, valid-sample rate, and stability
  trends.
- A/B history comparison and 3200 × 2000 share images.
- Time-aware curve compression, relative CSV references, rolling backup,
  corruption recovery, and legacy-history compatibility.
- Visible curve gaps when samples are missing instead of invented continuity.

#### Network intelligence

- macOS `/usr/bin/networkQuality` results for download, upload, latency,
  responsiveness, and related measurements.
- Layered DNS / TCP / TLS / HTTP diagnostics against fixed lightweight targets.
- On-demand IPv4/IPv6 egress, region/ASN, proxy/VPN/hosting, and IP-reputation
  signals.
- Cancellation, timeout, partial-failure, insufficient-data, and local-history
  states are represented explicitly.

### Local Data and Privacy

Stress sessions, CSV files, reports, speed-test history, network-diagnostic
history, and logs remain under the local user account by default:

```text
~/Library/Application Support/SHIXIN LAB Mac Stress & Power Monitor/
```

This directory retains an early internal name to preserve compatibility with
existing user history. Replacing or removing the app or Helper does not
automatically delete it.

XinMai does not upload hardware history or personal content in the background.
Network traffic occurs only when the user starts the relevant feature:

- `networkQuality` creates real download and upload traffic.
- International diagnostics connect to fixed test targets.
- IP analysis queries ipify, ipwho.is, and proxycheck.io for public-egress and
  reputation signals.

Sensitive network fields are masked in the interface and are not written to
ordinary history. Review and redact diagnostic files before posting them to a
public issue.

### Helper and Security Boundary

Complete `powermetrics` telemetry requires privileged local access. XinMai
uses a narrowly scoped LaunchDaemon Helper so the main app does not run as root
and never stores an administrator password.

The Helper:

- accepts only fixed local `ping` and `sample` requests;
- does not accept arbitrary shell commands, arguments, or paths;
- does not access the network;
- does not write user data or perform disk repair, erase, format, mount, or
  unmount operations;
- stops continuous sampling after requests become idle.

Installed components:

```text
/Library/PrivilegedHelperTools/com.shixinqvq.shixinlab.macstresspower.helper
/Library/LaunchDaemons/com.shixinqvq.shixinlab.macstresspower.helper.plist
/var/run/com.shixinqvq.shixinlab.macstresspower.helper.sock
```

### Measurement and Safety

- macOS telemetry and sensor values are system estimates or best-effort
  observations. They are useful for trends and comparison on the same Mac, not
  a replacement for external laboratory instruments.
- Sensor availability varies across Mac models, chip generations, permissions,
  and macOS releases.
- Stress tests create real heat, power use, fan noise, and battery drain. Save
  important work, keep the Mac ventilated, and begin with a short duration.
- Manual stop and thermal protection reduce risk but cannot remove every risk
  caused by misuse, hardware variation, or the surrounding environment.

### Build From Source

Requirements: Apple Silicon Mac, macOS 15+, and a Swift 6 toolchain.

```bash
swift build -c release --product ShixinStressPower
swift build -c release --product ShixinStressPowerHelper
swift run -c release ShixinStressPowerSelfTest --core-only
Scripts/build-app.sh
```

`Scripts/build-app.sh` creates the app under:

```text
~/Applications/SHIXIN LAB · 「芯脉」.app
```

The build only bundles `smartctl` when an explicit executable source is
provided. A distributable build that includes `smartctl` must also include
the matching smartmontools source archive and notices.

### Project Structure

```text
Sources/ShixinStressPower/              SwiftUI app and controllers
Sources/ShixinStressPowerCore/          Telemetry, stress, history, reports
Sources/ShixinNetworkDiagnosticsCore/   Network parsing, scoring, and history
Sources/ShixinStressPowerHelper/        Privileged local telemetry Helper
Sources/ShixinStressPowerSelfTest/      Reproducible non-stress self-tests
Packaging/                              Metadata, final v3 icon, release docs
Scripts/                                Build, audit, documentation, packaging
Testing/                                Hardware and release validation matrices
```

### Contributing, Security, and Support

- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)
- [Issue tracker](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/issues)

Never publish administrator credentials, unredacted diagnostic archives,
complete local paths, device identifiers, or IP/MAC/BSSID/SSID values in a
public issue.

### License, Copyright, and Brand

Copyright © 2026 SHIXIN LAB / Shixin.

SHIXIN LAB-owned program source code is free software licensed under the
[GNU General Public License, version 3 or any later version](LICENSE)
(`GPL-3.0-or-later`). Copyright ownership remains with SHIXIN LAB / Shixin.
Redistributed modified versions must comply with the GPL, preserve applicable
notices, provide corresponding source, and clearly identify modifications.

The GPL does **not** grant permission to use SHIXIN LAB or XinMai product names,
the final v3 icon, logos, screenshots, marketing artwork, or other protected
brand assets to imply an official release, sponsorship, or endorsement. See
[NOTICE.md](NOTICE.md) for the exact mixed-license scope and redistribution
rules.

Third-party components remain under their own licenses. In particular,
smartmontools / smartctl is licensed under `GPL-2.0-or-later`; see
[Packaging/THIRD-PARTY-NOTICES.txt](Packaging/THIRD-PARTY-NOTICES.txt).

---

<a id="简体中文"></a>

## 简体中文

`SHIXIN LAB · 「芯脉」 MacCore Monitor` 是一款面向 Apple Silicon Mac 的
原生、本地优先硬件性能控制台。它把实时硬件遥测、受控 CPU 与 Metal GPU
压力、连续曲线、Session 历史、性能热力报告、macOS 系统网速测试与分层网络
诊断连接成一套完整工作流。

「芯脉」由失心（`失心` / `ShiXinQvQ`）设计、开发与持续维护，是 SHIXIN LAB
旗下正式项目。SHIXIN LAB 是失心个人 IP 下的独立技术实验室与产品标识，面向
软件、硬件、创作者工具和数字实验。

- 产品官网：[https://shixinqvq.com/lab/maccore/](https://shixinqvq.com/lab/maccore/)
- SHIXIN LAB 官网：[https://shixinqvq.com/](https://shixinqvq.com/)
- 当前发布版本：`v0.3.0 Beta`（build `300`）
- Helper：`0.3.0-helper`
- 最低系统：macOS `15.0+`
- 架构：Apple Silicon / `arm64`
- 源码许可：GNU GPL 第 3 版或任何后续版本（`GPL-3.0-or-later`）

### 下载

`v0.3.0 Beta` 是当前正式发布版本。请从同一个 GitHub Release 下载 DMG 与配套
校验文件：

- [下载 v0.3.0 Beta DMG](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/download/v0.3.0-beta/SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg)
- [下载配套 SHA-256 文件](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/download/v0.3.0-beta/SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg.sha256)
- [版本说明与源码归档](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/releases/tag/v0.3.0-beta)
- [正式产品官网](https://shixinqvq.com/lab/maccore/)

首次打开前验证 DMG：

```bash
shasum -a 256 -c SHIXIN-LAB-XinMai-MacCore-Monitor-0.3.0-Beta.dmg.sha256
```

只有结果显示 `OK` 时才继续安装。

### 安装

1. 打开 DMG。
2. 将 `SHIXIN LAB · 「芯脉」.app` 拖到 `Applications` 快捷方式。
3. 从“应用程序”文件夹启动「芯脉」。
4. 进入 **设置关于 > 高级权限**，安装本地 Helper 以获得完整硬件遥测。

DMG 内附正式中英双语安装说明、版权与开源许可说明、第三方声明和发行清单。
替换 App 不会自动删除现有本机历史。

### 一座控制台，读懂整段性能过程

「芯脉」不把 Mac 简化成一个峰值数字。实时状态进入受控负载，负载进入连续曲线，
曲线沉淀为本机历史、报告与网络证据，让性能如何拉升、维持、降频、恢复与重新
连通都清晰可查。

#### 实时硬件遥测

- 功耗、CPU/GPU/SoC 温度、频率、负载、风扇、热状态、存储背景与采样健康。
- 约 0.5 秒级原始采样，数值卡高频更新，六组曲线按高效节奏连续呈现。
- 通过 macOS `powermetrics`、AppleSMC / HID，以及可用时的 `smartctl` 或
  `diskutil` 构成分层只读数据路径。
- 同时检查样本新鲜度与序列推进，避免把“进程仍在”误判成“遥测健康”。

#### 受控压力

- CPU、Metal GPU、CPU + GPU 三种模式。
- 手动停止、到时停止、退出清理与热状态保护。
- Serious 热状态使用持续宽限逻辑，Critical 热状态立即保护停止。
- 压力运行期间持续显示实时硬件状态。

#### 历史与报告

- Session 摘要、停止原因、完整 CSV 与覆盖全时段的轻量曲线。
- 性能热力报告覆盖持续/峰值功耗、估算能耗、温度、风扇、热状态、有效采样率与
  趋势型稳定性。
- 历史 A/B 对比与 3200 × 2000 高清分享图。
- 时间感知曲线压缩、相对 CSV 引用、滚动备份、损坏恢复与旧历史兼容。
- 样本明显缺失时主动断开曲线，不用连线伪造连续趋势。

#### 网络现场

- 使用 macOS `/usr/bin/networkQuality` 展示下载、上传、延迟、响应能力等数据。
- 对固定轻量目标执行 DNS / TCP / TLS / HTTP 分层诊断。
- 用户主动触发后查询 IPv4/IPv6 出口、地区/ASN、代理/VPN/Hosting 与 IP 信誉
  信号。
- 明确表达取消、超时、部分失败、数据不足和本机历史，不把单一服务失败伪装成
  完整结论。

### 本地数据与隐私

压力 Session、完整 CSV、报告、测速历史、网络诊断历史与日志默认保存在当前
用户的本机目录：

```text
~/Library/Application Support/SHIXIN LAB Mac Stress & Power Monitor/
```

该目录沿用早期内部名称，以保持现有用户历史兼容。替换或移除 App/Helper 都不会
自动删除此目录。

「芯脉」不会在后台上传硬件历史或个人内容。只有用户主动开始对应功能时才会发生
联网：

- `networkQuality` 会产生真实下载与上传流量。
- 国际网络诊断会连接固定测试目标。
- IP 分析会向 ipify、ipwho.is 与 proxycheck.io 查询公网出口与信誉信号。

敏感网络字段在界面中默认遮罩，也不会写入普通历史。向公开 Issue 提交诊断文件
前，请先检查并脱敏。

### Helper 与安全边界

完整 `powermetrics` 遥测需要本机高级权限。「芯脉」使用边界严格的
LaunchDaemon Helper，使主 App 不必以 root 运行，也不会保存管理员密码。

Helper：

- 只接受固定的本机 `ping` 与 `sample` 请求；
- 不接受任意 shell、命令参数或路径；
- 不访问网络；
- 不写入用户数据，也不执行磁盘修复、擦除、格式化、挂载或卸载操作；
- 无采样请求后停止持续采样并待机。

安装位置：

```text
/Library/PrivilegedHelperTools/com.shixinqvq.shixinlab.macstresspower.helper
/Library/LaunchDaemons/com.shixinqvq.shixinlab.macstresspower.helper.plist
/var/run/com.shixinqvq.shixinlab.macstresspower.helper.sock
```

### 测量与安全说明

- macOS 遥测与传感器读数属于系统估算或 best-effort 观察，适合同一台 Mac 上的
  趋势和对比，不替代外部实验室仪器。
- 传感器可用性会随 Mac 型号、芯片代际、权限和 macOS 版本变化。
- 压力测试会真实增加功耗、温度、风扇噪声与电池消耗。请保存重要工作、保持
  通风，并从较短时长开始。
- 手动停止与热状态保护可以降低风险，但无法消除不当使用、设备差异或外部环境
  造成的全部风险。

### 从源码构建

要求：Apple Silicon Mac、macOS 15+、Swift 6 工具链。

```bash
swift build -c release --product ShixinStressPower
swift build -c release --product ShixinStressPowerHelper
swift run -c release ShixinStressPowerSelfTest --core-only
Scripts/build-app.sh
```

`Scripts/build-app.sh` 默认把 App 生成到：

```text
~/Applications/SHIXIN LAB · 「芯脉」.app
```

构建流程只会在明确指定可执行文件来源时附带 `smartctl`。若发行包包含
`smartctl`，还必须同时提供对应 smartmontools 源码归档和许可证材料。

### 项目结构

```text
Sources/ShixinStressPower/              SwiftUI App 与控制器
Sources/ShixinStressPowerCore/          遥测、压力、历史与报告核心
Sources/ShixinNetworkDiagnosticsCore/   网络解析、评分与历史
Sources/ShixinStressPowerHelper/        特权本机遥测 Helper
Sources/ShixinStressPowerSelfTest/      可复现的非压力自检
Packaging/                              元数据、最终 v3 图标与发行文档
Scripts/                                构建、审计、文档与打包脚本
Testing/                                硬件与发布验收矩阵
```

### 贡献、安全与支持

- [参与贡献](CONTRIBUTING.md)
- [安全策略](SECURITY.md)
- [更新记录](CHANGELOG.md)
- [问题反馈](https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/issues)

请勿在公开 Issue 中发布管理员凭据、未经脱敏的诊断包、完整本机路径、设备标识，
或 IP/MAC/BSSID/SSID 等隐私字段。

### 许可、版权与品牌

Copyright © 2026 SHIXIN LAB / Shixin。

SHIXIN LAB 自有程序源码是自由软件，按照
[GNU General Public License 第 3 版或任何后续版本](LICENSE)
（`GPL-3.0-or-later`）开源。源码著作权仍归 SHIXIN LAB / Shixin 所有；对外
再分发修改版本时，必须遵守 GPL、保留适用声明、提供对应源码并明确标记修改。

GPL **不代表**授权他人使用 SHIXIN LAB 或「芯脉」产品名称、最终 v3 图标、Logo、
截图、宣传视觉或其他受保护品牌资产去冒充官方版本、合作关系或官方背书。具体
混合许可范围与再分发要求见 [NOTICE.md](NOTICE.md)。

第三方组件继续适用各自许可证。特别是 smartmontools / smartctl 采用
`GPL-2.0-or-later`，详见
[Packaging/THIRD-PARTY-NOTICES.txt](Packaging/THIRD-PARTY-NOTICES.txt)。
