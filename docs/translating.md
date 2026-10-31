# Translating

Cartouche is written in English, and each other language is one file in `app/locale/`, in the
[gettext `.po`](https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html) format Godot reads:
`fr.po`, `de.po`, `es.po`, `it.po`, `pt.po` (Portugal), `pt_BR.po` (Brazil), `ja.po`.

Each entry pairs an English text, its `msgid`, with its translation, its `msgstr`:

```po
msgid "Remove {platform}?"
msgstr "{platform} entfernen?"
```

- Keep every `{placeholder}` as it is: the app replaces it with a name or a number.
- `msgctxt` tells two uses of the same English apart (`ring` is the consoles' wheel).
- An entry with a plural English text has one translation per plural form of the language, as the file's
  Plural-Forms header says (Japanese has one).
- Write as the people of that language talk to their device, not word for word: the English is the meaning,
  not the shape. When Android has its own name for something (a setting, a permission), use that name, as the
  phone shows it in that language.

## Fix or improve a translation

Change the `msgstr` in the language's file and open a pull request; say in it what read wrong. No code changes.
`app/test/locale/locale_test.gd` checks that every language still has every text with the same placeholders.

Japanese is drawn with the device's own Japanese font, so any character can be used.

## Add a language

1. Copy `app/locale/fr.po` to `app/locale/<code>.po` (the locale code: nl, es_MX…), set its Language and
   Plural-Forms headers, and translate every `msgstr`, one line per text.
2. List the file in `app/project.godot`, under the internationalization translations.
3. Add the language, named in itself, to `NAMES` in `app/locale/locale.gd`, and to the `languages` of the desktop
   demo in `app/adapters/desktop/desktop_plugin.gd`.
4. Add it to `Language` in `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt`, its `@SerialName`
   the same code: the plugin only stores the languages listed there. `WireTest` lists the codes the plugin sends.
5. Run `scripts/test_godot.sh res://test/locale` and the Kotlin tests ([testing.md](testing.md)).

A language written in a script the app's fonts lack (Korean, Chinese…) also needs the system's face for that
script in `StudioText`, which draws the titles and hints: it adds the Japanese one in `_add_japanese()`.

## Add a text to the app

Text the user reads goes through `tr()` (or `tr_n()` for a count), or sits in a scene's `text` or `label`. Add
its English as a new entry at the end of every `.po` file, translated. `locale_test.gd` fails on a text the app
writes that a file lacks.
