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
		var bare_color = world.terrain_material.get_shader_parameter("winter_bare_color")
		if bare_color == null or (bare_color as Vector3).distance_to(
				Vector3(0.36, 0.235, 0.135)) > 0.001:
			failures.append("winter bare soil color wrong")
		var flower_mmi := world.find_child("flowerHead", true, false) as MultiMeshInstance3D
		if flower_mmi != null:
			var window_z: float = world.cottage_origin.y + float(world.COTTAGE.D) * 0.5 + 0.11
			for i in range(flower_mmi.multimesh.instance_count):
				var flower_pos := flower_mmi.multimesh.get_instance_transform(i).origin
				if absf(flower_pos.z - window_z) < 0.15 \
						and (absf(flower_pos.x - (world.cottage_origin.x - 0.95)) < 0.12
							or absf(flower_pos.x - (world.cottage_origin.x + 0.95)) < 0.12):
					failures.append("window flower box still present")
					break
		if world.rose_bushes.size() != 4:
			failures.append("rose bush count wrong")
		else:
			for rose in world.rose_bushes:
				var rose_offset: Vector2 = rose - Vector2(-1.1, -7.65)
				if absf(absf(rose_offset.x) - 2.19) > 0.06 \
						or absf(absf(rose_offset.y) - 0.83) > 0.06:
					failures.append("rose bush not at a garden corner")
					break
		if world.garden_plant_count != 86:
			failures.append("garden planting count wrong: " + str(world.garden_plant_count))
		if world.gravel_slab_count != 20:
			failures.append("gravel slab count wrong: " + str(world.gravel_slab_count))
		for stem_kind in ["lavenderStem", "foxgloveStem"]:
			var stem_mesh: Mesh = world.meshes.get(stem_kind)
			if stem_mesh == null:
				failures.append(stem_kind + " missing")
				continue
			var stem_vertices := 0
			for surface in range(stem_mesh.get_surface_count()):
				var arrays := stem_mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				stem_vertices += vertices.size()
			var minimum_vertices := 300 if stem_kind == "lavenderStem" else 80
			if stem_vertices < minimum_vertices:
				failures.append(stem_kind + " is not tubular")
		if world.meshes.has("sunflowerDisc"):
			failures.append("separate sunflower disc still exists")
		var bloom_mesh: Mesh = world.meshes.get("sunflowerBloom")
		if bloom_mesh == null:
			failures.append("sunflower bloom missing")
		else:
			var bloom_arrays: Array = bloom_mesh.surface_get_arrays(0)
			var bloom_colors: PackedColorArray = bloom_arrays[Mesh.ARRAY_COLOR]
			if bloom_colors.is_empty():
				failures.append("sunflower two-tone vertex colours missing")
		if not world.find_children("sunflowerDisc", "MultiMeshInstance3D", true, false).is_empty():
			failures.append("sunflowerDisc node still present")
		if world.path_mask == null or world.path_mask.get_width() != 1024:
			failures.append("ground mask is not 1024")
		elif not world.path_points.is_empty():
			var ground_image: Image = world.path_mask.get_image()
			var path_point: Vector2 = world.path_points[0]
			var path_px := int((path_point.x + 15.0) / 30.0 * 1024.0)
			var path_pz := int((path_point.y + 15.0) / 30.0 * 1024.0)
			if ground_image.get_pixel(path_px, path_pz).g < 0.2:
				failures.append("soft path mask missing")
			var tree_point: Array = FarmWorld.TREE_LIST[0]
			var tree_px := int((float(tree_point[0]) + 15.0) / 30.0 * 1024.0)
			var tree_pz := int((float(tree_point[1]) + 15.0) / 30.0 * 1024.0)
			if ground_image.get_pixel(tree_px, tree_pz).r < 0.2:
				failures.append("leaf litter mask missing")
		if world.boxes.is_empty():
			failures.append("oriented collision boxes missing")
		if world.bodies.size() < 7:
			failures.append("dynamic walker bodies missing")
		var inside_push: Vector2 = world.resolve_body(Vector2(-1.0, -2.5), 0.2, null)
		if inside_push.distance_to(Vector2(-1.0, -2.5)) < 0.5:
			failures.append("oriented box did not push the walker")
		var body_a: Dictionary = world.add_body(-5.0, -5.0, 0.2, "test")
		var body_b: Dictionary = world.add_body(-5.1, -5.0, 0.2, "test")
		var body_push: Vector2 = world.resolve_body(Vector2(-5.05, -5.0), 0.2, body_a)
		world.bodies.erase(body_a)
		world.bodies.erase(body_b)
		if body_push.distance_to(Vector2(-5.05, -5.0)) < 0.1:
			failures.append("dynamic body separation missing")
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
	if character != null:
		if character.state != "inside" or character.model == null or character.model.visible:
			failures.append("character did not start inside")
		if absf(float(character.walk_speed) - 0.62) > 0.001:
			failures.append("character walk speed wrong")
		if absf(float(character.turn_rate) - 6.0) > 0.001 \
				or absf(float(character.task_turn_rate) - 4.0) > 0.001:
			failures.append("character turn rate wrong")
		if character.toon_materials.is_empty():
			failures.append("toon character materials missing")
		else:
			var toon_material: ShaderMaterial = character.toon_materials[0]
			if toon_material.shader == null \
					or not toon_material.shader.resource_path.contains("toon_character"):
				failures.append("toon shader not applied")
			if absf(float(toon_material.get_shader_parameter("alpha_cut")) - 0.5) > 0.001:
				failures.append("toon alpha cut wrong")
		if character.toon_double_count <= 0:
			failures.append("double-sided hair material missing")
		if absf(float(character.world.cottage_door.x) + 1.0) > 0.001:
			failures.append("cottage door position wrong")
		if world.door_leaf == null:
			failures.append("cottage door leaf missing")
		else:
			var door_wood_count := -1
			var door_iron_count := -1
			for child in world.door_leaf.get_children():
				if child is MultiMeshInstance3D:
					var leaf_mmi := child as MultiMeshInstance3D
					if String(leaf_mmi.name) == "wood":
						door_wood_count = leaf_mmi.multimesh.instance_count
					elif String(leaf_mmi.name) == "iron":
						door_iron_count = leaf_mmi.multimesh.instance_count
					if not (leaf_mmi.material_override is ShaderMaterial):
						failures.append("door leaf lost its wood surface")
			if door_wood_count != 7 or door_iron_count != 1:
				failures.append("door leaf builder planks wrong")
		if character.gather_spots.size() != 6:
			failures.append("gather spot count wrong")
		if character.shore_spots.size() != 5:
			failures.append("shore spot count wrong")
		var gather_route: Array = character._task_route("gather")
		if gather_route.is_empty():
			failures.append("gather route missing")
		else:
			var gather_end: Vector2 = gather_route[gather_route.size() - 1]
			var bed_distance := minf(gather_end.distance_to(Vector2(1.1, 3.3)),
				gather_end.distance_to(Vector2(2.7, 3.3)))
			if bed_distance > 1.4:
				failures.append("gather spot is not at a front bed")
		var fish_route: Array = character._task_route("fish")
		if fish_route.is_empty():
			failures.append("fishing route missing")
		else:
			var fish_end: Vector2 = fish_route[fish_route.size() - 1]
			var pond_distance := fish_end.distance_to(Vector2(10.7, 6.3))
			if fish_end.y >= 6.3 or pond_distance < 3.0 or pond_distance > 6.0:
				failures.append("fishing spot is not on the north bank")

	var farm_life = main.get("farm_life")
	if farm_life == null:
		failures.append("farm life missing")
	else:
		if farm_life.paths == null:
			failures.append("chicken path graph missing")
		if farm_life.chickens.is_empty():
			failures.append("chicken flock missing")
		elif String(farm_life.chickens[0]["state"]) != "inside" \
				or bool(farm_life.chickens[0]["group"].visible):
			failures.append("chickens did not start inside")
		if farm_life.bird_legs.size() != 2:
			failures.append("bird legs missing")
		if String(farm_life.bird_state) != "away" or farm_life.bird.visible:
			failures.append("bird did not start away")
		for perch in farm_life.bird_perches:
			if String(perch.get("kind", "")) == "ridge":
				failures.append("extra ridge perch still present")
				break
		farm_life.wind = 12.0
		farm_life.bird_state = "perched"
		farm_life.bird_age = 0.0
		farm_life._update_bird(0.05)
		if String(farm_life.bird_state) != "takeoff":
			failures.append("bird did not leave in strong wind")
		farm_life.wind = 3.0
		farm_life.night_level = 0.9
		farm_life.bird_state = "perched"
		farm_life.bird_age = 0.0
		farm_life._update_bird(0.05)
		if String(farm_life.bird_state) != "takeoff":
			failures.append("bird did not leave at night")
		farm_life.night_level = 0.0
		farm_life.bird_state = "away"
		farm_life.bird_age = 0.0
		farm_life.bird.visible = false

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
				var lamp_light: SpotLight3D = entry["light"]
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
		ui.set_panel_open(true, true)
		if not ui.is_panel_open() or float(ui.full_body_height) <= 10.0:
			failures.append("panel did not open")
		var full_body: float = float(ui.full_body_height)
		ui.set_panel_open(false, true)
		if ui.is_panel_open():
			failures.append("panel did not close")
		ui.set_panel_open(true)
		await create_timer(0.15).timeout
		var mid_body := float(ui.body_clip.custom_minimum_size.y)
		if mid_body <= 0.0 or mid_body >= full_body:
			failures.append("panel fold did not animate")
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		ui._unhandled_input(escape)
		if ui.is_panel_open():
			failures.append("Escape did not close the panel")
		ui.set_panel_open(false, true)
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
	var cascade = world.get("cascade_fx") if world != null else null
	if cascade == null:
		failures.append("cascade FX missing")
	else:
		if cascade.drop_multimesh == null or cascade.drop_multimesh.instance_count != 900:
			failures.append("cascade droplet count wrong")
		if cascade.vapor.size() != 24:
			failures.append("cascade vapour count wrong")
		if cascade.foam == null:
			failures.append("cascade foam missing")
		if not FileAccess.file_exists("res://shaders/cascade_foam.gdshader"):
			failures.append("cascade foam shader missing")
	# The six weather weights must ease, not snap, when the dropdown changes.
	var cover_before := float(main.get("weather_coverage"))
	main._on_weather_changed(2)
	await process_frame
	await process_frame
	var cover_after := float(main.get("weather_coverage"))
	if cover_after <= cover_before or cover_after >= 1.9:
		failures.append("weather blend snapped")
	main._on_weather_changed(0)
	main._snap_weather_blend()

	# I8/I9: the slider targets change immediately, but the shown clock/wind
	# glide and the auto clock advances in whole minutes.
	var glide_ui = main.get("ui")
	main.hour = 8.5
	main.hour_target = 8.5
	main.wind = 3.0
	main.wind_target = 3.0
	main._on_time_changed(12.0)
	main._on_wind_changed(9.0)
	await process_frame
	await process_frame
	var hour_after := float(main.get("hour"))
	var wind_after := float(main.get("wind"))
	if hour_after <= 8.5 or hour_after >= 12.0:
		failures.append("hour did not glide")
	if wind_after <= 3.0 or wind_after >= 9.0:
		failures.append("wind did not glide")
	if glide_ui != null and glide_ui.time_value.text == "12:00":
		failures.append("hour label snapped to target")
	main._on_auto_toggled(true)
	var auto_start := float(main.get("hour_target"))
	await create_timer(0.3).timeout
	var auto_now := float(main.get("hour_target"))
	if auto_now <= auto_start:
		failures.append("auto clock did not advance")
	if absf(auto_now * 60.0 - round(auto_now * 60.0)) > 0.01:
		failures.append("auto clock not minute-quantized")
	main._on_auto_toggled(false)

	if failures.is_empty():
		print("SMOKE PASS: world, tasks, garden, footprints, porch stand, night, seasons, quality, shafts, rain collisions, compositor shaders, weather blend, cascade FX, UI glide")
		quit(0)
	else:
		for failure in failures:
			push_error("SMOKE FAIL: " + failure)
		quit(1)

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	quit(1)
