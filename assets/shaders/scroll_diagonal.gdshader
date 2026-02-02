shader_type canvas_item;

uniform float speed : hint_range(0.0, 1.0) = 0.05;
uniform vec2 scale = vec2(3.0, 3.0);
uniform sampler2D tex : source_color, repeat_enable;

// Color adjustments
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 3.0) = 1.0;
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float gamma : hint_range(0.1, 3.0) = 1.0;
uniform float exposure : hint_range(-3.0, 3.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 scroll = vec2(TIME, -TIME) * speed;
	vec2 uv = UV * scale + scroll;
	vec4 col = texture(tex, uv);
	
	// Tint
	col.rgb *= tint.rgb;
	col.a *= tint.a;
	
	// Exposure (before other adjustments)
	col.rgb *= pow(2.0, exposure);
	
	// Brightness
	col.rgb *= brightness;
	
	// Contrast (around 0.5 midpoint)
	col.rgb = (col.rgb - 0.5) * contrast + 0.5;
	
	// Saturation
	float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(luma), col.rgb, saturation);
	
	// Hue shift
	vec3 hsv = rgb_to_hsv(col.rgb);
	hsv.x = fract(hsv.x + hue_shift);
	col.rgb = hsv_to_rgb(hsv);
	
	// Gamma
	col.rgb = pow(col.rgb, vec3(1.0 / gamma));
	
	COLOR = col;
}
