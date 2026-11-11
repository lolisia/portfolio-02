extends Node3D
class_name FarmWorld

## Port of src/world.js. Builds the 30x30 tile diorama terrain, pond,
## cottage, coop, shed, garden, paths, vegetation and lanterns.

const NatureAssets = preload("res://scripts/nature_assets.gd")
const DioramaBuilder = preload("res://scripts/builder.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")

const WATER_Y := 0.44
const FLOOR_Y := -2.48
const COTTAGE := {
	"W": 3.3, "D": 3.0, "F": 0.45, "H": 1.6, "knee": 0.5, "P": 1.15,
	"B": 1.0, "BW": 2.4, "slope": 0.8, "over": 0.38, "E": 2.32, "run": 0.3,
	"chimney": Vector2(0.85, -0.6),
}

var b: DioramaBuilder
var meshes: Dictionary = {}
var ground: MeshInstance3D
var terrain_material: ShaderMaterial
var path_mask: ImageTexture
var water: MeshInstance3D
var lamps: Array = []
var window_light: OmniLight3D
var lamp_glass_material: StandardMaterial3D
var cottage_window := Vector3.ZERO
var obstacles: Array = []
var path_points: Array[Vector2] = []
var flight := {
	"ax": -4.72, "az": -3.0, "bx": -5.02, "bz": -6.75,
}
var flight_y0 := 0.0
var flight_y1 := 0.0

const TREE_LIST := [
	[-13.0, -12.0, 1.40], [-10.8, -13.9, 1.02], [-9.0, -12.1, 1.22],
	[-5.0, -13.5, 1.26], [-1.8, -13.0, 1.28], [2.0, -13.6, 1.45],
	[5.6, -12.1, 1.12], [9.5, -12.8, 1.35], [12.5, -10.0, 1.45],
	[-13.0, -8.7, 1.18], [-11.0, -6.4, 1.25], [-13.0, -3.8, 1.52],
	[-12.0, 0.2, 1.13], [-13.4, 3.7, 1.21], [-11.8, 7.2, 1.28],
	[-13.0, 11.4, 1.35], [-8.9, 12.7, 1.27], [-5.0, 13.1, 1.36],
	[-1.4, 12.1, 1.05], [3.1, 13.2, 1.24], [7.4, 12.7, 1.13],
	[12.1, 11.8, 1.25], [12.2, 0.1, 1.28], [10.5, -3.5, 1.16],
	[12.5, -5.6, 1.10], [-6.1, 1.8, 0.76], [-3.95, 2.0, 0.69],
	[-8.5, 6.2, 0.83], [6.1, -8.2, 0.88], [0.4, -9.8, 1.08],
	[-9.0, -2.7, 0.77],
]
const PINE_INDICES := [3, 6, 12, 24, 29]
const GREENS_LIGHT := ["#8fa553", "#9cb35c", "#a9b660", "#88a14f"]
const GREENS_DARK := ["#7d9447", "#8ba14a", "#90a451", "#76903f"]
const BARK_COLORS := ["#55412b", "#655034", "#493c2d"]
const TIMBER := ["#9c6a44", "#a9764b", "#8d5d3c", "#b27e54", "#a06c46", "#956540"]
const SHAKES := ["#7b5a43", "#6d4e3a", "#866550", "#5f4434", "#8a6a52", "#735240", "#6a5342"]
const TURF_GREENS := ["#536e37", "#718a40", "#98aa58", "#899d4c", "#647f3b"]

func build() -> void:
	meshes = NatureAssets.load_meshes()
	b = DioramaBuilder.new(self, meshes, 41573)
	_flight_setup()
	_build_terrain()
	_build_water()
	_build_bridge()
	_build_cascade()
	_build_perimeter()
	_build_cottage(-1.0, -2.5, 0.0)
	_build_coop(2.25, -1.92, 0.025)
	_build_shed(4.45, -1.90, -0.035)
	_build_garden_beds()
	_build_paths()
	_build_path_mask()
	_build_trees()
	_build_ground_cover()
	_build_lamps()
	b.finish()
	_build_extra_lights()
	_collect_materials()

func _flight_setup() -> void:
	var ax: float = flight.ax
	var az: float = flight.az
	var bx: float = flight.bx
	var bz: float = flight.bz
	var length := sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
	flight["len"] = length
	flight["ux"] = (bx - ax) / length
	flight["uz"] = (bz - az) / length
	flight_y0 = natural(ax, az)
	flight_y1 = natural(bx, bz)

func smooth01(n: float) -> float:
	n = clampf(n, 0.0, 1.0)
	return n * n * (3.0 - 2.0 * n)

func pond(x: float, z: float) -> float:
	return 1.0 - pow((x - 10.7) / 4.5, 2.0) - pow((z - 6.3) / 3.5, 2.0) + 0.11 * sin(z * 2.0 + x * 0.4)

func outlet(x: float, z: float) -> float:
	return minf((x - 11.0) * 0.9, 1.0 - absf(z - 6.1) / 1.38)

func wet(x: float, z: float) -> float:
	return maxf(pond(x, z), outlet(x, z))

func natural(x: float, z: float) -> float:
	var terrace := smooth01((-z - 4.0 + 0.7 * sin(x * 0.57) + 0.33 * cos(x * 1.17)) / 2.05)
	return 1.05 + terrace * 1.85 + 0.105 * sin(x * 0.63 + z * 0.48) + 0.08 * cos(z * 0.91) - 1.12 * smooth01((wet(x, z) + 0.19) * 2.9)

