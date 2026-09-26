#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Builds the Kotlin modules (with tests and lint), exports the debug APK and, with --install,
# installs and starts it on the device connected through adb.
#
# Needs the tools listed in README.md: JAVA_HOME, ANDROID_HOME, and Godot on PATH or in GODOT.
set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
  "" | --install) ;;
  *) echo "usage: dev/build.sh [--install]" >&2; exit 2 ;;
esac

GODOT="${GODOT:-godot}"
APK=build/cartouche-debug.apk

fail() { echo "error: $*" >&2; exit 1; }
command -v "$GODOT" > /dev/null || fail "Godot not found: put it on PATH or set GODOT"
[ -n "${ANDROID_HOME:-}" ] || fail "ANDROID_HOME is not set"
java_version=$("${JAVA_HOME:?JAVA_HOME is not set}/bin/java" -version 2>&1 | head -1)
[[ $java_version =~ \"17[.\"] ]] || fail "JDK 17 required, JAVA_HOME points to: $java_version"

(cd kotlin && ./gradlew --quiet ktlintCheck :core:test :android:testDebugUnitTest :android:assemble)
mkdir -p build
# A clean clone has no import cache yet: global class names must be registered before exporting.
"$GODOT" --headless --path app --import > build/import.log 2>&1 || { tail -20 build/import.log; fail "import failed"; }
"$GODOT" --headless --path app --install-android-build-template --export-debug Android "../$APK" > build/export.log 2>&1 \
  || { tail -40 build/export.log; fail "export failed (full log: build/export.log)"; }
echo "APK: $APK ($(du -h "$APK" | cut -f1))"

if [ "${1:-}" = "--install" ]; then
  adb="$ANDROID_HOME/platform-tools/adb"
  "$adb" install -r "$APK"
  "$adb" shell am start -n app.cartouche/com.godot.game.GodotAppLauncher > /dev/null
  echo "Installed and started. Logs: $adb logcat -s godot Cartouche"
fi
