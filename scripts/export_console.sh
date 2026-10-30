#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Exports the console of app/carousel/consoles/<folder>, or the medium of app/carousel/media/<folder>,
# for a three.js viewer: <folder>.glb and <folder>.model.json in out_dir (relative to the current
# directory; build/models of the repository by default), built by Godot, headless, from its own scene
# (see scripts/export_console.gd).
#
# Usage: scripts/export_console.sh <folder> [out_dir]   Needs Godot on PATH or in GODOT.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: scripts/export_console.sh <folder> [out_dir]" >&2; exit 2; }
out_dir=$(realpath -m "${2:-$(dirname "$0")/../build/models}")
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# A clean clone has no import cache yet; the import's errors show, its progress does not.
timeout 300 "$GODOT" --headless --path app --import > /dev/null
timeout 120 "$GODOT" --headless --path app -s "$PWD/scripts/export_console.gd" -- "$1" "$out_dir" 2>&1 \
  | grep -v '^Cartouche '
