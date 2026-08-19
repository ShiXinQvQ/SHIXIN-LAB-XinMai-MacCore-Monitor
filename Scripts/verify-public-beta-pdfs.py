#!/usr/bin/env python3

# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "output" / "pdf"
MANIFEST_PATH = OUTPUT_DIR / "SHIXIN-LAB-XinMai-PDF-SOURCE-MANIFEST.json"

EXPECTED_SOURCES = {
    "LICENSE",
    "NOTICE.md",
    "Packaging/AppIcon.iconset/icon_512x512@2x.png",
    "Packaging/Info.plist",
    "Packaging/PublicBetaDocs/COPYRIGHT_AND_LICENSES_BILINGUAL.md",
    "Packaging/PublicBetaDocs/INSTALLATION_GUIDE_BILINGUAL.md",
    "Packaging/THIRD-PARTY-NOTICES.txt",
    "Packaging/smartmontools-COPYING.txt",
    "Scripts/generate-public-beta-pdfs.py",
    "Scripts/requirements-public-beta-docs.txt",
    "Sources/ShixinStressPowerCore/HelperProtocol.swift",
}

EXPECTED_OUTPUTS = {
    "output/pdf/SHIXIN LAB - XinMai - Copyright, Open Source License & Third-Party Notices - zh-Hans & English.pdf",
    "output/pdf/SHIXIN LAB - XinMai - Installation Guide - zh-Hans & English.pdf",
}


def fail(message: str) -> None:
    raise SystemExit(f"PDF source verification failed: {message}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def repository_path(relative_path: str) -> Path:
    relative = Path(relative_path)
    if relative.is_absolute() or ".." in relative.parts:
        fail(f"unsafe manifest path: {relative_path}")
    resolved = (ROOT / relative).resolve()
    try:
        resolved.relative_to(ROOT.resolve())
    except ValueError:
        fail(f"manifest path escapes the repository: {relative_path}")
    return resolved


def current_release_metadata() -> dict[str, str]:
    with (ROOT / "Packaging" / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    helper_source = (
        ROOT / "Sources" / "ShixinStressPowerCore" / "HelperProtocol.swift"
    ).read_text(encoding="utf-8")
    helper_match = re.search(r'helperVersion\s*=\s*"([^"]+)"', helper_source)
    if helper_match is None:
        fail("could not read Helper version from HelperProtocol.swift")
    return {
        "app_version": str(info["CFBundleShortVersionString"]),
        "app_build": str(info["CFBundleVersion"]),
        "helper_version": helper_match.group(1),
    }


def pinned_reportlab_version() -> str:
    requirements = (
        ROOT / "Scripts" / "requirements-public-beta-docs.txt"
    ).read_text(encoding="utf-8")
    match = re.search(r"^reportlab==([^\s#]+)$", requirements, re.MULTILINE)
    if match is None:
        fail("reportlab must be pinned exactly in requirements-public-beta-docs.txt")
    return match.group(1)


def verify_manifest(manifest_path: Path) -> None:
    if not manifest_path.is_file():
        fail(f"manifest is missing: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"manifest is unreadable: {error}")

    if manifest.get("schema") != 1:
        fail("unsupported or missing manifest schema")
    if manifest.get("release") != current_release_metadata():
        fail("manifest release metadata no longer matches Info.plist/HelperProtocol.swift")
    if manifest.get("generator") != {"reportlab": pinned_reportlab_version()}:
        fail("manifest generator version does not match the pinned ReportLab version")

    sources = manifest.get("sources")
    outputs = manifest.get("outputs")
    if not isinstance(sources, dict) or set(sources) != EXPECTED_SOURCES:
        fail("manifest source set is incomplete or unexpected")
    if not isinstance(outputs, dict) or set(outputs) != EXPECTED_OUTPUTS:
        fail("manifest PDF output set is incomplete or unexpected")

    for relative_path, expected_hash in {**sources, **outputs}.items():
        if not isinstance(expected_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
            fail(f"invalid SHA-256 for {relative_path}")
        path = repository_path(relative_path)
        if not path.is_file() or path.stat().st_size == 0:
            fail(f"required file is missing or empty: {relative_path}")
        actual_hash = sha256(path)
        if actual_hash != expected_hash:
            fail(f"SHA-256 mismatch: {relative_path}")

    print("PDF source manifest verification passed.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify that release PDFs match their tracked sources and metadata."
    )
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    args = parser.parse_args()
    verify_manifest(args.manifest.resolve())


if __name__ == "__main__":
    main()
