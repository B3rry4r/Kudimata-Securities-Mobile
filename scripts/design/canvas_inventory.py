#!/usr/bin/env python3
"""Parse a Claude Design canvas export into a machine-diffable screen inventory.

Why this exists
---------------
The last redesign tracked 66 screens in a hand-transcribed spec document. The
canvas grew to 97 and the document silently went stale, because a paraphrase of
a design has no way to notice that the design moved.

A hash cannot go stale. This tool reduces each artboard to (identity, visible
copy, structure hash) so the next redesign is a *diff*, not a re-read: only the
screens that actually changed get an agent, and every screen claimed unchanged
is proven unchanged by its hash.

Usage
-----
    python3 scripts/design/canvas_inventory.py <canvas-dir> --out inventory.json
    python3 scripts/design/canvas_inventory.py <canvas-dir>            # summary

Canvas shape it expects (Claude Design `.dc.html` export):
    <div style="font:var(--text-card-title)...">22 · Home, verified</div>
    ...
    <div id="s22"  ...>   light artboard
    <div id="s22d" ...>   the same screen in dark
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
from pathlib import Path

SCREEN_OPEN = re.compile(r'<div\s+id="(s(\d+)([a-z]*))"', re.IGNORECASE)
TITLE = re.compile(
    r'<div[^>]*font:var\(--text-card-title\)[^>]*>(.*?)</div>', re.IGNORECASE | re.DOTALL
)
TAG = re.compile(r"<[^>]+>")
WS = re.compile(r"\s+")
STYLE_ATTR = re.compile(r'\sstyle="[^"]*"', re.IGNORECASE)
IMG_SRC = re.compile(r'<img[^>]*src="([^"]+)"', re.IGNORECASE)


def find_block(text: str, start: int) -> str:
    """Return the full <div>...</div> block that opens at `start`.

    Walks tags counting div depth. Cheap, and correct for the well-formed
    machine-generated markup these exports contain.
    """
    depth = 0
    i = start
    n = len(text)
    while i < n:
        lt = text.find("<", i)
        if lt == -1:
            break
        gt = text.find(">", lt)
        if gt == -1:
            break
        tag = text[lt : gt + 1]
        low = tag.lower()
        if low.startswith("<div"):
            if not low.endswith("/>"):
                depth += 1
        elif low.startswith("</div"):
            depth -= 1
            if depth == 0:
                return text[start : gt + 1]
        i = gt + 1
    return text[start:]


def visible_text(block: str) -> str:
    """The copy a user would read. This is the part a redesign usually changes."""
    stripped = TAG.sub(" ", block)
    return WS.sub(" ", html.unescape(stripped)).strip()


def structure_hash(block: str) -> str:
    """Layout identity, insensitive to inline-style churn and whitespace.

    Style attributes are deliberately excluded: a colour token swap should not
    read as "this screen was restructured". Copy and element order should.
    """
    skeleton = STYLE_ATTR.sub("", block)
    skeleton = WS.sub(" ", skeleton)
    return hashlib.sha256(skeleton.encode("utf-8")).hexdigest()[:16]


def full_hash(block: str) -> str:
    """Byte-level identity including styling. Any change at all moves this."""
    return hashlib.sha256(WS.sub(" ", block).encode("utf-8")).hexdigest()[:16]


def normalise_title(raw: str) -> str:
    """'22 · Home, verified' -> 'home, verified' — number-independent identity.

    Screen numbers are canvas-local and get renumbered when artboards are
    inserted. Titles survive. Matching on the title is what lets a diff across
    two canvases mean anything.
    """
    text = visible_text(raw)
    text = re.sub(r"^\s*\d+\s*[·:.\-]\s*", "", text)
    return WS.sub(" ", text).strip().lower()


def parse_file(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="replace")

    # Index every title with its offset so each artboard can claim the nearest
    # one above it.
    titles = [(m.start(), m.group(1)) for m in TITLE.finditer(text)]

    screens: list[dict] = []
    for order, m in enumerate(SCREEN_OPEN.finditer(text)):
        sid, number, suffix = m.group(1), int(m.group(2)), m.group(3)
        block = find_block(text, m.start())

        title_raw = ""
        for offset, raw in titles:
            if offset < m.start():
                title_raw = raw
            else:
                break

        copy = visible_text(block)
        screens.append(
            {
                "file": path.name,
                "id": sid,
                "number": number,
                "variant": "dark" if suffix == "d" else ("light" if not suffix else suffix),
                "order": order,
                "title": normalise_title(title_raw),
                "title_raw": visible_text(title_raw),
                "bytes": len(block),
                "copy": copy,
                "copy_words": len(copy.split()),
                "assets": sorted(set(IMG_SRC.findall(block))),
                "structure_hash": structure_hash(block),
                "full_hash": full_hash(block),
            }
        )
    return screens


def build(canvas_dir: Path) -> dict:
    files = sorted(canvas_dir.glob("*.dc.html"))
    if not files:
        print(f"no .dc.html files in {canvas_dir}", file=sys.stderr)
        sys.exit(2)

    screens: list[dict] = []
    for f in files:
        screens.extend(parse_file(f))

    return {
        "source": canvas_dir.name,
        "files": [f.name for f in files],
        "counts": {
            "total": len(screens),
            "light": sum(1 for s in screens if s["variant"] == "light"),
            "dark": sum(1 for s in screens if s["variant"] == "dark"),
        },
        "screens": screens,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("canvas_dir", type=Path)
    ap.add_argument("--out", type=Path, help="write inventory JSON here")
    args = ap.parse_args()

    inv = build(args.canvas_dir)

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(inv, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.out}")

    c = inv["counts"]
    print(f"\n{inv['source']}: {c['total']} artboards ({c['light']} light, {c['dark']} dark) "
          f"across {len(inv['files'])} file(s)")
    for f in inv["files"]:
        n = sum(1 for s in inv["screens"] if s["file"] == f)
        print(f"  {n:3}  {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
