#!/usr/bin/env bash
# Runs the exported builds in smoke mode (tools/export.sh first): the game starts itself. The road runs 3 s and
# prints "ROAD-SMOKE ok|FAIL ...", then the flat runs 3 s, checks the event catalogue, the clock and the story,
# and prints "SMOKE ok|FAIL ..." and saves a screenshot. Both lines must be ok, the road's first.
# --flat checks the flat alone, as before the road existed.
# Size cap first (the web download is the budget: 720 KiB before the model rebuild + 8 MiB), then the macOS app,
# then the web build in Chromium and WebKit. Windows and Linux builds need their own machines.
set -uo pipefail
cd "$(dirname "$(realpath "$0")")/.."
status=0
flat=""
[ "${1:-}" = "--flat" ] && flat="--flat"
cap=8912
pck=builds/web/index.pck
if bytes=$(stat -f%z "$pck" 2>/dev/null); then
  kib=$(( (bytes + 1023) / 1024 ))  # rounded up, so a miss never rounds into a pass
  echo "web: index.pck $kib KiB (cap $cap)"
  [ "$bytes" -le $((cap * 1024)) ] || { echo "web: index.pck is over the cap"; status=1; }
else
  echo "web: $pck missing (run tools/export.sh)"  # the other runs still go on, as they do when the pck is over the cap
  status=1
fi
tmp=$(mktemp -d)
unzip -q builds/macos/TheCondo.zip -d "$tmp" || exit 1
bin=$(ls -d "$tmp"/*.app/Contents/MacOS/*)
"$bin" -- --smoke $flat > "$tmp/out.txt" 2>&1 &
pid=$!
for _ in $(seq 1 60); do sleep 1; kill -0 $pid 2>/dev/null || break; done
kill $pid 2>/dev/null && echo "macOS: timed out"
# ROAD-SMOKE lines are not SMOKE lines: the checks below are anchored at the start of the line.
if grep -E '^(ROAD-)?SMOKE' "$tmp/out.txt" | sed 's/^/macOS: /' && awk -v flat="$flat" '/^ROAD-SMOKE ok/ { road = 1 } /^SMOKE ok/ { pass = road || flat != ""; exit } END { exit !pass }' "$tmp/out.txt"; then
  rm -rf "$tmp"
else
  echo "macOS: failed, log kept at $tmp/out.txt"
  status=1
fi
node tools/web_smoke.mjs builds/web $flat || status=1
exit $status
