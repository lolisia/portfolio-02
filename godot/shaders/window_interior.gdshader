shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, fog_disabled;

// Web parity (src/interior.js + surfaces.js): the window is plain emissive
// glass. A warm room lamp drives its brightness, a TV tint reaches only the
// living-room window, and a person crossing the room dims the pane they pass.
// No room geometry is drawn behind the glass.

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.67, 0.27);
uniform float lamp_level : hint_range(0.0, 1.5) = 1.0;
uniform vec3 tv_color : source_color = vec3(0.40, 0.60, 1.0);
uniform float tv_level : hint_range(0.0, 1.5) = 0.0;
uniform vec2 tv_at = vec2(-1.95, -1.95);
uniform vec4 person = vec4(0.0, 0.0, 0.0, 99.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float lit = clamp(night, 0.0, 1.0);
	vec2 q = world_pos.xz;
	float tv_reach = 1.0 - smoothstep(0.4, 2.4, distance(q, tv_at));
	float screen = tv_reach * min(1.0, length(tv_color));
	float passing = person.z * (1.0 - smoothstep(0.22, 0.62, distance(q, person.xy)))
		* step(world_pos.y, person.w);

	vec3 day = mix(vec3(0.07, 0.10, 0.13), vec3(0.21, 0.28, 0.32),
		smoothstep(0.0, 1.0, world_pos.y * 0.5 + 0.5));
	vec3 glow = lamp_color * (0.025 + lit * 2.5 * lamp_level);
	glow += tv_color * (tv_level * lit * tv_reach * 1.4);
	glow *= (1.0 - 0.45 * screen) * (1.0 - passing);

	ALBEDO = day;
	EMISSION = glow;
	ALPHA = mix(0.9, 0.96, lit);
}
