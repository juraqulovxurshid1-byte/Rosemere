shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_burley, specular_disabled;

uniform sampler2D sprite_texture : source_color;
uniform float outline_width : hint_range(1.0, 8.0) = 3.0;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float alpha_threshold : hint_range(0.01, 0.5) = 0.08;

void fragment() {
    vec4 original = texture(sprite_texture, UV);
    float alpha = original.a;
    
    // Fully discard truly transparent pixels - no depth write, no fragment
    if (alpha < 0.01) {
        ALBEDO = vec3(0.0);
        ALPHA = 0.0;
        return;
    }
    
    vec2 tex_size = vec2(textureSize(sprite_texture, 0));
    vec2 pixel = 1.0 / tex_size;
    
    bool at_inner_edge = false;
    bool near_visible = false;
    
    for (int i = 0; i < 16; i++) {
        float angle = float(i) * 0.392699;
        vec2 dir = vec2(cos(angle), sin(angle));
        
        vec2 inner_offset = dir * pixel * 1.5;
        float inner_alpha = texture(sprite_texture, UV + inner_offset).a;
        if (inner_alpha < alpha_threshold) {
            at_inner_edge = true;
        }
        
        vec2 outer_offset = dir * pixel * outline_width;
        float outer_alpha = texture(sprite_texture, UV + outer_offset).a;
        if (outer_alpha > alpha_threshold) {
            near_visible = true;
        }
    }
    
    vec4 col;
    
    if (alpha > alpha_threshold) {
        if (at_inner_edge) {
            col = outline_color;
        } else {
            col = original;
        }
    } else {
        if (near_visible) {
            col = outline_color;
        } else {
            col = vec4(0.0, 0.0, 0.0, 0.0);
        }
    }
    
    ALBEDO = col.rgb;
    ALPHA = col.a;
}
