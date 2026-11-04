#!/usr/bin/env bash
# Exports every preset into builds/ (git-ignored). Needs the 4.7.2 export templates installed.
# GODOT defaults to the binary on PATH; set GODOT=/path/to/Godot to override.
set -euo pipefail
cd "$(dirname "$(realpath "$0")")/.."
[ -f project.godot ] || { echo "not the project folder: $PWD" >&2; exit 1; }
GODOT="${GODOT:-godot}"
rm -rf builds
mkdir -p builds/web builds/macos builds/windows builds/linux
touch builds/.gdignore  # keep Godot from importing the exported files
"$GODOT" --headless --path . --import >/dev/null 2>&1 || { echo "import failed: run $GODOT --headless --path . --import" >&2; exit 1; }
"$GODOT" --headless --path . --export-release "Web" builds/web/index.html
"$GODOT" --headless --path . --export-release "macOS" builds/macos/TheCondo.zip
"$GODOT" --headless --path . --export-release "Windows Desktop" builds/windows/TheCondo.exe
"$GODOT" --headless --path . --export-release "Linux" builds/linux/TheCondo.x86_64
ls -l builds/*/
