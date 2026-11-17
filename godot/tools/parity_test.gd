extends SceneTree

## Regression checks for PARITY_AUDIT_2. Run headless with --script.
func _initialize() -> void:
	seed(2142026)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var character = main.character
	var world = main.world
	var failures: Array[String] = []
	# Check the imported animation and deformed boot positions. A moving
	# actor node alone did not catch the old A-pose/buried mesh regression.
	var walk: Animation = character.animation.get_animation("Walking")
	if walk.length > 1.3:
		failures.append("Walking still contains the absolute-timestamp pre-roll")
	var skeleton: Skeleton3D = character.model.find_child("Skeleton3D", true, false)
	var leg := skeleton.find_bone("Character1_LeftUpLeg")
	character.animation.play("Walking")
	character.animation.seek(0.0, true)
	character.animation.advance(0.0)
	var initial_leg := skeleton.get_bone_pose_rotation(leg)
	character.animation.advance(0.3)
	if initial_leg.angle_to(skeleton.get_bone_pose_rotation(leg)) < 0.05:
		failures.append("Walking does not animate the leg within its first 300ms")
	var bounds: AABB = character._model_aabb()
	if bounds.position.y < -0.05 or bounds.position.y > 0.12:
		failures.append("posed boots are not at actor ground height: %.3f" % bounds.position.y)
	character.animation.play("Standing")
	character.animation.advance(0.0)
	character.hour = 8.5
	character.weather = 0
	character.wind = 3.0
	var farthest := 0.0
	var exit_time := 0.0
	# Reproduce the original door jam through the actual schedule/walk/resolve
	# loop. Inspect real displacement, not just an emptied waypoint list.
	for i in range(1200):
		world._process(0.05)
		character._process(0.05)
		var point := Vector2(character.position.x, character.position.z)
		farthest = maxf(farthest, point.distance_to(world.cottage_threshold))
		if character.state == "exiting":
			exit_time += 0.05
	if farthest < 2.0 or exit_time > 12.0:
		failures.append("door exit stuck: distance=%.2f, exiting=%.2fs" % [farthest, exit_time])
	character.weather = 2
	for i in range(1600):
		world._process(0.05)
		character._process(0.05)
		if character.state == "inside":
			break
	if character.state != "inside" or Vector2(character.position.x, character.position.z).distance_to(world.cottage_threshold) > 0.25:
		failures.append("return did not reach the threshold: %s %s" % [character.state, character.position])
	# Drag down must increase camera elevation for both pointer types.
	main.orbit.set_view(Vector3.ZERO, 0.4, 0.8, 1.0)
	main.orbit._dragging = true
	main.orbit._drag_button = MOUSE_BUTTON_RIGHT
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(0, 20)
	main.orbit._unhandled_input(drag)
	if main.orbit.pitch_target <= 0.8:
		failures.append("mouse vertical drag inverted")
	main.orbit.set_view(Vector3.ZERO, 0.4, 0.8, 1.0)
	main.orbit._touch_points = {0: Vector2.ZERO, 1: Vector2(100, 0)}
	main.orbit._reset_touch_gesture()
	var touch := InputEventScreenDrag.new()
	touch.index = 0
	touch.relative = Vector2(0, 20)
	touch.position = Vector2(0, 20)
	var before: float = main.orbit.pitch_target
	main.orbit._unhandled_input(touch)
	main.orbit._update_pinch()
	if main.orbit.pitch_target <= before:
		failures.append("touch vertical drag inverted")
	main._web_closeup(Vector3(-1.1, 3.2, -7.65), 5.0)
	if (main.orbit.position - main.orbit.target).distance_to(Vector3(24, 18, 30)) > 0.001 or absf(main.orbit.zoom - 5.0) > 0.001:
		failures.append("closeup offset or zoom differs from web")
	var foam = world.cascade_fx.foam
	if absf(foam.global_basis.y.normalized().dot(Vector3.UP)) < 0.99:
		failures.append("cascade foam stands vertically")
	if failures.is_empty():
		print("PARITY PASS: animated leg/posed boots, up to 140s schedule/door roundtrip, mouse/touch orbit, web closeup, horizontal foam")
		quit(0)
	else:
		for failure in failures:
			push_error("PARITY FAIL: " + failure)
		quit(1)