func height(x: float, z: float) -> float:
	var ground_y := natural(x, z)
	var ax: float = flight.ax
	var az: float = flight.az
	var dx := x - ax
	var dz := z - az
	var along: float = dx * float(flight.ux) + dz * float(flight.uz)
	var across := absf(dx * float(flight.uz) - dz * float(flight.ux))
	var reach := (1.0 - smooth01((across - 0.66) / 0.62)) * (1.0 - smooth01((-along) / 0.35)) * (1.0 - smooth01((along - float(flight.len)) / 0.35))
	if reach <= 0.0:
		return ground_y
	return ground_y + (flight_y0 + (flight_y1 - flight_y0) * clampf(along / flight.len, 0.0, 1.0) - ground_y) * reach

func stand(x: float, z: float) -> float:
	return height(x, z)

func is_free(x: float, z: float, pad: float = 0.0) -> bool:
	for obstacle in obstacles:
		var ox: float = obstacle[0]
		var oz: float = obstacle[1]
		var radius: float = obstacle[2]
		if pow(x - ox, 2.0) + pow(z - oz, 2.0) <= pow(radius + pad, 2.0):
			return false
	return true

func near_path(x: float, z: float) -> bool:
	for p in path_points:
		if pow(x - p.x, 2.0) + pow(z - p.y, 2.0) < 0.42 * 0.42:
			return true
	return false

func clear(x: float, z: float) -> bool:
	return is_free(x, z, 0.16) and wet(x, z) < -0.13 and not near_path(x, z)

func _terrain_color(x: float, z: float, y: float) -> Color:
	var n := 0.5 + 0.25 * sin(x * 1.4 + sin(z)) + 0.25 * cos(z * 0.94 + x * 0.55)
	var base := Color(0.20, 0.29, 0.13).lerp(Color(0.40, 0.48, 0.20), clampf(n, 0.0, 1.0))
	if wet(x, z) > -0.13:
		base = base.lerp(Color(0.52, 0.48, 0.32), 0.68)
	if y < WATER_Y - 0.05:
		base = base.lerp(Color(0.10, 0.14, 0.09), 0.62)
	if maxf(absf(x), absf(z)) > 14.55:
		base = base.lerp(Color(0.30, 0.22, 0.14), 0.72)
	return base.srgb_to_linear()

func _build_terrain() -> void:
	var n := 120
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(n + 1):
		for i in range(n + 1):
			var x := -15.0 + 30.0 * float(i) / float(n)
			var z := -15.0 + 30.0 * float(j) / float(n)
			var y := height(x, z)
			st.set_color(_terrain_color(x, z, y))
			st.set_uv(Vector2(x * 0.1, z * 0.1))
			st.add_vertex(Vector3(x, y, z))
	for j in range(n):
		for i in range(n):
			var a := j * (n + 1) + i
			var c := a + n + 1
			var b_ := a + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b_)
			st.add_index(c)
			st.add_index(b_)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://shaders/terrain.gdshader")
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = terrain_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 9.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	water = MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = plane
	water.position = Vector3(10.0, WATER_Y, 6.1)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_bridge() -> void:
	b.place(13.7, WATER_Y + 0.48, 6.1, 1.0, 0.0, func() -> void:
		var length := 3.9
		for i in range(int(ceil(length / 0.22))):
			b.part("wood", 0.0, 0.1, -length * 0.5 + i * 0.22,
				1.23, 0.14, 0.205, b.pick(TIMBER))
		for side in [-1.0, 1.0]:
			for i in range(5):
				b.part("wood", float(side) * 0.57, 0.25, -length * 0.5 + i * length / 4.0,
					0.10, 1.1, 0.11, "#70523a")
			for y in [0.43, 0.74]:
				b.part("wood", float(side) * 0.57, y, 0.0,
					0.08, 0.085, length + 0.1, "#a77c50")
	)

func _build_cascade() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.1, 2.95)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/waterfall.gdshader")
	var falls := MeshInstance3D.new()
	falls.name = "Cascade"
	falls.mesh = plane
	falls.position = Vector3(15.18, (WATER_Y + FLOOR_Y) * 0.5 - 0.05, 6.1)
	falls.rotation.y = PI * 0.5
	falls.material_override = mat
	falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(falls)

func _build_perimeter() -> void:
	var top := 3.1
	var mid := (top + FLOOR_Y) * 0.5
	var h := top - FLOOR_Y
	b.part("stone", 0.0, mid, 15.08, 30.6, h, 0.32, "#4b5354")
	b.part("stone", 0.0, mid, -15.08, 30.6, h, 0.32, "#454d4f")
	b.part("stone", -15.08, mid, 0.0, 0.32, h, 30.6, "#454d4f")
	b.part("stone", 0.0, FLOOR_Y - 0.16, 0.0, 30.6, 0.32, 30.6, "#343b3d")
	# The +X wall is cut open at the pond outlet so the cascade can leave the island.
	var outlet_back := 4.25
	var outlet_front := 7.95
	for segment in [[-15.0, outlet_back], [outlet_front, 15.0]]:
		var z0: float = segment[0]
		var z1: float = segment[1]
		var length := z1 - z0
		b.part("stone", 15.08, mid, (z0 + z1) * 0.5, 0.32, h, length, "#4b5354")
	for i in range(6):
		var yy := FLOOR_Y + (i + 0.5) * h / 6.0
		var col: String = ["#474f54", "#4d5559", "#545d60", "#586165", "#667070", "#737771"][i]
		b.part("stone", 0.0, yy, 15.10, 30.62, h / 6.0 + 0.012, 0.34, col)
		b.part("stone", 0.0, yy, -15.10, 30.62, h / 6.0 + 0.012, 0.34, col)
		b.part("stone", -15.10, yy, 0.0, 0.34, h / 6.0 + 0.012, 30.62, col)
		for segment in [[-15.0, outlet_back], [outlet_front, 15.0]]:
			var z0: float = segment[0]
			var z1: float = segment[1]
			b.part("stone", 15.10, yy, (z0 + z1) * 0.5, 0.34, h / 6.0 + 0.012, z1 - z0, col)

