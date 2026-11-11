shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

// Snow print decal: the texture carries the hollow shape and the per-instance
// custom data red channel carries its fade (fresh prints fade as snow fills in).

uniform sampler2D print_tex : filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float v_fade;

void vertex() {
	v_fade = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec4 print = texture(print_tex, UV);
	ALBEDO = tint.rgb * print.rgb;
	ALPHA = print.a * v_fade;
}
