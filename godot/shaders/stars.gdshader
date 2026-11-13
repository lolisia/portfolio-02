shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, fog_disabled;

// Procedural night-sky stars, ported from the web composite (src/mist.js).
// Generating stars from the dome direction instead of a texture keeps every
// star a fixed small angular size; a texture texel was magnified to ~20 px by
// the orthographic camera and showed up as blurred squares.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;

varying vec3 v_dir;

const float TAU_F = 6.28318530718;
const float PI_F = 3.14159265359;

float star_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	v_dir = normalize(VERTEX);
}

void fragment() {
	vec3 dir = normalize(v_dir);
	float lat = asin(clamp(dir.y, -1.0, 1.0));
	float lon = atan(dir.z, dir.x);

	// Equal-area cylindrical cells: one possible star per cell. This keeps the
	// density even over the sphere instead of crowding the UV pole. The ortho
	// camera sees only a tiny patch of the dome, so the grid is fine.
	const vec2 cells = vec2(1400.0, 700.0);
	vec2 grid = vec2(
		(lon / TAU_F + 0.5) * cells.x,
		(sin(lat) * 0.5 + 0.5) * cells.y);
	vec2 cell = floor(grid);

	float seed = star_hash(cell);
	if (seed < 0.42) {
		discard;
	}
	vec2 jitter = vec2(star_hash(cell + 7.3), star_hash(cell + 19.1));
	vec2 center = (cell + vec2(0.18, 0.18) + jitter * 0.64) / cells;
	float star_lon = (center.x - 0.5) * TAU_F;
	float star_lat = asin(clamp(center.y * 2.0 - 1.0, -1.0, 1.0));
	vec3 star_dir = vec3(cos(star_lat) * cos(star_lon), sin(star_lat),
		cos(star_lat) * sin(star_lon));

	float distance = acos(clamp(dot(dir, star_dir), -1.0, 1.0));
	float size = mix(0.00013, 0.00038, star_hash(cell + 3.7));
	float power = pow(clamp((seed - 0.55) / 0.45, 0.0, 1.0), 2.4);
	float core = 1.0 - smoothstep(size * 0.30, size, distance);
	float halo = (1.0 - smoothstep(size, size * 2.4, distance)) * 0.10;
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
