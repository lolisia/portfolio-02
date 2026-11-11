shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

// Expanding rain ring on the pond. Per-instance custom data stores the fade.

uniform sampler2D ring_tex : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);

varying float v_fade;

void vertex() {
	v_fade = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec4 ring = texture(ring_tex, UV);
	ALBEDO = tint.rgb * ring.rgb;
	ALPHA = ring.a * v_fade;
}
