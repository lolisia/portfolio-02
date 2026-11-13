extends Node3D
class_name WeatherFX

## GPU rain/snow and pond ripple decals. Rain and snow fade in with
## `set_intensity` so weather changes blend instead of snapping. The particles
## are an emitter box over the island; roofs/ground collision is visual-only.

var rain: GPUParticles3D
var snow: GPUParticles3D
var rain_process: ParticleProcessMaterial
var snow_process: ParticleProcessMaterial
var world: FarmWorld
var wind := 3.0
var rain_level := 0.0
var snow_level := 0.0
var storm_level := 0.0
var quality_scale := 1.0
var ripples: MultiMeshInstance3D
var ripple_mesh: MultiMesh
var ripple_items: Array = []
var ripple_cursor := 0
var ripple_accum := 0.0
var ground_accum := 0.0
var water_material: ShaderMaterial
var water_impacts: Array = []
var water_time := 0.0
var impact_cursor := 0
var night_level := 0.0
var lamp_rain: Array[GPUParticles3D] = []
var lamp_rain_materials: Array[StandardMaterial3D] = []
var splash_instance: MultiMeshInstance3D
var splash_multimesh: MultiMesh
var splash_items: Array = []
var splash_cursor := 0
var splash_accum := 0.0
const SPLASH_COUNT := 300
const RIPPLE_CAPACITY := 160

func _ready() -> void:
	rain = _make_particles("Rain", 1600, 1.15, 8.5, 13.5, Color(0.55, 0.66, 0.78, 0.30), Vector2(0.028, 0.52))
	snow = _make_particles("Snow", 9000, 9.0, 0.8, 1.4, Color(0.92, 0.95, 1.0, 0.75), Vector2(0.045, 0.045))
	rain.position = Vector3(0, 7, 0)
	snow.position = Vector3(0, 7, 0)
	rain.emitting = false
	snow.emitting = false
	rain.amount_ratio = 0.0
	snow.amount_ratio = 0.0
	rain_process = rain.process_material as ParticleProcessMaterial
	snow_process = snow.process_material as ParticleProcessMaterial
	rain.collision_base_size = 0.10
	snow.collision_base_size = 0.08
	if rain_process != null:
		rain_process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	if snow_process != null:
		snow_process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_build_roof_collisions()
	_build_ripples()
	_setup_water_impacts()
	_build_splashes()
	_build_lamp_rain()

func _setup_water_impacts() -> void:
	if world == null or world.water == null:
		return
	water_material = world.water.material_override as ShaderMaterial
	if water_material == null:
		return
	water_impacts.clear()
	for i in range(18):
		water_impacts.append(Vector4(0.0, 0.0, -100.0, 0.0))
	water_material.set_shader_parameter("impacts", water_impacts)
	water_material.set_shader_parameter("sim_time", 0.0)

func _water_impact(x: float, z: float, power: float) -> void:
	if water_material == null:
		return
	water_impacts[impact_cursor] = Vector4(x, z, water_time, power)
	impact_cursor = (impact_cursor + 1) % 18
	water_material.set_shader_parameter("impacts", water_impacts)

func _soft_dot_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var dx := (float(x) - 15.5) / 15.5
			var dy := (float(y) - 15.5) / 15.5
			var a := pow(clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0), 2.2)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

func _build_splashes() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = _soft_dot_texture()
	material.albedo_color = Color(0.78, 0.87, 0.87, 0.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	splash_multimesh = MultiMesh.new()
	splash_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	splash_multimesh.use_colors = true
	splash_multimesh.mesh = quad
	splash_multimesh.instance_count = SPLASH_COUNT
	splash_instance = MultiMeshInstance3D.new()
	splash_instance.name = "RainSplashes"
	splash_instance.multimesh = splash_multimesh
	splash_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	splash_instance.custom_aabb = AABB(Vector3(-15, -3, -15), Vector3(30, 30, 30))
	add_child(splash_instance)
	for i in range(SPLASH_COUNT):
		splash_items.append({"life": 0.0, "max": 1.0, "x": 0.0, "y": -80.0,
			"z": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0})
		splash_multimesh.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -80, 0)))
		splash_multimesh.set_instance_color(i, Color(0, 0, 0, 0))

