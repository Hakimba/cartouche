#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Draws the plinth pictures of every console (app/carousel/consoles/<folder>/plinth.png and plinth_2x.png), which
# the "+" and Edit forms show: the app draws them itself, in its own room and light, then quits. Run it after a console's
# model, its pose on the plinth (app/data/turntable.json) or its plinth lights change, then commit the pictures
# and scripts/plinths.py's record (written here). Needs a display.
#
# Usage: scripts/bake_plinths.sh   Needs Godot on PATH or in GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build
data=$(mktemp -d)
trap 'rm -rf "$data"' EXIT
timeout 600 "$GODOT" --headless --path app --import > /dev/null 2>&1 || true
XDG_DATA_HOME="$data" timeout 300 "$GODOT" --path app --resolution 1280x960 -- --welcome=skip --bake-plinths 2>&1 \
  | grep '^plinth picture' | tee build/bake_plinths.log
[ -s build/bake_plinths.log ] && ! grep -q 'not written' build/bake_plinths.log || { echo "error: a picture was not written" >&2; exit 1; }
timeout 600 "$GODOT" --headless --path app --import > /dev/null 2>&1 || true
python3 scripts/plinths.py write
