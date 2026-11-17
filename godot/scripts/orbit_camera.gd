extends Camera3D

## Orthographic orbit camera matching the web diorama:
## Left drag / one finger pans on XZ. Right drag / two fingers orbits.
## Wheel / finger separation zooms toward the pointer / gesture centre.
@export var target := Vector3(0.0, 1.0, 0.0)
@export var distance := 59.6
@export var min_pitch := 0.3908
@export var max_pitch := 1.2208
@export var min_zoom := 0.70
@export var max_zoom := 12.0
@export var base_span := 31.5
@export var rotate_speed := 1.0
@export var zoom_step := 1.0526

var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var yaw_target := 0.0
var pitch_target := 0.0
var home_yaw := 0.0
var home_pitch := 0.0
var home_zoom := 1.0
var home_target := Vector3.ZERO
var portrait_scale := 1.0

var _dragging := false
var _drag_button := 0
var _touch_points := {}
var _pinch_distance := 0.0
var _gesture_center := Vector2.ZERO
var _touch_dirty := false
var _mouse_buttons := 0

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 0.1
	far = 220.0
	var offset := position - target
	distance = maxf(offset.length(), 1.0)
	yaw = atan2(offset.x, offset.z)
	pitch = asin(clampf(offset.y / distance, -1.0, 1.0))
	yaw_target = yaw
	pitch_target = pitch
	home_yaw = yaw
	home_pitch = pitch
	home_zoom = zoom
	home_target = target
	_apply()
	get_viewport().size_changed.connect(_apply)

func _process(delta: float) -> void:
	if _touch_dirty:
		_update_pinch()
	# C4: OrbitControls.enableDamping. Rotation eases toward the drag target
	# with the web's dampingFactor approximation; zoom stays immediate.
	var k := 1.0 - exp(-delta * 3.0)
	if absf(yaw_target - yaw) > 0.00005:
		yaw = lerp_angle(yaw, yaw_target, k)
		_apply()
	if absf(pitch_target - pitch) > 0.00005:
		pitch = lerpf(pitch, pitch_target, k)
		_apply()

func _apply() -> void:
	pitch = clampf(pitch, min_pitch, max_pitch)
	pitch_target = clampf(pitch_target, min_pitch, max_pitch)
	zoom = clampf(zoom, min_zoom, max_zoom)
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var span := maxf(base_span, 46.0 / maxf(aspect, 0.01))
	size = span / zoom * portrait_scale
	var cp := cos(pitch)
	var sp := sin(pitch)
	var offset := Vector3(distance * cp * sin(yaw), distance * sp, distance * cp * cos(yaw))
	position = target + offset
	look_at(target, Vector3.UP)

func _input(event: InputEvent) -> void:
	# Releases must also clear gestures when they land over the settings UI.
	# Initial presses still go through _unhandled_input so UI owns its touches.
	if event is InputEventMouseButton and not event.pressed:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_release_mouse(event.button_index)
	elif event is InputEventScreenTouch and not event.pressed:
		if _touch_points.has(event.index):
			_touch_points.erase(event.index)
			_reset_touch_gesture()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_mouse_buttons = 0
		_dragging = false
		_drag_button = 0
		_touch_points.clear()
		_reset_touch_gesture()
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _release_mouse(button: int) -> void:
	if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
		_mouse_buttons &= ~(1 << button)
		_sync_mouse_mode()

func _sync_mouse_mode() -> void:
	_drag_button = MOUSE_BUTTON_RIGHT if _mouse_buttons & (1 << MOUSE_BUTTON_RIGHT) else (MOUSE_BUTTON_LEFT if _mouse_buttons & (1 << MOUSE_BUTTON_LEFT) else 0)
	_dragging = _drag_button != 0
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if _dragging else Input.CURSOR_POINTING_HAND)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_mouse_buttons |= 1 << mb.button_index
				_sync_mouse_mode()
			else:
				_release_mouse(mb.button_index)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, zoom_step)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / zoom_step)
	elif event is InputEventMouseMotion and _dragging:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var motion := event as InputEventMouseMotion
		if _drag_button == MOUSE_BUTTON_RIGHT:
			_orbit_by(motion.relative)
		else:
			_pan_between(motion.position - motion.relative, motion.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
		else:
			_touch_points.erase(touch.index)
		_reset_touch_gesture()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touch_points.has(drag.index):
			return
		var previous: Vector2 = _touch_points[drag.index]
		_touch_points[drag.index] = drag.position
		if _touch_points.size() == 1:
			_pan_between(previous, drag.position)
		else:
			# Coalesce per-finger events into one gesture per frame. A symmetric
			# pinch must not briefly rotate as each finger's event arrives.
			_touch_dirty = true

func _orbit_by(relative: Vector2) -> void:
	var unit := TAU / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	yaw_target -= relative.x * unit * rotate_speed
	pitch_target = clampf(pitch_target + relative.y * unit * rotate_speed, min_pitch, max_pitch)

func _pan_between(from: Vector2, to: Vector2) -> void:
	var before = _screen_ground_point(from)
	var after = _screen_ground_point(to)
	if before != null and after != null:
		var offset: Vector3 = before - after
		offset.y = 0.0
		target += offset
		_apply()

func _reset_touch_gesture() -> void:
	_touch_dirty = false
	_pinch_distance = 0.0
	if _touch_points.size() >= 2:
		var points := _touch_points.values()
		_gesture_center = (points[0] + points[1]) * 0.5
		_pinch_distance = points[0].distance_to(points[1])

func _screen_ground_point(screen_pos: Vector2):
	# C5: three's zoomToCursor keeps the ground point under the cursor fixed.
	var origin := project_ray_origin(screen_pos)
	var direction := project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, target.y)
	return plane.intersects_ray(origin, direction)

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before = _screen_ground_point(screen_pos)
	zoom = clampf(zoom * factor, min_zoom, max_zoom)
	_apply()
	var after = _screen_ground_point(screen_pos)
	if before != null and after != null:
		target += (before as Vector3) - (after as Vector3)
		_apply()

func _update_pinch() -> void:
	_touch_dirty = false
	var points := _touch_points.values()
	if points.size() < 2:
		_reset_touch_gesture()
		return
	var center: Vector2 = (points[0] + points[1]) * 0.5
	var d: float = points[0].distance_to(points[1])
	_orbit_by(center - _gesture_center)
	if _pinch_distance > 0.001 and d > 0.001:
		_zoom_at(center, d / _pinch_distance)
	_gesture_center = center
	_pinch_distance = d

func reset_view() -> void:
	target = home_target
	yaw = home_yaw
	pitch = home_pitch
	yaw_target = home_yaw
	pitch_target = home_pitch
	zoom = home_zoom
	_apply()

func set_zoom_target(value: float) -> void:
	zoom = value
	_apply()

func set_portrait_scale(value: float) -> void:
	if absf(portrait_scale - value) < 0.0005:
		return
	portrait_scale = value
	_apply()

func set_view(new_target: Vector3, new_yaw: float, new_pitch: float, new_zoom: float) -> void:
	target = new_target
	yaw = new_yaw
	pitch = new_pitch
	yaw_target = new_yaw
	pitch_target = new_pitch
	zoom = new_zoom
	_apply()
