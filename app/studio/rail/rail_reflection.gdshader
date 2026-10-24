// SPDX-License-Identifier: GPL-3.0-or-later
// The tiles' floor reflections: the rail's own mask across (see rail_mask.gdshader) and the design's `box-reflect`
// mask down each. The mask is laid on the tile and then mirrored with it, as the browser draws it: the reflection
// shows an alpha of .22 at the tile's edge, fading to nothing 38 % of its height down, and nothing past that.
shader_type canvas_item;

#include "res://studio/rail/rail_mask.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 ramp = vec4(76.8, 256.0, 1024.0, 1203.2);
// The reflection's top (the tile's edge) and its height, in px.
uniform vec2 band = vec2(818.56, 102.4);
uniform float clear = 0.62;
uniform float far = 0.22;

varying vec2 at;

void vertex() {
	at = VERTEX;
}

void fragment() {
	vec4 shown = textureLod(screen_texture, SCREEN_UV, 0.0);
	float down = clamp(((1.0 - (at.y - band.x) / band.y) - clear) / (1.0 - clear), 0.0, 1.0) * far;
	COLOR = vec4(shown.rgb, shown.a * rail_across(at.x, ramp) * down);
}
