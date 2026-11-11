shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D path_mask : filter_linear;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow_depth : hint_range(0.0, 1.0) = 0.0;
uniform float winter : hint_range(0.0, 1.0) = 0.0;

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
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_color = COLOR.rgb;
}

void fragment() {
	if (CAMERA_POSITION_WORLD.y < 0.0 && v_world.y < 0.44) {
		discard;
	}
	float large = fbm(v_world.xz * 1.4);
	float fine = fbm(v_world.xz * 11.0);
	float blades = smoothstep(0.54, 0.92, fbm(v_world.xz * 88.0));
	vec3 albedo = v_color * (0.72 + 0.32 * large + 0.18 * fine);
	albedo += vec3(0.014, 0.030, 0.008) * blades;

	vec2 mask_uv = (v_world.xz + vec2(15.0)) / 30.0;
	float path = texture(path_mask, mask_uv).r;
	vec3 dirt = vec3(0.14, 0.085, 0.050) * (0.78 + 0.42 * fine);
	albedo = mix(albedo, dirt, smoothstep(0.18, 0.78, path));

	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float puddle = smoothstep(0.56, 0.82, fbm(v_world.xz * 1.7))
		* wet * smoothstep(0.72, 0.98, up);
	albedo = mix(albedo, vec3(0.018, 0.035, 0.045), puddle * 0.75);

	float wetness = wet * (0.35 + 0.65 * up);
	albedo = pow(max(albedo, vec3(0.0)), vec3(1.0 + 0.28 * wetness));
	float roughness = mix(1.0, 0.08, puddle);

	float snow_noise = fbm(v_world.xz * 3.4);
	float snow_mask = smoothstep(0.04, 0.42, snow_depth * 1.18 - snow_noise * 0.38)
		* smoothstep(0.0, 0.58, up);
	albedo = mix(albedo, vec3(0.66, 0.75, 0.86), snow_mask);
	roughness = mix(roughness, 0.94, snow_mask);
	albedo *= 1.0 - 0.22 * winter * (1.0 - snow_mask);

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
