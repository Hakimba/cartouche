// SPDX-License-Identifier: GPL-3.0-or-later
// The focus outline round a label: a rim and a soft glow on both sides of the rounded box.
shader_type canvas_item;
uniform vec2 box_size;
uniform float radius;
uniform vec4 gel : source_color;
varying vec2 point;
void vertex() { point = VERTEX - vec2(32.0); }
float erf_value(float x) {
	float a = abs(x);
	float t = 1.0 + (0.278393 + (0.230389 + 0.078108 * a * a) * a) * a;
	return sign(x) * (1.0 - 1.0 / (t * t * t * t));
}
void fragment() {
	vec2 q = abs(point - box_size * 0.5) - box_size * 0.5 + radius;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float aa = max(fwidth(d), 0.001);
	float rim = (1.0 - smoothstep(-aa, aa, d)) * smoothstep(-5.12 - aa, -5.12 + aa, d);
	float outside = 0.45 * (0.5 - 0.5 * erf_value(d / (8.96 * sqrt(2.0))));
	float inside = 0.25 * (0.5 + 0.5 * erf_value((d + 5.12) / (5.12 * sqrt(2.0))));
	float glow = d > 0.0 ? outside : inside;
	COLOR = vec4(gel.rgb, rim + glow * (1.0 - rim)) * COLOR;
}
