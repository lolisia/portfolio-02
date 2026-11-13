extends Node3D
class_name WaterReflection

## Forward+ planar reflection for the pond. A second orthographic camera is
## mirrored across the water plane and rendered into a small SubViewport. The
## water shader projects world positions through the mirror camera.

var viewport: SubViewport
var camera: Camera3D
var main_camera: Camera3D
var water: MeshInstance3D
var material: ShaderMaterial
var water_y := 0.44
var ready_for_render := false
var resolution_height := 512
var update_interval := 2
var frame_counter := 0
var pond_west := 5.0
var pond_east := 15.0
var pond_north := 1.6
var pond_south := 10.6

func setup(p_water: MeshInstance3D, p_camera: Camera3D, p_water_y: float) -> void:
	water = p_water
	main_camera = p_camera
	water_y = p_water_y
	material = water.material_override as ShaderMaterial
	if material == null:
		return
	water.layers = 2
	_compute_pond_bounds()

	viewport = SubViewport.new()
	viewport.name = "PondReflection"
	viewport.size = Vector2i(640, 512)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.canvas_cull_mask = 0
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "PondMirrorCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.cull_mask = 0xFFFFF & ~2 & ~4
	viewport.add_child(camera)
	camera.current = true
	material.set_shader_parameter("reflection_tex", viewport.get_texture())
	material.set_shader_parameter("reflection_strength", 1.0)
	frame_counter = 1
	ready_for_render = true

func _compute_pond_bounds() -> void:
	if water == null or water.mesh == null:
		return
	var west := INF
	var east := -INF
	var north := INF
	var south := -INF
	var offset := water.position
	for surface in range(water.mesh.get_surface_count()):
		var arrays := water.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var depth: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for i in range(vertices.size()):
			if depth.size() > i and depth[i].x > -0.03:
				west = minf(west, vertices[i].x + offset.x)
				east = maxf(east, vertices[i].x + offset.x)
				north = minf(north, vertices[i].z + offset.z)
				south = maxf(south, vertices[i].z + offset.z)
	if west < east and north < south:
		pond_west = west
		pond_east = east
		pond_north = north
		pond_south = south

func _process(_delta: float) -> void:
	if not ready_for_render or main_camera == null or camera == null:
		return
	frame_counter += 1
	if update_interval > 1 and frame_counter % update_interval != 0:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.keep_aspect = main_camera.keep_aspect

	var main_transform := main_camera.global_transform
	var main_origin := main_transform.origin
	var main_target := main_origin - main_transform.basis.z * 20.0
	var mirrored_origin := main_origin
	mirrored_origin.y = 2.0 * water_y - mirrored_origin.y
	var mirrored_target := main_target
	mirrored_target.y = 2.0 * water_y - mirrored_target.y
	var mirrored_up := main_transform.basis.y
	mirrored_up.y = -mirrored_up.y
	# The reflected camera sits below the pond, looking up at the mirrored
	# view target. The negative-handed orientation is the physical mirror.
	camera.look_at_from_position(mirrored_origin, mirrored_target, mirrored_up)

	# R3: crop the mirror camera to the pond's screen bounds, like water.js.
	# Crop vertically and horizontally in the mirror camera's local frame.
	var inverse := camera.global_transform.affine_inverse()
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for x in [pond_west, pond_east]:
		for z in [pond_north, pond_south]:
			var local: Vector3 = inverse * Vector3(x, water_y, z)
			min_x = minf(min_x, local.x)
			max_x = maxf(max_x, local.x)
			min_y = minf(min_y, local.y)
			max_y = maxf(max_y, local.y)
	if max_x > min_x and max_y > min_y:
		var center_x := (min_x + max_x) * 0.5
		var center_y := (min_y + max_y) * 0.5
		var crop_width := (max_x - min_x) * 1.10
		var crop_height := (max_y - min_y) * 1.10
		camera.global_position += camera.global_transform.basis.x * center_x \
			+ camera.global_transform.basis.y * center_y
		camera.size = maxf(crop_height, 0.001)
		var aspect := crop_width / maxf(crop_height, 0.001)
		var width := clampi(int(round(float(resolution_height) * aspect)), 128, 1024)
		viewport.size = Vector2i(width, resolution_height)

	material.set_shader_parameter("reflection_projection", camera.get_camera_projection())
	material.set_shader_parameter("reflection_view", camera.global_transform.affine_inverse())

func set_quality(level: int) -> void:
	if material == null or viewport == null:
		return
	if level >= 2:
		ready_for_render = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		material.set_shader_parameter("reflection_strength", 0.0)
	else:
		resolution_height = 512 if level == 0 else 384
		update_interval = 2
		frame_counter = 0
		ready_for_render = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		material.set_shader_parameter("reflection_strength", 1.0)
