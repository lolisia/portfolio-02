extends RefCounted
class_name DayCycle

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
## False while the compositor raymarch provides the fog (web mist.js only).
var depth_fog := true
var world: FarmWorld
var backdrop_material: ShaderMaterial

func setup(p_sun: DirectionalLight3D, p_fill: DirectionalLight3D, p_env: Environment,
		p_sky: ShaderMaterial, p_world: FarmWorld) -> void:
	sun = p_sun
	fill = p_fill
	env = p_env
	sky_material = p_sky
	world = p_world

func set_backdrop(material: ShaderMaterial) -> void:
	backdrop_material = material

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
		# three.js lights are irradiance shaded with albedo/PI; Godot energy
		# is shaded with albedo directly, so web intensities divide by PI.
		sun_energy = 0.34 / PI * smoothstep(0.0, 0.24, elevation)
	else:
		sun_energy = 2.85 / PI * (1.0 + 1.1 * golden) * smoothstep(-0.02, 0.34, elevation)
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
	if backdrop_material != null:
		# Pass sRGB Colors: Godot converts Color values to linear when it
		# uploads vec3/vec4 uniforms, so converting here as well darkened and
		# oversaturated the sky twice.
		backdrop_material.set_shader_parameter("bg_top", top_color)
		backdrop_material.set_shader_parameter("bg_bottom", horizon_color)
	var ground_color: Color = Daylight.color_at(Daylight.SKY_LAND, t["from"], t["to"], t["f"]).lerp(
		Color(0.22, 0.25, 0.25), overcast * 0.5)
	var fog_color: Color = Daylight.color_at(Daylight.FOG_SCATTER, t["from"], t["to"], t["f"])

	# L9(X): the web has no season-specific sky/fog tint; season changes only
	# foliageTint and winterBare. Keep the time-of-day palette untouched.

	sun.light_energy = sun_energy
	# L3 (web sky.js): the lighting probe is its own zenith/horizon/land
	# palette, not the screen backdrop, dimmed by weather and night in linear
	# space. Vector3 uniforms are uploaded as-is, so pass linear values.
	var probe_scale := (1.0 - 0.19 * coverage) * (1.0 - 0.75 * night)
	var zenith := Daylight.color_at(Daylight.SKY_TOP, t["from"], t["to"], t["f"]).srgb_to_linear()
	var horizon := Daylight.color_at(Daylight.SKY_HORIZON, t["from"], t["to"], t["f"]).srgb_to_linear()
	var land := Daylight.color_at(Daylight.SKY_LAND, t["from"], t["to"], t["f"]).srgb_to_linear()
	sky_material.set_shader_parameter("sky_top",
		Vector3(zenith.r, zenith.g, zenith.b) * probe_scale)
	sky_material.set_shader_parameter("sky_horizon",
		Vector3(horizon.r, horizon.g, horizon.b) * probe_scale)
	sky_material.set_shader_parameter("sky_land",
		Vector3(land.r, land.g, land.b) * probe_scale)
	sky_material.set_shader_parameter("sun_dir", t["direction"])
	sky_material.set_shader_parameter("sun_color", sun.light_color)
	sky_material.set_shader_parameter("sun_strength",
		(0.45 + 0.75 * golden) * (1.0 - night * 0.75))
	sky_material.set_shader_parameter("cloud_amount",
		clampf(0.08 + overcast * 0.78, 0.0, 0.90))
	sky_material.set_shader_parameter("cloud_clock",
		float(Time.get_ticks_msec()) / 1000.0)

	# Web: scene.environmentIntensity = .63 on the sky probe.
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 0.63
	env.background_energy_multiplier = 1.0
	env.fog_enabled = depth_fog
	env.fog_light_color = fog_color
	env.fog_light_energy = 0.35
	env.fog_density = (0.0025 + 0.008 * night) * (1.0 + overcast * 0.8)
	env.fog_sky_affect = 0.18
	env.fog_aerial_perspective = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.05 + 0.06 * golden + 0.11 * night
	env.glow_bloom = 0.04 + 0.10 * night
	env.glow_hdr_threshold = lerpf(1.25, 0.55, night)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Godot's ACES divides by the tonemapped white and biases exposure by
	# 1.8; white 16 and exposure 1.08 reproduce three's ACESFilmic at
	# toneMappingExposure 1.14 within one 8-bit step (measured on a grey ramp).
	env.tonemap_white = 16.0
	env.tonemap_exposure = 1.08
	# L9(X): the web grades only in the composite pass; no Environment
	# adjustment saturation/contrast/brightness or seasonal sky tint.
	env.adjustment_enabled = false

	if world != null:
		world.set_night(night)

