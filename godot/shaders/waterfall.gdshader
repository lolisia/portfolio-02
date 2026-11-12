shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float n = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		n += a * noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return n;
}

void fragment() {
	float edge = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	vec2 q = vec2(UV.x * 7.0, UV.y * 2.6 - TIME * 1.15);
	float body = fbm(q);
	float streak = fbm(vec2(UV.x * 30.0, UV.y * 4.5 - TIME * 2.1));
	// The reference cascade is white water: more foam, and it churns thicker
	// toward the plunge pool at the bottom of the sheet.
	float churn = smoothstep(0.55, 0.0, UV.y);
	float foam = smoothstep(0.38, 0.80, body * 0.55 + streak * 0.55 + churn * 0.16);
	float top_fade = smoothstep(1.0, 0.94, UV.y);
	float bottom_fade = smoothstep(0.0, 0.035, UV.y);
	vec3 water = mix(vec3(0.09, 0.28, 0.32), vec3(0.93, 0.98, 0.99), foam);
	water += vec3(0.05, 0.07, 0.075) * churn;
	ALBEDO = water;
	ALPHA = edge * top_fade * bottom_fade * (0.38 + 0.60 * foam);
}
