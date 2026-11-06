#!/usr/bin/env bash
# Renders the road's stills (tools/road_stills.gd) at 1920x1080 in a window: one PNG per shot and sheet.png.
#   tools/road_stills.sh <out> [--before=<dir>] [shot ...]   (no shot names: every shot)
# GODOT defaults to the binary on PATH.
set -euo pipefail
[ $# -ge 1 ] || { echo "usage: tools/road_stills.sh <out> [--before=<dir>] [shot ...]" >&2; exit 2; }
mkdir -p "$1"
out=$(cd "$1" && pwd)
shift
args=()
for a in "$@"; do  # the tool runs from the repo root: give it --before= as an absolute path
  case "$a" in --before=*) a="--before=$(cd "${a#--before=}" && pwd)" ;; esac
  args+=("$a")
done
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# The window opens at the project's size, not --resolution: 1920x1080 needs a window override.
if [ -e override.cfg ]; then echo "override.cfg already exists: not overwriting it"; exit 1; fi
trap 'rm -f override.cfg' EXIT
printf '[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
"$GODOT" --path . --resolution 1920x1080 --script res://tools/road_stills.gd -- --out="$out" ${args[@]+"${args[@]}"}  # (bash 3.2: an empty array is unbound under set -u)
