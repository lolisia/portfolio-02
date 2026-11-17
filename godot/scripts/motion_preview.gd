extends Control
class_name MotionPreview

## Port of the three canvas cards in src/motion.js: day/night horizon,
## anemometer and weather. Everything is drawn in the web's 220×94 canvas
## space with the same Bézier paths, colours and stroke widths, then scaled to
## the card like `setTransform(width/220, 0, 0, height/94)`.

const MODE_HORIZON := 0
const MODE_WIND := 1
const MODE_WEATHER := 2
const W := 220.0
const H := 94.0
const DEEP := Color("526d70")
const MID := Color("809995")
const LIGHT := Color("b8c9c3")
const SUN := Color("c5a66d")
const LINE := Color(1, 1, 1, 0x47 / 255.0)
const RADIUS := 9.0

var mode := MODE_HORIZON
var reduced_motion := false
var hour := 8.5
var hour_target := 8.5
var wind := 3.0
var wind_target := 3.0
var weather := 0
var phase := 0.0
var clock := 0.0
var cloud := 0.0
var rain := 0.0
var snow := 0.0
var fog := 0.0
var storm := 0.0
var _scale := Vector2.ONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(230, 98)

func set_time(value: float) -> void:
	hour_target = value

func set_wind(value: float) -> void:
	wind_target = value

func set_weather(index: int) -> void:
	weather = index

func _process(delta: float) -> void:
	# motion.js only animates while the panel is open.
	if not is_visible_in_tree():
		return
	var dt := minf(delta, 0.1)
	var k := 1.0 if reduced_motion else 1.0 - exp(-dt * 5.0)
	hour += (fposmod(hour_target - hour + 36.0, 24.0) - 12.0) * k
	hour = fposmod(hour, 24.0)
	wind += (wind_target - wind) * k
	var cloud_target := 0.0 if weather == 0 else (0.7 if weather == 3 else 1.0)
	cloud += (cloud_target - cloud) * k
	rain += ((1.0 if weather == 2 else 0.0) - rain) * k
	snow += ((1.0 if weather >= 4 else 0.0) - snow) * k
	fog += ((1.0 if weather == 3 else 0.0) - fog) * k
	storm += ((1.0 if weather == 5 else 0.0) - storm) * k
	if not reduced_motion:
		phase += dt * wind * 0.32
		clock += dt
	queue_redraw()

## The card keeps the canvas aspect (CSS aspect-ratio: 220/94).
func _card_rect() -> Rect2:
	var w := size.x
	var h := minf(size.y, w * H / W)
	return Rect2(Vector2(0.0, (size.y - h) * 0.5), Vector2(w, h))

func _draw() -> void:
	var rect := _card_rect()
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return
	_base(rect)
	_scale = Vector2(rect.size.x / W, rect.size.y / H)
	draw_set_transform(rect.position, 0.0, _scale)
	match mode:
		MODE_HORIZON:
			_horizon()
		MODE_WIND:
			_winds()
		MODE_WEATHER:
			_weather(0.0 if reduced_motion else clock)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ primitives

## Card face: rounded rect, '#ffffff1c'→'#ffffff08' diagonal gradient and the
## 1px hairline inset (`box-shadow: inset 0 0 0 1px var(--line)`).
func _base(rect: Rect2) -> void:
	var outline := _rounded(rect, RADIUS)
	var colors := PackedColorArray()
	for p in outline:
		var t := clampf(((p.x - rect.position.x) * W / rect.size.x
			+ (p.y - rect.position.y) * H / rect.size.y) / (W + H), 0.0, 1.0)
		colors.append(Color(1, 1, 1, lerpf(0x1c, 0x08, t) / 255.0))
	draw_polygon(outline, colors)
	var ring := outline.duplicate()
	ring.append(outline[0])
	draw_polyline(ring, LINE, 1.0, true)

