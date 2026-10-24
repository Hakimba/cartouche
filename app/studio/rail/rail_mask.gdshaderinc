// SPDX-License-Identifier: GPL-3.0-or-later
// The rail's mask (the design's `mask-image`), shared by the tiles' group and the reflections' group: across the
// 1280-wide frame, 0 up to the ramp's first x, rising linearly to 1 at its second, 1 to its third, falling
// linearly to 0 at its fourth. Each group is one backbuffer copy: two for the rail, a cost to look at when the
// optimisations come.
float rail_across(float x, vec4 ramp) {
	return clamp((x - ramp.x) / (ramp.y - ramp.x), 0.0, 1.0) * clamp((ramp.w - x) / (ramp.w - ramp.z), 0.0, 1.0);
}
