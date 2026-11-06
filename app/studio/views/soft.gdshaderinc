// SPDX-License-Identifier: GPL-3.0-or-later
// The softness the Studio draws its neighbours with, shared by the 2D layers that blur a view (MediaView,
// ContactShadow, ConsoleLayer) and by the models' materials, which grey a medium drawn in the app's own world.

// [colour] greyed towards its luminance as CSS saturate([amount]) does: 1 untouched, 0 grey.
vec3 saturated(vec3 colour, float amount) {
	return mix(vec3(dot(colour, vec3(0.2126, 0.7152, 0.0722))), colour, amount);
}
