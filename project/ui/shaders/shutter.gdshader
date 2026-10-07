shader_type canvas_item;

uniform vec4 slat_color : source_color = vec4(0.13, 0.145, 0.17, 1.0);
uniform vec4 groove_color : source_color = vec4(0.03, 0.035, 0.045, 1.0);
uniform float slat_height = 34.0;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float slat = mod(local_position.y, slat_height) / slat_height;
	float edge = smoothstep(0.0, 0.07, slat) * smoothstep(1.0, 0.88, slat);
	float curve = mix(0.7, 1.0, sin(slat * 3.14159));
	COLOR = vec4(mix(groove_color.rgb, slat_color.rgb * curve, edge), 1.0);
}