func _rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.end - Vector2(r, r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for i in range(7):
			var a: float = float(corner[1]) + PI * 0.5 * float(i) / 6.0
			points.append(Vector2(corner[0]) + Vector2(cos(a), sin(a)) * r)
	return points

## Canvas units -> device pixels: keep strokes and edge feathering crisp.
func _px() -> float:
	return 1.0 / maxf(_scale.x, 0.001)

func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3 or color.a <= 0.002:
		return
	# Canvas fills clip at the bitmap edge; keep Godot polygons simple and
	# clip them explicitly (the lowest hill crosses y=94).
	points = points.duplicate()
	if points[0].distance_squared_to(points[points.size() - 1]) < 0.0001:
		points.remove_at(points.size() - 1)
	var clipped := Geometry2D.intersect_polygons(points, PackedVector2Array([
		Vector2.ZERO, Vector2(W, 0), Vector2(W, H), Vector2(0, H)]))
	for polygon in clipped:
		draw_colored_polygon(polygon, color)
		# Feather clipped edges without drawing outside the card.
		var ring := polygon.duplicate()
		ring.append(polygon[0])
		draw_polyline(ring, Color(color, color.a * 0.5), _px(), true)

func _disc(center: Vector2, radius: float, color: Color) -> void:
	_fill(_ellipse(center, radius, radius), color)

func _ellipse(center: Vector2, rx: float, ry: float, segments: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points

func _stroke(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if color.a <= 0.002:
		return
	draw_line(a, b, color, width, true)
	# lineCap = 'round'
	draw_circle(a, width * 0.5, color, true, -1.0, true)
	draw_circle(b, width * 0.5, color, true, -1.0, true)

func _bezier(points: PackedVector2Array, p1: Vector2, p2: Vector2, p3: Vector2, steps: int = 16) -> void:
	var p0 := points[points.size() - 1]
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		points.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)

func _quadratic(points: PackedVector2Array, p1: Vector2, p2: Vector2, steps: int = 10) -> void:
	var p0 := points[points.size() - 1]
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		points.append(p0 * u * u + p1 * 2.0 * u * t + p2 * t * t)

func _xf(points: PackedVector2Array, origin: Vector2, angle: float = 0.0,
		scale_value: float = 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(origin + (p * scale_value).rotated(angle))
	return out

# ------------------------------------------------------------------ cards

func _land(y: float, color: Color, amplitude: float) -> void:
	var pts := PackedVector2Array([Vector2(0, H + amplitude + 20.0), Vector2(0, y)])
	_bezier(pts, Vector2(42, y - amplitude), Vector2(71, y - amplitude), Vector2(112, y))
	_bezier(pts, Vector2(156, y + amplitude), Vector2(184, y - amplitude), Vector2(220, y - 3))
	pts.append(Vector2(220, H + amplitude + 20.0))
	_fill(pts, color)

func _horizon() -> void:
	var is_day := hour >= 6.0 and hour < 18.0
	var progress := (hour - 6.0) / 12.0 if is_day else fposmod(hour + 6.0, 24.0) / 12.0
	var x := 30.0 + 160.0 * progress
	var y := 62.0 - 34.0 * sin(progress * PI)
	if is_day:
		_disc(Vector2(x, y), 23.0, Color(SUN, 0x16 / 255.0))
		_disc(Vector2(x, y), 16.0, Color(SUN, 0x24 / 255.0))
		_disc(Vector2(x, y), 11.0, SUN)
	else:
		# A filled crescent: arc .28π→1.72π, closed by a Bézier back to the start.
		var moon := PackedVector2Array()
		for i in range(33):
			var a := lerpf(0.28 * PI, 1.72 * PI, float(i) / 32.0)
			moon.append(Vector2(cos(a), sin(a)) * 12.0)
		_bezier(moon, Vector2(-1, -9), Vector2(-2, 6), Vector2(7.65, 9.25))
		_fill(_xf(moon, Vector2(x, y)), DEEP)
	_land(72.0, Color("b1c4bba6"), 18.0)
	_land(82.0, Color("7e9993b8"), 12.0)
	_land(93.0, Color("526d707d"), 8.0)

func _winds() -> void:
	_fill(_ellipse(Vector2(110, 80), 30, 5), Color("80999544"))
	_stroke(Vector2(110, 77), Vector2(110, 36), DEEP, 5.0)
	var cups: Array = []
	for i in range(3):
		var a := phase * 1.8 + float(i) * TAU / 3.0
		cups.append({"x": 110.0 + 43.0 * cos(a), "y": 35.0 + 13.0 * sin(a), "a": a})
	cups.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["y"]) < float(q["y"]))
	var bowl := PackedVector2Array([Vector2(-11, -4), Vector2(11, -4)])
	_bezier(bowl, Vector2(12, 12), Vector2(-12, 12), Vector2(-11, -4))
	var rim := _ellipse(Vector2(0, -4), 11, 4)
	for cup in cups:
		var at := Vector2(float(cup["x"]), float(cup["y"]))
		_stroke(Vector2(110, 35), at, MID, 4.5)
		var turn := cos(float(cup["a"])) * 0.2
		_fill(_xf(bowl, at, turn), MID if at.y < 35.0 else DEEP)
		_fill(_xf(rim, at, turn), LIGHT)
	_disc(Vector2(110, 35), 6.0, SUN)

func _cloud_shape(at: Vector2, scale_value: float, color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-37, 12)])
	_bezier(pts, Vector2(-57, 12), Vector2(-56, -12), Vector2(-37, -13))
	_bezier(pts, Vector2(-32, -37), Vector2(1, -40), Vector2(12, -17))
	_bezier(pts, Vector2(35, -25), Vector2(53, -9), Vector2(44, 6))
	_quadratic(pts, Vector2(41, 15), Vector2(28, 15))
	_fill(_xf(pts, at, 0.0, scale_value), color)

