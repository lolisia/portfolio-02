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

func apply(hour: float, weather: int = 0, season: int = 1) -> void:
	var t := Daylight.evaluate(hour)
	var night: float = t["night"]
	var golden: float = t["golden"]
	var coverage: float = [0.0, 1.0, 2.0, 1.0, 1.0, 2.0][clampi(weather, 0, 5)]
	var overcast := clampf(coverage * 0.42, 0.0, 0.88)
	var dim := 1.0 - overcast * 0.35
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
	sun_energy *= lerp(1.0, 0.55, overcast) * dim
	sun.light_energy = sun_energy

	fill.light_color = Color(0.58, 0.73, 0.95)
	fill.light_energy = (0.16 + 0.10 * (1.0 - night)) * (1.0 - overcast * 0.5)

	sky_material.sky_top_color = Daylight.color_at(Daylight.SKY_TOP, t["from"], t["to"], t["f"]).lerp(
		Color(0.55, 0.62, 0.67), overcast * 0.55)
	sky_material.sky_horizon_color = Daylight.color_at(Daylight.SKY_HORIZON, t["from"], t["to"], t["f"]).lerp(
		Color(0.68, 0.72, 0.75), overcast * 0.55)
	sky_material.ground_bottom_color = Daylight.color_at(Daylight.SKY_LAND, t["from"], t["to"], t["f"]).lerp(
		Color(0.22, 0.25, 0.25), overcast * 0.5)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_energy_multiplier = 1.0
	sky_material.sun_angle_max = 0.0

	env.ambient_light_sky_contribution = 0.58
	env.ambient_light_energy = 0.48
	env.background_energy_multiplier = 1.0
	env.fog_enabled = true
	env.fog_light_color = Daylight.color_at(Daylight.FOG_SCATTER, t["from"], t["to"], t["f"])
	env.fog_light_energy = 0.35
	env.fog_density = (0.0025 + 0.008 * night) * (1.0 + overcast * 0.8)
	env.fog_sky_affect = 0.18
	env.fog_aerial_perspective = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.14 + 0.42 * night
	env.glow_bloom = 0.04 + 0.10 * night
	env.glow_hdr_threshold = lerp(1.05, 0.35, night)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.98
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06 + 0.16 * golden - 0.12 * overcast
	env.adjustment_contrast = 1.02 + 0.04 * overcast
	env.adjustment_brightness = 1.0 - 0.08 * overcast
	if season == 3:
		env.adjustment_saturation *= 0.88

	if world != null:
		world.set_night(night)

