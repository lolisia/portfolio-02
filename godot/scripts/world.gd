extends Node3D
class_name FarmWorld

## Port of src/world.js. Builds the 30x30 tile diorama terrain, pond,
## cottage, coop, shed, garden, paths, vegetation and lanterns.

const NatureAssets = preload("res://scripts/nature_assets.gd")
const GardenAssets = preload("res://scripts/garden_assets.gd")
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
var _trample_materials: Array[ShaderMaterial] = []
var _cloud_materials: Array[ShaderMaterial] = []
var path_mask: ImageTexture
var water: MeshInstance3D
var cascade_materials: Array[ShaderMaterial] = []
var cascade_fx
var cascade_left := 4.25
var cascade_width := 3.1
var cascade_drop := WATER_Y - FLOOR_Y
var veg_beds: Array = []
var rose_bushes: Array[Vector2] = []
var garden_plant_count := 0
var gravel_slab_count := 0
var wildflower_clusters := 0
var roofs: Array = []
var pond_shore := Vector2(6.9, 4.0)
var lamps: Array = []
var lamp_pivots: Array = []
var lamp_glass_materials: Array[StandardMaterial3D] = []
var lamp_sway_time := 0.0
var breeze := 0.375
var window_light: OmniLight3D
var lamp_glass_material: StandardMaterial3D
var window_glass_material: ShaderMaterial
var cottage_window := Vector3.ZERO
var cottage_ridge := Vector3.ZERO
var cottage_chimney := Vector3.ZERO
var cottage_origin := Vector2(-1.0, -2.5)
var cottage_drop := 0.12
var cottage_steps := 1
var cottage_door := Vector2(-1.0, -0.6)
var cottage_threshold := Vector2(-1.0, -0.88)
var cottage_apron := Vector2(-1.0, 0.75)
var door_leaf: Node3D
var door_target_open := false
var door_open := 0.0
var obstacles: Array = []
var boxes: Array = []
## Static collision circles [x, z, r, tag] (web colliders.circle). Separate from
## `obstacles`, which only keeps scenery from being placed on top of itself.
var circles: Array = []
var bodies: Array = []
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
const HOUSE_WOOD := ["#815133", "#986342", "#70432e", "#aa7650"]
const SHAKES := ["#7b5a43", "#6d4e3a", "#866550", "#5f4434", "#8a6a52", "#735240", "#6a5342"]
const TURF_GREENS := ["#536e37", "#718a40", "#98aa58", "#899d4c", "#647f3b"]
const SEASON_TINTS := [
	Vector3(1.15, 1.18, 0.95),
	Vector3(1.0, 1.0, 1.0),
	Vector3(1.95, 0.60, 0.34),
	Vector3(0.79, 0.87, 0.83),
]

func build() -> void:
	meshes = NatureAssets.load_meshes()
	var garden_meshes: Dictionary = GardenAssets.build()
	for key in garden_meshes:
		if not meshes.has(key):
			meshes[key] = garden_meshes[key]
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
	_build_fences()
	_build_vegetable_beds()
	_build_paths()
	_build_garden_stairs()
	_build_path_mask()
	_build_trees()
	_build_stumps()
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

func roof_floor(x: float, z: float) -> float:
	var y := maxf(WATER_Y, height(x, z))
	for roof in roofs:
		var rx: float = roof["rx"]
		var rz: float = roof["rz"]
		var dx: float = absf(x - float(roof["x"]))
		var dz: float = absf(z - float(roof["z"]))
		if dx < rx and dz < rz:
			y = maxf(y, float(roof["y"]) + (rx - dx) * float(roof["slope"]))
	return y

func stand(x: float, z: float) -> float:
	# Faithful port of src/world.js stand(): the porch deck and its steps are
	# raised walking surfaces; everywhere else is the terrain.
	var ground := height(x, z)
	var lx := x - cottage_origin.x
	var lz := z - cottage_origin.y
	var w: float = COTTAGE.W
	var d: float = COTTAGE.D
	var p: float = COTTAGE.P
	var f: float = COTTAGE.F
	var run_distance: float = COTTAGE.run
	var house_y := height(cottage_origin.x, cottage_origin.y)
	if absf(lx) < w * 0.5 and lz > d * 0.5 and lz < d * 0.5 + p:
		return house_y + f
	var k := int(floor((lz - d * 0.5 - p) / run_distance)) + 1
	if absf(lx) < 0.5 and k >= 1 and k <= cottage_steps:
		return maxf(ground, house_y + f
			- float(k) * cottage_drop / float(cottage_steps + 1))
	return ground

## Height of the snow cover above the bare terrain. Mirrors the lift applied
## in shaders/terrain.gdshader and src/seasons.js.
func snow_lift(x: float, z: float, base_y: float, snow_value: float) -> float:
	var bank := smoothstep(WATER_Y + 0.015, WATER_Y + 0.3, base_y)
	return snow_value * bank * (0.078 + 0.031 * sin(x * 1.7 + cos(z * 0.91)))

func snow_surface(x: float, z: float, snow_value: float) -> float:
	var base := height(x, z)
	return base + snow_lift(x, z, base, snow_value) + 0.012

func is_on_porch(x: float, z: float) -> bool:
	# Porch deck and steps, used to allow the walker onto the raised surfaces
	# that the normal obstacle graph deliberately excludes.
	var lx := x - cottage_origin.x
	var lz := z - cottage_origin.y
	var w: float = COTTAGE.W
	var d: float = COTTAGE.D
	var p: float = COTTAGE.P
	var run_distance: float = COTTAGE.run
	if absf(lx) < w * 0.5 and lz > d * 0.5 - 0.05 and lz < d * 0.5 + p:
		return true
	var step_depth: float = float(cottage_steps) * run_distance + 0.22
	if absf(lx) < 0.62 and lz >= d * 0.5 + p - 0.05 and lz < d * 0.5 + p + step_depth:
		return true
	return false

func is_free(x: float, z: float, pad: float = 0.0) -> bool:
	for obstacle in obstacles:
		var ox: float = obstacle[0]
		var oz: float = obstacle[1]
		var radius: float = obstacle[2]
		if pow(x - ox, 2.0) + pow(z - oz, 2.0) <= pow(radius + pad, 2.0):
			return false
	return true

func add_box(x: float, z: float, w: float, d: float, angle: float, tag: String = "") -> void:
	boxes.append({"x": x, "z": z, "w": w, "d": d, "angle": angle, "tag": tag})

func add_circle(x: float, z: float, radius: float, tag: String = "") -> void:
	circles.append([x, z, radius, tag])

## Web colliders.blocked(): does a disc of radius r touch any static collider?
func blocked(x: float, z: float, radius: float = 0.0, skip: String = "") -> bool:
	for box in boxes:
		if skip != "" and String(box.get("tag", "")) == skip:
			continue
		if _box_overlap(x, z, radius, box):
			return true
	for circle in circles:
		if skip != "" and String(circle[3]) == skip:
			continue
		var dx := x - float(circle[0])
		var dz := z - float(circle[1])
		var minimum := float(circle[2]) + radius
		if dx * dx + dz * dz < minimum * minimum:
			return true
	return false

func add_body(x: float, z: float, radius: float, kind: String) -> Dictionary:
	var body := {
		"id": bodies.size(), "x": x, "z": z, "r": radius, "kind": kind,
		"active": true, "ignore": "",
	}
	bodies.append(body)
	return body

