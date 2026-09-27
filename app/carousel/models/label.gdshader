// SPDX-License-Identifier: GPL-3.0-or-later
// A game's label printed on a model's face, under a varnish. Every model's `Label` mesh uses this
// shader: the carousel sets `label_texture` (and `has_label` once it is drawn). The texture covers
// the mesh's UV square: a disc's whole face, or a cartridge's label.
//
// The light shows the surface as it moves: a fine grain, circular grooves on a disc, and the grey
// parts of a printed label shining like the bare metal they usually are.
shader_type spatial;

uniform sampler2D label_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_label = false;
// Whether the label is an image of a real one, rather than drawn from the game's title.
uniform bool scanned = false;
uniform vec3 blank_color : source_color = vec3(0.92);
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
// How much the clear varnish over the print reflects.
uniform float varnish : hint_range(0.0, 1.0) = 0.7;
// How much the grey, unprinted-looking parts of an image shine like metal.
uniform float silver : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.15;
// Circular grooves around the centre of the UV square, as on a disc; 0 for none.
uniform float grooves : hint_range(0.0, 1.0) = 0.0;
// How many, from the centre to the edge.
uniform float groove_count = 60.0;

float hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 colour = has_label ? texture(label_texture, UV).rgb : blank_color;
	float light = dot(colour, vec3(0.299, 0.587, 0.114));
	float saturation = max(colour.r, max(colour.g, colour.b)) - min(colour.r, min(colour.g, colour.b));
	float metal = (has_label && scanned) ? silver * (1.0 - smoothstep(0.05, 0.14, saturation)) * smoothstep(0.35, 0.55, light) * (1.0 - smoothstep(0.88, 0.97, light)) : 0.0;
	ALBEDO = colour;
	METALLIC = metal;
	ROUGHNESS = mix(roughness, 0.15, metal);
	CLEARCOAT = varnish;
	CLEARCOAT_ROUGHNESS = 0.08;
	// The grain and grooves only tilt the surface, fading where they get finer than a pixel.
	vec2 cells = UV * 180.0;
	vec2 bump = (vec2(hash(floor(cells)), hash(floor(cells) + 17.0)) - 0.5) * grain;
	bump *= 1.0 - smoothstep(0.4, 1.0, max(fwidth(cells.x), fwidth(cells.y)));
	// A disc's tangents go round it: across the grooves is the binormal.
	float ring = length(UV - 0.5) * 2.0 * groove_count;
	bump.y += sin(ring * TAU) * grooves * 0.35 * (1.0 - smoothstep(0.3, 0.8, fwidth(ring)));
	NORMAL_MAP = normalize(vec3(bump, 1.0)) * 0.5 + 0.5;
}
