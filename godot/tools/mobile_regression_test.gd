extends SceneTree

func _initialize() -> void:
	root.size = Vector2i(390, 848)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var failures: Array[String] = []
	main.orbit.set_view(Vector3(0, 1, 0), 0.4, 0.8, 2.0)
	main.ui.set_panel_open(false, true)
	main._update_view_framing(1.0)
	var transform: Transform3D = main.orbit.global_transform
	var span: float = main.orbit.size
	var offset: float = main.orbit.v_offset
	main.ui.set_panel_open(true, true)
	main._update_view_framing(1.0)
	if not main.orbit.global_transform.is_equal_approx(transform) or not is_equal_approx(main.orbit.size, span) or not is_equal_approx(main.orbit.v_offset, offset):
		failures.append("opening portrait panel moves/scales the game")
	main.orbit.zoom = 100.0
	main.orbit._apply()
	if not is_equal_approx(main.orbit.zoom, 12.0):
		failures.append("close zoom limit is not 12x")
	var cascade = main.world.cascade_fx
	cascade.update(0.016, 3.0, 0.8)
	for i in [0, 299, 899]:
		var k: int = i * 16
		var buffer: PackedFloat32Array = cascade.drop_multimesh.buffer
		var state: Dictionary = cascade.drop_states[i]
		var actual := Vector3(buffer[k + 3], buffer[k + 7], buffer[k + 11])
		if actual.distance_to(Vector3(state.x, state.y, state.z)) > 0.0001 or absf(buffer[k + 12] - 0.8) > 0.0001:
			failures.append("bulk particle upload changed position/colour")
	# Every point outside the conservative union has zero influence under the
	# original smoothstep radius. The expensive loop can safely be skipped.
	var slots := PackedVector4Array([Vector4(2, 3, 0.4, 1.0)])
	main.world.set_trample(slots)
	var mat: ShaderMaterial = main.world._trample_materials[0]
	var bounds: Vector4 = mat.get_shader_parameter("trample_bounds")
	if bounds.x > 1.32 or bounds.z < 2.68 or bounds.y > 2.32 or bounds.w < 3.68:
		failures.append("trample union cuts off visible influence")
	if failures.is_empty():
		print("MOBILE PASS: fixed panel framing, 12x zoom, bulk particles, conservative trample bounds")
		quit(0)
	else:
		for failure in failures:
			push_error("MOBILE FAIL: " + failure)
		quit(1)