func _cottage_steps(drop: float) -> int:
	return maxi(1, int(round(drop / 0.16)))

func _window(x: float, y: float, z: float, w: float = 0.62, h: float = 0.74, shutters: bool = true) -> void:
	b.part("glass", x, y, z + 0.02, w - 0.06, h - 0.06, 0.04, "#ffcc72")
	for s in [-1.0, 1.0]:
		b.part("wood", x + s * w * 0.5, y, z + 0.045, 0.08, h + 0.08, 0.07, "#563a27")
		b.part("wood", x, y + s * h * 0.5, z + 0.045, w - 0.08, 0.08, 0.07, "#563a27")
	b.part("wood", x, y, z + 0.05, 0.035, h - 0.08, 0.03, "#563a27")
	b.part("wood", x, y, z + 0.045, w - 0.08, 0.035, 0.02, "#563a27")
	b.part("wood", x, y - h * 0.5 - 0.07, z + 0.07, w + 0.2, 0.06, 0.14, "#6b4a33")
	if shutters:
		for s in [-1.0, 1.0]:
			var sx: float = x + float(s) * (w * 0.5 + 0.17)
			b.part("wood", sx, y, z + 0.025, 0.26, h + 0.02, 0.05, "#6f7a55")
			for f in [-0.3, 0.3]:
				b.part("wood", sx, y + f * h, z + 0.06, 0.24, 0.06, 0.02, "#5d6847")

func _door(x: float, y0: float, z: float, w: float = 0.74, h: float = 1.3) -> void:
	b.part("wood", x, y0 + h * 0.5, z + 0.005, w, h, 0.01, "#211811")
	for i in range(5):
		b.part("wood", x - w * 0.5 + (i + 0.5) * w / 5.0, y0 + h * 0.5, z + 0.03,
			w / 5.0 - 0.012, h - 0.02, 0.04, b.pick(["#6a432b", "#73492f", "#5f3c27"]))
	for f in [0.22, 0.78]:
		b.part("wood", x, y0 + h * f, z + 0.06, w - 0.08, 0.08, 0.02, "#4e3322")
	for s in [-1.0, 1.0]:
		b.part("wood", x + s * (w * 0.5 + 0.05), y0 + (h + 0.08) * 0.5, z + 0.045, 0.1, h + 0.08, 0.09, "#563a27")
	b.part("wood", x, y0 + h + 0.08, z + 0.05, w + 0.22, 0.1, 0.1, "#563a27")
	b.part("iron", x + w * 0.5 - 0.12, y0 + h * 0.5, z + 0.075, 0.04, 0.1, 0.04, "#2f2a24")

func _railing(ax: float, az: float, bx: float, bz: float, y: float, rail_h: float = 0.55, end_post: bool = true) -> void:
	var length := sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
	var count := maxi(1, int(round(length / 0.13)))
	var angle := atan2(bx - ax, bz - az)
	b.place((ax + bx) * 0.5, y, (az + bz) * 0.5, 1.0, angle, func() -> void:
		b.part("wood", 0.0, rail_h, 0.0, 0.09, 0.06, length, "#563a27")
		b.part("wood", 0.0, 0.1, 0.0, 0.05, 0.05, length, "#563a27")
		for i in range(1, count):
			b.part("wood", 0.0, (0.125 + rail_h - 0.03) * 0.5, -length * 0.5 + i * length / count,
				0.045, rail_h - 0.155, 0.045, b.pick(TIMBER))
		var ends := [-1.0, 1.0] if end_post else [-1.0]
		for end in ends:
			b.part("wood", 0.0, (rail_h + 0.05) * 0.5, end * length * 0.5, 0.1, rail_h + 0.05, 0.1, "#563a27")
	)

func _build_cottage(cx: float, cz: float, rot: float) -> void:
	var gy := height(cx, cz)
	var porch_z := cz + COTTAGE.D * 0.5 + COTTAGE.P
	var drop: float = maxf(0.12, gy + COTTAGE.F - height(cx, porch_z + 0.35))
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_cottage_parts(drop)
	)
	obstacles.append([cx, cz, 2.3])
	obstacles.append([cx, porch_z + 0.2, 0.75])
	cottage_window = Vector3(cx, gy + COTTAGE.F + 1.1, cz + COTTAGE.D * 0.5 + 0.7)

