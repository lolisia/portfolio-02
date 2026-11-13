shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded;

// Curtain shader ported from src/cascade.js. UV.x runs across the outlet and
// UV.y runs down the ballistic arc (-0.25 overhang .. 1.0 foot). Unlike the
// old unshaded sheet this material is lit (roughness .22) and adds a modest
// sky Fresnel, so the falls no longer glow in the dark.

uniform float shade : hint_range(0.0, 1.5) = 1.0;
uniform float freeze : hint_range(0.0, 1.0) = 0.0;
uniform float layer : hint_range(0.0, 1.0) = 0.0;
uniform float breeze : hint_range(0.0, 1.0) = 0.4;
uniform float light : hint_range(0.0, 1.5) = 1.0;
uniform float sky_level : hint_range(0.0, 1.5) = 1.0;
uniform vec3 sky_color = vec3(0.46, 0.63, 0.78);

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

void vertex() {
	float flight = max(UV.y, 0.0);
	float pulse = sin(flight * 20.0 - TIME * 8.0 + UV.x * 9.0
		+ sin(UV.x * 9.0 + TIME)) * 0.020;
	VERTEX.x += flight * (pulse + 0.015 * sin(flight * 42.0 - TIME * 14.0
		+ UV.x * 8.0));
	VERTEX.z += flight * (0.022 + 0.013 * breeze) * sin(flight * 9.0
		- TIME * 3.0 + UV.x * 5.0);
}

void fragment() {
	float f = UV.y;
	float across = UV.x;
	float back_layer = layer;
	vec2 flow = vec2(across * 1.2, (f - TIME * 1.35) * 0.55);
	float large = fbm(flow * 0.45 + vec2(layer * 3.7, 0.0));
	float fold = fbm(vec2(across * 3.4 + large * 0.3, (f - TIME * 1.9) * 0.2));
	float fleck = fbm(flow * vec2(4.0, 2.5) + large * 0.4);
	// fbm averages around .5; the reference cloud map sits higher. Bias the
	// lace so the sheet reads as white water with darker holes, not a dark
	// glass sheet with a few white specks.
	float lace = fold * 0.72 + fleck * 0.54;
	float bubbles = smoothstep(0.42, 0.80, lace)
		* (0.25 + 0.75 * smoothstep(0.02, 0.65, f));
	float breakup = smoothstep(0.72, 1.0, f) * smoothstep(0.30, 0.72, fleck);
	bubbles = max(bubbles, breakup * 0.9);
	vec3 water = mix(vec3(0.07, 0.18, 0.21), vec3(0.90, 0.96, 0.97), bubbles);
	water *= mix(1.0, 0.72, back_layer) * shade;

	float edge = smoothstep(0.0, 0.09 + 0.1 * large, across)
		* (1.0 - smoothstep(0.91 - 0.1 * fleck, 1.0, across));
	float sheet = 0.34 + 0.34 * fold;
	float top_fade = 1.0 - smoothstep(0.0, 0.06, -f);
	float bottom_fade = 1.0 - smoothstep(0.82 + 0.1 * fleck, 1.0, f);
	float alpha = mix(sheet, 0.90, bubbles * 0.85) * edge * top_fade * bottom_fade
		* (1.0 - breakup * 0.5) * mix(1.0, 0.75, back_layer);
	alpha *= 1.0 - smoothstep(0.08, 0.92, freeze);
	if (alpha < 0.03) {
		discard;
	}
	float fresnel = 0.025 + 0.80 * pow(1.0 - clamp(NORMAL.z, 0.0, 1.0), 5.0);
	ALBEDO = water * light + sky_color * fresnel * sky_level * 0.35;
	ROUGHNESS = 0.22;
	SPECULAR = 0.45;
	ALPHA = alpha;
}
