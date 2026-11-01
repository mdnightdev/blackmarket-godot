shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.83, 0.69, 0.22, 1.0);
uniform vec4 socket_color : source_color = vec4(0.03, 0.04, 0.06, 1.0);
uniform float border_thickness : hint_range(1.0, 6.0) = 2.0;
uniform float inner_shadow_depth : hint_range(0.0, 1.0) = 0.55;

void fragment() {
    vec2 uv = UV;
    vec4 col = socket_color;
    
    float dist_x = min(uv.x, 1.0 - uv.x);
    float dist_y = min(uv.y, 1.0 - uv.y);
    float edge_dist = min(dist_x, dist_y);
    
    if (edge_dist < 0.03 * border_thickness) {
        col = border_color;
    } else {
        float shadow = smoothstep(0.03, 0.22, edge_dist);
        col = mix(socket_color * (1.0 - inner_shadow_depth), socket_color, shadow);
    }
    
    COLOR = col;
}
