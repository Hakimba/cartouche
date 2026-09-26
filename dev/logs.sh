#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Follows a debug build's traces on the device connected through adb: the app's own lines
# (input, focus, lifecycle, plugin traffic, intents), activity starts and crashes.
# --clear drops what the device logged before.
set -euo pipefail
adb="${ANDROID_HOME:?ANDROID_HOME is not set}/platform-tools/adb"
[ "${1:-}" = "--clear" ] && "$adb" logcat -c
exec "$adb" logcat -v time godot:V Cartouche:V ActivityTaskManager:I AndroidRuntime:E '*:S'
