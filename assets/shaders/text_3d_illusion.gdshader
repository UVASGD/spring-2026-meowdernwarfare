shader_type canvas_item;

uniform float scale_left : hint_range(0.1, 3.0) = 1.3;
uniform float scale_right : hint_range(0.1, 3.0) = 0.8;
uniform float skew : hint_range(-1.0, 1.0) = 0.15;

void fragment() {
	vec2 uv = UV;
	
	// Calculate scale factor based on X position (left=big, right=small)
	float scale = mix(scale_left, scale_right, uv.x);
	
	// Scale Y around center (0.5)
	uv.y = 0.5 + (uv.y - 0.5) / scale;
	
	// Add skew (vertical offset based on x position)
	uv.y += (uv.x - 0.5) * skew;
	
	// Sample with bounds check
	vec4 col = texture(TEXTURE, uv);
	if (uv.y < 0.0 || uv.y > 1.0) {
		col.a = 0.0;
	}
	
	COLOR = col;
}