func _weather(t: float) -> void:
	var sx := 110.0 - cloud * 27.0
	var sy := 40.0 - cloud * 11.0
	var sun_alpha := 1.0 - cloud * 0.3
	_disc(Vector2(sx, sy), 25.0, Color(SUN, 0x18 / 255.0 * sun_alpha))
	_disc(Vector2(sx, sy), 16.0, Color(SUN, sun_alpha))
	if cloud > 0.002:
		var drift := sin(t * 0.35) * 3.0
		_cloud_shape(Vector2(133.0 + drift, 42.0), 0.77, Color(Color("9fb5af"), cloud))
		_cloud_shape(Vector2(106.0 + drift, 44.0), 0.8, Color(Color("dce5df"), cloud))
	var power := rain + snow
	var ice := snow / maxf(0.001, power)
	if power > 0.002:
		for i in range(10):
			var f := fposmod(t * (0.65 - 0.4 * ice + storm * 0.5) + float(i) * 0.618, 1.0)
			var x := 80.0 + float((i * 31) % 65) - f * (5.0 + storm * 21.0) + ice * sin(t + float(i)) * 3.0
			var y := 60.0 + f * 27.0
			var alpha := power * minf(1.0, minf(f * 7.0, (1.0 - f) * 5.0)) * 0.85
			if ice > 0.5:
				_disc(Vector2(x, y), 2.4, Color(DEEP, alpha))
			else:
				_stroke(Vector2(x, y), Vector2(x - 2.2, y + 5.0), Color(DEEP, alpha), 3.2)
	if fog > 0.002:
		for i in range(3):
			var offset := sin(t * 0.35 + float(i)) * 6.0
			var y2 := 62.0 + float(i) * 10.0
			_stroke(Vector2(60.0 + offset + float(i) * 7.0, y2),
				Vector2(160.0 + offset - float(i) * 9.0, y2),
				Color(MID if i == 1 else LIGHT, fog * (0.7 - float(i) * 0.12)), 5.0)
