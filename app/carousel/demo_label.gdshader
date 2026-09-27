// SPDX-License-Identifier: GPL-3.0-or-later
// Made-up artwork for the labels of the demo library, so that trying the models shows colourful
// labels like real ones: two colours blended across the label, soft shapes, and a dark band at the
// bottom as on many discs. [seed] makes each game's different.
shader_type canvas_item;

uniform float seed = 0.0;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 first = mix(hue(seed), vec3(1.0), 0.15);
	vec3 second = mix(hue(fract(seed + 0.35)), vec3(0.05), 0.35);
	vec3 colour = mix(first, second, clamp(UV.x * 0.6 + UV.y * 0.7 - 0.2, 0.0, 1.0));
	for (int i = 0; i < 4; i++) {
		vec2 centre = fract(vec2(sin(seed * 91.7 + float(i) * 12.9), cos(seed * 47.3 + float(i) * 7.1)) * 43.7);
		float blob = 1.0 - smoothstep(0.0, 0.32, distance(UV, centre));
		colour = mix(colour, hue(fract(seed + 0.6 + float(i) * 0.13)), blob * 0.55);
	}
	COLOR = vec4(mix(colour, vec3(0.06, 0.06, 0.08), step(0.82, UV.y)), 1.0);
}
