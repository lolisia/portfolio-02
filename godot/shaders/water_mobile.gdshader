// Mobile pond: sky-probe reflection, two wave octaves, no screen copy.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.070, 0.146, 0.132, 0.36);
uniform vec4 deep_color : source_color = vec4(0.003, 0.020, 0.038, 0.85);
uniform float wave_strength : hint_range(0.0, 3.0) = 1.0;
uniform float breeze : hint_range(0.0, 2.0) = 0.4;
uniform float freeze : hint_range(0.0, 1.0) = 0.0;
uniform vec4 impacts[18];
uniform float sim_time = 0.0;

varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pond_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Value noise with analytic derivatives, used for the advected wave field.
vec3 pond_noise_d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f - 1.0) * (f - 1.0);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	float k = a - b - c + d;
	return vec3(
		a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y - 0.5,
		du.x * (b - a + k * u.y),
		du.y * (c - a + k * u.x));
}

// Port of src/water.js: four rotated, advected noise octaves give finite
// crests and no single visible wavelength.
vec3 water_waves(vec2 q, float t, float wind_power) {
	vec3 total = vec3(0.0);
	mat2 axes = mat2(vec2(0.86, 0.51), vec2(-0.51, 0.86));
	float freq = 0.88;
	float amp = 0.045;
	for (int i = 0; i < 2; i++) {
		mat2 m = mat2(vec2(1.0, 0.0), vec2(0.0, 1.48)) * axes * freq;
		vec3 n = pond_noise_d(m * q + vec2(-0.28, 0.17) * t
			* (0.7 + 0.24 * float(i)) + vec2(float(i) * 31.71));
		vec2 rotated = vec2(dot(n.yz, m[0]), dot(n.yz, m[1]));
		total += amp * vec3(n.x, rotated);
		axes = axes * mat2(vec2(0.48, 0.877), vec2(-0.877, 0.48));
		freq *= 2.03;
		amp *= 0.43;
	}
	return total * (0.34 + wind_power * 1.12);
}

// Distance to the nearest Voronoi edge: narrow lines become ice cracks.
float voronoi_edge(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 offset = vec2(float(i), float(j));
			vec2 point = vec2(hash21(cell + offset), hash21(cell + offset + 17.0));
			vec2 delta = offset + point - local;
			float dist = dot(delta, delta);
			if (dist < first) {
				second = first;
				first = dist;
			} else if (dist < second) {
				second = dist;
			}
		}
	}
	return sqrt(second) - sqrt(first);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 waves = water_waves(world_pos.xz, TIME, breeze);
	// bedDepth is in UV2.x (the water mesh carries the real pond floor depth).
	float bank = smoothstep(0.0, 0.24, UV2.x)
		* (1.0 - smoothstep(14.45, 15.0, world_pos.x));
	VERTEX.y += waves.x * bank * wave_strength * (1.0 - freeze);
}

void fragment() {
	// Water.js: shallow = exp(-7.5 * bedDepth); the centre is deep and the
	// banks are shallow (the old ellipse mix had this backwards).
	float shallow = exp(-7.5 * max(UV2.x, 0.0));
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, shallow);
	ALPHA = mix(deep_color.a, shallow_color.a, shallow);
	ROUGHNESS = 0.09;
	METALLIC = 0.0;
	vec3 waves = water_waves(world_pos.xz, TIME, breeze);
	vec2 slope = waves.yz;
	vec3 fine = pond_noise_d(world_pos.xz * vec2(23.0, 18.0)
		+ vec2(-1.1, 0.75) * TIME);
	slope += fine.yz * 0.024 * breeze;
	// E8: 18 rain/fish impacts perturb the normal like water.js, instead of
	// drawing separate ring decals on the pond surface.
	for (int i = 0; i < 18; i++) {
		float age = sim_time - impacts[i].z;
		if (age >= 0.0 && age < 1.2) {
			vec2 delta = world_pos.xz - impacts[i].xy;
			float r = length(delta);
			float crest = r - age * 0.78;
			float pulse = sin(crest * 57.0) * exp(-abs(crest) * 22.0)
				* (1.0 - smoothstep(0.0, 1.2, age));
			slope += delta / max(0.016, r) * pulse * impacts[i].w;
		}
	}
	slope *= (1.0 - freeze) * wave_strength;
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float ice = smoothstep(0.04, 0.82, freeze);
	vec3 ice_color = vec3(0.24, 0.38, 0.40);
	if (ice > 0.001) {
		vec2 q = world_pos.xz * 1.3;
		float edge = voronoi_edge(q + vec2(3.1, 8.7));
		float crack = 1.0 - smoothstep(0.012, 0.075, edge);
		float frost = pond_noise(q * 6.5) * 0.65 + pond_noise(q * 17.0) * 0.35;
		ice_color += vec3(0.20, 0.23, 0.23) * frost + crack * 0.11;
	}

	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Water is almost transparent looking straight down and mirrors the sky and
	// banks at grazing angles (Schlick, matching the web original's fifth power).
	float fresnel = 0.03 + 0.97 * pow(1.0 - facing, 5.0);
	vec3 body = mix(ALBEDO, ice_color, ice);
	// Mobile uses the existing sky radiance probe for specular reflection.
	// No screen-texture dependency: avoid a full opaque-frame copy and
	// render-pass break on a tiled GPU. Terrain/fish remain visible through
	// the alpha-blended water, with the same shallow/deep colours.
	ALBEDO = body;
	SPECULAR = mix(0.8, 0.25, ice);
	ALPHA = mix(ALPHA, 0.97, fresnel * 0.55 * (1.0 - ice));
	ALPHA = mix(ALPHA, 1.0, ice);
	ROUGHNESS = mix(ROUGHNESS, 0.46, ice);
}

