shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform int surface_kind = 1; // 0 wood, 1 stone, 2 clay, 3 plaster, 4 soil, 5 iron
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow_depth : hint_range(0.0, 1.0) = 0.0;
uniform float winter : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;
varying vec3 v_world_normal;
varying vec3 v_color;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float n = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		n += a * noise3(p);
		p = p * 2.03 + vec3(7.1, 3.7, 5.3);
		a *= 0.5;
	}
	return n;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_color = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	// The pond mirror camera sits below the water plane. Discard the part of
	// the island below the waterline so the reflection only sees the world
	// above the pond instead of the underside of the diorama.
	if (CAMERA_POSITION_WORLD.y < 0.0 && v_world.y < 0.44) {
		discard;
	}
	float n = fbm3(v_world * 5.5);
	vec3 albedo = v_color;
	float roughness = 0.9;
	float metallic = 0.0;

	if (surface_kind == 0) {
		float grain = sin((v_world.y * 1.3 + n * 1.8) * 58.0) * 0.5 + 0.5;
		float fibre = fbm3(v_world * vec3(17.0, 2.0, 17.0));
		albedo *= 0.78 + 0.24 * grain + 0.14 * fibre;
		roughness = 0.82;
	} else if (surface_kind == 1) {
		float speck = fbm3(v_world * 19.0);
		float vein = pow(1.0 - abs(fbm3(v_world * 2.2) - 0.5) * 2.0, 14.0);
		albedo *= 0.78 + 0.28 * n + 0.16 * speck + 0.10 * vein;
		// The diorama's outer cliff reads as layered rock: broad sediment
		// bands, fine bedding lines and occasional vertical cracks.
		float cliff = 1.0 - smoothstep(2.8, 3.4, v_world.y);
		float warp = fbm3(vec3(v_world.x * 0.8, v_world.y * 1.8, v_world.z * 0.8));
		float strata = sin(v_world.y * 5.5 + warp * 3.2) * 0.5 + 0.5;
		float bedding = smoothstep(0.70, 0.96,
			sin(v_world.y * 26.0 + warp * 7.0) * 0.5 + 0.5);
		float crack = pow(1.0 - abs(fbm3(v_world * vec3(1.6, 5.0, 1.6)) - 0.5) * 2.0, 18.0);
		albedo *= mix(1.0, 0.86 + 0.20 * strata - 0.10 * bedding, cliff);
		albedo *= 1.0 - 0.22 * crack * cliff;
		roughness = 0.92;
	} else if (surface_kind == 2) {
		float tile = fbm3(v_world * 7.0);
		albedo *= 0.84 + 0.20 * tile + 0.10 * n;
		roughness = 0.76;
	} else if (surface_kind == 3) {
		albedo *= 0.93 + 0.07 * fbm3(v_world * 13.0);
		roughness = 0.97;
	} else if (surface_kind == 4) {
		float clod = fbm3(v_world * 9.0);
		albedo *= 0.78 + 0.30 * clod + 0.10 * n;
		roughness = 0.99;
	} else if (surface_kind == 5) {
		albedo *= 0.88 + 0.12 * n;
		roughness = 0.55;
		metallic = 0.55;
	}

	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float snow_noise = fbm3(v_world * 3.1);
	float snow_mask = smoothstep(0.04, 0.40, snow_depth * 1.15 - snow_noise * 0.38)
		* smoothstep(0.0, 0.55, up);
	snow_mask *= 1.0 - 0.35 * abs(v_world_normal.x);

	float wetness = wet * (0.35 + 0.65 * up) * (1.0 - snow_mask);
	albedo = pow(max(albedo, vec3(0.0)), vec3(1.0 + 0.32 * wetness));
	roughness = mix(roughness, 0.28, wetness);
	albedo = mix(albedo, vec3(0.66, 0.75, 0.86), snow_mask);
	roughness = mix(roughness, 0.93, snow_mask);

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.18;
}
