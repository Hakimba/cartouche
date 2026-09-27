#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Measures a debug build on the device connected through adb, at several library sizes: the
# user's own library ("real") and made-up ones of N games (`--demo-games`). For each size: cold
# starts (start to carousel shown, library read and sent, title indexing, first frames), then the
# carousel held scrolling and changing platform for 30 s each (frame times), the app's memory and
# the save of the selection. Run it after `dev/build.sh --install`.
#
# Prints one line per measurement; with --record FILE, also appends each one to FILE as a JSON
# record: {"date", "commit", "build", "device", "android", "scenario", "games", "metric",
# "value", "unit", "run"}.
#
# Usage: dev/bench.sh [--record FILE] [--starts N] [SIZE...]   (sizes: real or a number;
#        default: real 150 1000 5000)
set -euo pipefail
# Decimal points, whatever the machine's language.
export LC_ALL=C
cd "$(dirname "$0")/.."
adb="${ANDROID_HOME:?ANDROID_HOME is not set}/platform-tools/adb"
record=""
starts=3
sizes=()
while [ $# -gt 0 ]; do
  case "$1" in
    --record) record="$2"; shift 2 ;;
    --starts) starts="$2"; shift 2 ;;
    real | [0-9]*) sizes+=("$1"); shift ;;
    *) echo "usage: dev/bench.sh [--record FILE] [--starts N] [real|N...]" >&2; exit 2 ;;
  esac
done
[ ${#sizes[@]} -gt 0 ] || sizes=(real 150 1000 5000)

date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
commit=$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- app kotlin || echo "+changes")
device=$("$adb" shell getprop ro.product.model | tr -d '\r')
android=$("$adb" shell getprop ro.build.version.release | tr -d '\r')

# emit SCENARIO GAMES METRIC VALUE UNIT RUN
emit() {
  printf '%-12s %-5s %-24s %10s %s (run %s)\n' "$1" "$2" "$3" "$4" "$5" "$6"
  [ -z "$record" ] || printf '{"date":"%s","commit":"%s","build":"debug","device":"%s","android":"%s","scenario":"%s","games":"%s","metric":"%s","value":%s,"unit":"%s","run":%s}\n' \
    "$date" "$commit" "$device" "$android" "$1" "$2" "$3" "${4:-null}" "$5" "$6" >> "$record"
}

# start ARGUMENTS: a cold start, the launch arguments joined by commas.
start() {
  "$adb" shell am force-stop app.cartouche
  "$adb" logcat -c
  "$adb" shell am start -n app.cartouche/com.godot.game.GodotAppLauncher ${1:+--esa arguments "$1"} > /dev/null
}

# wait_for PATTERN SECONDS: until the log has a line matching PATTERN.
wait_for() {
  local waited=0
  until "$adb" logcat -d | grep -qE "$1"; do
    sleep 0.5
    waited=$((waited + 1))
    [ "$waited" -lt $(($2 * 2)) ] || { echo "error: no \"$1\" within $2 s" >&2; exit 1; }
  done
}

# first NUMBER-PATTERN: the first number the log shows in a line matching the extended regex.
first() { "$adb" logcat -d | grep -oE "$1" | head -1 | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1; }

for size in "${sizes[@]}"; do
  demo=$([ "$size" = real ] || echo "--demo-games=$size")
  args=${demo:+$demo,}
  for run in $(seq "$starts"); do
    start "$demo"
    wait_for "carousel: shown" 30
    sleep 3
    # The device's own clock: from the start request to the first frame showing the carousel.
    shown=$("$adb" logcat -d -v epoch | awk '/START u0 .*app.cartouche/ && !s { s = $1 }
      /carousel: shown/ && !e { e = $1 } END { printf "%d", (e - s) * 1000 }')
    emit start "$size" start_to_shown "$shown" ms "$run"
    emit library "$size" library_answer "$(first '#1 answered in [0-9]+ ms')" ms "$run"
    emit library "$size" library_json_sent "$(first 'characters of JSON in [0-9]+ ms')" ms "$run"
    emit library "$size" library_read_by_godot "$(first 'games read from [0-9]+ characters in [0-9.]+ ms')" ms "$run"
    emit library "$size" library_json_characters "$(first '[0-9]+ characters of JSON')" characters "$run"
    # The first frames showing the shelf: the slowest of them.
    worst=$("$adb" logcat -d | grep -oE "first frames: [0-9., ]+ ms" | head -1 | grep -oE "[0-9]+\.[0-9]+" | sort -n | tail -1)
    emit first_frames "$size" first_frames_worst "$worst" ms "$run"
    indexed=$(first 'titles: ps2: [0-9]+ indexed in [0-9]+ ms' || true)
    [ -z "$indexed" ] || emit titles "$size" title_index_ps2 "$indexed" ms "$run"
  done
  for scenario in scroll switch; do
    start "$args--bench=$scenario"
    wait_for "bench: $scenario:" 60
    line=$("$adb" logcat -d | grep -oE "bench: $scenario: .*" | head -1)
    for key in fps worst_ms p95_ms slow_frames steps; do
      value=$(echo "$line" | grep -oE "$key=[0-9.]+" | cut -d= -f2)
      unit=$(case "$key" in fps) echo fps ;; *_ms) echo ms ;; *) echo count ;; esac)
      emit "$scenario" "$size" "$key" "$value" "$unit" 1
    done
    if [ "$scenario" = scroll ]; then
      emit memory "$size" memory_pss "$("$adb" shell dumpsys meminfo app.cartouche | awk '/TOTAL PSS:/ { print $3; exit }')" kB 1
      # Leaving the app (here for the system settings) saves the selection.
      "$adb" shell am start -a android.settings.SETTINGS > /dev/null
      wait_for "selection: saved" 10
      emit selection "$size" selection_saved "$(first 'selection: saved .* in [0-9]+ ms')" ms 1
    fi
  done
done
"$adb" shell am force-stop app.cartouche
