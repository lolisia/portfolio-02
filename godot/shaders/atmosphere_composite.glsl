#[compute]
#version 450

// Full-resolution composite: the half-resolution atmosphere texture holds
// rgb = in-scattered fog/shaft light and a = transmittance. Apply it to a copy
// of the HDR scene color and write the result back into the scene color image.

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
	vec4 atmosphere = texture(shaft_texture, uv);
	imageStore(color_output, pixel, vec4(color * atmosphere.a + atmosphere.rgb, 1.0));
}
