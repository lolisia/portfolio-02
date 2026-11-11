extends Node3D

## Godot port entry point. Builds the diorama, orbit camera, environment,
## day/night cycle and the control panel.

const FarmWorld = preload("res://scripts/world.gd")
const OrbitCamera = preload("res://scripts/orbit_camera.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const DayCycle = preload("res://scripts/day_cycle.gd")
const UnityChan = preload("res://scripts/unity_chan.gd")

var world: FarmWorld
var orbit: OrbitCamera
var ui: GameUI
var character: UnityChan
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
var auto_time := false
var auto_start := 8.5
var auto_elapsed := 0.0
var _wind_applied := -1.0
var _last_apply_hour := -999.0

func _ready() -> void:
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
	add_child(character)

	orbit = OrbitCamera.new()
	orbit.name = "OrbitCamera"
	orbit.position = Vector3(31.0, 34.0, 41.0)
	orbit.target = Vector3(0.0, 1.0, 0.0)
	add_child(orbit)

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
	if "--pond" in cli:
		orbit.set_view(Vector3(10.8, 0.3, 6.1), 0.7, 0.98, 2.8)

	ui = GameUI.new()
	ui.name = "GameUI"
	add_child(ui)
	ui.time_changed.connect(_on_time_changed)
	ui.wind_changed.connect(_on_wind_changed)
	ui.weather_changed.connect(_on_weather_changed)
	ui.season_changed.connect(_on_season_changed)
	ui.auto_toggled.connect(_on_auto_toggled)
	ui.reset_requested.connect(_on_reset_requested)

	day_cycle = DayCycle.new()
	day_cycle.setup(sun, fill, env, sky_material, world)
	_apply_time(true)
	world.set_wind(wind)
	_wind_applied = wind
	ui.set_time_value(hour)
	ui.set_wind_value(wind)

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
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.1

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
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.ssao_power = 1.0
	env.ssao_detail = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.50, 0.52)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.18
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(0.50, 0.58, 0.58)
	env.volumetric_fog_length = 55.0
	env.volumetric_fog_detail_spread = 1.4
	env.volumetric_fog_anisotropy = 0.35
	env.adjustment_enabled = true

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)

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

func _apply_time(force: bool) -> void:
	if not force and absf(hour - _last_apply_hour) < 0.0005:
		return
	_last_apply_hour = hour
	day_cycle.apply(hour, weather, season)

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
	_apply_time(true)

func _on_auto_toggled(enabled: bool) -> void:
	auto_time = enabled
	auto_start = hour
	auto_elapsed = 0.0

func _on_reset_requested() -> void:
	orbit.reset_view()

