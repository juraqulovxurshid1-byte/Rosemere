shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 cobble_color1 : source_color = vec4(0.18, 0.16, 0.15, 1.0);
uniform vec4 cobble_color2 : source_color = vec4(0.14, 0.12, 0.11, 1.0);
uniform vec4 cobble_color3 : source_color = vec4(0.22, 0.19, 0.17, 1.0);
uniform vec4 grout_color : source_color = vec4(0.05, 0.04, 0.04, 1.0);
uniform vec4 wet_streak_color : source_color = vec4(0.08, 0.07, 0.06, 1.0);
uniform float tile_size : hint_range(0.5, 6.0) = 1.5;
uniform float roughness_val : hint_range(0.5, 1.0) = 0.9;
uniform float wetness : hint_range(0.0, 1.0) = 0.4;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

// Simple hash for variation
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2D noise for organic stone shapes
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 world_pos = VERTEX.xz;
    vec2 tile_uv = world_pos / tile_size;
    vec2 tile_floor = floor(tile_uv);
    vec2 tile_frac = fract(tile_uv);
    
    // Organic cobblestone pattern using noise
    float n = noise(tile_uv * 2.0 + 1.0);
    float n2 = noise(tile_uv * 4.0 + 5.0);
    
    // Cobble shape - irregular stone edges
    vec2 center_offset = vec2(
        hash(tile_floor + 0.1) * 0.3 - 0.15,
        hash(tile_floor + 0.2) * 0.3 - 0.15
    );
    vec2 centered_frac = tile_frac - 0.5 + center_offset;
    float stone_dist = length(centered_frac);
    
    // Choose cobble color per stone
    float color_selector = hash(tile_floor + 0.5);
    vec4 base_stone = cobble_color1;
    if (color_selector < 0.33) base_stone = cobble_color1;
    else if (color_selector < 0.66) base_stone = cobble_color2;
    else base_stone = cobble_color3;
    
    // Add subtle color variation per stone
    base_stone.rgb += (hash(tile_floor + 0.7) * 0.04 - 0.02);
    
    // Irregular stone edges - grout between stones
    float grout_width = 0.08 + hash(tile_floor + 1.5) * 0.04;
    float stone_mask = 1.0 - smoothstep(0.35 - grout_width, 0.35 + grout_width, stone_dist);
    
    // Wet streaks on some stones
    float wet_streak = smoothstep(0.0, 0.05, abs(centered_frac.y - 0.3)) * hash(tile_floor + 2.0) * wetness;
    
    // Final color
    vec4 final_color = mix(grout_color, base_stone, stone_mask);
    final_color.rgb = mix(final_color.rgb, wet_streak_color.rgb, wet_streak * 0.3);
    
    // Surface roughness varies with wetness
    float final_roughness = mix(roughness_val, 0.3, wet_streak * 0.5);
    
    // Subtle ambient glow on wet surfaces
    float ambient_glow = wet_streak * 0.1;
    final_color.rgb += vec3(0.02, 0.015, 0.025) * ambient_glow;
    
    ALBEDO = final_color.rgb;
    ROUGHNESS = final_roughness;
    METALLIC = 0.0;
}
