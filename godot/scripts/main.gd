extends Node3D

## Godot port entry point. Builds the diorama, orbit camera, environment,
## day/night cycle and the control panel.

const FarmWorld = preload("res://scripts/world.gd")
const OrbitCamera = preload("res://scripts/orbit_camera.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const DayCycle = preload("res://scripts/day_cycle.gd")
const UnityChan = preload("res://scripts/unity_chan.gd")
const WeatherFX = preload("res://scripts/weather_fx.gd")
const PostProcess = preload("res://scripts/post_process.gd")
const FarmLife = preload("res://scripts/farm_life.gd")
const WaterReflection = preload("res://scripts/water_reflection.gd")
const Footprints = preload("res://scripts/footprints.gd")
const NightLife = preload("res://scripts/night_life.gd")
const SeasonsFX = preload("res://scripts/seasons_fx.gd")
const QualityManager = preload("res://scripts/quality_manager.gd")
const AtmosphereEffect = preload("res://scripts/atmosphere_effect.gd")
const SunShadow = preload("res://scripts/sun_shadow.gd")
const PathDebug = preload("res://scripts/path_debug.gd")

var world: FarmWorld
var orbit: OrbitCamera
var ui: GameUI
var character: UnityChan
var weather_fx: WeatherFX
var seasons_fx: SeasonsFX
var post: PostProcess
var farm_life: FarmLife
var water_reflection: WaterReflection
var footprints: Footprints
var night_life: NightLife
var quality_manager: QualityManager
var atmosphere_effect: AtmosphereEffect
var sun_shadow: SunShadow
var path_debug: PathDebug
var use_shadow_depth := true
var shadow_debug := false
var mist: FogVolume
var mist_material: FogMaterial
var low_mist: FogVolume
var low_mist_material: FogMaterial
var quality := 0
var high_end_rendering := true
var day_cycle: DayCycle
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_material: ProceduralSkyMaterial
var world_environment: WorldEnvironment

var hour := 8.5
var hour_target := 8.5
var wind := 3.0
var weather := 0
const WEATHER_COVERAGE := [0.0, 1.0, 2.0, 1.0, 1.0, 2.0]
const WEATHER_DENSITY := [1.0, 1.0, 1.0, 3.8, 1.4, 2.4]
var weather_weights: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var weather_coverage := 0.0
var weather_density := 1.0
var season := 1
var wet := 0.0
var snow_depth := 0.0
var _surface_wet := -1.0
var _surface_snow := -1.0
var auto_time := false
var auto_start := 8.5
var auto_elapsed := 0.0
var _wind_applied := -1.0
var _last_apply_hour := -999.0
var rain_fx := 0.0
var snow_fx := 0.0
var storm_fx := 0.0
var water_freeze := 0.0
var _water_freeze_applied := -1.0
var _presses: Dictionary = {}
var _trail: Array = []
var _trail_clock := 0.0
var adaptive_scale := 1.0
var _base_render_scale := 1.0
var _fps_smooth := 60.0
var _fps_check := 0.0
var _bench_target := 0
var _bench_frames := 0
var _bench_elapsed := 0.0

func _ready() -> void:
	_apply_content_scale()
	get_window().size_changed.connect(_apply_content_scale)
	_setup_environment()
	_setup_lights()

	world = FarmWorld.new()
	world.name = "FarmWorld"
	add_child(world)
	world.build()

	character = UnityChan.new()
	character.name = "UnityChan"
	character.world = world
	character.position = Vector3(-0.35, 0.0, 1.0)
	character.weather = weather
	character.season = season
	add_child(character)

	path_debug = PathDebug.new()
	path_debug.name = "PathDebug"
	add_child(path_debug)
	path_debug.setup(world, character)

	weather_fx = WeatherFX.new()
	weather_fx.name = "WeatherFX"
	weather_fx.world = world
	add_child(weather_fx)

	seasons_fx = SeasonsFX.new()
	seasons_fx.name = "SeasonsFX"
	seasons_fx.world = world
	add_child(seasons_fx)
	seasons_fx.setup()

	farm_life = FarmLife.new()
	farm_life.name = "FarmLife"
	farm_life.world = world
	farm_life.character = character
	farm_life.weather_fx = weather_fx
	add_child(farm_life)
	farm_life.build()

	footprints = Footprints.new()
	footprints.name = "Footprints"
	footprints.world = world
	add_child(footprints)
	footprints.setup()
	character.footprints = footprints
	farm_life.footprints = footprints

	orbit = OrbitCamera.new()
	orbit.name = "OrbitCamera"
	orbit.position = Vector3(31.0, 34.0, 41.0)
	orbit.target = Vector3(0.0, 1.0, 0.0)
	add_child(orbit)

	night_life = NightLife.new()
	night_life.name = "NightLife"
	night_life.world = world
	add_child(night_life)
	night_life.setup()

	high_end_rendering = String(RenderingServer.get_current_rendering_method()) == "forward_plus"
	if high_end_rendering:
		water_reflection = WaterReflection.new()
		water_reflection.name = "WaterReflection"
		add_child(water_reflection)
		water_reflection.setup(world.water, orbit, world.water.position.y)
		atmosphere_effect = null
		if DisplayServer.get_name() != "headless":
			sun_shadow = SunShadow.new()
			sun_shadow.name = "SunShadow"
			add_child(sun_shadow)
			sun_shadow.setup(world.get_world_3d())
			atmosphere_effect = AtmosphereEffect.new()
			var compositor := Compositor.new()
			compositor.compositor_effects = [atmosphere_effect]
			orbit.compositor = compositor
		_add_volumetric_mist()

	var cli: Array = []
	for arg in OS.get_cmdline_args():
		cli.append(arg)
	for arg in OS.get_cmdline_user_args():
		cli.append(arg)
	if "--house" in cli:
		orbit.set_view(Vector3(-1.0, 1.6, -1.2), 0.6747, 0.438, 3.0)
	if "--coop" in cli:
		orbit.set_view(Vector3(2.25, 1.7, -1.6), 0.0, 0.438, 3.3)
	if "--char" in cli:
		orbit.set_view(Vector3(-1.0, 0.65, 0.85), 0.0, 1.05, 7.0)
	if "--char2" in cli:
		orbit.set_view(Vector3(-1.0, 0.55, 1.75), 0.0, 1.35, 8.0)
	if "--charclose" in cli:
		orbit.max_zoom = 12.0
		orbit.set_view(Vector3(-0.35, 1.25, 1.0), 1.1, 1.12, 10.0)
	if "--pond" in cli:
		orbit.set_view(Vector3(10.2, 0.4, 6.3), 0.0, 0.438, 5.0)
	if "--pondside" in cli:
		orbit.set_view(Vector3(8.6, 0.6, 6.0), 1.95, 0.46, 2.3)
	if "--fishtest" in cli:
		orbit.set_view(Vector3(6.6, 0.6, 4.0), 0.55, 1.2, 4.0)
	if "--door" in cli:
		orbit.set_view(Vector3(-0.8, 1.0, -0.6), 0.25, 1.35, 4.2)
	if "--front" in cli:
		orbit.set_view(Vector3(-1.0, 1.2, -0.4), 0.1, 0.42, 4.0)
	if "--garden" in cli:
		orbit.set_view(Vector3(-1.1, 3.2, -7.65), 0.0, 0.438, 5.0)
	if "--stairs" in cli:
		orbit.set_view(Vector3(-5.4, 2.2, -4.4), 0.0, 0.438, 3.0)
	if "--falls" in cli:
		orbit.set_view(Vector3(13.4, -0.10, 6.1), 0.965, 0.391, 3.25)
	if "--porch" in cli:
		character.position = Vector3(-1.0, 0.0, 0.55)
		orbit.set_view(Vector3(-1.0, 1.2, 0.3), 0.0, 0.62, 3.0)
	if "--window" in cli:
		orbit.max_zoom = 12.0
		orbit.set_view(Vector3(-0.05, 1.35, -0.95), 0.0, 0.35, 10.0)

	ui = GameUI.new()
	ui.name = "GameUI"
	ui.layer = 2
	add_child(ui)
	post = PostProcess.new()
	post.name = "PostProcess"
	add_child(post)
	post.setup(ui)
	ui.time_changed.connect(_on_time_changed)
	ui.wind_changed.connect(_on_wind_changed)
	ui.weather_changed.connect(_on_weather_changed)
	ui.season_changed.connect(_on_season_changed)
	ui.auto_toggled.connect(_on_auto_toggled)
	ui.reset_requested.connect(_on_reset_requested)
	ui.quality_changed.connect(_on_quality_changed)

	quality = 1 if not high_end_rendering else 0
	quality_manager = QualityManager.new()
	quality_manager.setup(env, sun, world, water_reflection, weather_fx, seasons_fx,
		get_viewport(), mist)
	_set_quality(quality)

	day_cycle = DayCycle.new()
	day_cycle.setup(sun, fill, env, sky_material, world)
	_apply_time(true)
	world.set_wind(wind)
	world.set_surface_state(0.0, 0.0, season)
	_surface_wet = 0.0
	_surface_snow = 0.0
	_wind_applied = wind
	weather_fx.set_weather(weather)
	farm_life.hour = hour
	farm_life.wind = wind
	farm_life.weather = weather

	# Development shortcuts for previewing a settled weather/season state.
	if "--spring" in cli:
		season = 0
		ui.set_season(0)
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
	if "--autumn" in cli:
		season = 2
		ui.set_season(2)
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
	if "--winter" in cli:
		season = 3
		ui.set_season(3)
		snow_depth = 1.0
		_surface_snow = 1.0
		water_freeze = 1.0
		_water_freeze_applied = 1.0
		world.set_water_freeze(1.0)
		farm_life.water_freeze = 1.0
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
	if "--snow" in cli:
		weather = 4
		ui.set_weather(4)
		snow_depth = 1.0
		_surface_snow = 1.0
		snow_fx = 1.0
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
		weather_fx.set_weather(weather)
	if "--rain" in cli:
		weather = 2
		ui.set_weather(2)
		wet = 1.0
		_surface_wet = 1.0
		rain_fx = 1.0
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
		weather_fx.set_weather(weather)
	if "--storm" in cli:
		weather = 5
		ui.set_weather(5)
		wet = 1.0
		_surface_wet = 1.0
		snow_depth = 1.0
		_surface_snow = 1.0
		snow_fx = 1.0
		storm_fx = 1.0
		world.set_surface_state(wet, snow_depth, season)
		day_cycle.apply(hour, weather, season)
		weather_fx.set_weather(weather)
	if "--panel" in cli:
		ui.set_panel_open(true)
	if "--night" in cli:
		hour = 22.0
		hour_target = 22.0
		_apply_time(true)
	if "--dusk" in cli:
		hour = 18.6
		hour_target = 18.6
		_apply_time(true)
	if "--dawn" in cli:
		hour = 6.4
		hour_target = 6.4
		_apply_time(true)
	if "--auto" in cli:
		auto_time = true
		auto_start = hour
		auto_elapsed = 0.0
	if "--sunrise" in cli:
		orbit.set_view(Vector3(0.0, 1.0, 0.0), 1.57, 0.35, 1.0)
	if "--gather" in cli:
		character._begin_journey("gather")
	if "--fish" in cli:
		character._begin_journey("fish")
	if "--salute" in cli:
		character._begin_journey("salute")
	if "--fishnear" in cli:
		character.position = Vector3(6.5, 0.0, 4.2)
		character._begin_journey("fish")
	if "--gathernear" in cli:
		character.position = Vector3(1.0, 0.0, 2.2)
		character._begin_journey("gather")
	if "--pathdebug" in cli:
		path_debug.visible = true
	if "--snowtest" in cli:
		character.position = Vector3(-3.0, 0.0, 4.0)
		character._begin_journey("gather")
		orbit.max_zoom = 12.0
		orbit.set_view(Vector3(-2.2, 1.3, 3.4), 0.4, 0.95, 6.0)
	if "--low" in cli:
		_set_quality(2)
	if "--medium" in cli:
		_set_quality(1)
	if "--high" in cli:
		_set_quality(0)
	if "--noshadow" in cli:
		use_shadow_depth = false
	if "--shadowdebug" in cli:
		shadow_debug = true
	_snap_weather_blend()
	var shot_index := cli.find("--shot")
	if shot_index >= 0 and shot_index + 1 < cli.size():
		_capture_screenshot(String(cli[shot_index + 1]))
	var bench_index := cli.find("--bench")
	if bench_index >= 0:
		_bench_target = int(cli[bench_index + 1]) if bench_index + 1 < cli.size() else 600
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	orbit.v_offset = _desired_v_offset()
	orbit.set_portrait_scale(_desired_portrait_scale())
	ui.set_time_value(hour)
	ui.set_wind_value(wind)

func _exit_tree() -> void:
	if atmosphere_effect != null:
		atmosphere_effect.shutdown()
	if sun_shadow != null:
		sun_shadow.shutdown()

func _desired_v_offset() -> float:
	if ui == null:
		return 0.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x >= viewport_size.y:
		return 0.0
	return -22.0 if ui.is_panel_open() else -4.0

func _desired_portrait_scale() -> float:
	if ui == null:
		return 1.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x >= viewport_size.y:
		return 1.0
	return 1.38 if ui.is_panel_open() else 1.0

func _update_view_framing(delta: float) -> void:
	if orbit == null or ui == null:
		return
	var wanted_v_offset := _desired_v_offset()
	if absf(orbit.v_offset - wanted_v_offset) > 0.01:
		orbit.v_offset = lerpf(orbit.v_offset, wanted_v_offset, 1.0 - exp(-delta * 7.0))
	var wanted_scale := _desired_portrait_scale()
	if absf(orbit.portrait_scale - wanted_scale) > 0.0005:
		orbit.set_portrait_scale(lerpf(orbit.portrait_scale, wanted_scale, 1.0 - exp(-delta * 7.0)))

func _capture_screenshot(path: String) -> void:
	# Development helper: save the current window at its real resolution.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	get_tree().quit()

func _apply_content_scale() -> void:
	# Keep the UI at a readable physical size on phones while still scaling up
	# comfortably on very large desktop windows. With canvas_items stretch the
	# content size is the layout space; 0 would mean "use the window size".
	var window_size := get_window().size
	var ui_scale := clampf(float(window_size.y) / 720.0, 1.0, 1.75)
	get_window().content_scale_size = Vector2i(
		maxi(1, roundi(float(window_size.x) / ui_scale)),
		maxi(1, roundi(float(window_size.y) / ui_scale)))

func _setup_environment() -> void:
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.34, 0.55, 0.72)
	sky_material.sky_horizon_color = Color(0.68, 0.76, 0.80)
	sky_material.sky_curve = 0.15
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_bottom_color = Color(0.055, 0.075, 0.068)
	sky_material.ground_horizon_color = Color(0.68, 0.76, 0.80)
	sky_material.ground_curve = 0.18
	sky_material.ground_energy_multiplier = 1.0
	sky_material.sun_angle_max = 9.0
	sky_material.sun_curve = 0.12

	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.58
	env.ambient_light_energy = 0.48
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.14
	env.glow_enabled = true
	env.glow_intensity = 0.16
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	var method := String(RenderingServer.get_current_rendering_method())
	var high_end := method == "forward_plus"
	high_end_rendering = high_end
	env.ssao_enabled = high_end
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.0
	env.ssao_detail = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.50, 0.52)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.18
	env.volumetric_fog_enabled = high_end
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.55, 0.63, 0.64)
	env.volumetric_fog_length = 55.0
	env.volumetric_fog_detail_spread = 1.4
	env.volumetric_fog_anisotropy = 0.35
	env.adjustment_enabled = true

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)