func _cottage_parts(drop: float) -> void:
	var W: float = COTTAGE.W
	var D: float = COTTAGE.D
	var F: float = COTTAGE.F
	var H: float = COTTAGE.H
	var knee: float = COTTAGE.knee
	var P: float = COTTAGE.P
	var B: float = COTTAGE.B
	var BW: float = COTTAGE.BW
	var slope: float = COTTAGE.slope
	var over: float = COTTAGE.over
	var E: float = COTTAGE.E
	var run: float = COTTAGE.run
	var top := F + H
	var span := W * 0.5 + over
	var pitch := atan(slope)
	var trim := "#563a27"
	var core := "#3a281c"

	# Stone plinth and ground skirt.
	b.part("stone", 0.0, F * 0.5 - 0.2, 0.0, W + 0.1, F + 0.4, D + 0.1, "#7a7262")
	b.part("stone", 0.0, (F - 0.21 - 0.45) * 0.5, D * 0.5 + 0.13 + (P - 0.13) * 0.5,
		W - 0.12, F - 0.21 + 0.45, P - 0.3, "#2e241b")

	# Wall core.
	b.part("wood", 0.0, F + (H + knee) * 0.5, 0.0, W - 0.12, H + knee, D - 0.12, core)

	# Horizontal siding, butt-jointed at a random point on each face.
	for s in [-1.0, 1.0]:
		for k in range(10):
			var y := F + (k + 0.5) * (H + knee) / 10.0
			var col: String = String(b.pick(TIMBER))
			b.part("wood", 0.0, y, float(s) * (D * 0.5 - 0.03), W - 0.14, (H + knee) / 10.0 - 0.016, 0.06, col)
		for k in range(8):
			var y2 := F + (k + 0.5) * H / 8.0
			var col2: String = String(b.pick(TIMBER))
			b.part("wood", float(s) * (W * 0.5 - 0.03), y2, 0.0, 0.06, H / 8.0 - 0.016, D - 0.14, col2)

	# Corner posts and belt bands.
	for x in [-W * 0.5, W * 0.5]:
		for z in [-D * 0.5, D * 0.5]:
			b.part("wood", x, F + (H + knee) * 0.5, z, 0.2, H + knee, 0.2, trim)
	b.part("wood", 0.0, F + 0.06, 0.0, W + 0.26, 0.12, D + 0.26, trim)
	b.part("wood", 0.0, top + 0.07, 0.0, W + 0.26, 0.14, D + 0.26, trim)

	# Front door and windows.
	_door(0.0, F + 0.12, D * 0.5)
	for x in [-0.95, 0.95]:
		_window(x, F + 0.95, D * 0.5)
	for z in [-0.65, 0.75]:
		b.place(W * 0.5, 0.0, z, 1.0, PI * 0.5, func() -> void:
			_window(0.0, F + 0.95, 0.0)
		)
	b.place(-W * 0.5, 0.0, 0.0, 1.0, -PI * 0.5, func() -> void:
		_window(0.0, F + 0.95, 0.0)
	)
	b.place(0.0, 0.0, -D * 0.5, 1.0, PI, func() -> void:
		_window(0.0, F + 0.95, 0.0)
		_window(0.0, top + 0.75, 0.0, 0.5, 0.6, false)
	)

	# Gable boards up under the roof.
	for s in [-1.0, 1.0]:
		for i in range(16):
			var x := -W * 0.5 + 0.1 + i * 0.2
			var yl := E + (span - absf(x)) * slope - 0.075
			var y0 := top + 0.14
			if yl > y0 + 0.05:
				b.part("wood", x, (yl + y0) * 0.5, s * (D * 0.5 - 0.03), 0.19, yl - y0, 0.06, b.pick(TIMBER))
	_door(0.0, top + 0.14, D * 0.5, 0.7, 1.1)

	# Balcony.
	var ry := top + 0.14
	var bz := D * 0.5 + B
	b.part("wood", 0.0, top, bz - 0.08, BW + 0.1, 0.12, 0.14, trim)
	for s in [-1.0, 1.0]:
		b.part("wood", s * (BW * 0.5 - 0.05), top, D * 0.5 + 0.13 + (B - 0.28) * 0.5, 0.12, 0.12, B - 0.28, trim)
	for i in range(15):
		b.part("wood", -BW * 0.5 + (i + 0.5) * BW / 15.0, top + 0.1, D * 0.5 + 0.13 + (B - 0.13) * 0.5,
			BW / 15.0 - 0.012, 0.08, B - 0.13, b.pick(TIMBER))
	for s in [-1.0, 1.0]:
		var px: float = float(s) * (BW * 0.5 - 0.05)
		b.part("wood", px, (F + top - 0.06) * 0.5, bz - 0.08, 0.14, top - 0.06 - F, 0.14, trim)
		b.part("wood", px - s * 0.17, top - 0.25, bz - 0.08, 0.07, 0.46, 0.07, trim, 0.0, 0.0, s * 0.75)
		_railing(px, D * 0.5 + 0.14, px, bz - 0.05, ry, 0.55, false)
	_railing(-BW * 0.5 + 0.05, bz - 0.05, BW * 0.5 - 0.05, bz - 0.05, ry)

	# Porch deck, fascia and railings.
	for i in range(20):
		b.part("wood", -W * 0.5 + (i + 0.5) * W / 20.0, F - 0.04, D * 0.5 + 0.13 + (P - 0.13) * 0.5,
			W / 20.0 - 0.012, 0.08, P - 0.13, b.pick(TIMBER))
	b.part("wood", 0.0, F - 0.14, D * 0.5 + P - 0.01, W, 0.14, 0.06, trim)
	for s in [-1.0, 1.0]:
		_railing(s * (W * 0.5 - 0.06), D * 0.5 + 0.15, s * (W * 0.5 - 0.06), D * 0.5 + P - 0.06, F, 0.5, false)
		_railing(s * (W * 0.5 - 0.06), D * 0.5 + P - 0.06, s * 0.58, D * 0.5 + P - 0.06, F, 0.5)

	# Steps.
	var step_count := _cottage_steps(drop)
	var foot := F - drop - 0.25
	for k in range(1, step_count + 1):
		var tread := F - k * drop / (step_count + 1)
		var z := D * 0.5 + P + (k - 0.5) * run
		b.part("wood", 0.0, (tread - 0.05 + foot) * 0.5, z, 0.94, tread - 0.05 - foot, run, trim)
		b.part("wood", 0.0, tread - 0.025, z + 0.02, 1.0, 0.05, run + 0.04, b.pick(TIMBER))

	# Shake roof: two sloped slabs with staggered shingle courses.
	var z_front := bz + 0.28
	var z_back := -D * 0.5 - 0.35
	var lz := z_front - z_back
	var zc := (z_front + z_back) * 0.5
	var L := span * sqrt(1.0 + slope * slope)
	for s in [-1.0, 1.0]:
		var rz: float = -float(s) * pitch
		b.part("clay", s * 0.5 * span, E + 0.5 * span * slope, zc, L, 0.1, lz, "#3a281c", 0.0, 0.0, rz)
		var rows := 12
		var step := L / rows
		var cols := int(round(lz / 0.27))
		var cw := lz / cols
		for j in range(rows):
			var t := (j + 0.6) / rows
			var x: float = float(s) * t * span
			var y := E + (1.0 - t) * span * slope + 0.085
			var shift := cw * 0.5 if j % 2 else 0.0
			for i in range(cols + 1):
				var a := maxf(z_back, z_back + i * cw - shift)
				var b2 := minf(z_front, z_back + (i + 1) * cw - shift)
				if b2 - a < 0.06:
					continue
				b.part("clay", x, y, (a + b2) * 0.5, step * 1.42, 0.035, b2 - a - 0.018 - b.randf() * 0.02,
					b.pick(SHAKES), 0.0, 0.0, rz + s * 0.075)
		b.part("clay", s * 0.11, E + 0.135, zc, 0.26, 0.05, lz + 0.06, "#3a281c", 0.0, 0.0, rz)
		for z in [z_front + 0.03, z_back - 0.03]:
			b.part("wood", s * 0.5 * span, E + 0.03, z, L + 0.02, 0.2, 0.06, trim, 0.0, 0.0, rz)
	# Ridge cap.
	b.part("clay", 0.0, E + span * slope + 0.09, zc, 0.28, 0.1, lz + 0.12, "#7b5a43")

	# Chimney.
	var ch_top := E + span * slope + 0.35
	b.part("stone", COTTAGE.chimney.x, (top + ch_top) * 0.5, COTTAGE.chimney.y,
		0.52, ch_top - top, 0.52, "#8a8170")
	b.part("stone", COTTAGE.chimney.x, ch_top + 0.07, COTTAGE.chimney.y,
		0.64, 0.14, 0.64, "#a39b87")
	b.part("stone", COTTAGE.chimney.x, ch_top + 0.145, COTTAGE.chimney.y,
		0.32, 0.02, 0.32, "#2a2a26")

