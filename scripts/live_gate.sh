#!/usr/bin/env bash
# Live-backend gate runner — see integration_test/live_gate_test.dart for
# what it asserts and why. Builds and serves the REAL app and drives it in a
# real Chrome tab (real widget finders — the integration_test package, never
# DOM selectors) against a configurable backend base URL (defaults to the
# deployed alpha instance).
#
# Uses `-d web-server` (NOT `-d chrome`): with `-d chrome`, flutter_tools
# launches its OWN Chrome for the app (to open a CDP debug connection) *in
# addition to* the separate Chrome chromedriver launches to drive it — two
# concurrent Chrome process trees. In a container with a constrained cgroup
# pids.max, two Chromes' worth of threads reliably blows the budget
# (`pthread_create: Resource temporarily unavailable`, Chrome crashes before
# the debug connection even completes). `-d web-server` serves the app over
# plain HTTP with no browser of its own; chromedriver's one Chrome instance
# both hosts the app AND is what this script drives. One Chrome instead of
# two. The --web-browser-flag values below additionally trim that one
# instance's own process/thread footprint.
#
# Usage:
#   scripts/live_gate.sh                                   # default base URL
#   scripts/live_gate.sh https://staging.kudimatasecurities.com
#
# Requires: a chromedriver binary compatible with the installed Chrome,
# reachable on PATH or at $CHROMEDRIVER (see below). `google-chrome
# --version` and `chromedriver --version` must report the same major
# version or the WebDriver handshake fails outright.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BASE_URL="${1:-https://alpha.kudimatasecurities.com}"
CHROMEDRIVER="${CHROMEDRIVER:-chromedriver}"
PORT="${CHROMEDRIVER_PORT:-4444}"
WEB_PORT="${LIVE_GATE_WEB_PORT:-7788}"

echo "== Live gate =="
echo "Backend:      $BASE_URL"
echo "Chromedriver: $("$CHROMEDRIVER" --version 2>&1 | head -1)"
echo "Chrome:       $(google-chrome --version 2>&1 || true)"
echo

# Reclaim pid/thread budget from any leftover Chrome/chromedriver process
# trees before starting — see the header comment: this container's cgroup
# pids.max is tight enough that stale processes from a previous run are
# enough on their own to starve a fresh Chrome launch.
pkill -9 -f "chromedriver" >/dev/null 2>&1 || true
pkill -9 -f "/opt/google/chrome/chrome" >/dev/null 2>&1 || true
pkill -9 -f "google-chrome" >/dev/null 2>&1 || true
sleep 1

"$CHROMEDRIVER" --port="$PORT" >/tmp/chromedriver.log 2>&1 &
CHROMEDRIVER_PID=$!
cleanup() {
  kill "$CHROMEDRIVER_PID" >/dev/null 2>&1 || true
  wait "$CHROMEDRIVER_PID" 2>/dev/null || true
  # chromedriver does not reliably reap the Chrome it launched on a killed
  # session — clean up its process tree too (rule 8: kill what you start).
  pkill -9 -f "chromedriver" >/dev/null 2>&1 || true
  pkill -9 -f "/opt/google/chrome/chrome" >/dev/null 2>&1 || true
  pkill -9 -f "google-chrome" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Give chromedriver a moment to bind its port.
for _ in $(seq 1 20); do
  if curl -sf "http://localhost:$PORT/status" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/live_gate_test.dart \
  -d web-server \
  --browser-name=chrome \
  --headless \
  --browser-dimension=430x932 \
  --web-port="$WEB_PORT" \
  --dart-define=API_BASE_URL="$BASE_URL" \
  --web-browser-flag=--disable-dev-shm-usage \
  --web-browser-flag=--disable-gpu \
  --web-browser-flag=--disable-software-rasterizer \
  --web-browser-flag=--no-zygote \
  --web-browser-flag=--disable-extensions \
  --web-browser-flag=--disable-background-networking \
  --web-browser-flag=--disable-sync \
  --web-browser-flag=--disable-default-apps \
  --web-browser-flag=--disable-translate \
  --web-browser-flag=--renderer-process-limit=1

echo
echo "Screenshots: build/live_gate_screenshots/"
