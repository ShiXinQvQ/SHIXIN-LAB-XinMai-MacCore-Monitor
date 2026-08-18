#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SHIXIN LAB · 「芯脉」"
PRODUCT_NAME="ShixinStressPower"
HELPER_LABEL="com.shixinqvq.shixinlab.macstresspower.helper"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
EXPECTED_HELPER_VERSION="$(sed -n 's/.*helperVersion = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Sources/ShixinStressPowerCore/HelperProtocol.swift" | head -n 1)"
SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)"
SOURCE_CHANGE_COUNT="$(git -C "$ROOT_DIR" status --porcelain | wc -l | tr -d ' ')"
STAMP="$(date +%Y%m%d-%H%M%S)"
APP_VERSION_FILENAME="$(printf '%s' "$APP_VERSION" | sed 's/-beta/-Beta/')"
DIST_DIR="$ROOT_DIR/Dist/Release-${APP_VERSION}-${STAMP}"
DMG_PATH="$DIST_DIR/SHIXIN-LAB-XinMai-MacCore-Monitor-${APP_VERSION_FILENAME}.dmg"
DMG_FILENAME="$(basename "$DMG_PATH")"
INSTALL_PDF="$ROOT_DIR/output/pdf/SHIXIN LAB - XinMai - Installation Guide - zh-Hans & English.pdf"
LEGAL_PDF="$ROOT_DIR/output/pdf/SHIXIN LAB - XinMai - Copyright, Open Source License & Third-Party Notices - zh-Hans & English.pdf"
WORK_ROOT="$(mktemp -d /private/tmp/xinmai-public-beta.XXXXXX)"
APP_OUTPUT="$WORK_ROOT/app"
SCRATCH_PATH="$WORK_ROOT/swift-build"
STAGE_DIR="$WORK_ROOT/stage"
MOUNT_DIR="$WORK_ROOT/mount"
MOUNTED=0

cleanup() {
  if [ "$MOUNTED" -eq 1 ]; then
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  fi
  case "$WORK_ROOT" in
    /private/tmp/xinmai-public-beta.*)
      /bin/rm -rf -- "$WORK_ROOT"
      ;;
  esac
}
trap cleanup EXIT

cd "$ROOT_DIR"

echo "[1/9] Validate source hygiene, metadata, localizations, and release documents"
test -s README.md
test -s LICENSE
test -s SECURITY.md
test -s CONTRIBUTING.md
test -s CHANGELOG.md
if [ -x Scripts/audit-public-source.sh ]; then
  Scripts/audit-public-source.sh
fi
git diff --check
plutil -lint \
  Packaging/Info.plist \
  Packaging/com.shixinqvq.shixinlab.macstresspower.helper.plist \
  Sources/ShixinStressPower/Resources/zh-Hans.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/en.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/ja.lproj/Localizable.strings
test -s "$INSTALL_PDF"
test -s "$LEGAL_PDF"

ruby -e '
  ARGV.each do |path|
    values = Hash.new { |hash, key| hash[key] = [] }
    File.foreach(path) do |line|
      match = line.match(/^\s*"((?:\\.|[^"])*)"\s*=\s*"(.*)"\s*;/)
      values[match[1]] << match[2] if match
    end
    duplicates = values.select { |_key, entries| entries.length > 1 }
    abort("Duplicate localization keys remain in #{path}: #{duplicates.keys.join(", ")}") unless duplicates.empty?
  end
' \
  Sources/ShixinStressPower/Resources/zh-Hans.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/en.lproj/Localizable.strings \
  Sources/ShixinStressPower/Resources/ja.lproj/Localizable.strings

echo "[2/9] Run the non-stress core release self-test"
swift run --scratch-path "$SCRATCH_PATH" -c release ShixinStressPowerSelfTest --core-only

echo "[3/9] Build or import the isolated release candidate"
mkdir -p "$APP_OUTPUT" "$STAGE_DIR" "$MOUNT_DIR" "$DIST_DIR"
if [ -n "${SHIXIN_RELEASE_APP_SOURCE:-}" ]; then
  test -d "$SHIXIN_RELEASE_APP_SOURCE"
  ditto "$SHIXIN_RELEASE_APP_SOURCE" "$APP_OUTPUT/${APP_NAME}.app"
else
  SHIXIN_APP_INSTALL_DIR="$APP_OUTPUT" \
  SHIXIN_SWIFT_SCRATCH_PATH="$SCRATCH_PATH" \
    Scripts/build-app.sh
