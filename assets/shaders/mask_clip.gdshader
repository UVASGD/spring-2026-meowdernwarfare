shader_type canvas_item;

uniform sampler2D mask : hint_default_white;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float mask_alpha = texture(mask, UV).a;
	col.a *= mask_alpha;
	COLOR = col;
}
