#!/usr/bin/env bash
# One command for the redesign verification harness: render every routed
# screen (light + dark) to PNG, render every declared SUB-STATE (a second
# tab, an empty/loading/error fixture — docs/redesign/DECISIONS.md B-3/B-4),
# render every declared modal-sheet FLOW step (buy/sell/add-money/withdraw
# and the shared confirm-passcode/glossary sheets — test/shots_flows.dart,
# 2026-08-29: these are never GoRoutes, so shots_all.dart's route walk
# structurally cannot see them), build the artboard-annotated manifest, and
# print a summary an agent (or a human) can trust without re-deriving it.
#
# Usage:
#   bash scripts/design/shots.sh
#
# Produces:
#   build/shots/<screen>__light.png / __dark.png            — one pair per routed screen
#   build/shots/<screen>__<substate>__light.png / __dark.png — one pair per declared sub-state
#   build/shots/<flow>__light.png / __dark.png               — one pair per declared flow step
#   build/shots/_captures.json                    — raw per-(route,theme) facts
#   build/shots/_substate_captures.json           — raw per-(screen,substate,theme) facts
#   build/shots/_flow_captures.json               — raw per-(flow,theme) facts
#   build/shots/manifest.json                     — route/file/PNGs/artboard per screen + sub-state + flow
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

echo "== shots.sh: rendering every routed screen (light + dark) =="
flutter test test/shots_all.dart

echo
echo "== shots.sh: rendering every declared sub-state (light + dark) =="
flutter test test/shots_substates.dart

echo
echo "== shots.sh: rendering every declared modal-sheet flow step (light + dark) =="
flutter test test/shots_flows.dart

echo
echo "== shots.sh: building build/shots/manifest.json =="
python3 scripts/design/build_manifest.py
