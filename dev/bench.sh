#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Measures a debug build on the device connected through adb, at several library sizes: the
# user's own library ("real") and made-up ones of N games (`--demo-games`). For each size: cold
# starts (start to carousel shown, library read and sent, title indexing, first frames), then the
# carousel held scrolling, changing platform and turning the selected game for 30 s each (frame
# times), the app's memory and the save of the selection. With the user's own library, it also
# launches the selected game once (insertion frames, times to check it and to start its emulator,
# time for the emulator to show), then comes back and stops that emulator, just started: nothing
# of the user's is running in it. First, with the user's own library, the art downloaded so far is
# deleted and downloaded again while the carousel scrolls (time for 40 games and for all, frame
# times meanwhile); the starts that follow read it from the device (the selected game's label
# shown, the slowest label read). Run it after `dev/build.sh --install`, with the device online.
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

# emit_bench SCENARIO SIZE KEY...: the KEYs of the scenario's `bench:` line.
emit_bench() {
  local line
  line=$("$adb" logcat -d | grep -oE "bench: $1: .*" | head -1)
  for key in "${@:3}"; do
    emit "$1" "$2" "$key" "$(echo "$line" | grep -oE "$key=[0-9.]+" | cut -d= -f2)" \
      "$(case "$key" in fps) echo fps ;; *_ms) echo ms ;; *) echo count ;; esac)" 1
  done
}

# first NUMBER-PATTERN: the first number the log shows in a line matching the extended regex.
first() { "$adb" logcat -d | grep -oE "$1" | head -1 | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1; }

# seconds_between START-PATTERN END-PATTERN [NTH]: seconds from the first line matching START to
# the NTH (default: first) line matching END, by the device's clock.
seconds_between() {
  "$adb" logcat -d -v epoch | awk -v start="$1" -v end="$2" -v nth="${3:-1}" '
    $0 ~ start && !s { s = $1 } $0 ~ end && s { if (++n == nth) { printf "%.1f", $1 - s; exit } }'
}

for size in "${sizes[@]}"; do
  demo=$([ "$size" = real ] || echo "--demo-games=$size")
  args=${demo:+$demo,}
  if [ "$size" = real ]; then
    # Cartouche's own downloads, downloaded again below: nothing else is deleted.
    "$adb" shell run-as app.cartouche rm -rf files/art
    start "--bench=scrape"
    wait_for "bench: scrape:" 90
    emit_bench scrape "$size" fps worst_ms p95_ms slow_frames steps
    wait_for "art: run over" 300
    emit scrape "$size" scrape_40_games "$(seconds_between 'games to look for' ', stored in ' 40)" s 1
    emit scrape "$size" scrape_all "$(first 'run over: [0-9]+ games in [0-9]+ s')" s 1
    emit scrape "$size" scrape_games "$(first 'run over: [0-9]+ games')" count 1
    emit scrape "$size" labels_stored "$("$adb" logcat -d | grep -c ', stored in ')" count 1
  fi
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
    selected=$(first 'selected label shown [0-9]+ ms after' || true)
    [ -z "$selected" ] || emit art "$size" selected_label_shown "$selected" ms "$run"
    read_worst=$("$adb" logcat -d | grep -oE "art: .* read in [0-9.]+" | grep -oE "[0-9.]+$" | sort -n | tail -1 || true)
    [ -z "$read_worst" ] || emit art "$size" label_read_worst "$read_worst" ms "$run"
  done
  for scenario in scroll switch turn; do
    start "$args--bench=$scenario"
    wait_for "bench: $scenario:" 60
    emit_bench "$scenario" "$size" fps worst_ms p95_ms slow_frames steps
    if [ "$scenario" = scroll ]; then
      emit memory "$size" memory_pss "$("$adb" shell dumpsys meminfo app.cartouche | awk '/TOTAL PSS:/ { print $3; exit }')" kB 1
      # Leaving the app (here for the system settings) saves the selection.
      "$adb" shell am start -a android.settings.SETTINGS > /dev/null
      wait_for "selection: saved" 10
      emit selection "$size" selection_saved "$(first 'selection: saved .* in [0-9]+ ms')" ms 1
    fi
  done
  if [ "$size" = real ]; then
    start "--bench=launch"
    wait_for "bench: launch:" 60
    emit_bench launch "$size" worst_ms p95_ms slow_frames check_ms start_ms
    emulator=$("$adb" logcat -d | grep -oE "launch: .* in [A-Za-z0-9_.]+$" | head -1 | awk '{ print $NF }')
    sleep 5
    # Android's own measure, such as "Displayed com.example/.Main: +1s187ms".
    shown=$("$adb" logcat -d | grep -oE "Displayed $emulator/[^ ]+: \+[0-9s]+ms" | head -1 | grep -oE "[0-9s]+ms$" |
      sed 's/ms$//' | awk -F's' '{ print NF == 2 ? $1 * 1000 + $2 : $1 + 0 }')
    [ -z "$shown" ] || emit launch "$size" emulator_shown "$shown" ms 1
    "$adb" shell am start -n app.cartouche/com.godot.game.GodotAppLauncher > /dev/null
    sleep 2
    [ -z "$emulator" ] || "$adb" shell am force-stop "$emulator"
  fi
done
"$adb" shell am force-stop app.cartouche
