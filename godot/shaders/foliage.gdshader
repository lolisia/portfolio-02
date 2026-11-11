shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float wind_strength : hint_range(0.0, 2.5) = 1.0;
uniform vec4 base_color : source_color = vec4(1.0);

varying vec3 v_color;

void vertex() {
	v_color = INSTANCE_CUSTOM.rgb;
	float sway = INSTANCE_CUSTOM.a;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.39, 0.23));
	float gust = sin(TIME * 1.37 - phase) + 0.42 * sin(TIME * 2.31 - phase * 0.71);
	float h = max(0.0, VERTEX.y);
	float bend = sway * (sway > 0.1 ? h : h * h) * gust * wind_strength;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.36;
}

void fragment() {
	ALBEDO = base_color.rgb * v_color;
	ROUGHNESS = 0.86;
	SPECULAR = 0.15;
}
