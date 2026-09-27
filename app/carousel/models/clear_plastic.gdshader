// SPDX-License-Identifier: GPL-3.0-or-later
// Clear plastic, such as a disc's hub and rim: what is behind shows through, greyed, while the
// surface still reflects the light, more and more at grazing angles. Its edges (the faces along
// the axis, Z) and the rim (where the vertex colour's green is 1) look darker, as light bounces
// inside the plastic before leaving it.
shader_type spatial;
render_mode blend_premul_alpha, depth_draw_opaque;

uniform vec3 tint : source_color = vec3(0.5, 0.51, 0.54);
uniform vec3 edge_tint : source_color = vec3(0.22, 0.23, 0.25);
// How much of what is behind is hidden, looking straight at a face, and at an edge.
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;

varying float edge;

void vertex() {
	edge = max(1.0 - abs(NORMAL.z), COLOR.g);
}

void fragment() {
	float grazing = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALPHA = mix(mix(opacity, 0.85, grazing), edge_opacity, edge);
	// Premultiplied: the reflections added by the lights stay whole where the plastic is clear.
	ALBEDO = mix(tint, edge_tint, edge) * ALPHA;
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
}
