// SPDX-License-Identifier: GPL-3.0-or-later
// The underside of a disc being faded (see ModelFade): drawn with the transparent ones, its depth
// still written so that it hides what is behind it.
shader_type spatial;
render_mode depth_draw_always;

#define FADING
#include "res://carousel/models/disc_mirror.gdshaderinc"
