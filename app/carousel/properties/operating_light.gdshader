// SPDX-License-Identifier: GPL-3.0-or-later
// The light over a staged game, like an operating table's: the room darkens round it and a warm
// pool of light falls on it. Drawn between the backdrop and the 3D. Positions are in the rect's own
// units (the 1280×960 design).
shader_type canvas_item;

// Where the light falls, and how far its pool reaches.
uniform vec2 centre = vec2(640.0, 462.0);
uniform float radius = 400.0;
// How dark the room gets, from 0 (not at all: nothing drawn) to 1.
uniform float darkness = 0.0;
uniform bool shaped = false;
uniform vec2 radii = vec2(600.0, 660.0);
uniform vec4 pool_color : source_color;
// The backdrop's: the dark the room falls off to (its alpha: how far), and how strong the warm light is at
// its centre.
uniform vec4 dark = vec4(0.071, 0.078, 0.102, 1.0);
uniform float warm_alpha = 0.38;

const vec3 WARM = vec3(1.0, 0.973, 0.91);

varying vec2 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	if (shaped) {
		float t = clamp((length((position - centre) / radii) - 0.48) / 0.52, 0.0, 1.0);
		COLOR = vec4(pool_color.rgb, pool_color.a * darkness * t);
	} else {
		// The pool: warm near its centre, clear further out, then darker and darker.
		float t = clamp((length(position - centre) - radius * 0.3) / (radius * 1.4), 0.0, 1.0);
		COLOR = t < 0.42 ? vec4(WARM, warm_alpha * darkness * (1.0 - t / 0.42)) : vec4(dark.rgb, dark.a * 0.74 * darkness * (t - 0.42) / 0.58);
	}
}