func _add_volumetric_mist() -> void:
	var fog := FogVolume.new()
	fog.name = "ForestMist"
	fog.size = Vector3(36, 12, 36)
	fog.position = Vector3(0, 4, 0)
	mist_material = FogMaterial.new()
	mist_material.density = 0.12
	mist_material.albedo = Color(0.58, 0.68, 0.70)
	mist_material.emission = Color(0.01, 0.015, 0.02)
	mist_material.height_falloff = 0.38
	mist_material.edge_fade = 0.15
	fog.material = mist_material
	mist = fog
	add_child(fog)

	low_mist = FogVolume.new()
	low_mist.name = "LowMist"
	low_mist.size = Vector3(22, 2.4, 16)
	low_mist.position = Vector3(6.5, 1.35, 5.4)
	low_mist_material = FogMaterial.new()
	low_mist_material.density = 0.02
	low_mist_material.albedo = Color(0.62, 0.70, 0.72)
	low_mist_material.emission = Color(0.008, 0.012, 0.014)
	low_mist_material.height_falloff = 0.7
	low_mist_material.edge_fade = 0.3
	low_mist.material = low_mist_material
	low_mist.visible = false
	add_child(low_mist)

func _setup_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.91, 0.80)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	add_child(sun)

	fill = DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.light_color = Color(0.58, 0.73, 0.95)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	fill.look_at_from_position(Vector3(12.0, 19.0, 17.0), Vector3.ZERO, Vector3.UP)
	add_child(fill)

