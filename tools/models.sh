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
marker="$(mktemp)"
"$GODOT" --headless --path . --import
# The textures that import just extracted from the .glb files: VRAM compressed with mipmaps, as the editor's
# 3D detection would make them, pinned so the result never depends on whether the editor was opened.
extracted="$(find assets/models -name '*.png' -newer "$marker")"
rm -f "$marker"
if [ -n "$extracted" ]; then
  for png in $extracted; do
    sed -i.bak -e 's|^compress/mode=.*|compress/mode=2|' -e 's|^mipmaps/generate=.*|mipmaps/generate=true|' \
      -e 's|^detect_3d/compress_to=.*|detect_3d/compress_to=0|' "$png.import"
    case "$png" in *_normal.png) sed -i.bak 's|^compress/normal_map=.*|compress/normal_map=1|' "$png.import" ;; esac
    rm -f "$png.import.bak"
  done
  "$GODOT" --headless --path . --import
fi
