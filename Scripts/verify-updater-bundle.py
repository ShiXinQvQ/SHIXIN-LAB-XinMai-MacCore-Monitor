#!/usr/bin/env python3
# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the shipping updater configuration without contacting its server."""
import argparse
import base64
import hashlib
import os
import plistlib
import re
import subprocess
from pathlib import Path


FEED = "https://shixinqvq.com/lab/maccore/updates/appcast.xml"
POLICY = {
    "SUEnableAutomaticChecks": False, "SUAutomaticallyUpdate": False,
    "SUAllowsAutomaticUpdates": False, "SUEnableSystemProfiling": False,
    "SUEnableJavaScript": False, "SUVerifyUpdateBeforeExtraction": True,
    "SURequireSignedFeed": True, "SUSignedFeedFailureExpirationInterval": 0,
}


def validate(info, require_key):
    if info.get("SUFeedURL") != FEED:
        raise ValueError("Unexpected production update URL")
    for key, value in POLICY.items():
        if key not in info or info[key] != value:
            raise ValueError("Unexpected updater policy: " + key)
    if any(key.startswith("XinMaiReview") for key in info) or "LSEnvironment" in info:
        raise ValueError("Test environment must not enter a release")
    if info.get("CFBundleIdentifier") != "com.shixinqvq.shixinlab.macstresspower":
        raise ValueError("Unexpected product bundle identifier")
    key = info.get("SUPublicEDKey")
    if require_key or key is not None:
        if not isinstance(key, str) or len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError("A valid product Ed25519 public key is required")
    if require_key and int(info["CFBundleVersion"]) <= 300:
        raise ValueError("The first update-enabled release needs a new build above 300")
    return hashlib.sha256(base64.b64decode(key)).hexdigest() if key else "not configured (development only)"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--require-key", action="store_true")
    args = parser.parse_args()
    contents = args.app / "Contents"
    info = plistlib.loads((contents / "Info.plist").read_bytes())
    fingerprint = validate(info, args.require_key)
    build_info = subprocess.check_output([
        "xcrun", "vtool", "-show-build", str(contents / "MacOS/ShixinStressPower")
    ], text=True)
    sdk_path = Path(os.environ.get("SHIXIN_BUILD_SDK_PATH") or subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip())
    sdk = plistlib.loads((sdk_path / "SDKSettings.plist").read_bytes())["Version"]
    versions = re.findall(r"^\s+sdk\s+(\S+)", build_info, re.MULTILINE)
    def version_tuple(value):
        return tuple((list(map(int, value.split("."))) + [0, 0])[:3])
    if not versions or any(version_tuple(value) != version_tuple(sdk) for value in versions):
        raise ValueError(f"Linked SDK {versions} does not match build SDK {sdk}; use Scripts/swift-build.sh")
    framework = contents / "Frameworks/Sparkle.framework"
    metadata = plistlib.loads((framework / "Resources/Info.plist").read_bytes())
    if metadata["CFBundleShortVersionString"] != "2.10.0":
        raise ValueError("Unexpected Sparkle framework version")
    linked = subprocess.check_output(["otool", "-L", str(contents / "MacOS/ShixinStressPower")], text=True)
    if "@rpath/Sparkle.framework/Versions/B/Sparkle" not in linked:
        raise ValueError("Missing relocatable Sparkle dependency")
    if any("Sparkle.framework" in line and "@rpath/" not in line for line in linked.splitlines()[1:]):
        raise ValueError("Sparkle dependency references an external location")
    if not (contents / "Resources/Licenses/Sparkle-LICENSE.txt").is_file():
        raise ValueError("Sparkle license is missing")
    smartctl = contents / "Resources/Tools/smartctl"
    if smartctl.is_file():
        record = (contents / "Resources/Licenses/smartctl-version.txt").read_text().splitlines()[-1]
        expected = hashlib.sha256(smartctl.read_bytes()).hexdigest() + "  smartctl"
        if record != expected:
            raise ValueError("smartctl checksum must describe the signed binary without a local path")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(args.app)], check=True)
    print("Updater bundle verified; public-key SHA-256: " + fingerprint)


if __name__ == "__main__":
    main()
