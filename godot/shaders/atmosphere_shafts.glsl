#[compute]
#version 450

// Half-resolution depth-aware light-shaft pass. It marches from each pixel
// toward the sun through a bright-pass of the scene. A sample that lies closer
// to the camera than the current pixel is treated as an occluder, so foreground
// silhouettes punch depth-masked gaps into the shafts.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D scene_color;
layout(set = 0, binding = 1) uniform sampler2D scene_depth;
layout(set = 0, binding = 2, rgba16f) uniform image2D shaft_image;
layout(set = 0, binding = 3, std140) uniform Params {
	vec4 sun;       // xy: sun screen uv (sentinel x < -5 = hidden)
	vec4 sun_color; // rgb: color, w: strength
	vec4 settings;  // x: full width, y: full height, z: time, w: depth sign
} params;

float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 shaft_size = imageSize(shaft_image);
	if (pixel.x >= shaft_size.x || pixel.y >= shaft_size.y) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / vec2(shaft_size);
	vec3 shaft = vec3(0.0);
	if (params.sun_color.w > 0.001 && params.sun.x > -5.0) {
		float center_depth = texture(scene_depth, uv).r;
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
			float delta = (sample_depth - center_depth) * params.settings.w;
			// Negative delta means the sampled pixel is closer to the camera.
			float occluder = 1.0 - smoothstep(-0.030, 0.005, delta);
			float bright = max(luminance(sample_color) - 0.25, 0.0);
			float density = 0.006 + bright * 0.55;
			shaft += density * weight * (1.0 - 0.78 * occluder) * edge.x * edge.y;
			weight *= 0.90;
		}
		shaft *= params.sun_color.w * 0.55;
	}
	imageStore(shaft_image, pixel, vec4(shaft, 1.0));
}
