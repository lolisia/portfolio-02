shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform int surface_kind = 1; // 0 wood, 1 stone, 2 clay, 3 plaster, 4 soil, 5 iron
uniform bool use_detail_map = false;
uniform sampler2D detail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_noise_map : filter_linear_mipmap, repeat_enable;
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow_depth : hint_range(0.0, 1.0) = 0.0;
uniform float winter : hint_range(0.0, 1.0) = 0.0;
uniform bool mobile_clouds = false;
uniform float cloud_amount : hint_range(0.0, 1.2) = 0.0;
uniform float cloud_clock = 0.0;
uniform float water_y = 0.44;

varying vec3 v_world;
varying float v_cloud_shade;
varying vec3 v_world_normal;
varying vec3 v_color;
varying vec3 v_local;
varying vec3 v_local_normal;
varying vec3 v_scale;
varying vec3 v_offset;

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

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float n = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		n += a * noise2(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return n;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	v_color = INSTANCE_CUSTOM.rgb;
	v_local = VERTEX;
	v_local_normal = NORMAL;
	v_scale = vec3(max(length(MODEL_MATRIX[0].xyz), 0.0001),
		max(length(MODEL_MATRIX[1].xyz), 0.0001),
		max(length(MODEL_MATRIX[2].xyz), 0.0001));
	v_offset = MODEL_MATRIX[3].xyz;
}

// K7: world-scale box mapping. Each face samples at its true size, with the
// texture v axis along the longer in-plane edge (web surfaces.js) and a stable
// per-instance offset so repeated boards do not share identical pixels.
vec2 box_uv() {
	vec3 bp = v_local * v_scale;
	vec3 an = abs(normalize(v_local_normal));
	vec2 q;
	if (an.x > 0.5) {
		q = v_scale.z > v_scale.y ? bp.yz : bp.zy;
	} else if (an.y > 0.5) {
		q = v_scale.z > v_scale.x ? bp.xz : bp.zx;
	} else {
		q = v_scale.y > v_scale.x ? bp.xy : bp.yx;
	}
	vec2 offset = fract(sin(vec2(
		dot(v_offset, vec3(12.99, 78.23, 37.72)),
		dot(v_offset, vec3(39.35, 11.13, 83.17)))) * 43758.55) * vec2(5.0, 9.0);
	float scale = surface_kind == 0 ? 1.0 : (surface_kind == 1 ? 0.75 : (surface_kind == 2 ? 1.4 : 0.8));
	return (q + offset) * scale;
}

// Procedural relief sampled in box-UV space (K7).
float box_relief(vec2 p) {
	if (surface_kind == 0) {
		float grain = fbm2(vec2(p.x * 3.2, p.y * 0.55));
		float ring = 0.5 + 0.5 * sin((p.x * 4.0 + grain * 2.2) * TAU);
		return 0.55 - 0.30 * pow(ring, 7.0) + 0.22 * grain;
	} else if (surface_kind == 1) {
		float coarse = fbm2(p * 1.4);
		float fine = fbm2(p * 6.0);
		float grit = fbm2(p * 18.0);
		float vein = pow(1.0 - abs(fine - 0.5) * 2.0, 20.0);
		return 0.38 * coarse + 0.30 * fine + 0.18 * grit - 0.25 * vein;
	} else if (surface_kind == 2) {
		return 0.26 * fbm2(p * 2.0) + 0.18 * fbm2(p * 7.0)
			+ 0.18 * fbm2(p * 20.0) + 0.38 * pow(cos(p.x * TAU * 0.7), 2.0);
	} else if (surface_kind == 3) {
		return 0.32 * fbm2(p * 2.0) + 0.33 * fbm2(p * 7.0)
			+ 0.35 * fbm2(p * 20.0);
	}
	return 0.5;
}

