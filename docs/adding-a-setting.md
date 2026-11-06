# Adding a setting

**You are here.** A setting is a choice the user makes on the settings card (Y): a switch, a level, or a choice
opening its own page. It is declared once in the core, which stores it, checks every value sent for it and sends it
to Godot. The bridge, the stored file and the wire's tests follow the declaration; the answer sent to Godot names it
once more, and Godot's reader of it is generated. What is left is its row on the card and what it changes in the
app.

## The contract

| Layer | What it holds | Where |
|---|---|---|
| Core | the field of `Settings` and its default, the only one | `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt` |
| Core | its declaration, a `Setting`: its key, how its value is sent and checked | `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Setting.kt` |
| Bridge | `saveSetting` stores any declared setting, refusing a value it does not take; `settings` sends them all | `CartouchePlugin.kt`, `Sent.kt` |
| Godot | `save_setting(key, value)`, and the answer's field named after the key, generated | `android_services.gd`, `android_wire.gd` |
| Card | its row, from `SettingsMenu.ROWS` | `app/screens/settings_menu.gd`, `app/screens/screen_flow.gd` |

A value reaches Godot as one of three kinds (`SettingValue`): a choice's name (the enum's `@SerialName`, as the
file stores it), a switch's `bool`, or a level's number. Godot sends it back as text, as `str()` writes it
(`true`, `4`, `pt_BR`), and the declaration reads that text: `saveSetting(key, value)` takes two texts, nothing
else. A choice also sends the names it takes under its key and `s` (`languages`), the only ones `saveSetting` takes.

## Steps

1. **Core.** Add the field to `Settings` with its default: a fresh install gets it, and a file stored before it
   existed reads with it. Its type is an enum with a `@SerialName` per entry for a choice, `Boolean` for a switch,
   or a value class with its range check (`SoundLevel.of`) for a level. Never rename a stored field or a
   `@SerialName`: a stored file would no longer read.
2. **Declaration.** In `Setting`'s companion, one line: its key (in snake case, the name Godot uses) and its form
   (`switch`, `level`, `choice<…>()` for an enum, or `.optional(cleared = …)` for a choice that can be none), then
   add it to `Setting.all`. Add the field to the `settings` generator (`Generators.kt`): nothing fails without it,
   but the round trip below then only ever tries its default.
3. **Kotlin tests.** `cd kotlin && ./gradlew :core:test :android:testDebugUnitTest`. `SettingTest` fails while a
   field of `Settings` has no declaration in `Setting.all` (its key is the field's name in snake case); `WireTest`
   fails while a declared setting is not sent under its key as its declaration writes it, or does not come back as
   sent; `VersionedJsonTest` checks the file reads back the same,
   and `CartouchePluginTest` saves it through the plugin, a value it does not take changing nothing.
4. **Godot's answer.** Add the field to `Sent.SettingsAnswer` (`kotlin/android/src/main/kotlin/app/cartouche/android/Sent.kt`), and its names list
   for a choice, then write `android_wire.gd` again:
   `./gradlew :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true`. Its `SettingsAnswer` reads an
   absent value as the fresh install's. `DesktopDemoTest` then writes the fresh install's settings to a
   `desktop.json` in the `kotlin/android` build folder: copy it to `app/dev/demo/desktop.json`, the desktop's
   answers.
5. **The row.** One entry in `SettingsMenu.ROWS`, keyed by what a press on it emits, with its `label` and `kind`:
   - `Kind.SWITCH`, keyed by the setting's key, with its `note`: nothing more. `ScreenFlow` slides it, saves it
     by its key and slides it back when the save fails; the app reads it as the settings close, from
     `SettingsMenu.switch_on` (`carousel.gd`, as the games' float). A switch whose effect shows at once, while the
     card is still open, gets its own case in `ScreenFlow._turn_switch` once saved, as the pixel veil does.
   - `Kind.CHOICE` (value right of its name) or `Kind.CHOICE_BELOW` (a long value, under it): a page to choose
     on (`CardChoiceScreen` for a list of names, as the region and the language do), a `_choose_…` method that saves
     through `ScreenFlow._save` (one save, its refusal traced, the presses held if asked) and keeps the value in the
     stored `SettingsAnswer`, a case in `ScreenFlow._settings_menu`, and its value shown in `SettingsMenu.open`.
   - `Kind.LEVEL` is the sounds' bar, drawn on its own; a second level needs its own drawing.
6. **Text.** The row's `label` and `note` in every `.po` file ([translating.md](translating.md#add-a-text-to-the-app));
   `locale_test.gd` reads them from `ROWS`.
7. **What it changes.** Read it where the app starts (`ScreenFlow.run`, `carousel.gd`) and apply it; trace a
   change with `Diagnostics.trace`.
8. **Check.** `scripts/test_godot.sh res://test/screens res://test/adapters res://test/locale`, then run the app
   on the desktop and open the card (Y): the row, its page or switch, the card scrolled to it and back. A choice with
   its own page adds a row to the two tables of `settings_test.gd` (saved once and applied, refused and not applied);
   add a test of its own only for a behaviour that could break silently.

## Neighbours

- The settings card and the screens in front of the carousel: [architecture/godot.md](architecture/godot.md).
- The plugin and its wire: [architecture/android.md](architecture/android.md).
- A setting that changes the background's look: [adding-a-background.md](adding-a-background.md).
