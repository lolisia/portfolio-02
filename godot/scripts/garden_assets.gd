extends RefCounted
class_name GardenAssets

## Procedural garden flowers ported from src/garden.js. Stems are swept tubes
## along a Catmull-Rom curve and leaves are arched strap planes; blooms keep
## their instanced petal/bud meshes.

static func build() -> Dictionary:
	return {
		"tulipStem": _tulip_stem(),
		"tulipBloom": _tulip_bloom(),
		"lavenderStem": _lavender_stem(),
		"lavenderBloom": _lavender_bloom(),
		"sunflowerStem": _sunflower_stem(),
		"sunflowerBloom": _sunflower_bloom(),
		"foxgloveStem": _foxglove_stem(),
		"foxgloveBloom": _foxglove_bloom(),
		"roseBloom": _rose_bloom(),
		"flowerStem": _generic_stem(),
		"flowerHead": _generic_head(),
	}

static func _cylinder(top: float, bottom: float, height: float, segments: int = 6) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

static func _sphere(radius: float, segments: int = 6, rings: int = 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh

static func _merge(parts: Array) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var mesh: Mesh = part[0]
		var transform: Transform3D = part[1]
		for surface in range(mesh.get_surface_count()):
			tool.append_from(mesh, surface, transform)
	return tool.commit()

static func _place(mesh: Mesh, position: Vector3, scale_value: Vector3,
		rotation: Vector3 = Vector3.ZERO) -> Array:
	return [mesh, Transform3D(
		Basis.from_euler(rotation) * Basis.from_scale(scale_value), position)]

static func _mesh_from(vertices: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _curve_point(points: Array, t: float) -> Vector3:
	var count := points.size()
	if count == 0:
		return Vector3.ZERO
	if count == 1:
		return points[0]
	var scaled := clampf(t, 0.0, 1.0) * float(count - 1)
	var index := clampi(int(floor(scaled)), 0, count - 2)
	var u := scaled - float(index)
	var p0: Vector3 = points[maxi(index - 1, 0)]
	var p1: Vector3 = points[index]
	var p2: Vector3 = points[index + 1]
	var p3: Vector3 = points[mini(index + 2, count - 1)]
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3)

## A thin curved stem from the origin to (dx, top, dz), like garden.js stem().
static func _tube_stem(top: float, radius: float, dx: float = 0.0, dz: float = 0.0,
		tubular_segments: int = 6, radial_segments: int = 4) -> ArrayMesh:
	var points: Array = []
	for i in range(6):
		var u := float(i) / 5.0
		points.append(Vector3(dx * u * u, top * u, dz * u * u))
	var rings := tubular_segments + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var last_tangent := Vector3.UP
	for r in range(rings):
		var t := float(r) / float(tubular_segments)
		var center := _curve_point(points, t)
		var tangent := (_curve_point(points, minf(t + 0.002, 1.0))
			- _curve_point(points, maxf(t - 0.002, 0.0))).normalized()
		if tangent.length_squared() < 0.001:
			tangent = last_tangent
		last_tangent = tangent
		var up := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		var right := up.cross(tangent).normalized()
		var normal_up := tangent.cross(right).normalized()
		for k in range(radial_segments):
			var angle := TAU * float(k) / float(radial_segments)
			var normal := (cos(angle) * right + sin(angle) * normal_up).normalized()
			vertices.append(center + normal * radius)
			normals.append(normal)
			uvs.append(Vector2(float(k) / float(radial_segments), t))
	for r in range(rings - 1):
		for k in range(radial_segments):
			var i0 := r * radial_segments + k
			var i1 := r * radial_segments + (k + 1) % radial_segments
			var i2 := (r + 1) * radial_segments + k
			var i3 := (r + 1) * radial_segments + (k + 1) % radial_segments
			indices.append_array([i0, i2, i1, i1, i2, i3])
	return _mesh_from(vertices, normals, uvs, indices)

## A tapered, arched strap leaf from the base, like garden.js strap().
static func _strap_mesh(angle: float, length: float, width: float,
		rise: float = 0.6) -> ArrayMesh:
	var rows := 4
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var basis := Basis(Vector3.UP, angle)
	var normal := basis * Vector3(0.0, 0.0, 1.0)
	for r in range(rows + 1):
		var v := float(r) / float(rows)
		var half := width * 0.5 * (1.0 - v * 0.85)
		var y := v * length
		var z := v * v * length * (1.0 - rise)
		vertices.append(basis * Vector3(-half, y, z))
		vertices.append(basis * Vector3(half, y, z))
		normals.append(normal)
		normals.append(normal)
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(1.0, v))
	for r in range(rows):
		var i0 := r * 2
		var i1 := r * 2 + 1
		var i2 := (r + 1) * 2
		var i3 := (r + 1) * 2 + 1
		indices.append_array([i0, i2, i1, i1, i2, i3])
	return _mesh_from(vertices, normals, uvs, indices)

