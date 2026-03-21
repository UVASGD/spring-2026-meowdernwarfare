shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(-0.2, 1.2) = 0.0;
uniform float feather : hint_range(0.0, 1) = 0.1;
uniform int direction : hint_enum("Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top") = 0;
uniform sampler2D custom_texture : hint_default_white;
uniform bool use_texture = false;

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
	
	float edge0 = progress - feather;
	float edge1 = progress + feather;
	float alpha = 1.0 - smoothstep(edge0, edge1, coord);
	
	if (use_texture) {
		vec4 tex_color = texture(custom_texture, UV);
		COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, alpha);
	}
}
