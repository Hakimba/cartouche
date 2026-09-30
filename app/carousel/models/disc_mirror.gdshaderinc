// SPDX-License-Identifier: GPL-3.0-or-later
// The underside of an optical disc: a dark mirror seen through clear plastic, whose circular
// grooves split the light into a rainbow streak that turns as the disc moves. The grooves act as a
// reflection grating: light leaves along the grooves' direction as from a mirror (the streak), and
// across them at the angles where the spacing matches a wavelength (its colours). The mesh's
// tangents follow the grooves, and its vertex colour's red is 1 on the recorded area.
// Included by disc_mirror.gdshader, and by disc_mirror_fading.gdshader with FADING defined.

#ifdef FADING
// How faded the model is, from 0 (opaque) to 1 (gone), set per model (see ModelFade).
instance uniform float fade = 0.0;
#endif
uniform vec3 mirror_color : source_color = vec3(0.5, 0.51, 0.54);
// The recorded area looks darker than the bare mirror around it.
uniform vec3 recorded_color : source_color = vec3(0.36, 0.36, 0.39);
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
// Distance between grooves: 740 nm on a DVD, 1600 nm on a CD.
uniform float groove_spacing_nm = 740.0;
// Width of the streak along the grooves, and brightness of its colours.
uniform float streak_width = 0.12;
uniform float rainbow = 0.55;

varying vec3 grooves;
varying float recorded;

// Approximate colour of light of wavelength [nm] (Zucconi's six-bump fit of the visible spectrum).
vec3 spectrum(float nm) {
	float x = clamp((nm - 400.0) / 300.0, 0.0, 1.0);
	vec3 a = vec3(3.54585104, 2.93225262, 2.41593945) * (x - vec3(0.69549072, 0.49228336, 0.27699880));
	vec3 b = vec3(3.90307140, 3.21182957, 3.96587128) * (x - vec3(0.11748627, 0.86755042, 0.66077860));
	return clamp(1.0 - a * a - vec3(0.02312639, 0.15225084, 0.52607955), 0.0, 1.0)
		+ clamp(1.0 - b * b - vec3(0.84897130, 0.88445281, 0.73949448), 0.0, 1.0);
}

void fragment() {
	recorded = COLOR.r;
	ALBEDO = mix(mirror_color, recorded_color, recorded);
	METALLIC = 1.0;
	ROUGHNESS = roughness;
	// The polycarbonate over the mirror reflects too.
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.03;
	grooves = TANGENT;
#ifdef FADING
	ALPHA = 1.0 - fade;
#endif
}

void light() {
	vec3 along_grooves = normalize(grooves);
	vec3 across = normalize(cross(NORMAL, along_grooves));
	vec3 half_way = normalize(LIGHT + VIEW);
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	// Mirror-like along the grooves: bright only where the half vector is across them.
	float along = dot(half_way, along_grooves) / streak_width;
	float streak = exp(-along * along) * lit;
	// Across the grooves, order m sends wavelength spacing * |sin in + sin out| / m this way.
	float sines = abs(dot(LIGHT + VIEW, across));
	vec3 colours = vec3(0.0);
	for (int order = 1; order <= 3; order++) {
		colours += spectrum(groove_spacing_nm * sines / float(order));
	}
	// Only the streak: the lamp itself is never mirrored (its round spot looks like a light bulb).
	SPECULAR_LIGHT += LIGHT_COLOR * streak * colours * rainbow * mix(0.35, 1.0, recorded);
}
