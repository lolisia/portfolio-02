shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wind_strength : hint_range(0.0, 2.5) = 1.0;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float snow_depth : hint_range(0.0, 1.0) = 0.0;
uniform float winter : hint_range(0.0, 1.0) = 0.0;
uniform float evergreen : hint_range(0.0, 1.0) = 0.0;
uniform float leaf_cut : hint_range(0.0, 2.0) = 0.0;
uniform float use_vertex_color : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_amount : hint_range(0.0, 1.2) = 0.0;
uniform float cloud_clock = 0.0;
uniform float trample_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 season_tint = vec3(1.0);
// Web foliageTint influence: needles .19, petals 0 (not tinted), else 1.
uniform float tint_influence : hint_range(0.0, 1.0) = 1.0;
// Web leafSpray() canvas baked by tools/leaf-spray.py (spray / needle).
uniform sampler2D spray_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 trample[16];

varying vec3 v_color;
varying vec3 v_origin;
varying vec3 v_world;
varying vec3 v_world_normal;

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
	for (int i = 0; i < 3; i++) {
		n += a * noise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return n;
}

void vertex() {
	v_color = INSTANCE_CUSTOM.rgb
		* (use_vertex_color > 0.5 ? COLOR.rgb : vec3(1.0));
	float sway = INSTANCE_CUSTOM.a;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_origin = origin;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	float phase = dot(origin.xz, vec2(0.39, 0.23));
	float gust = sin(TIME * 1.37 - phase) + 0.42 * sin(TIME * 2.31 - phase * 0.71);
	float h = max(0.0, VERTEX.y);
	float bend = sway * (sway > 0.1 ? h : h * h) * gust * wind_strength;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.36;

	// Walkers part the turf around them and leave a slowly recovering trail.
	// Only materials flagged as ground cover pay for the 16-slot loop.
	if (trample_strength > 0.0) {
		vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float world_height = max(0.0, world_vertex.y - origin.y);
		vec2 parted = vec2(0.0);
		float pressed = 0.0;
		for (int i = 0; i < 16; i++) {
			vec4 t = trample[i];
			if (t.w < 0.01) {
				continue;
			}
			vec2 away = world_vertex.xz - t.xy;
			if (abs(away.x) + abs(away.y) > t.z * 2.4) {
				continue;
			}
			float dist = length(away);
			float f = t.w * (1.0 - smoothstep(t.z * 0.35, t.z * 1.7, dist));
			// Fade the lateral push to zero at the centre so a blade never flips sides.
			parted += away / max(dist, t.z * 0.7) * f;
			pressed = max(pressed, f);
		}
		parted /= max(1.0, length(parted));
		vec3 world_offset = vec3(parted.x * world_height * 0.8,
			-pressed * world_height * 0.45, parted.y * world_height * 0.8);
		// Transform the world-space push back into the instance's local space.
		vec3 axis_x = MODEL_MATRIX[0].xyz;
		vec3 axis_y = MODEL_MATRIX[1].xyz;
		vec3 axis_z = MODEL_MATRIX[2].xyz;
		float sx = max(length(axis_x), 0.0001);
		float sy = max(length(axis_y), 0.0001);
		float sz = max(length(axis_z), 0.0001);
		VERTEX.x += (world_offset.x * axis_z.z - world_offset.z * axis_z.x) / (sx * sz);
		VERTEX.z += (world_offset.x * axis_z.x + world_offset.z * axis_z.z) / (sz * sz);
		VERTEX.y -= pressed * world_height * 0.45 / sy;
	}
}

void fragment() {
	if (CAMERA_POSITION_WORLD.y < 0.0 && v_origin.y < 0.44) {
		discard;
	}
	// Web parity (surfaces.js): each seasonal plant instance has a fixed rank and
	// drops out once winterBare passes it, so plants thin out one by one while
	// the blend eases 0 -> 1 and are all gone at full winter. Evergreens stay.
	float rank = fract(dot(v_origin, vec3(16.321, 28.735, 9.135)));
	if (evergreen < 0.5 && rank < winter) {
		discard;
	}
	// Leaves and needles are alpha-tested sprays mapped by the card UVs, like
	// the web 'spray'/'needle' materials (alphaTest .29). The web canvas
	// texture is flipY'd, so sample with v flipped to match its orientation.
	vec4 spray = vec4(1.0);
	if (leaf_cut > 0.5) {
		spray = texture(spray_tex, vec2(UV.x, 1.0 - UV.y));
		if (spray.a < 0.29) {
			discard;
		}
	}
	vec3 albedo = base_color.rgb * v_color * spray.rgb
		* mix(vec3(1.0), season_tint, tint_influence);
	// K9: spring blossom freckles on broadleaf spray (web foliageTint.g > 1).
	float spring = clamp((season_tint.g - 1.02) * 6.0, 0.0, 1.0);
	if (leaf_cut > 0.5 && leaf_cut < 1.5 && spring > 0.01) {
		float blossom = smoothstep(0.56, 0.72,
			fbm(v_world.xz * 1.2 + vec2(v_world.y * 0.42)));
		albedo = mix(albedo, vec3(0.93, 0.55, 0.66),
			blossom * spring * 0.75);
	}
	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float snow_noise = fbm(v_origin.xz * 2.6);
	float snow_mask = smoothstep(0.04, 0.46, snow_depth * 1.2 - snow_noise * 0.35)
		* smoothstep(0.0, 0.70, up);
	float wetness = wet * (1.0 - snow_mask);
	albedo *= mix(1.0, 0.76, wetness);
	albedo = mix(albedo, vec3(0.68, 0.77, 0.87), snow_mask * 0.92);
	// Web roughness: spray/needle .78, grass .82.
	ROUGHNESS = mix(leaf_cut > 0.5 ? 0.78 : 0.82, 0.94, snow_mask);
	SPECULAR = 0.15;
	ALBEDO = albedo;
}

void light() {
	float shade = LIGHT_IS_DIRECTIONAL
		? 1.0 - smoothstep(0.31, 0.66,
			fbm((v_world.xz + v_world.y * vec2(0.25, -0.16)) * 0.55
				+ vec2(cloud_clock * 0.05, cloud_clock * 0.02))) * cloud_amount
		: 1.0;
	float ndl = max(0.0, dot(NORMAL, LIGHT));
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR * shade / PI;
	// K5: backlit leaves transmit a warm-green light when the sun is behind
	// them, matching the web alphaTest foliage term.
	if (leaf_cut > 0.5) {
		float back = max(0.0, -dot(NORMAL, LIGHT));
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade
			* vec3(0.38, 0.48, 0.16) * (0.12 + 0.88 * back);
	}
}
