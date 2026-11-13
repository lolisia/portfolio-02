extends Node3D
class_name Footprints

## Port of src/footprints.js: pressed boot and claw prints on the snow cover.
## Two MultiMesh layers share a procedural print texture; each instance fades
## with the stored life and follows the rising snow surface.

const BOOT_SIZE := Vector2(0.10, 0.175)
const CLAW_SIZE := Vector2(0.075, 0.075)
const BOOT_CAPACITY := 360
const CLAW_CAPACITY := 420
const QUALITY_CAPACITY := [[360, 420], [240, 280], [150, 170]]
const QUALITY_TEXTURE := [64, 48, 32]
const QUALITY_FILL := [1.0, 1.15, 1.35]

var world: FarmWorld
var snow_depth := 0.0
var snowfall := 0.0
var layers: Dictionary = {}
var quality := 0
var fill_scale := 1.0

var _surface_timer := 0.0
var _last_surface_depth := -1.0

func setup() -> void:
	layers["boot"] = _make_layer("boot", _boot_texture(), BOOT_CAPACITY, BOOT_SIZE)
	layers["claw"] = _make_layer("claw", _claw_texture(), CLAW_CAPACITY, CLAW_SIZE)

func _make_layer(kind: String, texture: Texture2D, capacity: int, size: Vector2) -> Dictionary:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.orientation = PlaneMesh.FACE_Y
	plane.subdivide_width = 0
	plane.subdivide_depth = 0

	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/footprint.gdshader")
	material.set_shader_parameter("print_tex", texture)
	material.set_shader_parameter("tint", Color(0.96, 1.02, 1.12, 1.0))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = plane
	multimesh.instance_count = capacity
	for i in range(capacity):
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -80.0, 0.0)))
		multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))

	var instance := MultiMeshInstance3D.new()
	instance.name = "Footprints-" + kind
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-15.0, -5.0, -15.0), Vector3(30.0, 35.0, 30.0))
	add_child(instance)

	return {
		"kind": kind, "instance": instance, "multimesh": multimesh,
		"size": size, "capacity": capacity, "items": [], "next": 0, "texture_size": 64,
	}

## Lay a print at (x, z). `heading` is the walker's Y rotation. Mirrors the
## original guard: only deep enough snow, above the waterline, not on a deck.
func press(kind: String, x: float, z: float, heading: float, scale: float = 1.0) -> void:
	if world == null or snow_depth < 0.3:
		return
	if not layers.has(kind):
		return
	var ground := world.height(x, z)
	if ground < world.WATER_Y + 0.06:
		return
	if world.stand(x, z) > ground + 0.02:
		return
	var layer: Dictionary = layers[kind]
	var items: Array = layer["items"]
	var index: int = layer["next"]
	layer["next"] = (index + 1) % int(layer["capacity"])
	var item := {"x": x, "z": z, "heading": heading, "scale": scale, "life": 1.0}
	if items.size() <= index:
		items.resize(int(layer["capacity"]))
	items[index] = item
	_place(layer, index, item)

func _place(layer: Dictionary, index: int, item: Dictionary) -> void:
	if world == null:
		return
	var size: Vector2 = layer["size"]
	var position := Vector3(
		float(item["x"]),
		world.snow_surface(float(item["x"]), float(item["z"]), snow_depth),
		float(item["z"]))
	var basis := Basis(Vector3.UP, float(item["heading"]) + PI)
	basis = basis.scaled(Vector3(size.x * float(item["scale"]), 1.0, size.y * float(item["scale"])))
	var multimesh: MultiMesh = layer["multimesh"]
	multimesh.set_instance_transform(index, Transform3D(basis, position))

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	fill_scale = QUALITY_FILL[quality]
	var caps: Array = QUALITY_CAPACITY[quality]
	var tex_size: int = QUALITY_TEXTURE[quality]
	_resize_layer("boot", int(caps[0]), tex_size)
	_resize_layer("claw", int(caps[1]), tex_size)

