shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// L1: the web background is a screen-space vertical gradient with a sun-edge
// glow, not a sky dome. A quad parented to the camera supplies that gradient;
// the ProceduralSky remains only for ambient/reflection light.

uniform vec3 bg_top : source_color = vec3(0.34, 0.55, 0.72);
uniform vec3 bg_bottom : source_color = vec3(0.68, 0.76, 0.80);
uniform vec2 sun_uv = vec2(-10.0, -10.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.62);
uniform float sun_strength = 0.0;
uniform float aspect = 1.777;

void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 color = mix(bg_top, bg_bottom, smoothstep(0.0, 1.0, t));
	if (sun_uv.x > -5.0 && sun_strength > 0.001) {
		vec2 delta = (UV - sun_uv) * vec2(aspect, 1.0);
		float dist = length(delta);
		float glow = exp(-dist * 5.5) * 0.32 + exp(-dist * 24.0) * 0.75;
		color += sun_color * glow * sun_strength;
	}
	ALBEDO = color;
}