static func _tulip_stem() -> ArrayMesh:
	return _merge([
		[_tube_stem(0.34, 0.009, 0.02, 0.01), Transform3D.IDENTITY],
		[_strap_mesh(0.4, 0.2, 0.05, 0.7), Transform3D.IDENTITY],
		[_strap_mesh(3.4, 0.17, 0.045, 0.6), Transform3D.IDENTITY],
	])

static func _tulip_bloom() -> ArrayMesh:
	var petal := _sphere(0.032, 5, 3)
	var parts := []
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		parts.append(_place(petal,
			Vector3(cos(angle) * 0.018, 0.37, sin(angle) * 0.018),
			Vector3(1.0, 1.7, 0.55),
			Vector3(0.18 * (0.5 if i % 2 == 0 else 1.0), angle, 0.0)))
	return _merge(parts)

static func _lavender_stem() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for i in range(13):
		var a := float(i) * 2.4 + rng.randf() * 0.5
		var lean := 0.05 + rng.randf() * 0.09
		var top := 0.26 + rng.randf() * 0.12
		parts.append([_tube_stem(top, 0.004, sin(a) * lean, cos(a) * lean),
			Transform3D.IDENTITY])
	for i in range(6):
		parts.append([_strap_mesh(float(i) * 1.05, 0.11, 0.012, 0.4),
			Transform3D.IDENTITY])
	return _merge(parts)

static func _lavender_bloom() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for i in range(13):
		var a := float(i) * 2.4 + rng.randf() * 0.5
		var lean := 0.05 + rng.randf() * 0.09
		var top := 0.26 + rng.randf() * 0.12
		var tip := Vector3(sin(a) * lean, top, cos(a) * lean)
		for k in range(5):
			var bud := _sphere(0.013 - float(k) * 0.0012, 5, 3)
			parts.append(_place(bud,
				Vector3(tip.x * (1.0 + float(k) * 0.04),
					tip.y + 0.005 + float(k) * 0.022,
					tip.z * (1.0 + float(k) * 0.04)),
				Vector3(1.0, 1.5, 1.0)))
	return _merge(parts)

static func _sunflower_stem() -> ArrayMesh:
	var parts: Array = [[_tube_stem(0.98, 0.018, 0.03, 0.06), Transform3D.IDENTITY]]
	for entry in [[0.28, 0.3, 1.0], [0.46, 2.6, 0.95],
			[0.63, 4.6, 0.85], [0.80, 1.4, 0.7]]:
		var y: float = entry[0]
		var a: float = entry[1]
		var s: float = entry[2]
		var leaf := _sphere(0.075 * s, 7, 5)
		parts.append(_place(leaf, Vector3(0.0, y, 0.1 * s),
			Vector3(1.0, 0.12, 1.35), Vector3(-0.35, a, 0.0)))
	return _merge(parts)

