shader_type canvas_item;

uniform float flash_speed : hint_range(1.0, 20.0) = 8.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.85;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    float time = TIME;
    vec3 color = texture(screen_texture, SCREEN_UV).rgb;

    float flash = abs(sin(time * flash_speed)) * 0.5 + 0.5;
    float flash2 = abs(cos(time * flash_speed * 1.3 + 1.0)) * 0.4 + 0.3;

    vec3 white_flash = vec3(flash * 1.2, flash2 * 1.1, flash * 0.9);

    float applied = intensity * fade;
    color = mix(color, white_flash, applied);

    COLOR = vec4(color, 1.0);
}
