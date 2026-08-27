#!/usr/bin/env python3
"""Diff two canvas inventories into a per-screen work order.

The point
--------
A redesign is a *diff*, not a re-read. Handing an agent 56 artboards and saying
"make the app look like this" produces two failures at once: screens that were
already right get rebuilt (churn, regressions, wasted tokens), and screens that
quietly changed get missed because nobody enumerated them.

This produces the enumeration. Every screen lands in exactly one bucket, and
every bucket has a defined consequence:

    unchanged   proven identical by hash        -> no agent, do not touch
    restyled    same structure + copy, new CSS  -> token/theme pass only
    changed     copy or structure moved         -> one scoped agent, with a copy diff
    added       in the new canvas only          -> one scoped agent, build it
    dropped     in the old canvas only          -> HUMAN RULING. never auto-deleted,
                                                   never silently kept.

`dropped` is the bucket that matters most and the one an unaided agent gets
wrong. It cannot infer whether a screen was deliberately consolidated away or
simply not redrawn yet, and either guess ships a defect: delete a live feature,
or leave 41 screens on an obsolete design system.

Usage
-----
    python3 scripts/design/canvas_diff.py old.json new.json --out screen-diff.json
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

# Below this, two titles are not the same screen wearing a new name.
FUZZY_THRESHOLD = 0.72
# Above this, a probable match is confident enough to bucket without a ruling.
FUZZY_CONFIDENT = 0.90


def light_screens(inv: dict) -> list[dict]:
    """Only the light artboards carry screen identity.

    Dark and state variants (`s24d`, `s24b`, `s24bd`) hang off a light screen;
    counting them as screens would triple the work order and produce a diff
    nobody can read.
    """
    return [s for s in inv["screens"] if s["variant"] == "light"]


def variants_for(inv: dict, number: int, file: str) -> list[str]:
    return sorted(
        s["id"]
        for s in inv["screens"]
        if s["number"] == number and s["file"] == file and s["variant"] != "light"
    )


def copy_diff(old: str, new: str, limit: int = 40) -> list[str]:
    """Word-level copy changes, as +/- lines. This is what a screen agent reads."""
    old_w, new_w = old.split(), new.split()
    out: list[str] = []
    for line in difflib.unified_diff(old_w, new_w, lineterm="", n=0):
        if line.startswith(("---", "+++", "@@")):
            continue
        out.append(line)
        if len(out) >= limit:
            out.append(f"... (+{max(0, len(new_w) - len(old_w))} words net, truncated)")
            break
    return out


def match(old_screens: list[dict], new_screens: list[dict]) -> tuple[list[tuple], list[dict], list[dict]]:
    """Pair screens by title, then by fuzzy title. Returns (pairs, added, dropped)."""
    by_title: dict[str, list[dict]] = {}
    for s in old_screens:
        by_title.setdefault(s["title"], []).append(s)

    pairs: list[tuple[dict, dict, float]] = []
    used_old: set[str] = set()

    # Pass 1 -- exact normalised title.
    remaining_new: list[dict] = []
    for s in new_screens:
        bucket = [o for o in by_title.get(s["title"], []) if o["id"] not in used_old]
        if bucket and s["title"]:
            old = bucket[0]
            used_old.add(old["id"])
            pairs.append((old, s, 1.0))
        else:
            remaining_new.append(s)

    # Pass 2 -- fuzzy title, best available partner.
    leftover_old = [o for o in old_screens if o["id"] not in used_old]
    still_new: list[dict] = []
    for s in remaining_new:
        best, score = None, 0.0
        for o in leftover_old:
            if o["id"] in used_old:
                continue
            r = difflib.SequenceMatcher(None, s["title"], o["title"]).ratio()
            if r > score:
                best, score = o, r
        if best is not None and score >= FUZZY_THRESHOLD:
            used_old.add(best["id"])
            pairs.append((best, s, round(score, 3)))
        else:
            still_new.append(s)

    dropped = [o for o in old_screens if o["id"] not in used_old]
    return pairs, still_new, dropped


def classify(old: dict, new: dict, score: float) -> str:
    if old["full_hash"] == new["full_hash"]:
        return "unchanged"
    if old["structure_hash"] == new["structure_hash"]:
        return "restyled"
    return "changed"


def build(old_inv: dict, new_inv: dict) -> dict:
    old_screens = light_screens(old_inv)
    new_screens = light_screens(new_inv)
    pairs, added, dropped = match(old_screens, new_screens)

    entries: list[dict] = []

    for old, new, score in pairs:
        bucket = classify(old, new, score)
        entry = {
            "bucket": bucket,
            "new_id": new["id"],
            "new_file": new["file"],
            "old_id": old["id"],
            "title": new["title_raw"] or old["title_raw"],
            "match_confidence": score,
            "needs_ruling": score < FUZZY_CONFIDENT,
            "variants": variants_for(new_inv, new["number"], new["file"]),
            "copy_words": {"old": old["copy_words"], "new": new["copy_words"]},
        }
        if bucket == "changed":
            entry["copy_diff"] = copy_diff(old["copy"], new["copy"])
        entries.append(entry)

    for new in added:
        entries.append(
            {
                "bucket": "added",
                "new_id": new["id"],
                "new_file": new["file"],
                "old_id": None,
                "title": new["title_raw"],
                "match_confidence": 0.0,
                "needs_ruling": False,
                "variants": variants_for(new_inv, new["number"], new["file"]),
                "copy_words": {"old": 0, "new": new["copy_words"]},
            }
        )

    for old in dropped:
        entries.append(
            {
                "bucket": "dropped",
                "new_id": None,
                "new_file": None,
                "old_id": old["id"],
                "title": old["title_raw"],
                "match_confidence": 0.0,
                # Always. An agent may not decide whether a screen was
                # consolidated away or merely not redrawn.
                "needs_ruling": True,
                "ruling": None,
                "variants": [],
                "copy_words": {"old": old["copy_words"], "new": 0},
            }
        )

    order = {"added": 0, "changed": 1, "dropped": 2, "restyled": 3, "unchanged": 4}
    entries.sort(key=lambda e: (order.get(e["bucket"], 9), e.get("new_id") or e.get("old_id") or ""))

    counts: dict[str, int] = {}
    for e in entries:
        counts[e["bucket"]] = counts.get(e["bucket"], 0) + 1

    return {
        "old_source": old_inv["source"],
        "new_source": new_inv["source"],
        "counts": counts,
        "totals": {"old_light": len(old_screens), "new_light": len(new_screens)},
        "rulings_required": sum(1 for e in entries if e["needs_ruling"]),
        "dark_variants_added": new_inv["counts"]["dark"],
        "screens": entries,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("old", type=Path)
    ap.add_argument("new", type=Path)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--bucket", help="print only this bucket")
    args = ap.parse_args()

    old_inv = json.loads(args.old.read_text(encoding="utf-8"))
    new_inv = json.loads(args.new.read_text(encoding="utf-8"))
    diff = build(old_inv, new_inv)

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(diff, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.out}\n")

    t = diff["totals"]
    print(f"old: {t['old_light']} light screens   new: {t['new_light']} light screens"
          f"   (+{diff['dark_variants_added']} dark artboards)")
    print()
    for bucket in ("added", "changed", "dropped", "restyled", "unchanged"):
        n = diff["counts"].get(bucket, 0)
        if n:
            print(f"  {bucket:10} {n:3}")
    print(f"\n  rulings required: {diff['rulings_required']}")

    if args.bucket:
        print(f"\n--- {args.bucket} ---")
        for e in diff["screens"]:
            if e["bucket"] == args.bucket:
                ident = e["new_id"] or e["old_id"]
                conf = "" if e["match_confidence"] in (1.0, 0.0) else f"  ~{e['match_confidence']}"
                print(f"  {ident:8} {e['title'][:70]}{conf}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