func _box_overlap(x: float, z: float, pad: float, box: Dictionary) -> bool:
	var dx := x - float(box["x"])
	var dz := z - float(box["z"])
	var angle := float(box["angle"])
	var c := cos(angle)
	var s := sin(angle)
	var lx := c * dx - s * dz
	var lz := s * dx + c * dz
	var hx := float(box["w"]) * 0.5
	var hz := float(box["d"]) * 0.5
	var closest_x := clampf(lx, -hx, hx)
	var closest_z := clampf(lz, -hz, hz)
	var ox := lx - closest_x
	var oz := lz - closest_z
	if absf(lx) <= hx and absf(lz) <= hz:
		return true
	return ox * ox + oz * oz < pad * pad

func resolve_body(point: Vector2, radius: float, self_body = null) -> Vector2:
	# Web parity (colliders.resolve): three passes of oriented boxes, static
	# collision circles and the other walkers. Scenery placement circles
	# (`obstacles`) are not colliders; a body skips statics tagged `ignore`.
	var p := point
	for iteration in range(3):
		for box in boxes:
			if self_body != null \
					and String(box.get("tag", "")) == String(self_body.get("ignore", "")):
				continue
			p = _push_out_box(p, radius, box)
		for circle in circles:
			if self_body != null and String(circle[3]) == String(self_body.get("ignore", "")):
				continue
			var ox := p.x - float(circle[0])
			var oz := p.y - float(circle[1])
			var minimum := float(circle[2]) + radius
			var distance_sq := ox * ox + oz * oz
			if distance_sq < minimum * minimum:
				if distance_sq > 1e-9:
					var distance := sqrt(distance_sq)
					p += Vector2(ox, oz) / distance * (minimum - distance)
				else:
					p.x += minimum
		if self_body != null:
			for other in bodies:
				if int(other["id"]) == int(self_body["id"]) or not bool(other["active"]):
					continue
				var dx := p.x - float(other["x"])
				var dz := p.y - float(other["z"])
				var minimum_b := radius + float(other["r"])
				var distance_sq_b := dx * dx + dz * dz
				if distance_sq_b < minimum_b * minimum_b:
					if distance_sq_b > 1e-9:
						var distance_b := sqrt(distance_sq_b)
						p += Vector2(dx, dz) / distance_b * (minimum_b - distance_b)
					else:
						p.x += minimum_b
	return p

func _push_out_box(point: Vector2, radius: float, box: Dictionary) -> Vector2:
	var dx := point.x - float(box["x"])
	var dz := point.y - float(box["z"])
	var angle := float(box["angle"])
	var c := cos(angle)
	var s := sin(angle)
	var lx := c * dx - s * dz
	var lz := s * dx + c * dz
	var hx := float(box["w"]) * 0.5
	var hz := float(box["d"]) * 0.5
	var closest_x := clampf(lx, -hx, hx)
	var closest_z := clampf(lz, -hz, hz)
	var ox := lx - closest_x
	var oz := lz - closest_z
	var distance_sq := ox * ox + oz * oz
	if distance_sq >= radius * radius:
		return point
	var push_x := 0.0
	var push_z := 0.0
	if distance_sq > 1e-8:
		var distance := sqrt(distance_sq)
		push_x = ox / distance * (radius - distance)
		push_z = oz / distance * (radius - distance)
	else:
		# Inside the box: exit through the nearest face.
		var face_x := hx - absf(lx)
		var face_z := hz - absf(lz)
		if face_x < face_z:
			push_x = (1.0 if lx >= 0.0 else -1.0) * (face_x + radius)
		else:
			push_z = (1.0 if lz >= 0.0 else -1.0) * (face_z + radius)
	# Rotate the local push back into world space.
	return point + Vector2(c * push_x + s * push_z, -s * push_x + c * push_z)

func is_free_for_walker(x: float, z: float, pad: float = 0.16) -> bool:
	# Water stays off limits; everything else is the web collision world.
	return wet(x, z) <= -0.10 and not blocked(x, z, pad)

func near_path(x: float, z: float) -> bool:
	for p in path_points:
		if pow(x - p.x, 2.0) + pow(z - p.y, 2.0) < 0.42 * 0.42:
			return true
	return false

func clear(x: float, z: float) -> bool:
	return is_free(x, z, 0.16) and wet(x, z) < -0.13 and not near_path(x, z)

func _terrain_color(x: float, z: float, _y: float) -> Color:
	# Web world.js ground canvas: (123,149,73) grass or (125,129,87) shore,
	# plus the smooth field term (the per-pixel speckle lives in the shader).
	var field := sin(x * 1.4 + sin(z)) * 3.0 + cos(z * 0.94 + x * 0.55) * 5.0 		+ sin(z * 3.2 - x * 2.2) * 2.0
	var shore := wet(x, z) > -0.13
	var r := (125.0 if shore else 123.0) + field
	var g := (129.0 if shore else 149.0) + field
	var bl := (87.0 if shore else 73.0) + field * 0.62
	return Color(r / 255.0, g / 255.0, bl / 255.0).srgb_to_linear()

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
	terrain_material.set_shader_parameter("winter_bare_color",
		Vector3(0.36, 0.235, 0.135))
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = terrain_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(ground)

