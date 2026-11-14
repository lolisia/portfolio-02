shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec4 panel_rect = vec4(0.5, 0.93, 0.25, 0.03);
uniform float panel_radius = 0.018;
uniform float lens_strength = 0.010;
uniform vec3 tint = vec3(1.0);
uniform vec3 shadow_tint = vec3(1.0);
uniform vec3 highlight_tint = vec3(1.0);
uniform float saturation = 1.02;
uniform float contrast = 1.01;
uniform float vignette = 0.10;
uniform vec2 sun_uv = vec2(-10.0, -10.0);
uniform float sun_strength = 0.0;
uniform float shaft_strength = 0.0;
uniform vec3 sun_color = vec3(1.0, 0.85, 0.62);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 linear_to_srgb(vec3 c) {
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 half_size = max(panel_rect.zw, vec2(0.0001));
	vec2 q = abs(uv - panel_rect.xy) - half_size + vec2(panel_radius);
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - panel_radius;
	float edge = 1.0 - smoothstep(0.0, 0.018, abs(sd));
	vec2 dir = normalize((uv - panel_rect.xy) / half_size + vec2(0.00001));
	vec2 lens_uv = clamp(uv - dir * edge * lens_strength, vec2(0.001), vec2(0.999));

	vec3 color = texture(screen_tex, lens_uv).rgb;
	// I15: web composite only refracts at the panel bevel; it has no frosted
	// blur behind the transparent panel.
	float center_lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
	if (shaft_strength > 0.001 && sun_uv.x > -5.0) {
		// Screen-space light shafts: march toward the sun through a bright-pass
		// of the scene. Foreground trees/buildings punch dark gaps into the
		// streaks, approximating sun-shadow masking without a second shadow map.
		vec2 to_sun = sun_uv - uv;
		float ray_length = length(to_sun);
		vec2 ray_dir = to_sun / max(ray_length, 0.0001);
		vec2 step = ray_dir * min(ray_length, 0.42) / 11.0;
		vec2 sample_uv = uv;
		float shaft = 0.0;
		float weight = 1.0;
		for (int i = 0; i < 11; i++) {
			sample_uv += step;
			vec2 edge = smoothstep(vec2(0.0), vec2(0.12), sample_uv)
				* (1.0 - smoothstep(vec2(0.88), vec2(1.0), sample_uv));
			vec3 sample_color = texture(screen_tex, clamp(sample_uv, vec2(0.001), vec2(0.999))).rgb;
			float bright = max(dot(sample_color, vec3(0.2126, 0.7152, 0.0722)) - 0.44, 0.0);
			shaft += bright * weight * edge.x * edge.y;
			weight *= 0.90;
		}
		color += sun_color * shaft * shaft_strength * 0.34;
	}
	if (sun_strength > 0.001 && sun_uv.x > -5.0) {
		vec2 delta = (uv - sun_uv) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0);
		float dist = length(delta);
		float sky_mask = smoothstep(0.42, 0.82, center_lum);
		float glow = exp(-dist * 5.5) * 0.32 + exp(-dist * 24.0) * 0.75;
		color += sun_color * glow * sun_strength * sky_mask;
	}
	// The web grades the linear HDR frame (mist.js composite). This pass sees
	// the display-encoded image, so decode to linear first; grading sRGB
	// values directly made the vignette and contrast roughly twice as strong.
	color = srgb_to_linear(max(color, vec3(0.0)));
	float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color *= mix(shadow_tint, highlight_tint, smoothstep(0.02, 0.45, lum));
	lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = max(vec3(0.0), mix(vec3(lum), color, saturation)) * tint;
	// Web weather contrast pivots on mid grey: .18 * pow(c / .18, contrast).
	color = 0.18 * pow(color / 0.18, vec3(contrast));
	vec2 edge_dist = (uv - 0.5) * vec2(viewport_size.x / max(viewport_size.y, 1.0), 1.0);
	color *= 1.0 - vignette * smoothstep(0.25, 1.05, length(edge_dist));
	color = linear_to_srgb(color);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
