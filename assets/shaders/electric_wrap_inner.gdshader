shader_type canvas_item;

uniform vec4 edge_color_a : source_color = vec4(1, 1, 1.0, 1.0);
uniform vec4 edge_color_b : source_color = vec4(1, 1, 1.0, 1.0);
uniform vec4 inner_color_a : source_color = vec4(1, 1, 1.0, 1.0);
uniform vec4 inner_color_b : source_color = vec4(1, 1, 1.0, 1.0);

uniform float edge_px : hint_range(0.5, 8.0) = 3.819;
uniform float edge_strength : hint_range(0.0, 4.0) = 2.077;
uniform float inner_strength : hint_range(0.0, 3.0) = 1.641;

uniform float speed : hint_range(0.0, 8.0) = 2.327;
uniform float edge_noise_scale : hint_range(1.0, 120.0) = 48.0;
uniform float inner_noise_scale : hint_range(1.0, 120.0) = 1;
uniform float pulse : hint_range(0.0, 1.0) = 1;
uniform float inner_threshold : hint_range(0.0, 1.0) = 0.5;
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

	float t = TIME * speed;
	float edge_n = noise2d(UV * edge_noise_scale + vec2(t, -t * 0.63));
	float flicker = 0.7 + pulse * sin(TIME * (8.0 + speed * 2.0) + UV.y * 36.0 + edge_n * 10.0);
	float edge_bolt = smoothstep(0.42, 1.0, edge_n * flicker);
	float edge_glow = edge * edge_bolt * edge_strength;

	float inner_n1 = noise2d(UV * inner_noise_scale + vec2(-t * 0.72, t * 0.55));
	float inner_n2 = noise2d(UV * (inner_noise_scale * 1.7) + vec2(t * 1.2, -t * 0.8));
	float inner_mix = inner_n1 * 0.65 + inner_n2 * 0.35;
	float inner_line = smoothstep(inner_threshold, 1.0, inner_mix);
	float inner_pulse = 0.6 + 0.4 * sin(TIME * (6.0 + speed) + UV.x * 24.0 + inner_mix * 8.0);
	float inner_glow = inner_line * inner_pulse * inner_strength * a;

	vec3 edge_col = mix(edge_color_a.rgb, edge_color_b.rgb, edge_n);
	vec3 inner_col = mix(inner_color_a.rgb, inner_color_b.rgb, inner_mix);
	vec3 rgb = tex.rgb + edge_col * edge_glow + inner_col * inner_glow;

	float fx_alpha = max(
		edge_glow * max(edge_color_a.a, edge_color_b.a),
		inner_glow * max(inner_color_a.a, inner_color_b.a)
	);
	float out_a = max(a, fx_alpha);

	if (out_a < alpha_cutoff) {
		discard;
	}

	COLOR = vec4(rgb, out_a);
}