void fragment() {
	// The pond mirror camera sits below the water plane. Discard the part of
	// the island below the waterline so the reflection only sees the world
	// above the pond instead of the underside of the diorama.
	if (CAMERA_POSITION_WORLD.y < 0.0 && v_world.y < 0.44) {
		discard;
	}
	float n = 0.0;
	if (surface_kind == 4 || surface_kind == 5) { n = fbm3(v_world * 5.5); }
	vec2 box_uv_pos = surface_kind == 7 ? vec2(UV.x, 1.0 - UV.y) : box_uv();
	float relief = 0.0;
	if (!use_detail_map && surface_kind <= 3) { relief = box_relief(box_uv_pos); }
	vec3 albedo = v_color;
	float roughness = 0.9;
	float metallic = 0.0;

	if (surface_kind == 0) {
		// Web wood: grain streaks and late-wood rings in world-scale box UV.
		albedo *= 0.76 + 0.34 * relief;
		roughness = 0.80;
	} else if (surface_kind == 1) {
		albedo *= 0.80 + 0.30 * relief;
		roughness = 0.91;
	} else if (surface_kind == 2) {
		albedo *= 0.82 + 0.28 * relief;
		roughness = 0.74;
	} else if (surface_kind == 3) {
		albedo *= 0.94 + 0.12 * relief;
		roughness = 0.98;
	} else if (surface_kind == 4) {
		float clod = fbm3(v_world * 9.0);
		albedo *= 0.78 + 0.30 * clod + 0.10 * n;
		roughness = 0.99;
	} else if (surface_kind == 5) {
		albedo *= 0.88 + 0.12 * n;
		roughness = 0.55;
		metallic = 0.55;
	}

	if (surface_kind == 6) {
		// cascade.js rockMat is plain, wet-looking stone.
		roughness = 0.36;
		albedo = v_color;
	} else if (use_detail_map) {
		// The web texture recipes are baked verbatim, including their sRGB
		// albedo and restrained normal maps; no extra cliff strata/cracks.
		albedo = v_color * texture(detail_albedo, box_uv_pos).rgb;
		if (surface_kind == 7) { roughness = 0.98; }
		vec3 map_normal = texture(detail_normal, box_uv_pos).rgb * 2.0 - 1.0;
		map_normal.xy *= 1.0 - clamp(snow_depth, 0.0, 1.0) * 0.9;
		vec3 wn = normalize(v_world_normal);
		vec3 dpdx = dFdx(v_world), dpdy = dFdy(v_world);
		vec2 duvdx = dFdx(box_uv_pos), duvdy = dFdy(box_uv_pos);
		vec3 px = cross(dpdy, wn), py = cross(wn, dpdx);
		vec3 tangent = px * duvdx.x + py * duvdy.x;
		vec3 bitangent = px * duvdx.y + py * duvdy.y;
		float inv_scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 0.000001));
		wn = normalize(mat3(tangent * inv_scale, bitangent * inv_scale, wn) * map_normal);
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	} else {
		// K7 normal detail: finite differences of the same box relief, applied in
		// a tangent frame so all six box faces receive matching surface bumps.
		if (surface_kind <= 3) {
			float eps = 0.012;
			float dx = box_relief(box_uv_pos + vec2(eps, 0.0))
				- box_relief(box_uv_pos - vec2(eps, 0.0));
			float dy = box_relief(box_uv_pos + vec2(0.0, eps))
				- box_relief(box_uv_pos - vec2(0.0, eps));
			float relief_depth = surface_kind == 0 ? 0.10
				: (surface_kind == 1 ? 0.12 : (surface_kind == 2 ? 0.05 : 0.04));
			// Snow settles over the relief instead of tracing every plank/tile gap.
			relief_depth *= 1.0 - clamp(snow_depth, 0.0, 1.0) * 0.9;
			vec3 wn = normalize(v_world_normal);
			vec3 tangent = normalize(cross(abs(wn.y) < 0.9 ? vec3(0.0, 1.0, 0.0)
				: vec3(1.0, 0.0, 0.0), wn));
			vec3 bitangent = cross(wn, tangent);
			wn = normalize(wn - (tangent * dx + bitangent * dy) * relief_depth / eps);
			NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
		}

	}

	float up = clamp(v_world_normal.y, 0.0, 1.0);
	// surfaces.js snow: favour upward faces and leave trunks/vertical
	// twigs brown. Triplanar noise avoids streaks down narrow branches.
	float uneven = 0.0;
	float snow_mask = 0.0;
	if (snow_depth > 0.0) {
		vec3 tri = pow(abs(v_world_normal), vec3(4.0));
		tri /= max(dot(tri, vec3(1.0)), 0.0001);
		for (int i = 0; i < 3; i++) {
			float scale = i == 0 ? 0.21 : (i == 1 ? 0.83 : 3.1);
			float offset = i == 0 ? 0.0 : (i == 1 ? 0.37 : 0.71);
			float n = texture(snow_noise_map, v_world.yz * scale + offset).r * tri.x
				+ texture(snow_noise_map, v_world.xz * scale + offset).r * tri.y
				+ texture(snow_noise_map, v_world.xy * scale + offset).r * tri.z;
			uneven += n * (i == 0 ? 0.6 : (i == 1 ? 0.3 : 0.1));
		}
		float hold = mix(0.6, 1.0, smoothstep(0.35, 0.95, up));
		snow_mask = smoothstep(0.0, 0.16, snow_depth * 1.55 * hold - uneven * 0.82)
			* smoothstep(0.14, 0.84, up) * smoothstep(0.43, 0.69, v_world.y);
	}

	float wetness = wet * (0.35 + 0.65 * up) * (1.0 - snow_mask);
	// K8: stone at the waterline keeps a dark wet foot and a low-roughness sheen.
	float wet_foot = 0.0;
	if (surface_kind == 1) {
		wet_foot = 1.0 - smoothstep(0.0, 0.12, abs(v_world.y - water_y));
		albedo *= 1.0 - 0.26 * wet_foot;
		roughness = mix(roughness, 0.40, wet_foot * 0.9);
		if (wetness > 0.01 && up > 0.5) {
			vec3 wn = normalize(v_world_normal);
			vec2 rg = vec2(
				cos(dot(v_world.xz, vec2(21.0, 18.0)) + TIME * 3.4),
				cos(dot(v_world.xz, vec2(-17.0, 24.0)) - TIME * 2.8))
				* wetness * 0.018;
			NORMAL = normalize((VIEW_MATRIX * vec4(
				normalize(wn + vec3(rg.x, 0.0, rg.y)), 0.0)).xyz);
		}
	}
	albedo = pow(max(albedo, vec3(0.0)), vec3(1.0 + 0.32 * wetness));
	roughness = mix(roughness, 0.28, wetness);
	albedo = mix(albedo, vec3(0.80, 0.88, 0.95) * (0.87 + 0.17 * uneven), snow_mask);
	roughness = mix(roughness, 0.93, snow_mask);
	// No snow means no visible crystal term. Avoid four octaves of 3D
	// noise at every dry stone/roof pixel just to multiply the result by 0.
	if (snow_mask > 0.0) {
		float snow_glint = pow(fbm3(v_world * 78.0 + vec3(TIME * 0.19)), 16.0);
		albedo += vec3(0.16, 0.19, 0.22) * snow_glint * snow_mask;
	}
	// Shared by both directional lights, evaluated once per fragment.
	vec3 cloud_wind = vec3(cloud_clock * 0.05, 0.0, cloud_clock * 0.02);
	float cloud_cover = mobile_clouds ? texture(snow_noise_map, (v_world.xz + v_world.y * vec2(0.25, -0.16)) * 0.024 + vec2(cloud_clock * 0.0019, cloud_clock * 0.0008)).r : fbm3(vec3(v_world.x * 0.55, v_world.y * 0.22, v_world.z * 0.55) + cloud_wind);
	v_cloud_shade = 1.0 - smoothstep(0.31, 0.66, cloud_cover) * cloud_amount;

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = surface_kind == 5 ? 0.5 : 0.03;
}

void light() {
	float shade = LIGHT_IS_DIRECTIONAL ? v_cloud_shade : 1.0;
	float ndl = max(0.0, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR * shade / PI;
	// The old fixed Phong term ignored roughness and made .91 stone shine
	// like polished metal. Keep the strong highlight on actual iron only.
	if (surface_kind == 5) {
		float spec = pow(max(0.0, dot(NORMAL, normalize(LIGHT + VIEW))), 24.0);
		SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * shade * 0.18;
	}
}
