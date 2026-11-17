shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;

// Foam disc at the foot of the cascade (src/cascade.js). Two fbm layers drift
// across the impact; soft edge falloff blends the foam into the rocks.

uniform float clock = 0.0;
uniform float freeze = 0.0;
uniform float opacity = 0.6;

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
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	// Avoid q/length(q) advection: its singularity stretches noise into a
	// stationary radial fan as time grows. Drift two continuous fields.
	float n1 = fbm(q * 3.0 + vec2(clock * 0.11, -clock * 0.08));
	float n2 = fbm(q * 5.2 + vec2(0.37 - clock * 0.09, 0.11 + clock * 0.13));
	float lace = smoothstep(0.30, 0.65, n1 * 0.6 + n2 * 0.55);
	float edge = 1.0 - smoothstep(0.15, 0.95, r);
	ALBEDO = vec3(0.894, 0.933, 0.941);
	ROUGHNESS = 0.92;
	SPECULAR = 0.0;
	ALPHA = lace * edge * opacity * 0.65 * (1.0 - smoothstep(0.08, 0.92, freeze));
}
