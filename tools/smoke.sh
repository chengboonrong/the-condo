#!/usr/bin/env bash
# Runs the exported builds in smoke mode (tools/export.sh first): the game starts itself, runs 3 s, checks
# the event catalogue, the clock and the story, then prints "SMOKE ok|FAIL ..." and saves a screenshot.
# macOS app here, then the web build in Chromium and WebKit. Windows and Linux builds need their own machines.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
unzip -q builds/macos/TheCondo.zip -d "$tmp"
bin=$(ls -d "$tmp"/*.app/Contents/MacOS/*)
"$bin" -- --smoke > "$tmp/out.txt" 2>&1 &
pid=$!
for _ in $(seq 1 60); do sleep 1; kill -0 $pid 2>/dev/null || break; done
kill $pid 2>/dev/null && echo "macOS: timed out"
grep '^SMOKE' "$tmp/out.txt" | sed 's/^/macOS: /'
grep -q '^SMOKE ok' "$tmp/out.txt"
rm -rf "$tmp"
node tools/web_smoke.mjs builds/web
