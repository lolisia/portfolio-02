extends RefCounted
class_name Daylight

## Faithful port of src/daylight.js.
## Palette slots: 0 day, 1 noon, 2 dawn, 3 night, 4 dusk.

const KEYS := [
	[0.0, 3],
	[5.0, 3],
	[6.3, 2],
	[8.4, 0],
	[12.5, 1],
	[16.0, 0],
	[18.25, 4],
	[20.0, 3],
	[24.0, 3],
]

const SUN = [Color("ffeed4"), Color("fff5df"), Color("ffb48c"), Color("ffb887"), Color("ff8b4a")]
const SKY = [Color("e8f3fc"), Color("f3fbff"), Color("bab3ea"), Color("97aed6"), Color("8e88d4")]
const SKY_TOP = [Color("578db7"), Color("518ac3"), Color("7677a8"), Color("131f37"), Color("4f4a8c")]
const SKY_HORIZON = [Color("ffdcaa"), Color("dbedf1"), Color("ffae94"), Color("34445b"), Color("ff7f3c")]
const SKY_LAND = [Color("697153"), Color("737962"), Color("766552"), Color("161e21"), Color("766552")]
const BACKDROP = [Color("acbfca"), Color("93b9d4"), Color("d8aaa6"), Color("17263f"), Color("d48b6c")]
const FOG_SCATTER = [Color("657577"), Color("768183"), Color("957a8c"), Color("192d45"), Color("8d5a44")]

static func smooth01(n: float) -> float:
	n = clampf(n, 0.0, 1.0)
	return n * n * (3.0 - 2.0 * n)

static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func slot(list: Array, index: int) -> Color:
	if index < list.size():
		return list[index]
	return list[2] if list.size() > 2 else Color.WHITE

static func color_at(list: Array, from_index: int, to_index: int, f: float) -> Color:
	return slot(list, from_index).lerp(slot(list, to_index), f)

static func evaluate(hour: float) -> Dictionary:
	hour = fposmod(hour, 24.0)
	var end_index := 1
	for i in range(1, KEYS.size()):
		if KEYS[i][0] >= hour:
			end_index = i
			break
	var a: Array = KEYS[end_index - 1]
	var b: Array = KEYS[end_index]
	var from_index: int = a[1]
	var to_index: int = b[1]
	var f := smoothstep(a[0], b[0], hour)
	var theta := (hour - 6.0) * PI / 12.0
	var direction := Vector3(-cos(theta), sin(theta) * 0.90, -sin(theta) * 0.48)
	direction = direction.rotated(Vector3.UP, -0.20).normalized()
	var night := 1.0 - smoothstep(-0.18, 0.17, direction.y)
	var golden := exp(-pow((direction.y - 0.05) / 0.15, 2.0))
	return {
		"hour": hour,
		"from": from_index,
		"to": to_index,
		"f": f,
		"direction": direction,
		"night": night,
		"golden": golden,
		"dawn": hour < 12.0,
	}

static func sun_color(t: Dictionary) -> Color:
	return color_at(SUN, t.from, t.to, t.f)
