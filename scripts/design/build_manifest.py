#!/usr/bin/env python3
"""Build build/shots/manifest.json from a shots_all.dart run.

test/shots_all.dart renders every registered GoRoute (light + dark) and
writes build/shots/_captures.json — the raw per-capture facts (route, source
dart file, PNG paths, whether it actually rendered). This script's only job
is to attach each one's artboard id, read from docs/redesign/RULINGS.md.

R-5 (docs/redesign/DECISIONS.md): "A screen agent takes its artboard id ONLY
from RULINGS.md... No agent may cite a canvas id it did not receive in its
own task." Code comments in lib/screens/** cite STALE canvas ids from the old
97-screen numbering and must never be used for this — see R-5's own example
(`s29`/`s30`/`#s47` etc. now point at unrelated screens). This script never
reads a .dart file's comments; it only reads RULINGS.md's own markdown
tables, matching on the exact `screen` column string shots_all.dart recorded
as each capture's `rulingKey`.

Usage:
    python3 scripts/design/build_manifest.py \
        --captures build/shots/_captures.json \
        --rulings  docs/redesign/RULINGS.md \
        --out      build/shots/manifest.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

# Buckets that carry a `screen | what it does | artboard | confidence | why`
# table (artboard column present). needs-ruling's table has no artboard
# column at all (`screen | what it does | route | evidence | your ruling`) —
# handled separately below.
ARTBOARD_BUCKETS = {"restyle-only", "redesign-to-artboard", "no-action"}
ALL_BUCKETS = {"needs-ruling", *ARTBOARD_BUCKETS}


def _split_row(line: str) -> list[str]:
    """Split one markdown table row into trimmed cells (drop the outer `|`s)."""
    cells = line.strip().strip("|").split("|")
    return [c.strip() for c in cells]


def parse_rulings(path: Path) -> dict[str, dict]:
    """Return {screen_column_text: {"bucket":..., "artboard": str|None}}.

    `screen_column_text` is the exact backtick-stripped `screen` column value
    (e.g. `account/plans_screen.dart` or `wallet/wallet_screens.dart#wallet_home`),
    matching what build_rulings.py's own `short()` writes and what
    shots_all.dart's `rulingKey` field is deliberately built to equal.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    rulings: dict[str, dict] = {}
    current_bucket: str | None = None
    in_table = False

    for line in lines:
        heading = re.match(r"^##\s+([a-z-]+)\s*\(\d+\)\s*$", line.strip())
        if heading:
            bucket = heading.group(1)
            current_bucket = bucket if bucket in ALL_BUCKETS else None
            in_table = False
            continue
        if line.startswith("## "):
            # Any other heading (e.g. the trailing findings section) ends
            # whatever bucket we were in.
            current_bucket = None
            in_table = False
            continue

        if current_bucket is None or not line.strip().startswith("|"):
            continue

        cells = _split_row(line)
        if not cells or not cells[0]:
            continue
        if cells[0].lower() == "screen":
            in_table = True
            continue
        if set(cells[0]) <= {"-"}:
            # Header/body separator row (`|---|---|...`).
            continue
        if not in_table:
            continue

        screen = cells[0].strip("`")
        if not screen:
            continue

        if current_bucket == "needs-ruling":
            # | screen | what it does | route | evidence | your ruling |
            ruling_cell = cells[4] if len(cells) > 4 else ""
            rulings[screen] = {
                "bucket": "needs-ruling",
                "artboard": ruling_cell or None,
            }
        else:
            # | screen | what it does | artboard | confidence | why |
            artboard_cell = cells[2] if len(cells) > 2 else ""
            artboard = None if artboard_cell in ("", "—", "-") else artboard_cell
            rulings[screen] = {
                "bucket": current_bucket,
                "artboard": artboard,
            }

    return rulings


