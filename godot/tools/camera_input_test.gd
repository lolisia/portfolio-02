extends SceneTree

var camera: Camera3D
var failures: Array[String] = []
const START := Vector2(600, 340)
const MOVE := Vector2(40, 20)

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	camera = load("res://scripts/orbit_camera.gd").new()
	camera.position = Vector3(31, 34, 41)
	root.add_child(camera)
	await process_frame
	reset()
	button(MOUSE_BUTTON_LEFT, true)
	mouse_drag()
	var mouse_pan: Vector3 = camera.target
	check(mouse_pan.distance_to(Vector3(0, 1, 0)) > 0.1, "left drag did not pan")
	check(absf(mouse_pan.y - 1.0) < 0.0001 and is_equal_approx(camera.yaw_target, 0.4), "pan changed height or rotation")
	# Releasing over a UI control still ends the gesture via _input.
	button(MOUSE_BUTTON_LEFT, false, true)
	check(not camera._dragging, "release over UI left drag active")
	reset()
	touch(0, START)
	finger_drag(0, START + MOVE)
	check(camera.target.distance_to(mouse_pan) < 0.0001, "mouse/finger pan differ")
	touch(0, START + MOVE, false)
	reset()
	button(MOUSE_BUTTON_RIGHT, true)
	mouse_drag()
	var mouse_yaw: float = camera.yaw_target
	var mouse_pitch: float = camera.pitch_target
	check(mouse_yaw < 0.4 and mouse_pitch > 0.8, "right drag did not orbit")
	check(camera.target.distance_to(Vector3(0, 1, 0)) < 0.0001, "right drag panned")
	button(MOUSE_BUTTON_RIGHT, false)
	reset()
	touch(0, START - Vector2(100, 0))
	touch(1, START + Vector2(100, 0))
	finger_drag(0, START - Vector2(100, 0) + MOVE)
	finger_drag(1, START + Vector2(100, 0) + MOVE)
	camera._update_pinch()
	check(is_equal_approx(camera.yaw_target, mouse_yaw) and is_equal_approx(camera.pitch_target, mouse_pitch), "mouse/two-finger orbit differ")
	check(is_equal_approx(camera.zoom, 1.0), "parallel two-finger drag zoomed")
	reset()
	touch(0, START - Vector2(100, 0))
	touch(1, START + Vector2(100, 0))
	var anchor = camera._screen_ground_point(START)
	finger_drag(0, START - Vector2(125, 0))
	finger_drag(1, START + Vector2(125, 0))
	camera._update_pinch()
	check(is_equal_approx(camera.zoom, 1.25), "pinch zoom ratio wrong")
	check(is_equal_approx(camera.yaw_target, 0.4) and is_equal_approx(camera.pitch_target, 0.8), "symmetric pinch rotated")
	check(anchor.distance_to(camera._screen_ground_point(START)) < 0.0001, "pinch moved its ground anchor")
	# Transition to one finger must start from its latest position, without a jump.
	touch(1, START + Vector2(125, 0), false)
	var previous_target: Vector3 = camera.target
	finger_drag(0, START - Vector2(125, 0))
	check(previous_target.distance_to(camera.target) < 0.0001, "two-to-one transition jumped")
	camera._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(camera._touch_points.is_empty() and not camera._dragging, "focus loss did not reset input")
	camera.reset_view()
	check(camera.target.distance_to(camera.home_target) < 0.0001, "reset did not restore pan")
	if failures.is_empty():
		print("CAMERA PASS: mouse/touch pan and orbit parity, centred pinch, UI release, finger transition, focus loss, reset")
		quit(0)
	else:
		for failure in failures:
			push_error("CAMERA FAIL: " + failure)
		quit(1)

func reset() -> void:
	camera._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	camera.set_view(Vector3(0, 1, 0), 0.4, 0.8, 1.0)

func button(index: int, pressed: bool, over_ui := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	if over_ui:
		camera._input(event)
	else:
		camera._unhandled_input(event)

func mouse_drag() -> void:
	var event := InputEventMouseMotion.new()
	event.relative = MOVE
	event.position = START + MOVE
	camera._unhandled_input(event)

func touch(index: int, at: Vector2, pressed := true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	camera._unhandled_input(event)

func finger_drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	camera._unhandled_input(event)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
