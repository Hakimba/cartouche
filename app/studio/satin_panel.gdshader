// SPDX-License-Identifier: GPL-3.0-or-later
// A Studio material (SatinPanel): a rounded box filled with a gradient, its CSS box-shadows around it (Gaussian,
// standard deviation blur / 2, cut out under the box as CSS does) and its inset shadows inside it. Drawn once on a
// quad that covers the box and its shadows; nothing here moves with time.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// The box, in the quad's own pixels.
uniform vec2 box_position;
uniform vec2 box_size;
uniform float radius;
// The fill: up to four stops; a radial fill from its centre (parts of the box) to the farthest corner, or a
// fill from top to bottom when the centre is negative.
uniform int stop_count = 2;
uniform float stops[4];
uniform vec4 colors[4];
uniform vec2 centre = vec2(-1.0);
// Shadows as (x, y, blur, spread) and colour, the insets first, each group in CSS order (the first on top).
uniform int inset_count = 0;
uniform int shadow_count = 0;
uniform vec4 shadow_shapes[4];
uniform vec4 shadow_colors[4];

varying vec2 position;

void vertex() {
	position = VERTEX;
}

float box_distance(vec2 point, vec2 corner, vec2 size, float round_by) {
	vec2 half_size = size * 0.5;
	float r = clamp(round_by, 0.0, min(half_size.x, half_size.y));
	vec2 q = abs(point - corner - half_size) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float coverage(vec2 point, vec2 corner, vec2 size, float round_by) {
	return clamp(0.5 - box_distance(point, corner, size, round_by), 0.0, 1.0);
}

vec2 erf2(vec2 x) {
	vec2 s = sign(x);
	vec2 a = abs(x);
	x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	x *= x;
	return s - s / (x * x);
}

// A rounded box blurred by a Gaussian of standard deviation sigma: exact along x (erf), integrated along y.
float blurred(vec2 point, vec2 corner, vec2 size, float round_by, float sigma) {
	if (sigma < 0.01) {
		return coverage(point, corner, size, round_by);
	}
	vec2 half_size = size * 0.5;
	float r = clamp(round_by, 0.0, min(half_size.x, half_size.y));
	point -= corner + half_size;
	float start = clamp(-3.0 * sigma, point.y - half_size.y, point.y + half_size.y);
	float end = clamp(3.0 * sigma, point.y - half_size.y, point.y + half_size.y);
	float step = (end - start) / 8.0;
	float y = start + step * 0.5;
	float value = 0.0;
	for (int i = 0; i < 8; i++) {
		float delta = min(half_size.y - r - abs(point.y - y), 0.0);
		float curved = half_size.x - r + sqrt(max(0.0, r * r - delta * delta));
		vec2 integral = 0.5 + 0.5 * erf2((point.x + vec2(-curved, curved)) * (sqrt(0.5) / sigma));
		value += (integral.y - integral.x) * exp(-(y * y) / (2.0 * sigma * sigma)) / (2.5066283 * sigma) * step;
		y += step;
	}
	return value;
}

vec4 fill_at(vec2 point) {
	float t;
	if (centre.x < 0.0) {
		t = (point.y - box_position.y) / box_size.y;
	} else {
		vec2 from = box_position + centre * box_size;
		vec2 far = max(abs(box_position - from), abs(box_position + box_size - from));
		t = length(point - from) / length(far);
	}
	vec4 color = colors[0];
	for (int i = 1; i < stop_count; i++) {
		color = mix(color, colors[i], clamp((t - stops[i - 1]) / max(stops[i] - stops[i - 1], 1e-5), 0.0, 1.0));
	}
	return color;
}

vec4 over(vec4 below, vec4 color, float alpha) {
	float a = color.a * alpha;
	return vec4(color.rgb * a, a) + below * (1.0 - a);
}

void fragment() {
	float inside = coverage(position, box_position, box_size, radius);
	vec4 painted = vec4(0.0);
	for (int i = shadow_count - 1; i >= inset_count; i--) {
		vec4 shape = shadow_shapes[i];
		vec2 grown = vec2(shape.w);
		float cast = blurred(position, box_position + shape.xy - grown, box_size + 2.0 * grown, radius + shape.w, shape.z / 2.0);
		painted = over(painted, shadow_colors[i], cast * (1.0 - inside));
	}
	painted = over(painted, fill_at(position), inside);
	for (int i = inset_count - 1; i >= 0; i--) {
		vec4 shape = shadow_shapes[i];
		vec2 shrunk = vec2(shape.w);
		float lit = blurred(position, box_position + shape.xy + shrunk, box_size - 2.0 * shrunk, radius - shape.w, shape.z / 2.0);
		painted = over(painted, shadow_colors[i], (1.0 - lit) * inside);
	}
	// COLOR comes in as the item's modulate: a fading panel fades its material too.
	COLOR = vec4(painted.rgb * COLOR.rgb, painted.a) * COLOR.a;
}
