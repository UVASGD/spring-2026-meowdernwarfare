shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float feather : hint_range(0.0, 1) = 0.1;
uniform int direction : hint_enum("Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top") = 0;
uniform bool use_texture = false;
uniform sampler2D custom_texture : hint_default_white;
uniform vec2 frame_size = vec2(1920.0, 1080.0);
uniform int frame_count = 1;
uniform int frame_index = 0;

void fragment() {
	float coord;
	if (direction == 0) {
		coord = UV.x; // Left to right
	} else if (direction == 1) {
		coord = 1.0 - UV.x; // Right to left
	} else if (direction == 2) {
		coord = UV.y; // Top to bottom
	} else {
		coord = 1.0 - UV.y; // Bottom to top
	}
	
	float alpha;
	if (feather <= 0.0001) {
		// Hard wipe when feather is zero.
		alpha = 1.0 - step(progress, coord);
	} else {
		float edge0 = progress - feather;
		float edge1 = progress + feather;
		alpha = 1.0 - smoothstep(edge0, edge1, coord);
	}
	
	int clamped_index = clamp(frame_index, 0, max(frame_count - 1, 0));
	vec2 tex_size = vec2(textureSize(custom_texture, 0));
	vec2 safe_frame = max(frame_size, vec2(1.0));
	float cols_f = max(1.0, floor(tex_size.x / safe_frame.x));
	float col = mod(float(clamped_index), cols_f);
	float row = floor(float(clamped_index) / cols_f);
	vec2 frame_origin = vec2(col * safe_frame.x, row * safe_frame.y);
	vec2 frame_uv = (frame_origin + UV * safe_frame) / tex_size;
	
	if (use_texture) {
		vec4 tex_color = texture(custom_texture, frame_uv);
		COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, alpha);
	}
}
