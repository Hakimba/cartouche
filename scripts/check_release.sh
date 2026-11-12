#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
pack_dir=$(mktemp -d)
trap 'rm -rf "$pack_dir"' EXIT
if ! timeout 900s "$GODOT" --headless --path app --export-pack Android "$pack_dir/release.pck" > "$pack_dir/export.log" 2>&1; then
  cat "$pack_dir/export.log"
  exit 1
fi
python3 - "$pack_dir/release.pck" <<'CHECK'
import struct
import sys
from pathlib import Path

with Path(sys.argv[1]).open('rb') as pack:
    def number(fmt):
        return struct.unpack(fmt, pack.read(struct.calcsize(fmt)))[0]
    if pack.read(4) != b'GDPC':
        raise SystemExit('invalid release pack')
    version = number('<I')
    pack.read(12)
    flags = number('<I') if version >= 2 else 0
    if flags & 1:
        raise SystemExit('cannot inspect an encrypted release pack')
    if version >= 2:
        number('<Q')
    if version >= 3:
        directory = number('<Q')
        pack.seek(directory)
    else:
        pack.read(64)
    count = number('<I')
    paths = []
    for _ in range(count):
        path = pack.read(number('<I')).rstrip(b'\0').decode('utf-8')
        paths.append(path)
        pack.read(32)
        if version >= 2:
            pack.read(4)
    dev_only = ('dev/start_trace.gd', 'dev/carousel_bench.gd', 'dev/frame_shots.gd')
    leaked = [path for path in paths if path.removeprefix('res://').startswith('dev/bridge/') or path.removeprefix('res://') in dev_only]
    if leaked:
        raise SystemExit('bridge files in release pack: ' + ', '.join(leaked))
    if not paths:
        raise SystemExit('release pack is empty')
    print(f'Release pack: {count} paths, no bridge or dev files')
CHECK
# A script the pack keeps may still need a file it leaves out (a preload of dev/bridge/): start the pack and refuse
# any script error, in a user data folder of its own (Godot keeps user:// under XDG_DATA_HOME) so a developer's files
# are neither read nor written. Started means quit on its own within the bound with the carousel restored on a game
# (a trace the debug engine running the pack prints), never just the absence of an error.
status=0
started=$(XDG_DATA_HOME="$pack_dir/data" timeout 120s "$GODOT" --headless --main-pack "$pack_dir/release.pck" --quit-after 240 2>&1) \
  || status=$?
if grep -q 'SCRIPT ERROR' <<<"$started"; then
  grep -A1 'SCRIPT ERROR' <<<"$started"
  exit 1
fi
if [ "$status" -ne 0 ] || ! grep -q '^Cartouche carousel: restored ' <<<"$started"; then
  tail -n 20 <<<"$started"
  echo "Release pack did not start: exit $status, carousel restored: $(grep -c '^Cartouche carousel: restored ' <<<"$started")"
  exit 1
fi
echo 'Release pack starts, its carousel shown, without a script error'
