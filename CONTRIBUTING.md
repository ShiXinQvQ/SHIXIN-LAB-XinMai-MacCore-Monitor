# Contributing / 参与贡献

Thank you for reviewing SHIXIN LAB · 「芯脉」 MacCore Monitor. Before proposing
a change, read `README.md`, `SECURITY.md`, `LICENSE`, and the relevant test
matrix under `Testing/`.

感谢你审查 SHIXIN LAB ·「芯脉」MacCore Monitor。提交修改前，请先阅读
`README.md`、`SECURITY.md`、`LICENSE` 与 `Testing/` 中相关测试矩阵。

## Non-Negotiable Invariants / 不可突破的边界

- Preserve the published bundle identifier, Helper label, historical data
  directory, schema compatibility, and final v3 icon unless a separately
  reviewed migration plan explicitly changes them.
- The privileged Helper must keep a narrow local protocol and must not accept
  arbitrary shell commands, arguments, paths, or network requests.
- SMART / NVMe access must remain read-only. Do not add raw-device writes,
  formatting, repair, erase, mount/unmount, cleanup, or destructive fallback
  behavior.
- Stress modes must retain manual stop, duration stop, thermal protection,
  cancellation, and process-exit cleanup.
- Network access must remain user initiated, accurately disclosed, cancellable,
  and free of embedded private API keys.
- Do not upload device data or expose serial numbers, UUIDs, UDIDs, IP/MAC/
  BSSID/SSID values, complete local paths, or unredacted diagnostics by default.

- 除非另有独立审查的迁移方案，不得改变已发布的 Bundle ID、Helper label、历史
  数据目录、schema 兼容性与最终 v3 图标。
- 特权 Helper 必须保持固定、狭窄的本机协议，不得接受任意 shell、参数、路径或
  网络请求。
- SMART / NVMe 访问必须保持只读，不得加入原始设备写入、格式化、修复、擦除、
  挂载/卸载、清理或破坏性降级。
- 压力模式必须保留手动停止、到时停止、热保护、取消与进程退出清理。
- 联网必须由用户主动触发、准确说明、可以取消，并且不得在客户端嵌入私密 Key。
- 默认不得上传设备数据，也不得暴露序列号、UUID、UDID、IP/MAC/BSSID/SSID、
  完整本机路径或未经脱敏的诊断内容。

## Validation / 验证

At minimum, run:

```bash
swift build -c release --product ShixinStressPower
swift build -c release --product ShixinStressPowerHelper
swift run -c release ShixinStressPowerSelfTest --core-only
plutil -lint Packaging/Info.plist \
  Sources/ShixinStressPower/Resources/en.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/ja.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/zh-Hans.lproj/Localizable.strings
bash -n Scripts/build-app.sh Scripts/release-public-beta.sh
git diff --check
```

UI, real telemetry, Helper lifecycle, network behavior, packaging, and macOS
compatibility changes require focused validation beyond a successful compile.
Do not run full stress workloads or make network requests without explicit user
intent.

界面、真实采样、Helper 生命周期、联网、打包与系统兼容性改动必须补充针对性
验证；仅编译通过不等于发行完成。未经用户明确意图，不得自行执行完整压力负载
或产生网络请求。

## Pull Requests / Pull Request

Keep each change focused. Describe the user-visible result, failure mode,
preserved invariants, tests performed, and remaining hardware or macOS limits.
Never commit DMGs, local archives, user history, screenshots containing private
data, credentials, generated diagnostics, or machine-specific absolute paths.

每次修改应保持范围清晰，并说明用户可见结果、修复的失效模式、保持的不变量、
已执行验证和仍存在的硬件/macOS 边界。不得提交 DMG、本地归档、用户历史、含
隐私信息的截图、凭据、诊断产物或机器专属绝对路径。
