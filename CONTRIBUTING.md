# Contributing / 参与贡献

Thank you for reviewing SHIXIN LAB · 「芯脉」 MacCore Monitor. Before proposing
a change, read `README.md`, `SECURITY.md`, `LICENSE`, `NOTICE.md`, and the
relevant test matrix under `Testing/`.

感谢你审查 SHIXIN LAB · 「芯脉」 MacCore Monitor。提交修改前，请先阅读
`README.md`、`SECURITY.md`、`LICENSE`、`NOTICE.md` 与 `Testing/`
中相关测试矩阵。

## Contribution License / 贡献许可

Unless separately agreed in writing before acceptance, submitted code
contributions are provided under `GPL-3.0-or-later` for inclusion in the
program. Contributions do not grant permission to reuse SHIXIN LAB names, the
final v3 icon, screenshots, promotional artwork, or other protected brand
assets outside the scope of `NOTICE.md`.

除非在贡献被接受前另有书面约定，提交并被接受的代码贡献将按
`GPL-3.0-or-later` 纳入程序。提交贡献并不获得超出 `NOTICE.md` 范围复用
SHIXIN LAB 名称、最终 v3 图标、截图、宣传视觉或其他受保护品牌资产的许可。

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
bash -n Scripts/audit-public-source.sh Scripts/build-app.sh Scripts/release-public-beta.sh
python3 -m py_compile Scripts/generate-public-beta-pdfs.py Scripts/verify-public-beta-pdfs.py
git diff --check
```

Before official packaging, generate and review the bilingual PDFs with the
pinned documentation dependency, then verify their source manifest:

```bash
python3 -m pip install --requirement Scripts/requirements-public-beta-docs.txt
python3 Scripts/generate-public-beta-pdfs.py
python3 Scripts/verify-public-beta-pdfs.py
```

The generated PDFs and manifest remain local release artifacts. The official
release script requires a clean Git working tree and refuses PDFs that no longer
match their Markdown, generator, icon, release metadata, or legal inputs. An
imported app must have been produced from the same clean commit by
`Scripts/build-app.sh`; its embedded provenance and executable hashes are
recorded in the release manifest.

正式打包前，请使用锁定版本的文档依赖生成并人工检查双语 PDF，再运行上述
PDF 源文件清单校验。生成的 PDF 与清单属于本地发行产物，不提交到源码仓库。
正式发布脚本要求 Git 工作区干净；PDF 与 Markdown、生成脚本、图标、版本元数据
或法律材料不一致时会拒绝打包。导入的 App 必须由同一干净提交下的
`Scripts/build-app.sh` 生成，其内置构建来源与二进制摘要会写入发行清单。

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