func _build_lamp_rain() -> void:
	if world == null:
		return
	for lamp in world.lamps:
		var position: Vector3 = lamp["position"]
		var particles := GPUParticles3D.new()
		particles.name = "LampRain"
		particles.amount = 80
		particles.lifetime = 1.4
		particles.preprocess = 1.4
		particles.local_coords = false
		particles.visibility_aabb = AABB(Vector3(-4, -6, -4), Vector3(8, 10, 8))
		particles.position = position
		particles.emitting = false
		var quad := QuadMesh.new()
		quad.size = Vector2(0.024, 0.42)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(1.0, 0.72, 0.35, 0.0)
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = material
		particles.draw_pass_1 = quad
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		process.emission_sphere_radius = 1.25
		process.direction = Vector3(0, -1, 0)
		process.spread = 4.0
		process.initial_velocity_min = 4.5
		process.initial_velocity_max = 7.0
		process.gravity = Vector3(0, -8.0, 0)
		particles.process_material = process
		add_child(particles)
		lamp_rain.append(particles)
		lamp_rain_materials.append(material)

func _update_splashes(delta: float) -> void:
	if world == null or splash_instance == null:
		return
	splash_accum += delta * 1100.0 * rain_level * quality_scale
	while splash_accum >= 1.0:
		splash_accum -= 1.0
		if rain_level <= 0.02:
			continue
		for attempt in range(8):
			var x := randf_range(-13.0, 13.0)
			var z := randf_range(-13.0, 13.0)
			if world.height(x, z) < world.water.position.y - 0.04:
				continue
			var index := splash_cursor
			splash_cursor = (splash_cursor + 1) % SPLASH_COUNT
			var max_life := 0.17 + randf() * 0.10
			splash_items[index] = {
				"life": max_life, "max": max_life, "x": x,
				"y": world.roof_floor(x, z) + 0.02, "z": z,
				"vx": (randf() - 0.5) * 1.3, "vy": 0.38 + randf() * 0.7,
				"vz": (randf() - 0.5) * 1.3,
			}
			break
	for i in range(splash_items.size()):
		var item: Dictionary = splash_items[i]
		if float(item["life"]) <= 0.0:
			continue
		item["life"] = float(item["life"]) - delta
		if float(item["life"]) <= 0.0:
			splash_multimesh.set_instance_transform(i,
				Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -80, 0)))
			splash_multimesh.set_instance_color(i, Color(0, 0, 0, 0))
			continue
		item["vy"] = float(item["vy"]) - 6.0 * delta
		item["x"] = float(item["x"]) + float(item["vx"]) * delta
		item["y"] = float(item["y"]) + float(item["vy"]) * delta
		item["z"] = float(item["z"]) + float(item["vz"]) * delta
		splash_multimesh.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, Vector3(float(item["x"]), float(item["y"]),
				float(item["z"]))))
		var fade := float(item["life"]) / maxf(float(item["max"]), 0.001)
		splash_multimesh.set_instance_color(i,
			Color(1.0, 1.0, 1.0, 0.53 * rain_level * clampf(fade, 0.0, 1.0)))

func _update_lamp_rain() -> void:
	var level := rain_level * clampf(night_level, 0.0, 1.0)
	for i in range(lamp_rain.size()):
		var particles: GPUParticles3D = lamp_rain[i]
		particles.emitting = level > 0.02
		particles.amount_ratio = clampf(level, 0.0, 1.0)
		var material: StandardMaterial3D = lamp_rain_materials[i]
		var tint := material.albedo_color
		tint.a = 0.55 * level
		material.albedo_color = tint

func _make_particles(label: String, amount: int, lifetime: float, vmin: float, vmax: float,
		color: Color, quad_size: Vector2) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.fixed_fps = 0
	particles.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 22, 32))

	var quad := QuadMesh.new()
	quad.size = quad_size
	particles.draw_pass_1 = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = (BaseMaterial3D.BILLBOARD_PARTICLES if label == "Rain"
		else BaseMaterial3D.BILLBOARD_ENABLED)
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 8.0, 15.0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 4.0
	process.initial_velocity_min = vmin
	process.initial_velocity_max = vmax
	process.gravity = Vector3(0.0, -0.8 if label == "Rain" else -0.1, 0.0)
	process.lifetime_randomness = 0.25
	process.angular_velocity_min = -15.0
	process.angular_velocity_max = 15.0
	if label == "Snow":
		# Flutter and gusty swirl, like the sine/cosine drift in seasons.js.
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 0.55
		process.turbulence_noise_scale = 2.4
		process.turbulence_noise_speed = Vector3(0.10, 0.05, 0.07)
		process.turbulence_influence_min = 0.03
		process.turbulence_influence_max = 0.16
	particles.process_material = process

	add_child(particles)
	return particles

