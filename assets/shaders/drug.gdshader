shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float wobble_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float color_speed : hint_range(0.1, 5.0) = 1.5;
uniform float color_intensity : hint_range(0.0, 1.0) = 0.3;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    float time = TIME * time_scale;

    // Wobbly distortion
    vec2 wobble = vec2(
        sin(UV.y * 15.0 + time * 2.0) * wobble_intensity,
        cos(UV.x * 12.0 + time * 1.7) * wobble_intensity
    );

    // Additional wave distortion
    wobble += vec2(
        sin(UV.x * 8.0 + UV.y * 6.0 + time * 3.0) * wobble_intensity * 0.5,
        cos(UV.y * 10.0 - UV.x * 4.0 + time * 2.5) * wobble_intensity * 0.5
    );

    vec2 distorted_uv = SCREEN_UV + wobble;
    vec3 color = texture(screen_texture, distorted_uv).rgb;

    // Cycling rainbow tint
    float hue_shift = time * color_speed;

    // Create shifting color overlays
    vec3 tint1 = vec3(
        sin(hue_shift) * 0.5 + 0.5,
        sin(hue_shift + 2.094) * 0.5 + 0.5,  // +120 degrees
        sin(hue_shift + 4.189) * 0.5 + 0.5   // +240 degrees
    );

    // Second tint with different phase for more chaos
    vec3 tint2 = vec3(
        cos(hue_shift * 0.7 + UV.x * 3.0) * 0.5 + 0.5,
        cos(hue_shift * 0.7 + UV.y * 3.0 + 2.094) * 0.5 + 0.5,
        cos(hue_shift * 0.7 + 4.189) * 0.5 + 0.5
    );

    vec3 combined_tint = mix(tint1, tint2, 0.5);

    // Apply tint while preserving some of original color
    color = mix(color, color * combined_tint * 1.5, color_intensity);

    // Slight pulsing brightness
    float pulse = sin(time * 4.0) * 0.05 + 1.0;
    color *= pulse;

    COLOR = vec4(color, 1.0);
}
