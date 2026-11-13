#[compute]
#version 450

// Half-resolution atmosphere pass. Two things happen per pixel:
//
// 1. A short screen-space march toward the sun through a bright-pass of the
//    scene estimates how much of the sun is visible behind foreground
//    silhouettes. Depth is reverse-Z, so a sample closer to the camera than
//    the current pixel occludes it.
// 2. A 24-step raymarch through the island's analytic fog volume integrates
//    height falloff, drifting noise banks, low dawn mist, sun forward
//    scattering and warm lantern scattering.
//
// The result is stored as rgb = in-scattered light and a = transmittance, so
// the full-resolution composite can do scene * a + rgb.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D scene_color;
layout(set = 0, binding = 1) uniform sampler2D scene_depth;
layout(set = 0, binding = 2, rgba16f) uniform image2D shaft_image;
layout(set = 0, binding = 4) uniform sampler2D sun_shadow;
layout(set = 0, binding = 3, std140) uniform Params {
	vec4 sun;         // xy: sun screen uv (x < -5 = hidden)
	vec4 sun_color;   // rgb: sun light color, w: shaft strength
	vec4 settings;    // x: full width, y: full height, z: time, w: cloud amount
	vec4 scatter;     // rgb: ambient fog color, w: fog density
	vec4 cam_right;   // xyz: camera right, w: tan(fov/2)
	vec4 cam_up;      // xyz: camera up, w: aspect
	vec4 cam_forward; // xyz: camera forward, w: near plane
	vec4 cam_pos;     // xyz: camera position, w: far plane
	vec4 fog;         // x: mist low, y: lamp power, z: golden, w: sun energy
	vec4 sun_dir;     // xyz: direction toward the sun, w: orthographic flag
	vec4 lamps[5];    // xyz: lantern world position, w: normalized energy
	vec4 shadow_right;   // xyz: sun camera right, w: ortho size
	vec4 shadow_up;      // xyz: sun camera up, w: camera far
	vec4 shadow_forward; // xyz: sun camera forward
	vec4 shadow_pos;     // xyz: sun camera position, w: enabled
} params;

