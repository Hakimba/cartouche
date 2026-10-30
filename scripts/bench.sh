#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Measures a debug build on the device connected through adb, at several library sizes: the
# user's own library ("real") and made-up ones of N games (`--demo-games`). For each size: cold
# starts (start to carousel shown, library read and sent, first frames), then the
# carousel held scrolling, going into a console and back out, stepping along the consoles,
# turning the selected game, opening a game's properties and closing them, moving a console round
# the ring that puts them in order, swiping the games by touch, and staying still on the games
# screen and on the consoles screen, for 30 s each (frame times, draw calls, and what each costs
# in energy: the app's processor time a second and, where the GPU tells it, how busy it is and at
# which clock), the app's memory and the save of the selection. With the user's own library, it also
# launches the selected game once (insertion frames, times to check it and to start its emulator,
# time for the emulator to show), then comes back and stops that emulator, just started: nothing
# of the user's is running in it. First, with the user's own library, its art is set aside and the
# scans downloaded again from nothing while the carousel scrolls (time for 40 games and for all,
# frame times meanwhile), then the user's art is put back as it was; the starts that follow read it
# from the device (the selected game's label shown, the slowest label read). Every scenario starts
# on the PS2's games, whichever console the app showed last. Run it after `scripts/build.sh --install`,
# with the device online.
#
# Prints one line per measurement, and keeps each scenario's slow frames in build/bench/SCENARIO-SIZE.log; with
# --record FILE, also appends each one to FILE as a JSON
# record: {"date", "commit", "build", "device", "android", "scenario", "games", "metric",
# "value", "unit", "run", "label"}, the label naming the run (--label, empty by default).
#
# Usage: scripts/bench.sh [--record FILE] [--label TEXT] [--starts N] [SIZE...]   (sizes: real or a number;
#        default: real 150 1000 5000)
set -euo pipefail
# Decimal points, whatever the machine's language.
export LC_ALL=C
cd "$(dirname "$0")/.."
adb="${ANDROID_HOME:?ANDROID_HOME is not set}/platform-tools/adb"
record=""
label=""
starts=3
sizes=()
while [ $# -gt 0 ]; do
  case "$1" in
    --record) record="$2"; shift 2 ;;
    --label) label="$2"; shift 2 ;;
    --starts) starts="$2"; shift 2 ;;
    real | [0-9]*) sizes+=("$1"); shift ;;
    *) echo "usage: scripts/bench.sh [--record FILE] [--label TEXT] [--starts N] [real|N...]" >&2; exit 2 ;;
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
  [ -z "$record" ] || printf '{"date":"%s","commit":"%s","build":"debug","device":"%s","android":"%s","scenario":"%s","games":"%s","metric":"%s","value":%s,"unit":"%s","run":%s,"label":"%s"}\n' \
    "$date" "$commit" "$device" "$android" "$1" "$2" "$3" "${4:-null}" "$5" "$6" "$label" >> "$record"
}

