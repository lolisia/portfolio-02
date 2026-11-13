shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D path_mask : filter_linear;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow_depth : hint_range(0.0, 1.0) = 0.0;
uniform float winter : hint_range(0.0, 1.0) = 0.0;
uniform vec3 winter_bare_color = vec3(0.36, 0.235, 0.135);
uniform float water_y = 0.44;

varying vec3 v_world;
varying vec3 v_world_normal;
varying vec3 v_color;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Snow accumulates on the banks above the waterline and lifts the visible
	// surface, matching src/seasons.js. The ground node has an identity
	// transform, so a world-space lift can be added straight to VERTEX.y.
	float bank = smoothstep(water_y + 0.015, water_y + 0.3, v_world.y);
	float lift = snow_depth * bank * (0.078 + 0.031 * sin(v_world.x * 1.7 + cos(v_world.z * 0.91)));
	VERTEX.y += lift;
	v_world.y += lift;
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_color = COLOR.rgb;
}

void fragment() {
	if (CAMERA_POSITION_WORLD.y < 0.0 && v_world.y < 0.44) {
		discard;
	}
	float large = fbm(v_world.xz * 1.4);
	float fine = fbm(v_world.xz * 11.0);
	float soil_detail = fbm(v_world.xz * 34.0);
	float blades = smoothstep(0.54, 0.92, fbm(v_world.xz * 88.0));
	float spatter = step(0.72, fbm(v_world.xz * 47.0));
	vec3 albedo = v_color * (0.72 + 0.32 * large + 0.18 * fine);
	albedo += vec3(0.014, 0.030, 0.008) * blades;
	albedo += vec3(0.020, 0.030, 0.012) * spatter;

	// Ground mask: R = leaf litter under trees, G = soft trail.
	vec2 mask_uv = (v_world.xz + vec2(15.0)) / 30.0;
	vec4 zones = texture(path_mask, mask_uv);
	float leaf_grain = step(0.50, fbm(v_world.xz * 74.0));
	vec3 litter_color = mix(vec3(0.29, 0.22, 0.12), vec3(0.46, 0.36, 0.20), leaf_grain);
	albedo = mix(albedo, litter_color * (0.82 + 0.30 * fine),
		smoothstep(0.12, 0.72, zones.r) * 0.92);

	vec3 dirt = vec3(0.60, 0.49, 0.33) * (0.78 + 0.38 * fine + 0.10 * soil_detail);
	float path = smoothstep(0.14, 0.76, zones.g);
	albedo = mix(albedo, dirt, path);

	// Wet mud band right at the pond/outlet waterline.
	float mud_band = 1.0 - smoothstep(0.0, 0.16, abs(v_world.y - water_y));
	float up_world = clamp(v_world_normal.y, 0.0, 1.0);
	vec3 mud = vec3(0.37, 0.34, 0.25) * (0.80 + 0.30 * fine);
	albedo = mix(albedo, mud, mud_band * smoothstep(0.08, 0.42, up_world) * 0.88);

	float up = up_world;
	float puddle = smoothstep(0.56, 0.82, fbm(v_world.xz * 1.7))
		* wet * smoothstep(0.72, 0.98, up);
	albedo = mix(albedo, vec3(0.018, 0.035, 0.045), puddle * 0.75);

	float wetness = wet * (0.35 + 0.65 * up);
	albedo = pow(max(albedo, vec3(0.0)), vec3(1.0 + 0.28 * wetness));
	float roughness = mix(1.0, 0.08, puddle);
	roughness = clamp(roughness + 0.045 * soil_detail - 0.06 * path, 0.05, 1.0);

	// Fine soil bump from the same fbm field (G7 soil detail).
	float eps = 0.012;
	float hx = fbm((v_world.xz + vec2(eps, 0.0)) * 34.0);
	float hz = fbm((v_world.xz + vec2(0.0, eps)) * 34.0);
	vec3 bumped = normalize(v_world_normal
		+ vec3(soil_detail - hx, 0.0, soil_detail - hz) / eps * 0.012);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);

	// Web surfaces.js winterBare: swap the exposed ground to the #5c3c22
	// bare-soil tone, modulated by the local soil grain, before snow settles.
	float soil_grain = dot(albedo, vec3(0.30, 0.50, 0.20));
	albedo = mix(albedo,
		winter_bare_color * (soil_grain * 1.8 + 0.25), winter);

	float snow_noise = fbm(v_world.xz * 3.4);
	float snow_mask = smoothstep(0.04, 0.42, snow_depth * 1.18 - snow_noise * 0.38)
		* smoothstep(0.0, 0.58, up);
	albedo = mix(albedo, vec3(0.66, 0.75, 0.86), snow_mask);
	roughness = mix(roughness, 0.94, snow_mask);

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
