extends Node3D
class_name PathDebug

## Development overlay for the 0.6-tile A* walking graph. Shows walkable node
## markers, graph edges and the character's current route. Enabled with
## `--pathdebug`; hidden in normal play.

var world: FarmWorld
var character: UnityChan
var nodes_mesh: MultiMeshInstance3D
var edges_mesh: MeshInstance3D
var route_mesh: MeshInstance3D
var route_nodes: MultiMeshInstance3D
var route_markers: MultiMesh

func setup(p_world: FarmWorld, p_character: UnityChan) -> void:
	world = p_world
	character = p_character
	_build_nodes()
	_build_edges()
	_build_route()
	visible = false

func _debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_nodes() -> void:
	if character == null or character.paths == null:
		return
	var paths: FarmPaths = character.paths
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 6
	sphere.rings = 3
	multimesh.mesh = sphere
	multimesh.instance_count = paths.nodes.size()
	for i in range(paths.nodes.size()):
		var node: Dictionary = paths.nodes[i]
		var x: float = node["x"]
		var z: float = node["z"]
		multimesh.set_instance_transform(i,
			Transform3D(Basis(), Vector3(x, world.height(x, z) + 0.055, z)))
	nodes_mesh = MultiMeshInstance3D.new()
	nodes_mesh.name = "PathNodes"
	nodes_mesh.multimesh = multimesh
	nodes_mesh.material_override = _debug_material(Color(0.20, 0.95, 0.60, 0.55))
	nodes_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodes_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(nodes_mesh)

func _build_edges() -> void:
	if character == null or character.paths == null:
		return
	var paths: FarmPaths = character.paths
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(paths.nodes.size()):
		var node: Dictionary = paths.nodes[i]
		var ax: float = node["x"]
		var az: float = node["z"]
		var ay := world.height(ax, az) + 0.07
		for edge in node["edges"]:
			var j := int(edge[0])
			if j <= i:
				continue
			var other: Dictionary = paths.nodes[j]
			var bx: float = other["x"]
			var bz: float = other["z"]
			var by := world.height(bx, bz) + 0.07
			immediate.surface_add_vertex(Vector3(ax, ay, az))
			immediate.surface_add_vertex(Vector3(bx, by, bz))
	immediate.surface_end()
	edges_mesh = MeshInstance3D.new()
	edges_mesh.name = "PathEdges"
	edges_mesh.mesh = immediate
	edges_mesh.material_override = _debug_material(Color(0.15, 0.85, 0.55, 0.42))
	edges_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edges_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(edges_mesh)

func _build_route() -> void:
	route_mesh = MeshInstance3D.new()
	route_mesh.name = "PathRoute"
	route_mesh.material_override = _debug_material(Color(1.0, 0.55, 0.10, 0.95))
	route_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	route_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(route_mesh)

	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	route_markers = MultiMesh.new()
	route_markers.transform_format = MultiMesh.TRANSFORM_3D
	route_markers.mesh = sphere
	route_markers.instance_count = 64
	for i in range(64):
		route_markers.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -80.0, 0.0)))
	route_nodes = MultiMeshInstance3D.new()
	route_nodes.name = "PathRouteMarkers"
	route_nodes.multimesh = route_markers
	route_nodes.material_override = _debug_material(Color(1.0, 0.55, 0.10, 0.95))
	route_nodes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	route_nodes.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(route_nodes)

func _hide_route_markers() -> void:
	for i in range(64):
		route_markers.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -80.0, 0.0)))

func _process(_delta: float) -> void:
	if not visible or character == null or world == null:
		return
	var route: Array = character.route
	if route.is_empty():
		route_mesh.mesh = null
		_hide_route_markers()
		return
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	var previous := character.position
	previous.y += 0.12
	for point in route:
		var next := Vector3(float(point.x), world.height(float(point.x), float(point.y)) + 0.12,
			float(point.y))
		immediate.surface_add_vertex(previous)
		immediate.surface_add_vertex(next)
		previous = next
	immediate.surface_end()
	route_mesh.mesh = immediate

	var count := mini(route.size() + 1, 64)
	for i in range(64):
		if i < count:
			var px: float
			var pz: float
			var py: float
			if i == 0:
				px = character.position.x
				pz = character.position.z
				py = character.position.y + 0.14
			else:
				var point: Vector2 = route[i - 1]
				px = point.x
				pz = point.y
				py = world.height(px, pz) + 0.14
			route_markers.set_instance_transform(i,
				Transform3D(Basis(), Vector3(px, py, pz)))
		else:
			route_markers.set_instance_transform(i,
				Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -80.0, 0.0)))