fi

BUILT_APP="$APP_OUTPUT/${APP_NAME}.app"
BUILT_HELPER="$BUILT_APP/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"
test -x "$BUILT_APP/Contents/MacOS/$PRODUCT_NAME"
test -x "$BUILT_HELPER"
codesign --verify --deep --strict --verbose=2 "$BUILT_APP"
codesign --verify --strict --verbose=2 "$BUILT_HELPER"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUILT_APP/Contents/Info.plist")" = "$APP_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT_APP/Contents/Info.plist")" = "$APP_BUILD"
strings "$BUILT_HELPER" | grep -Fx "$EXPECTED_HELPER_VERSION" >/dev/null
file "$BUILT_APP/Contents/MacOS/$PRODUCT_NAME" | grep -F "arm64" >/dev/null

if [ -x "$BUILT_APP/Contents/Resources/Tools/smartctl" ]; then
  test -n "${SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE:-}"
  test -s "$SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE"
  SMARTMONTOOLS_SOURCE_FILENAME="$(basename "$SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE")"
  SMARTCTL_STATUS="bundled; corresponding source included as Licenses/$SMARTMONTOOLS_SOURCE_FILENAME"
else
  SMARTMONTOOLS_SOURCE_FILENAME=""
  SMARTCTL_STATUS="not bundled in this build"
fi

echo "[4/9] Stage the release distribution"
ditto "$BUILT_APP" "$STAGE_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp "$INSTALL_PDF" "$STAGE_DIR/安装与使用说明 - Installation Guide.pdf"
cp "$LEGAL_PDF" "$STAGE_DIR/版权、开源许可与第三方声明 - Copyright, Open Source License and Third-Party Notices.pdf"
mkdir -p "$STAGE_DIR/Licenses"
cp LICENSE "$STAGE_DIR/Licenses/SHIXIN-LAB-GPL-3.0.txt"
cp NOTICE.md "$STAGE_DIR/Licenses/SHIXIN-LAB-NOTICE.md"
cp Packaging/THIRD-PARTY-NOTICES.txt "$STAGE_DIR/Licenses/THIRD-PARTY-NOTICES.txt"
cp Packaging/smartmontools-COPYING.txt "$STAGE_DIR/Licenses/smartmontools-COPYING.txt"
if [ -s "$BUILT_APP/Contents/Resources/Licenses/smartctl-version.txt" ]; then
  cp "$BUILT_APP/Contents/Resources/Licenses/smartctl-version.txt" "$STAGE_DIR/Licenses/smartctl-version.txt"
fi
if [ -n "$SMARTMONTOOLS_SOURCE_FILENAME" ]; then
  cp "$SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE" "$STAGE_DIR/Licenses/$SMARTMONTOOLS_SOURCE_FILENAME"
fi

{
  printf '%s\n' 'SHIXIN LAB · 「芯脉」 MacCore Monitor'
  printf '%s\n' 'Release Manifest / 发行清单'
  printf '\n'
  printf 'Product version / 产品版本: %s\n' "$APP_VERSION"
  printf 'Build / 构建: %s\n' "$APP_BUILD"
  printf 'Helper version / Helper 版本: %s\n' "$EXPECTED_HELPER_VERSION"
  printf 'Source baseline / 源码基线: %s\n' "$SOURCE_COMMIT"
  printf 'Release working-tree entries / 发行工作区条目: %s\n' "$SOURCE_CHANGE_COUNT"
  printf 'Generated / 生成时间: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Architecture / 架构: Apple Silicon arm64\n'
  printf 'Minimum system / 最低系统: macOS 15.0\n'
  printf 'Program source license / 程序源码许可: GNU GPL v3 or later (GPL-3.0-or-later)\n'
  printf 'Brand assets / 品牌资产: See NOTICE.md / 见 NOTICE.md\n'
  printf 'smartctl: %s\n' "$SMARTCTL_STATUS"
  printf '\n'
  printf 'Website / 官网: https://shixinqvq.com/lab/xinmai/\n'
  printf 'Source / 源码: https://github.com/ShiXinQvQ/SHIXIN-LAB-XinMai-MacCore-Monitor\n'
  printf '\n'
  printf '%s\n' 'The SHA-256 file is distributed next to this DMG.'
  printf '%s\n' 'SHA-256 校验文件与本 DMG 同目录发布。'
} > "$STAGE_DIR/Release Manifest - 发行清单.txt"

