# macOS 27 appearance and updater acceptance

This document records acceptance evidence and remaining coverage limits for 0.3.1-beta / 301. Earlier dated observations below are historical, not current failures.

## Reproducible local checks

```sh
swift test -c release
swift run -c release ShixinStressPowerSelfTest --core-only
Scripts/audit-public-source.sh
python3 Scripts/verify-public-beta-pdfs.py
```

Build into a dedicated review directory with `SHIXIN_APP_INSTALL_DIR` and
`SHIXIN_SWIFT_SCRATCH_PATH`. Do not run the default installation script over a
daily app during acceptance. `Scripts/verify-updater-bundle.py <app>` checks the
embedded framework, signature, license and privacy policy without network access.
Add `--require-key` for a release: an unconfigured development bundle must fail.

The `SHIXIN_UPDATE_TESTING` compiler flag is exclusively for local fixtures. It
allows a loopback HTTP feed, requires a distinct `.review.updater` bundle ID and
an isolated `CFFIXED_USER_HOME`, and records relaunch build/path inside that home.
Never publish that build, its key, home, receipts or fixture appcast. Shipping
bundle validation rejects the review home and environment configuration.

## Evidence captured on macOS 27

- Actual XinMai application, ad-hoc signed, bundled Sparkle 2.10.0: signed local
  DMG downloads and automatic install/relaunch from build 900302 to 900303,
  then 900303 to 900305 and 900305 to 900307 with the final service fixes. Target build, path and
  isolated home confirmed by launch receipts. These numbers are test-only.
- Same build: no reinstall. Lower build: no downgrade and an explicit settings
  message. Minimum-system 99 fixture: rejected. Tampered signed feed, tampered
  archive and HTTP 404: errors, original app preserved, check action restored.
- Update offer blocks the stress shortcut before any stress work starts and
  blocks diagnostic export before a save panel opens. Unit tests cover multiple
  activity leases, duplicate cleanup and cancellation cleanup before unlocking.
- A minimized update offer can be restored through Check for Updates. Closing
  the offer releases the gate and reports cancellation. About uses running bundle
  metadata rather than source constants.
- Cancelling an active, throttled loopback download stops the transfer, reports
  cancellation and restores Check for Updates. Retrying with the normal signed
  feed completes installation and relaunch successfully.
- Build 900307 includes the newly built Helper payload. Its mismatch is detected
  after relaunch, the update explanation is shown, and Later continues read-only
  sampling. The system Helper was not replaced; authorization rejection remains
  untested.
- Chinese monitoring and English settings/update content were visually inspected
  at the QA-requested minimum content size (980 x 680). The actual window can be
  taller due to system chrome/layout minimums. Normal-size navigation across all
  eight pages was checked. Language restart correctly selected English.
- Copied history, CSV, network history and log files remained byte-identical
  across the isolated upgrades. Daily app, actual data, root Helper, daemon and
  final v3 source assets remained byte-identical to the baseline.
- Normal and `SHIXIN_LEGACY_SDK` builds compile. This is not a macOS 15/26 runtime
  claim. The appearance profile is selected only when OS major version equals 27.

## Release checks still required

- Real macOS 26 and oldest supported-system execution; the full macOS 27 minimum-window
  page matrix, accessibility settings, Japanese visual verification, mouse/keyboard interactions
  and user visual acceptance. A forced theme on 27 does not count as 26 testing.
- Controlled, repeated monitor/scroll/GPU performance measurements. Short idle
  measurements cannot substantiate a general performance improvement.
- Normal installed, system Applications, two-copy, read-only DMG, unwritable and
  translocated launch paths in a disposable account/VM. Do not trigger privilege
  changes or overwrite the daily installation to fabricate this evidence.
- Offline/interrupted download, stable-versus-beta
  channel transitions, archive architecture mismatch, and exact final package.
- Actual changed-Helper installation and rejected-authorization behavior. The
  mismatch prompt was verified, but no system daemon was installed or replaced.
- Production public key custody/backup, approved clean source commit, matching
  final app/DMG/website/GitHub/feed, and a real published-source upgrade rehearsal.

## Public release procedure

1. Reserve a globally increasing build above 300. Version 0.3.0 cannot update
   itself; explain the one-time manual installation clearly.
