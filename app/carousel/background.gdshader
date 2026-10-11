// SPDX-License-Identifier: GPL-3.0-or-later
// The app's backdrop, "Pois": a light vertical gradient under big pale dots that drift diagonally,
// as far as `Backdrop` (backdrop.gd) has them, which slows them to a stop while the app rests.
// Positions are in the rect's own units (the 1280×960 design), so the dots keep their size whatever
// the screen.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.961, 0.973, 0.984, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.902, 0.922, 0.945, 1.0);
uniform vec4 dot_color : source_color = vec4(0.431, 0.627, 0.843, 0.17);
// In design pixels: a tile holds two dots, at a quarter and three quarters of its diagonal.
uniform float tile = 120.0;
uniform float dot_radius = 17.0;
// How far the dots have drifted, in tiles, from 0 to 1.
uniform float drift = 0.0;
// In design pixels: the dots blurred as the consoles in front of them (see ConsoleLayer).
uniform float blur = 0.0;

varying vec2 position;

void vertex() {
	position = VERTEX;
}

void fragment() {
	vec4 color = mix(top_color, bottom_color, UV.y);
	vec2 shifted = position - vec2(tile) * drift;
	vec2 cell = mod(shifted, tile);
	float distance_to_dot = min(length(cell - vec2(tile * 0.25)), length(cell - vec2(tile * 0.75)));
	float edge = max(fwidth(distance_to_dot), blur);
	float dot = 1.0 - smoothstep(dot_radius - edge, dot_radius + edge, distance_to_dot);
	COLOR = vec4(mix(color.rgb, dot_color.rgb, dot * dot_color.a), 1.0);
}
