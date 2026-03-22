shader_type canvas_item;

// Burn-away overlay effect
// progress: 1.0 = fully covered (black), 0.0 = fully burned away (transparent)
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform vec4 edge_color_inner : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform sampler2D noise_texture : hint_default_white;
uniform float noise_scale : hint_range(0.1, 5.0) = 1.0;
uniform float alpha_cutoff : hint_range(0.0, 0.2) = 0.01;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	if (base_color.a < alpha_cutoff) {
		discard;
	}
	float noise_val = texture(noise_texture, UV * noise_scale).r;
	
	// Burn threshold - as progress decreases, more gets burned away
	float burn_threshold = progress;
	float diff = noise_val - burn_threshold;
	
	if (diff > edge_width) {
		// Fully burned away - transparent
		COLOR = vec4(0.0);
	} else if (diff > 0.0) {
		// Burning edge - glowing effect
		float edge_progress = diff / edge_width;
		
		// Inner edge (closer to burned area) is hotter
		vec4 glow = mix(edge_color, edge_color_inner, edge_progress);
		COLOR = vec4(glow.rgb, glow.a * base_color.a);
	} else {
		// Not yet burned - show overlay color
		COLOR = base_color;
	}
}
