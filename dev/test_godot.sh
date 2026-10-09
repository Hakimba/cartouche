#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript tests of app/test with GdUnit4, headless; with arguments, only the test
# folders or files they name (`dev/test_godot.sh res://test/screens`). GdUnit4 (MIT) is not part of
# the repository: the pinned release is downloaded once into build/, checked, and linked into
# app/addons/gdUnit4 (ignored by git, left out of exports).
#
# Usage: dev/test_godot.sh [res://test/PATH...]   Needs Godot on PATH or in GODOT; GODOT_TESTS_S bounds
# the run (900 s by default).
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
targets=()
for path in "${@:-res://test}"; do targets+=(-a "$path"); done
# A clean clone has no import cache yet: GdUnit4's classes must be registered first.
"$GODOT" --headless --path app --import > build/test-import.log 2>&1 || { tail -20 build/test-import.log; fail "import failed"; }
# A hung test must not hold the run: the whole suite takes a few minutes, GODOT_TESTS_S at most.
# `timeout` is GNU coreutils (`gtimeout` on macOS with Homebrew); without either, the run is not bounded.
bounded=$(command -v timeout || command -v gtimeout || true)
status=0
${bounded:+"$bounded" -k 10 "${GODOT_TESTS_S:-900}"} "$GODOT" --headless --path app -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode "${targets[@]}" -rd ../build/gdunit-reports -c > build/test-godot.log 2>&1 || status=$?
[ "$status" -ne 124 ] || fail "the tests did not finish within ${GODOT_TESTS_S:-900} s: one hangs? (full log: build/test-godot.log)"
[ "$status" -eq 0 ] \
  || { grep -E "FAILED|failed|Error|ERROR" build/test-godot.log | head -40; fail "GDScript tests failed (full log: build/test-godot.log)"; }
grep -E "Overall Summary|Executed test" build/test-godot.log | tail -3
