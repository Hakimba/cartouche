// SPDX-License-Identifier: GPL-3.0-or-later
// A backdrop's wall drawn from the baked studio (Cyclorama): its lightness mapped from `low` to `high`, so the wall
// keeps the studio's shape in other colours.
shader_type canvas_item;
render_mode unshaded;

uniform vec4 low;
uniform vec4 high;
// The 3D colour buffer this backdrop is copied into (the mobile renderer's RGB10_A2, holding linear light
// halved): one step of it, in linear light.
const float BUFFER_STEP = 2.0 / 1023.0;

void fragment() {
	float lightness = dot(texture(TEXTURE, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 color = mix(low.rgb, high.rgb, clamp((lightness - 0.79) / 0.17, 0.0, 1.0));
	// The canvas is copied into a linear buffer whose steps near black are 6 to 13 sRGB levels apart: the
	// dither is one of those steps, in linear light, the same on the three channels, so the gradient survives
	// the copy as a fine grain instead of rings.
	vec3 lin = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(0.04045, color));
	float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	lin = max(lin + noise * BUFFER_STEP, 0.0);
	vec3 srgb = mix(lin * 12.92, 1.055 * pow(lin, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, lin));
	COLOR = vec4(srgb, 1.0);
}
