shader_type sky;

// L3: HDR sky for ambient/reflection light. The visible background is the
// screen-space backdrop quad; this shader supplies the palette, cloud veil and
// sun glow that the water and materials reflect, matching surfaces.js.

uniform vec3 sky_top : source_color = vec3(0.24, 0.42, 0.58);
uniform vec3 sky_horizon : source_color = vec3(0.42, 0.50, 0.54);
uniform vec3 sky_land : source_color = vec3(0.10, 0.12, 0.10);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.62);
uniform float sun_strength = 0.8;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.2;
uniform float cloud_clock = 0.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float n = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		n += a * noise2(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return n;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = clamp(dir.y, -1.0, 1.0);
	vec3 color;
	if (up >= 0.0) {
		color = mix(sky_horizon, sky_top, smoothstep(0.0, 1.0, pow(up, 0.55)));
	} else {
		color = mix(sky_horizon, sky_land, smoothstep(0.0, 1.0, pow(-up, 0.55)));
	}
	// Cloud veil: a slowly drifting fbm layer around the upper hemisphere.
	vec2 cloud_uv = dir.xz / max(0.15, abs(dir.y) + 0.24);
	float cloud = smoothstep(0.42, 0.72,
		fbm2(cloud_uv * 2.2 + vec2(cloud_clock * 0.010, -cloud_clock * 0.006)));
	color = mix(color, vec3(0.58, 0.62, 0.66), cloud * cloud_amount
		* smoothstep(0.0, 0.25, up));
	// Sun disc and broad glow, like the web sky/PMREM source.
	float facing = max(dot(dir, normalize(sun_dir)), 0.0);
	color += sun_color * (pow(facing, 260.0) * 2.2 + pow(facing, 10.0) * 0.20)
		* sun_strength;
	COLOR = color;
}
