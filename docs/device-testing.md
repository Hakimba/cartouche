# Testing on a device

The desktop build proves the screens. A device proves what only Android does: picking folders, scanning them,
downloading labels, starting an emulator, and the plugin's answers crossing into Godot. You need an Android 11 or
later arm64 device with Vulkan, USB debugging on, and `adb devices` listing it as `device`.

## Install beside your own Cartouche

A debug build cannot replace a release: they are signed with different keys, and uninstalling the release deletes
its library, settings and chosen labels. Install the test build under its own package name.

1. In `app/export_presets.cfg`, change `package/unique_name="app.cartouche"` to a name of your own, such as
   `app.cartouche.test`. Never commit this change.
2. Build and export. The export's first line names the engine template used
   ([the engine template](README.md#the-engine-template)); after a change to GDScript only, the export alone is
   enough.

   ```sh
   scripts/build.sh                                        # every check, and the Kotlin plugin
   scripts/export_apk.sh debug build/cartouche-test.apk
   git checkout app/export_presets.cfg                     # back to the real package name
   ```

3. Install and start it, with [debug arguments](README.md#diagnostics-and-debug-arguments) if needed:

   ```sh
   adb install -r build/cartouche-test.apk
   adb shell am start -n app.cartouche.test/com.godot.game.GodotAppLauncher --esa arguments --welcome=skip,--demo-games=500
   ```

4. When done: `adb uninstall app.cartouche.test`.

On a device with no release of Cartouche, `scripts/build.sh --install` does it all as `app.cartouche`.

Keep the user's data safe:

- Never delete files under the app's data folder: its art folder holds the label pictures the user chose.
- Try an older or experimental build on a made-up library (`--demo-games=N`), and test games in a folder of
  their own.
- The app comes back where it was left, and A on a game starts its emulator: take a screenshot before pressing A.
  `--launch=rehearse` plays a launch without starting anything.

## Traces

```sh
scripts/logs.sh                               # follows the traces as they come
scripts/logs.sh --clear                       # drops what the device logged before
adb exec-out screencap -p > build/device.png  # a picture of the screen
```

The traces are the GDScript ones (tag `godot`, written by `Diagnostics.trace`), the plugin's (tag `Cartouche`,
written by `trace` in `Wire.kt`), the activities started (the intent sent to an emulator) and crashes. After
walking through the screens, look for SCRIPT ERROR and FATAL: there should be none.

The [debug bridge](debug-bridge.md) reaches a device through `adb reverse tcp:5201 tcp:5201`, the build started
with `--bridge`. No test covers this path: try it on a demo library first.

## Benchmarks

`scripts/bench.sh` measures the debug build installed as `app.cartouche` (so on a device without a release): cold
starts, then each scenario of `CarouselBench` for a fixed time, at several library sizes. Run it only when a change
touches something measured: the scan, the library's loading, the carousel's frame cost, image decoding, the start.

```sh
scripts/build.sh --install
scripts/bench.sh --record build/bench.jsonl --label before 150 1000      # sizes: numbers of made-up games, or real
```

| Option | Does |
|---|---|
| `--record FILE`, `--label TEXT` | appends each measure to FILE as one JSON line, the label naming the run |
| `--scenarios session` | keeps only the scenarios named; the starts stay |
| `--starts 0` | leaves the cold starts out |
| the size `real` | uses the library on the device: the label pictures are set aside while their download is measured, then put back |

The `session` scenario plays about five minutes of use and reports frames and memory as a whole and part by part
(recorded as session/scroll, session/enter and so on); the app is then left as a game's launch leaves it and its
memory read again (`paused`). Run the bench before and after a change, with the same sizes. More than 10 % slower is a regression to
fix or explain in the pull request.
