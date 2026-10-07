shader_type canvas_item;

uniform float side_fade : hint_range(0.0, 0.5) = 0.08;
uniform float top_fade : hint_range(0.0, 0.5) = 0.06;
uniform float bottom_fade : hint_range(0.0, 0.5) = 0.2;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float fade = smoothstep(0.0, side_fade, UV.x) * smoothstep(0.0, side_fade, 1.0 - UV.x)
			* smoothstep(0.0, top_fade, UV.y) * smoothstep(0.0, bottom_fade, 1.0 - UV.y);
	COLOR = vec4(color.rgb, color.a * fade);
}
