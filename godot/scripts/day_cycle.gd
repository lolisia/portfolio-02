extends RefCounted
class_name DayCycle

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_material: ProceduralSkyMaterial
var world: FarmWorld

func setup(p_sun: DirectionalLight3D, p_fill: DirectionalLight3D, p_env: Environment,
		p_sky: ProceduralSkyMaterial, p_world: FarmWorld) -> void:
	sun = p_sun
	fill = p_fill
	env = p_env
	sky_material = p_sky
	world = p_world

func apply(hour: float, weather: int = 0, _season: int = 1,
		coverage_value: float = -1.0) -> void:
	var t := Daylight.evaluate(hour)
	var night: float = t["night"]
	var golden: float = t["golden"]
	var coverage: float = coverage_value if coverage_value >= 0.0 \
		else [0.0, 1.0, 2.0, 1.0, 1.0, 2.0][clampi(weather, 0, 5)]
	var overcast := clampf(coverage * 0.42, 0.0, 0.88)
	var moon: bool = t["direction"].y < 0.0

	var sun_pos: Vector3 = t["direction"] * (33.0 if not moon else -33.0)
	sun.look_at_from_position(sun_pos, Vector3.ZERO, Vector3.UP)
	if moon:
		sun.light_color = Color(0.65, 0.76, 0.93)
	else:
		sun.light_color = Daylight.sun_color(t)
	var elevation := absf(t["direction"].y)
	var sun_energy := 0.0
	if moon:
		sun_energy = 0.22 * smoothstep(0.0, 0.24, elevation)
	else:
		sun_energy = 1.16 * (1.0 + 1.1 * golden) * smoothstep(-0.02, 0.34, elevation)
	# L5: web main.js weather curve — clear/cloudy eases to .52, then storm to .25.
	sun_energy *= lerp(1.0, 0.52, minf(coverage, 1.0)) if coverage <= 1.0 \
		else lerpf(0.52, 0.25, coverage - 1.0)

	fill.light_color = Color(0.58, 0.73, 0.95)
	fill.light_energy = (0.16 + 0.10 * (1.0 - night)) * (1.0 - overcast * 0.5)

	var backdrop: Color = Daylight.color_at(Daylight.BACKDROP, t["from"], t["to"], t["f"])
	var clear := 1.0 - minf(1.0, overcast * 1.1)
	# Web dimming: 1→.92 over the first weather step, .92→.68 for a storm.
	var dimming := lerpf(1.0, 0.92, minf(coverage, 1.0)) if coverage <= 1.0 \
		else lerpf(0.92, 0.68, coverage - 1.0)
	backdrop = backdrop.lerp(Color(0.56, 0.62, 0.66), overcast * 0.55)
	var top_color: Color = backdrop.lerp(
		Daylight.color_at(Daylight.SKY_BACK_TOP, t["from"], t["to"], t["f"]), 0.60 * clear)
	var horizon_color: Color = backdrop.lerp(
		Daylight.color_at(Daylight.SKY_BACK_BOTTOM, t["from"], t["to"], t["f"]), 0.55 * clear)
	top_color *= dimming
	horizon_color *= dimming
	var ground_color: Color = Daylight.color_at(Daylight.SKY_LAND, t["from"], t["to"], t["f"]).lerp(
		Color(0.22, 0.25, 0.25), overcast * 0.5)
	var fog_color: Color = Daylight.color_at(Daylight.FOG_SCATTER, t["from"], t["to"], t["f"])

	# L9(X): the web has no season-specific sky/fog tint; season changes only
	# foliageTint and winterBare. Keep the time-of-day palette untouched.

	sun.light_energy = sun_energy
	sky_material.sky_top_color = top_color
	sky_material.sky_horizon_color = horizon_color
	# Below the diorama the world falls away into a dark void rather than a
	# bright green hemisphere; the sky gradient stays at the horizon.
	sky_material.ground_bottom_color = ground_color.darkened(0.78).lerp(
		Color(0.02, 0.035, 0.045), 0.40)
	sky_material.ground_horizon_color = horizon_color
	sky_material.ground_curve = 0.18
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_energy_multiplier = 1.0
	sky_material.sun_angle_max = 9.0
	sky_material.sun_curve = 0.12

	env.ambient_light_sky_contribution = 0.58
	env.ambient_light_energy = 0.48
	env.background_energy_multiplier = 1.0
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_light_energy = 0.35
	env.fog_density = (0.0025 + 0.008 * night) * (1.0 + overcast * 0.8)
	env.fog_sky_affect = 0.18
	env.fog_aerial_perspective = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.14 + 0.42 * night
	env.glow_bloom = 0.04 + 0.10 * night
	env.glow_hdr_threshold = lerp(1.05, 0.35, night)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.14
	# L9(X): the web grades only in the composite pass; no Environment
	# adjustment saturation/contrast/brightness or seasonal sky tint.
	env.adjustment_enabled = false

	if world != null:
		world.set_night(night)

