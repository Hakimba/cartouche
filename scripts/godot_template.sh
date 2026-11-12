#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# The Android export template Cartouche is exported with: Godot at a fixed tag, the patches of
# tools/godot/patches and the options of tools/godot/, built once and kept in
# ~/.cache/cartouche/godot/FINGERPRINT/android_source.zip. Nothing calls `build`: scripts/export_apk.sh
# only asks for `zip`, and exports with the official template when there is none.
#
# Usage: scripts/godot_template.sh fingerprint   prints the fingerprint of the sources and options
#        scripts/godot_template.sh zip           prints the cached zip's path; fails when it is not built
#        scripts/godot_template.sh build         builds it (about an hour), then prints its path
#
# `build` needs scons, python3, git, JAVA_HOME (JDK 17) and ANDROID_HOME holding the NDK named below.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_TAG=4.7.2-stable
GODOT_COMMIT=ed1daf0bf001b61586d9930840f2f1394092c079
# The NDK this tag builds with (platform/android/detect.py, get_ndk_version).
NDK_VERSION=29.0.14206865
cache="${XDG_CACHE_HOME:-$HOME/.cache}/cartouche/godot"

fail() { echo "error: $*" >&2; exit 1; }

# Everything the binary depends on: a change of any of them is another template.
fingerprint() {
  {
    echo "$GODOT_COMMIT $NDK_VERSION"
    sha256sum tools/godot/scons_options.txt tools/godot/cartouche.gdbuild tools/godot/patches/*.diff
  } | sha256sum | cut -c1-16
}

build() {
  local source="$cache/source" out="$cache/$1" bounded java_version options patch zip library
  command -v scons > /dev/null || fail "scons not found: python3 -m pip install --user scons"
  [ -d "${ANDROID_HOME:?ANDROID_HOME is not set}/ndk/$NDK_VERSION" ] \
    || fail "NDK $NDK_VERSION not found: sdkmanager \"ndk;$NDK_VERSION\""
  java_version=$("${JAVA_HOME:?JAVA_HOME is not set}/bin/java" -version 2>&1 | head -1)
  [[ $java_version =~ \"17[.\"] ]] || fail "JDK 17 required, JAVA_HOME points to: $java_version"
  bounded=$(command -v timeout || command -v gtimeout || true)

  mkdir -p "$cache"
  [ -d "$source/.git" ] \
    || git clone --quiet --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$source"
  [ "$(git -C "$source" rev-parse HEAD)" = "$GODOT_COMMIT" ] || fail "$source is not at $GODOT_TAG ($GODOT_COMMIT)"
  # Back to the tag: earlier patches go, the objects already compiled (ignored files) stay.
  git -C "$source" reset --quiet --hard "$GODOT_COMMIT"
  git -C "$source" clean --quiet -fd
  for patch in tools/godot/patches/*.diff; do
    git -C "$source" apply --check "$PWD/$patch" || fail "$patch no longer applies on $GODOT_TAG"
    git -C "$source" apply "$PWD/$patch"
  done
  # Without Swappy the build stops (swappy=yes), and a template without it paces frames badly.
  [ -f "$source/thirdparty/swappy-frame-pacing/arm64-v8a/libswappy_static.a" ] \
    || (cd "$source" && python3 misc/scripts/install_swappy_android.py)

  mapfile -t options < <(grep -v '^#' tools/godot/scons_options.txt | grep .)
  options+=("build_profile=$PWD/tools/godot/cartouche.gdbuild" "-j$(nproc)")
  rm -f "$source/bin/android_source.zip"
  # Release first: the Gradle step of the second run packs both libraries into one zip.
  (cd "$source" && ${bounded:+"$bounded" -k 10 7200} scons "${options[@]}" target=template_release) \
    || fail "the release library did not build"
  (cd "$source" && ${bounded:+"$bounded" -k 10 7200} scons "${options[@]}" target=template_debug generate_android_binaries=yes) \
    || fail "the debug library did not build"
  zip="$source/bin/android_source.zip"
  [ -f "$zip" ] || fail "no $zip: the Gradle step failed; see ./gradlew generateGodotTemplates in $source/platform/android/java"
  for library in libs/release/godot-lib.template_release.aar libs/debug/godot-lib.template_debug.aar; do
    unzip -l "$zip" "$library" > /dev/null || fail "$zip holds no $library"
  done
  mkdir -p "$out"
  cp "$zip" "$out/android_source.zip.part"
  mv "$out/android_source.zip.part" "$out/android_source.zip"
}

case "${1:-}" in
  fingerprint) fingerprint ;;
  zip)
    zip="$cache/$(fingerprint)/android_source.zip"
    [ -f "$zip" ] || exit 1
    echo "$zip"
    ;;
  build)
    fingerprint=$(fingerprint)
    [ -f "$cache/$fingerprint/android_source.zip" ] || build "$fingerprint"
    echo "fingerprint: $fingerprint"
    echo "$cache/$fingerprint/android_source.zip"
    ;;
  *) echo "usage: scripts/godot_template.sh fingerprint|zip|build" >&2; exit 2 ;;
esac
