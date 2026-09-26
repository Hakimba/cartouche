# Invariants

Guarantees every change must keep. Each id is part of the name of the test (or tests) enforcing it.
Weakening one is a design decision to discuss first, never a side effect of a change.

| Id | Area | Invariant | Why |
|---|---|---|---|
| INV-E0-01 | Launch | Templates can never grant URI permissions: `--grant-*` and any `-f` value with a grant bit are rejected, and a `LaunchSpec` can only be built by resolving a template (its constructor is internal). | Player definitions are third-party data. |
| INV-E0-02 | Launch | Only the game's own URI is ever granted, exactly when the launch depends on it; no other content URI is handed where Android grants access with the intent (the data URI, `--eu` extras). | A template must not reach other files in a granted folder. |
| INV-E0-03 | Launch | Placeholder values are inserted verbatim in every kind of value, including string arrays. | A file name with quotes, commas or `-n …` must not change the launch. |
| INV-E0-04 | Launch | Parsing and resolving templates is total: a template or a typed error, never an exception. | Bad data is reported, not a crash. |
| INV-E0-05 | Launch | Single- and double-quoted tokens tokenize back to themselves. | The tokenizer never loses or alters characters. |
| INV-E0-06 | Launch | A template needing `{file.path}` never launches a file without a filesystem path. | Otherwise the emulator starts with an empty ROM argument. |
| INV-E0-07 | Catalog | Every definition file shipped in `app/data/platforms` parses with no rejection. | Updating bundled data must not silently lose emulators. |
| INV-E0-08 | Catalog | A broken or duplicate player is rejected alone, a broken or duplicate platform whole, and every rejection is reported. | Nothing disappears silently. |
| INV-E0-09 | Catalog | Hidden files (`.x`, `._x`) are never offered to a player, whatever the patterns say. | They are not games. |
| INV-E0-10 | Catalog | Catalog parsing and file matching are total. | As INV-E0-04, for definition files and names. |
| INV-E0-11 | Storage | Only documents of the external storage provider map to a filesystem path; the mapping is total. | `{file.path}` must never point to a guessed location. |
| INV-E0-12 | Android | Whatever the template, a launch intent grants read access to the game URI when it hands it, and to nothing else; it never grants write, persistable or prefix access. | The emulator can open the game; nobody can write to ROM folders. |
| INV-E0-13 | Android | Launches always start a new task and keep the template's activity switches. | Templates are written for `am start`. |
| INV-E0-14 | Android | Only read access to a picked folder is kept. | Cartouche never writes to ROM folders. |
| INV-E0-15 | Android | Every folder pick is answered exactly once: by its result, by the failure to open the picker, or as cancelled by a newer pick. | A screen awaiting a pick never hangs or gets two answers. |
| INV-E0-16 | Android | Everything the plugin sends to Godot is a value its JNI bridge converts: text, booleans, numbers, Dictionaries, and lists as `Object[]`. | Any other array reaches GDScript as an opaque object, and lists show up empty. |