func _snap_weather_blend() -> void:
	for i in range(6):
		weather_weights[i] = 1.0 if i == weather else 0.0
	weather_coverage = float(WEATHER_COVERAGE[clampi(weather, 0, 5)])
	weather_density = float(WEATHER_DENSITY[clampi(weather, 0, 5)])
	rain_fx = weather_weights[2]
	snow_fx = weather_weights[4] + weather_weights[5]
	storm_fx = weather_weights[5]

func _update_weather_blend(delta: float) -> void:
	# Web parity (src/weather.js): all six weights ease toward the target with
	# k = 1 - e^(-0.85 dt), so coverage/density/rain/snow/storm change together
	# instead of snapping when the dropdown changes.
	var k := 1.0 - exp(-maxf(delta, 0.0) * 0.85)
	var difference := 0.0
	for i in range(6):
		var wanted := 1.0 if i == weather else 0.0
		weather_weights[i] += (wanted - weather_weights[i]) * k
		difference = maxf(difference, absf(wanted - weather_weights[i]))
	if difference < 0.0005:
		for i in range(6):
			weather_weights[i] = 0.0
		weather_weights[weather] = 1.0
	weather_coverage = 0.0
	weather_density = 0.0
	for i in range(6):
		weather_coverage += weather_weights[i] * float(WEATHER_COVERAGE[i])
		weather_density += weather_weights[i] * float(WEATHER_DENSITY[i])
	rain_fx = weather_weights[2]
	snow_fx = weather_weights[4] + weather_weights[5]
	storm_fx = weather_weights[5]

