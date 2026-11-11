shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.055, 0.19, 0.17, 0.62);
uniform vec4 deep_color : source_color = vec4(0.006, 0.045, 0.085, 0.90);
uniform float wave_strength : hint_range(0.0, 3.0) = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D reflection_tex : filter_linear;
uniform mat4 reflection_projection;
uniform mat4 reflection_view;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec4 mirror_coord;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	mirror_coord = reflection_projection * (reflection_view * vec4(world_pos, 1.0));
	float w = sin(world_pos.x * 2.2 + TIME * 1.3) + sin(world_pos.z * 2.8 - TIME * 1.1);
	VERTEX.y += w * 0.004 * wave_strength;
}

void fragment() {
	vec2 p = (world_pos.xz - vec2(10.0, 6.1)) / vec2(4.5, 3.5);
	float d = clamp(length(p), 0.0, 1.0);
	float depth_mix = smoothstep(0.20, 1.05, d);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, depth_mix);
	ALPHA = mix(shallow_color.a, deep_color.a, depth_mix);
	ROUGHNESS = 0.09;
	METALLIC = 0.0;
	vec3 world_normal = normalize(vec3(
		sin(world_pos.x * 4.0 + TIME * 1.8) * 0.035,
		1.0,
		cos(world_pos.z * 4.6 - TIME * 1.5) * 0.035));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	vec2 ripple = vec2(
		sin(world_pos.x * 2.1 + TIME * 1.3),
		cos(world_pos.z * 2.4 - TIME * 1.1)) * 0.006;
	vec3 reflected = texture(screen_tex, clamp(SCREEN_UV + ripple, vec2(0.001), vec2(0.999))).rgb;
	vec2 mirror_uv = mirror_coord.xy / max(mirror_coord.w, 0.0001) * 0.5 + 0.5;
	// SubViewport textures use a top-left origin while clip space is bottom-left.
	mirror_uv.y = 1.0 - mirror_uv.y;
	vec3 mirror = texture(reflection_tex, clamp(mirror_uv + ripple * 1.5, vec2(0.001), vec2(0.999))).rgb;
	reflected = mix(reflected, mirror, reflection_strength);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Water is almost transparent looking straight down and mirrors the sky and
	// banks at grazing angles (Schlick, matching the web original's fifth power).
	float fresnel = 0.03 + 0.97 * pow(1.0 - facing, 5.0);
	ALBEDO = mix(ALBEDO, reflected, fresnel);
	ALPHA = mix(ALPHA, 0.97, fresnel * 0.55);
}

