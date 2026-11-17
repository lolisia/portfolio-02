extends Node

## Opt-in debug-device profiler. Configuration is written to user://profile.json
## through `adb shell run-as <package>`; normal launches never instantiate it.
var main: Node
var phases: Array = []
var index := -1
var elapsed := 0.0
var samples: Array = []
var results: Array = []
var restores: Array[Callable] = []
var config: Dictionary

func setup(scene: Node, options: Dictionary) -> void:
	main = scene
	config = options
	phases = options.get("phases", ["full"])
	main._apply_render_scale()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), options.get("gpu", true))
	if options.get("night", false):
		main.hour = 22.0
		main.hour_target = 22.0
		main._apply_time(true)
	if options.get("panel", false):
		main.ui.set_panel_open(true, true)
	if options.has("zoom"):
		main.orbit.set_zoom_target(float(options.zoom))
	if options.has("weather"):
		main._on_weather_changed(int(options.weather))
		main._snap_weather_blend()
	if options.has("season"):
		main._on_season_changed(int(options.season))
		main._snap_season_blend()
	print("DEVICE_PROFILE start ", JSON.stringify(options))
	_next()

func _next() -> void:
	for restore in restores:
		restore.call()
	restores.clear()
	index += 1
	elapsed = 0.0
	samples.clear()
	if index >= phases.size():
		var file := FileAccess.open("user://profile-results.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "\t"))
		get_tree().quit()
		return
	if str(phases[index]).begins_with("scale_"):
		var original := get_viewport().scaling_3d_scale
		get_viewport().scaling_3d_scale = str(phases[index]).trim_prefix("scale_").to_float() / 100.0
		restores.append(func(): get_viewport().scaling_3d_scale = original)
	match phases[index]:
		"no_3d":
			get_viewport().disable_3d = true
			restores.append(func(): get_viewport().disable_3d = false)
		"no_terrain":
			main.world.ground.hide()
			restores.append(func(): main.world.ground.show())
		"no_shadows":
			for light in main.find_children("*", "Light3D", true, false):
				var original: bool = light.shadow_enabled
				light.shadow_enabled = false
				restores.append(func(): light.shadow_enabled = original)
		"no_foliage":
			for node in main.world.get_children():
				if node is MultiMeshInstance3D and (node.name.begins_with("turf") or node.name.begins_with("grass") or "Leaves" in node.name or "Needles" in node.name):
					_hide(node)
		"no_post":
			_hide(main.post.screen)
		"no_water":
			_hide(main.world.water)
		"no_fog":
			main.env.fog_enabled = false
			restores.append(func(): main.env.fog_enabled = true)
		"simple_lighting":
			for node in main.world.find_children("*", "MultiMeshInstance3D", true, false):
				var material = node.material_override
				if not material is ShaderMaterial or material.shader == null:
					continue
				var original: Shader = material.shader
				var split := original.code.find("void light()")
				if split < 0:
					continue
				var test := Shader.new()
				test.code = original.code.left(split) + "void light() { DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI; }"
				material.shader = test
				restores.append(func(): material.shader = original)
		"no_fx":
			_hide(main.world.cascade_fx)
	print("DEVICE_PROFILE phase ", phases[index])

func _hide(node: Node) -> void:
	var original: bool = node.visible
	node.hide()
	restores.append(func(): node.visible = original)

func _process(delta: float) -> void:
	if index >= phases.size():
		return
	elapsed += delta
	if elapsed > float(config.get("warmup", 3.0)):
		var vp := get_viewport().get_viewport_rid()
		samples.append([delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp)])
	if elapsed < float(config.get("warmup", 3.0)) + float(config.get("seconds", 8.0)):
		return
	var avg := PackedFloat64Array([0, 0, 0, 0])
	var frames: Array = []
	for sample in samples:
		frames.append(sample[0])
		for i in range(4):
			avg[i] += float(sample[i]) / samples.size()
	frames.sort()
	var result := {"phase": phases[index], "frames": samples.size(), "frame_ms": avg[0], "fps": 1000.0 / avg[0],
		"process_ms": avg[1], "render_cpu_ms": avg[2], "gpu_ms": avg[3], "p90_ms": frames[int(frames.size() * 0.9)],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"scale": get_viewport().scaling_3d_scale, "quality": main.quality, "viewport": str(get_viewport().get_visible_rect().size), "window_px": str(get_window().size), "renderer": RenderingServer.get_current_rendering_method()}
	results.append(result)
	print("DEVICE_PROFILE result ", JSON.stringify(result))
	_next()
