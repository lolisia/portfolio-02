extends Node3D
class_name WeatherFX

## GPU rain/snow and the waterfall spray. Rain and snow fade in with
## `set_intensity` so weather changes blend instead of snapping. The particles
## are an emitter box over the island; roofs/ground collision is visual-only.

var rain: GPUParticles3D
var snow: GPUParticles3D
var spray: GPUParticles3D
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
const RIPPLE_CAPACITY := 120

func _ready() -> void:
	rain = _make_particles("Rain", 1100, 1.15, 5.0, 9.0, Color(0.55, 0.66, 0.78, 0.30), Vector2(0.028, 0.52))
	snow = _make_particles("Snow", 2400, 9.0, 0.5, 1.4, Color(0.92, 0.95, 1.0, 0.75), Vector2(0.045, 0.045))
	rain.position = Vector3(0, 7, 0)
	snow.position = Vector3(0, 7, 0)
	rain.emitting = false
	snow.emitting = false
	rain.amount_ratio = 0.0
	snow.amount_ratio = 0.0
	rain_process = rain.process_material as ParticleProcessMaterial
	snow_process = snow.process_material as ParticleProcessMaterial
	_build_spray()
	_build_ripples()

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
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
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
	process.gravity = Vector3(0, -9.8 if label == "Rain" else -0.8, 0)
	process.lifetime_randomness = 0.25
	process.angular_velocity_min = -15.0
	process.angular_velocity_max = 15.0
	particles.process_material = process

	add_child(particles)
	return particles

func _soft_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var a := pow(clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0), 2.4)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

func _build_spray() -> void:
	spray = GPUParticles3D.new()
	spray.name = "WaterfallSpray"
	spray.amount = 70
	spray.lifetime = 2.4
	spray.preprocess = 2.4
	spray.local_coords = false
	spray.visibility_aabb = AABB(Vector3(-4, -6, -4), Vector3(8, 12, 8))
	spray.position = Vector3(15.05, 0.18, 6.1)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.26, 0.26)
	spray.draw_pass_1 = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = _soft_texture()
	material.albedo_color = Color(0.78, 0.88, 0.96, 0.18)
	quad.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.18, 0.35, 1.25)
	process.direction = Vector3(0.8, 0.55, 0.0)
	process.spread = 30.0
	process.initial_velocity_min = 0.15
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0.0, -0.75, 0.0)
	process.lifetime_randomness = 0.4
	process.scale_min = 0.4
	process.scale_max = 1.1
	process.angular_velocity_min = -30.0
	process.angular_velocity_max = 30.0
	spray.process_material = process
	add_child(spray)

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
	ripples.custom_aabb = AABB(Vector3(5.0, 0.0, 2.0), Vector3(10.0, 2.0, 8.0))
	add_child(ripples)
	ripple_items.resize(RIPPLE_CAPACITY)

func _place_ripple(index: int, item: Dictionary) -> void:
	var scale_value: float = float(item["scale"]) * (1.0 + float(item["life"]) * 0.9)
	var basis := Basis.from_scale(Vector3(scale_value, 1.0, scale_value))
	ripple_mesh.set_instance_transform(index,
		Transform3D(basis, Vector3(float(item["x"]), world.water.position.y + 0.018, float(item["z"]))))
	ripple_mesh.set_instance_custom_data(index,
		Color(1.0, 1.0, 1.0, (1.0 - float(item["life"])) * 0.8))

func _update_ripples(delta: float) -> void:
	if world == null:
		return
	ripple_accum += delta * (7.0 + 26.0 * rain_level) * quality_scale
	while ripple_accum >= 1.0:
		ripple_accum -= 1.0
		if rain_level <= 0.02:
			continue
		for attempt in range(16):
			var x := randf_range(6.8, 13.9)
			var z := randf_range(3.2, 9.2)
			if world.height(x, z) >= world.water.position.y - 0.08:
				continue
			var index := ripple_cursor
			ripple_cursor = (ripple_cursor + 1) % RIPPLE_CAPACITY
			var item := {"x": x, "z": z, "life": 0.0, "scale": randf_range(0.10, 0.22)}
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
		rain_process.gravity = Vector3(wind * 0.16 + storm_level * 2.5, -9.8, wind * 0.05)
	if snow_process != null:
		snow_process.gravity = Vector3(wind * 0.08 + storm_level * 1.8, -0.8, wind * 0.03)
	if spray != null:
		spray.amount_ratio = quality_scale
	if delta > 0.0:
		_update_ripples(delta)

func set_weather(weather: int) -> void:
	set_intensity(1.0 if weather == 2 else 0.0, 1.0 if weather >= 4 else 0.0,
		1.0 if weather == 5 else 0.0)

func splash(x: float, z: float) -> void:
	if world == null or ripple_mesh == null:
		return
	var index := ripple_cursor
	ripple_cursor = (ripple_cursor + 1) % RIPPLE_CAPACITY
	var item := {"x": x, "z": z, "life": 0.0, "scale": randf_range(0.18, 0.30)}
	ripple_items[index] = item
	_place_ripple(index, item)
