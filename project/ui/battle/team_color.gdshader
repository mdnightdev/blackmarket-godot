shader_type canvas_item;

// Repaints the red clothing of the fighter art in a team color, keeping its shading. Steel and hair stay as drawn.
uniform vec4 team_color : source_color = vec4(1.0);

vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec3 hsv = to_hsv(COLOR.rgb);
	float distance_from_red = min(hsv.x, 1.0 - hsv.x);
	float cloth = (1.0 - smoothstep(0.03, 0.07, distance_from_red)) * smoothstep(0.35, 0.55, hsv.y);
	vec3 repainted = team_color.rgb * min(hsv.z * 1.8, 1.4);
	COLOR.rgb = mix(COLOR.rgb, repainted, cloth * team_color.a);
}
