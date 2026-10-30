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
    leaked = [path for path in paths if path.removeprefix('res://').startswith('dev/bridge/')]
    if leaked:
        raise SystemExit('bridge files in release pack: ' + ', '.join(leaked))
    if not paths:
        raise SystemExit('release pack is empty')
    print(f'Release pack: {count} paths, no bridge files')
CHECK
