#!/usr/bin/env bash
# Renders the itch.io page images (docs/itch-page.md) into builds/itch/: five screenshots at 1920x1080 from
# tools/stills.gd (act 1 for home, act 2 after the colour drains) and the 630x500 cover from tools/cover.gd.
# Exits 1 if any image is missing or the wrong size.
# Needs a window, not --headless. Retake them whenever the game's look changes.
#   GODOT=<Godot 4.7.2> tools/itch.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
out=builds/itch

# stills.gd saves at the window size: 1920x1080 needs a window override, as in tools/trailer.sh.
if [ -e override.cfg ]; then echo "override.cfg already exists: not overwriting it" >&2; exit 1; fi
tmp=$(mktemp -d)
trap 'rm -f override.cfg; rm -rf "$tmp"' EXIT
printf '[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
for act in 1 2; do
  "$GODOT" --path . --script res://tools/stills.gd -- --out="$tmp/act$act" --act=$act > "$tmp/act$act.log" 2>&1 \
    || { cat "$tmp/act$act.log" >&2; exit 1; }
  if grep -q "SCRIPT ERROR" "$tmp/act$act.log"; then cat "$tmp/act$act.log" >&2; exit 1; fi
done
rm -f override.cfg

rm -rf "$out"
mkdir -p "$out/screenshots"
# Tease only, as the trailer: nothing from the reveal (stills.gd's b1107 and still_gap are never used).
# Strongest first: itch.io shows the first screenshot largest.
cp "$tmp/act2/hallway_figure.png" "$out/screenshots/1-hallway.png"
cp "$tmp/act2/bedroom_wall.png" "$out/screenshots/2-bedroom.png"
cp "$tmp/act2/tap.png" "$out/screenshots/3-tap.png"
cp "$tmp/act1/entrance.png" "$out/screenshots/4-front-door.png"
cp "$tmp/act2/clock.png" "$out/screenshots/5-clock.png"
"$GODOT" --path . --script res://tools/cover.gd -- --still="$tmp/act2/kitchen_figure.png" --out="$PWD/$out/cover.png" \
  --focus=0.49 > "$tmp/cover.log" 2>&1 || { cat "$tmp/cover.log" >&2; exit 1; }
if grep -q "SCRIPT ERROR" "$tmp/cover.log"; then cat "$tmp/cover.log" >&2; exit 1; fi

fails=0
for f in cover.png:630x500 screenshots/{1-hallway,2-bedroom,3-tap,4-front-door,5-clock}.png:1920x1080; do
  file=$out/${f%%:*}
  size=$(sips -g pixelWidth -g pixelHeight "$file" 2>/dev/null | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { print w "x" h }')
  echo "$file $size"
  [ "$size" = "${f##*:}" ] || { echo "FAIL: $file should be ${f##*:}" >&2; fails=1; }
done
exit "$fails"
