# SHIXIN LAB · 「芯脉」 MacCore Monitor

**让 Mac 看见性能脉动，都留下证据。**

「芯脉」是一款面向 Apple Silicon Mac 的原生性能控制台：把实时硬件遥测、受控
CPU / Metal GPU 压力负载、连续曲线、历史记录、性能热力报告、系统网速测试与
分层网络诊断整合进一个清晰、可解释的 macOS 工作流。

- 当前版本：`0.3.0-beta`（build `300`）
- Helper：`0.3.0-helper`
- 平台：Apple Silicon (`arm64`)
- 最低系统：macOS 15.0
- 官网：https://shixinqvq.com/lab/xinmai/
- 许可：SHIXIN LAB Source-Available Notice（见 [LICENSE](LICENSE)）

> 本仓库公开源码用于审查、透明说明、学习参考与安全检查。它采用 source-
> available 许可，不是 OSI 批准的开源许可证；第三方组件继续适用各自许可证。

![SHIXIN LAB XinMai app icon and interface preview](Packaging/AppIconPreviewInApp.png)

## 下载与安装

正式 Beta 安装包将通过 SHIXIN LAB 官网与本仓库的 GitHub Releases 提供。每个
DMG 都应同时发布独立的 `.sha256` 文件；请确认文件名、版本与时间戳属于同一次
发行。

安装步骤：

1. 打开 DMG。
2. 将 `SHIXIN LAB · 「芯脉」.app` 拖到 `Applications` 快捷方式。
3. 从“应用程序”文件夹打开 App。
4. 在“设置关于 > 高级权限”安装本地 Helper，以获得完整硬件遥测。

DMG 内附正式中英双语安装说明、版权与源码许可说明、第三方许可证和 Release
Manifest。替换 App 不会自动删除已有历史数据。

## 核心能力

### 原生压力与实时监测

- CPU、Metal GPU、CPU + GPU 三种受控负载模式。
- 手动停止、到时停止、Serious 宽限与 Critical 热状态保护。
- 功耗、温度、频率、负载、风扇、热状态与采样健康。
- 约 0.5 秒原始采样，数值卡保持高频更新；六组曲线按约 1 秒节奏批量呈现，
  减少无意义重绘。
- powermetrics、AppleSMC / HID、smartctl 或 diskutil 的分层只读采样路径。

### 可复盘的历史证据

- 每次 Session 保存摘要、停止原因、轻量全时段曲线与完整采样 CSV。
- 性能热力报告包含峰值/持续功耗、估算能耗、峰值/平均温度、风扇、热状态、
  有效采样率与趋势型稳定性判断。
- 历史 A/B 对比与 3200 × 2000 高清分享图。
- History schema 3：相对 CSV 引用、时间感知曲线压缩、滚动备份、损坏恢复与
  旧格式兼容。
- 明显采样缺口会让曲线主动断开，不用连线伪造连续趋势。

### 网速与网络诊断

- 使用 macOS `/usr/bin/networkQuality` 的下载、上传、延迟、抖动与 RPM 测试。
- 固定轻量 HTTPS 目标的分层国际链路诊断，展示 DNS / TCP / TLS / HTTP 阶段。
- 用户主动同意后查询 IPv4/IPv6 出口、地区/ASN 与 VPN / Proxy / Hosting /
  风险信号。
- 支持取消、超时、部分失败、数据不足与本机历史；不把单一 Provider 失败伪装成
  完整结论。

## 数据、隐私与联网边界

压力测试历史、完整 CSV、测速与诊断历史、日志默认保存在：

```text
~/Library/Application Support/SHIXIN LAB Mac Stress & Power Monitor/
```

该目录沿用早期内部名称，以保持已有用户数据兼容。替换 App 或卸载 App/Helper
不会自动删除此目录。

「芯脉」不会在后台上传硬件历史或个人内容。以下请求只在用户主动开始对应功能
后发生：

- `networkQuality` 标准网速测试会产生真实下载与上传流量。
- 国际诊断会连接固定测试目标。
- IP 分析会使用 ipify、ipwho.is 与 proxycheck.io 查询当前公网出口及相关信号。

公网 IP、本机 IP、MAC、BSSID、SSID 与 DNS 地址不会写入普通历史；敏感网络
字段在界面中默认遮罩。公开提交诊断报告前仍应先检查并脱敏。

更详细的数据源、供应商和评分边界见
[网络诊断数据源说明](docs/network-diagnostics-data-sources.md)。

## Helper 与权限模型

powermetrics 的完整遥测需要特权。App 通过安装在本机的 LaunchDaemon Helper
读取固定的硬件采样，不让主 App 以 root 运行，也不保存管理员密码。

Helper 只接受固定的本机 `ping` 与 `sample` 请求：

- 不接受任意 shell、命令、参数或路径。
- 不联网，不负责网速或 IP 分析。
- 不写入、修复、擦除、格式化、挂载或卸载磁盘。
- 只读采集 powermetrics、AppleSMC / HID、电源与存储温度信息。
- 无采样请求后自动停止持续 powermetrics 流并待机。

安装位置：

```text
/Library/PrivilegedHelperTools/com.shixinqvq.shixinlab.macstresspower.helper
/Library/LaunchDaemons/com.shixinqvq.shixinlab.macstresspower.helper.plist
/var/run/com.shixinqvq.shixinlab.macstresspower.helper.sock
```

