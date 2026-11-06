// SPDX-License-Identifier: GPL-3.0-or-later
// The rail's mask (the design's `mask-image`), shared by the tiles' group and the reflections' group: across the
// rail, 0 up to the ramp's first x, rising linearly to 1 at its second, 1 to its third, falling linearly to 0 at its
// fourth. The rail sets the ramp (ConsoleRail.MASK, opened on a wider screen or for a strip). Each group is one
// backbuffer copy: two for the rail, a cost to look at when the optimisations come.
uniform vec4 ramp;

float rail_across(float x) {
	return clamp((x - ramp.x) / (ramp.y - ramp.x), 0.0, 1.0) * clamp((ramp.w - x) / (ramp.w - ramp.z), 0.0, 1.0);
}
