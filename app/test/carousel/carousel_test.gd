# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const CAROUSEL := preload("res://carousel/carousel.tscn")


func test_the_art_bar_follows_a_run_greys_while_it_waits_and_fades_once_it_is_over() -> void:
	var carousel: Carousel = auto_free(CAROUSEL.instantiate())
	add_child(carousel)
	var progress: Control = carousel.get_node("%ArtProgress")
	var bar: ProgressBar = carousel.get_node("%Bar")
	var text: Label = carousel.get_node("%ArtText")
	var content: Control = carousel.get_node("%Content")
	var tell := func(payload: Dictionary) -> void:
		carousel._on_art_changed(AndroidServices.ArtChange.new(payload))
		# The bar moves on its tween: moved to its end here, rather than waited for.
		if carousel._art_tween:
			carousel._art_tween.custom_step(Carousel._ART_STEP_S + 0.01)
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()
	tell.call({"done": 12, "total": 55})
	assert_bool(progress.visible).is_true()
	assert_float(bar.value).is_equal(12.0)
	assert_float(bar.max_value).is_equal(55.0)
	assert_str(text.text).is_equal("Disc images · 12 / 55")
	assert_str(bar.theme_type_variation).is_equal("ArtBar")
	var messages := {
		"offline": "Disc images · offline, resuming when the network is back",
		"refused": "Disc images · server unavailable, trying again later",
		"storage": "Disc images · no room left on the device",
	}
	for stall: String in messages:
		tell.call({"done": 12, "total": 55, "stall": stall})
		assert_str(text.text).is_equal(messages[stall])
		assert_str(bar.theme_type_variation).is_equal("ArtBarStalled")
		assert_float(bar.value).is_equal(12.0)
	# A launch failure's message shows where the bar is: the bar hides for it.
	carousel._show_message("No emulator.")
	assert_bool(content.visible).is_false()
	carousel._on_message_timer_timeout()
	assert_bool(content.visible).is_true()
	tell.call({"done": 55, "total": 55})
	assert_float(bar.value).is_equal(55.0)
	assert_bool(progress.visible).is_true()
	carousel._art_tween.custom_step(Carousel._ART_FULL_S + Carousel._ART_FADE_S + 0.1)
	assert_bool(progress.visible).is_false()
	# A later run with nothing to look for shows nothing.
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()
