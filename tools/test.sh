#!/usr/bin/env bash
# Imports the project (needed on a fresh checkout) and runs every test. Exit code = test result.
# GODOT defaults to the binary on PATH; set GODOT=/path/to/Godot to override.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --script res://tests/run_tests.gd -- "$@"
