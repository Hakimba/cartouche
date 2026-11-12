#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Exports the APK: with the template scripts/godot_template.sh built, when there is one for the
# current sources and options, else with Godot's official template. It never builds the engine.
#
# Usage: scripts/export_apk.sh debug|release APK   (APK: a path from the repository's root)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
case "${1:-}" in
  debug | release) ;;
  *) echo "usage: scripts/export_apk.sh debug|release APK" >&2; exit 2 ;;
esac
kind=$1 apk=${2:?usage: scripts/export_apk.sh debug|release APK}
presets=app/export_presets.cfg
option=gradle_build/android_source_template

fail() { echo "error: $*" >&2; exit 1; }
! grep -q "^$option=" "$presets" || fail "$presets names a template (an export was killed?): git checkout $presets"

mkdir -p build app/android "$(dirname "$apk")"
template=official
if zip=$(scripts/godot_template.sh zip); then
  template=$(scripts/godot_template.sh fingerprint)
  echo "Engine template: $zip"
  # The preset cannot hold a path that differs on every machine: it names the zip for this export only.
  cp "$presets" build/export_presets.cfg.kept
  trap 'cp build/export_presets.cfg.kept "$presets"' EXIT
  sed -i.tmp "s|^gradle_build/use_gradle_build=true\$|&\n$option=\"$zip\"|" "$presets" && rm -f "$presets.tmp"
  grep -q "^$option=" "$presets" || fail "$presets has no gradle_build/use_gradle_build=true line"
  # R8 is an option of this template's Gradle build, read from the environment; it applies to release builds.
  export ORG_GRADLE_PROJECT_enable_minification=true
else
  echo "Engine template: Godot's official one (scripts/godot_template.sh build makes Cartouche's)"
fi
# Installing a template overwrites files and deletes none: another template starts from an empty folder.
mark=app/android/.cartouche_template
[ "$(cat "$mark" 2> /dev/null)" = "$template" ] || rm -rf app/android/build
echo "$template" > "$mark"
"$GODOT" --headless --path app --install-android-build-template "--export-$kind" Android "../$apk" > build/export.log 2>&1 \
  || { tail -40 build/export.log; fail "export failed (full log: build/export.log)"; }
echo "APK: $apk ($(du -h "$apk" | cut -f1))"
