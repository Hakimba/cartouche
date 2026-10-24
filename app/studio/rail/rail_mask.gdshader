// SPDX-License-Identifier: GPL-3.0-or-later
// The rail's tiles, faded toward both edges by the design's mask.
shader_type canvas_item;

#include "res://studio/rail/rail_mask.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 ramp = vec4(76.8, 256.0, 1024.0, 1203.2);

varying float x;

void vertex() {
	x = VERTEX.x;
}

void fragment() {
	vec4 shown = textureLod(screen_texture, SCREEN_UV, 0.0);
	COLOR = vec4(shown.rgb, shown.a * rail_across(x, ramp));
}