func _build_roof_collisions() -> void:
	# Boxes hide rain/snow when it reaches the cottage, coop and shed roofs.
	var boxes := [
		[Vector3(-1.0, 3.25, -2.5), Vector3(6.4, 3.6, 6.4)],
		[Vector3(2.25, 3.3, -1.92), Vector3(3.8, 3.2, 3.8)],
		[Vector3(4.45, 3.3, -1.90), Vector3(3.2, 3.0, 3.2)],
	]
	for entry in boxes:
		var box := GPUParticlesCollisionBox3D.new()
		box.size = entry[1]
		box.position = entry[0]
		add_child(box)
	# Canopies stop rain/snow from falling through the tree crowns. The boxes
	# come from the actual foliage mesh AABBs and follow the tree list.
	if world != null:
		for entry in world.tree_canopies():
			var canopy := GPUParticlesCollisionBox3D.new()
			canopy.name = "CanopyCollision"
			canopy.size = entry[1]
			canopy.position = entry[0]
			add_child(canopy)

func _ring_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - absf(r - 0.70) / 0.12, 0.0, 1.0)
			a *= a * 0.75
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(image)

func _build_ripples() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.orientation = PlaneMesh.FACE_Y
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ripple.gdshader")
	material.set_shader_parameter("ring_tex", _ring_texture())
	material.set_shader_parameter("tint", Color(0.72, 0.84, 0.90, 1.0))
	ripple_mesh = MultiMesh.new()
	ripple_mesh.transform_format = MultiMesh.TRANSFORM_3D
	ripple_mesh.use_custom_data = true
	ripple_mesh.mesh = plane
	ripple_mesh.instance_count = RIPPLE_CAPACITY
	for i in range(RIPPLE_CAPACITY):
		ripple_mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -80, 0)))
		ripple_mesh.set_instance_custom_data(i, Color(0, 0, 0, 0))
	ripples = MultiMeshInstance3D.new()
	ripples.name = "RainRipples"
	ripples.multimesh = ripple_mesh
	ripples.material_override = material
	ripples.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripples.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	ripples.custom_aabb = AABB(Vector3(-15.0, -2.0, -15.0), Vector3(30.0, 8.0, 30.0))
	add_child(ripples)
	ripple_items.resize(RIPPLE_CAPACITY)

func _place_ripple(index: int, item: Dictionary) -> void:
	var scale_value: float = float(item["scale"]) * (1.0 + float(item["life"]) * 0.9)
	var basis := Basis.from_scale(Vector3(scale_value, 1.0, scale_value))
	var ground := bool(item.get("ground", false))
	var y := world.height(float(item["x"]), float(item["z"])) + 0.02 if ground else world.water.position.y + 0.018
	ripple_mesh.set_instance_transform(index,
		Transform3D(basis, Vector3(float(item["x"]), y, float(item["z"]))))
	ripple_mesh.set_instance_custom_data(index,
		Color(1.0, 1.0, 1.0, (1.0 - float(item["life"])) * (0.5 if ground else 0.8)))