def build_substate_entries(substate_captures: list[dict]) -> list[dict]:
    """Group test/shots_substates.dart's raw (screen, substate, theme) records
    into one manifest entry per (screen, substate) pair — same shape as the
    per-screen entries build_manifest already produces (light/dark PNG paths,
    rendered, unrenderableReason), plus `screen`/`substate` so a sub-state
    entry is distinguishable from a plain screen entry in the same list
    (docs/redesign/DECISIONS.md B-3/B-4: sub-states live in the SAME
    manifest.json screen agents already know to read, not a second file).
    """
    by_name: dict[str, dict] = {}
    order: list[str] = []
    for c in substate_captures:
        name = c["name"]
        if name not in by_name:
            order.append(name)
            by_name[name] = {
                "name": name,
                "screen": c["screen"],
                "substate": c["substate"],
                "route": c["route"],
                "dartFile": c["dartFile"],
                "light": None,
                "dark": None,
                "rendered": True,
                "unrenderableReason": None,
            }
        entry = by_name[name]
        entry[c["theme"]] = c["png"]
        if not c["rendered"]:
            entry["rendered"] = False
            reason = c.get("error") or "unknown"
            existing = entry["unrenderableReason"]
            entry["unrenderableReason"] = reason if not existing else f"{existing}; {c['theme']}: {reason}"
    return [by_name[name] for name in order]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--captures", type=Path, default=Path("build/shots/_captures.json"))
    ap.add_argument(
        "--substate-captures",
        type=Path,
        default=Path("build/shots/_substate_captures.json"),
        help="test/shots_substates.dart's output (docs/redesign/DECISIONS.md B-3/B-4). "
        "Optional — skipped silently if the file doesn't exist.",
    )
    ap.add_argument(
        "--flow-captures",
        type=Path,
        default=Path("build/shots/_flow_captures.json"),
        help="test/shots_flows.dart's output — modal-sheet flows (buy/sell/add-money/"
        "withdraw, confirm-passcode, glossary) that are never GoRoutes, so shots_all.dart's "
        "route walk cannot see them (2026-08-29 audit). Same per-capture record shape as "
        "--substate-captures, folded in the same way. Optional — skipped silently if the "
        "file doesn't exist.",
    )
    ap.add_argument("--rulings", type=Path, default=Path("docs/redesign/RULINGS.md"))
    ap.add_argument("--out", type=Path, default=Path("build/shots/manifest.json"))
    args = ap.parse_args()

    if not args.captures.is_file():
        print(f"no captures file at {args.captures} — run test/shots_all.dart first")
        return 2
    if not args.rulings.is_file():
        print(f"no rulings file at {args.rulings}")
        return 2

    captures = json.loads(args.captures.read_text(encoding="utf-8"))
    rulings = parse_rulings(args.rulings)

    # One manifest entry per SCREEN (route), not per (route, theme) capture —
    # each entry carries both PNG paths. shots_all.dart always writes light
    # then dark for a given `name`, so group by name in first-seen order.
    by_name: dict[str, dict] = {}
    order: list[str] = []
    for c in captures:
        name = c["name"]
        if name not in by_name:
            order.append(name)
            by_name[name] = {
                "name": name,
                "route": c["route"],
                "dartFile": c["dartFile"],
                "light": None,
                "dark": None,
                "rendered": True,
                "unrenderableReason": None,
            }
        entry = by_name[name]
        entry[c["theme"]] = c["png"]
        if not c["rendered"]:
            entry["rendered"] = False
            reason = c.get("error") or "unknown"
            existing = entry["unrenderableReason"]
            entry["unrenderableReason"] = reason if not existing else f"{existing}; {c['theme']}: {reason}"

        ruling_key = c["rulingKey"]
        info = rulings.get(ruling_key)
        if info is None:
            entry["artboard"] = None
            entry["bucket"] = None
            entry["rulingLookupMiss"] = ruling_key
        else:
            entry["artboard"] = info["artboard"]
            entry["bucket"] = info["bucket"]

    screen_entries = [by_name[name] for name in order]

    # Sub-state entries (docs/redesign/DECISIONS.md B-3/B-4) — additive, and
    # optional: a repo with no test/shots_substates.dart run yet still
    # builds a manifest exactly as before.
    substate_entries: list[dict] = []
    if args.substate_captures.is_file():
        substate_captures = json.loads(args.substate_captures.read_text(encoding="utf-8"))
        substate_entries = build_substate_entries(substate_captures)

    # Flow entries (test/shots_flows.dart, 2026-08-29) — same per-capture
    # record shape as substate_captures, so the same grouping function
    # applies unmodified. Kept as its own list (not merged into
    # substate_entries) purely so this script's own summary can report a
    # flow-specific count, per that file's own audit brief ("report your
    # own numbers"); every entry still lands in the one manifest.json list
    # a screen agent already knows to read.
    flow_entries: list[dict] = []
    if args.flow_captures.is_file():
        flow_captures = json.loads(args.flow_captures.read_text(encoding="utf-8"))
        flow_entries = build_substate_entries(flow_captures)

    manifest = screen_entries + substate_entries + flow_entries

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    total = len(screen_entries)
    captured = sum(1 for e in screen_entries if e["rendered"])
    unrenderable = total - captured
    no_artboard = sum(1 for e in screen_entries if e["rendered"] and not e.get("artboard"))
    lookup_misses = [e["name"] for e in screen_entries if e.get("rulingLookupMiss")]

    substate_total = len(substate_entries)
    substate_captured = sum(1 for e in substate_entries if e["rendered"])
    substate_unrenderable = substate_total - substate_captured

    flow_total = len(flow_entries)
    flow_captured = sum(1 for e in flow_entries if e["rendered"])
    flow_unrenderable = flow_total - flow_captured

    print(f"wrote {args.out}")
    print(f"  screens captured:      {captured}")
    print(f"  screens unrenderable:  {unrenderable}")
    print(f"  captured + unrenderable = {captured + unrenderable} (total routed screens: {total})")
    print(f"  screens with no artboard (needs-ruling / restyle-only / no-action / unmapped): {no_artboard}")
    print(f"  sub-states captured:      {substate_captured}")
    print(f"  sub-states unrenderable:  {substate_unrenderable}")
    print(f"  flow steps captured:      {flow_captured}")
    print(f"  flow steps unrenderable:  {flow_unrenderable}")
    if unrenderable:
        print("  UNRENDERABLE (screens):")
        for e in screen_entries:
            if not e["rendered"]:
                print(f"    - {e['name']} ({e['route']}, {e['dartFile']}): {e['unrenderableReason']}")
    if substate_unrenderable:
        print("  UNRENDERABLE (sub-states):")
        for e in substate_entries:
            if not e["rendered"]:
                print(f"    - {e['name']} ({e['route']}, {e['dartFile']}): {e['unrenderableReason']}")
    if flow_unrenderable:
        print("  UNRENDERABLE (flow steps):")
        for e in flow_entries:
            if not e["rendered"]:
                print(f"    - {e['name']} ({e['route']}, {e['dartFile']}): {e['unrenderableReason']}")
    if lookup_misses:
        # Should never happen if shots_all.dart's rulingKey values are kept
        # in sync with RULINGS.md's screen column — surfaced loudly rather
        # than silently defaulting to null so a drift is caught immediately.
        print(f"  WARNING: {len(lookup_misses)} screen(s) had a rulingKey not found in RULINGS.md at all:")
        for n in lookup_misses:
            print(f"    - {n}")

    # One line a human or an agent can trust without re-deriving it —
    # scripts/design/shots.sh's own required summary line (docs/redesign/
    # DECISIONS.md B-3/B-4: "N screens, N sub-states, N unrenderable"; flow
    # steps added 2026-08-29 alongside test/shots_flows.dart).
    print(
        f"SUMMARY: {total} screens, {substate_total} sub-states, {flow_total} flow steps, "
        f"{unrenderable + substate_unrenderable + flow_unrenderable} unrenderable"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