func _build_water() -> void:
	# Web parity (water.js): a 10×9 grid with a per-vertex bed depth attribute.
	# The shader uses the real depth instead of an ellipse distance, so the
	# pond centre is deep and the banks shallow.
	var cols := 136
	var rows := 120
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	for r in range(rows + 1):
		for c in range(cols + 1):
			var u := float(c) / float(cols)
			var v := float(r) / float(rows)
			var lx := (u - 0.5) * 10.0
			var lz := (v - 0.5) * 9.0
			vertices.append(Vector3(lx, 0.0, lz))
			uvs.append(Vector2(u, v))
			uv2s.append(Vector2(WATER_Y - height(10.0 + lx, 6.1 + lz), 0.0))
	for r in range(rows):
		for c in range(cols):
			var i := r * (cols + 1) + c
			indices.append_array([i, i + cols + 1, i + 1,
				i + 1, i + cols + 1, i + cols + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("breeze", 0.4)
	water = MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = mesh
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
	cascade_materials.clear()
	# Find the actual pond outlet exactly like cascade.js: the first and last
	# z where the terrain at x=15 sits below the water line.
	var found := false
	var z := 4.25
	while z <= 7.95:
		if height(15.0, z) < WATER_Y - 0.018:
			if not found:
				cascade_left = z
				found = true
			cascade_width = z - cascade_left
		z += 0.018
	if not found:
		cascade_left = 4.25
		cascade_width = 3.7
	# One continuous ballistic curtain in two layers (front bright, back dark),
	# with 44 columns across the outlet and 56 rows down the arc.
	for layer in [0.0, 1.0]:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/waterfall.gdshader")
		mat.set_shader_parameter("layer", layer)
		mat.set_shader_parameter("shade", 1.0 if layer < 0.5 else 0.62)
		mat.set_shader_parameter("freeze", 0.0)
		mat.set_shader_parameter("breeze", 0.4)
		cascade_materials.append(mat)
		var falls := MeshInstance3D.new()
		falls.name = "Cascade" if layer < 0.5 else "CascadeBack"
		falls.mesh = _cascade_curtain(layer)
		falls.material_override = mat
		falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(falls)
	# The web's seven displaced boulders around the outlet.
	var rock_color := "#515b56"
	var middle := cascade_left + cascade_width * 0.5
	b.part("boulder", 15.36, FLOOR_Y + 0.08, middle, 1.11, 0.34, cascade_width * 0.73,
		rock_color, 0.13, 0.08, -0.14)
	b.part("boulder", 15.84, FLOOR_Y + 0.10, cascade_left + 0.18, 0.49, 0.27, 0.57,
		rock_color, 0.13, 0.72, -0.14)
	b.part("boulder", 15.68, FLOOR_Y + 0.07, cascade_left + cascade_width * 0.82,
		0.62, 0.32, 0.52, rock_color, 0.13, -0.4, -0.14)
	for entry in [[cascade_left, -1.0], [cascade_left + cascade_width, 1.0]]:
		var edge_z: float = entry[0]
		var sign: float = entry[1]
		b.part("boulder", 14.93, WATER_Y + 0.03, edge_z + sign * 0.12, 0.37, 0.23, 0.32,
			rock_color, 0.13, sign * 0.6, -0.14)
		b.part("boulder", 15.10, WATER_Y - 0.31, edge_z + sign * 0.09, 0.28, 0.28, 0.41,
			rock_color, 0.13, -sign * 0.25, -0.14)
	# Droplets, foam and vapour from cascade.js.
	cascade_fx = preload("res://scripts/cascade_fx.gd").new()
	cascade_fx.name = "CascadeFX"
	add_child(cascade_fx)
	cascade_fx.setup(cascade_left, cascade_width, cascade_drop, FLOOR_Y,
		Callable(self, "cascade_path"))

func cascade_path(across: float, t: float, layer: float) -> Vector3:
	var a := maxf(0.0, t)
	var wave := sin(across * 17.3 + layer * 2.1) * 0.5 + sin(across * 5.1 + 1.3) * 0.5
	var x := 14.76 + 0.24 * minf(1.0, (t + 0.25) * 4.0) + a * (0.78 + 0.05 * wave) \
		+ 0.08 * a * a + layer * 0.045 * a
	var y := WATER_Y + 0.012 - cascade_drop * a * a
	var z := cascade_left + across * cascade_width + a * a * (across - 0.5) * 0.28
	return Vector3(x, y, z)

func _cascade_curtain(layer: float) -> ArrayMesh:
	var cols := 44
	var rows := 56
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var eps := 0.004
	for r in range(rows + 1):
		var t := -0.25 + 1.25 * float(r) / float(rows)
		for c in range(cols + 1):
			var across := float(c) / float(cols)
			var p := cascade_path(across, t, layer)
			vertices.append(p)
			uvs.append(Vector2(across, t))
			var du := cascade_path(minf(across + eps, 1.0), t, layer) \
				- cascade_path(maxf(across - eps, 0.0), t, layer)
			var dv := cascade_path(across, t + eps, layer) \
				- cascade_path(across, t - eps, layer)
			var n := du.cross(dv).normalized()
			if n.x < 0.0:
				n = -n
			normals.append(n)
	for r in range(rows):
		for c in range(cols):
			var i := r * (cols + 1) + c
			indices.append_array([i, i + cols + 1, i + 1,
				i + 1, i + cols + 1, i + cols + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_perimeter() -> void:
	# Web parity: exposed soil + chipped stone strata follow the terrain height
	# around all four edges instead of a flat 3.1-high plate wall.
	var soil_colors := ["#815a3c", "#80583b", "#896346"]
	var rock_palettes := [
		["#474f54", "#4d5559"], ["#545d60", "#586165"],
		["#667070", "#61696a"], ["#737771", "#707571"],
	]
	for side in range(4):
		for i in range(120):
			var t := (float(i) + 0.5) * 0.25 - 15.0
			var x := 15.0 if side == 0 else (-15.0 if side == 1 else t)
			var z := 15.0 if side == 2 else (-15.0 if side == 3 else t)
			var top := height(x, z)
			var earth := 0.36 + 0.055 * sin(t)
			var w := 0.08 if side < 2 else 0.255
			var d := 0.255 if side < 2 else 0.08
			b.part("stone", x, top - earth * 0.5 - 0.015, z, w, earth + 0.015, d,
				String(b.pick(soil_colors)))
			var rock_h := top - earth - FLOOR_Y
			for j in range(4):
				var yy := FLOOR_Y + (float(j) + 0.5) * rock_h / 4.0
				b.part("stone", x, yy, z, w, rock_h / 4.0 + 0.013, d,
					String(b.pick(rock_palettes[j])))

func _build_door_leaf(cx: float, gy: float, cz: float, rot: float) -> Node3D:
	var D: float = COTTAGE.D
	var F: float = COTTAGE.F
	var pivot := Node3D.new()
	pivot.name = "CottageDoor"
	pivot.position = Vector3(cx - 0.37, gy + F + 0.12, cz + D * 0.5 + 0.01)
	pivot.rotation.y = rot
	add_child(pivot)
	# H10: the leaf is built through the same batched builder as the rest of
	# the cottage, so the planks use the wood surface shader and the web's
	# random board palette instead of alternating StandardMaterial colors.
	var leaf := DioramaBuilder.new(pivot, meshes, 9182)
	var leaf_w := 0.74
	var leaf_h := 1.28
	for i in range(5):
		leaf.part("wood", (float(i) + 0.5) * leaf_w / 5.0, leaf_h * 0.5, 0.02,
			leaf_w / 5.0 - 0.012, leaf_h - 0.02, 0.04,
			b.pick(["#6a432b", "#73492f", "#5f3c27"]))
	for fraction in [0.22, 0.78]:
		leaf.part("wood", leaf_w * 0.5, leaf_h * float(fraction), 0.05,
			leaf_w - 0.08, 0.08, 0.02, "#4e3322")
	leaf.part("iron", leaf_w - 0.12, leaf_h * 0.5, 0.065,
		0.04, 0.1, 0.04, "#2f2a24")
	leaf.finish()
	return pivot

func set_door_open(open: bool) -> void:
	door_target_open = open

func door_open_amount() -> float:
	return door_open

func _process(delta: float) -> void:
	if door_leaf == null:
		return
	# Web parity: the hinge eases out while opening and lands with a small
	# rebound against the jamb when it falls shut.
	var want := 1.0 if door_target_open else 0.0
	var rate := 1.6 if want > door_open else 1.15
	door_open = move_toward(door_open, want, rate * delta)
	var k := (1.0 - pow(1.0 - door_open, 2.0)) if door_target_open \
		else pow(door_open, 1.6)
	var rebound := 0.0
	if not door_target_open and door_open < 0.06:
		rebound = 0.025 * sin(door_open / 0.06 * PI)
	door_leaf.rotation.y = -1.68 * k + rebound

	lamp_sway_time += delta
	for entry in lamp_pivots:
		var pivot: Node3D = entry["pivot"]
		var phase: float = float(entry["phase"])
		var gust := sin(lamp_sway_time * 1.37 - phase) \
			+ 0.42 * sin(lamp_sway_time * 2.31 - phase * 0.71)
		pivot.rotation.z = gust * 0.11 * breeze
		pivot.rotation.x = 0.037 * breeze * sin(lamp_sway_time * 1.55 - phase)

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

func _door(x: float, y0: float, z: float, w: float = 0.74, h: float = 1.3,
		has_leaf: bool = false) -> void:
	b.part("wood", x, y0 + h * 0.5, z + 0.005, w, h, 0.01, "#211811")
	if not has_leaf:
		for i in range(5):
			b.part("wood", x - w * 0.5 + (i + 0.5) * w / 5.0, y0 + h * 0.5, z + 0.03,
				w / 5.0 - 0.012, h - 0.02, 0.04, b.pick(["#6a432b", "#73492f", "#5f3c27"]))
		for f in [0.22, 0.78]:
			b.part("wood", x, y0 + h * f, z + 0.06, w - 0.08, 0.08, 0.02, "#4e3322")
	for s in [-1.0, 1.0]:
		b.part("wood", x + s * (w * 0.5 + 0.05), y0 + (h + 0.08) * 0.5, z + 0.045, 0.1, h + 0.08, 0.09, "#563a27")
	b.part("wood", x, y0 + h + 0.08, z + 0.05, w + 0.22, 0.1, 0.1, "#563a27")
	if not has_leaf:
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
	cottage_origin = Vector2(cx, cz)
	cottage_drop = drop
	cottage_steps = _cottage_steps(drop)
	cottage_door = Vector2(cx, cz + COTTAGE.D * 0.5 + 0.4)
	cottage_threshold = Vector2(cx, cz + COTTAGE.D * 0.5 + 0.12)
	cottage_apron = Vector2(cx, porch_z + float(cottage_steps) * float(COTTAGE.run) + 0.3)
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_cottage_parts(drop)
	)
	# Oriented collision boxes: house body, porch side railings and the two
	# front railings with the door step gap left open (U9).
	add_box(cx, cz, COTTAGE.W + 0.26, COTTAGE.D + 0.26, rot, "house")
	for side in [-1.0, 1.0]:
		add_box(cx + float(side) * (COTTAGE.W * 0.5 - 0.06),
			cz + COTTAGE.D * 0.5 + 0.13 + (COTTAGE.P - 0.13) * 0.5,
			0.14, COTTAGE.P - 0.13, rot, "house")
		add_box(cx + float(side) * (COTTAGE.W * 0.5 + 0.58) * 0.5,
			porch_z - 0.06, COTTAGE.W * 0.5 - 0.58, 0.14, rot, "house")
	# Balcony support posts standing on the porch deck.
	for side in [-1.0, 1.0]:
		add_circle(cx + float(side) * (float(COTTAGE.BW) * 0.5 - 0.05),
			cz + COTTAGE.D * 0.5 + float(COTTAGE.B) - 0.08, 0.1, "house")
	door_leaf = _build_door_leaf(cx, gy, cz, rot)
	obstacles.append([cx, cz, 2.3])
	obstacles.append([cx, porch_z + 0.2, 0.75])
	cottage_window = Vector3(cx, gy + COTTAGE.F + 1.1, cz + COTTAGE.D * 0.5 + 0.7)
	var span: float = COTTAGE.W * 0.5 + COTTAGE.over
	var ridge_y: float = gy + COTTAGE.E + span * COTTAGE.slope
	cottage_ridge = Vector3(cx, ridge_y + 0.12, cz - 0.5)
	cottage_chimney = Vector3(cx + COTTAGE.chimney.x, ridge_y + 0.58, cz + COTTAGE.chimney.y)
	var roof_span: float = COTTAGE.W * 0.5 + COTTAGE.over
	var roof_front: float = COTTAGE.D * 0.5 + COTTAGE.B + 0.28
	var roof_back: float = -COTTAGE.D * 0.5 - 0.35
	roofs.append({
		"x": cx, "z": cz + (roof_front + roof_back) * 0.5,
		"rx": roof_span, "rz": (roof_front - roof_back) * 0.5,
		"y": gy + COTTAGE.E, "slope": COTTAGE.slope,
	})

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
		W - 0.12, F - 0.21 + 0.45, P - 0.3, "#3a281c")
	# H7: two rows of random-length foundation stones on the x± and z− faces.
	for face in [["x", 1.0], ["x", -1.0], ["z", -1.0]]:
		var axis: String = face[0]
		var side: float = face[1]
		for stone_y in [0.1, 0.3]:
			var run_len := D if axis == "x" else W
			var cursor := -run_len * 0.5 + 0.03 + (0.12 if stone_y > 0.2 else 0.0)
			while cursor < run_len * 0.5 - 0.1:
				var stone_len := minf(0.28 + b.randf() * 0.26,
					run_len * 0.5 - 0.03 - cursor)
				var center := cursor + stone_len * 0.5
				var color := String(b.pick(["#8b8371", "#7a7364", "#958d79", "#6f6a5d"]))
				if axis == "x":
					b.part("stone", side * (W * 0.5 + 0.07), stone_y, center,
						0.06, 0.18, stone_len - 0.025, color)
				else:
					b.part("stone", center, stone_y, side * (D * 0.5 + 0.07),
						stone_len - 0.025, 0.18, 0.06, color)
				cursor += stone_len

	# Wall core.
	b.part("wood", 0.0, F + (H + knee) * 0.5, 0.0, W - 0.12, H + knee, D - 0.12, core)

	# H8: horizontal cladding, each course butt-jointed at a random point.
	# Web order: x faces use the full H+knee with 10 courses, z faces use H
	# with 8 courses.
	for s in [-1.0, 1.0]:
		var x_len := D - 0.14
		for k in range(10):
			var y := F + (k + 0.5) * (H + knee) / 10.0
			var cut_x := -x_len * 0.5 + x_len * (0.3 + 0.4 * b.randf())
			for segment in [[-x_len * 0.5, cut_x], [cut_x, x_len * 0.5]]:
				var a: float = segment[0]
				var bb: float = segment[1]
				b.part("wood", float(s) * (W * 0.5 - 0.03), y, (a + bb) * 0.5,
					0.06, (H + knee) / 10.0 - 0.016, bb - a - 0.012, b.pick(TIMBER))
		var z_len := W - 0.14
		for k in range(8):
			var y2 := F + (k + 0.5) * H / 8.0
			var cut_z := -z_len * 0.5 + z_len * (0.3 + 0.4 * b.randf())
			for segment in [[-z_len * 0.5, cut_z], [cut_z, z_len * 0.5]]:
				var a2: float = segment[0]
				var b2: float = segment[1]
				b.part("wood", (a2 + b2) * 0.5, y2, float(s) * (D * 0.5 - 0.03),
					b2 - a2 - 0.012, H / 8.0 - 0.016, 0.06, b.pick(TIMBER))

	# Corner posts and belt bands.
	for x in [-W * 0.5, W * 0.5]:
		for z in [-D * 0.5, D * 0.5]:
			b.part("wood", x, F + (H + knee) * 0.5, z, 0.2, H + knee, 0.2, trim)
	b.part("wood", 0.0, F + 0.06, 0.0, W + 0.26, 0.12, D + 0.26, trim)
	b.part("wood", 0.0, top + 0.07, 0.0, W + 0.26, 0.14, D + 0.26, trim)

	# Front door and windows.
	_door(0.0, F + 0.12, D * 0.5, 0.74, 1.3, true)
	for x in [-0.95, 0.95]:
		_window(x, F + 0.95, D * 0.5)
	# H12/X: the web façade has no window flower boxes; keep the windows bare.
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
			var x: float = float(s) * t * span + float(s) * sin(pitch) * 0.085
			var y := E + (1.0 - t) * span * slope + cos(pitch) * 0.085
			var shift := cw * 0.5 if j % 2 else 0.0
			for i in range(cols + 1):
				var a := maxf(z_back, z_back + i * cw - shift)
				var b2 := minf(z_front, z_back + (i + 1) * cw - shift)
				if b2 - a < 0.06:
					continue
				b.part("clay", x, y, (a + b2) * 0.5, step * 1.42, 0.035, b2 - a - 0.018 - b.randf() * 0.02,
					b.pick(SHAKES), 0.0, 0.0, rz + s * 0.075)
		# Eave strip near the ridge (web: at(.11/span,.135)), offset along
		# the roof normal instead of sitting at the eave height.
		var eave_x := float(s) * 0.11 + float(s) * sin(pitch) * 0.135
		var eave_y := E + span * slope - 0.11 * slope + cos(pitch) * 0.135
		b.part("clay", eave_x, eave_y, zc, 0.26, 0.05, lz + 0.06, "#3a281c", 0.0, 0.0, rz)
		# Barge boards at mid-slope (web: at(.5,.03)).
		var barge_x := float(s) * 0.5 * span + float(s) * sin(pitch) * 0.03
		var barge_y := E + 0.5 * span * slope + cos(pitch) * 0.03
		for z in [z_front + 0.03, z_back - 0.03]:
			b.part("wood", barge_x, barge_y, z, L + 0.02, 0.2, 0.06, trim, 0.0, 0.0, rz)

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
				w / 9.0 - 0.016, h, 0.05, b.pick(HOUSE_WOOD))
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
				b.part("wood", -0.24 + i * 0.16, 0.85, front + 0.12, 0.145, 1.23, 0.04, b.pick(HOUSE_WOOD))
		for i in range(8):
			var tread := 0.385 - i * 0.09
			b.part("wood", 0.0, (tread - 0.42) * 0.5, front + 0.13 + i * 0.14, 0.81, tread + 0.42, 0.14, b.pick(HOUSE_WOOD))
		var span := w * 0.5 + 0.22
		var pitch := atan(0.60)
		var base := h + 0.29
		b.place(0.0, 0.0, 0.0, 1.0, PI * 0.5, func() -> void:
			for side in [-1.0, 1.0]:
				var angle: float = float(side) * pitch
				b.part("clay", 0.0, base + span * 0.60 * 0.5, side * span * 0.5,
					d + 0.48, 0.16, span * sqrt(1.0 + 0.60 * 0.60), "#793f2e",
					angle, 0.0, 0.0)
				for j in range(5):
					for i in range(8):
						var t := (j + 0.5) / 5.0
						b.part("clay", (i + 0.5 - 4.0) * (d + 0.4) / 8.0,
							base + (1.0 - t) * span * 0.60 + 0.105, side * t * span,
							(d + 0.4) / 8.0 - 0.012, 0.08, span / 5.0 * 1.19,
							b.pick(["#a64e35", "#b45739", "#aa5137", "#c06b45", "#98432f", "#b96141"]),
							angle - float(side) * 0.06, 0.0, 0.0)
			for i in range(7):
				var f := (i + 0.5) / 7.0
				b.part("wood", 0.0, base + f * span * 0.60, 0.0, d + 0.01,
					span * 0.60 / 7.0 + 0.01, w * (1.0 - f), b.pick(HOUSE_WOOD))
		)
	)

