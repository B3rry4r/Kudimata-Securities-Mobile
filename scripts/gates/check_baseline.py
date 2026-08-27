#!/usr/bin/env python3
"""The baseline is where accepted violations live. Guard it.

An accepted violation with no owner and no reason is a stub with better
manners: it silences a gate and records nothing anyone can act on. Six months
later nobody knows whether it was a deliberate trade-off or an agent trying to
get to green.

So: every entry in baseline.json needs a real owner and a real reason, and this
runs in CI alongside the gates themselves.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASELINE = HERE / "baseline.json"

# NOTE: no empty string in here. `"anything".startswith("")` is True, so an ""
# entry makes every value look like a placeholder and the check fails on
# perfectly good baselines. Emptiness is handled by the length tests below.
PLACEHOLDERS = ("unset", "todo", "tbd", "n/a", "na", "?", "none", "-")
MIN_REASON = 15


def main() -> int:
    if not BASELINE.exists():
        print("no baseline.json - nothing accepted, nothing to check")
        return 0

    try:
        data = json.loads(BASELINE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"baseline.json is unreadable: {exc}", file=sys.stderr)
        return 1

    accepted = data.get("accepted", {})
    bad: list[str] = []

    for key, entry in accepted.items():
        owner = str(entry.get("owner", "")).strip()
        reason = str(entry.get("reason", "")).strip()
        where = entry.get("where", "?")

        if owner.lower().startswith(PLACEHOLDERS) or len(owner) < 2:
            bad.append(f"{key} ({where}): no owner")
        if reason.lower().startswith(PLACEHOLDERS) or len(reason) < MIN_REASON:
            bad.append(f"{key} ({where}): reason is missing or too thin to act on")

    print(f"baseline entries: {len(accepted)}")
    if bad:
        print("\nUnexplained accepted violations:\n", file=sys.stderr)
        for line in bad:
            print(f"  {line}", file=sys.stderr)
        print(
            f"\n{len(bad)} problem(s). Give each entry an owner and a reason, "
            "or delete the entry and fix the finding.",
            file=sys.stderr,
        )
        return 1

    print("every accepted violation has an owner and a reason")
    return 0


if __name__ == "__main__":
    sys.exit(main())
