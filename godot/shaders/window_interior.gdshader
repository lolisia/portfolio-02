shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, fog_disabled;

// A shallow lit room seen through the cottage glass: plaster wall, plank
// floor, curtains, table/chair, shelves, a reading lamp and a TV. The room is
// drawn in the window quad, matching the original's window-only interior.

uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.67, 0.27);
uniform float lamp_level : hint_range(0.0, 1.5) = 1.0;
uniform vec3 tv_color : source_color = vec3(0.40, 0.60, 1.0);
uniform float tv_level : hint_range(0.0, 1.5) = 0.0;

varying vec2 room_uv;

float box_mask(vec2 p, vec2 lo, vec2 hi) {
	return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y);
}

void vertex() {
	// The glass is a unit box; local y is up, so this maps top-left to (0,0).
	room_uv = vec2(VERTEX.x + 0.5, 0.5 - VERTEX.y);
}

void fragment() {
	vec2 p = room_uv;
	float lit = clamp(night, 0.0, 1.0);

	// Back wall and plank floor.
	vec3 wall = mix(vec3(0.55, 0.31, 0.16), vec3(0.21, 0.12, 0.075),
		smoothstep(0.0, 0.62, p.y));
	float floor_mask = smoothstep(0.64, 0.69, p.y);
	vec3 floor_color = vec3(0.29, 0.17, 0.09)
		+ 0.035 * sin(p.x * 42.0 + p.y * 8.0);
	wall = mix(wall, floor_color, floor_mask);

	// Rug.
	vec2 rug_p = (p - vec2(0.54, 0.84)) / vec2(0.30, 0.11);
	wall = mix(wall, vec3(0.38, 0.13, 0.10),
		(1.0 - smoothstep(0.72, 1.0, length(rug_p))) * floor_mask);

	// Curtains with soft vertical folds.
	float fold = 0.5 + 0.5 * sin(p.x * 74.0 + p.y * 4.0);
	float curtain_mask = max(smoothstep(0.15, 0.0, p.x),
		smoothstep(0.85, 1.0, p.x));
	vec3 curtain = mix(vec3(0.20, 0.065, 0.05), vec3(0.38, 0.14, 0.09), fold);
	wall = mix(wall, curtain, curtain_mask * (1.0 - 0.55 * floor_mask));

	// Table with legs, a chair, and a little vase.
	float table = box_mask(p, vec2(0.16, 0.58), vec2(0.47, 0.65));
	wall = mix(wall, vec3(0.24, 0.13, 0.07), table);
	float legs = box_mask(p, vec2(0.19, 0.65), vec2(0.215, 0.84))
		+ box_mask(p, vec2(0.43, 0.65), vec2(0.455, 0.84));
	wall = mix(wall, vec3(0.145, 0.08, 0.045), clamp(legs, 0.0, 1.0));
	float chair = box_mask(p, vec2(0.50, 0.68), vec2(0.61, 0.72))
		+ box_mask(p, vec2(0.505, 0.72), vec2(0.60, 0.84))
		+ box_mask(p, vec2(0.50, 0.55), vec2(0.595, 0.69));
	wall = mix(wall, vec3(0.17, 0.095, 0.055), clamp(chair, 0.0, 1.0));
	wall = mix(wall, vec3(0.60, 0.33, 0.17),
		box_mask(p, vec2(0.31, 0.50), vec2(0.35, 0.58)));

	// Framed picture and shelves on the right wall.
	wall = mix(wall, vec3(0.12, 0.09, 0.06),
		box_mask(p, vec2(0.66, 0.19), vec2(0.85, 0.37)));
	wall = mix(wall, vec3(0.70, 0.42, 0.23),
		box_mask(p, vec2(0.68, 0.21), vec2(0.83, 0.35)));
	wall = mix(wall, vec3(0.36, 0.21, 0.11),
		box_mask(p, vec2(0.66, 0.44), vec2(0.88, 0.47))
		+ box_mask(p, vec2(0.66, 0.58), vec2(0.88, 0.61)));
	wall = mix(wall, vec3(0.55, 0.25, 0.18),
		box_mask(p, vec2(0.68, 0.47), vec2(0.72, 0.58))
		+ box_mask(p, vec2(0.74, 0.47), vec2(0.79, 0.58))
		+ box_mask(p, vec2(0.81, 0.47), vec2(0.86, 0.53)));

	// Floor lamp: stand, shade and a warm pool.
	float stand = box_mask(p, vec2(0.225, 0.38), vec2(0.243, 0.66));
	wall = mix(wall, vec3(0.18, 0.12, 0.07), stand);
	float shade = box_mask(p, vec2(0.17, 0.30), vec2(0.30, 0.38));
	wall = mix(wall, mix(vec3(0.55, 0.32, 0.14), lamp_color, 0.55), shade);
	vec2 lamp_delta = (p - vec2(0.235, 0.36)) * vec2(2.1, 2.4);
	float lamp_glow = lamp_level * exp(-dot(lamp_delta, lamp_delta) * 5.5);
	wall += lamp_color * lamp_glow * 0.85;

	// TV on the right shelf: a dark bezel and a flickering colour screen.
	float tv_bezel = box_mask(p, vec2(0.68, 0.40), vec2(0.88, 0.60));
	float tv_screen = box_mask(p, vec2(0.695, 0.42), vec2(0.865, 0.58));
	wall = mix(wall, vec3(0.045, 0.04, 0.045), tv_bezel);
	float scan = 0.72 + 0.28 * sin(p.y * 150.0 + TIME * 9.0);
	vec3 tv_glow = tv_color * tv_level * scan;
	wall = mix(wall, tv_glow + vec3(0.02), tv_screen);
	wall += tv_color * tv_level * 0.35 * tv_screen;

	// Daytime glass and muntins.
	vec3 day = mix(vec3(0.07, 0.10, 0.13), vec3(0.21, 0.28, 0.32), p.y);
	day += vec3(0.10, 0.14, 0.16) * smoothstep(0.30, 0.0, abs(p.x - 0.30 + p.y * 0.15));
	float muntin = max(step(abs(p.x - 0.5), 0.012), step(abs(p.y - 0.5), 0.012));
	wall = mix(wall, vec3(0.10, 0.07, 0.05), muntin * 0.9);
	day = mix(day, vec3(0.09, 0.09, 0.10), muntin);

	ALBEDO = mix(day, wall, lit);
	ALPHA = mix(0.55, 0.96, lit);
}