func _build_coop(cx: float, cz: float, rot: float) -> void:
	var gy := height(cx, cz)
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_house_parts(true)
	)
	obstacles.append([cx, cz, 1.4])
	add_box(cx, cz, 1.76, 1.82, rot, "coop")
	var ramp := 1.82 * 0.5 + 0.6
	add_box(cx + sin(rot) * ramp, cz + cos(rot) * ramp,
		0.86, 1.2, rot, "coop")
	roofs.append({"x": cx, "z": cz, "rx": 1.10, "rz": 1.1,
		"y": gy + 2.15, "slope": 0.6})

func _build_shed(cx: float, cz: float, rot: float) -> void:
	var gy := height(cx, cz)
	b.place(cx, gy, cz, 1.0, rot, func() -> void:
		_house_parts(false)
	)
	obstacles.append([cx, cz, 1.4])
	add_box(cx, cz, 1.76, 1.82, rot, "")
	var ramp := 1.82 * 0.5 + 0.6
	add_box(cx + sin(rot) * ramp, cz + cos(rot) * ramp,
		0.86, 1.2, rot, "")
	roofs.append({"x": cx, "z": cz, "rx": 1.10, "rz": 1.1,
		"y": gy + 2.15, "slope": 0.6})

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
		# Flower garden: web planting loop starts at step*0.6 and jitters each
		# plant by ±step*0.175 (G3), rather than a regular grid.
		var step: float = [0.36, 0.20, 0.17, 0.24][cell]
		var a := -bw * 0.5 + step * 0.6
		while a < bw * 0.5 - step * 0.4:
			var c := -bd * 0.5 + step * 0.6
			while c < bd * 0.5 - step * 0.4:
				var x := x0 + a + (b.randf() - 0.5) * step * 0.35
				var z := z0 + c + (b.randf() - 0.5) * step * 0.35
				_plant_garden_cell(cell, x, z, soil - 0.01)
				garden_plant_count += 1
				c += step
			a += step
		# A per-cell obstacle for the bed frame.
		obstacles.append([x0, z0, 0.8])
	# Rose bushes at the four garden corners (web: cx ± (bw+gap/2+.42),
	# cz ± (bd+gap/2−.1)); not one set per bed.
	for rsx in [-1.0, 1.0]:
		for rsz in [-1.0, 1.0]:
			var rx: float = cx + float(rsx) * (bw + gap * 0.5 + 0.42)
			var rz: float = cz + float(rsz) * (bd + gap * 0.5 - 0.1)
			var ry := height(rx, rz) - 0.02
			b.part("bushALeaves", rx, ry, rz, 0.62, 0.55, 0.62,
				b.pick(["#4f6e33", "#5a7a3a"]), 0.0, b.randf() * TAU, 0.0, 0.0)
			for i in range(9):
				var a4 := b.randf() * TAU
				var u := 0.12 + b.randf() * 0.16
				b.part("roseBloom", rx + cos(a4) * u, ry + 0.22 + b.randf() * 0.14,
					rz + sin(a4) * u, 1.2, 1.2, 1.2,
					b.pick(["#c8243a", "#e85a78", "#f3b3c0", "#a51d2e"]), 0.0, b.randf() * TAU, 0.0, 0.05)
			rose_bushes.append(Vector2(rx, rz))
	# Gravel cross: web loop places ceil(len/.3) small 0.27-square slabs at
	# 0.3 spacing along each axis (G4), instead of 8 long slabs.
	for cross in [[cx, cz, gap, bd * 2.0 + gap + 0.1],
			[cx, cz, bw * 2.0 + gap + 0.1, gap]]:
		var x: float = cross[0]
		var z: float = cross[1]
		var w: float = cross[2]
		var d: float = cross[3]
		var count := ceili(maxf(w, d) / 0.3)
		for i in range(count):
			var f := (float(i) + 0.5) / float(count) - 0.5
			var gx := x + (f * w if w > d else 0.0)
			var gz := z + (f * d if d > w else 0.0)
			var slab_w := (0.3 if w > d else gap) - 0.03
			var slab_d := (0.3 if d > w else gap) - 0.03
			b.part("stone", gx, height(gx, gz) + 0.02, gz,
				slab_w, 0.06, slab_d, b.pick(["#c9b994", "#bfb18e", "#d2c4a0"]),
				0.0, (b.randf() - 0.5) * 0.1, 0.0)
			path_points.append(Vector2(gx, gz))
			gravel_slab_count += 1