func _process(delta: float) -> void:
	if _bench_target > 0:
		_bench_frames += 1
		if _bench_frames > 30:
			_bench_elapsed += delta
		if _bench_frames >= _bench_target + 30:
			var avg := _bench_elapsed / float(maxi(_bench_target, 1))
			print("BENCH avg_ms=", snappedf(avg * 1000.0, 0.01),
				" fps=", snappedf(1.0 / maxf(avg, 0.0001), 0.1))
			get_tree().quit()
			return
	if auto_time:
		auto_elapsed += delta
		hour = fposmod(auto_start + auto_elapsed * 24.0 / 120.0, 24.0)
		hour_target = hour
		ui.set_time_value(hour)
		_apply_time(false)
	elif absf(hour - hour_target) > 0.001:
		hour = lerpf(hour, hour_target, 1.0 - exp(-delta * 10.0))
		if absf(hour - hour_target) < 0.002:
			hour = hour_target
		_apply_time(false)
	if absf(_wind_applied - wind) > 0.001:
		world.set_wind(wind)
		_wind_applied = wind

	_update_view_framing(delta)
	if OS.has_feature("mobile"):
		_fps_smooth = lerpf(_fps_smooth, Engine.get_frames_per_second(), 1.0 - exp(-delta * 0.3))
		_fps_check += delta
		if _fps_check > 2.0:
			_fps_check = 0.0
			var changed := false
			if _fps_smooth < 45.0 and adaptive_scale > 0.65:
				adaptive_scale = maxf(0.65, adaptive_scale - 0.05)
				changed = true
			elif _fps_smooth > 57.0 and adaptive_scale < 1.0:
				adaptive_scale = minf(1.0, adaptive_scale + 0.03)
				changed = true
			if changed:
				_apply_render_scale()

	if farm_life != null:
		farm_life.hour = hour
		farm_life.wind = wind
		farm_life.weather = weather
	if character != null:
		character.weather = weather
		character.season = season

	_update_weather_blend(delta)
	# Web atmosphere.soak(): rain eases wetness in at .5/s and it dries at
	# .035/s; fog no longer wets the ground.
	if rain_fx > wet:
		wet += (rain_fx - wet) * (1.0 - exp(-delta * 0.5))
	else:
		wet = maxf(rain_fx, wet - delta * 0.035)
	# Web seasons.js snow cover: accumulate while snowing, thaw per season
	# (rain melts fastest); winter damps toward a full cover.
	var thaw := float([0.14, 0.24, 0.09, 0.002][clampi(season, 0, 3)])
	var melt := lerpf(thaw, maxf(thaw, 0.3), rain_fx)
	var snow_rate := snow_fx * (0.016 + 0.017 * storm_fx) - (1.0 - snow_fx) * melt
	snow_depth = clampf(snow_depth + delta * snow_rate, 0.0, 1.0)
	if season == 3:
		snow_depth = lerpf(snow_depth, 1.0, 1.0 - exp(-delta * 1.25))
		if snow_depth > 0.995:
			snow_depth = 1.0
	if absf(wet - _surface_wet) > 0.002 or absf(snow_depth - _surface_snow) > 0.002:
		world.set_surface_state(wet, snow_depth, season)
		_surface_wet = wet
		_surface_snow = snow_depth

	if weather_fx != null:
		weather_fx.wind = wind
		weather_fx.set_intensity(rain_fx, snow_fx, storm_fx, delta)
	if seasons_fx != null:
		seasons_fx.update(delta, season, wind)

	water_freeze = lerpf(water_freeze, 1.0 if season == 3 else 0.0, 1.0 - exp(-delta * 0.9))
	if absf(water_freeze - _water_freeze_applied) > 0.002:
		world.set_water_freeze(water_freeze)
		_water_freeze_applied = water_freeze
	if farm_life != null:
		farm_life.water_freeze = water_freeze

	if footprints != null:
		footprints.snow_depth = snow_depth
		# Match the original: weatherBlend.snow * (1 + weatherBlend.storm).
		# Using the smoothed fades avoids a hard jump when a storm starts.
		footprints.snowfall = snow_fx * (1.0 + storm_fx)
	_update_trample(delta)

	var daylight := Daylight.evaluate(hour)
	var coverage := weather_coverage
	var overcast: float = clampf(coverage * 0.42, 0.0, 0.88)
	if high_end_rendering and mist_material != null:
		var golden := float(daylight["golden"])
		var night := float(daylight["night"])
		var compositor_fog := atmosphere_effect != null and atmosphere_effect.active and atmosphere_effect.working
		var mist_target := 0.10 + 0.10 * golden + 0.04 * night + 0.06 * overcast
		if season == 3:
			mist_target += 0.02
		# The compositor raymarch already carries the volumetric haze; keep the
		# FogVolume only as a light complement so the two do not double up.
		if compositor_fog:
			mist_target *= 0.22
		mist_material.density = lerpf(mist_material.density, mist_target, 1.0 - exp(-delta * 0.7))
		env.volumetric_fog_density = (0.009 + 0.008 * night + 0.006 * overcast + 0.005 * golden) \
			* (0.30 if compositor_fog else 1.0)
		if low_mist_material != null:
			var low_target := clampf(golden * 1.3 + overcast * 0.45 + (1.0 if weather == 3 else 0.0)
				+ (0.15 if season == 3 else 0.0), 0.0, 1.0) * (1.0 - night * 0.45)
			low_mist_material.density = lerpf(low_mist_material.density,
				lerpf(0.015, 0.20, low_target), 1.0 - exp(-delta * 0.7))
			low_mist.visible = quality < 2 and low_target > 0.04 and not compositor_fog
	_update_atmosphere(daylight)
	if world != null:
		world.update_cascade(delta, wind, 1.0 - float(daylight["night"]) * 0.9)
	if night_life != null:
		night_life.update(delta, float(daylight["night"]), float(daylight["golden"]),
			1.0 - minf(1.0, overcast * 1.1), weather, season, wind, orbit.yaw)

	if post != null:
		var t := daylight
		var golden := float(t["golden"])
		var night := float(t["night"])
		var dawn := bool(t["dawn"])
		var night_cast := 0.35 * night * (1.0 - golden)
		var gold_shadow := Vector3(-0.12, -0.08, 0.14) if dawn else Vector3(-0.10, -0.15, 0.12)
		var shadow := Vector3.ONE + gold_shadow * golden + Vector3(-0.12, -0.06, 0.16) * night_cast
		var gold_highlight := Vector3(0.10, 0.02, -0.06) if dawn else Vector3(0.17, -0.01, -0.17)
		var highlight := Vector3.ONE + gold_highlight * golden + Vector3(-0.04, 0.0, 0.06) * night_cast
		var day := 1.0 - 0.6 * night
		var foggy := 1.0 if weather == 3 else 0.0
		var mood_tint := Vector3(
			1.0 - 0.035 * rain_fx - 0.03 * snow_depth * day - 0.02 * storm_fx,
			1.0 - 0.005 * snow_depth * day,
			1.0 + 0.03 * rain_fx + 0.04 * snow_depth * day + 0.02 * storm_fx)
		var mood_sat := 1.0 - 0.15 * rain_fx - 0.10 * foggy - 0.14 * storm_fx - 0.04 * snow_depth
		var mood_contrast := 1.0 + 0.05 * rain_fx - 0.07 * foggy - 0.05 * storm_fx
		var sat := (1.02 + 0.16 * golden) * mood_sat
		var vig := 0.20 + 0.10 * night
		post.set_grade(Color(mood_tint.x, mood_tint.y, mood_tint.z), sat, mood_contrast, vig,
			shadow, highlight)
		var mood_bloom := (1.0 + 1.1 * foggy + 0.5 * wet + 0.2 * storm_fx) * (1.0 - 0.5 * snow_depth)
		env.glow_intensity = (0.14 + 0.42 * night) * mood_bloom
		if sun != null and orbit != null:
			var sun_dir := sun.global_transform.basis.z.normalized()
			var facing := sun_dir.dot(-orbit.global_transform.basis.z)
			if facing > 0.05:
				var vp := get_viewport().get_visible_rect().size
				var screen := orbit.unproject_position(orbit.global_position + sun_dir * 160.0)
				var strength := clampf((0.22 + float(t["golden"]) * 1.1) * facing
					* (1.0 - float(t["night"])), 0.0, 1.2)
				var sun_screen := Vector2(screen.x / maxf(vp.x, 1.0), screen.y / maxf(vp.y, 1.0))
				post.set_sun(sun_screen, strength, sun.light_color)
				if atmosphere_effect != null:
					atmosphere_effect.sun_uv = sun_screen
					atmosphere_effect.sun_strength = strength
					atmosphere_effect.sun_color = sun.light_color
					atmosphere_effect.depth_sign = -1.0
					atmosphere_effect.active = quality < 2
				var canvas_shafts := strength * (1.0 if quality == 0 else (0.6 if quality == 1 else 0.0))
				post.set_shafts(0.0 if atmosphere_effect != null and atmosphere_effect.working and atmosphere_effect.active else canvas_shafts)
			else:
				post.set_sun(Vector2(-10.0, -10.0), 0.0, Color.WHITE)
				post.set_shafts(0.0)
				if atmosphere_effect != null:
					atmosphere_effect.sun_uv = Vector2(-10.0, -10.0)
					atmosphere_effect.sun_strength = 0.0