static func _sunflower_bloom() -> ArrayMesh:
	# G5: the dark disc and yellow rays live in the bloom mesh and carry their
	# two-tone vertex colours; the separate sunflowerDisc kind is gone.
	var ray_color := Color(1.0, 0.78, 0.12)
	var parts := []
	for i in range(18):
		var angle := float(i) * TAU / 18.0
		var petal := _tint_mesh(_sphere(0.024, 5, 3), ray_color)
		parts.append(_place(petal,
			Vector3(cos(angle) * 0.11, 1.0, sin(angle) * 0.11),
			Vector3(1.0, 2.3, 0.35),
			Vector3(-0.2, angle + PI * 0.5, 0.0)))
	var disc := _tint_mesh(_cylinder(0.075, 0.08, 0.035, 12),
		Color(0.32, 0.19, 0.08))
	parts.append(_place(disc, Vector3(0.0, 1.0, 0.0), Vector3.ONE,
		Vector3(PI * 0.5, 0.0, 0.0)))
	return _merge(parts)

static func _tint_mesh(mesh: Mesh, color: Color) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _foxglove_stem() -> ArrayMesh:
	var parts: Array = [[_tube_stem(0.62, 0.008, 0.0, 0.015), Transform3D.IDENTITY]]
	for i in range(7):
		parts.append([_strap_mesh(float(i) * 0.9, 0.15, 0.04, 0.75),
			Transform3D.IDENTITY])
	var bud := CylinderMesh.new()
	bud.top_radius = 0.0
	bud.bottom_radius = 0.01
	bud.height = 0.05
	bud.radial_segments = 5
	bud.rings = 1
	parts.append(_place(bud, Vector3(0.0, 0.64, 0.015), Vector3.ONE))
	return _merge(parts)

static func _foxglove_bloom() -> ArrayMesh:
	var parts := []
	var tip := Vector3(0.0, 0.62, 0.015)
	for k in range(14):
		var u := float(k) / 13.0
		var y := 0.32 + u * 0.29
		var a := float(k) * 2.2
		var size := 1.15 - u * 0.65
		var bell := CylinderMesh.new()
		bell.top_radius = 0.018 * size
		bell.bottom_radius = 0.009 * size
		bell.height = 0.05 * size
		bell.radial_segments = 7
		bell.rings = 1
		bell.cap_top = false
		bell.cap_bottom = false
		parts.append(_place(bell,
			Vector3(sin(a) * 0.025 + tip.x * u, y - 0.025 * size,
				cos(a) * 0.025 + tip.z * u),
			Vector3.ONE, Vector3(1.1, a, 0.0)))
	return _merge(parts)

static func _rose_bloom() -> ArrayMesh:
	var petal := _sphere(0.024, 5, 3)
	var parts := []
	for ring in range(3):
		for i in range(5):
			var angle := float(i) * TAU / 5.0 + float(ring) * 0.6
			parts.append(_place(petal,
				Vector3(cos(angle) * (0.01 + ring * 0.018), 0.02 + ring * 0.01,
					sin(angle) * (0.01 + ring * 0.018)),
				Vector3(1.0, 1.0, 0.55),
				Vector3(-0.9 + ring * 0.35, angle, 0.0)))
	return _merge(parts)

static func _generic_stem() -> ArrayMesh:
	return _merge([
		[_tube_stem(0.4, 0.005), Transform3D.IDENTITY],
		[_strap_mesh(0.6, 0.08, 0.016, 0.5), Transform3D.IDENTITY],
	])

static func _generic_head() -> ArrayMesh:
	var petal := _sphere(0.018, 5, 3)
	var parts := []
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		parts.append(_place(petal,
			Vector3(cos(angle) * 0.018, 0.41, sin(angle) * 0.018),
			Vector3(1.0, 0.35, 1.0),
			Vector3(0.0, angle, 0.0)))
	return _merge(parts)