func _plant_garden_cell(cell: int, x: float, z: float, y: float) -> void:
	var s := 0.9 + b.randf() * 0.3
	match cell:
		0:
			s = 0.9 + b.randf() * 0.2
			var a0 := 0.6 + (b.randf() - 0.5) * 0.5
			b.part("sunflowerStem", x, y, z, s, s, s, "#6f9142", 0.0, a0, 0.0, 0.12)
			b.part("sunflowerBloom", x, y, z, s, s, s,
				b.pick(["#ffffff", "#fff3d8", "#ffe2b0"]), 0.0, a0, 0.0, 0.12)
		1:
			s = 1.0 + b.randf() * 0.4
			var a1 := b.randf() * TAU
			b.part("foxgloveStem", x, y, z, s, s, s, "#6b8c45", 0.0, a1, 0.0, 0.22)
			b.part("foxgloveBloom", x, y, z, s, s, s,
				b.pick(["#c76aa4", "#e7a6cf", "#f2eef2", "#a676c8", "#d9809a"]), 0.0, a1, 0.0, 0.22)
		2:
			s = 0.9 + b.randf() * 0.25
			var a2 := b.randf() * TAU
			b.part("tulipStem", x, y, z, s, s, s, "#73964a", 0.0, a2, 0.0, 0.22)
			b.part("tulipBloom", x, y, z, s, s, s,
				b.pick(["#e0362f", "#f2c430", "#f08bb0", "#f7f1e6", "#f07a2a", "#b0367a"]), 0.0, a2, 0.0, 0.22)
		_:
			s = 0.85 + b.randf() * 0.4
			var a3 := b.randf() * TAU
			if b.randf() < 0.7:
				b.part("lavenderStem", x, y, z, s, s, s, "#7d9468", 0.0, a3, 0.0, 0.30)
				b.part("lavenderBloom", x, y, z, s, s, s,
					b.pick(["#8a6cc4", "#9b7fd1", "#7a5fb5"]), 0.0, a3, 0.0, 0.30)
			else:
				for i in range(3):
					var fx := x + (b.randf() - 0.5) * 0.14
					var fz := z + (b.randf() - 0.5) * 0.14
					var fs := 0.55 + b.randf() * 0.3
					b.part("flowerStem", fx, y, fz, fs, fs, fs, "#6f8f45", 0.0, b.randf() * TAU, 0.0, 0.22)
					b.part("flowerHead", fx, y, fz, fs, fs, fs,
						b.pick(["#f4f1e4", "#f2d25a"]), 0.0, b.randf() * TAU, 0.0, 0.22)

