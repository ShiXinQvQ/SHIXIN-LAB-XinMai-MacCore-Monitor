#!/usr/bin/env python3
# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later
"""Assemble a double-clickable, isolated local review app; never a release bundle."""
import argparse
import plistlib
import shutil
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-app", required=True, type=Path)
    parser.add_argument("--test-executable", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--build", required=True, type=int)
    args = parser.parse_args()
    output, home = args.output.resolve(), args.home.resolve()
    if output.exists() or output.suffix != ".app":
        raise SystemExit("Output must be a new .app path; existing apps are never overwritten")
    if args.build <= 300:
        raise SystemExit("Use a distinct local review build above 300")
    if home == Path.home() or home == output or output in home.parents:
        raise SystemExit("Review home must be isolated and outside the app bundle")
    marker = b"Updater test build requires its isolated review home"
    if marker not in args.test_executable.read_bytes():
        raise SystemExit("Expected a SHIXIN_UPDATE_TESTING executable with its isolation guard")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(args.base_app)], check=True)
    home.mkdir(parents=True, exist_ok=True)
    shutil.copytree(args.base_app, output, symlinks=True)
    contents = output / "Contents"
    shutil.copy2(args.test_executable, contents / "MacOS/ShixinStressPower")
    path = contents / "Info.plist"
    info = plistlib.loads(path.read_bytes())
    info.update({
        "CFBundleIdentifier": "com.shixinqvq.shixinlab.macstresspower.audit.review.updater",
        "CFBundleName": output.stem, "CFBundleDisplayName": output.stem,
        "CFBundleVersion": str(args.build),
        "CFBundleShortVersionString": "0.3.1-beta-review",
        "XinMaiReviewHome": str(home),
        "LSEnvironment": {"CFFIXED_USER_HOME": str(home)},
        "SUEnableAutomaticChecks": False,
    })
    # Local review is not permitted to contact or install from a production feed.
    info.pop("SUPublicEDKey", None)
    path.write_bytes(plistlib.dumps(info))
    subprocess.run(["codesign", "--force", "--sign", "-", str(output)], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(output)], check=True)
    print(output)


if __name__ == "__main__":
    main()
