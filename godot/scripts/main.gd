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
var mist: FogVolume
var mist_material: FogMaterial
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
		_add_volumetric_mist()

	var cli: Array = []
	for arg in OS.get_cmdline_args():
		cli.append(arg)
	for arg in OS.get_cmdline_user_args():
		cli.append(arg)
	if "--house" in cli:
		orbit.set_view(Vector3(-1.0, 1.0, 0.1), 0.65, 0.98, 2.6)
	if "--char" in cli:
		orbit.set_view(Vector3(-1.0, 0.65, 0.85), 0.0, 1.05, 7.0)
	if "--char2" in cli:
		orbit.set_view(Vector3(-1.0, 0.55, 1.75), 0.0, 1.35, 8.0)
	if "--charclose" in cli:
		orbit.max_zoom = 12.0
		orbit.set_view(Vector3(-0.35, 1.25, 1.0), 1.1, 1.12, 10.0)
	if "--pond" in cli:
		orbit.set_view(Vector3(10.8, 0.3, 6.1), 0.7, 0.98, 2.8)
	if "--pondside" in cli:
		orbit.set_view(Vector3(8.6, 0.6, 6.0), 1.95, 0.46, 2.3)
	if "--fishtest" in cli:
		orbit.set_view(Vector3(6.6, 0.6, 4.0), 0.55, 1.2, 4.0)
	if "--door" in cli:
		orbit.set_view(Vector3(-0.8, 1.0, -0.6), 0.25, 1.35, 4.2)
	if "--front" in cli:
		orbit.set_view(Vector3(-1.0, 1.2, -0.4), 0.1, 0.42, 4.0)
	if "--garden" in cli:
		orbit.set_view(Vector3(-1.1, 1.6, -7.3), 0.2, 0.95, 4.2)

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
	quality_manager.apply(quality)
	ui.set_quality(quality)

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
	var shot_index := cli.find("--shot")
	if shot_index >= 0 and shot_index + 1 < cli.size():
		_capture_screenshot(String(cli[shot_index + 1]))
	orbit.v_offset = _desired_v_offset()
	orbit.set_portrait_scale(_desired_portrait_scale())
	ui.set_time_value(hour)
	ui.set_wind_value(wind)

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
	sky_material.ground_bottom_color = Color(0.30, 0.35, 0.27)
	sky_material.ground_horizon_color = Color(0.68, 0.76, 0.80)
	sky_material.ground_curve = 0.05
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
	env.tonemap_exposure = 0.98
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

func _process(delta: float) -> void:
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

	if farm_life != null:
		farm_life.hour = hour
		farm_life.wind = wind
		farm_life.weather = weather
	if character != null:
		character.weather = weather
		character.season = season

	var wet_target := 1.0 if weather == 2 else (0.65 if weather == 3 else 0.0)
	wet = lerpf(wet, wet_target, 1.0 - exp(-delta * 0.8))
	var snow_target := 1.0 if season == 3 or weather >= 4 else 0.0
	var snow_speed := 0.55 if season == 3 else 1.1
	snow_depth = lerpf(snow_depth, snow_target, 1.0 - exp(-delta * snow_speed))
	if absf(wet - _surface_wet) > 0.002 or absf(snow_depth - _surface_snow) > 0.002:
		world.set_surface_state(wet, snow_depth, season)
		_surface_wet = wet
		_surface_snow = snow_depth

	rain_fx = lerpf(rain_fx, 1.0 if weather == 2 else 0.0, 1.0 - exp(-delta * 1.4))
	snow_fx = lerpf(snow_fx, 1.0 if weather >= 4 else 0.0, 1.0 - exp(-delta * 1.4))
	storm_fx = lerpf(storm_fx, 1.0 if weather == 5 else 0.0, 1.0 - exp(-delta * 1.4))
	if weather_fx != null:
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
		footprints.snowfall = 1.0 if weather == 4 else (2.0 if weather == 5 else 0.0)
	_update_trample(delta)

	var daylight := Daylight.evaluate(hour)
	var coverage: float = [0.0, 1.0, 2.0, 1.0, 1.0, 2.0][clampi(weather, 0, 5)]
	var overcast: float = clampf(coverage * 0.42, 0.0, 0.88)
	if high_end_rendering and mist_material != null:
		var golden := float(daylight["golden"])
		var night := float(daylight["night"])
		var mist_target := 0.10 + 0.10 * golden + 0.04 * night + 0.06 * overcast
		if season == 3:
			mist_target += 0.02
		mist_material.density = lerpf(mist_material.density, mist_target, 1.0 - exp(-delta * 0.7))
		env.volumetric_fog_density = 0.009 + 0.008 * night + 0.006 * overcast + 0.005 * golden
	if night_life != null:
		night_life.update(delta, float(daylight["night"]), float(daylight["golden"]),
			1.0 - minf(1.0, overcast * 1.1), weather, season, wind, orbit.yaw)

	if post != null:
		var t := daylight
		var tint := Color(1, 1, 1)
		if t["golden"] > 0.01:
			tint = tint.lerp(Color(1.03, 1.0, 0.94), 0.25 * float(t["golden"]))
		if t["night"] > 0.01:
			tint = tint.lerp(Color(0.88, 0.94, 1.0), 0.25 * float(t["night"]))
		var sat: float = 1.03 + 0.10 * float(t["golden"]) - 0.06 * overcast
		var con: float = 1.01 + 0.03 * overcast
		var vig: float = 0.08 + 0.08 * float(t["night"])
		post.set_grade(tint, sat, con, vig)

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
	if quality_manager != null:
		quality_manager.apply(quality)
	if ui != null:
		ui.set_quality(quality)

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


