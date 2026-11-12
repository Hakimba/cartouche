# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The recording the core made of its searches (RecordedSearchesTest), for the games search tests: each shelf's
## titles, regions and answers.

const PATH := "res://test/carousel/search/recorded_searches.json"

static var _recording: Dictionary


## The recorded shelf [param shelf_name].
static func shelf(shelf_name: String) -> Dictionary:
	if _recording.is_empty():
		_recording = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _recording[shelf_name]


## What the core answered on [param recorded] (a shelf) for [param typed], or with nothing typed its index by `title`
## or `region` ([param order]); [param count_offset] is added to its count, as if the plugin answered for another
## library. A query the core never made stops the test.
static func browse(recorded: Dictionary, order: StringName, typed: String, count_offset := 0) -> AndroidServices.Browse:
	var browsed: Dictionary = recorded["browse"]
	var answer: Dictionary = recorded["by_region"] if order == &"region" and typed.is_empty() else browsed.get(typed, {})
	assert(not answer.is_empty(), "the core was never asked for '%s': record it in RecordedSearchesTest" % typed)
	var told := answer.duplicate()
	told["count"] += count_offset
	return AndroidServices.Browse.new(told)