## 测量与安全说明

- powermetrics 功耗和频率是 macOS 系统估算值，适合同一台 Mac 上观察趋势、
  峰值与持续平台，不替代外部实验室仪器。
- AppleSMC / HID 传感器可用性随 Mac 型号、芯片代际与 macOS 版本变化。
- 压力测试会真实增加功耗、温度、风扇噪声和电池消耗。测试前请保存工作、
  保持通风，并从较短时长开始。
- App 提供手动停止和热状态保护，但不能消除不当使用、设备差异或外部环境造成
  的全部风险。

## 从源码构建

要求：Apple Silicon Mac、macOS 15+、Swift 6 工具链。

仅构建主 App 与 Helper：

```bash
swift build -c release --product ShixinStressPower
swift build -c release --product ShixinStressPowerHelper
```

运行不产生压力负载的核心自检：

```bash
swift run -c release ShixinStressPowerSelfTest --core-only
```

生成本机 `.app`：

```bash
Scripts/build-app.sh
```

默认输出到：

```text
~/Applications/SHIXIN LAB · 「芯脉」.app
```

构建脚本使用 ad-hoc 签名，并把 Helper 放入 App bundle。只有项目本地存在可执行
的 `Tools/smartctl`，或显式设置 `SHIXIN_SMARTCTL_SOURCE`，才会随 App 附带该
独立 GPL 工具；构建不会静默拾取维护者电脑上的 Homebrew 文件。实际包含情况以
App 内 `smartctl-version.txt` 为准。

若公开发行包需要附带 smartctl，打包时还必须设置
`SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE` 指向该二进制对应版本的完整源码归档；
发行脚本会把归档放入 DMG 的 `Licenses/`，缺少时直接终止打包。

## 测试与发行门禁

基础校验：

```bash
plutil -lint Packaging/Info.plist \
  Sources/ShixinStressPower/Resources/en.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/ja.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/zh-Hans.lproj/Localizable.strings
bash -n Scripts/build-app.sh Scripts/release-public-beta.sh
git diff --check
```

生成双语 PDF：

```bash
python3 Scripts/generate-public-beta-pdfs.py
```

执行公开 Beta 打包门禁：

```bash
Scripts/release-public-beta.sh
```

该流程验证版本、本地化、重复键、核心自检、App/Helper 结构与版本、arm64、
签名、PDF、第三方材料、DMG 只读挂载内容和 SHA-256 回读。真实传感器、Helper
安装/更新、视觉、多机型和不同 macOS 版本仍需按 `Testing/` 中矩阵验收；编译
通过不等于真实硬件覆盖完成。

## 项目结构

```text
Sources/ShixinStressPower/              SwiftUI App 与控制器
Sources/ShixinStressPowerCore/          采样、压力、历史、报告与导出核心
Sources/ShixinNetworkDiagnosticsCore/   网络诊断解析、评分与历史
Sources/ShixinStressPowerHelper/        特权本地采样 Helper
Sources/ShixinStressPowerSelfTest/      可复现自检
Packaging/                              App 元数据、v3 图标、PDF 源文档与许可证
Scripts/                                构建、文档与公开 Beta 打包
Testing/                                测试矩阵与发布边界
```

## 参与、安全与反馈

- 贡献说明：[CONTRIBUTING.md](CONTRIBUTING.md)
- 安全策略：[SECURITY.md](SECURITY.md)
- 更新记录：[CHANGELOG.md](CHANGELOG.md)
- 问题反馈：https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor/issues

请勿在公开 Issue 上传未经脱敏的诊断包、用户历史、完整本机路径、设备标识、
公网/本机 IP、MAC/BSSID/SSID、管理员凭据或其他私人数据。

## 许可与第三方组件

SHIXIN LAB 原创源码和原创资产适用仓库根目录的
[SHIXIN LAB Source-Available Notice](LICENSE)。未经书面许可，不得复制、再
分发、再授权、销售、发布修改版本，或将原创源码/资产用于其他产品。

smartmontools / smartctl 是独立上游组件，采用 GPL-2.0-or-later。完整许可证与
第三方摘要位于：

- [Packaging/smartmontools-COPYING.txt](Packaging/smartmontools-COPYING.txt)
- [Packaging/THIRD-PARTY-NOTICES.txt](Packaging/THIRD-PARTY-NOTICES.txt)

Apple、Mac、macOS、Apple Silicon 与 Metal 是 Apple Inc. 的商标或注册商标。
「芯脉」是独立第三方工具，与 Apple Inc. 不存在隶属、赞助、背书或官方认证关系。

---

## English Summary

SHIXIN LAB · 「芯脉」 MacCore Monitor is a native Apple Silicon performance
console for controlled CPU/Metal GPU stress, live hardware telemetry, continuous
charts, evidence-preserving session history, thermal reports, macOS
networkQuality testing, and layered on-demand network diagnostics.

Version `0.3.0-beta` (build `300`) targets `arm64` Macs running macOS 15 or
later. Historical data stays local by default. Network traffic occurs only when
the user starts a speed test, international diagnostic, or IP analysis. The
privileged Helper is limited to fixed local telemetry requests and does not
perform network access or arbitrary commands.

Release DMGs include bilingual installation and legal documents, a release
manifest, third-party notices, and a matching SHA-256 file published beside the
artifact. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
[LICENSE](LICENSE) before proposing or redistributing changes.
