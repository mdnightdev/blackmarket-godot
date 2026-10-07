shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 5.0;
uniform float reach = 7.0;
uniform vec4 red : source_color = vec4(0.78, 0.13, 0.17, 1.0);
uniform vec4 blue : source_color = vec4(0.18, 0.32, 0.88, 1.0);

void fragment() {
	float swap = step(0.0, sin(TIME * speed));
	float pulse = 0.75 + 0.25 * sin(TIME * speed * 2.0);
	float left = exp(-UV.x * reach);
	float right = exp(-(1.0 - UV.x) * reach);
	float vertical = exp(-min(UV.y, 1.0 - UV.y) * reach * 1.6) * 0.35;
	vec3 left_color = mix(red.rgb, blue.rgb, swap);
	vec3 right_color = mix(blue.rgb, red.rgb, swap);
	vec3 color = (left_color * left + right_color * right) / max(left + right, 0.0001);
	float glow = clamp(max(left, right) + vertical, 0.0, 1.0);
	COLOR = vec4(color, glow * intensity * pulse);
}
