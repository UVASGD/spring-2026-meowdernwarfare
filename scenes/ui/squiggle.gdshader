shader_type canvas_item;
render_mode world_vertex_coords;

group_uniforms Squiggle;
/**
 * Noise texture scale
 * By default, the noise texture's size in world coordinates is set by its resolution
*/
uniform vec2 scale = vec2(1.0);
uniform float strength = 1.0;
/**
 * Number of squiggle frames per second
*/
uniform float fps = 6.0;
uniform sampler2D noise : filter_linear, repeat_enable;
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 edge_color_inner : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float burn_noise_scale : hint_range(0.1, 5.0) = 1.0;
uniform float alpha_cutoff : hint_range(0.0, 0.2) = 0.01;
group_uniforms;

varying vec4 modulate;
varying vec2 noise_uv;

void vertex() {
	modulate = COLOR;

	// Use world coordinates for scale-independent squiggles, offset by position to keep pattern attached to object
	noise_uv = (VERTEX - MODEL_MATRIX[3].xy) / (vec2(textureSize(noise, 0)) * scale);
}

// Use irrational constants for unique squiggles every frame
#define offset_multiplier vec2(PI, E)

void fragment() {
	vec2 noise_offset = vec2(floor(TIME * fps)) * offset_multiplier;
	float noise_sample = texture(noise, noise_uv + noise_offset).r * 4.0 * PI;
	vec2 direction = vec2(cos(noise_sample), sin(noise_sample));
	vec2 squiggle_uv = UV + direction * strength * 0.005;
	vec4 base_color = texture(TEXTURE, squiggle_uv) * modulate;
	if (base_color.a < alpha_cutoff) {
		discard;
	}

	float burn_noise = texture(noise, UV * burn_noise_scale + noise_offset * 0.013).r;
	float diff = burn_noise - progress;
	if (diff > edge_width) {
		COLOR = vec4(0.0);
	} else if (diff > 0.0) {
		float t = diff / edge_width;
		vec4 glow = mix(edge_color, edge_color_inner, t);
		COLOR = vec4(glow.rgb, glow.a * base_color.a);
	} else {
		COLOR = base_color;
	}
}