echo "[5/9] Create the compressed DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "[6/9] Verify and mount the DMG read-only"
hdiutil verify "$DMG_PATH"
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" -quiet
MOUNTED=1

MOUNTED_APP="$MOUNT_DIR/${APP_NAME}.app"
MOUNTED_HELPER="$MOUNTED_APP/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"
test -d "$MOUNTED_APP"
test -L "$MOUNT_DIR/Applications"
test -s "$MOUNT_DIR/安装与使用说明 - Installation Guide.pdf"
test -s "$MOUNT_DIR/版权、开源许可与第三方声明 - Copyright, Open Source License and Third-Party Notices.pdf"
test -s "$MOUNT_DIR/Release Manifest - 发行清单.txt"
test -s "$MOUNT_DIR/Licenses/SHIXIN-LAB-GPL-3.0.txt"
test -s "$MOUNT_DIR/Licenses/SHIXIN-LAB-NOTICE.md"
test -s "$MOUNT_DIR/Licenses/THIRD-PARTY-NOTICES.txt"
test -s "$MOUNT_DIR/Licenses/smartmontools-COPYING.txt"
codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP"
codesign --verify --strict --verbose=2 "$MOUNTED_HELPER"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNTED_APP/Contents/Info.plist")" = "$APP_VERSION"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNTED_APP/Contents/Info.plist")" = "$APP_BUILD"
strings "$MOUNTED_HELPER" | grep -Fx "$EXPECTED_HELPER_VERSION" >/dev/null
cmp -s "$BUILT_APP/Contents/MacOS/$PRODUCT_NAME" "$MOUNTED_APP/Contents/MacOS/$PRODUCT_NAME"
cmp -s "$BUILT_HELPER" "$MOUNTED_HELPER"
cmp -s "$INSTALL_PDF" "$MOUNT_DIR/安装与使用说明 - Installation Guide.pdf"
cmp -s "$LEGAL_PDF" "$MOUNT_DIR/版权、开源许可与第三方声明 - Copyright, Open Source License and Third-Party Notices.pdf"
cmp -s LICENSE "$MOUNT_DIR/Licenses/SHIXIN-LAB-GPL-3.0.txt"
cmp -s NOTICE.md "$MOUNT_DIR/Licenses/SHIXIN-LAB-NOTICE.md"

if [ -x "$MOUNTED_APP/Contents/Resources/Tools/smartctl" ]; then
  test -s "$MOUNTED_APP/Contents/Resources/Licenses/THIRD-PARTY-NOTICES.txt"
  test -s "$MOUNTED_APP/Contents/Resources/Licenses/smartmontools-COPYING.txt"
  test -s "$MOUNTED_APP/Contents/Resources/Licenses/smartctl-version.txt"
  test -s "$MOUNT_DIR/Licenses/smartctl-version.txt"
  test -s "$MOUNT_DIR/Licenses/$SMARTMONTOOLS_SOURCE_FILENAME"
  cmp -s "$MOUNTED_APP/Contents/Resources/Licenses/smartctl-version.txt" "$MOUNT_DIR/Licenses/smartctl-version.txt"
  cmp -s "$SHIXIN_SMARTMONTOOLS_SOURCE_ARCHIVE" "$MOUNT_DIR/Licenses/$SMARTMONTOOLS_SOURCE_FILENAME"
  RECORDED_SMARTCTL_SHA="$(tail -n 1 "$MOUNTED_APP/Contents/Resources/Licenses/smartctl-version.txt" | awk '{print $1}')"
  ACTUAL_SMARTCTL_SHA="$(shasum -a 256 "$MOUNTED_APP/Contents/Resources/Tools/smartctl" | awk '{print $1}')"
  test "$RECORDED_SMARTCTL_SHA" = "$ACTUAL_SMARTCTL_SHA"
fi

echo "[7/9] Detach the verified image"
hdiutil detach "$MOUNT_DIR" -quiet
MOUNTED=0

echo "[8/9] Write and verify SHA-256"
(
  cd "$DIST_DIR"
  shasum -a 256 "$DMG_FILENAME" > "${DMG_FILENAME}.sha256"
  shasum -a 256 -c "${DMG_FILENAME}.sha256"
)

echo "[9/9] Release package complete"
echo "DMG: $DMG_PATH"
echo "SHA-256: ${DMG_PATH}.sha256"
echo "Version: $APP_VERSION ($APP_BUILD)"
echo "Helper: $EXPECTED_HELPER_VERSION"
