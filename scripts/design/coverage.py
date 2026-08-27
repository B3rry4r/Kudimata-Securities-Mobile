#!/usr/bin/env python3
"""Map the app's existing screens against the new design canvas.

The failure this prevents
-------------------------
A redesign canvas is almost never a complete replacement for a shipped app. This
one has 56 designed screens; the app has 77 routes. Hand an agent "make the app
match this canvas" and one of two things happens, both silent:

  * it builds the 56 and the other 21 surfaces quietly rot on the old design
    system, or
  * it decides the undesigned screens were dropped and deletes live features.

Neither is the agent's call. Coverage has to be *enumerated* and the gaps ruled
on by a human, before any screen work starts.

This tool does the enumeration mechanically: for every app screen it produces a
ranked shortlist of candidate canvas artboards by content overlap. Confident
matches are proposed; weak ones are flagged. It never decides -- it produces the
table somebody else decides from.

Usage
-----
    python3 scripts/design/coverage.py \
        --inventory new-inventory.json \
        --screens lib/screens \
        --out coverage.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

# Strings a user could read. Dart source is full of non-copy literals
# (route paths, asset keys, keys) -- those are filtered below.
STRING_LIT = re.compile(r"""'([^'\\\n]{3,120})'|"([^"\\\n]{3,120})\"""")

NON_COPY = re.compile(
    r"^(?:/|[a-z_]+/|assets/|package:|https?:|#|[a-z]+[A-Z]|[a-z_]+\.[a-z]|"
    r"[A-Z_]{3,}$|\d+(\.\d+)?$|[a-z-]+$)"
)

STOP = {
    "the", "a", "an", "and", "or", "to", "of", "in", "on", "for", "with", "your",
    "you", "is", "are", "be", "it", "this", "that", "at", "by", "from", "as",
    "light", "dark", "lte", "9", "41",
}


def tokens(text: str) -> set[str]:
    return {t for t in re.findall(r"[a-z][a-z']+", text.lower()) if t not in STOP and len(t) > 2}


def screen_copy(path: Path) -> str:
    """Extract plausible user-visible copy from a Dart screen file."""
    try:
        src = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    out: list[str] = []
    for m in STRING_LIT.finditer(src):
        lit = (m.group(1) or m.group(2) or "").strip()
        if not lit or NON_COPY.match(lit):
            continue
        if " " not in lit and lit.islower():
            continue
        out.append(lit)
    return " ".join(out)


def score(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    # Containment, not Jaccard: a canvas artboard carries far more copy than a
    # Dart file's literals, so symmetric overlap systematically under-scores a
    # true match. What matters is how much of the app screen the artboard covers.
    return len(a & b) / len(a)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--inventory", type=Path, required=True)
    ap.add_argument("--screens", type=Path, required=True)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--confident", type=float, default=0.30)
    ap.add_argument("--weak", type=float, default=0.15)
    args = ap.parse_args()

    inv = json.loads(args.inventory.read_text(encoding="utf-8"))
    artboards = [s for s in inv["screens"] if s["variant"] == "light"]
    art_tokens = {s["id"]: tokens(s["copy"]) for s in artboards}
    art_title = {s["id"]: (s["title_raw"] or s["copy"][:60]) for s in artboards}

    files = sorted(p for p in args.screens.rglob("*.dart"))
    rows: list[dict] = []

    for f in files:
        ft = tokens(screen_copy(f))
        ranked = sorted(
            ((score(ft, art_tokens[a["id"]]), a["id"]) for a in artboards),
            reverse=True,
        )[:3]
        top = ranked[0] if ranked else (0.0, None)
        status = (
            "proposed" if top[0] >= args.confident
            else "weak" if top[0] >= args.weak
            else "uncovered"
        )
        rows.append(
            {
                "app_screen": str(f).replace("\\", "/"),
                "copy_tokens": len(ft),
                "status": status,
                "candidates": [
                    {"artboard": aid, "score": round(sc, 3), "title": art_title.get(aid, "")}
                    for sc, aid in ranked if aid
                ],
                "ruling": None,
            }
        )

    claimed = {c["artboard"] for r in rows if r["status"] == "proposed" for c in r["candidates"][:1]}
    unclaimed = [a["id"] for a in artboards if a["id"] not in claimed]

    result = {
        "app_screens": len(rows),
        "canvas_artboards": len(artboards),
        "counts": {
            s: sum(1 for r in rows if r["status"] == s)
            for s in ("proposed", "weak", "uncovered")
        },
        "artboards_unclaimed": unclaimed,
        "rows": sorted(rows, key=lambda r: (r["status"] != "uncovered", r["status"] != "weak", r["app_screen"])),
    }

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.out}\n")

    print(f"app screens: {result['app_screens']}   canvas artboards: {result['canvas_artboards']}")
    for k, v in result["counts"].items():
        print(f"  {k:10} {v:3}")
    print(f"  artboards claimed by nothing: {len(unclaimed)}")

    print("\n--- app screens with NO design in the new canvas (human ruling required) ---")
    for r in result["rows"]:
        if r["status"] == "uncovered":
            print(f"  {r['app_screen']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