func _update_atmosphere(daylight: Dictionary) -> void:
	if atmosphere_effect == null or orbit == null:
		return
	var coverage := weather_coverage
	var density_scale := weather_density
	var from_index := int(daylight["from"])
	var to_index := int(daylight["to"])
	var blend := float(daylight["f"])
	var base_density := Daylight.value_at(Daylight.FOG_DENSITY, from_index, to_index, blend)
	atmosphere_effect.fog_density = base_density * (1.0 + 0.38 * coverage) * density_scale
	var scatter := Daylight.color_at(Daylight.FOG_SCATTER, from_index, to_index, blend)
	atmosphere_effect.fog_scatter = Color(scatter.r * 0.55, scatter.g * 0.55, scatter.b * 0.55)
	var golden := float(daylight["golden"])
	var night := float(daylight["night"])
	atmosphere_effect.mist_low = (1.0 if bool(daylight["dawn"]) else 0.3) \
		* golden * (1.0 - 0.5 * minf(1.0, coverage))
	atmosphere_effect.golden = golden
	atmosphere_effect.lamp_power = night
	atmosphere_effect.cloud_amount = lerpf(0.63, 0.84, coverage) if coverage < 1.0 \
		else lerpf(0.84, 0.94, coverage - 1.0)

	if sun != null:
		atmosphere_effect.sun_energy = sun.light_energy
		atmosphere_effect.sun_direction = sun.global_transform.basis.z.normalized()

	var xform := orbit.global_transform
	var basis := xform.basis
	atmosphere_effect.cam_right = basis.x.normalized()
	atmosphere_effect.cam_up = basis.y.normalized()
	atmosphere_effect.cam_forward = -basis.z.normalized()
	atmosphere_effect.cam_position = xform.origin
	atmosphere_effect.cam_ortho = orbit.projection == Camera3D.PROJECTION_ORTHOGONAL
	atmosphere_effect.cam_half_height = orbit.size * 0.5
	atmosphere_effect.cam_tan_half = tan(deg_to_rad(orbit.fov) * 0.5)
	var viewport_size := get_viewport().get_visible_rect().size
	atmosphere_effect.cam_aspect = viewport_size.x / maxf(viewport_size.y, 1.0)
	atmosphere_effect.cam_near = orbit.near
	atmosphere_effect.cam_far = orbit.far

	if sun_shadow != null and atmosphere_effect != null:
		var sun_dir := sun.global_transform.basis.z.normalized() if sun != null else Vector3.UP
		sun_shadow.set_sun(sun_dir)
		var shadow_xform := sun_shadow.camera.global_transform
		atmosphere_effect.shadow_texture_rid = sun_shadow.capture_rid()
		atmosphere_effect.shadow_enabled = use_shadow_depth
		atmosphere_effect.shadow_debug = shadow_debug
		atmosphere_effect.shadow_right = shadow_xform.basis.x.normalized()
		atmosphere_effect.shadow_up = shadow_xform.basis.y.normalized()
		atmosphere_effect.shadow_forward = -shadow_xform.basis.z.normalized()
		atmosphere_effect.shadow_position = shadow_xform.origin
		atmosphere_effect.shadow_size = sun_shadow.camera.size
		atmosphere_effect.shadow_far = sun_shadow.camera.far

	var lamp_data: Array = []
	if world != null:
		for entry in world.lamps:
			var light: OmniLight3D = entry.light
			lamp_data.append(Vector4(light.global_position.x, light.global_position.y,
				light.global_position.z, clampf(light.light_energy / 3.6, 0.0, 1.0)))
	atmosphere_effect.lamps = lamp_data

