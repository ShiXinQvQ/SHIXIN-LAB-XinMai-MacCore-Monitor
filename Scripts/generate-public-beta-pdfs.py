#!/usr/bin/env python3

# Copyright (C) 2026 SHIXIN LAB / Shixin
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

import hashlib
import json
import plistlib
import re
from pathlib import Path
from xml.sax.saxutils import escape

import reportlab
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    HRFlowable,
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "Packaging" / "PublicBetaDocs"
OUTPUT_DIR = ROOT / "output" / "pdf"
ICON_PATH = ROOT / "Packaging" / "AppIcon.iconset" / "icon_512x512@2x.png"
INFO_PLIST_PATH = ROOT / "Packaging" / "Info.plist"
HELPER_PROTOCOL_PATH = ROOT / "Sources" / "ShixinStressPowerCore" / "HelperProtocol.swift"

INSTALL_OUTPUT_NAME = "SHIXIN LAB - XinMai - Installation Guide - zh-Hans & English.pdf"
LEGAL_OUTPUT_NAME = "SHIXIN LAB - XinMai - Copyright, Open Source License & Third-Party Notices - zh-Hans & English.pdf"
MANIFEST_PATH = OUTPUT_DIR / "SHIXIN-LAB-XinMai-PDF-SOURCE-MANIFEST.json"

SOURCE_FILES = (
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
)

LIGHT_FONT = "/System/Library/Fonts/STHeiti Light.ttc"
MEDIUM_FONT = "/System/Library/Fonts/STHeiti Medium.ttc"

NAVY = colors.HexColor("#07131F")
INK = colors.HexColor("#10202F")
MUTED = colors.HexColor("#5E6C78")
CYAN = colors.HexColor("#16B9E8")
PALE_CYAN = colors.HexColor("#EAF9FE")
LINE = colors.HexColor("#D9E4EB")
WHITE = colors.white
BRAND_TEXT = "SHIXIN LAB · 「芯脉」"


def release_metadata() -> dict[str, str]:
    with INFO_PLIST_PATH.open("rb") as handle:
        info = plistlib.load(handle)
    helper_source = HELPER_PROTOCOL_PATH.read_text(encoding="utf-8")
    helper_match = re.search(r'helperVersion\s*=\s*"([^"]+)"', helper_source)
    if helper_match is None:
        raise RuntimeError("Could not read Helper version from HelperProtocol.swift")
    return {
        "app_version": str(info["CFBundleShortVersionString"]),
        "app_build": str(info["CFBundleVersion"]),
        "helper_version": helper_match.group(1),
    }


RELEASE = release_metadata()
APP_VERSION = RELEASE["app_version"]
APP_BUILD = RELEASE["app_build"]
HELPER_VERSION = RELEASE["helper_version"]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_document_metadata() -> None:
    for path in SOURCE_DIR.glob("*.md"):
        text = path.read_text(encoding="utf-8")
        for value, label in (
            (APP_VERSION, "app version"),
            (APP_BUILD, "app build"),
            (HELPER_VERSION, "Helper version"),
        ):
            if value not in text:
                raise RuntimeError(f"{path.name} is missing current {label}: {value}")


def write_source_manifest() -> None:
    manifest = {
        "schema": 1,
        "release": RELEASE,
        "generator": {"reportlab": str(reportlab.Version)},
        "sources": {relative: sha256(ROOT / relative) for relative in SOURCE_FILES},
        "outputs": {
            f"output/pdf/{INSTALL_OUTPUT_NAME}": sha256(OUTPUT_DIR / INSTALL_OUTPUT_NAME),
            f"output/pdf/{LEGAL_OUTPUT_NAME}": sha256(OUTPUT_DIR / LEGAL_OUTPUT_NAME),
        },
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def brand_markup(separator_size: float | None = None) -> str:
    """Render the brand separator with Latin metrics instead of a full CJK cell."""
    size = f" size='{separator_size:g}'" if separator_size is not None else ""
    return f"SHIXIN LAB<font name='Helvetica'{size}> · </font>「芯脉」"


def escaped_with_narrow_separators(text: str) -> str:
    return escape(text).replace(" · ", "<font name='Helvetica'> · </font>")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("XinMaiSans", LIGHT_FONT))
    pdfmetrics.registerFont(TTFont("XinMaiSansMedium", MEDIUM_FONT))
    pdfmetrics.registerFontFamily(
        "XinMaiSans",
        normal="XinMaiSans",
        bold="XinMaiSansMedium",
        italic="XinMaiSans",
        boldItalic="XinMaiSansMedium",
    )


