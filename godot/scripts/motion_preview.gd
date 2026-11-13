extends Control
class_name MotionPreview

## Port of the three canvas cards in src/motion.js: day/night horizon,
## anemometer and weather. Drawn with Control primitives so it scales with the
## responsive panel.

const MODE_HORIZON := 0
const MODE_WIND := 1
const MODE_WEATHER := 2
const DEEP := Color(0.32, 0.43, 0.44)
const MID := Color(0.50, 0.60, 0.58)
const LIGHT := Color(0.72, 0.79, 0.76)
const SUN := Color(0.77, 0.65, 0.43)

var mode := MODE_HORIZON
var reduced_motion := false
var hour := 8.5
var hour_target := 8.5
var wind := 3.0
var wind_target := 3.0
var weather := 0
var phase := 0.0
var cloud := 0.0
var rain := 0.0
var snow := 0.0
var fog := 0.0
var storm := 0.0
var _style: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(110, 58)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(1, 1, 1, 0.045)
	_style.set_corner_radius_all(8)
	_style.border_color = Color(1, 1, 1, 0.06)
	_style.set_border_width_all(1)

func set_time(value: float) -> void:
	hour_target = value

func set_wind(value: float) -> void:
	wind_target = value

func set_weather(index: int) -> void:
	weather = index

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var k := 1.0 if reduced_motion else 1.0 - exp(-delta * 5.0)
	var diff := fposmod(hour_target - hour + 12.0, 24.0) - 12.0
	hour = fposmod(hour + diff * k, 24.0)
	wind = lerpf(wind, wind_target, k)
	var cloud_target := 0.0 if weather == 0 else (0.7 if weather == 3 else 1.0)
	cloud = lerpf(cloud, cloud_target, k)
	rain = lerpf(rain, 1.0 if weather == 2 else 0.0, k)
	snow = lerpf(snow, 1.0 if weather >= 4 else 0.0, k)
	fog = lerpf(fog, 1.0 if weather == 3 else 0.0, k)
	storm = lerpf(storm, 1.0 if weather == 5 else 0.0, k)
	if not reduced_motion:
		phase += delta * wind * 0.32
	queue_redraw()

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	if _style != null:
		draw_style_box(_style, Rect2(Vector2.ZERO, size))
	match mode:
		MODE_HORIZON:
			_draw_horizon()
		MODE_WIND:
			_draw_wind()
		MODE_WEATHER:
			_draw_weather()

func _draw_horizon() -> void:
	var w := size.x
	var h := size.y
	var is_day := hour >= 6.0 and hour < 18.0
	var progress := ((hour - 6.0) / 12.0) if is_day else (fposmod(hour + 6.0, 24.0) / 12.0)
	var sx := w * (0.18 + 0.64 * progress)
	var sy := h * (0.66 - 0.32 * sin(progress * PI))
	if is_day:
		draw_circle(Vector2(sx, sy), minf(w, h) * 0.24, Color(SUN, 0.09))
		draw_circle(Vector2(sx, sy), minf(w, h) * 0.17, Color(SUN, 0.16))
		draw_circle(Vector2(sx, sy), minf(w, h) * 0.11, SUN)
	else:
		var r := minf(w, h) * 0.12
		draw_circle(Vector2(sx, sy), r, DEEP)
		draw_circle(Vector2(sx + r * 0.45, sy - r * 0.22), r * 0.92,
			Color(0.055, 0.095, 0.115, 0.92))
	_land(w, h, 0.68, 0.14, Color(0.69, 0.77, 0.73, 0.65))
	_land(w, h, 0.79, 0.09, Color(0.49, 0.60, 0.58, 0.72))
	_land(w, h, 0.90, 0.055, Color(0.32, 0.43, 0.44, 0.85))

func _land(w: float, h: float, base: float, amplitude: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(0, h))
	for i in range(41):
		var t := float(i) / 40.0
		var y := h * base + sin(t * PI * 2.0 + base * 9.0) * h * amplitude * (0.6 + 0.4 * sin(t * 5.0))
		points.append(Vector2(t * w, y))
	points.append(Vector2(w, h))
	draw_colored_polygon(points, color)

