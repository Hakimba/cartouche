// SPDX-License-Identifier: GPL-3.0-or-later
// The carousel's backdrop: a light vertical gradient under a grid of small dots, in screen space.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.93, 0.94, 0.95, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.78, 0.80, 0.83, 1.0);
uniform vec4 dot_color : source_color = vec4(0.62, 0.64, 0.68, 1.0);
// In pixels.
uniform float dot_spacing = 28.0;
uniform float dot_radius = 1.6;

void fragment() {
	vec4 color = mix(top_color, bottom_color, SCREEN_UV.y);
	vec2 cell = mod(FRAGCOORD.xy, dot_spacing) - dot_spacing * 0.5;
	float dot = 1.0 - smoothstep(dot_radius - 0.8, dot_radius + 0.8, length(cell));
	COLOR = mix(color, dot_color, dot);
}
