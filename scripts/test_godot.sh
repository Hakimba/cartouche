#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript tests of app/test with GdUnit4, headless; with arguments, only the test
# folders or files they name (`scripts/test_godot.sh res://test/screens`). GdUnit4 (MIT) is not part of
# the repository: the pinned release is downloaded once into build/, checked, and linked into
# app/addons/gdUnit4 (ignored by git, left out of exports).
#
# Usage: scripts/test_godot.sh [res://test/PATH...]   Needs Godot on PATH or in GODOT; GODOT_TESTS_S bounds
# each suite file (900 s by default); GODOT_TESTS_JOBS sets how many Godot processes run at once (4 by default).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VERSION=6.2.1
SHA256=ffb48847c46f386bf0c7a716fd68c6dace7d67730775cf7f748adce8ef3ed794
archive="build/gdunit4-$VERSION.zip"

fail() { echo "error: $*" >&2; exit 1; }
mkdir -p build
if [ ! -d "build/gdUnit4-$VERSION" ]; then
  curl -sSfL -o "$archive" "https://github.com/MikeSchulze/gdUnit4/archive/refs/tags/v$VERSION.zip"
  echo "$SHA256  $archive" | sha256sum -c --quiet - || fail "unexpected GdUnit4 archive"
  unzip -q -o "$archive" -d build
fi
ln -sfn "../../build/gdUnit4-$VERSION/addons/gdUnit4" app/addons/gdUnit4
# A clean clone has no import cache yet: GdUnit4's classes must be registered first.
"$GODOT" --headless --path app --import > build/test-import.log 2>&1 || { tail -20 build/test-import.log; fail "import failed"; }

# One Godot process per test file, GODOT_TESTS_JOBS at a time, the largest files first (size stands for time):
# a suite never sees what another left in the engine, and the order of the suites does not matter.
jobs=${GODOT_TESTS_JOBS:-4}
files=()
for path in "${@:-res://test}"; do
  while IFS= read -r file; do files+=("$file"); done < <(find "app/${path#res://}" -name '*_test.gd')
done
[ "${#files[@]}" -gt 0 ] || fail "no test under: ${*:-res://test}"

# A hung test must not hold the run: a suite file takes a few minutes, GODOT_TESTS_S at most.
# `timeout` is GNU coreutils (`gtimeout` on macOS with Homebrew); without either, the run is not bounded.
bounded=$(command -v timeout || command -v gtimeout || true)
data=$(mktemp -d)
trap 'rm -rf "$data"' EXIT
rm -rf build/test-godot build/gdunit-reports
mkdir -p build/test-godot
export GODOT bounded data
# A suite's logs and reports are named after its path below app/test: two suites may share a file name.
suite() { local name=${1#app/test/}; name=${name%.gd}; echo "${name//\//-}"; }
run_one() {
  local name; name=$(suite "$1")
  mkdir -p "$data/$name"
  # Each run its own user:// (Godot keeps it under XDG_DATA_HOME): runs going at once never share their files.
  # Every frame advances the game by 1/60 s however long it takes: tweens, timers and presses land on the same frames
  # whatever the machine's load.
  XDG_DATA_HOME="$data/$name" ${bounded:+"$bounded" -k 10 "${GODOT_TESTS_S:-900}"} "$GODOT" --headless --fixed-fps 60 --path app \
    -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a "res://${1#app/}" -rd "../build/gdunit-reports/$name" -c \
    > "build/test-godot/$name.log" 2>&1 || { echo "$1 exit $?" >> build/test-godot/failed; true; }
}
export -f suite run_one
for file in "${files[@]}"; do echo "$(wc -c < "$file") $file"; done | sort -rn | cut -d' ' -f2 | xargs -P "$jobs" -I{} bash -c 'run_one {}'
# A suite that ends without its summary (a crash, an error before the first test) ran nothing it can report.
for file in "${files[@]}"; do
  grep -q "Overall Summary" "build/test-godot/$(suite "$file").log" || echo "$file printed no summary" >> build/test-godot/failed
done
sed -E 's/\x1b\[[0-9;]*m//g' build/test-godot/*.log > build/test-godot.log
if [ -e build/test-godot/failed ]; then
  grep -E " FAILED" build/test-godot.log | head -40 || true
  cat build/test-godot/failed
  fail "GDScript tests failed, ended without their summary, or did not finish within ${GODOT_TESTS_S:-900} s per suite (full log: build/test-godot.log)"
fi
awk -F'[ |]+' '
  /Overall Summary/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) total[$(i + 1)] += $i }
  END { printf "Overall Summary: %d test cases | %d errors | %d failures | %d skipped | %d orphans\n", total["test"], total["errors"], total["failures"], total["skipped"], total["orphans"] }' build/test-godot.log
