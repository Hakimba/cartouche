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

const vec3 WARM = vec3(1.0, 0.973, 0.91);
const vec3 DARK = vec3(0.071, 0.078, 0.102);

varying vec2 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	// The pool: warm near its centre, clear further out, then darker and darker.
	float t = clamp((length(position - centre) - radius * 0.3) / (radius * 1.4), 0.0, 1.0);
	COLOR = t < 0.42 ? vec4(WARM, 0.38 * darkness * (1.0 - t / 0.42)) : vec4(DARK, 0.74 * darkness * (t - 0.42) / 0.58);
}
