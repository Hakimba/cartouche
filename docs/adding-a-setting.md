# Adding a setting

A setting is a choice on the settings card (Y): a switch, a level, or a choice opening its own page. It is
declared once in the core, which stores it, checks every value sent for it and sends it to Godot; Godot's reader is
generated. What is left by hand is its row on the card and what it changes.

A value reaches Godot as a choice's name (the enum's `@SerialName`), a switch's `bool` or a level's number
(`SettingValue`). Godot sends it back as text, as `str()` writes it: `saveSetting(key, value)` takes two texts.

## Steps

1. **The field.** In `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt`, add the field to
   `Settings` with its default: an enum with a `@SerialName` per entry for a choice, `Boolean` for a switch, a
   value class with its range check (`SoundLevel.of`) for a level. Never rename a stored field or a `@SerialName`:
   a stored file would no longer read.
2. **The declaration.** In the companion of `Setting`
   (`kotlin/core/src/main/kotlin/app/cartouche/core/settings/Setting.kt`), one line: its key in snake case and its
   form (`switch`, `level`, `choice<…>()`, or `.optional(cleared = …)` for a choice that can be none). Add it to
   `Setting.all`, and the field to the `settings` generator (`Generators.kt`), or the round trip only tries its
   default.
3. **The answer.** Add the field to `Sent.SettingsAnswer`
   (`kotlin/android/src/main/kotlin/app/cartouche/android/Sent.kt`), with its names list for a choice.
4. **Generate and test.**

   ```sh
   cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true   # android_wire.gd
   cd kotlin && ./gradlew :core:test :android:testDebugUnitTest
   ```

   `SettingTest` fails while a field of `Settings` has no declaration, `WireTest` while a declared setting is not
   sent under its key and read back, `CartouchePluginTest` saves it through the plugin. `DesktopDemoTest` writes a
   new `desktop.json` in the `kotlin/android` build folder: copy it to `app/dev/demo/desktop.json`.
5. **The row.** One entry in `SettingsMenu.ROWS` (`app/screens/settings_menu.gd`), with its `label` and `kind`
   (`arc: true` for a row that only screens whose games stand on an arc show):

   | `kind` | Also needs |
   |---|---|
   | `Kind.SWITCH`, keyed by the setting's key, with its `note` | `ScreenFlow._turn_switch` slides it, saves it through `ScreenFlow._save_held` and slides it back when the save fails. The new value is applied once the plugin keeps it, whenever that is, the settings closed meanwhile or not: a switch that changes something gets its case there, as the pixel veil (shown) has; a switch of the games row is a `ShelfRow` property of the setting's key, set through `ScreenFlow.row_switch_kept`, as the games' float and the games in a line are |
   | `Kind.CHOICE` (value right of its name) or `Kind.CHOICE_BELOW` (a long value, under it) | a page to choose on (`CardChoiceScreen` for a list of names); a `_choose_…` method of `ScreenFlow` that saves through `ScreenFlow._save_held`, whose `kept` callable keeps the value in the stored `SettingsAnswer` or puts the old one back; a case in `ScreenFlow._settings_menu`; its value shown in `SettingsMenu._open(request)` |
   | `Kind.LEVEL` | the sounds' bar is drawn on its own: a second level needs its own drawing |

   While a save is under way (`ScreenFlow.HeldSave`, its one owner) the settings hold their presses (INV-20): the card
   itself, a choice page through `Page.busy_while`. B lets go of the page the save holds, or of the card, once the save
   has lasted two seconds (`HeldSave.ESCAPE_MS`), the save going on and its answer applied when it comes.

6. **The fake plugin.** An entry in `Scripted.Request` (`app/test/carousel/fixtures.gd`) named after the key in
   capitals, like `SAVE_PIXEL_VEIL`: `Scripted.save_of(key)` looks it up, and a test saving the setting stops
   without it.
7. **Text.** The row's `label` and `note` in every `.po` file ([translating.md](translating.md#add-a-text-to-the-app)).
8. **What it changes.** Read it where the app starts (`ScreenFlow.run`, `carousel.gd`) and apply it; trace a
   change with `Diagnostics.trace`.
9. **Check.** `GODOT=$GODOT scripts/test_godot.sh res://test/screens res://test/adapters res://test/locale`, then
   run the app and open the card (Y). A choice with its own page adds a row to the two tables of
   `settings_test.gd` (saved once and applied; refused and not applied).