func _apply_time(force: bool) -> void:
	if not force and absf(hour - _last_apply_hour) < 0.0005:
		return
	_last_apply_hour = hour
	day_cycle.apply(hour, weather, season)
	if quality == 2:
		env.glow_enabled = false

func _on_time_changed(value: float) -> void:
	hour = value
	hour_target = value
	auto_start = value
	auto_elapsed = 0.0
	_apply_time(true)

func _on_wind_changed(value: float) -> void:
	wind = value
	world.set_wind(wind)
	_wind_applied = wind

func _on_weather_changed(index: int) -> void:
	weather = index
	_apply_time(true)

func _on_season_changed(index: int) -> void:
	season = index
	world.set_surface_state(wet, snow_depth, season)
	_surface_wet = wet
	_surface_snow = snow_depth
	_apply_time(true)

func _on_auto_toggled(enabled: bool) -> void:
	auto_time = enabled
	auto_start = hour
	auto_elapsed = 0.0

func _on_reset_requested() -> void:
	orbit.reset_view()

func _set_quality(index: int) -> void:
	quality = clampi(index, 0, 2)
	_base_render_scale = [1.0, 0.85, 0.72][quality]
	adaptive_scale = 1.0
	if quality_manager != null:
		quality_manager.apply(quality)
	if atmosphere_effect != null:
		atmosphere_effect.active = quality < 2
	if sun_shadow != null:
		sun_shadow.set_active(quality < 2)
	if footprints != null:
		footprints.set_quality(quality)
	_apply_render_scale()
	if ui != null:
		ui.set_quality(quality)

