#!/usr/bin/env bash
# Builds the Blender models (art/<id>/build.py: every one when no id is given), then imports the project so
# Godot picks up the new assets/models/<id>.glb files.
#   tools/models.sh [id ...]
# BLENDER defaults to the macOS app's binary, GODOT to the binary on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
GODOT="${GODOT:-godot}"
if [ $# -eq 0 ]; then
  set -- $(for f in art/*/build.py; do basename "$(dirname "$f")"; done)
fi
for id in "$@"; do
  "$BLENDER" -b --factory-startup --python-exit-code 1 --python "art/$id/build.py"
done
"$GODOT" --headless --path . --import
