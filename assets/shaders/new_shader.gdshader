shader_type canvas_item;
// shader by Pcniado, modified for sprite alpha masking

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform float u_distortion_intensity : hint_range(0.0, 2.0) = 1.8;
uniform float u_blur_intensity : hint_range(0.0, 3.0) = 2.0;

vec3 get_blurred_color(sampler2D tex, vec2 screen_uv, vec2 pixel_size, float blur_radius) {
    vec3 color = vec3(0.0);
    float total_weight = 0.0;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_radius * pixel_size;
            float weight = exp(-0.5 * (float(x*x + y*y)) / 2.0);

            color += texture(tex, screen_uv + offset).rgb * weight;
            total_weight += weight;
        }
    }
    return color / total_weight;
}

void fragment() {
    // Sample the original sprite texture to get alpha
    vec4 sprite_color = texture(TEXTURE, UV);
    float sprite_alpha = sprite_color.a;
    
    // Discard transparent pixels
    if (sprite_alpha < 0.1) {
        discard;
    }
    
    // Calculate distortion based on UV position relative to center
    vec2 center_offset = UV - 0.5;
    float dist_from_center = length(center_offset);
    vec2 normalized_dir = normalize(center_offset + vec2(0.001)); // avoid div by zero
    
    // Create glass distortion effect
    float distortion = dist_from_center * u_distortion_intensity * 0.1;
    vec2 screen_uv_offset = normalized_dir * distortion * SCREEN_PIXEL_SIZE * 50.0;
    vec2 target_uv = SCREEN_UV - screen_uv_offset;
    
    // Blur based on distance from edge (use sprite alpha for edge detection)
    float edge_factor = smoothstep(0.1, 0.5, sprite_alpha);
    float current_blur_radius = u_blur_intensity * (1.0 - edge_factor * 0.5);
    
    // Chromatic aberration at edges
    vec2 chromatic_shift = normalized_dir * (1.0 - edge_factor) * 3.0 * SCREEN_PIXEL_SIZE;

    float r = get_blurred_color(screen_texture, target_uv - chromatic_shift, SCREEN_PIXEL_SIZE, current_blur_radius).r;
    float g = get_blurred_color(screen_texture, target_uv, SCREEN_PIXEL_SIZE, current_blur_radius).g;
    float b = get_blurred_color(screen_texture, target_uv + chromatic_shift, SCREEN_PIXEL_SIZE, current_blur_radius).b;

    vec3 glass_color = vec3(r, g, b);
    glass_color *= 0.85; // Slight darkening for glass effect
    
    // Use sprite alpha for final output
    COLOR = vec4(glass_color, sprite_alpha);
}
