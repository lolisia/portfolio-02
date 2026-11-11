shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, fog_disabled;

// Night star dome. The texture is a transparent star field; additive blending
// keeps the existing sky gradient visible underneath.

uniform sampler2D star_tex : filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 star = texture(star_tex, UV);
	ALBEDO = star.rgb * amount;
	ALPHA = 1.0;
}
