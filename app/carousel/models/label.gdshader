// SPDX-License-Identifier: GPL-3.0-or-later
// A game's label printed on a model's face. Every model's `Label` mesh uses this shader: the
// carousel sets `label_texture` (and `has_label` once it is drawn). Round labels leave out what
// lies outside the ring of a disc, and darken its centre hole.
shader_type spatial;

uniform sampler2D label_texture : source_color, filter_linear_mipmap;
uniform bool has_label = false;
uniform vec3 blank_color : source_color = vec3(0.35, 0.37, 0.42);
uniform bool round = false;
// As fractions of the face's half width.
uniform float outer_radius = 0.97;
uniform float inner_radius = 0.3;
uniform float hole_radius = 0.12;

void fragment() {
	vec3 color = has_label ? texture(label_texture, UV).rgb : blank_color;
	if (round) {
		float r = length(UV - 0.5) * 2.0;
		if (r > outer_radius) {
			discard;
		}
		if (r < inner_radius) {
			// The clear hub around the hole, then the hole itself.
			color = r < hole_radius ? vec3(0.08) : vec3(0.82, 0.84, 0.88);
		}
	}
	ALBEDO = color;
	ROUGHNESS = 0.55;
}
