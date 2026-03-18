shader_type canvas_item;

group_uniforms Grain;
uniform float grain_size : hint_range(0.05, 2.0, 0.01) = 0.2;
uniform float contrast : hint_range(1.0, 100.0, 0.1) = 40.0;
uniform float opacity : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float speed : hint_range(0.0, 5.0, 0.01) = 1.0;

void fragment() {
	vec2 scaled_uv = UV * grain_size;
	float noise = fract(sin(dot(scaled_uv, vec2(12.9898, 78.233) * TIME * speed)) * 438.5453) * 1.9;
	float grain = clamp(pow(noise, contrast), 0.0, 1.0);
	COLOR.a *= grain * opacity;
}