2. Generate the product key using the pinned official Sparkle tools. Keep the
   private key in the maintainer's Keychain with a protected backup. Export only
   its public key into a local public-key file and supply
   `SHIXIN_UPDATE_PUBLIC_KEY_FILE` to the build. Do not reuse fixture keys or
   silently add credentials to Actions.
3. Freeze an accepted clean source commit; regenerate the bilingual PDFs with
   the pinned ReportLab environment and verify their source manifest. Preserve
   GPL correspondence and smartctl source/license requirements.
4. Build exactly one final DMG with `Scripts/release-public-beta.sh`; its updater
   gate requires real configuration and enforces the Pages 25 MiB limit. Verify
   public-key fingerprint, source commit, executable hashes and toolchain.
5. Use Sparkle 2.10.0 `generate_appcast` and `sign_update --verify` with the same
   product Keychain account. Use the final unique static DMG URL, arm64,
   minimum macOS 15 and beta channel; use full packages initially, without deltas.
6. Publish byte-identical archive/checksum to the website and GitHub, then publish
   the signed appcast last. Never edit or inject into signed XML/HTML afterward.
   Verify downloaded bytes and an actual predecessor-to-successor upgrade.

Production publication requires the real product key, a clean source commit, the verified final artifact, and explicit release authorization.

## Appearance correction after user review

The first blue-gray surface and the minimum-window preview were rejected by the
user. The minimum-window launch override has been removed: WindowSizeController
now matches the original 1180 x 1000 implementation exactly, including QA builds.
On macOS 27, headers, metrics and charts now share one neutral #292B2E surface,
after the user found the Settings-derived color too dark for ordinary cards. The
separate elevated surface role was removed. Settings card and non-27 material
branches remain unchanged.

A native hidden-window regression test lays out the real SidebarView and verifies
all eight rows have a 32 pt pitch, matching the supplied 2x macOS 26 screenshot.
Build and geometry verification pass. Final desktop visual acceptance is still
required; a sandbox symlink-root startup failure prevented the native UI tool from
opening the corrected preview in this correction turn. Do not call this accepted
solely from a passing build or geometry test.

## Chart chronology correction

TelemetryChartRows now stably orders the selected samples by capturedAt before
creating line segments. Six offline regressions reproduce backward connections
and misplaced missing spans in the previous logic, then pass after this local
change; the complete suite is 10/10. Raw samples and real missing-value gaps are
retained. This does not repair the separately observed installed Helper failure
(Bad file descriptor and stale sequence), nor claim live desktop acceptance.

## 2026-09-23 full UI regression correction

Historical review found that incorrect SDK 15
link metadata (despite SDK 27 compilation) caused legacy native controls across
screens; the build wrapper now supplies the real SDK and bundle verification
rejects the old artifact. Sidebar spacing/icons, macOS 27 chart layout and
vectorized rendering were checked in native windows; 12 tests pass.

CPU counter fallback no longer mixes residency with kernel utilisation. Expired
Helper samples use the existing local sensor path, with unavailable power and
frequency left unavailable. The installed Helper later reproduced a persistent
`Bad file descriptor` during idle recovery. It was not modified; full live power
and frequency acceptance is therefore NOT complete. Earlier successful sampling
and an improved short performance sample must not be presented as final full
functional or macOS 26 runtime acceptance.

## 2026-09-25 follow-up

After the owner updated the Helper, the previous persistent Helper failure no
longer reproduced. The SDK 26.5 main executable and SDK 27 Helper combination
passed a 322-second macOS 27 sampling check: after four initial startup fallback
rows, 543 power samples were valid, with no reversed timestamps and a maximum
one-second gap. Eighteen regression tests and the non-stress core self-test
passed locally. This is not macOS 26 GUI or stress-test acceptance.

Official builds use the bundled public key in `Packaging/Sparkle-public-key.txt`.
`SHIXIN_BUILD_SDK_PATH` selects the main SDK; `SHIXIN_HELPER_BUILD_SDK_PATH` and
`SHIXIN_HELPER_SWIFT_SCRATCH_PATH` allow independently preserving the verified
Helper build. Only public key material may enter an App or source commit.
