// SPDX-License-Identifier: GPL-3.0-or-later
// The console held on the ring, peeled off like a sticker: its picture, drawn apart, with a white
// border round its outline and a soft dark copy of both below, as its shadow.
shader_type canvas_item;

// The console's picture, which the rect drawn shows a part of; the border's width and the shadow's
// offset, in its pixels.
uniform sampler2D picture : filter_linear;
uniform float border = 9.0;
uniform vec2 shadow = vec2(6.0, 11.0);
uniform vec4 shadow_color : source_color = vec4(0.08, 0.086, 0.11, 0.26);

// How much of the picture lies within the border's width of [uv], looking 16 ways: 1 on the
// console and its border.
float covered(vec2 uv, vec2 pixel) {
	float found = texture(picture, uv).a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * TAU / 16.0;
		found = max(found, texture(picture, uv + vec2(cos(angle), sin(angle)) * pixel * border).a);
	}
	return found;
}

// [top] drawn over [under], both with straight alpha.
vec4 over(vec4 under, vec4 top) {
	float alpha = top.a + under.a * (1.0 - top.a);
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(alpha, 1e-4), alpha);
}

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(picture, 0));
	vec4 shade = vec4(shadow_color.rgb, shadow_color.a * covered(UV - shadow * pixel, pixel));
	vec4 white = vec4(1.0, 1.0, 1.0, covered(UV, pixel));
	COLOR = over(over(shade, white), texture(picture, UV));
}
