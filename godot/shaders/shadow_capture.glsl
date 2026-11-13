#[compute]
#version 450

// Reads the shadow camera's reverse-Z orthographic depth and writes a linear
// distance (normalized by the far plane) into the camera's color buffer. The
// main atmosphere compositor samples that color texture as the sun shadow map.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D scene_depth;
layout(set = 0, binding = 1, rgba16f) uniform image2D color_output;
layout(set = 0, binding = 2, std140) uniform Params {
	vec4 planes; // x: near, y: far
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_output);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	float z = texture(scene_depth, uv).r;
	float distance = params.planes.y - z * (params.planes.y - params.planes.x);
	imageStore(color_output, pixel, vec4(clamp(distance / params.planes.y, 0.0, 1.0), 0.0, 0.0, 1.0));
}
