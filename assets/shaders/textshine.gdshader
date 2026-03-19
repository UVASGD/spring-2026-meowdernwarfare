shader_type canvas_item;

uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shine_progress : hint_range(0.0, 10.0, 0.001) = 0.0;
uniform float shine_size : hint_range(0.01, 1.0, 0.01) = 0.1;
uniform float shine_angle : hint_range(0.0, 360.0, 0.1) = 45.0; 

// Must be set via GDScript!
uniform vec2 text_size = vec2(100.0, 100.0); 

varying vec2 pixel_pos;

void vertex() {
	// Capture absolute pixel position
	pixel_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 original_color = tex * COLOR;
	// 1. Normalize position based on label size (0.0 to 1.0)
	vec2 box_uv = pixel_pos / text_size;
	
	// 2. Calculate Direction Vector
    float rad = radians(shine_angle);
    vec2 dir = vec2(cos(rad), sin(rad));
    float projection = dot(box_uv, dir);;
	
	// 4. Calculate dynamic boundaries
	// We project all 4 corners of the box to find the exact start/end for this angle
	float p1 = dot(vec2(0.0, 0.0), dir);
	float p2 = dot(vec2(1.0, 0.0), dir);
	float p3 = dot(vec2(0.0, 1.0), dir);
	float p4 = dot(vec2(1.0, 1.0), dir);
	
	float min_dist = min(min(p1, p2), min(p3, p4));
	float max_dist = max(max(p1, p2), max(p3, p4));
	
	// 5. Map progress to these bounds
	// We subtract shine_size from start so it begins completely invisible
	float current_pos = mix(min_dist - shine_size, max_dist, shine_progress);
	
	// 6. Create the band
	float shine = step(current_pos, projection) - step(current_pos + shine_size, projection);
	
	COLOR = original_color;
	COLOR.rgb = mix(COLOR.rgb, shine_color.rgb, shine * shine_color.a);
}
