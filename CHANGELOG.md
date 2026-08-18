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
- Bilingual installation and copyright/source-license documents for the public
  Beta DMG.

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
- Public Beta packaging includes release manifest, SHA-256 verification,
  bilingual guides, and third-party notices.
