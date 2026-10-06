// SPDX-License-Identifier: GPL-3.0-or-later
// A label image as a small disc: the image cut round, the hole in the middle, a thin edge; a blank
// disc with its clear hub while there is no image yet; for the user's own image, a dashed circle
// with a "+" in it.
shader_type canvas_item;

uniform bool has_label = false;
uniform bool own = false;

const float OUTER = 0.47;
const float HUB = 0.155;
const float HOLE = 0.08;

const vec3 INK = vec3(0.13, 0.14, 0.17);

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	float edge = fwidth(d);
	if (own) {
		float dash = step(0.5, fract(atan(p.y, p.x) / TAU * 26.0));
		float ring = (1.0 - smoothstep(0.012 - edge, 0.012 + edge, abs(d - 0.44))) * dash;
		vec2 a = abs(p);
		float plus = step(max(a.x, a.y), 0.15) * step(min(a.x, a.y), 0.02);
		COLOR = vec4(INK, max(ring * 0.45, plus));
	} else {
		vec3 color = has_label ? texture(TEXTURE, UV).rgb : (d < HUB ? vec3(0.78, 0.8, 0.84) : vec3(0.86, 0.88, 0.91));
		color = mix(color, INK, 0.25 * smoothstep(OUTER - 0.012, OUTER, d));
		float shown = (1.0 - smoothstep(OUTER - edge, OUTER + edge, d)) * smoothstep(HOLE - edge, HOLE + edge, d);
		COLOR = vec4(color, shown);
	}
}
