// SPDX-License-Identifier: GPL-3.0-or-later
// The consoles behind the games (see ConsoleLayer): the view they are drawn in, blurred over
// `radius` screen pixels, greyed towards no colour as `saturation` goes to 0, faded by `opacity`.
shader_type canvas_item;

uniform float radius = 0.0;
uniform float opacity = 1.0;
uniform float saturation = 1.0;

const int TAPS = 16;
// Taps spread evenly over the disc of the blur, turning by the golden angle.
const float GOLDEN_ANGLE = 2.39996;

void fragment() {
	vec3 colour = vec3(0.0);
	float cover = 0.0;
	for (int i = 0; i < TAPS; i++) {
		float away = sqrt((float(i) + 0.5) / float(TAPS)) * radius;
		float angle = float(i) * GOLDEN_ANGLE;
		vec4 tap = texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * away * SCREEN_PIXEL_SIZE);
		// Weighted by how much of the tap the consoles cover, so that the clear view around them
		// does not darken their edges.
		colour += tap.rgb * tap.a;
		cover += tap.a;
	}
	colour /= max(cover, 0.0001);
	float grey = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(vec3(grey), colour, saturation), cover / float(TAPS) * opacity);
}