func _resize_layer(kind: String, capacity: int, tex_size: int) -> void:
	if not layers.has(kind):
		return
	var layer: Dictionary = layers[kind]
	var old_capacity: int = int(layer["capacity"])
	var multimesh: MultiMesh = layer["multimesh"]
	var items: Array = layer["items"]
	if capacity != old_capacity:
		multimesh.instance_count = capacity
		items.resize(capacity)
		if capacity < old_capacity:
			layer["next"] = mini(int(layer["next"]), capacity - 1)
		else:
			for i in range(old_capacity, capacity):
				multimesh.set_instance_transform(i,
					Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -80.0, 0.0)))
				multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
		layer["capacity"] = capacity
	if int(layer.get("texture_size", 64)) != tex_size:
		layer["texture_size"] = tex_size
		var texture := _boot_texture(tex_size) if kind == "boot" else _claw_texture(tex_size)
		var instance: MultiMeshInstance3D = layer["instance"]
		var material := instance.material_override as ShaderMaterial
		if material != null:
			material.set_shader_parameter("print_tex", texture)

func _process(delta: float) -> void:
	if world == null:
		return
	var cover := smoothstep(0.3, 0.75, snow_depth)
	var fill := delta * (1.0 / 120.0 + snowfall / 55.0) * fill_scale
	_surface_timer += delta
	var move_surface := _surface_timer > 0.08 and absf(snow_depth - _last_surface_depth) > 0.001
	if move_surface:
		_surface_timer = 0.0
		_last_surface_depth = snow_depth

	for kind in layers:
		var layer: Dictionary = layers[kind]
		var items: Array = layer["items"]
		if items.is_empty():
			continue
		var multimesh: MultiMesh = layer["multimesh"]
		var instance: MultiMeshInstance3D = layer["instance"]
		instance.visible = cover > 0.002
		for i in range(items.size()):
			var item: Variant = items[i]
			if item == null:
				continue
			var entry: Dictionary = item
			var life := float(entry["life"]) - fill
			entry["life"] = life
			if life <= 0.0:
				items[i] = null
				multimesh.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
				continue
			if move_surface:
				_place(layer, i, entry)
			var fade: float = clampf(life * 1.6, 0.0, 1.0) * cover
			multimesh.set_instance_custom_data(i, Color(1.0, 1.0, 1.0, fade))

# --- Procedural print textures -------------------------------------------
# The source draws into a 64px canvas centred at (32, 32): a rounded boot sole
# with the toe toward the top, and a three-toed claw. Reproduce the shapes as
# distance fields so they stay soft at the edges like the blurred canvas.

func _boot_texture(size: int = 64) -> ImageTexture:
	size = maxi(8, size)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var scale := 64.0 / float(size)
	var base := Color(70.0 / 255.0, 92.0 / 255.0, 128.0 / 255.0)
	var hollow := Color(40.0 / 255.0, 56.0 / 255.0, 86.0 / 255.0)
	for y in range(size):
		for x in range(size):
			var dx := (float(x) + 0.5 - float(size) * 0.5) * scale
			var dy := (float(y) + 0.5 - float(size) * 0.5) * scale
			var d := minf(
				sqrt(pow(dx / 10.0, 2.0) + pow((dy + 9.0) / 15.0, 2.0)),
				sqrt(pow(dx / 8.0, 2.0) + pow((dy - 15.0) / 10.0, 2.0)))
			var alpha := clampf((1.0 - d) / 0.26, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var core := minf(
				sqrt(pow((dx + 1.5) / 10.0, 2.0) + pow((dy - 1.0 + 9.0) / 15.0, 2.0)),
				sqrt(pow((dx + 1.5) / 8.0, 2.0) + pow((dy - 1.0 - 15.0) / 10.0, 2.0)))
			var shade := clampf((1.0 - core) / 0.30, 0.0, 1.0)
			var color := base.lerp(hollow, shade * 0.9).srgb_to_linear()
			color.a = alpha * 0.9
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _claw_texture(size: int = 64) -> ImageTexture:
	size = maxi(8, size)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var scale := 64.0 / float(size)
	var color := Color(60.0 / 255.0, 80.0 / 255.0, 116.0 / 255.0).srgb_to_linear()
	var toes: Array = []
	for angle in [-0.62, 0.0, 0.62]:
		toes.append([Vector2(0.0, 10.0), Vector2(sin(angle) * 24.0, 10.0 - cos(angle) * 26.0)])
	toes.append([Vector2(0.0, 10.0), Vector2(0.0, 22.0)])
	for y in range(size):
		for x in range(size):
			var p := Vector2((float(x) + 0.5 - float(size) * 0.5) * scale,
				(float(y) + 0.5 - float(size) * 0.5) * scale)
			var nearest := 999.0
			for toe in toes:
				nearest = minf(nearest, _segment_distance(p, toe[0], toe[1]))
			var alpha := clampf((3.6 - nearest) / 2.2, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var pixel := color
			pixel.a = alpha * 0.95
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)

func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)