def inline_markup(text: str) -> str:
    parts = re.split(r"(\*\*.*?\*\*|`.*?`)", text)
    output: list[str] = []
    for part in parts:
        if part.startswith("**") and part.endswith("**"):
            output.append(f"<b>{escaped_with_narrow_separators(part[2:-2])}</b>")
        elif part.startswith("`") and part.endswith("`"):
            output.append(f"<font name='Courier'>{escape(part[1:-1])}</font>")
        else:
            output.append(escaped_with_narrow_separators(part))
    return "".join(output)


def draw_mixed_footer(canvas, x: float, y: float) -> None:
    segments = (
        ("XinMaiSans", 8, "SHIXIN LAB"),
        ("Helvetica", 7.2, " · "),
        ("XinMaiSans", 8, "「芯脉」 MacCore Monitor"),
        ("Helvetica", 7.2, " · "),
        ("XinMaiSans", 8, APP_VERSION),
    )
    cursor = x
    for font_name, font_size, text in segments:
        canvas.setFont(font_name, font_size)
        canvas.drawString(cursor, y, text)
        cursor += pdfmetrics.stringWidth(text, font_name, font_size)


def build_styles(compact: bool = False):
    base = getSampleStyleSheet()
    body_size = 8.5 if compact else 9.1
    body_leading = 12.8 if compact else 14.3
    heading_size = 12.6 if compact else 13.5
    heading_leading = 17.5 if compact else 19
    heading_space_before = 8 if compact else 10
    return {
        "cover_title": ParagraphStyle(
            "CoverTitle",
            parent=base["Title"],
            fontName="XinMaiSansMedium",
            fontSize=27,
            leading=35,
            textColor=WHITE,
            alignment=TA_LEFT,
            spaceAfter=10,
            wordWrap="CJK",
        ),
        "cover_subtitle": ParagraphStyle(
            "CoverSubtitle",
            parent=base["Normal"],
            fontName="XinMaiSans",
            fontSize=14,
            leading=22,
            textColor=colors.HexColor("#BCEEFF"),
            spaceAfter=12,
            wordWrap="CJK",
        ),
        "cover_meta": ParagraphStyle(
            "CoverMeta",
            parent=base["Normal"],
            fontName="XinMaiSans",
            fontSize=10.5,
            leading=17,
            textColor=colors.HexColor("#9BAEBB"),
            wordWrap="CJK",
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="XinMaiSansMedium",
            fontSize=22,
            leading=30,
            textColor=NAVY,
            spaceBefore=4,
            spaceAfter=16,
            wordWrap="CJK",
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="XinMaiSansMedium",
            fontSize=heading_size,
            leading=heading_leading,
            textColor=colors.HexColor("#087FA5"),
            spaceBefore=heading_space_before,
            spaceAfter=4,
            keepWithNext=True,
            wordWrap="CJK",
        ),
        "h3": ParagraphStyle(
            "H3",
            parent=base["Heading3"],
            fontName="XinMaiSansMedium",
            fontSize=11.5,
            leading=17,
            textColor=INK,
            spaceBefore=9,
            spaceAfter=4,
            keepWithNext=True,
            wordWrap="CJK",
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="XinMaiSans",
            fontSize=body_size,
            leading=body_leading,
            textColor=INK,
            spaceAfter=4,
            wordWrap="CJK",
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="XinMaiSans",
            fontSize=body_size,
            leading=body_leading,
            leftIndent=11,
            firstLineIndent=-7,
            textColor=INK,
            spaceAfter=2,
            wordWrap="CJK",
        ),
        "note": ParagraphStyle(
            "Note",
            parent=base["BodyText"],
            fontName="XinMaiSans",
            fontSize=9.3,
            leading=15.5,
            textColor=colors.HexColor("#0A5F7A"),
            wordWrap="CJK",
        ),
    }


