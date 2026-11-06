#!/usr/bin/env bash
# Builds the Blender models (art/<id>/build.py: every one when no id is given), then imports the project so
# Godot picks up the new assets/models/<id>.glb files.
#   tools/models.sh [id ...]
# BLENDER defaults to the macOS app's binary, GODOT to the binary on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
GODOT="${GODOT:-godot}"
shopt -s nullglob
if [ $# -eq 0 ]; then
  set -- $(for f in art/*/build.py; do basename "$(dirname "$f")"; done)
fi
for id in "$@"; do
  "$BLENDER" -b --factory-startup --python-exit-code 1 --python "art/$id/build.py"
done
"$GODOT" --headless --path . --import
# Every model texture: lossless with mipmaps, pinned (3D detection off) so the editor never switches it to VRAM
# compression, which costs nearly four times the download. The people's (hafiz_*, mei_*) are lossy WebP instead: their
# baked colour is noisy, the loss does not show at full size, and the bytes pay for their faces. Pinned on every run,
# then imported again if that changed any.
changed=0
for f in assets/models/*.png.import; do
  case "$(basename "$f")" in
    hafiz_*|mei_*) mode='s|^compress/mode=.*|compress/mode=1|;s|^compress/lossy_quality=.*|compress/lossy_quality=0.75|' ;;
    *) mode='s|^compress/mode=.*|compress/mode=0|' ;;
  esac
  sed -e "$mode" -e 's|^mipmaps/generate=.*|mipmaps/generate=true|' \
    -e 's|^detect_3d/compress_to=.*|detect_3d/compress_to=0|' "$f" > "$f.tmp"
  if cmp -s "$f" "$f.tmp"; then rm "$f.tmp"; else mv "$f.tmp" "$f"; changed=1; fi
done
if [ "$changed" -eq 1 ]; then
  "$GODOT" --headless --path . --import
fi