func _house_parts(coop: bool) -> void:
	var w := 1.76
	var d := 1.82
	var h := 1.48
	for x in [-0.71, 0.71]:
		for z in [-0.73, 0.73]:
			b.part("wood", x, 0.32, z, 0.18, 0.64, 0.18, "#59422c")
	b.place(0.0, 0.38, 0.0, 1.0, 0.0, func() -> void:
		if coop:
			b.part("wood", 0.0, h * 0.5 + 0.2, -d * 0.5, w, h, 0.12, "#855438")
			for side in [-1.0, 1.0]:
				b.part("wood", side * (w * 0.5 - 0.06), h * 0.5 + 0.2, 0.0, 0.12, h, d, "#855438")
			for side in [-1.0, 1.0]:
				b.part("wood", side * (w * 0.25 + 0.18), h * 0.5 + 0.2, d * 0.5, w * 0.5 - 0.36, h, 0.12, "#855438")
			b.part("wood", 0.0, h + 0.12, d * 0.5, w, 0.2, 0.12, "#855438")
		else:
			b.part("wood", 0.0, h * 0.5 + 0.2, 0.0, w, h, d, "#855438")
		for i in range(9):
			if coop and i >= 3 and i <= 5:
				continue
			b.part("wood", -w * 0.5 + (i + 0.5) * w / 9.0, h * 0.5 + 0.2, d * 0.5 + (0.085 if coop else 0.02),
				w / 9.0 - 0.016, h, 0.05, b.pick(TIMBER))
		for x in [-w * 0.5, 0.0, w * 0.5]:
			for z in [-d * 0.5, d * 0.5]:
				if coop and x == 0.0 and z > 0.0:
					continue
				b.part("wood", x, h * 0.5 + 0.19, z, 0.15, h + 0.1, 0.15, "#5f412d")
		for y in [0.28, h + 0.12]:
			b.part("wood", 0.0, y, 0.0, w + 0.2, 0.17, d + 0.2, "#674832")
		var front := d * 0.5 + 0.09
		if coop:
			b.part("wood", 0.0, 0.88, front - 0.26, 0.69, 1.3, 0.045, "#29251e")
			b.place(-0.37, 0.0, front, 1.0, -1.35, func() -> void:
				b.part("wood", 0.34, 0.87, 0.0, 0.68, 1.3, 0.08, "#70432e")
			)
		else:
			b.part("wood", 0.0, 0.87, front + 0.04, 0.69, 1.36, 0.12, "#53392a")
			for i in range(4):
				b.part("wood", -0.24 + i * 0.16, 0.85, front + 0.12, 0.145, 1.23, 0.04, b.pick(TIMBER))
		for i in range(8):
			var tread := 0.385 - i * 0.09
			b.part("wood", 0.0, (tread - 0.42) * 0.5, front + 0.13 + i * 0.14, 0.81, tread + 0.42, 0.14, b.pick(TIMBER))
		var span := w * 0.5 + 0.22
		var pitch := atan(0.60)
		var base := h + 0.29
		for side in [-1.0, 1.0]:
			var angle: float = float(side) * pitch
			b.part("clay", 0.0, base + span * 0.60 * 0.5, side * span * 0.5,
				d + 0.48, 0.16, span * sqrt(1.0 + 0.60 * 0.60), "#793f2e", 0.0, 0.0, angle)
			for j in range(5):
				for i in range(8):
					var t := (j + 0.5) / 5.0
					b.part("clay", (i + 0.5 - 4.0) * (d + 0.4) / 8.0,
						base + (1.0 - t) * span * 0.60 + 0.105, side * t * span,
						(d + 0.4) / 8.0 - 0.012, 0.08, span / 5.0 * 1.19,
						b.pick(["#a64e35", "#b45739", "#aa5137", "#c06b45", "#98432f", "#b96141"]),
						0.0, 0.0, angle - side * 0.06)
		for i in range(7):
			var f := (i + 0.5) / 7.0
			b.part("wood", 0.0, base + f * span * 0.60, 0.0, d + 0.01, span * 0.60 / 7.0 + 0.01, w * (1.0 - f), b.pick(TIMBER))
	)

