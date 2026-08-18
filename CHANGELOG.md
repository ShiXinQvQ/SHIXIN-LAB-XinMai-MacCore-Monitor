# Changelog / 更新记录

This project follows release-oriented notes rather than promising strict
semantic-versioning compatibility during Beta.

Beta 阶段按发行版本记录变化，不承诺严格的语义化版本兼容。

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
  switched its fixed 128 × 128 display to the final v3 icon's 1024 × 1024 source.
- Standardized the official product URL, visible permission labels, and precise
  Helper filesystem boundary across the README, release documents, and package
  manifest.
- Added per-file GPL-3.0-or-later SPDX notices, public-source wording guards, and
  macOS CI for source audit, metadata validation, release builds, and non-stress
  self-tests.
