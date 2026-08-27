#!/usr/bin/env python3
"""Merge per-batch evidence into one ruling sheet.

The evidence files are written by agents. This file is written by a script, and
the difference matters: an agent that both gathers evidence and assembles the
final list can quietly drop a row it was unsure about. A script cannot. Every
screen that entered a batch appears in the output or the count does not balance.

Usage
-----
    python3 scripts/design/build_rulings.py \
        --evidence docs/redesign/evidence \
        --batches  docs/redesign/batches \
        --out      docs/redesign/RULINGS.md
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

# Order the sheet by how much the ruling matters, not alphabetically.
PRIORITY = {"needs-ruling": 0, "restyle-only": 1, "redesign-to-artboard": 2, "no-action": 3}

BUCKET_BLURB = {
    "needs-ruling": (
        "**No artboard covers these, and the reason is not obvious.** Each one is "
        "either a feature deliberately dropped from the redesign or one simply not "
        "redrawn yet. An agent cannot tell those apart, and guessing wrong either "
        "deletes a live feature or strands it on the dead design system. Rule each."
    ),
    "restyle-only": (
        "No artboard, but the screen clearly survives — bring it onto the new "
        "tokens and components without reinventing its layout. Confirm or override."
    ),
    "redesign-to-artboard": (
        "Covered by a specific artboard. These need no ruling; they are the build "
        "queue. Listed so the count balances and so you can spot a wrong mapping."
    ),
    "no-action": "Helpers, barrel files and unrouted code. No design coverage owed.",
}


def load_batches(batch_dir: Path) -> set[str]:
    expected: set[str] = set()
    for f in sorted(batch_dir.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        for s in data.get("screens", []):
            expected.add(s["app_screen"])
    return expected


def load_evidence(evidence_dir: Path) -> tuple[list[dict], dict]:
    rows: list[dict] = []
    extras: dict = {}
    for f in sorted(evidence_dir.glob("*.json")):
        data = json.loads(f.read_text(encoding="utf-8"))
        batch = data.get("batch", f.stem)
        for s in data.get("screens", []):
            s["batch"] = batch
            rows.append(s)
        for key, value in data.items():
            if key not in ("batch", "screens"):
                extras.setdefault(batch, {})[key] = value
    return rows, extras


def render(rows: list[dict], extras: dict, missing: set[str], orphan: set[str]) -> str:
    out: list[str] = []
    w = out.append

    w("# Redesign 2026-08 — ruling sheet\n")
    w("Every app screen, and what the new canvas does or does not say about it.\n")
    w("Authority and standing rulings: `docs/redesign/DECISIONS.md`. "
      "Per-screen evidence: `docs/redesign/evidence/*.json`.\n")
    w("**Nothing in the build queue starts until the `needs-ruling` section is empty.**\n")

    counts: dict[str, int] = {}
    for r in rows:
        counts[r.get("recommendation", "?")] = counts.get(r.get("recommendation", "?"), 0) + 1

    w("\n| bucket | screens |")
    w("|---|---|")
    for bucket in sorted(counts, key=lambda b: PRIORITY.get(b, 9)):
        w(f"| {bucket} | {counts[bucket]} |")
    w(f"| **total** | **{len(rows)}** |\n")

    if missing:
        w("\n> ⚠️ **Evidence missing** for these screens — they were in a batch but no "
          "agent reported on them. They are unruled by omission, which is the failure "
          "this sheet exists to prevent:\n")
        for m in sorted(missing):
            w(f"> - `{m}`")
        w("")
    if orphan:
        w("\n> ⚠️ Evidence reported for screens not in any batch (agent invented rows "
          "or a path drifted):\n")
        for o in sorted(orphan):
            w(f"> - `{o}`")
        w("")

    for bucket in sorted(counts, key=lambda b: PRIORITY.get(b, 9)):
        group = [r for r in rows if r.get("recommendation") == bucket]
        if not group:
            continue
        w(f"\n## {bucket} ({len(group)})\n")
        w(BUCKET_BLURB.get(bucket, "") + "\n")

        if bucket == "needs-ruling":
            w("| screen | what it does | route | evidence | your ruling |")
            w("|---|---|---|---|---|")
            for r in sorted(group, key=lambda x: x["app_screen"]):
                w(f"| `{short(r['app_screen'])}` | {clean(r.get('purpose'))} "
                  f"| `{clean(r.get('route'))}` | {clean(r.get('evidence'), 160)} | |")
        else:
            w("| screen | what it does | artboard | confidence | why |")
            w("|---|---|---|---|---|")
            for r in sorted(group, key=lambda x: x["app_screen"]):
                art = ", ".join(r.get("covered_by") or []) or "—"
                w(f"| `{short(r['app_screen'])}` | {clean(r.get('purpose'))} | {art} "
                  f"| {r.get('coverage_confidence','?')} | {clean(r.get('why'))} |")

    if extras:
        w("\n---\n\n# Findings the agents were asked to answer directly\n")
        for batch in sorted(extras):
            for key, value in extras[batch].items():
                w(f"\n### {batch} · {key}\n")
                if isinstance(value, str):
                    w(value + "\n")
                else:
                    w("```json")
                    w(json.dumps(value, indent=2)[:6000])
                    w("```")

    return "\n".join(out) + "\n"


def short(path: str) -> str:
    return path.replace("lib/screens/", "")


def clean(text, limit: int = 110) -> str:
    if not text:
        return "—"
    t = str(text).replace("|", "\\|").replace("\n", " ").strip()
    return t if len(t) <= limit else t[: limit - 1] + "…"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--evidence", type=Path, default=Path("docs/redesign/evidence"))
    ap.add_argument("--batches", type=Path, default=Path("docs/redesign/batches"))
    ap.add_argument("--out", type=Path, default=Path("docs/redesign/RULINGS.md"))
    args = ap.parse_args()

    if not args.evidence.is_dir():
        print(f"no evidence directory at {args.evidence}")
        return 2

    expected = load_batches(args.batches)
    rows, extras = load_evidence(args.evidence)
    reported = {r["app_screen"].split("#")[0] for r in rows}

    missing = expected - reported
    orphan = reported - expected

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(rows, extras, missing, orphan), encoding="utf-8")

    print(f"wrote {args.out}")
    print(f"  screens expected from batches: {len(expected)}")
    print(f"  screens reported by agents:    {len(reported)}")
    if missing:
        print(f"  MISSING evidence:              {len(missing)}")
    if orphan:
        print(f"  orphan rows:                   {len(orphan)}")
    needs = sum(1 for r in rows if r.get("recommendation") == "needs-ruling")
    print(f"  rulings required:              {needs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
