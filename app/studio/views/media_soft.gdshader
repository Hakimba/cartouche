// SPDX-License-Identifier: GPL-3.0-or-later
// A medium drawn alone (MediaView), softened as a CSS filter `blur(b) drop-shadow(0 y s colour) saturate(k)`
// would: its view blurred by a Gaussian of standard deviation `blur` pixels, a warm shadow of its blurred
// coverage `shadow_y` pixels down, blurred by `shadow_blur` (a CSS shadow blur, twice its standard deviation),
// then the whole greyed towards `saturation`. The view is premultiplied (a transparent 3D view), and so is what
// is drawn. It runs once each time the view is drawn, into a picture of its own (MediaView).
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://studio/views/soft.gdshaderinc"

uniform float blur = 0.0;
uniform float shadow_y = 0.0;
uniform float shadow_blur = 0.0;
uniform vec4 shadow_colour = vec4(0.0);
uniform float saturation = 1.0;
// The taps of each Gaussian (MediaView.taps): few for the medium's pixel of blur, many for its shadow, so that no
// edge shows its copies. Each is its offset in standard deviations and its share of the sum.
uniform vec3 medium_taps[16];
uniform vec3 shadow_taps[48];

// The view blurred by a Gaussian of standard deviation SIGMA (pixels) at UV_AT, over TAPS: written out in
// fragment() itself, where the view (TEXTURE) is.
#define GAUSSIAN(OUT, UV_AT, SIGMA, TAPS) { \
	OUT = texture(TEXTURE, UV_AT); \
	if (SIGMA >= 0.05) { \
		OUT = vec4(0.0); \
		for (int i = 0; i < TAPS.length(); i++) { \
			OUT += texture(TEXTURE, UV_AT + TAPS[i].xy * SIGMA * TEXTURE_PIXEL_SIZE) * TAPS[i].z; \
		} \
	} \
}

void fragment() {
	vec4 medium;
	GAUSSIAN(medium, UV, blur, medium_taps)
	vec4 drawn = medium;
	// The shadow shows only where the medium does not cover: under it, it would add exactly nothing.
	if (shadow_colour.a > 0.0 && medium.a < 1.0) {
		// The shadow is cast by the blurred medium: the two Gaussians add up.
		vec4 casting;
		GAUSSIAN(casting, UV - vec2(0.0, shadow_y) * TEXTURE_PIXEL_SIZE, length(vec2(blur, shadow_blur / 2.0)), shadow_taps)
		float shade = shadow_colour.a * casting.a;
		drawn += vec4(shadow_colour.rgb * shade, shade) * (1.0 - medium.a);
	}
	// CSS saturate(), on the colour as drawn (sRGB), not premultiplied.
	vec3 colour = saturated(drawn.rgb / max(drawn.a, 1e-4), saturation);
	COLOR = vec4(clamp(colour, 0.0, 1.0) * drawn.a, drawn.a);
}
