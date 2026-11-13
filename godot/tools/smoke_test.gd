extends SceneTree

## Headless smoke test for the ported scene. Run:
##   Godot --headless --path godot --script res://tools/smoke_test.gd
## Exits 1 when a core system or shader parameter is missing.

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("main scene did not load")
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var failures: Array[String] = []
	var world = main.get("world")
	if world == null:
		failures.append("world missing")
	else:
		if world.ground == null:
			failures.append("terrain missing")
		if world.water == null:
			failures.append("pond missing")
		if world.meshes.is_empty():
			failures.append("nature meshes empty")
		if world.snow_surface(0.0, 0.0, 1.0) <= world.height(0.0, 0.0):
			failures.append("snow surface does not rise")
		if not world.meshes.has("tulipBloom"):
			failures.append("procedural garden asset missing")
		if world.window_glass_material == null:
			failures.append("window interior material missing")
		var house_y: float = world.height(-1.0, -2.5)
		var deck_y: float = world.stand(-1.0, -0.4)
		var step_y: float = world.stand(-1.0, 0.30)
		var beside_y: float = world.stand(-4.0, -0.4)
		if absf(deck_y - (house_y + float(world.COTTAGE.F))) > 0.02:
			failures.append("porch deck stand height wrong")
		if step_y >= deck_y - 0.02:
			failures.append("porch step is not below the deck")
		if absf(beside_y - world.height(-4.0, -0.4)) > 0.001:
			failures.append("off-deck stand height changed")

	var character = main.get("character")
	if character == null:
		failures.append("Unity-chan missing")
	elif character.paths == null:
		failures.append("A* paths missing")
	elif character.paths.route(main.world, Vector2(0, 2), Vector2(10, 5)).is_empty():
		failures.append("A* route empty")
	if character != null and character.paths != null:
		var porch_route: Array = character.paths.route(main.world,
			Vector2(-0.35, 1.0), Vector2(-1.0, -0.35))
		var deck_route := false
		for p in porch_route:
			if float(p.y) < 0.1:
				deck_route = true
		if porch_route.is_empty() or not deck_route:
			failures.append("porch route missing")
		if not character._can_stand(Vector2(-1.0, -0.35)):
			failures.append("porch walk blocked")

	if main.get("footprints") == null:
		failures.append("footprints layer missing")
	else:
		var footprints = main.get("footprints")
		footprints.set_quality(2)
		if int(footprints.layers["boot"]["capacity"]) >= 360:
			failures.append("footprint low capacity not applied")
		if int(footprints.layers["boot"]["texture_size"]) != 32:
			failures.append("footprint low texture not applied")
		footprints.set_quality(0)
		# Storm snowfall must fill prints faster than calm snow.
		footprints.snow_depth = 1.0
		footprints.snowfall = 2.0
		var boot_next: int = int(footprints.layers["boot"]["next"])
		footprints.press("boot", -4.0, 4.0, 0.0)
		var storm_item: Dictionary = footprints.layers["boot"]["items"][boot_next]
		footprints._process(1.0)
		var storm_life: float = float(storm_item["life"])
		footprints.snowfall = 0.0
		boot_next = int(footprints.layers["boot"]["next"])
		footprints.press("boot", -3.0, 4.0, 0.0)
		var calm_item: Dictionary = footprints.layers["boot"]["items"][boot_next]
		footprints._process(1.0)
		var calm_life: float = float(calm_item["life"])
		if not (storm_life < calm_life - 0.02 and storm_life > 0.90):
			failures.append("snow footprint fill tuning wrong")
		footprints.snow_depth = 0.0
		footprints.snowfall = 0.0
	if main.get("night_life") == null:
		failures.append("night life missing")
	if main.get("seasons_fx") == null:
		failures.append("season particles missing")
	if main.get("path_debug") == null:
		failures.append("path debug missing")
	if main.get("quality_manager") == null:
		failures.append("quality manager missing")
	else:
		var quality_manager = main.get("quality_manager")
		quality_manager.apply(2)
		if world != null:
			for entry in world.lamps:
				var lamp_light: OmniLight3D = entry["light"]
				if lamp_light != null and lamp_light.shadow_enabled:
					failures.append("low quality kept lantern shadows")
					break
		quality_manager.apply(0)
	var ui = main.get("ui")
	if ui == null or ui.get("horizon_preview") == null:
		failures.append("motion preview missing")
	else:
		ui.set_reduced_motion(true)
		if not ui.horizon_preview.reduced_motion or not ui.wind_preview.reduced_motion \
				or not ui.weather_preview.reduced_motion:
			failures.append("reduced motion not applied")
		ui.set_reduced_motion(false)
	if not FileAccess.file_exists("res://shaders/atmosphere_shafts.glsl"):
		failures.append("atmosphere shaft shader missing")
	if not FileAccess.file_exists("res://shaders/atmosphere_composite.glsl"):
		failures.append("atmosphere composite shader missing")
	if not FileAccess.file_exists("res://scripts/sun_shadow.gd"):
		failures.append("sun shadow script missing")
	if not FileAccess.file_exists("res://shaders/shadow_capture.glsl"):
		failures.append("shadow capture shader missing")
	var post = main.get("post")
	if post == null or post.material == null or post.material.shader == null:
		failures.append("post-process shader missing")
	else:
		var uniforms: Array = post.material.shader.get_shader_uniform_list()
		var has_shafts := false
		for uniform in uniforms:
			if String(uniform["name"]) == "shaft_strength":
				has_shafts = true
				break
		if not has_shafts:
			failures.append("light-shaft uniform missing")
	var weather = main.get("weather_fx")
	if weather == null:
		failures.append("weather FX missing")
	else:
		if weather.ripples == null or weather.ripple_mesh.instance_count < 160:
			failures.append("rain impact layer missing")
		if weather.find_children("*", "GPUParticlesCollisionBox3D", true, false).size() < 30:
			failures.append("rain canopy collisions missing")

	if failures.is_empty():
		print("SMOKE PASS: world, tasks, garden, footprints, porch stand, night, seasons, quality, shafts, rain collisions, compositor shaders")
		quit(0)
	else:
		for failure in failures:
			push_error("SMOKE FAIL: " + failure)
		quit(1)

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	quit(1)
