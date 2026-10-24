# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_the_tokens_file_carries_the_hash_of_its_own_text_so_a_hand_edit_fails() -> void:
	var lines := FileAccess.get_file_as_string("res://studio/studio_tokens.gd").split("\n")
	var kept := Array(lines).filter(func(line: String) -> bool: return not line.begins_with("const SHA256 := "))
	assert_str("\n".join(PackedStringArray(kept)).sha256_text()).is_equal(StudioTokens.SHA256)


func test_every_supported_console_has_its_gel() -> void:
	assert_int(ConsoleManifest.found().size()).is_greater_equal(12)
	for manifest in ConsoleManifest.found():
		var console := ConsoleManifest.folder_of(manifest)
		assert_bool(manifest.gel() != StudioTokens.NEUTRAL).override_failure_message(console).is_true()
