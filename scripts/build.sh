#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the Kotlin modules (with tests and lint), exports the debug APK and, with --install,
# installs and starts it on the device connected through adb.
#
# Needs the tools listed in README.md: JAVA_HOME, ANDROID_HOME, Godot on PATH or in GODOT, and gdlint (gdtoolkit 4).
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  "" | --install) ;;
  *) echo "usage: scripts/build.sh [--install]" >&2; exit 2 ;;
esac

GODOT="${GODOT:-godot}"
APK=build/cartouche-debug.apk

fail() { echo "error: $*" >&2; exit 1; }
command -v "$GODOT" > /dev/null || fail "Godot not found: put it on PATH or set GODOT"
[ -n "${ANDROID_HOME:-}" ] || fail "ANDROID_HOME is not set"
java_version=$("${JAVA_HOME:?JAVA_HOME is not set}/bin/java" -version 2>&1 | head -1)
[[ $java_version =~ \"17[.\"] ]] || fail "JDK 17 required, JAVA_HOME points to: $java_version"

# Every step is bounded, a hung one stopped: `timeout` is GNU coreutils (`gtimeout` on macOS with
# Homebrew); without either, the runs are not bounded.
bounded=$(command -v timeout || command -v gtimeout || true)
mkdir -p build
python3 scripts/check_docs.py || fail "the docs cite a path, name or heading the code no longer has"
# GDScript style, as gdlintrc sets it (member order, names, line length); the generated tokens are checked by
# their generator instead.
command -v gdlint > /dev/null || fail "gdlint not found: pip install --user \"gdtoolkit==4.*\""
scripts=$(git ls-files -co --exclude-standard 'app/*.gd' ':!app/addons/*' ':!app/android/*' ':!app/studio/studio_tokens.gd')
echo "$scripts" | xargs gdlint > build/gdlint.log 2>&1 \
  || { grep -v "^Success" build/gdlint.log | tail -20; fail "GDScript style (full log: build/gdlint.log)"; }
spread=$(echo "$scripts" | xargs grep -lzP '\n\n\n\n' || true)
[ -z "$spread" ] || fail "more than two blank lines in a row in: $spread"
# A class the engine template leaves out exists on the desktop and not in an APK built with that template.
left_out=$(grep -o '"[A-Z][A-Za-z0-9]*"' tools/godot/cartouche.gdbuild | tr -d '"' | paste -sd'|' -)
named=$(git ls-files -co --exclude-standard 'app/*.gd' 'app/*.tscn' 'app/*.tres' 'app/*.res' ':!app/addons/gdUnit4/*' ':!app/test/*' \
  | xargs grep -lawE "$left_out" || true)
[ -z "$named" ] || fail "a class left out of the engine template (tools/godot/cartouche.gdbuild) is named in: $named"
# With ubershaders off, the engine template compiles ahead only the pipelines app/project.godot lists.
python3 scripts/specialized_pipelines.py listed > /dev/null || fail "the pipeline list of app/project.godot"
python3 scripts/plinths.py check || fail "a console's plinth picture"
status=0
(cd kotlin && ${bounded:+"$bounded" -k 10 1800} ./gradlew --quiet ktlintCheck :core:test :android:testDebugUnitTest :android:lintDebug \
  :android:assemble) || status=$?
[ "$status" -ne 124 ] || fail "the Kotlin build and tests did not finish within 1800 s"
[ "$status" -eq 0 ] || exit "$status"
# The gate before an APK runs everything, the asset checks included.
GODOT="$GODOT" scripts/test_godot.sh res://test
GODOT="$GODOT" bash scripts/check_release.sh
# The export packs scripts that fail to compile: run the project briefly to catch them first, in a user data folder
# of its own (Godot keeps user:// under XDG_DATA_HOME) so a developer's files are neither read nor written.
rm -rf build/run-data
XDG_DATA_HOME="$PWD/build/run-data" ${bounded:+"$bounded" -k 10 120} "$GODOT" --headless --path app --quit-after 30 \
  > build/run.log 2>&1 || status=$?
[ "$status" -ne 124 ] || fail "the project did not stop within 120 s (full log: build/run.log)"
[ "$status" -eq 0 ] || fail "the project did not run (exit $status, full log: build/run.log)"
! grep -E "SCRIPT ERROR|Parse Error|Failed to load script" build/run.log || fail "GDScript errors (full log: build/run.log)"
GODOT="$GODOT" scripts/export_apk.sh debug "$APK"

if [ "${1:-}" = "--install" ]; then
  adb="$ANDROID_HOME/platform-tools/adb"
  "$adb" install -r "$APK"
  "$adb" shell am start -n app.cartouche/com.godot.game.GodotAppLauncher > /dev/null
  echo "Installed and started. Logs: $adb logcat -s godot Cartouche"
fi
