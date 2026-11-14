extends RefCounted
class_name DioramaBuilder

## Batched instanced builder, a port of src/modules.js + the batching half of
## src/surfaces.js. Every kind becomes one MultiMeshInstance3D.

var root: Node3D
var assets: Dictionary
var rng := RandomNumberGenerator.new()
var batches: Dictionary = {}
var parent := Transform3D.IDENTITY

const BOX_KINDS := ["wood", "stone", "clay", "plaster", "glass", "lampglass", "soil", "iron"]
const PLANT_KINDS := [
	"oakALeaves", "oakBLeaves", "pineANeedles",
	"bushALeaves", "bushBLeaves", "grass0", "grass1", "grass2",
	"turf0", "turf1", "turf2", "reed", "carrot", "flowerStem",
	"flowerHead", "cabbage", "sunflowerStem", "sunflowerBloom",
	"lavenderStem", "lavenderBloom", "tulipStem", "tulipBloom",
	"foxgloveStem", "foxgloveBloom", "roseBloom",
]
const LEAF_SPRAY := preload("res://assets/textures/leaf_spray.png")
const NEEDLE_SPRAY := preload("res://assets/textures/needle_spray.png")
const NO_SHADOW := ["turf0", "turf1", "turf2", "grass0", "grass1", "grass2", "glass"]

func _init(p_root: Node3D, p_assets: Dictionary, p_seed: int = 41573) -> void:
	root = p_root
	assets = p_assets
	rng.seed = p_seed

func randf() -> float:
	return rng.randf()

func pick(values: Array) -> Variant:
	return values[rng.randi_range(0, values.size() - 1)]

func part(kind: String, x: float, y: float, z: float, w: float, h: float, d: float,
		color: Variant, rx: float = 0.0, ry: float = 0.0, rz: float = 0.0, sway: float = 0.0) -> void:
	var c: Color = color if color is Color else Color(str(color))
	# Vertex and MultiMesh instance/custom data are raw shader data; convert the
	# sRGB-authored palette to linear once here.
	c = c.srgb_to_linear()
	var basis := Basis.from_euler(Vector3(rx, ry, rz)) * Basis.from_scale(Vector3(w, h, d))
	var t := parent * Transform3D(basis, Vector3(x, y, z))
	if not batches.has(kind):
		batches[kind] = []
	batches[kind].append([t, c, sway])

func place(x: float, y: float, z: float, scale: float, angle: float, fn: Callable) -> void:
	var old := parent
	parent = old * Transform3D(Basis(Vector3.UP, angle) * Basis.from_scale(Vector3.ONE * scale), Vector3(x, y, z))
	fn.call()
	parent = old

func finish() -> void:
	for kind in batches.keys():
		var kind_name := String(kind)
		var items: Array = batches[kind_name]
		if items.is_empty():
			continue
		var mesh: Mesh = _mesh_for(kind_name)
		if mesh == null:
			continue
		# Ground cover is randomly ordered so the Low quality instance budget is
		# spread over the whole island instead of emptying one corner.
		if kind_name.begins_with("turf") or kind_name.begins_with("grass"):
			for i in range(items.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var swap = items[i]
				items[i] = items[j]
				items[j] = swap
		var material: Material = _material_for(kind_name, mesh)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = items.size()
		for i in range(items.size()):
			var item: Array = items[i]
			mm.set_instance_transform(i, item[0])
			var item_color: Color = item[1]
			mm.set_instance_color(i, item_color)
			# The foliage shader reads the tint from custom data as well, because
			# MultiMesh instance colors are not exposed consistently in custom shaders.
			mm.set_instance_custom_data(i, Color(item_color.r, item_color.g, item_color.b, float(item[2])))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind_name
		mmi.multimesh = mm
		mmi.material_override = material
		var no_shadow := kind_name in NO_SHADOW
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if no_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(mmi)

func _mesh_for(kind: String) -> Mesh:
	if assets.has(kind):
		return assets[kind]
	match kind:
		"stone", "wood", "clay", "plaster", "glass", "lampglass", "soil", "iron":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			return box
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.55
			cone.height = 1.0
			cone.radial_segments = 7
			cone.rings = 1
			return cone
		"trunk":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.40
			trunk.bottom_radius = 0.53
			trunk.height = 1.0
			trunk.radial_segments = 7
			trunk.rings = 1
			return trunk
		"leaf", "boulder":
			var sphere := SphereMesh.new()
			sphere.radius = 0.52
			sphere.height = 1.04
			sphere.radial_segments = 7
			sphere.rings = 4
			return sphere
		_:
			var fallback := BoxMesh.new()
			fallback.size = Vector3.ONE
			return fallback

func _material_for(kind: String, mesh: Mesh = null) -> Material:
	if kind in PLANT_KINDS:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = preload("res://shaders/foliage.gdshader")
		shader_mat.set_shader_parameter("wind_strength", 1.0)
		# K4: the Blender nature meshes carry their baked shading in vertex
		# colours. Detect that per mesh and multiply it into the instance tint.
		var has_vertex_colors := false
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface)
				var colors = arrays[Mesh.ARRAY_COLOR]
				if colors != null and (colors as PackedColorArray).size() > 0:
					has_vertex_colors = true
					break
		shader_mat.set_shader_parameter("use_vertex_color",
			1.0 if has_vertex_colors else 0.0)
		# Only low ground cover is flattened by walkers; trees keep their sway.
		if kind.begins_with("turf") or kind.begins_with("grass"):
			shader_mat.set_shader_parameter("trample_strength", 1.0)
		# The web keeps pine needles evergreen in winter.
		if kind == "pineANeedles":
			shader_mat.set_shader_parameter("evergreen", 1.0)
			shader_mat.set_shader_parameter("leaf_cut", 2.0)
			shader_mat.set_shader_parameter("spray_tex", NEEDLE_SPRAY)
			shader_mat.set_shader_parameter("tint_influence", 0.19)
		elif kind.ends_with("Leaves"):
			shader_mat.set_shader_parameter("leaf_cut", 1.0)
			shader_mat.set_shader_parameter("spray_tex", LEAF_SPRAY)
		elif kind == "flowerHead" or kind.ends_with("Bloom"):
			# Web 'petal' material is not part of the foliageTint set.
			shader_mat.set_shader_parameter("tint_influence", 0.0)
		return shader_mat
	if kind == "glass" or kind == "lampglass":
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		if kind == "glass":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1, 1, 1, 0.42)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.67, 0.32)
			mat.emission_energy_multiplier = 0.03
			mat.roughness = 0.23
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		else:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.93, 0.80)
			mat.emission_energy_multiplier = 0.03
			mat.roughness = 0.2
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat
	var kind_index := 1
	match kind:
		"wood", "bedFrame", "stumpBark", "stumpTop": kind_index = 0
		"stone", "boulder", "leaf": kind_index = 1
		"clay": kind_index = 2
		"plaster": kind_index = 3
		"soil", "bedSoil": kind_index = 4
		"iron": kind_index = 5
	# Bark, twigs and stump parts use the wood grain rather than the default
	# stone surface (the web gives them a dedicated rough bark recipe).
	var lower_kind := kind.to_lower()
	if "bark" in lower_kind or "twig" in lower_kind or lower_kind.begins_with("stump"):
		kind_index = 0
	var surface_mat := ShaderMaterial.new()
	surface_mat.shader = preload("res://shaders/surface.gdshader")
	surface_mat.set_shader_parameter("surface_kind", kind_index)
	return surface_mat

