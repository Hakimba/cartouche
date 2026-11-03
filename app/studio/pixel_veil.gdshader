// SPDX-License-Identifier: GPL-3.0-or-later
// The pixel veil over a backdrop (Cyclorama): small square pixels whose brightness ripples in slow diagonal waves.
// Its time `t` is the backdrop's own and goes on while the app rests. Each of its `count` colours is painted, at its
// strongest, as `lights[i]` added (over a dark wall) or `inks[i]` laid at its alpha (over a light one), as
// Cyclorama.veil_paint picks them for the wall. The colours spread one per pixel at random, or in big slow `waves`.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// The rect's size on the screen, in pixels: the veil's pixels are the screen's.
uniform vec2 frame = vec2(1280.0, 960.0);
uniform float t = 0.0;
uniform vec4 lights[3];
uniform vec4 inks[3];
uniform int count = 1;
uniform bool waves = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	const float CELL = 7.0;
	vec2 at = UV * frame;
	vec2 cell = floor(at / CELL);
	vec2 centre = (cell + 0.5) * CELL;
	float slow = sin((centre.x + centre.y) * 0.010 - t * 0.55);
	float cross_wave = sin((centre.x * 0.55 - centre.y) * 0.007 - t * 0.31 + 1.7);
	float wave = clamp((slow * 0.62 + cross_wave * 0.38) * 0.5 + 0.5, 0.0, 1.0);
	float grain = 0.55 + 0.45 * hash(cell);
	// A square of 5 px centred in its cell.
	vec2 edge = abs(at - centre);
	float amount = pow(wave, 2.4) * grain * step(max(edge.x, edge.y), 2.5);
	int last = count - 1;
	vec4 light;
	vec4 ink;
	if (waves) {
		float p = (0.5 + 0.5 * sin((centre.x * 0.6 + centre.y * 0.8) * 0.0035 - t * 0.12)) * float(last);
		int i = min(int(p), last);
		int j = min(i + 1, last);
		float f = smoothstep(0.0, 1.0, p - float(i));
		light = mix(lights[i], lights[j], f);
		ink = mix(inks[i], inks[j], f);
	} else {
		int i = int(hash(cell + vec2(31.7, 57.3)) * float(count));
		light = lights[i];
		ink = inks[i];
	}
	float covered = ink.a * amount;
	COLOR = vec4(light.rgb * amount + ink.rgb * covered, covered);
}
