// SPDX-License-Identifier: GPL-3.0-or-later
shader_type canvas_item;

uniform bool has_label = false;
uniform bool own = false;
uniform bool cartridge = false;
uniform float proportion = 1.0;

const float OUTER = 0.47;
const float HUB = 0.155;
const float HOLE = 0.08;

const vec3 INK = vec3(0.13, 0.14, 0.17);

varying float faded;

void vertex() {
	faded = COLOR.a;
}

void fragment() {
	vec2 p = UV - 0.5;
	vec2 fitted = p * vec2(max(1.0, 1.0 / proportion), max(1.0, proportion));
	vec2 q = abs(fitted) - vec2(0.40);
	float rectangle = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.04;
	float d = cartridge ? rectangle + OUTER : length(p);
	float edge = fwidth(d);
	if (own) {
		float dash = step(0.5, fract(atan(p.y, p.x) / TAU * 26.0));
		float ring = (1.0 - smoothstep(0.012 - edge, 0.012 + edge, abs(d - 0.44))) * dash;
		vec2 a = abs(p);
		float plus = step(max(a.x, a.y), 0.15) * step(min(a.x, a.y), 0.02);
		COLOR = vec4(INK, max(ring * 0.45, plus));
	} else {
		vec2 source_uv = UV;
		if (cartridge) {
			vec2 cover = vec2(min(1.0, proportion * TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y), min(1.0, TEXTURE_PIXEL_SIZE.y / (proportion * TEXTURE_PIXEL_SIZE.x)));
			source_uv = fitted / 0.88 * cover + 0.5;
		}
		vec3 color = has_label ? texture(TEXTURE, source_uv).rgb : (d < HUB ? vec3(0.78, 0.8, 0.84) : vec3(0.86, 0.88, 0.91));
		color = mix(color, INK, 0.25 * smoothstep(OUTER - 0.012, OUTER, d));
		float shown = (1.0 - smoothstep(OUTER - edge, OUTER + edge, d)) * (cartridge ? 1.0 : smoothstep(HOLE - edge, HOLE + edge, d));
		COLOR = vec4(color, shown);
	}
	COLOR.a *= faded;
}