func _build_vegetable_beds() -> void:
	# The original places four beds: two by the cottage and two on the far
	# slope behind the flower garden.
	for bed in [Vector2(1.1, 3.3), Vector2(2.7, 3.3), Vector2(-7.0, -9.5), Vector2(-5.45, -9.5)]:
		var x: float = bed.x
		var z: float = bed.y
		var y := height(x, z)
		b.place(x, y, z, 1.0, 0.0, func() -> void:
			b.part("bedFrame", 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, "#9a6c47")
			b.part("bedSoil", 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, "#6a4630")
			for row in range(5):
				for col in range(3):
					var px := (col - 1) * 0.36 + (b.randf() - 0.5) * 0.04
					var pz := (row - 2) * 0.30 + (b.randf() - 0.5) * 0.04
					var s := 0.80 + b.randf() * 0.35
					if row % 2 == 0:
						b.part("cabbage", px, 0.19, pz, s, s, s, b.pick(["#93b65a", "#a3c063", "#86a84f"]), 0.0, b.randf() * TAU, 0.0, 0.2)
					else:
						b.part("carrot", px, 0.19, pz, s, s, s, b.pick(["#6f9a3e", "#7ea946"]), 0.0, b.randf() * TAU, 0.0, 0.3)
		)
		obstacles.append([x, z, 0.78])
		add_box(x, z, 1.32, 1.72, 0.0, "bed")
		veg_beds.append(Vector2(x, z))

func _build_fences() -> void:
	var hx := -1.0
	var hz := -2.5
	var w: float = COTTAGE.W
	var d: float = COTTAGE.D
	var porch_z := hz + d * 0.5 + float(COTTAGE.P)
	var runs := [
		[Vector2(hx - w * 0.5 - 0.1, porch_z - 0.03),
			Vector2(hx - w * 0.5 - 0.6, porch_z - 0.03),
			Vector2(hx - w * 0.5 - 0.6, hz - d * 0.5 + 0.05),
			Vector2(hx - w * 0.5 - 0.08, hz - d * 0.5 + 0.05)],
		[Vector2(hx + w * 0.5 + 0.1, porch_z - 0.03),
			Vector2(hx + w * 0.5 + 0.42, porch_z - 0.03),
			Vector2(hx + w * 0.5 + 0.42, porch_z - 0.9)],
		[Vector2(hx + w * 0.5 + 0.42, porch_z - 1.7),
			Vector2(hx + w * 0.5 + 0.42, hz - d * 0.5 + 0.05),
			Vector2(hx + w * 0.5 + 0.08, hz - d * 0.5 + 0.05)],
	]
	for points in runs:
		_fence_run(points)

