// SPDX-License-Identifier: GPL-3.0-or-later
// A plain surface of one colour: plastic, rubber, metal, a varnished shell, a lit diode. The models'
// plain parts all use it rather than standard materials, whose every combination of features is a
// shader of its own: on handhelds, each shader and its fading copy hold megabytes in the graphics
// driver. Included by solid.gdshader, and by solid_fading.gdshader with FADING defined.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
// A clear varnish over it, as on a console's shell; none at 0.
uniform float clearcoat : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.5;
// The light it gives, as a diode's; none when black.
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
#ifdef FADING
// How faded the model is, from 0 (opaque) to 1 (gone), set per model (see ModelFade).
instance uniform float fade = 0.0;
#endif

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	EMISSION = emission.rgb * emission_energy;
#ifdef FADING
	ALPHA = 1.0 - fade;
#endif
}
