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
var resolution_height := 288
var update_interval := 2
var frame_counter := 0

func setup(p_water: MeshInstance3D, p_camera: Camera3D, p_water_y: float) -> void:
	water = p_water
	main_camera = p_camera
	water_y = p_water_y
	material = water.material_override as ShaderMaterial
	if material == null:
		return
	water.layers = 2

	viewport = SubViewport.new()
	viewport.name = "PondReflection"
	viewport.size = Vector2i(512, 288)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.canvas_cull_mask = 0
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "PondMirrorCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.cull_mask = 0xFFFFF & ~2
	viewport.add_child(camera)
	camera.current = true
	material.set_shader_parameter("reflection_tex", viewport.get_texture())
	material.set_shader_parameter("reflection_strength", 1.0)
	frame_counter = 1
	ready_for_render = true

func _process(_delta: float) -> void:
	if not ready_for_render or main_camera == null or camera == null:
		return
	frame_counter += 1
	if update_interval > 1 and frame_counter % update_interval != 0:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	camera.size = main_camera.size
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

	var viewport_size := get_viewport().get_visible_rect().size
	var height := resolution_height
	var width := maxi(1, int(round(height * viewport_size.x / maxf(viewport_size.y, 1.0))))
	viewport.size = Vector2i(width, height)

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
		resolution_height = 288 if level == 0 else 224
		update_interval = 2
		frame_counter = 0
		ready_for_render = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		material.set_shader_parameter("reflection_strength", 1.0)