func _draw_wind() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var hub := Vector2(cx, h * 0.34)
	draw_circle(Vector2(cx, h * 0.80), w * 0.13, Color(0.50, 0.60, 0.58, 0.20))
	draw_line(Vector2(cx, h * 0.80), hub, DEEP, maxf(2.0, w * 0.018), true)
	var cups: Array = []
	var t := 0.0 if reduced_motion else phase
	for i in range(3):
		var angle := t * 1.8 + float(i) * TAU / 3.0
		cups.append({
			"x": cx + w * 0.34 * cos(angle),
			"y": hub.y + h * 0.13 * sin(angle),
			"back": sin(angle) < 0.0,
		})
	cups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return bool(a["back"]) and not bool(b["back"]))
	for cup in cups:
		var p := Vector2(float(cup["x"]), float(cup["y"]))
		draw_line(hub, p, MID, maxf(1.5, w * 0.015), true)
		draw_circle(p, maxf(2.4, w * 0.042), Color(0.55, 0.64, 0.62) if bool(cup["back"]) else DEEP)
		draw_circle(p + Vector2(-1, -1), maxf(1.2, w * 0.022), Color(0.72, 0.79, 0.76, 0.9))
	draw_circle(hub, maxf(2.0, w * 0.032), SUN)

func _draw_weather() -> void:
	var w := size.x
	var h := size.y
	var t := 0.0 if reduced_motion else phase
	var sun_pos := Vector2(w * (0.40 - cloud * 0.16), h * (0.40 - cloud * 0.08))
	draw_circle(sun_pos, minf(w, h) * 0.26, Color(SUN, 0.10 * (1.0 - cloud * 0.3)))
	draw_circle(sun_pos, minf(w, h) * 0.16, Color(SUN, (1.0 - cloud * 0.45)))
	if cloud > 0.01:
		var drift := sin(t * 0.35) * w * 0.02
		_draw_cloud(Vector2(w * 0.54 + drift, h * 0.44), w * 0.032, Color(0.62, 0.71, 0.69, 0.55 * cloud))
		_draw_cloud(Vector2(w * 0.67 + drift, h * 0.38), w * 0.040, Color(0.80, 0.86, 0.84, 0.70 * cloud))
	var power := rain + snow
	var ice := snow / maxf(power, 0.001)
	if power > 0.01:
		for i in range(10):
			var f := fposmod(t * (0.65 - 0.4 * ice + storm * 0.5) + float(i) * 0.618, 1.0)
			var x := w * 0.30 + fposmod(float(i) * 31.0, 65.0) / 220.0 * w - f * (5.0 + storm * 21.0) * w / 220.0
			var y := h * 0.62 + f * h * 0.28
			var alpha := power * minf(1.0, minf(f * 7.0, (1.0 - f) * 5.0)) * 0.8
			if ice > 0.5:
				draw_circle(Vector2(x, y), maxf(1.2, w * 0.012), Color(DEEP, alpha))
			else:
				draw_line(Vector2(x, y), Vector2(x - w * 0.008, y + h * 0.06), Color(DEEP, alpha), 1.4, true)
	if fog > 0.01:
		for i in range(3):
			var alpha2 := fog * (0.7 - i * 0.12)
			var offset := sin(t * 0.35 + i) * w * 0.03
			draw_line(Vector2(w * 0.26 + offset + i * w * 0.03, h * (0.66 + i * 0.09)),
				Vector2(w * 0.74 + offset - i * w * 0.04, h * (0.66 + i * 0.09)),
				Color(LIGHT, alpha2), 3.0, true)

func _draw_cloud(center: Vector2, scale_factor: float, color: Color) -> void:
	draw_circle(center + Vector2(-scale_factor * 1.6, 0), scale_factor * 1.0, color)
	draw_circle(center + Vector2(0, -scale_factor * 0.5), scale_factor * 1.25, color)
	draw_circle(center + Vector2(scale_factor * 1.7, 0.1), scale_factor * 0.95, color)
	draw_rect(Rect2(center + Vector2(-scale_factor * 1.7, 0), Vector2(scale_factor * 3.4, scale_factor * 0.8)), color)
