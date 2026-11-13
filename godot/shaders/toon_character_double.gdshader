shader_type spatial;
render_mode cull_disabled;

// Double-sided variant for hair / "nol" materials, mirroring the web's
// MeshToonMaterial side: DoubleSide rule.

uniform sampler2D albedo_tex : source_color, filter_linear, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.92;
	SPECULAR = 0.0;
	METALLIC = 0.0;
	EMISSION = tex.rgb * 0.04;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float ramp = ndl < 0.33333 ? 0.37647 : (ndl < 0.66667 ? 0.71373 : 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp / PI;
}