func _update_ripples(delta: float) -> void:
	if world == null:
		return
	water_time += delta
	if water_material != null:
		water_material.set_shader_parameter("sim_time", water_time)
	ripple_accum += delta * (7.0 + 26.0 * rain_level) * quality_scale
	while ripple_accum >= 1.0:
		ripple_accum -= 1.0
		if rain_level <= 0.02 or water_material == null:
			continue
		for attempt in range(16):
			var x := randf_range(6.8, 13.9)
			var z := randf_range(3.2, 9.2)
			if world.height(x, z) >= world.water.position.y - 0.08:
				continue
			_water_impact(x, z, 0.12)
			break
	ground_accum += delta * (4.0 + 16.0 * rain_level) * quality_scale
	while ground_accum >= 1.0:
		ground_accum -= 1.0
		if rain_level <= 0.02:
			continue
		for attempt in range(8):
			var x := randf_range(-13.0, 13.0)
			var z := randf_range(-13.0, 13.0)
			var ground_y := world.height(x, z)
			if ground_y < world.water.position.y + 0.03:
				continue
			var index := ripple_cursor
			ripple_cursor = (ripple_cursor + 1) % RIPPLE_CAPACITY
			var item := {"x": x, "z": z, "life": 0.0, "scale": randf_range(0.05, 0.12), "ground": true}
			ripple_items[index] = item
			_place_ripple(index, item)
			break
	for i in range(ripple_items.size()):
		var item: Variant = ripple_items[i]
		if item == null:
			continue
		var entry: Dictionary = item
		entry["life"] = float(entry["life"]) + delta / 0.7
		if float(entry["life"]) >= 1.0:
			ripple_items[i] = null
			ripple_mesh.set_instance_custom_data(i, Color(0, 0, 0, 0))
			continue
		_place_ripple(i, entry)

func set_intensity(rain_amount: float, snow_amount: float, storm_amount: float, delta: float = 0.0) -> void:
	rain_level = clampf(rain_amount, 0.0, 1.0)
	snow_level = clampf(snow_amount, 0.0, 1.0)
	storm_level = clampf(storm_amount, 0.0, 1.0)
	if rain == null or snow == null:
		return
	rain.emitting = rain_level > 0.01
	snow.emitting = snow_level > 0.01
	rain.amount_ratio = rain_level * quality_scale
	snow.amount_ratio = snow_level * (0.35 + 0.65 * storm_level) * quality_scale
	if rain_process != null:
		# Straight-line rain slanted by wind. The original uses a constant
		# horizontal velocity (wind * .43 / .16), so encode it in the emission
		# direction instead of accelerating the drops sideways.
		var rain_side := wind * 0.43 + storm_level * 2.5
		var rain_depth := wind * 0.16 + storm_level * 0.7
		rain_process.direction = Vector3(rain_side, -11.0, rain_depth).normalized()
		rain_process.initial_velocity_min = 8.5 + storm_level * 1.5
		rain_process.initial_velocity_max = 13.0 + storm_level * 2.0
		rain_process.spread = 2.5 + storm_level * 4.5
		rain_process.gravity = Vector3(0.0, -0.8, 0.0)
	if snow_process != null:
		# Snow drifts at a gentle constant speed and speeds up in a whiteout.
		var snow_side := wind * 0.13 + storm_level * 2.4
		var snow_depth := wind * 0.055 + storm_level * 0.15
		snow_process.direction = Vector3(snow_side, -1.0, snow_depth).normalized()
		snow_process.initial_velocity_min = 0.8 + storm_level * 0.9
		snow_process.initial_velocity_max = 1.4 + storm_level * 1.8
		snow_process.spread = 8.0 + storm_level * 10.0
		snow_process.gravity = Vector3(0.0, -0.10, 0.0)
		snow_process.turbulence_noise_strength = 0.55 + storm_level * 0.9
		snow_process.turbulence_influence_max = 0.16 + storm_level * 0.25
		snow_process.turbulence_noise_speed = Vector3(
			0.10 + wind * 0.012, 0.05, 0.07 + wind * 0.008)
	if delta > 0.0:
		_update_ripples(delta)
	_update_splashes(delta)
	_update_lamp_rain()

func set_weather(weather: int) -> void:
	set_intensity(1.0 if weather == 2 else 0.0, 1.0 if weather >= 4 else 0.0,
		1.0 if weather == 5 else 0.0)

func splash(x: float, z: float) -> void:
	if world == null:
		return
	if water_material != null and world.height(x, z) < world.water.position.y - 0.04:
		# E8: the web routes fish/rain splashes into the pond shader's impacts.
		_water_impact(x, z, 0.26)
		return
	if ripple_mesh == null:
		return
	var index := ripple_cursor
	ripple_cursor = (ripple_cursor + 1) % RIPPLE_CAPACITY
	var item := {"x": x, "z": z, "life": 0.0, "scale": randf_range(0.18, 0.30)}
	ripple_items[index] = item
	_place_ripple(index, item)
