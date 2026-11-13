extends Camera3D

## Orthographic orbit camera matching the web diorama:
## left-drag orbits, wheel/pinch zooms, touch drag orbits.
@export var target := Vector3(0.0, 1.0, 0.0)
@export var distance := 59.6
@export var min_pitch := 0.3908
@export var max_pitch := 1.2208
@export var min_zoom := 0.70
@export var max_zoom := 3.30
@export var base_span := 31.5
@export var rotate_speed := 1.0
@export var zoom_step := 1.0526

var yaw := 0.0
var pitch := 0.0
var zoom := 1.0
var home_yaw := 0.0
var home_pitch := 0.0
var home_zoom := 1.0
var portrait_scale := 1.0

var _dragging := false
var _drag_button := 0
var _touch_points := {}
var _pinch_distance := 0.0

func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_HEIGHT
	near = 0.1
	far = 220.0
	var offset := position - target
	distance = maxf(offset.length(), 1.0)
	yaw = atan2(offset.x, offset.z)
	pitch = asin(clampf(offset.y / distance, -1.0, 1.0))
	home_yaw = yaw
	home_pitch = pitch
	home_zoom = zoom
	_apply()
	get_viewport().size_changed.connect(_apply)

func _apply() -> void:
	pitch = clampf(pitch, min_pitch, max_pitch)
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_drag_button = mb.button_index
			if mb.pressed:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= zoom_step
			_apply()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom /= zoom_step
			_apply()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var rotate_unit := TAU / maxf(get_viewport().get_visible_rect().size.y, 1.0)
		yaw -= motion.relative.x * rotate_unit * rotate_speed
		pitch -= motion.relative.y * rotate_unit * rotate_speed
		_apply()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
		else:
			_touch_points.erase(touch.index)
		_update_pinch()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_points[drag.index] = drag.position
		if _touch_points.size() == 1:
			var rotate_unit := TAU / maxf(get_viewport().get_visible_rect().size.y, 1.0)
			yaw -= drag.relative.x * rotate_unit * rotate_speed
			pitch -= drag.relative.y * rotate_unit * rotate_speed
			_apply()
		elif _touch_points.size() >= 2:
			_update_pinch()

func _update_pinch() -> void:
	var points := _touch_points.values()
	if points.size() < 2:
		_pinch_distance = 0.0
		return
	var d: float = points[0].distance_to(points[1])
	if _pinch_distance > 0.0 and d > 0.0:
		zoom *= d / _pinch_distance
		_apply()
	_pinch_distance = d

func reset_view() -> void:
	yaw = home_yaw
	pitch = home_pitch
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
	zoom = new_zoom
	_apply()
