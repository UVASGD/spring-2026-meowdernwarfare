shader_type canvas_item;

uniform float speed = 50.0;
uniform float text_width = 500.0;

void fragment() {
	float offset = mod(TIME * speed, text_width);
	vec2 uv = UV;
	uv.x = fract(uv.x + offset / text_width);
	COLOR = texture(TEXTURE, uv);
}
