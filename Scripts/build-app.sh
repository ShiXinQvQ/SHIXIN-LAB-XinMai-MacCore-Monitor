#!/usr/bin/env bash

# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SHIXIN LAB · 「芯脉」"
PRODUCT_NAME="ShixinStressPower"
HELPER_PRODUCT_NAME="ShixinStressPowerHelper"
HELPER_LABEL="com.shixinqvq.shixinlab.macstresspower.helper"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
HELPER_VERSION="$(sed -n 's/.*helperVersion = "\([^"]*\)".*/\1/p' "$ROOT_DIR/Sources/ShixinStressPowerCore/HelperProtocol.swift" | head -n 1)"
test -n "$HELPER_VERSION"
if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse --verify HEAD)"
  if [ -n "$(git -C "$ROOT_DIR" status --porcelain=v1 --untracked-files=all)" ]; then
    SOURCE_TREE_STATE="dirty"
  else
    SOURCE_TREE_STATE="clean"
  fi
else
  SOURCE_COMMIT="unavailable (source archive)"
  SOURCE_TREE_STATE="unavailable"
fi
APP_INSTALL_DIR="${SHIXIN_APP_INSTALL_DIR:-$HOME/Applications}"
APP_DIR="$APP_INSTALL_DIR/${APP_NAME}.app"
STAGING_ROOT="$(mktemp -d /private/tmp/shixin-maccore-build.XXXXXX)"
STAGED_APP_DIR="$STAGING_ROOT/${APP_NAME}.app"
SWIFT_BUILD_ARGS=(-c release)
if [ -n "${SHIXIN_SWIFT_SCRATCH_PATH:-}" ]; then
  SWIFT_BUILD_ARGS+=(--scratch-path "$SHIXIN_SWIFT_SCRATCH_PATH")
fi

cd "$ROOT_DIR"
swift build "${SWIFT_BUILD_ARGS[@]}" --product "$PRODUCT_NAME"
swift build "${SWIFT_BUILD_ARGS[@]}" --product "$HELPER_PRODUCT_NAME"

BIN_PATH="$(swift build "${SWIFT_BUILD_ARGS[@]}" --product "$PRODUCT_NAME" --show-bin-path)/$PRODUCT_NAME"
HELPER_BIN_PATH="$(swift build "${SWIFT_BUILD_ARGS[@]}" --product "$HELPER_PRODUCT_NAME" --show-bin-path)/$HELPER_PRODUCT_NAME"

mkdir -p "$STAGED_APP_DIR/Contents/MacOS" "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools" "$STAGED_APP_DIR/Contents/Resources/Tools" "$STAGED_APP_DIR/Contents/Resources/Licenses"
cp "$BIN_PATH" "$STAGED_APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$HELPER_BIN_PATH" "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"
cp "$ROOT_DIR/Packaging/Info.plist" "$STAGED_APP_DIR/Contents/Info.plist"
if [ -d "$ROOT_DIR/Sources/ShixinStressPower/Resources" ]; then
  find "$ROOT_DIR/Sources/ShixinStressPower/Resources" -maxdepth 1 -name "*.lproj" -type d -exec cp -R {} "$STAGED_APP_DIR/Contents/Resources/" \;
fi
cp "$ROOT_DIR/Packaging/AppIcon.icns" "$STAGED_APP_DIR/Contents/Resources/AppIconOpenStyle.icns"
for asset in AppIconPreview.png AppIconPreviewInApp.png; do
  if [ -f "$ROOT_DIR/Packaging/$asset" ]; then
    cp "$ROOT_DIR/Packaging/$asset" "$STAGED_APP_DIR/Contents/Resources/$asset"
  fi
done

{
  printf '%s\n' 'SHIXIN LAB · 「芯脉」 Build Provenance / 构建来源'
  printf 'Schema: 1\n'
  printf 'Source commit: %s\n' "$SOURCE_COMMIT"
  printf 'Source working tree: %s\n' "$SOURCE_TREE_STATE"
  printf 'Build script: Scripts/build-app.sh\n'
  printf 'App version: %s\n' "$APP_VERSION"
  printf 'App build: %s\n' "$APP_BUILD"
  printf 'Helper version: %s\n' "$HELPER_VERSION"
} > "$STAGED_APP_DIR/Contents/Resources/SHIXIN-LAB-Build-Provenance.txt"

SMARTCTL_SOURCE="${SHIXIN_SMARTCTL_SOURCE:-}"
if [ -n "$SMARTCTL_SOURCE" ] && [ ! -x "$SMARTCTL_SOURCE" ]; then
  echo "SHIXIN_SMARTCTL_SOURCE is not executable: $SMARTCTL_SOURCE" >&2
  exit 1
fi
if [ -z "$SMARTCTL_SOURCE" ] && [ -x "$ROOT_DIR/Tools/smartctl" ]; then
  SMARTCTL_SOURCE="$ROOT_DIR/Tools/smartctl"
fi

if [ -n "$SMARTCTL_SOURCE" ]; then
  cp "$SMARTCTL_SOURCE" "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl"
  chmod +x "$STAGED_APP_DIR/Contents/Resources/Tools/smartctl"
  cp "$ROOT_DIR/Packaging/THIRD-PARTY-NOTICES.txt" "$STAGED_APP_DIR/Contents/Resources/Licenses/THIRD-PARTY-NOTICES.txt"
  if [ -f "$ROOT_DIR/Packaging/smartmontools-COPYING.txt" ]; then
    cp "$ROOT_DIR/Packaging/smartmontools-COPYING.txt" "$STAGED_APP_DIR/Contents/Resources/Licenses/smartmontools-COPYING.txt"
  fi
  "$SMARTCTL_SOURCE" --version > "$STAGED_APP_DIR/Contents/Resources/Licenses/smartctl-version.txt"
  /usr/bin/shasum -a 256 "$SMARTCTL_SOURCE" >> "$STAGED_APP_DIR/Contents/Resources/Licenses/smartctl-version.txt"
fi

chmod +x "$STAGED_APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$STAGED_APP_DIR/Contents/Resources/PrivilegedHelperTools/$HELPER_LABEL"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$STAGED_APP_DIR" >/dev/null
fi

mkdir -p "$APP_INSTALL_DIR"
if [ -e "$APP_DIR" ]; then
  TRASH_DIR="${SHIXIN_TRASH_DIR:-$HOME/.Trash}"
  PREVIOUS_APP="$TRASH_DIR/${APP_NAME}-prebuild-$(date +%Y%m%d-%H%M%S)-$$.app"
  mkdir -p "$TRASH_DIR"
  mv "$APP_DIR" "$PREVIOUS_APP"
  echo "Previous build moved to Trash: $PREVIOUS_APP"
fi
mv "$STAGED_APP_DIR" "$APP_DIR"
rmdir "$STAGING_ROOT"

echo "Built: $APP_DIR"
