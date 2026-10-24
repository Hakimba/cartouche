// SPDX-License-Identifier: GPL-3.0-or-later
// The cyclorama's glows (Cyclorama) over its baked wall and floor, in one pass and in the design's paint order:
// the gel on the floor, the gel on the wall, the key light, the floor's pool of light. Each is a radial gradient
// of an ellipse, its colour at the centre fading to nothing at its last stop, composed as CSS composes stacked
// backgrounds. Half a level of fixed dither keeps the 8-bit screen from banding; nothing moves with time.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// In px of the 1280 x 960 frame the rect stands for, bottom glow first.
uniform vec2 frame = vec2(1280.0, 960.0);
uniform vec2 centres[4];
uniform vec2 radii[4];
uniform vec4 colors[4];
uniform float stops[4];
// 1 for a glow the gel tints, its colour's alpha kept.
uniform float tinted[4];
uniform vec3 gel = vec3(0.627, 0.47, 0.314);

void fragment() {
	vec2 at = UV * frame;
	vec4 painted = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		vec3 color = mix(colors[i].rgb, gel, tinted[i]);
		float reach = length((at - centres[i]) / radii[i]);
		float alpha = colors[i].a * clamp(1.0 - reach / stops[i], 0.0, 1.0);
		painted = vec4(color * alpha, alpha) + painted * (1.0 - alpha);
	}
	// A fixed pattern per pixel, from -0.5 to 0.5 of a level.
	float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
	COLOR = vec4(painted.rgb + dither / 255.0 * painted.a, painted.a);
}
