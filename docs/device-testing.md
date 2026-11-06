# Testing on a device

**You are here.** The desktop build proves the screens, but not what only Android does: picking folders, scanning
them, downloading labels, starting an emulator, and the plugin's answers crossing into Godot. This page builds a
debug APK, installs it without touching your own Cartouche and its library, reads its traces, and measures it.
Read [README.md](README.md#build-run-and-test) first for the tools.

You need an Android 11 or later arm64 device with Vulkan, USB debugging turned on, and `adb` seeing it
(`adb devices` lists it as `device`).

## Keep your own library safe

If Cartouche is already installed from a release, a debug build cannot replace it: the two are signed with
different keys, and Android refuses the update. Uninstalling the release to make room deletes its library, its
settings and the label pictures you chose. So install your test build **beside** it, under its own package name.

1. In `app/export_presets.cfg`, change `package/unique_name="app.cartouche"` to a name of your own, such as
   `app.cartouche.test`. Never commit this change.
2. Build, then export the debug APK:

   ```sh
   scripts/build.sh                                        # every check, and the Kotlin plugin
   $GODOT --headless --path app --export-debug Android ../build/cartouche-test.apk
   git checkout app/export_presets.cfg                     # back to the real package name
   ```

   After a change to GDScript only, the export alone is enough.
3. Install and start it:

   ```sh
   adb install -r build/cartouche-test.apk
   adb shell am start -n app.cartouche.test/com.godot.game.GodotAppLauncher
   ```

4. When you are done: `adb uninstall app.cartouche.test`.

On a device with no release of Cartouche, `scripts/build.sh --install` builds, installs and starts the debug
build as `app.cartouche` in one go.

A few more habits keep your own data safe:

- Never delete files under the app's data folder: its art folder holds the label pictures the user chose.
- Try an older or experimental build on a made-up library (`--demo-games=N`, below), not on your own games.
- Put test games in a folder of their own.
- The app comes back where it was left, and A on a game starts its emulator: take a screenshot before pressing A.

## Debug arguments

A debug build reads the debug arguments of [README.md](README.md#diagnostics-and-debug-arguments) from the
`arguments` extra, comma-separated:

```sh
adb shell am start -n app.cartouche.test/com.godot.game.GodotAppLauncher --esa arguments --welcome=skip,--demo-games=500
```

`--demo-games=N` shows a made-up library of N games, kept apart from the real one. `--launch=rehearse` plays a
launch to its end without starting an emulator. `--art-refused`, `--art-slow=MS`, `--launch-slow=MS` and
`--screenscraper=quota` make the network or storage misbehave on purpose.

## Traces

```sh
scripts/logs.sh                  # follows the traces as they come
scripts/logs.sh --clear          # drops what the device logged before
```

It shows the GDScript traces (tag `godot`, written by `Diagnostics.trace`), the plugin's (tag `Cartouche`, written by
`trace` in `Wire.kt`), the activities started (the intent sent to an emulator) and crashes (`AndroidRuntime`).
After walking through the screens, look for SCRIPT ERROR and FATAL in it: there should be none.

Pictures of the screen:

```sh
adb exec-out screencap -p > build/device.png
```

## The debug bridge on a device

The debug bridge ([debug-bridge.md](debug-bridge.md)) dials `127.0.0.1` on the machine it runs on. On a device,
`adb reverse tcp:5201 tcp:5201` forwards that address to a client on your computer; start the build with `--bridge`
in its arguments. This path is not covered by the tests yet: try it on a demo library first.

## Benchmarks

`scripts/bench.sh` measures the debug build installed as `app.cartouche`: cold starts, then each scenario of
`CarouselBench` (`app/dev/carousel_bench.gd`) for a fixed time, at several library sizes. Run it only when your
change touches something measured: the scan, the library's loading, the carousel's frame cost, image decoding or the
start. It drives the package `app.cartouche` and reads its files, so it needs a debug build installed under that
name: use a device without a release of Cartouche.

```sh
scripts/build.sh --install
scripts/bench.sh --record build/bench.jsonl --label before 150 1000      # sizes: numbers of made-up games, or real
```

`--scenarios session` keeps only the scenarios named (the starts stay; `--starts 0` leaves them out). The `session`
scenario plays about five minutes of use (games scrolled, consoles entered and stepped along, properties, settings,
search, the "+" chooser, the ordering ring, then a rest) and reports its frames and Godot's memory as a whole and part
by part (recorded as scenarios session/scroll, session/enter and so on), so that hitches and memory over time show. After it, the app is left for the system
settings as a game's launch leaves it, and its memory read again (`paused`). The app's memory (`memory_pss`,
`memory_java_kb`, `memory_native_kb`, `memory_graphics_kb`, and `memory_gpu_kb` where the device lets the GPU's count
be read without root) is read after `scroll`, after `session` and while paused.

Run it once before your change and once after, with the same sizes, and compare. More than 10 % slower is a
regression to fix or explain in the pull request. With the size `real`, it uses the library on the device: it sets
the label pictures aside while it measures their download, and puts them back after.

## Neighbours

- [README.md](README.md#diagnostics-and-debug-arguments): every debug argument.
- [testing.md](testing.md#pictures-and-benchmarks): pictures and benchmarks.
- [debug-bridge.md](debug-bridge.md): the remote control of a debug build.
- [architecture/android.md](architecture/android.md): what the plugin does on the device.
- Back to the entry: [README.md](README.md).