const vec3 BOX_MIN = vec3(-17.0, -0.7, -17.0);
const vec3 BOX_MAX = vec3(17.0, 10.0, 17.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float hash12(vec2 p) {
	vec3 q = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float shadow_visibility(vec3 p) {
	if (params.shadow_pos.w < 0.5) {
		return 1.0;
	}
	vec3 rel = p - params.shadow_pos.xyz;
	vec2 suv = vec2(
		0.5 + dot(rel, params.shadow_right.xyz) / params.shadow_right.w,
		0.5 - dot(rel, params.shadow_up.xyz) / params.shadow_right.w);
	if (suv.x <= 0.002 || suv.x >= 0.998 || suv.y <= 0.002 || suv.y >= 0.998) {
		return 1.0;
	}
	float stored = texture(sun_shadow, suv).r * params.shadow_up.w;
	float actual = dot(rel, params.shadow_forward.xyz);
	return smoothstep(-0.12, 0.03, stored - actual);
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(shaft_image);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	float center_depth = texture(scene_depth, uv).r;
	float sun_strength = params.sun_color.w;

	// Screen-space shaft estimate: march toward the sun and let foreground
	// depth punch dark gaps into the bright-pass. This doubles as a cheap
	// shadow-visibility proxy for the volumetric fog below.
	float shaft = 0.0;
	if (sun_strength > 0.001 && params.sun.x > -5.0) {
		vec2 to_sun = params.sun.xy - uv;
		float ray_length = length(to_sun);
		vec2 ray_dir = to_sun / max(ray_length, 0.0001);
		vec2 step = ray_dir * min(ray_length, 0.55) / 12.0;
		vec2 sample_uv = uv;
		float weight = 1.0;
		for (int i = 0; i < 12; i++) {
			sample_uv += step;
			vec2 edge = smoothstep(vec2(0.0), vec2(0.10), sample_uv)
				* (1.0 - smoothstep(vec2(0.90), vec2(1.0), sample_uv));
			vec2 clamped_uv = clamp(sample_uv, vec2(0.001), vec2(0.999));
			vec3 sample_color = texture(scene_color, clamped_uv).rgb;
			float sample_depth = texture(scene_depth, clamped_uv).r;
			float delta = (sample_depth - center_depth) * params.sun.w;
			// Negative delta means the sampled pixel is closer to the camera.
			float occluder = 1.0 - smoothstep(-0.030, 0.005, delta);
			float bright = max(luminance(sample_color) - 0.25, 0.0);
			float density = 0.006 + bright * 0.55;
			shaft += density * weight * (1.0 - 0.78 * occluder) * edge.x * edge.y;
			weight *= 0.90;
		}
	}
	float lit = clamp(shaft * 2.6, 0.0, 1.0);

	// Reconstruct the view ray and the linear distance to the opaque surface.
	// The orbit camera is orthographic, so every pixel has its own ray origin
	// on the near plane; perspective support stays for safety.
	bool ortho = params.sun_dir.w > 0.5;
	vec3 origin;
	vec3 ray;
	float surface_dist;
	if (ortho) {
		float half_height = params.cam_right.w;
		float aspect = params.cam_up.w;
		origin = params.cam_pos.xyz
			+ params.cam_right.xyz * ((uv.x * 2.0 - 1.0) * half_height * aspect)
			+ params.cam_up.xyz * ((1.0 - uv.y * 2.0) * half_height);
		ray = normalize(params.cam_forward.xyz);
		surface_dist = params.cam_pos.w - center_depth * (params.cam_pos.w - params.cam_forward.w);
	} else {
		origin = params.cam_pos.xyz;
		ray = normalize(
			params.cam_right.xyz * ((uv.x * 2.0 - 1.0) * params.cam_right.w * params.cam_up.w)
			+ params.cam_up.xyz * ((1.0 - uv.y * 2.0) * params.cam_right.w)
			+ params.cam_forward.xyz);
		float near_plane = params.cam_forward.w;
		float far_plane = params.cam_pos.w;
		float view_depth = near_plane * far_plane
			/ max(center_depth * (far_plane - near_plane) + near_plane, 0.0001);
		surface_dist = view_depth / max(dot(ray, params.cam_forward.xyz), 0.0001);
	}

	// Slab test against the fog volume.
	vec3 inv = 1.0 / (sign(ray + vec3(0.0000001)) * max(abs(ray), vec3(0.00001)));
	vec3 a = (BOX_MIN - origin) * inv;
	vec3 b = (BOX_MAX - origin) * inv;
	vec3 lo = min(a, b);
	vec3 hi = max(a, b);
	float start = max(0.0, max(lo.x, max(lo.y, lo.z)));
	float end = min(surface_dist, min(hi.x, min(hi.y, hi.z)));

	vec3 sum = vec3(0.0);
	float through = 1.0;
	vec3 sun_light = params.sun_color.rgb * params.fog.w * 0.68;
	float golden = params.fog.z;
	float phase = 0.35 + (0.75 + 1.9 * golden)
		* pow(max(dot(params.sun_dir.xyz, ray), 0.0), 3.0 + 4.0 * golden);

	if (end > start) {
		// Spend most samples in the low layer where fog and tree shadows show.
		float split = ray.y < -0.001
			? clamp((5.0 - origin.y) / ray.y, start, max(start, end)) : start;
		float ds_high = (split - start) / 6.0;
		float ds_low = max(0.0, end - split) / 18.0;
		float jitter = 0.25 + 0.5 * fract(52.9829189
			* fract(dot(vec2(pixel), vec2(0.06711056, 0.00583715))));
		vec3 p = origin + ray * (start + ds_high * jitter);
		float ds = ds_high;
		for (int i = 0; i < 24; i++) {
			if (i == 6) {
				p = origin + ray * (split + ds_low * jitter);
				ds = ds_low;
			}
			float edge = 1.0 - smoothstep(13.4, 17.0, max(abs(p.x), abs(p.z)));
			float bank = value_noise(p.xz * 0.039 + p.y * vec2(0.019, -0.027)
				+ params.settings.z * vec2(-0.0014, 0.0008));
			vec2 pond = p.xz - vec2(10.5, 6.0);
			float pool = exp(-0.029 * dot(pond, pond));
			float rho = params.scatter.w * edge
				* mix(0.20, 1.15, smoothstep(0.24, 0.70, bank))
				* (1.0 - 0.73 * pool)
				* exp(-0.38 * max(0.0, p.y - 1.3))
				* smoothstep(-0.7, 0.65, p.y)
				* (1.0 + params.fog.x * 2.4 * exp(-2.2 * max(0.0, p.y - 0.85)));
			float opacity = 1.0 - exp(-rho * ds);
			float shadow_lit = shadow_visibility(p);
			// The real shadow map drives the fog's sun term. The screen-space
			// proxy is only used when no shadow pass is available (Mobile/Low).
			float sun_visible = (params.shadow_pos.w > 0.5) ? shadow_lit : lit;
			vec3 incident = params.scatter.rgb
				+ sun_light * (phase * sun_visible * (1.0 - params.settings.w
					* smoothstep(0.31, 0.66, bank)));
			if (params.fog.y > 0.01) {
				for (int j = 0; j < 5; j++) {
					vec3 v = p - params.lamps[j].xyz;
					float d2 = dot(v, v);
					if (d2 < 30.0) {
						float cone = smoothstep(0.22, 0.72, -v.y * inversesqrt(d2 + 0.001));
						incident += params.fog.y * params.lamps[j].w
							* vec3(2.8, 1.45, 0.50) * cone
							* exp(-d2 * 0.26) / (1.0 + d2 * 0.45);
					}
				}
			}
			sum += through * opacity * incident;
			through *= 1.0 - opacity;
			p += ray * ds;
		}
	}

	// Debug view: blot the scene by the shadow mask so sampling and alignment
	// can be checked without the fog's scattering term hiding it.
	if (params.shadow_pos.w > 1.5) {
		vec3 debug_point = origin + ray * max(0.0, surface_dist - 0.05);
		float debug_lit = shadow_visibility(debug_point);
		imageStore(shaft_image, pixel, vec4(0.0, 0.0, 0.0, debug_lit));
		return;
	}

	// Add the screen-space shafts themselves, softened at night.
	sum += params.sun_color.rgb * shaft * sun_strength * 0.45
		* (0.55 + 0.45 * (1.0 - params.fog.y));
	imageStore(shaft_image, pixel, vec4(sum, through));
}