func _build_coop(cx: float, cz: float, rot: float) -> void:
	var gy := height(cx, cz)
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_house_parts(true)
	)
	obstacles.append([cx, cz, 1.4])

func _build_shed(cx: float, cz: float, rot: float) -> void:
	var gy := height(cx, cz)
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_house_parts(false)
	)
	obstacles.append([cx, cz, 1.4])

func _build_garden_beds() -> void:
	var cx := -1.1
	var cz := -7.65
	var bw := 1.62
	var bd := 0.78
	var gap := 0.3
	var kinds := [0, 1, 2, 3]
	for cell in kinds:
		var sx := -1.0 if cell % 2 == 0 else 1.0
		var sz := -1.0 if cell < 2 else 1.0
		var x0 := cx + sx * (bw + gap) * 0.5
		var z0 := cz + sz * (bd + gap) * 0.5
		var top := -1000.0
		var low := 1000.0
		for a in [-0.5, 0.0, 0.5]:
			for c in [-0.5, 0.0, 0.5]:
				var g := height(x0 + a * bw, z0 + c * bd)
				top = maxf(top, g)
				low = minf(low, g)
		var soil := top + 0.08
		b.part("soil", x0, (soil + low - 0.2) * 0.5, z0, bw, soil - low + 0.2, bd, "#5e3f2a")
		for s in [-1.0, 1.0]:
			b.part("wood", x0, (soil + 0.05 + low - 0.2) * 0.5, z0 + s * (bd * 0.5 + 0.03),
				bw + 0.12, soil + 0.05 - low + 0.2, 0.06, b.pick(TIMBER))
			b.part("wood", x0 + s * (bw * 0.5 + 0.03), (soil + 0.05 + low - 0.2) * 0.5, z0,
				0.06, soil + 0.05 - low + 0.2, bd, b.pick(TIMBER))
		for row in range(5):
			for col in range(3):
				var x := x0 + (col - 1) * 0.36 + (b.randf() - 0.5) * 0.04
				var z := z0 + (row - 2) * 0.3 + (b.randf() - 0.5) * 0.04
				var s := 0.8 + b.randf() * 0.35
				if row % 2 == 0:
					b.part("cabbage", x, soil - 0.01, z, s, s, s,
						b.pick(["#93b65a", "#a3c063", "#86a84f"]), 0.0, b.randf() * TAU, 0.0, 0.2)
				else:
					b.part("carrot", x, soil - 0.01, z, s, s, s,
						b.pick(["#6f9a3e", "#7ea946"]), 0.0, b.randf() * TAU, 0.0, 0.3)
		obstacles.append([x0, z0, 0.8])
	# Gravel cross.
	for i in range(8):
		var f := (i + 0.5) / 8.0 - 0.5
		b.part("stone", cx, height(cx, cz + f * bd * 2.0) + 0.02, cz + f * bd * 2.0,
			gap, 0.06, bd * 2.0 / 8.0, b.pick(["#c9b994", "#bfb18e", "#d2c4a0"]))
		b.part("stone", cx + f * bw * 2.0, height(cx + f * bw * 2.0, cz) + 0.02, cz,
			bw * 2.0 / 8.0, 0.06, gap, b.pick(["#c9b994", "#bfb18e", "#d2c4a0"]))
		path_points.append(Vector2(cx, cz + f * bd * 2.0))
		path_points.append(Vector2(cx + f * bw * 2.0, cz))

func _path(ax: float, az: float, bx: float, bz: float) -> void:
	var length := sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
	var count := maxi(1, int(ceil(length / 0.73)))
	var angle := atan2(bx - ax, bz - az)
	for i in range(count):
		var f := float(i) / float(count)
		var x := ax + (bx - ax) * f + (b.randf() - 0.5) * 0.12
		var z := az + (bz - az) * f + (b.randf() - 0.5) * 0.13
		if wet(x, z) > -0.19:
			continue
		b.part("stone", x, height(x, z) + 0.024, z, 0.65 + b.randf() * 0.17, 0.09, 0.47 + b.randf() * 0.14,
			b.pick(["#c5ae84", "#d3b990", "#baaa81"]), 0.0, angle + (b.randf() - 0.5) * 0.18, 0.0)
		path_points.append(Vector2(x, z))

