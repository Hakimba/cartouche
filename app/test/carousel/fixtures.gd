# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Readable values for the carousel's tests, and the seeded random cases their properties run on:
## the same cases on every run.

## Cases each property checks.
const CASES := 2000
const FRAME_S := 1.0 / 60.0
const DVD := preload("res://carousel/models/dvd.tscn")


## A generator of cases, seeded by the test so that a failure always comes back.
static func cases(test_seed: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = test_seed
	return random


## Left or right, as [param random] draws it.
static func direction(random: RandomNumberGenerator) -> int:
	return -1 if random.randf() < 0.5 else 1


## [param count] games of one shelf, titled `Game 0`, `Game 1`…
static func games(count: int) -> Array[AndroidServices.Game]:
	var shelf: Array[AndroidServices.Game] = []
	for i in count:
		shelf.append(AndroidServices.Game.new({
			"id": "test/%d" % i, "platform_id": "test", "title": "Game %d" % i, "identified": false,
			"discs": [{"name": "Game %d.iso" % i}], "last_disc": 0,
		}))
	return shelf
