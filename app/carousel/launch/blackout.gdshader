// SPDX-License-Identifier: GPL-3.0-or-later
// The black that covers the screen as a game launches, on a rect covering the screen: a black disc
// around `centre` (a fraction of the rect, from its top left) of `radius` pixels, all of it faded
// by `opacity` as the carousel shows again.
shader_type canvas_item;

uniform vec2 centre = vec2(0.5);
uniform vec2 size = vec2(1.0);
uniform float radius = 0.0;
uniform float opacity = 1.0;

void fragment() {
	float away = length((UV - centre) * size);
	// Soft over a pixel and a half outside the radius: at the radius, the black is whole.
	COLOR = vec4(0.0, 0.0, 0.0, opacity * (1.0 - smoothstep(radius, radius + 1.5, away)));
}
