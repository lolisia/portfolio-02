#[compute]
#version 450

// Full-resolution composite: add the half-resolution shafts to a copy of the
// scene and write the result into the HDR scene color storage image.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D scene_color;
layout(set = 0, binding = 1) uniform sampler2D shaft_texture;
layout(set = 0, binding = 2, rgba16f) uniform image2D color_output;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_output);
	if (pixel.x >= size.x || pixel.y >= size.y) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec3 color = texture(scene_color, uv).rgb;
	vec3 shaft = texture(shaft_texture, uv).rgb;
	imageStore(color_output, pixel, vec4(color + shaft, 1.0));
}
