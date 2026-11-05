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
# The textures that import just extracted from the .glb files: lossless with mipmaps, pinned (3D detection off)
# so the editor never switches them to VRAM compression, which costs nearly four times the download.
extracted="$(find assets/models -name '*.png' -newer "$marker")"
rm -f "$marker"
if [ -n "$extracted" ]; then
  for png in $extracted; do
    sed -i.bak -e 's|^compress/mode=.*|compress/mode=0|' -e 's|^mipmaps/generate=.*|mipmaps/generate=true|' \
      -e 's|^detect_3d/compress_to=.*|detect_3d/compress_to=0|' "$png.import"
    rm -f "$png.import.bak"
  done
  "$GODOT" --headless --path . --import
fi
