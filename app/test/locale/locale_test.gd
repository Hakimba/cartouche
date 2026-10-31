# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The translations against the text the app writes: every language has every text, with the same placeholders.

const _LOCALE := "res://locale/"
## Texts that stay as they are in every language.
const _UNTRANSLATED := ["Cartouche"]


func test_every_language_has_every_text_translated_with_its_placeholders() -> void:
	var reference := _entries(_LOCALE + "fr.po")
	for file in DirAccess.get_files_at(_LOCALE):
		if not file.ends_with(".po"):
			continue
		var entries := _entries(_LOCALE + file)
		assert_array(entries.keys()).override_failure_message(file).contains_exactly(reference.keys())
		for key: String in entries:
			for text: String in entries[key]:
				# An empty translation shows the English without a word.
				assert_str(text).override_failure_message("%s: \"%s\" is not translated" % [file, key]).is_not_empty()
				assert_array(_placeholders(text)).override_failure_message("%s: %s" % [file, text]) \
					.contains_exactly_in_any_order(_placeholders(key))


func test_every_text_the_app_writes_is_translated() -> void:
	var translated := _entries(_LOCALE + "fr.po")
	# A `tr` call's second argument is its context; a `tr_n` call's, its plural.
	var calls := RegEx.create_from_string("\\b(tr|tr_n|translate)\\(\"((?:[^\"\\\\]|\\\\.)*)\"(?:, &?\"(\\w*)\")?")
	var fields := RegEx.create_from_string("(?m)^(text|label|title|note) = \"((?:[^\"\\\\]|\\\\.)*)\"$")
	for path in _sources("res://"):
		var source := FileAccess.get_file_as_string(path)
		for found in calls.search_all(source) + (fields.search_all(source) if path.ends_with(".tscn") else []):
			var text := found.get_string(2).c_unescape()
			if found.get_string(1) == "tr" and found.get_string(3):
				text = found.get_string(3) + "|" + text
			if text not in _UNTRANSLATED and RegEx.create_from_string("[A-Za-z]{2}").search(text):
				assert_bool(translated.has(text)).override_failure_message("%s: \"%s\" has no translation" % [path, text]) \
					.is_true()


func test_every_language_named_has_its_translation() -> void:
	assert_array(TranslationServer.get_loaded_locales()).contains_exactly_in_any_order(Locale.NAMES.keys().filter(
		func(code: String) -> bool: return code != "en"))


## Each `msgid` of [param path] (its `msgctxt` before it, a `|` between) with its translations.
func _entries(path: String) -> Dictionary[String, PackedStringArray]:
	var entries: Dictionary[String, PackedStringArray] = {}
	var field := RegEx.create_from_string("(?m)^(msgctxt|msgid|msgstr(?:\\[\\d\\])?) \"(.*)\"$")
	var source := FileAccess.get_file_as_string(path)
	# One line per text: a text wrapped over lines would be read cut.
	assert_object(RegEx.create_from_string("(?m)^\"").search(source.substr(source.find("\nmsgid \"No ")))) \
		.override_failure_message("%s: a text is wrapped over lines" % path).is_null()
	for block in source.split("\n\n"):
		var context := ""
		var key := ""
		var texts := PackedStringArray()
		for found in field.search_all(block):
			match found.get_string(1):
				"msgctxt":
					context = found.get_string(2) + "|"
				"msgid":
					key = found.get_string(2).c_unescape()
				_:
					texts.append(found.get_string(2).c_unescape())
		if key:
			entries[key if not context else context + key] = texts
	return entries


func _placeholders(text: String) -> PackedStringArray:
	var names := PackedStringArray()
	for found in RegEx.create_from_string("\\{\\w+\\}").search_all(text):
		names.append(found.get_string())
	return names


## The app's scripts and scenes under [param folder]; tests, tools, add-ons and the Android build template aside.
func _sources(folder: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "tscn"]:
			paths.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub)
		if path not in ["res://addons", "res://android", "res://test", "res://.godot", "res://dev"]:
			paths.append_array(_sources(path))
	return paths
