# Changelog / 更新记录

This project follows release-oriented notes rather than promising strict
semantic-versioning compatibility during Beta.

Beta 阶段按发行版本记录变化，不承诺严格的语义化版本兼容。

## 0.3.4-beta (Build 304) — Unreleased / 未发布

- Helper security: the privileged Helper no longer reads the disk temperature and never launches `smartctl`. Earlier Helpers could run a `smartctl` found in a user-writable Homebrew folder with root privileges. The app now reads the disk temperature itself, without elevated privileges, and refreshes it in the background so sampling never waits on a slow disk query.
- Helper stability: the powermetrics stream now owns its pipe and child process directly, so each descriptor is opened, closed and reaped exactly once. Power-source state is read through IOKit instead of `pmset`, leaving powermetrics as the Helper's only child process. If descriptor errors still occur three times in a row, the Helper exits and launchd starts a fresh instance; each failure is logged to the Helper error log.
- Battery state: a discharging battery is no longer reported as charging.
- Development builds from `Scripts/build-app.sh` go to `Dist/Development/` by default instead of replacing the installed app.
- Users of 0.3.3 and earlier keep working with an older Helper; the app reads the disk temperature locally and asks for a one-time Helper update.
- The bundled installation guide now leads with System Settings → Privacy & Security → Open Anyway; Control-click no longer bypasses Gatekeeper on macOS 15 and later.

- Helper 安全：特权 Helper 不再读取硬盘温度，也不再启动 `smartctl`。此前的 Helper 可能以 root 身份运行位于用户可写的 Homebrew 目录中的 `smartctl`。现在由 App 以普通权限读取硬盘温度，并在后台刷新，采样不会因磁盘查询变慢而等待。
- Helper 稳定性：powermetrics 采样流改为直接管理自己的管道与子进程，每个描述符只打开、关闭、回收一次。电源状态改用 IOKit 读取，不再启动 `pmset`，Helper 只剩 powermetrics 一个子进程。若仍连续三次出现描述符错误，Helper 会退出并由 launchd 重新启动，每次失败都会写入 Helper 错误日志。
- 电池状态：放电中不再被误报为“充电中”。
- `Scripts/build-app.sh` 的开发构建默认输出到 `Dist/Development/`，不再覆盖已安装的 App。
- 0.3.3 及更早版本的用户在旧 Helper 下仍可正常使用；App 会在本地读取硬盘温度，并提示更新一次 Helper。
- 随包安装说明改为首选“系统设置 → 隐私与安全性 → 仍要打开”；macOS 15 起，按住 Control 点按“打开”已不能绕过安全提示。

## 0.3.3-beta (Build 303) — 2026-09-29

- Show whole-machine system load in monitoring, overview, curves, peak/average and energy; retain CPU/GPU as separate compute estimates.
- Prefer the read-only SMC PSTR sensor for timely readings. Hardware without PSTR uses a clearly labelled slower system-load reading; unavailable is never replaced by charger input or CPU/GPU sums.
- Preserve the computing-only meaning of older history and exports; do not calculate misleading comparisons between old and new power scopes.
- Keep the existing window, macOS appearance branches, v3 icon, Helper and manual Sparkle update behavior.
- Acceptance: bounded single-worker CPU and short GPU/combined bursts, stop/recovery checks, live power cadence and regression tests. This is not long-duration full-load certification or every-Mac visual acceptance.
- Known limitation: previously observed intermittent Helper idle/recovery `Bad file descriptor` has not been proven permanently resolved; whole-machine power remains independent of Helper.

## 0.3.1-beta (Build 301) — 2026-09-25

- macOS 27 only: stable dark card surfaces and readable secondary text; original appearance branches remain on other macOS releases.
- Manual-default Sparkle 2.10.0 updates in Settings & About and the app menu, with optional scheduled checks and signed-feed/archive verification.
- Updates and test/export/Helper operations cannot start over each other. Existing termination cleanup and separate Helper installation remain in place.
- Bundle embedding, public-key configuration, source/PDF/license checks, and a 25 MiB hosting gate. The production public key is bundled; private signing material remains outside the source repository.
- 修复曲线时间排序与过期采样复用，恢复默认窗口与侧栏布局；仅在27启用外观修正，保留其他系统原分支。
- 0.3.0 用户需手动安装一次，此后可在设置中检查更新。旧系统视觉验收仍受限于缺少真机。

## 0.3.0-beta (Build 300) — 2026-08-18

### Added / 新增

- Native macOS performance console for Apple Silicon with CPU, Metal GPU, and
  combined stress modes.
- Live power, temperature, frequency, load, fan, thermal-state, and sampling-
  health views with six groups of continuous charts.
- Session history, complete CSV export, performance thermal reports, A/B
  comparison, and high-resolution share images.
- macOS networkQuality speed testing, layered international diagnostics, and
  on-demand IP analysis with explicit network boundaries.
- Bilingual installation, GPL open-source, copyright, and brand-asset documents
  for the published DMG.

### Reliability / 可靠性

- Persistent 500 ms Helper sampling with freshness metadata, cancellation,
  resource limits, and idle shutdown.
- History schema 3 with time-aware curve compression, relative CSV references,
  rolling backups, recovery, and legacy decoding.
- Monotonic stress-test timing, mode-aware validity checks, thermal protection,
  and explicit degraded-data states.
- Reduced hidden CPU use when the stress or history page is idle while
  preserving live-monitor freshness.

### Distribution / 发行

- App `0.3.0-beta` (build `300`), Helper `0.3.0-helper`.
- Apple Silicon (`arm64`), minimum macOS 15.0.
- Release packaging includes the manifest, SHA-256 verification, bilingual
  guides, GPLv3 text, protected-brand notice, and third-party notices.
- SHIXIN LAB-owned program source is released under GPL-3.0-or-later; protected
  names, final v3 icon, screenshots, promotional artwork, and other brand assets
  remain subject to NOTICE.md.

### Publication Maintenance / 公开发布维护

- Aligned the GitHub README hero with the SHIXIN LAB product-family layout and
  switched its fixed 128 × 128 display to a high-resolution 842 × 842 preview
  derived without resampling from the final v3 icon source.
- Standardized the official product URL, visible permission labels, and precise
  Helper filesystem boundary across the README, release documents, and package
  manifest.
- Added per-file GPL-3.0-or-later SPDX notices, public-source wording guards, and
  macOS CI for source audit, metadata validation, release builds, and non-stress
  self-tests.
- Hardened future official packaging so it requires a clean Git source tree and
  records the exact source commit, embedded App provenance, and App/Helper
  executable SHA-256 values.
- Added a pinned, source-hashed bilingual-PDF manifest and corrected the public
  test matrix to distinguish automatic core-only checks from real-device stress
  and macOS 15 compatibility coverage.