func _build_paths() -> void:
	_path(-7.0, -10.0, flight.bx, flight.bz - 0.1)
	_path(flight.ax, flight.az + 0.15, -3.85, 0.25)
	_path(flight.bx + 0.35, flight.bz - 0.25, -3.1, -7.65)
	_path(-3.85, 0.25, -2.0, 0.8)
	_path(-2.0, 0.8, 5.5, 0.82)
	_path(5.5, 0.82, 10.8, 3.0)
	_path(1.0, 0.8, 1.0, 2.6)

func _build_path_mask() -> void:
	var size := 512
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for p in path_points:
		var px := int((p.x + 15.0) / 30.0 * size)
		var pz := int((p.y + 15.0) / 30.0 * size)
		var radius := 6
		image.fill_rect(Rect2i(px - radius, pz - radius, radius * 2, radius * 2), Color.WHITE)
	path_mask = ImageTexture.create_from_image(image)
	if terrain_material != null:
		terrain_material.set_shader_parameter("path_mask", path_mask)

func set_surface_state(wet_value: float, snow_value: float, season_value: int) -> void:
	var winter_value := 1.0 if season_value == 3 else 0.0
	if terrain_material != null:
		terrain_material.set_shader_parameter("wet", wet_value)
		terrain_material.set_shader_parameter("snow_depth", snow_value)
		terrain_material.set_shader_parameter("winter", winter_value)
	for child in get_children():
		if child is MultiMeshInstance3D:
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat.set_shader_parameter("wet", wet_value)
				mat.set_shader_parameter("snow_depth", snow_value)
				mat.set_shader_parameter("winter", winter_value)

func _build_trees() -> void:
	for i in range(TREE_LIST.size()):
		var item: Array = TREE_LIST[i]
		var x: float = item[0]
		var z: float = item[1]
		var s: float = item[2]
		var y := height(x, z)
		var angle := b.randf() * TAU
		var pine := i in PINE_INDICES
		if pine:
			b.part("pineABark", x, y, z, s, s, s, b.pick(BARK_COLORS), 0.0, angle, 0.0)
			b.part("pineANeedles", x, y, z, s, s, s, b.pick(["#5d7a45", "#678449", "#55703f"]), 0.0, angle, 0.0, 0.014)
		else:
			var kind := "oakA" if b.randf() > 0.5 else "oakB"
			var light := b.randf() > 0.32
			var palette := GREENS_LIGHT if light else GREENS_DARK
			b.part(kind + "Bark", x, y, z, s, s, s, b.pick(BARK_COLORS), 0.0, angle, 0.0)
			b.part(kind + "Leaves", x, y, z, s, s, s, b.pick(palette), 0.0, angle, 0.0, 0.014)
		obstacles.append([x, z, 0.58 * s])

func _build_ground_cover() -> void:
	var gx := -14.85
	while gx < 14.9:
		var gz := -14.85
		while gz < 14.9:
			var x := gx + (b.randf() - 0.5) * 0.24
			var z := gz + (b.randf() - 0.5) * 0.24
			gz += 0.26
			if not clear(x, z):
				continue
			var lush := 0.5 + 0.5 * sin(x * 0.83 + cos(z * 1.1)) * sin(z * 0.67 - x * 0.31)
			var s := 0.8 + b.randf() * 0.45
			var edge := 14.97 - 0.36 * s
			if absf(x) > edge or absf(z) > edge:
				continue
			var kind: String = ["turf0", "turf1", "turf2"][b.rng.randi_range(0, 2)]
			b.part(kind, x, height(x, z) - 0.01, z, s, s * (0.55 + 0.75 * lush + b.randf() * 0.25), s,
				b.pick(TURF_GREENS), 0.0, b.randf() * TAU, 0.0, 0.39)
			if b.randf() < 0.12 and maxf(absf(x), absf(z)) < 14.6:
				var k := 0.5 + b.randf() * 0.5
				var gkind: String = ["grass0", "grass1", "grass2"][b.rng.randi_range(0, 2)]
				b.part(gkind, x, height(x, z) - 0.01, z, k, k * (0.9 + b.randf() * 0.6), k,
					b.pick(TURF_GREENS), 0.0, b.randf() * TAU, 0.0, 0.39)
		gx += 0.26

	# Flowers, bushes and boulders.
	for i in range(440):
		var x := b.randf() * 28.4 - 14.2
		var z := b.randf() * 28.4 - 14.2
		if not clear(x, z):
			continue
		if i % 4 == 0:
			var s := 0.6 + b.randf() * 0.76
			var turn := b.randf() * TAU
			var color: String = String(b.pick(["#ed8d48", "#d55a3e", "#e7c464", "#e9e2c4", "#a1a6c6", "#e58fae"]))
			b.part("flowerStem", x, height(x, z) - 0.01, z, s, s, s, "#6f8f45", 0.0, turn, 0.0, 0.25)
			b.part("flowerHead", x, height(x, z) - 0.01, z, s, s, s, color, 0.0, turn, 0.0, 0.25)
		elif i % 5 == 0:
			for j in range(5):
				var a := x + (b.randf() - 0.5) * 0.75
				var c := z + (b.randf() - 0.5) * 0.75
				var s2 := 0.18 + b.randf() * 0.5
				b.part("boulder", a, height(a, c) + s2 * 0.16, c, s2, s2 * 0.74, s2 * 0.88,
					b.pick(["#82877a", "#989c87", "#747b73", "#a3a48d"]), 0.0, b.randf() * 5.0, 0.0)
		elif i % 6 == 0:
			var kind := "bushA" if b.randf() > 0.5 else "bushB"
			var s3 := 0.8 + b.randf() * 0.55
			var turn := b.randf() * TAU
			b.part(kind + "Twigs", x, height(x, z) - 0.02, z, s3, s3, s3, "#5b4632", 0.0, turn, 0.0)
			b.part(kind + "Leaves", x, height(x, z) - 0.02, z, s3, s3 * (0.85 + b.randf() * 0.3), s3,
				b.pick(["#6f8d40", "#7e9949", "#8b9f4f"]), 0.0, turn, 0.0, 0.05)
			obstacles.append([x, z, 0.42 * s3])

	# Shallow gravel and reeds around the pond.
	for i in range(850):
		var x := 6.0 + b.randf() * 8.75
		var z := 2.45 + b.randf() * 8.0
		var depth := WATER_Y - height(x, z)
		if depth < -0.12 or depth > 0.49 or x > 13.1:
			continue
		var size := 0.055 + b.randf() * 0.17
		b.part("boulder", x, WATER_Y - depth + 0.024, z, size, size * 0.58, size * 0.79,
			b.pick(["#888979", "#9e997c", "#667568"]), 0.0, b.randf() * 6.0, 0.0)
		if depth < 0.17 and sin(x * 1.8 + z * 0.62) > 0.48:
			for k in range(5):
				var a := x + (b.randf() - 0.5) * 0.23
				var c := z + (b.randf() - 0.5) * 0.21
				var h := 0.26 + b.randf() * 0.37
				b.part("reed", a, height(a, c) - 0.02, c, 0.7, h * 1.6, 0.7,
					b.pick(["#768449", "#8c9751", "#516f42"]), 0.0, b.randf() * TAU, 0.0, 0.3)

