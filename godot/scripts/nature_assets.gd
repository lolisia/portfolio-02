extends RefCounted
class_name NatureAssets

## Reads the mesh resources out of the Blender nature asset. The .glb is
## imported as a PackedScene; we only keep the Mesh resources, not the nodes.

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
			result[String(node.name)] = mi.mesh
	for child in node.get_children():
		_collect(child, result)
