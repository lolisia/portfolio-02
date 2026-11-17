shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, fog_disabled;

// Pixel-sized night stars; independent of orbit zoom and phone DPI.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;

float star_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	// Pixel-space stars stay small on a high-DPI phone and at every zoom.
	// acos(dot(dir,star_dir)) rounded to zero over a broad area on mobile,
	// turning the old tiny angular radii into large flat discs.
	vec2 grid = SCREEN_UV * VIEWPORT_SIZE / 46.0;
	vec2 cell = floor(grid);
	float seed = star_hash(cell);
	if (seed < 0.78) { discard; }
	vec2 jitter = vec2(star_hash(cell + 7.3), star_hash(cell + 19.1));
	vec2 center = vec2(0.18) + jitter * 0.64;
	float distance = length((fract(grid) - center) * 46.0);
	float size = mix(0.55, 1.1, star_hash(cell + 3.7));
	float power = pow(clamp((seed - 0.55) / 0.45, 0.0, 1.0), 2.4);
	float core = 1.0 - smoothstep(max(0.0, size - 0.5), size + 0.5, distance);
	float halo = (1.0 - smoothstep(size, size + 1.0, distance)) * 0.06;
	float twinkle = 0.74 + 0.26 * sin(clock * (1.4 + 2.6 * star_hash(cell + 11.9))
		+ seed * 91.0);
	vec3 hue = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.90, 0.74),
		star_hash(cell + 29.3));
	// The camera looks down at the diorama, so the visible background is the
	// lower half of the dome. Fade by screen height like the web composite,
	// not by the dome's local y.
	float screen_fade = mix(0.15, 1.0, 1.0 - SCREEN_UV.y);
	float brightness = (0.16 + 1.7 * power) * twinkle * screen_fade * amount;
	vec3 color = hue * (core + halo) * brightness;
	ALBEDO = color;
	ALPHA = 1.0;
}
