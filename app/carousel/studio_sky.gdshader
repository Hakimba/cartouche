// SPDX-License-Identifier: GPL-3.0-or-later
// What the models reflect: a soft grey studio with a few bright panels behind the camera, like a
// photo shoot. It is never drawn, only reflected, and is computed over the first frames.
shader_type sky;

uniform vec3 ground : source_color = vec3(0.42, 0.42, 0.45);
uniform vec3 horizon : source_color = vec3(0.62, 0.63, 0.66);
uniform vec3 ceiling : source_color = vec3(0.8, 0.81, 0.84);
uniform float panel_energy = 3.0;

// A bright panel facing [towards], [size] wide and high (in radians, roughly), soft at its edges.
float panel(vec3 eye, vec3 towards, vec2 size) {
	vec3 centre = normalize(towards);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), centre));
	vec3 up = cross(centre, side);
	float facing = dot(eye, centre);
	vec2 at = vec2(dot(eye, side), dot(eye, up)) / max(facing, 0.001);
	// Soft all the way in: a panel reflects as a glow, not as a lamp.
	vec2 edge = 1.0 - smoothstep(size * 0.3, size, abs(at));
	return facing > 0.0 ? edge.x * edge.y : 0.0;
}

void sky() {
	float height = EYEDIR.y;
	vec3 colour = height < 0.0 ? mix(horizon, ground, smoothstep(0.0, 0.6, -height))
		: mix(horizon, ceiling, smoothstep(0.0, 0.7, height));
	// The key panel sits where the camera sees the selected game's face reflected: its slow sway
	// takes the reflection across the label.
	float lights = panel(EYEDIR, vec3(0.55, 0.45, 0.7), vec2(0.4, 0.28))
		+ 0.5 * panel(EYEDIR, vec3(-0.6, 0.35, 0.7), vec2(0.2, 0.35))
		+ 0.8 * panel(EYEDIR, vec3(0.0, 0.95, 0.3), vec2(0.6, 0.08));
	COLOR = colour + lights * panel_energy;
}
