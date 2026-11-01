shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.035, 0.043, 0.055, 0.98);
uniform vec4 border_color : source_color = vec4(0.24, 0.28, 0.35, 1.0);
uniform vec4 inner_line : source_color = vec4(0.12, 0.15, 0.20, 1.0);
uniform float corner_cut : hint_range(0.0, 32.0) = 12.0;
uniform float border_width : hint_range(1.0, 6.0) = 2.0;

void fragment() {
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 pixel_coord = UV * size;
    
    float d_tl = pixel_coord.x + pixel_coord.y;
    float d_tr = (size.x - pixel_coord.x) + pixel_coord.y;
    float d_bl = pixel_coord.x + (size.y - pixel_coord.y);
    float d_br = (size.x - pixel_coord.x) + (size.y - pixel_coord.y);
    
    float min_corner = min(min(d_tl, d_tr), min(d_bl, d_br));
    
    if (min_corner < corner_cut) {
        discard;
    }
    
    if (min_corner < corner_cut + border_width || 
        pixel_coord.x < border_width || pixel_coord.x > size.x - border_width ||
        pixel_coord.y < border_width || pixel_coord.y > size.y - border_width) {
        COLOR = border_color;
    } else if (min_corner < corner_cut + border_width + 1.5 ||
               pixel_coord.x < border_width + 1.5 || pixel_coord.x > size.x - (border_width + 1.5) ||
               pixel_coord.y < border_width + 1.5 || pixel_coord.y > size.y - (border_width + 1.5)) {
        COLOR = inner_line;
    } else {
        COLOR = bg_color;
    }
}
