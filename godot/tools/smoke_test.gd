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

	var character = main.get("character")
	if character == null:
		failures.append("Unity-chan missing")
	elif character.paths == null:
		failures.append("A* paths missing")
	elif character.paths.route(main.world, Vector2(0, 2), Vector2(10, 5)).is_empty():
		failures.append("A* route empty")

	if main.get("footprints") == null:
		failures.append("footprints layer missing")
	if main.get("night_life") == null:
		failures.append("night life missing")
	if main.get("seasons_fx") == null:
		failures.append("season particles missing")
	if main.get("quality_manager") == null:
		failures.append("quality manager missing")
	if not FileAccess.file_exists("res://shaders/atmosphere_shafts.glsl"):
		failures.append("atmosphere shaft shader missing")
	if not FileAccess.file_exists("res://shaders/atmosphere_composite.glsl"):
		failures.append("atmosphere composite shader missing")
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
		if weather.find_children("*", "GPUParticlesCollisionBox3D", true, false).size() < 3:
			failures.append("rain roof collisions missing")

	if failures.is_empty():
		print("SMOKE PASS: world, tasks, garden, footprints, night, seasons, quality, shafts, rain collisions, compositor shaders")
		quit(0)
	else:
		for failure in failures:
			push_error("SMOKE FAIL: " + failure)
		quit(1)

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	quit(1)
