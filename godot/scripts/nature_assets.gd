extends RefCounted
class_name NatureAssets

## Reads the mesh resources out of the Blender nature asset. The .glb is
## imported as a PackedScene; we only keep the Mesh resources, not the nodes.
## The source GLB has no COLOR_0 stream, so the web's vertexColors materials
## are effectively white. We synthesise the intended baked top-lit gradient
## here so the foliage shader can apply it (K4).

static func load_meshes(path: String = "res://assets/models/nature.glb") -> Dictionary:
	var result: Dictionary = {}
	var packed := load(path)
	if packed == null:
		push_warning("nature asset not imported yet: " + path)
		return result
	var scene: Node = packed.instantiate()
	_collect(scene, result)
	scene.free()
	return result

static func _collect(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			result[String(node.name)] = _with_shade_colors(mi.mesh)
	for child in node.get_children():
		_collect(child, result)

static func _with_shade_colors(mesh: Mesh) -> Mesh:
	var has_colors := false
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var existing = arrays[Mesh.ARRAY_COLOR]
		if existing != null and (existing as PackedColorArray).size() > 0:
			has_colors = true
			break
	if has_colors:
		return mesh
	var shaded := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var count := vertices.size()
		if count == 0:
			continue
		var min_y := INF
		var max_y := -INF
		for vertex in vertices:
			min_y = minf(min_y, vertex.y)
			max_y = maxf(max_y, vertex.y)
		var span := maxf(max_y - min_y, 0.001)
		var colors := PackedColorArray()
		colors.resize(count)
		for i in range(count):
			var up := clampf(normals[i].y, 0.0, 1.0) if normals.size() > i else 0.5
			var height := clampf((vertices[i].y - min_y) / span, 0.0, 1.0)
			var shade := 0.82 + 0.10 * up + 0.08 * height
			colors[i] = Color(shade, shade, shade, 1.0)
		arrays[Mesh.ARRAY_COLOR] = colors
		shaded.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
	return shaded
