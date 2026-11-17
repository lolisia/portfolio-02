extends RefCounted
class_name QualityManager

## High / Medium / Low render budget. High keeps the Forward+ reflection,
## volumetric fog and full ground cover; Low falls back to screen-space water,
## no SSAO/volumetrics and thinner grass/particles.

var env: Environment
var sun: DirectionalLight3D
var world: FarmWorld
var reflection: WaterReflection
var weather: WeatherFX
var seasons: SeasonsFX
var viewport: Viewport
var mist: FogVolume

func setup(p_env: Environment, p_sun: DirectionalLight3D, p_world: FarmWorld,
		p_reflection: WaterReflection, p_weather: WeatherFX, p_seasons: SeasonsFX,
		p_viewport: Viewport, p_mist: FogVolume) -> void:
	env = p_env
	sun = p_sun
	world = p_world
	reflection = p_reflection
	weather = p_weather
	seasons = p_seasons
	viewport = p_viewport
	mist = p_mist

func apply(level: int) -> void:
	level = clampi(level, 0, 2)
	var high := level == 0
	var low := level == 2
	var forward_plus := String(RenderingServer.get_current_rendering_method()) == "forward_plus"

	if env != null:
		env.ssao_enabled = high and forward_plus
		env.volumetric_fog_enabled = not low and forward_plus
		env.volumetric_fog_density = 0.012 if high else 0.008
		env.glow_enabled = not low
	if mist != null:
		mist.visible = not low
	if sun != null:
		sun.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
		sun.directional_shadow_max_distance = 80.0 if high else (65.0 if not low else 50.0)
		sun.shadow_blur = 1.0 if high else 0.7
	if world != null:
		# Five shadow-casting lanterns dominate the shadow budget at night;
		# only the High preset keeps them.
		for entry in world.lamps:
			var lamp_light: SpotLight3D = entry["light"]
			if lamp_light != null:
				lamp_light.shadow_enabled = high
	if viewport != null:
		viewport.msaa_3d = (Viewport.MSAA_4X if high else (Viewport.MSAA_2X if not low else Viewport.MSAA_DISABLED))
		viewport.scaling_3d_scale = 1.0 if high else (0.85 if not low else 0.72)
	if reflection != null:
		reflection.set_quality(level)
	if weather != null:
		weather.quality_scale = 1.0 if high else (0.75 if not low else 0.5)
	if seasons != null:
		seasons.quality_scale = (0.45 if high else 0.35) if MobileProfile.enabled() else (1.0 if high else (0.75 if not low else 0.5))
	if world != null:
		world.set_quality(level)