func _lantern_parts(section: String) -> void:
	if section != "pendant":
		b.part("stone", 0.0, 0.13, 0.0, 0.46, 0.26, 0.43, "#7a7867")
		b.part("wood", 0.0, 1.27, 0.0, 0.14, 2.36, 0.15, "#865e3e")
		b.part("wood", 0.24, 2.39, 0.0, 0.65, 0.13, 0.16, "#946b46")
		b.part("wood", 0.17, 2.15, 0.0, 0.085, 0.55, 0.10, "#684832", 0.0, 0.0, -0.67)
	if section == "post":
		return
	b.part("iron", 0.48, 2.26, 0.0, 0.045, 0.25, 0.05, "#403b32")
	b.part("iron", 0.48, 2.12, 0.0, 0.39, 0.095, 0.36, "#4d493e")
	b.part("lampglass", 0.48, 1.90, 0.0, 0.265, 0.35, 0.25, "#f6f2ea")
	for x in [0.33, 0.63]:
		for z in [-0.14, 0.14]:
			b.part("iron", x, 1.90, z, 0.035, 0.38, 0.035, "#453c32")
	b.part("iron", 0.48, 1.68, 0.0, 0.36, 0.085, 0.33, "#443c32")

func _build_lamps() -> void:
	var placements := [
		[-6.1, -7.35, 0.0],
		[-3.75, -2.5, 2.7],
		[0.04, 1.58, -1.0],
		[6.3, 0.60, 1.35],
		[13.07, 3.74, 0.0],
	]
	for placement in placements:
		var x: float = placement[0]
		var z: float = placement[1]
		var angle: float = placement[2]
		var y := height(x, z)
		b.place(x, y, z, 1.0, angle, func() -> void:
			_lantern_parts("post")
		)
		b.place(x, y, z, 1.0, angle, func() -> void:
			_lantern_parts("pendant")
		)
		obstacles.append([x, z, 0.2])
		var light := OmniLight3D.new()
		light.name = "LanternLight"
		light.position = Vector3(x + 0.48 * cos(angle), y + 1.90, z - 0.48 * sin(angle))
		light.light_color = Color(1.0, 0.92, 0.80)
		light.light_energy = 0.0
		light.omni_range = 6.0
		light.omni_attenuation = 1.3
		light.shadow_enabled = true
		light.shadow_bias = 0.04
		add_child(light)
		lamps.append({"light": light, "position": light.position})

func _build_extra_lights() -> void:
	window_light = OmniLight3D.new()
	window_light.name = "CottageWindowLight"
	window_light.position = cottage_window
	window_light.light_color = Color(1.0, 0.69, 0.32)
	window_light.light_energy = 0.0
	window_light.omni_range = 6.0
	window_light.omni_attenuation = 1.4
	window_light.shadow_enabled = false
	add_child(window_light)

func _collect_materials() -> void:
	for child in get_children():
		if child is MultiMeshInstance3D and child.name == "lampglass":
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is StandardMaterial3D:
				lamp_glass_material = mat

func set_night(night: float) -> void:
	for entry in lamps:
		var light: OmniLight3D = entry.light
		light.light_energy = night * 3.6
		light.visible = night > 0.02
	if window_light != null:
		window_light.light_energy = night * 2.4
	if lamp_glass_material != null:
		lamp_glass_material.emission_energy_multiplier = 0.03 + night * 3.0

func set_wind(wind_ms: float) -> void:
	var strength := clampf(wind_ms / 8.0, 0.0, 2.0)
	for child in get_children():
		if child is MultiMeshInstance3D:
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat.set_shader_parameter("wind_strength", strength)

func walkable(x: float, z: float) -> bool:
	return wet(x, z) < -0.2 and is_free(x, z, 0.26)

