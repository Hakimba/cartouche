#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript tests of app/test with GdUnit4, headless; with arguments, only the test
# folders or files they name (`scripts/test_godot.sh res://test/screens`). GdUnit4 (MIT) is not part of
# the repository: the pinned release is downloaded once into build/, checked, and linked into
# app/addons/gdUnit4 (ignored by git, left out of exports).
#
# Usage: scripts/test_godot.sh [--changed] [res://test/PATH...]   Needs Godot on PATH or in GODOT; GODOT_TESTS_S bounds
# each suite file (900 s by default); GODOT_TESTS_JOBS sets how many Godot processes run at once (4 by default).
# The asset checks (res://test/assets: every shipped console and medium) run when a path names them (`res://test` does, and
# so does scripts/build.sh, the gate before an APK), and, with no path or with --changed, when something they check changed
# since main (app/carousel/consoles, media, models, launch, shelf_row.gd, app/data). With no path nothing else is left out.
# --changed runs only the suites of what changed since main: a leaf folder of app/ with its own test folder runs that
# folder; anything else that GDScript depends on (the carousel's own scripts, screens, adapters, studio, data, locale,
# fonts, the test helpers) runs everything; a change under kotlin/ selects nothing (those tests are Gradle's).
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
assets=res://test/assets
# What changed since main, committed or not.
changed() { { git diff --name-only "$(git merge-base HEAD main 2> /dev/null || echo HEAD)"; git ls-files -o --exclude-standard; } | sort -u; }
# Whether a change touches what the asset checks look at.
assets_changed() {
  changed | grep -qE '^app/(carousel/(consoles|media|models|launch)/|carousel/shelf_row\.gd|data/|test/assets/)'
}
# The suites a change asks for. A leaf folder with its own test folder runs it; what many things depend on runs everything.
suites_changed() {
  local path dir
  changed | grep -q '^kotlin/' && echo "kotlin changed: its tests are Gradle's, none selected" >&2
  while IFS= read -r path; do
    case $path in
      app/test/*_test.gd) echo "res://${path#app/}" ;;
      app/test/*) echo res://test ;;
      app/*/*/*)
        dir=$(dirname "${path#app/}")
        if [ -d "app/test/$dir" ]; then echo "res://test/$dir"; else echo res://test; fi ;;
      app/*) echo res://test ;;
    esac
  done < <(changed) | sort -u
}
selection=("$@")
if [ "${1:-}" = "--changed" ]; then
  mapfile -t selection < <(suites_changed)
  [ "${#selection[@]}" -gt 0 ] || { echo "no change that a GDScript suite covers since main"; exit 0; }
  # Everything asked for: the folders add nothing.
  if printf '%s\n' "${selection[@]}" | grep -qx res://test; then selection=(res://test); fi
  echo "suites: ${selection[*]}"
fi
files=()
for path in "${selection[@]:-res://test}"; do
  while IFS= read -r file; do files+=("$file"); done < <(find "app/${path#res://}" -name '*_test.gd')
done
mapfile -t files < <(printf '%s\n' "${files[@]}" | sort -u)
# With no path, or with --changed asking for everything, the asset checks wait for a change of what they check.
if [ "${#selection[@]}" -eq 0 ] || { [ "${1:-}" = "--changed" ] && [ "${selection[0]}" = res://test ]; }; then
  if ! assets_changed; then
    kept=()
    for file in "${files[@]}"; do [[ $file == app/test/assets/* ]] || kept+=("$file"); done
    files=("${kept[@]}")
    echo "asset checks skipped: nothing they check changed (scripts/test_godot.sh $assets runs them)"
  fi
fi
[ "${#files[@]}" -gt 0 ] || fail "no test under: ${selection[*]:-res://test}"

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
# The files that build no scene (no node added, no carousel, no wait) share one process: an engine start costs more than
# they run. Each of the others runs alone.
SCENE='add_child|instantiate|\.tscn|fresh_carousel|new_carousel|shown_carousel|auto_free|get_tree|await|\.shown\(|SceneTree|Input\.|NewDevice|past_first_launch'
run_job() {
  local name=$1 list=$2 args=() file
  IFS=, read -ra paths <<< "$list"
  for file in "${paths[@]}"; do args+=(-a "res://${file#app/}"); done
  mkdir -p "$data/$name"
  # Each run its own user:// (Godot keeps it under XDG_DATA_HOME): runs going at once never share their files.
  # Every frame advances the game by 1/60 s however long it takes: tweens, timers and presses land on the same frames
  # whatever the machine's load.
  XDG_DATA_HOME="$data/$name" ${bounded:+"$bounded" -k 10 "${GODOT_TESTS_S:-900}"} "$GODOT" --headless --fixed-fps 60 --path app \
    -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "${args[@]}" -rd "../build/gdunit-reports/$name" -c \
    > "build/test-godot/$name.log" 2>&1 || { echo "$name exit $?" >> build/test-godot/failed; true; }
}
export -f run_job
pure=()
jobs_list=$(mktemp)
for file in "${files[@]}"; do
  if grep -qE "$SCENE" "$file"; then echo "$(wc -c < "$file") $(suite "$file") $file" >> "$jobs_list"; else pure+=("$file"); fi
done
if [ "${#pure[@]}" -gt 0 ]; then
  echo "$(cat "${pure[@]}" | wc -c) pure $(IFS=,; echo "${pure[*]}")" >> "$jobs_list"
fi
sort -rn "$jobs_list" | cut -d' ' -f2- | xargs -P "$jobs" -L 1 bash -c 'run_job "$0" "$1"'
rm -f "$jobs_list"
# A suite that ends without its summary (a crash, an error before the first test) ran nothing it can report.
for log in build/test-godot/*.log; do
  grep -q "Overall Summary" "$log" || echo "${log#build/test-godot/} printed no summary" >> build/test-godot/failed
done
# The files sharing one process print one summary: each must still appear in its report.
for file in "${pure[@]}"; do
  grep -qF "res://${file#app/}" build/test-godot/pure.log || echo "$file is missing from the shared run (pure.log)" >> build/test-godot/failed
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