func _fence_run(points: Array) -> void:
	var posts: Array[Vector2] = []
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var length := a.distance_to(b)
		var count := maxi(1, int(round(length / 0.85)))
		for k in range(1 if i > 1 else 0, count + 1):
			posts.append(a.lerp(b, float(k) / float(count)))
		# Web: one fence collider box per polyline segment.
		add_box((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0.16, length,
			atan2(b.x - a.x, b.y - a.y), "fence")
	for i in range(posts.size()):
		var p: Vector2 = posts[i]
		var py := height(p.x, p.y)
		b.part("wood", p.x, py + 0.31, p.y, 0.1, 0.74, 0.1,
			b.pick(["#6b4b33", "#5e4230", "#735139"]), 0.0, b.randf() * 0.3)
		b.part("wood", p.x, py + 0.70, p.y, 0.13, 0.04, 0.13, "#4f3725", 0.0, b.randf() * 0.3)
		obstacles.append([p.x, p.y, 0.22])
		if i == 0:
			continue
		var prev: Vector2 = posts[i - 1]
		var prev_y := height(prev.x, prev.y)
		var length := p.distance_to(prev)
		var angle := atan2(p.x - prev.x, p.y - prev.y)
		b.place((p.x + prev.x) * 0.5, (py + prev_y) * 0.5, (p.y + prev.y) * 0.5, 1.0, angle, func() -> void:
			for rail_y in [0.26, 0.55]:
				b.part("wood", 0.0, rail_y, 0.0, 0.045, 0.075, length + 0.06,
					b.pick(["#8f6644", "#9b7049", "#86603f"]), -atan2(py - prev_y, length))
		)

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

func _build_garden_stairs() -> void:
	# Port of src/world.js stairs(): pale treads over dark risers with stepped
	# cheek walls, following the carved flight grade.
	var ax: float = flight.ax
	var az: float = flight.az
	var ux: float = flight.ux
	var uz: float = flight.uz
	var length: float = flight.len
	var y0 := flight_y0
	var y1 := flight_y1
	var count := maxi(4, int(round((y1 - y0) / 0.145)))
	var rise := (y1 - y0) / float(count)
	var run := length / float(count)
	var angle := atan2(ux, uz)
	var width := 1.0
	for k in range(count):
		var at := (float(k) + 0.5) * run
		var x := ax + ux * at
		var z := az + uz * at
		var top := y0 + float(k + 1) * rise
		var base := y0 + float(k) * rise - 0.2
		b.place(x, 0.0, z, 1.0, angle, func() -> void:
			b.part("stone", 0.0, (top - 0.04 + base) * 0.5, 0.0,
				width - 0.04, top - 0.04 - base, run + 0.02,
				String(b.pick(["#7f7c6c", "#77756a", "#868272"])))
			b.part("stone", 0.0, top - 0.025, 0.025, width + 0.02, 0.05, run + 0.06,
				String(b.pick(["#b3ad94", "#a9a58c", "#bab39a", "#a19e88"])),
				0.0, (b.randf() - 0.5) * 0.03)
			for side in [-1.0, 1.0]:
				b.part("stone", float(side) * (width * 0.5 + 0.08),
					(top + 0.13 + base) * 0.5, 0.0, 0.16,
					top + 0.13 - base, run + 0.012,
					String(b.pick(["#8b8778", "#807d70", "#938e7d"])))
		)
		path_points.append(Vector2(x, z))

func _build_path_mask() -> void:
	# G7: 1024² RGBA ground mask. R = leaf litter (tree radial stamps),
	# G = soft trail (radial stamps along every path point), B/A unused.
	# Linear filtering + radial falloff replace the old 6-pixel square mask.
	var size := 1024
	var data := PackedByteArray()
	data.resize(size * size * 4)
	data.fill(0)
	for tree in FarmWorld.TREE_LIST:
		var x: float = tree[0]
		var z: float = tree[1]
		var s: float = tree[2]
		_stamp_ground_mask(data, size, x, z, 2.1 * s, 0, 1.0)
	for p in path_points:
		_stamp_ground_mask(data, size, p.x, p.y, 1.02, 1, 0.91)
	var image := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	path_mask = ImageTexture.create_from_image(image)
	if terrain_material != null:
		terrain_material.set_shader_parameter("path_mask", path_mask)

func _stamp_ground_mask(data: PackedByteArray, size: int, x: float, z: float,
		radius_world: float, channel: int, opacity: float) -> void:
	var cx := int((x + 15.0) / 30.0 * float(size))
	var cz := int((z + 15.0) / 30.0 * float(size))
	var radius := maxi(1, int(ceil(radius_world / 30.0 * float(size))))
	var radius_sq := float(radius * radius)
	for py in range(maxi(0, cz - radius), mini(size, cz + radius + 1)):
		for px in range(maxi(0, cx - radius), mini(size, cx + radius + 1)):
			var dx := float(px - cx)
			var dz := float(py - cz)
			var distance_sq := dx * dx + dz * dz
			if distance_sq > radius_sq:
				continue
			var value := int((1.0 - sqrt(distance_sq / radius_sq)) * opacity * 255.0)
			var index := (py * size + px) * 4 + channel
			if value > int(data[index]):
				data[index] = value

func set_surface_state(wet_value: float, snow_value: float, _season_value: int) -> void:
	# Wet/snow are updated continuously; the season tint/winter blend is owned by
	# set_season_blend() so the UI season change can lerp over time.
	if terrain_material != null:
		terrain_material.set_shader_parameter("wet", wet_value)
		terrain_material.set_shader_parameter("snow_depth", snow_value)
	for child in get_children():
		if child is MultiMeshInstance3D:
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat.set_shader_parameter("wet", wet_value)
				mat.set_shader_parameter("snow_depth", snow_value)

func set_season_blend(tint: Vector3, winter: float) -> void:
	if terrain_material != null:
		terrain_material.set_shader_parameter("winter", winter)
	for child in get_children():
		if child is MultiMeshInstance3D:
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat.set_shader_parameter("winter", winter)
				mat.set_shader_parameter("season_tint", tint)

## 16 x (x, z, radius, strength) presses written by main.gd. Only the turf /
## grass materials receive the array, so trees and crops skip the loop.
func set_trample(slots: PackedVector4Array) -> void:
	for mat in _trample_materials:
		mat.set_shader_parameter("trample", slots)

func set_water_freeze(value: float) -> void:
	if cascade_fx != null:
		cascade_fx.set_freeze(value)
	if water == null:
		return
	var mat := water.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("freeze", clampf(value, 0.0, 1.0))
	for cascade_mat in cascade_materials:
		cascade_mat.set_shader_parameter("freeze", clampf(value, 0.0, 1.0))

func update_cascade(delta: float, wind: float, light: float) -> void:
	for cascade_mat in cascade_materials:
		cascade_mat.set_shader_parameter("light", clampf(light, 0.0, 1.5))
		cascade_mat.set_shader_parameter("sky_level", clampf(light, 0.0, 1.5))
	if cascade_fx != null:
		cascade_fx.update(delta, wind, light)

func set_quality(level: int) -> void:
	var factor: float = [1.0, 0.78, 0.50][clampi(level, 0, 2)]
	for child in get_children():
		if not (child is MultiMeshInstance3D):
			continue
		var mmi := child as MultiMeshInstance3D
		var kind := String(mmi.name)
		if not (kind.begins_with("turf") or kind.begins_with("grass")):
			continue
		var multimesh := mmi.multimesh
		if multimesh == null:
			continue
		if factor >= 1.0:
			multimesh.visible_instance_count = -1
		else:
			multimesh.visible_instance_count = maxi(1, int(multimesh.instance_count * factor))

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
		add_circle(x, z, 0.32 * s, "tree")

func tree_canopies() -> Array:
	# World-space AABBs for the tree canopies, used by the rain/snow collision
	# pass. The meshes are authored base-at-origin in nature.glb.
	var result: Array = []
	var oak_a: Mesh = meshes.get("oakALeaves")
	var oak_b: Mesh = meshes.get("oakBLeaves")
	var pine: Mesh = meshes.get("pineANeedles")
	for i in range(TREE_LIST.size()):
		var item: Array = TREE_LIST[i]
		var x: float = item[0]
		var z: float = item[1]
		var s: float = item[2]
		var is_pine := i in PINE_INDICES
		var mesh: Mesh = pine if is_pine else (oak_a if oak_a != null else oak_b)
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		if not is_pine and oak_a != null and oak_b != null:
			aabb = aabb.merge(oak_b.get_aabb())
		var center := Vector3(x, height(x, z)
			+ (aabb.position.y + aabb.size.y * 0.5) * s, z)
		var size := aabb.size * s
		# Slight padding covers the random yaw and leaf fringes.
		result.append([center, size * 1.06])
	return result

func _build_stumps() -> void:
	# The web's three stump pairs (world.js: stumpBark/stumpTop at -0.04).
	for entry in [[-8.5, -4.2], [7.6, 10.4], [-6.0, 8.0]]:
		var x: float = entry[0]
		var z: float = entry[1]
		var angle := b.randf() * TAU
		b.place(x, height(x, z), z, 1.0, angle, func() -> void:
			b.part("stumpBark", 0.0, -0.04, 0.0, 1.0, 1.0, 1.0, "#7a5a3a")
			b.part("stumpTop", 0.0, -0.04, 0.0, 1.0, 1.0, 1.0, "#d1b07a")
		)
		obstacles.append([x, z, 0.45])
		add_circle(x, z, 0.4, "plant")

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
			# M3: kit.flowers() is a single-colour cluster of 7 blooms plus
			# three grass tufts, not one flower per scatter point.
			var flower_color: String = String(b.pick(
				["#ed8d48", "#d55a3e", "#e7c464", "#e9e2c4", "#a1a6c6", "#e58fae"]))
			b.place(x, height(x, z) - 0.01, z, 1.0, 0.0, func() -> void:
				for j in range(7):
					var fx := (b.randf() - 0.5) * 0.8
					var fz := (b.randf() - 0.5) * 0.76
					var fs := 0.75 + b.randf() * 0.6
					var turn := b.randf() * TAU
					b.part("flowerStem", fx, 0.0, fz, fs, fs, fs, "#6f8f45",
						0.0, turn, 0.0, 0.25)
					b.part("flowerHead", fx, 0.0, fz, fs, fs, fs, flower_color,
						0.0, turn, 0.0, 0.25)
				for j in range(3):
					var tuft_x := (b.randf() - 0.5) * 0.7
					var tuft_z := (b.randf() - 0.5) * 0.7
					var gs := 0.45 + b.randf() * 0.3
					var gkind: String = ["grass0", "grass1", "grass2"][b.rng.randi_range(0, 2)]
					b.part(gkind, tuft_x, 0.0, tuft_z, gs, gs, gs, "#86a24c",
						0.0, b.randf() * TAU, 0.0, 0.25)
			)
			wildflower_clusters += 1
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
			add_circle(x, z, 0.42 * s3, "plant")

	# M4(X): the web has no separate wildflower drifts; the 440-point scatter
	# above (a single-colour cluster every fourth point) is the only source.

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

func _lantern_parts(section: String, target: DioramaBuilder = null) -> void:
	var builder: DioramaBuilder = b if target == null else target
	if section != "pendant":
		builder.part("stone", 0.0, 0.13, 0.0, 0.46, 0.26, 0.43, "#7a7867")
		builder.part("wood", 0.0, 1.27, 0.0, 0.14, 2.36, 0.15, "#865e3e")
		builder.part("wood", 0.24, 2.39, 0.0, 0.65, 0.13, 0.16, "#946b46")
		builder.part("wood", 0.17, 2.15, 0.0, 0.085, 0.55, 0.10, "#684832", 0.0, 0.0, -0.67)
	if section == "post":
		return
	builder.part("iron", 0.48, 2.26, 0.0, 0.045, 0.25, 0.05, "#403b32")
	builder.part("iron", 0.48, 2.12, 0.0, 0.39, 0.095, 0.36, "#4d493e")
	builder.part("lampglass", 0.48, 1.90, 0.0, 0.265, 0.35, 0.25, "#f6f2ea")
	for x in [0.33, 0.63]:
		for z in [-0.14, 0.14]:
			builder.part("iron", x, 1.90, z, 0.035, 0.38, 0.035, "#453c32")
	builder.part("iron", 0.48, 1.68, 0.0, 0.36, 0.085, 0.33, "#443c32")

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
		obstacles.append([x, z, 0.2])
		add_circle(x, z, 0.2, "lamp")
		# M5: the pendant hangs from its own pivot so it can swing with the
		# breeze; the spotlight travels with it like the web's lantern pivot.
		var pivot := Node3D.new()
		pivot.name = "LanternPivot"
		pivot.position = Vector3(x + 0.48 * cos(angle), y + 2.385,
			z - 0.48 * sin(angle))
		pivot.rotation.y = angle
		add_child(pivot)
		var pendant := DioramaBuilder.new(pivot, meshes, 7000 + lamps.size() * 131)
		pendant.place(-0.48, -2.385, 0.0, 1.0, 0.0, func() -> void:
			_lantern_parts("pendant", pendant)
		)
		pendant.finish()
		var glass_material: StandardMaterial3D
		for node in pivot.find_children("lampglass", "MultiMeshInstance3D", true, false):
			var glass_mmi := node as MultiMeshInstance3D
			if glass_mmi.material_override is StandardMaterial3D:
				glass_material = glass_mmi.material_override as StandardMaterial3D
		var phase := pivot.position.x * 0.39 + pivot.position.z * 0.23
		lamp_pivots.append({"pivot": pivot, "phase": phase})
		var light := SpotLight3D.new()
		light.name = "LanternLight"
		light.position = Vector3(0.0, -0.485, 0.0)
		light.light_color = Color(1.0, 0.92, 0.80)
		light.light_energy = 0.0
		light.spot_range = 8.0
		light.spot_angle = 67.0
		light.spot_angle_attenuation = 0.72
		light.spot_attenuation = 1.65
		light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		light.shadow_enabled = true
		light.shadow_bias = 0.04
		pivot.add_child(light)
		lamps.append({
			"light": light,
			"glass": glass_material,
			"position": Vector3(x + 0.48 * cos(angle), y + 1.90,
				z - 0.48 * sin(angle)),
		})

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
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var mat := mmi.material_override
		if mmi.name == "lampglass" and mat is StandardMaterial3D:
			var glass_mat := mat as StandardMaterial3D
			lamp_glass_materials.append(glass_mat)
			if lamp_glass_material == null:
				lamp_glass_material = glass_mat
		if mmi.name == "glass":
			var glass := ShaderMaterial.new()
			glass.shader = preload("res://shaders/window_interior.gdshader")
			mmi.material_override = glass
			window_glass_material = glass
		var name := String(mmi.name)
		if mat is ShaderMaterial and (name.begins_with("turf") or name.begins_with("grass")):
			_trample_materials.append(mat)

func set_night(night: float) -> void:
	for entry in lamps:
		var light: SpotLight3D = entry.light
		light.light_energy = night * 3.6
		light.visible = night > 0.02
	if window_light != null:
		window_light.light_energy = night * 2.4
	for glass in lamp_glass_materials:
		glass.emission_energy_multiplier = 0.03 + night * 3.0

func set_wind(wind_ms: float) -> void:
	var strength := clampf(wind_ms / 8.0, 0.0, 2.0)
	breeze = strength
	for child in get_children():
		if child is MultiMeshInstance3D:
			var mat := (child as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial:
				mat.set_shader_parameter("wind_strength", strength)
	if water != null:
		var water_mat := water.material_override as ShaderMaterial
		if water_mat != null:
			water_mat.set_shader_parameter("breeze", strength)

func set_cloud_shadow(amount: float, clock: float) -> void:
	if _cloud_materials.is_empty():
		if terrain_material != null:
			_cloud_materials.append(terrain_material)
		for node in find_children("*", "MultiMeshInstance3D", true, false):
			var mat := (node as MultiMeshInstance3D).material_override
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
				and (mat as ShaderMaterial).shader.code.contains("cloud_amount"):
				_cloud_materials.append(mat)
	for mat in _cloud_materials:
		mat.set_shader_parameter("cloud_amount", amount)
		mat.set_shader_parameter("cloud_clock", clock)

func walkable(x: float, z: float) -> bool:
	# Web: !colliders.blocked(x, z, .26) && wet < -.2
	return wet(x, z) < -0.2 and not blocked(x, z, 0.26)