def draw_page(canvas, doc) -> None:
    width, height = A4
    canvas.saveState()
    if doc.page == 1:
        canvas.setFillColor(NAVY)
        canvas.rect(0, 0, width, height, fill=1, stroke=0)
        canvas.setFillColor(CYAN)
        canvas.rect(0, height - 7 * mm, width, 7 * mm, fill=1, stroke=0)
        canvas.setFillColor(colors.HexColor("#0C3147"))
        canvas.circle(width - 22 * mm, 29 * mm, 48 * mm, fill=1, stroke=0)
    else:
        canvas.setFillColor(WHITE)
        canvas.rect(0, 0, width, height, fill=1, stroke=0)
        canvas.setFillColor(CYAN)
        canvas.rect(18 * mm, height - 18 * mm, 42 * mm, 1.6 * mm, fill=1, stroke=0)
        canvas.setStrokeColor(LINE)
        canvas.line(18 * mm, 15 * mm, width - 18 * mm, 15 * mm)
        canvas.setFillColor(MUTED)
        draw_mixed_footer(canvas, 18 * mm, 9.5 * mm)
        canvas.setFont("XinMaiSans", 8)
        canvas.drawRightString(width - 18 * mm, 9.5 * mm, f"{doc.page}")
    canvas.restoreState()


def markdown_flowables(markdown_path: Path, styles) -> list:
    lines = markdown_path.read_text(encoding="utf-8").splitlines()
    content_started = False
    flow: list = []
    for raw in lines:
        line = raw.strip()
        if not content_started:
            if line == "---":
                content_started = True
            continue
        if line == "<!-- PAGEBREAK -->":
            flow.append(PageBreak())
        elif not line:
            continue
        elif line.startswith("# "):
            flow.append(Paragraph(inline_markup(line[2:]), styles["h1"]))
            flow.append(HRFlowable(width="100%", thickness=0.8, color=LINE, spaceAfter=5 * mm))
        elif line.startswith("## "):
            flow.append(Paragraph(inline_markup(line[3:]), styles["h2"]))
        elif line.startswith("### "):
            flow.append(Paragraph(inline_markup(line[4:]), styles["h3"]))
        elif line.startswith("- "):
            flow.append(Paragraph("• " + inline_markup(line[2:]), styles["bullet"]))
        elif line.startswith("> "):
            note = Table(
                [[Paragraph(inline_markup(line[2:]), styles["note"]) ]],
                colWidths=[160 * mm],
            )
            note.setStyle(
                TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (-1, -1), PALE_CYAN),
                        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#9EDFF1")),
                        ("LEFTPADDING", (0, 0), (-1, -1), 9),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                        ("TOPPADDING", (0, 0), (-1, -1), 8),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                    ]
                )
            )
            flow.extend([note, Spacer(1, 3 * mm)])
        else:
            flow.append(Paragraph(inline_markup(line), styles["body"]))
    return flow


def build_pdf(markdown_name: str, output_name: str, subtitle: str, compact: bool = False) -> None:
    styles = build_styles(compact=compact)
    output_path = OUTPUT_DIR / output_name
    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(output_path),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=19 * mm,
        bottomMargin=19 * mm,
        title=subtitle,
        author="SHIXIN LAB / Shixin",
        subject=f"SHIXIN LAB · 「芯脉」 MacCore Monitor {APP_VERSION}",
        creator="SHIXIN LAB Release Documentation",
    )

    story: list = [Spacer(1, 14 * mm)]
    if ICON_PATH.exists():
        icon = Image(str(ICON_PATH), width=28 * mm, height=28 * mm)
        icon.hAlign = "LEFT"
        story.extend([icon, Spacer(1, 6 * mm)])
    story.append(Paragraph(brand_markup(separator_size=18), styles["cover_title"]))
    story.append(Paragraph(subtitle, styles["cover_subtitle"]))
    story.append(
        Paragraph(
            inline_markup(
                f"MacCore Monitor · Version {APP_VERSION} · Build {APP_BUILD}"
            )
            + "<br/>"
            + inline_markup("Apple Silicon · macOS 15+ · Local-first"),
            styles["cover_meta"],
        )
    )
    story.extend([Spacer(1, 55 * mm), Paragraph("Designed and maintained by Shixin", styles["cover_meta"]), PageBreak()])
    story.extend(markdown_flowables(SOURCE_DIR / markdown_name, styles))
    doc.build(story, onFirstPage=draw_page, onLaterPages=draw_page)


def main() -> None:
    validate_document_metadata()
    register_fonts()
    build_pdf(
        "INSTALLATION_GUIDE_BILINGUAL.md",
        INSTALL_OUTPUT_NAME,
        "安装与使用说明 | Installation & Usage Guide",
    )
    build_pdf(
        "COPYRIGHT_AND_LICENSES_BILINGUAL.md",
        LEGAL_OUTPUT_NAME,
        "版权、开源许可与第三方声明 | Copyright, Open Source License & Third-Party Notices",
        compact=True,
    )
    write_source_manifest()
    print(f"Generated and recorded: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