# start [ARGUMENTS]: Cartouche started anew with the comma-separated ARGUMENTS, past its welcome
# screen (which waits for a press).
start() {
  "$adb" shell am force-stop app.cartouche
  "$adb" logcat -c
  "$adb" shell am start -n app.cartouche/com.godot.game.GodotAppLauncher --esa arguments "--welcome=skip${1:+,$1}" > /dev/null
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

# sampled SCENARIO SIZE: from the scenario's start to its `bench:` line, the app's processor time
# a second and, each second, how busy the GPU is and its clock (Adreno's kgsl files; left out
# where the GPU does not tell). A scenario without its line within 120 s fails the run.
gpu=/sys/class/kgsl/kgsl-3d0
sampled() {
  wait_for "bench: $1 started" 60
  local pid ticks started busy=0 clock=0 samples=0 reading deadline=$((SECONDS + 120))
  pid=$("$adb" shell pidof app.cartouche | tr -d '\r')
  ticks=$("$adb" shell cat "/proc/$pid/stat" | awk '{ print $14 + $15 }')
  started=$(date +%s.%N)
  until "$adb" logcat -d | grep -qE "bench: $1:"; do
    [ "$SECONDS" -lt "$deadline" ] || { echo "error: no \"bench: $1:\" within 120 s" >&2; exit 1; }
    reading=$("$adb" shell "cat $gpu/gpu_busy_percentage $gpu/clock_mhz 2> /dev/null" | tr -d '\r %' | paste -sd ' ')
    if [ -n "$reading" ]; then
      busy=$(echo "$busy ${reading% *}" | awk '{ print $1 + $2 }')
      clock=$(echo "$clock ${reading#* }" | awk '{ print $1 + $2 }')
      samples=$((samples + 1))
    fi
    sleep 1
  done
  # Clock ticks of 10 ms (USER_HZ 100).
  emit "$1" "$2" cpu_ms_per_s "$("$adb" shell cat "/proc/$pid/stat" | awk -v t="$ticks" -v s="$started" -v n="$(date +%s.%N)" \
    '{ printf "%.0f", ($14 + $15 - t) * 10 / (n - s) }')" ms 1
  [ "$samples" -eq 0 ] || emit "$1" "$2" gpu_busy "$(awk -v b="$busy" -v n="$samples" 'BEGIN { printf "%.1f", b / n }')" % 1
  [ "$samples" -eq 0 ] || emit "$1" "$2" gpu_mhz "$(awk -v c="$clock" -v n="$samples" 'BEGIN { printf "%.0f", c / n }')" MHz 1
}

# emit_bench SCENARIO SIZE KEY...: the KEYs of the scenario's `bench:` line.
emit_bench() {
  local line
  line=$("$adb" logcat -d | grep -oE "bench: $1: .*" | head -1)
  for key in "${@:3}"; do
    emit "$1" "$2" "$key" "$(echo "$line" | grep -oE "$key=[0-9.]+" | cut -d= -f2)" \
      "$(case "$key" in fps) echo fps ;; *_ms) echo ms ;; *_per_s) echo per_s ;; *) echo count ;; esac)" 1
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

# The user's art, the scans downloaded and the pictures of their own put on labels, is set aside
# while the scans are downloaded again from nothing (set_art_aside), then put back exactly as it was
# (put_art_back), even when the run stops early. Art left aside by an earlier run is the user's: it
# is put back first. Only the folder made for the run, marked, is ever deleted: when the app made
# another one meanwhile, both are the user's and the run stops, for them to be put together by hand.
put_art_back() {
  "$adb" shell am force-stop app.cartouche
  "$adb" shell "run-as app.cartouche sh -c 'if [ -d files/art.aside ]; then [ ! -d files/art ] || [ -f files/art/.bench ] || exit 3;
    rm -rf files/art; mv files/art.aside files/art; fi'" || { echo "files/art and files/art.aside both hold the user's art" >&2; exit 1; }
}
set_art_aside() {
  put_art_back
  "$adb" shell "run-as app.cartouche sh -c 'if [ -d files/art ]; then mv files/art files/art.aside; fi; mkdir files/art; touch files/art/.bench'"
  trap put_art_back EXIT
}

mkdir -p build/bench
for size in "${sizes[@]}"; do
  demo=$([ "$size" = real ] || echo "--demo-games=$size")
  # The same console's games each time, whichever the app showed last.
  args="${demo:+$demo,}--shelf=ps2,"
  if [ "$size" = real ]; then
    set_art_aside
    start "${args}--bench=scrape"
    wait_for "bench: scrape:" 90
    emit_bench scrape "$size" fps worst_ms p95_ms slow_frames steps
    wait_for "art: run over" 300
    emit scrape "$size" scrape_40_games "$(seconds_between 'games to look for' ', stored in ' 40)" s 1
    emit scrape "$size" scrape_all "$(first 'run over: [0-9]+ games in [0-9]+ s')" s 1
    emit scrape "$size" scrape_games "$(first 'run over: [0-9]+ games')" count 1
    emit scrape "$size" labels_stored "$("$adb" logcat -d | grep -c ', stored in ')" count 1
    put_art_back
    trap - EXIT
  fi
  for run in $(seq "$starts"); do
    start "${args%,}"
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
    selected=$(first 'selected label shown [0-9]+ ms after' || true)
    [ -z "$selected" ] || emit art "$size" selected_label_shown "$selected" ms "$run"
    read_worst=$("$adb" logcat -d | grep -oE "art: .* read in [0-9.]+" | grep -oE "[0-9.]+$" | sort -n | tail -1 || true)
    [ -z "$read_worst" ] || emit art "$size" label_read_worst "$read_worst" ms "$run"
  done
  for scenario in scroll enter step turn properties order swipe idle idle_consoles; do
    start "${args}--bench=$scenario"
    sampled "$scenario" "$size"
    # At rest the app draws only when something changes, its loop running 30 times a second: its frame times say
    # nothing, the frames it draws (about none) say whether something keeps changing.
    case "$scenario" in
      idle*) emit_bench "$scenario" "$size" steps draw_calls process_ms draw_cpu_ms drawn_per_s ;;
      *) emit_bench "$scenario" "$size" fps worst_ms p95_ms slow_frames steps draw_calls process_ms draw_cpu_ms ;;
    esac
    # Each slow frame (its processing, drawing, GPU time and the pipelines compiled) between the steps it fell among,
    # to tell what a hitch was.
    "$adb" logcat -d | grep -E "frame: slow frame|carousel: (step|jump|platform) " > "build/bench/$scenario-$size.log" || true
    if [ "$scenario" = scroll ]; then
      emit memory "$size" memory_pss "$("$adb" shell dumpsys meminfo app.cartouche | awk '/TOTAL PSS:/ { print $3; exit }')" kB 1
      # Leaving the app (here for the system settings) saves the selection.
      "$adb" shell am start -a android.settings.SETTINGS > /dev/null
      wait_for "selection: saved" 10
      emit selection "$size" selection_saved "$(first 'selection: saved .* in [0-9]+ ms')" ms 1
    fi
  done
  if [ "$size" = real ]; then
    start "${args}--bench=launch"
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
