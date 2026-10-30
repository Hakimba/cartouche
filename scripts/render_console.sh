#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Renders the console of app/carousel/consoles/<folder>, or the medium of app/carousel/media/<folder>,
# a medium with the label image given if any, as the carousel lights it, from six points of view, into
# one PNG (relative to the current directory; build/renders/<folder>.png of the repository by
# default), to set the model beside photos of the real one (see scripts/render_console.gd). Needs a
# display; the window never takes the keyboard's focus.
#
# Usage: scripts/render_console.sh <folder> [png] [label image]   Needs Godot on PATH or in GODOT.
set -euo pipefail

[ $# -ge 1 ] || { echo "usage: scripts/render_console.sh <folder> [png] [label image]" >&2; exit 2; }
png=$(realpath -m "${2:-$(dirname "$0")/../build/renders/$1.png}")
label=${3:+$(realpath "$3")}
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p "$(dirname "$png")"
override=app/override.cfg
[ ! -e "$override" ] || { echo "$override exists: remove it first" >&2; exit 2; }
printf '[display]\n\nwindow/size/no_focus=true\n' > "$override"
trap 'rm -f "$override"' EXIT
timeout 300 "$GODOT" --headless --path app --import > /dev/null
timeout 120 "$GODOT" --path app --resolution 640x480 -s "$PWD/scripts/render_console.gd" -- "$1" "$png" ${label:+"$label"} 2>&1 \
  | grep -v '^Cartouche '
