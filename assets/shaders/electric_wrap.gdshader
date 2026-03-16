shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.20, 0.95, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.75, 0.35, 1.0, 1.0);
uniform float edge_px : hint_range(0.5, 8.0) = 2.2;
uniform float glow_strength : hint_range(0.0, 4.0) = 1.4;
uniform float speed : hint_range(0.0, 8.0) = 1.5;
uniform float noise_scale : hint_range(1.0, 120.0) = 48.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.35;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 edge_color_inner : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float alpha_cutoff : hint_range(0.0, 0.2) = 0.01;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	float a = tex.a;
	vec2 px = TEXTURE_PIXEL_SIZE * edge_px;

	float max_a = 0.0;
	float min_a = 1.0;
	vec2 dirs[8] = vec2[](
		vec2(1.0, 0.0), vec2(-1.0, 0.0),
		vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(0.707, 0.707), vec2(-0.707, 0.707),
		vec2(0.707, -0.707), vec2(-0.707, -0.707)
	);

	for (int i = 0; i < 8; i++) {
		float sa = texture(TEXTURE, UV + dirs[i] * px).a;
		max_a = max(max_a, sa);
		min_a = min(min_a, sa);
	}

	float edge_outer = clamp(max_a - a, 0.0, 1.0);
	float edge_inner = clamp(a - min_a, 0.0, 1.0);
	float edge = max(edge_outer, edge_inner * 0.6);

	float n = noise2d(UV * noise_scale + vec2(TIME * speed, -TIME * speed * 0.63));
	float flicker = 0.7 + pulse * sin(TIME * (8.0 + speed * 2.0) + UV.y * 36.0 + n * 10.0);
	float bolt = smoothstep(0.42, 1.0, n * flicker);
	float glow = edge * bolt * glow_strength;

	vec3 electric = mix(color_a.rgb, color_b.rgb, n);
	vec3 rgb = tex.rgb + electric * glow;
	float out_a = max(a, glow * max(color_a.a, color_b.a));

	if (out_a < alpha_cutoff) {
		discard;
	}
	float diff = n - progress;
	if (diff > edge_width) {
		COLOR = vec4(0.0);
	} else if (diff > 0.0) {
		float t = diff / edge_width;
		vec4 glow = mix(edge_color, edge_color_inner, t);
		COLOR = vec4(glow.rgb, glow.a * out_a);
	} else {
		COLOR = vec4(rgb, out_a);
	}
}
