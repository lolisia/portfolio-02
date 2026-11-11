shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec4 panel_rect = vec4(0.5, 0.93, 0.25, 0.03);
uniform float panel_radius = 0.018;
uniform float lens_strength = 0.010;
uniform vec3 tint = vec3(1.0);
uniform float saturation = 1.02;
uniform float contrast = 1.01;
uniform float vignette = 0.10;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 half_size = max(panel_rect.zw, vec2(0.0001));
	vec2 q = abs(uv - panel_rect.xy) - half_size + vec2(panel_radius);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - panel_radius;
	float edge = 1.0 - smoothstep(0.0, 0.018, abs(sd));
	vec2 dir = normalize((uv - panel_rect.xy) / half_size + vec2(0.00001));
	vec2 lens_uv = clamp(uv - dir * edge * lens_strength, vec2(0.001), vec2(0.999));

	vec3 color = texture(screen_tex, lens_uv).rgb;
	float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(lum), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	color *= tint;

	vec2 edge_dist = (uv - 0.5) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0);
	color *= 1.0 - vignette * smoothstep(0.25, 1.05, length(edge_dist));
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