func _apply_render_scale() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.scaling_3d_scale = clampf(_base_render_scale * adaptive_scale, 0.55, 1.0)

func _on_quality_changed(index: int) -> void:
	_set_quality(index)

## Port of the trample pass in src/main.js: each walker presses the turf and
## leaves a short trail that springs back, packed into 16 shader slots.
func _update_trample(delta: float) -> void:
	if world == null:
		return
	var ease := 1.0 - exp(-delta * 7.0)
	var bodies: Array = []
	if character != null and character.model != null:
		bodies.append({
			"id": "unitychan", "x": character.position.x, "z": character.position.z,
			"r": 0.2, "active": true,
		})
	if farm_life != null:
		bodies.append_array(farm_life.tramplers())

	var seen := {}
	for body in bodies:
		var id := String(body["id"])
		seen[id] = true
		if not _presses.has(id):
			_presses[id] = {
				"x": float(body["x"]), "z": float(body["z"]),
				"r": float(body["r"]) * 1.5, "s": 0.0, "tx": 1e9, "tz": 1e9,
			}
		var press: Dictionary = _presses[id]
		press["x"] = float(body["x"])
		press["z"] = float(body["z"])
		press["r"] = float(body["r"]) * 1.5
		var target := 1.0 if bool(body["active"]) else 0.0
		press["s"] = float(press["s"]) + (target - float(press["s"])) * ease
	for id in _presses.keys():
		if seen.has(id):
			continue
		var stale: Dictionary = _presses[id]
		stale["s"] = float(stale["s"]) * (1.0 - ease)
		if float(stale["s"]) < 0.005:
			_presses.erase(id)

	_trail_clock += delta
	if _trail_clock > 0.15:
		_trail_clock = 0.0
		for body in bodies:
			if not bool(body["active"]):
				continue
			var press: Dictionary = _presses[String(body["id"])]
			var walked := Vector2(float(press["x"]) - float(press["tx"]), float(press["z"]) - float(press["tz"])).length()
			if walked > 0.14 or float(press["tx"]) > 1e8:
				press["tx"] = float(press["x"])
				press["tz"] = float(press["z"])
				_trail.append({
					"x": float(press["x"]), "z": float(press["z"]),
					"r": float(body["r"]) * 1.4, "life": 1.0, "s": 0.0,
				})
	for i in range(_trail.size() - 1, -1, -1):
		var item: Dictionary = _trail[i]
		item["life"] = float(item["life"]) - delta / 2.6
		var life := maxf(float(item["life"]), 0.0)
		var wanted := 0.7 * pow(life, 1.5)
		item["s"] = float(item["s"]) + (wanted - float(item["s"])) * ease
		if float(item["life"]) <= 0.0 and float(item["s"]) < 0.01:
			_trail.remove_at(i)

	var all: Array = []
	for press in _presses.values():
		if float(press["s"]) > 0.005:
			all.append(press)
	for item in _trail:
		if float(item["s"]) > 0.005:
			all.append(item)
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["s"]) > float(b["s"]))
	var slots := PackedVector4Array()
	slots.resize(16)
	for i in range(16):
		if i < all.size():
			var entry: Dictionary = all[i]
			slots[i] = Vector4(float(entry["x"]), float(entry["z"]), float(entry["r"]), float(entry["s"]))
		else:
			slots[i] = Vector4.ZERO
	world.set_trample(slots)


