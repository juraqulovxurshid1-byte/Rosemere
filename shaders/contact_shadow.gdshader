shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never;

uniform float softness : hint_range(0.0, 2.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec2 centered = UV - vec2(0.5);
    float dist = length(centered) * 2.0;
    float alpha = 1.0 - smoothstep(0.0, 1.0 + softness, dist);
    alpha *= opacity;
    ALBEDO = shadow_color.rgb;
    ALPHA = alpha;
}
