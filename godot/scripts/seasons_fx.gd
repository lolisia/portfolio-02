extends Node3D
class_name SeasonsFX

## Spring cherry petals and autumn leaves, ported from src/seasons.js. Both are
## instanced bits that spawn in the tree crowns, tumble on the wind, land on the
## ground or a roof, rest there for 1.75 s and respawn. Snow stays in WeatherFX.

const PETAL_COUNT := 155
const LEAF_COUNT := 175
const REST_TIME := 1.75
const PETAL_COLORS := [
	Color(1.0, 0.749, 0.820), Color(1.0, 0.878, 0.894), Color(0.898, 0.639, 0.714),
]
const LEAF_COLORS := [
	Color(0.733, 0.376, 0.169), Color(0.906, 0.604, 0.251),
	Color(0.659, 0.243, 0.149), Color(0.867, 0.733, 0.337),
]

var world: FarmWorld
var petal_instance: MultiMeshInstance3D
var leaf_instance: MultiMeshInstance3D
var petal_multimesh: MultiMesh
var leaf_multimesh: MultiMesh
var petal_material: StandardMaterial3D
var leaf_material: StandardMaterial3D
var petal_items: Array = []
var leaf_items: Array = []
var petal_level := 0.0
var leaf_level := 0.0
var quality_scale := 1.0
var time := 0.0
var rng := RandomNumberGenerator.new()

func setup() -> void:
	rng.seed = 61837
	var petal_tex := _petal_texture(false)
	var leaf_tex := _petal_texture(true)
	var petals := _build_system("SpringPetals", PETAL_COUNT, petal_tex,
		Color(1.0, 0.88, 0.92), PETAL_COLORS, 0.105, 0.135)
	petal_instance = petals["instance"]
	petal_multimesh = petals["multimesh"]
	petal_material = petals["material"]
	petal_items = petals["items"]
	var leaves := _build_system("AutumnLeaves", LEAF_COUNT, leaf_tex,
		Color(0.93, 0.70, 0.42), LEAF_COLORS, 0.13, 0.17)
	leaf_instance = leaves["instance"]
	leaf_multimesh = leaves["multimesh"]
	leaf_material = leaves["material"]
	leaf_items = leaves["items"]
	petal_instance.visible = false
	leaf_instance.visible = false

func _build_system(label: String, count: int, texture: Texture2D, tint: Color,
		palette: Array, size_x: float, size_y: float) -> Dictionary:
	var quad := QuadMesh.new()
	quad.size = Vector2(size_x, size_y)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.custom_aabb = AABB(Vector3(-15, -3, -15), Vector3(30, 30, 30))
	add_child(instance)

	var items: Array = []
	for i in range(count):
		var item := {
			"phase": rng.randf() * TAU,
			"rate": 0.7 + rng.randf() * 0.7,
			"size": (0.7 + rng.randf() * 0.9),
			"x": 0.0, "y": 0.0, "z": 0.0, "rest": 0.0,
		}
		_spawn(item, true)
		items.append(item)
		multimesh.set_instance_color(i, palette[i % palette.size()])
	return {"instance": instance, "multimesh": multimesh,
		"material": material, "items": items}

func _spawn(item: Dictionary, initial: bool) -> void:
	var trees := FarmWorld.TREE_LIST
	var tree: Array = trees[rng.randi_range(0, trees.size() - 1)]
	var tree_x: float = tree[0]
	var tree_z: float = tree[1]
	var tree_scale: float = tree[2]
	item["x"] = tree_x + (rng.randf() - 0.5) * 2.0
	item["z"] = tree_z + (rng.randf() - 0.5) * 2.0
	var base := world.roof_floor(float(item["x"]), float(item["z"])) + 0.035
	var top := maxf(base + 0.5, world.height(tree_x, tree_z) + 3.7 * tree_scale - 0.25)
	item["y"] = lerpf(base, top, rng.randf()) if initial else top
	item["rest"] = 0.0

func _petal_texture(leaf: bool) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var tint := Color(1.0, 0.82, 0.88) if not leaf else Color(0.94, 0.62, 0.30)
	for y in range(32):
		for x in range(32):
			var u := (float(x) - 15.5) / 14.0
			var v := (float(y) - 15.5) / 15.0
			var d := 0.0
			if leaf:
				# A pointed oval leaf.
				d = sqrt(pow(u / 0.82, 2.0) + pow(v / 1.0, 2.0))
				d += absf(u) * 0.22
			else:
				# A soft cherry petal with a small notch at the top.
				d = sqrt(pow(u / 0.72, 2.0) + pow(v / 1.0, 2.0))
				d += maxf(0.0, -v - 0.45) * absf(u) * 0.35
			var alpha := clampf((1.0 - d) / 0.16, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var color := tint
			color.a = alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _update_system(items: Array, multimesh: MultiMesh, level: float,
		wind: float, delta: float) -> void:
	var active := int(round(float(items.size()) * clampf(quality_scale, 0.0, 1.0)))
	for i in range(items.size()):
		if i >= active or level <= 0.002:
			multimesh.set_instance_transform(i,
				Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -80, 0)))
			continue
		var item: Dictionary = items[i]
		var a: float = float(item["phase"]) + time * float(item["rate"])
		var base := world.roof_floor(float(item["x"]), float(item["z"])) + 0.035
		if float(item["y"]) > base:
			item["x"] = float(item["x"]) + delta * (wind * 0.11 + sin(a) * 0.33)
			item["z"] = float(item["z"]) + delta * (wind * 0.055 + cos(a * 0.87) * 0.28)
			item["y"] = float(item["y"]) - delta * float(item["rate"]) * 0.57
		else:
			item["y"] = base
			item["rest"] = float(item["rest"]) + delta
		if maxf(absf(float(item["x"])), absf(float(item["z"]))) > 15.0 \
				or float(item["rest"]) > REST_TIME:
			_spawn(item, false)
		var size: float = float(item["size"])
		var basis: Basis
		if float(item["rest"]) > 0.0:
			basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, a * 0.5))
		else:
			basis = Basis.from_euler(Vector3(a * 0.88 - PI * 0.5, a * 0.5, sin(a) * 0.9))
		basis = basis.scaled(Vector3.ONE * size)
		multimesh.set_instance_transform(i,
			Transform3D(basis, Vector3(float(item["x"]), float(item["y"]), float(item["z"]))))

func update(delta: float, season: int, wind: float) -> void:
	time += delta
	var petal_target := 1.0 if season == 0 else 0.0
	var leaf_target := 1.0 if season == 2 else 0.0
	petal_level = lerpf(petal_level, petal_target, 1.0 - exp(-delta * 0.9))
	leaf_level = lerpf(leaf_level, leaf_target, 1.0 - exp(-delta * 0.9))
	if petal_material != null:
		var petal_tint := petal_material.albedo_color
		petal_tint.a = petal_level
		petal_material.albedo_color = petal_tint
	if leaf_material != null:
		var leaf_tint := leaf_material.albedo_color
		leaf_tint.a = leaf_level
		leaf_material.albedo_color = leaf_tint
	petal_instance.visible = petal_level > 0.002
	leaf_instance.visible = leaf_level > 0.002
	if petal_instance.visible:
		_update_system(petal_items, petal_multimesh, petal_level, wind, delta)
	if leaf_instance.visible:
		_update_system(leaf_items, leaf_multimesh, leaf_level, wind, delta)
