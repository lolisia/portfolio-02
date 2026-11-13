extends Node3D
class_name FarmLife

## Chickens and the roof weather vane/anemometer. The chicken behaviour is a
## compact version of src/farm-life.js: wander around the coop, pause, peck.

var world: FarmWorld
var footprints: Footprints
var weather_fx: WeatherFX
var chickens: Array = []
var vane_root: Node3D
var vane_arrow: Node3D
var vane_rotor: Node3D
var smoke: GPUParticles3D
var smoke_process: ParticleProcessMaterial
var smoke_material: StandardMaterial3D
var fish_school: Array = []
var next_leap := 4.0
var character
var bird: Node3D
var bird_wings: Array = []
var bird_state := "perched"
var bird_timer := 5.0
var bird_from := Vector3.ZERO
var bird_to := Vector3.ZERO
var bird_t := 0.0
var bird_phase := 0.0
var bird_duration := 2.0
var bird_perches: Array = []
var rotor_speed := 0.0
var time := 0.0
var wind := 3.0
var hour := 8.5
var weather := 0
var water_freeze := 0.0

var sphere: SphereMesh
var leg_mesh: CylinderMesh
var materials: Dictionary = {}

const WIND_HEADING := 1.22
const COOP_CENTER := Vector2(2.25, -0.35)
const COOP_DOOR := Vector2(2.25, -1.12)
const COOP_APRON := Vector2(2.25, 0.38)

var paths: FarmPaths

func build() -> void:
	sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	leg_mesh = CylinderMesh.new()
	leg_mesh.top_radius = 0.018
	leg_mesh.bottom_radius = 0.014
	leg_mesh.height = 0.19
	leg_mesh.radial_segments = 5
	leg_mesh.rings = 1
	_build_vane()
	_build_smoke()
	_build_flock()
	_build_fish()
	_build_bird()

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.87
	materials[key] = mat
	return mat

func _egg(parent: Node3D, color: Color, x: float, y: float, z: float,
		w: float, h: float, d: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = _material(color)
	mi.position = Vector3(x, y, z)
	mi.scale = Vector3(w, h, d)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node3D, mesh: CylinderMesh, material: StandardMaterial3D,
		x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _box(parent: Node3D, material: StandardMaterial3D, x: float, y: float, z: float,
		w: float, h: float, d: float) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = material
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

func _build_vane() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.31, 0.30, 0.25)
	metal.metallic = 0.65
	metal.roughness = 0.46
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.71, 0.60, 0.38)
	brass.metallic = 0.65
	brass.roughness = 0.42

	vane_root = Node3D.new()
	vane_root.name = "RoofWeatherVane"
	vane_root.position = world.cottage_ridge
	add_child(vane_root)

	var mast := CylinderMesh.new()
	mast.top_radius = 0.025
	mast.bottom_radius = 0.04
	mast.height = 0.9
	mast.radial_segments = 8
	_cylinder(vane_root, mast, metal, 0.0, 0.45, 0.0)

	_box(vane_root, metal, 0.0, 0.33, 0.0, 1.05, 0.025, 0.025)
	_box(vane_root, metal, 0.0, 0.33, 0.0, 0.025, 0.025, 1.05)

	vane_arrow = Node3D.new()
	vane_arrow.position.y = 0.82
	vane_root.add_child(vane_arrow)
	_box(vane_arrow, metal, 0.0, 0.0, 0.0, 0.045, 0.045, 1.35)
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.15
	head.height = 0.3
	head.radial_segments = 3
	var head_mesh := _cylinder(vane_arrow, head, brass, 0.0, 0.0, 0.8)
	head_mesh.rotation.x = PI * 0.5
	_box(vane_arrow, brass, 0.0, 0.05, -0.62, 0.26, 0.18, 0.025)
	var hub := SphereMesh.new()
	hub.radius = 0.065
	hub.height = 0.13
	hub.radial_segments = 10
	hub.rings = 6
	var hub_mesh := MeshInstance3D.new()
	hub_mesh.mesh = hub
	hub_mesh.material_override = brass
	vane_arrow.add_child(hub_mesh)
	vane_arrow.add_child(_rooster_silhouette())

	vane_rotor = Node3D.new()
	vane_rotor.position.y = 1.65
	vane_root.add_child(vane_rotor)
	var rotor_mast := CylinderMesh.new()
	rotor_mast.top_radius = 0.018
	rotor_mast.bottom_radius = 0.018
	rotor_mast.height = 0.8
	rotor_mast.radial_segments = 8
	_cylinder(vane_root, rotor_mast, metal, 0.0, 1.24, 0.0)
	var cup_mesh := SphereMesh.new()
	cup_mesh.radius = 0.115
	cup_mesh.height = 0.23
	cup_mesh.radial_segments = 10
	cup_mesh.rings = 6
	for i in range(3):
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / 3.0
		vane_rotor.add_child(arm)
		_box(arm, metal, 0.19, 0.0, 0.0, 0.38, 0.025, 0.025)
		var cup := MeshInstance3D.new()
		cup.mesh = cup_mesh
		cup.material_override = brass
		cup.position = Vector3(0.4, 0.0, 0.0)
		cup.rotation.x = PI * 0.5
		cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		arm.add_child(cup)

func _rooster_silhouette() -> MeshInstance3D:
	# Traditional brass rooster cut-out, drawn as a 2D silhouette texture so the
	# shape stays crisp at diorama distance without a CSG/extrusion dependency.
	var points := PackedVector2Array([
		Vector2(-0.37, 0.10), Vector2(-0.55, 0.25), Vector2(-0.62, 0.55),
		Vector2(-0.48, 0.66), Vector2(-0.56, 0.50), Vector2(-0.27, 0.55),
		Vector2(-0.03, 0.28), Vector2(0.14, 0.30), Vector2(0.18, 0.55),
		Vector2(0.13, 0.65), Vector2(0.21, 0.62), Vector2(0.25, 0.71),
		Vector2(0.30, 0.63), Vector2(0.37, 0.66), Vector2(0.36, 0.56),
		Vector2(0.46, 0.51), Vector2(0.34, 0.47), Vector2(0.36, 0.36),
		Vector2(0.24, 0.29), Vector2(0.22, 0.18), Vector2(0.10, 0.06),
		Vector2(-0.20, 0.03),
	])
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var brass := Color(0.71, 0.60, 0.38)
	for y in range(128):
		for x in range(128):
			var p := Vector2(
				(float(x) - 64.0) / 105.0,
				0.36 - (float(y) - 64.0) / 105.0)
			if _point_in_polygon(p, points):
				image.set_pixel(x, y, brass)
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color.WHITE
	material.metallic = 0.65
	material.roughness = 0.42
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "RoosterSilhouette"
	mesh.mesh = quad
	mesh.position = Vector3(0.0, 0.34, 0.0)
	mesh.rotation.y = PI * 0.5
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func _point_in_polygon(p: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[j]
		if ((a.y > p.y) != (b.y > p.y)) and (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside

func _build_smoke() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (x - 31.5) / 31.5
			var dy := (y - 31.5) / 31.5
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	var texture := ImageTexture.create_from_image(image)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color(0.58, 0.58, 0.55, 0.42)
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 0.75)
	quad.material = material

	smoke = GPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.amount = 144
	smoke.lifetime = 32.0
	smoke.preprocess = 18.0
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-14, -4, -14), Vector3(28, 32, 28))
	smoke.draw_pass_1 = quad
	smoke.position = world.cottage_chimney + Vector3(0, 0.1, 0)
	smoke_process = ParticleProcessMaterial.new()
	smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke_process.emission_sphere_radius = 0.14
	smoke_process.direction = Vector3(0, 1, 0)
	smoke_process.spread = 13.0
	smoke_process.initial_velocity_min = 0.28
	smoke_process.initial_velocity_max = 0.75
	smoke_process.gravity = Vector3(0, 0.22, 0)
	smoke_process.lifetime_randomness = 0.38
	smoke_process.angular_velocity_min = -18.0
	smoke_process.angular_velocity_max = 18.0
	smoke_process.scale_min = 0.38
	smoke_process.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.08, Color(1, 1, 1, 0.50))
	ramp.add_point(0.55, Color(1, 1, 1, 0.22))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	smoke_process.color_ramp = ramp_texture
	smoke.process_material = smoke_process
	smoke_material = material
	add_child(smoke)

func set_night(night: float) -> void:
	if smoke_material != null:
		var shade := 1.0 - clampf(night, 0.0, 1.0) * 0.72
		smoke_material.albedo_color = Color(0.58 * shade, 0.58 * shade, 0.55 * shade, 0.42)

func _build_flock() -> void:
	paths = FarmPaths.new(world) if world != null else null
	var positions := [
		Vector2(2.1, -0.25), Vector2(2.7, -0.1), Vector2(1.5, 0.4),
		Vector2(3.0, 0.5), Vector2(2.2, 1.15), Vector2(3.5, 1.2),
	]
	for i in range(positions.size()):
		var chick := i >= 2
		var chicken := _chicken(chick, i)
		chicken["x"] = COOP_DOOR.x
		chicken["z"] = COOP_DOOR.y
		chicken["target"] = Vector2(positions[i].x, positions[i].y)
		chicken["wait"] = randf() * 2.0
		chicken["group"].position = Vector3(COOP_DOOR.x,
			world.height(COOP_DOOR.x, COOP_DOOR.y) + 0.65, COOP_DOOR.y)
		chicken["group"].visible = false
		chickens.append(chicken)

func _chicken(chick: bool, index: int) -> Dictionary:
	var group := Node3D.new()
	group.name = ("chick-" if chick else "hen-") + str(index)
	var feather := Color(0.894, 0.769, 0.478) if chick else (Color(0.718, 0.514, 0.322) if index else Color(0.902, 0.859, 0.737))
	_egg(group, feather, 0.0, 0.29, 0.0, 0.19, 0.23, 0.27)
	for side in [-1.0, 1.0]:
		_egg(group, Color(0.831, 0.702, 0.424) if chick else Color(0.624, 0.475, 0.322),
			float(side) * 0.16, 0.30, -0.02, 0.055, 0.15, 0.2)
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.46, 0.18)
	group.add_child(head)
	_egg(head, feather, 0.0, 0.03, 0.025, 0.12, 0.135, 0.13)
	_egg(head, Color(0.773, 0.600, 0.294), 0.0, -0.005, 0.16, 0.055, 0.035, 0.09)
	for side in [-1.0, 1.0]:
		_egg(head, Color(0.129, 0.122, 0.094), float(side) * 0.104, 0.065, 0.095, 0.018, 0.019, 0.018)
	if not chick:
		for i in range(3):
			_egg(head, Color(0.651, 0.302, 0.224), 0.0, 0.165 + i * 0.008, -0.035 + i * 0.045, 0.038, 0.057, 0.034)
		_egg(head, Color(0.651, 0.302, 0.224), 0.0, -0.085, 0.085, 0.042, 0.066, 0.035)
	var tail := _egg(group, Color(0.831, 0.702, 0.424) if chick else Color(0.482, 0.380, 0.282), 0.0, 0.37, -0.27, 0.12, 0.18, 0.075)
	tail.rotation.x = -0.5
	var legs: Array = []
	for side in [-1.0, 1.0]:
		legs.append(_cylinder(group, leg_mesh, _material(Color(0.663, 0.541, 0.322)),
			float(side) * 0.078, 0.1, 0.025))
	group.scale = Vector3.ONE * (0.48 if chick else 1.0)
	add_child(group)
	var body := world.add_body(COOP_DOOR.x, COOP_DOOR.y,
		0.09 if chick else 0.15, "chicken")
	body["ignore"] = "coop"
	body["active"] = false
	return {
		"group": group, "head": head, "legs": legs, "chick": chick, "index": index,
		"x": 0.0, "z": 0.0, "target": Vector2.ZERO, "wait": 0.0,
		"gait": randf() * 4.0, "speed": (0.31 if chick else 0.27) + randf() * 0.12,
		"state": "inside", "stride": -1, "flee": 0.0, "inside": false,
		"route": [], "pace": 0.0, "noticed": false, "intent": false,
		"reaction": 1.5 + randf() * 10.0, "flee_cool": 0.0, "stuck": 0.0,
		"retry": 0.0, "leg_speed": 1.0, "body": body,
	}

func _pick_target(c: Dictionary) -> Vector2:
	for i in range(8):
		var x := COOP_CENTER.x + randf_range(-1.9, 1.9)
		var z := COOP_CENTER.y + randf_range(-0.2, 3.2)
		if world.is_free(x, z, 0.18):
			return Vector2(x, z)
	return COOP_CENTER

func _fish_in_pond(x: float, z: float) -> bool:
	return world.wet(x, z) > 0.30 and world.height(x, z) < world.water.position.y - 0.20 and x < 12.6

func _pick_fish_target(f: Dictionary) -> Vector2:
	for i in range(12):
		var x := randf_range(7.4, 12.5)
		var z := randf_range(3.4, 9.0)
		if _fish_in_pond(x, z):
			return Vector2(x, z)
	return Vector2(10.0, 6.1)

func _build_fish() -> void:
	var palettes := [
		[Color(0.384, 0.475, 0.420), Color(0.678, 0.694, 0.545), Color(0.502, 0.420, 0.322)],
		[Color(0.541, 0.435, 0.298), Color(0.824, 0.698, 0.486), Color(0.608, 0.420, 0.239)],
		[Color(0.886, 0.863, 0.796), Color(0.949, 0.933, 0.886), Color(0.847, 0.471, 0.235)],
	]
	for i in range(10):
		var palette: Array = palettes[i % palettes.size()]
		var group := Node3D.new()
		group.name = "fish-" + str(i)
		add_child(group)
		var body := _egg(group, palette[0], 0, 0, 0, 0.092, 0.12, 0.34)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var belly := _egg(group, palette[1], 0, -0.055, 0.07, 0.073, 0.065, 0.21)
		belly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tail := _egg(group, palette[2], 0, 0, -0.36, 0.028, 0.14, 0.14)
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in [-1.0, 1.0]:
			var eye := _egg(group, Color(0.153, 0.157, 0.114), float(s) * 0.074, 0.024, 0.208, 0.016, 0.016, 0.016)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var scale := 0.62 + 0.3 * float((i * 37) % 10) / 10.0
		group.scale = Vector3.ONE * scale
		var target := _pick_fish_target({})
		fish_school.append({
			"group": group, "tail": tail, "x": target.x, "z": target.y,
			"target": target, "depth": randf_range(0.18, 0.48),
			"speed": randf_range(0.22, 0.38), "phase": randf() * 9.0,
			"leap": -1.0,
		})
		group.position = Vector3(target.x, world.water.position.y - 0.3, target.y)

func _bird_ellipsoid(parent: Node3D, color: Color, x: float, y: float, z: float,
		w: float, h: float, d: float) -> MeshInstance3D:
	var mi := _egg(parent, color, x, y, z, w, h, d)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

func _build_bird() -> void:
	bird = Node3D.new()
	bird.name = "PerchingBird"
	add_child(bird)
	_bird_ellipsoid(bird, Color(0.502, 0.384, 0.290), 0, 0.11, 0, 0.12, 0.115, 0.21)
	_bird_ellipsoid(bird, Color(0.333, 0.314, 0.294), 0, 0.22, 0.13, 0.101, 0.106, 0.11)
	_bird_ellipsoid(bird, Color(0.898, 0.757, 0.604), 0, 0.14, 0.13, 0.092, 0.083, 0.095)
	_bird_ellipsoid(bird, Color(0.757, 0.588, 0.345), 0, 0.20, 0.235, 0.044, 0.028, 0.067)
	for s in [-1.0, 1.0]:
		_bird_ellipsoid(bird, Color(0.129, 0.118, 0.110), float(s) * 0.083, 0.241, 0.172, 0.015, 0.015, 0.015)
	_bird_ellipsoid(bird, Color(0.298, 0.271, 0.243), 0, 0.12, -0.217, 0.063, 0.043, 0.158)
	for s in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(float(s) * 0.069, 0.15, -0.013)
		bird.add_child(wing)
		_bird_ellipsoid(wing, Color(0.408, 0.345, 0.290), float(s) * 0.15, 0, -0.03, 0.205, 0.031, 0.103)
		_bird_ellipsoid(wing, Color(0.271, 0.243, 0.220), float(s) * 0.295, 0, -0.094, 0.124, 0.021, 0.055)
		bird_wings.append(wing)
	bird.scale = Vector3.ONE * 1.35

	for tree in FarmWorld.TREE_LIST:
		var x: float = tree[0]
		var z: float = tree[1]
		var s: float = tree[2]
		bird_perches.append(Vector3(x + 0.36 * s, world.height(x, z) + 3.97 * s, z + 0.25 * s))
	for lamp in world.lamps:
		var p: Vector3 = lamp.position
		bird_perches.append(p + Vector3(0, 0.08, 0))
	bird_perches.append(world.cottage_ridge + Vector3(0, 0.22, 0))
	bird.position = bird_perches[bird_perches.size() - 1]
	bird_timer = 6.0

func _update_fish(delta: float) -> void:
	var water_y: float = world.water.position.y
	var frozen := water_freeze > 0.15
	next_leap -= delta
	if not frozen and next_leap <= 0.0:
		var jumper: Dictionary = fish_school[randi() % fish_school.size()]
		var jumper_group: Node3D = jumper["group"]
		var heading: float = jumper_group.rotation.y
		if float(jumper["leap"]) < 0.0 and _fish_in_pond(
				float(jumper["x"]) + sin(heading) * 1.4,
				float(jumper["z"]) + cos(heading) * 1.4):
			jumper["leap"] = 0.0
			if weather_fx != null:
				weather_fx.splash(float(jumper["x"]), float(jumper["z"]))
		next_leap = 4.0 + randf() * 8.0
	for f in fish_school:
		var fish_group: Node3D = f.group
		fish_group.visible = not frozen
		if frozen:
			continue
		if float(f["leap"]) >= 0.0:
			f["leap"] = float(f["leap"]) + delta / 1.15
			var u := minf(1.0, float(f["leap"]))
			var heading: float = fish_group.rotation.y
			f.x += sin(heading) * delta * 1.15
			f.z += cos(heading) * delta * 1.15
			fish_group.position = Vector3(f.x, water_y - 0.22 + sin(PI * u) * 0.95, f.z)
			fish_group.rotation.x = -0.95 * cos(PI * u)
			var tail: MeshInstance3D = f.tail
			tail.rotation.y = sin(time * 22.0) * 0.5
			if float(f["leap"]) >= 1.0:
				f["leap"] = -1.0
				fish_group.rotation.x = 0.0
				if weather_fx != null:
					weather_fx.splash(float(f.x), float(f.z))
				f.target = _pick_fish_target(f)
			continue
		var flat := Vector2(f.target.x - f.x, f.target.y - f.z)
		if flat.length() < 0.16:
			f.target = _pick_fish_target(f)
			continue
		var direction := flat.normalized()
		var step := minf(f.speed * delta, flat.length())
		f.x += direction.x * step
		f.z += direction.y * step
		var group: Node3D = f.group
		group.position = Vector3(f.x, water_y - f.depth, f.z)
		group.rotation.y = lerp_angle(group.rotation.y, atan2(direction.x, direction.y), 1.0 - exp(-delta * 4.0))
		var tail: MeshInstance3D = f.tail
		tail.rotation.y = sin(time * 9.0 + f.phase) * 0.38

func _update_bird(delta: float) -> void:
	if bird == null:
		return
	if bird_state == "perched":
		bird_timer -= delta
		bird.rotation.x = 0.05 * pow(maxf(0.0, sin(time * 0.7)), 8.0)
		bird.rotation.z = sin(time * 2.4) * 0.033
		for i in range(bird_wings.size()):
			var wing: Node3D = bird_wings[i]
			wing.rotation.z = lerp(wing.rotation.z, float(-1 if i == 0 else 1) * 0.12, 1.0 - exp(-delta * 5.0))
		if bird_timer <= 0.0:
			bird_from = bird.position
			var next = bird_perches[randi() % bird_perches.size()]
			if next.distance_to(bird_from) < 0.5 and bird_perches.size() > 1:
				next = bird_perches[(randi() + 1) % bird_perches.size()]
			bird_to = next
			bird_t = 0.0
			bird_phase = 0.28
			bird_duration = clampf(bird_from.distance_to(bird_to) * 0.28, 1.6, 4.2)
			bird_state = "takeoff"
	elif bird_state == "takeoff":
		bird_phase = maxf(0.0, bird_phase - delta)
		var lift := 1.0 - bird_phase / 0.28
		bird.position = bird_from + Vector3(0.0, -0.03 * sin(lift * PI), 0.0)
		bird.rotation.x = 0.25 * sin(lift * PI)
		for i in range(bird_wings.size()):
			var wing_takeoff: Node3D = bird_wings[i]
			wing_takeoff.rotation.z = lerp(wing_takeoff.rotation.z,
				float(-1 if i == 0 else 1) * 0.45, 1.0 - exp(-delta * 18.0))
		if bird_phase <= 0.001:
			bird_state = "flying"
	elif bird_state == "flying":
		bird_t = minf(1.0, bird_t + delta / bird_duration)
		var pos := bird_from.lerp(bird_to, bird_t)
		pos.y += sin(bird_t * PI) * (0.5 + bird_from.distance_to(bird_to) * 0.16)
		bird.position = pos
		var ahead := bird_to - bird_from
		bird.rotation.y = atan2(ahead.x, ahead.z)
		bird.rotation.x = -sin(bird_t * PI) * 0.45
		for i in range(bird_wings.size()):
			var wing2: Node3D = bird_wings[i]
			wing2.rotation.z = float(-1 if i == 0 else 1) * (0.45 + sin(time * 18.0) * 0.55)
		if bird_t >= 1.0:
			bird.position = bird_to
			bird_state = "landing"
			bird_phase = 0.7
	else:
		# Landing flare: rock forward, then fold the wings and settle.
		bird_phase = maxf(0.0, bird_phase - delta)
		var age := 0.7 - bird_phase
		var settle := clampf(age / 0.7, 0.0, 1.0)
		bird.position = bird_to + Vector3(0.0,
			-0.035 * sin(PI * minf(1.0, age / 0.35)) * (1.0 - settle), 0.0)
		bird.rotation.x = -0.75 * exp(-age * 7.0) * cos(age * 11.0) + 0.12 * sin(PI * settle) * (1.0 - settle)
		for i in range(bird_wings.size()):
			var wing_land: Node3D = bird_wings[i]
			var folded := lerpf(0.45, 0.12, smoothstep(0.0, 0.7, age))
			wing_land.rotation.z = float(-1 if i == 0 else 1) * folded
		if bird_phase <= 0.001:
			bird.position = bird_to
			bird_state = "perched"
			bird.rotation.x = 0.0
			bird_timer = 6.0 + randf() * 8.0

## Walker discs for the turf trample shader: one per visible chicken.
func tramplers() -> Array:
	var result: Array = []
	for c in chickens:
		var group: Node3D = c["group"]
		if not group.visible:
			continue
		result.append({
			"id": "chicken-%d" % int(c["index"]),
			"x": float(c["x"]), "z": float(c["z"]),
			"r": 0.09 if c["chick"] else 0.15,
			"active": true,
		})
	return result

func _process(delta: float) -> void:
	if world == null:
		return
	time += delta
	_update_fish(delta)
	_update_bird(delta)
	var outside := hour >= 6.0 and hour < 18.0 and (weather <= 1 or weather == 4) and wind < 11.0
	var gust := sin(time * 1.37) + 0.42 * sin(time * 2.31)
	var target_heading := WIND_HEADING + gust * 0.11 * minf(1.0, wind / 8.0)
	vane_arrow.rotation.y = lerp_angle(vane_arrow.rotation.y, target_heading, 1.0 - exp(-delta * (1.0 + wind * 0.35)))
	rotor_speed = lerp(rotor_speed, wind * 0.7, 1.0 - exp(-delta * 1.8))
	vane_rotor.rotation.y += delta * rotor_speed
	if smoke_process != null:
		smoke_process.gravity = Vector3(wind * 0.055, 0.22, wind * 0.028)

	_update_chickens(delta, outside)

func _update_chickens(delta: float, outside: bool) -> void:
	var threat := Vector2(1e9, 1e9)
	if character != null and character.model != null and character.model.visible:
		threat = Vector2(character.position.x, character.position.z)
	for c in chickens:
		var group: Node3D = c["group"]
		var c_body: Dictionary = c["body"]
		c_body["active"] = group.visible
		c_body["x"] = float(c["x"])
		c_body["z"] = float(c["z"])
		if bool(c["noticed"]) != outside:
			c["noticed"] = outside
			c["reaction"] = (1.5 + randf() * 10.0) if outside \
				else ((1.0 + randf() * 6.0) if weather >= 2 else (3.0 + randf() * 11.0))
		c["reaction"] = maxf(0.0, float(c["reaction"]) - delta)
		if float(c["reaction"]) <= 0.0:
			c["intent"] = outside
		if c["state"] == "inside":
			group.visible = false
			c["pace"] = 0.0
			if bool(c["intent"]):
				c["state"] = "exiting"
				c["x"] = COOP_DOOR.x
				c["z"] = COOP_DOOR.y
				c["route"] = [COOP_APRON]
				group.visible = true
				c["wait"] = 0.0
				c["pace"] = 0.0
			continue
		if not bool(c["intent"]) and c["state"] != "returning":
			c["state"] = "returning"
			c["wait"] = 0.4 + randf() * 1.8
			_set_chicken_trip(c, true)
		c["retry"] = maxf(0.0, float(c["retry"]) - delta)
		var here := Vector2(float(c["x"]), float(c["z"]))
		if c["state"] == "foraging" and float(c["wait"]) > 0.0 \
				and _in_coop_entrance(here):
			c["wait"] = 0.0
			if (c["route"] as Array).is_empty():
				_set_chicken_trip(c, false)
		c["flee_cool"] = maxf(0.0, float(c["flee_cool"]) - delta)
		if threat.x < 1e8 and (c["state"] == "foraging" or c["state"] == "fleeing") \
				and float(c["flee_cool"]) <= 0.0 and here.distance_to(threat) < 1.5:
			_chicken_flee(c, threat)
		var moving := false
		if float(c["wait"]) > 0.0:
			c["wait"] = maxf(0.0, float(c["wait"]) - delta)
			c["pace"] = lerpf(float(c["pace"]), 0.0, 1.0 - exp(-delta * 6.0))
		elif c["state"] == "exiting":
			moving = true
			if _chicken_walk(c, delta, 0.85):
				c["state"] = "foraging"
				c["wait"] = 0.0
				_set_chicken_trip(c, false)
		elif c["state"] == "returning":
			moving = true
			if _chicken_walk(c, delta, 1.25):
				c["state"] = "inside"
				group.visible = false
				c["pace"] = 0.0
				continue
		elif c["state"] == "fleeing":
			moving = true
			if _chicken_walk(c, delta, 3.0):
				c["state"] = "foraging"
				c["wait"] = 0.4 + randf() * 1.2
				c["leg_speed"] = 0.7 + randf() * 0.65
		elif c["state"] == "foraging":
			moving = true
			if _chicken_walk(c, delta, 1.0):
				moving = false
				c["wait"] = 2.0 + randf() * 6.0
				_set_chicken_trip(c, false)
			elif randf() < delta * 0.025 and not _in_coop_entrance(here):
				c["wait"] = 0.8 + randf() * 2.5
		if not group.visible:
			continue
		var x := float(c["x"])
		var z := float(c["z"])
		var ramp := 0.0
		if absf(x - COOP_DOOR.x) < 0.5:
			ramp = clampf((0.35 - z) / 1.47, 0.0, 1.0) * 0.65
		group.position = Vector3(x, world.height(x, z) + ramp, z)
		group.rotation.z = sin(float(c["gait"])) * 0.017 if moving else 0.0
		var head: Node3D = c["head"]
		var peck := 0.0
		if not moving and c["state"] == "foraging":
			peck = 0.2 + maxf(0.0, sin(time * (2.1 + float(c["index"]) * 0.19)
				+ float(c["index"]) * 0.53)) * 0.95
		head.rotation.x = lerp(head.rotation.x, peck, 1.0 - exp(-delta * 5.0))
		var legs: Array = c["legs"]
		for i in range(legs.size()):
			var leg: MeshInstance3D = legs[i]
			leg.rotation.x = sin(float(c["gait"]) + float(i) * PI) * 0.28 if moving else 0.0
		var stride := int(floor(float(c["gait"]) / PI))
		if footprints != null and moving and ramp == 0.0 and stride != int(c["stride"]):
			var heading: float = group.rotation.y
			var side := 1.0 if stride % 2 else -1.0
			var chick_scale := 0.48 if c["chick"] else 1.0
			footprints.press("claw",
				x + cos(heading) * side * 0.075 * chick_scale,
				z - sin(heading) * side * 0.075 * chick_scale,
				heading, chick_scale * (0.9 + 0.2 * randf()))
		c["stride"] = stride

func _in_coop_entrance(point: Vector2) -> bool:
	return absf(point.x - COOP_DOOR.x) < 0.6 \
		and point.y > COOP_DOOR.y - 0.2 and point.y < COOP_APRON.y + 0.75

func _set_chicken_trip(c: Dictionary, home: bool) -> void:
	if paths == null:
		c["route"] = [_pick_target(c)]
		return
	var current := Vector2(float(c["x"]), float(c["z"]))
	if home:
		var route: Array = paths.route(world, current, COOP_APRON)
		route.append(COOP_DOOR)
		c["route"] = route
		return
	if float(c["retry"]) > 0.0:
		return
	c["retry"] = 0.5
	var far := randf() > 0.42
	var candidates: Array[Vector2] = []
	for node in paths.nodes:
		if node.has("porch"):
			continue
		var p := Vector2(float(node["x"]), float(node["z"]))
		var radius := p.distance_to(COOP_APRON)
		if radius > (3.5 if far else 1.0) and radius < (9.0 if far else 4.0) \
				and p.distance_to(current) > 1.0 and not _in_coop_entrance(p):
			candidates.append(p)
	for i in range(8):
		if candidates.is_empty():
			break
		var target := candidates[randi() % candidates.size()]
		var route2: Array = paths.route(world, current, target)
		if not route2.is_empty():
			c["route"] = route2
			break
	if (c["route"] as Array).is_empty():
		c["route"] = [_pick_target(c)]
	c["leg_speed"] = 0.7 + randf() * 0.65

func _chicken_flee(c: Dictionary, threat: Vector2) -> void:
	var current := Vector2(float(c["x"]), float(c["z"]))
	var away := current - threat
	var length := maxf(away.length(), 0.001)
	var ax := away.x / length
	var az := away.y / length
	var best: Vector2 = Vector2.ZERO
	var best_score := -INF
	if paths != null:
		for node in paths.nodes:
			if node.has("porch"):
				continue
			var p := Vector2(float(node["x"]), float(node["z"]))
			var reach := p.distance_to(current)
			if reach < 1.3 or reach > 3.4 or _in_coop_entrance(p):
				continue
			var facing := ((p.x - current.x) * ax + (p.y - current.y) * az) / reach
			if facing < 0.45:
				continue
			var value := p.distance_to(threat) + facing + randf() * 0.6
			if value > best_score:
				best_score = value
				best = p
	var route: Array = paths.route(world, current, best) if best_score > -INF else []
	if route.is_empty():
		route = [current + Vector2(ax, az) * 1.4]
	c["route"] = route
	c["state"] = "fleeing"
	c["wait"] = 0.0
	c["flee_cool"] = 0.7
	c["leg_speed"] = 1.15 + randf() * 0.3

func _chicken_walk(c: Dictionary, delta: float, multiplier: float) -> bool:
	var route: Array = c["route"]
	if route.is_empty():
		c["pace"] = lerpf(float(c["pace"]), 0.0, 1.0 - exp(-delta * 5.0))
		return true
	var target: Vector2 = route[0]
	var x := float(c["x"])
	var z := float(c["z"])
	var dx := target.x - x
	var dz := target.y - z
	var distance := sqrt(dx * dx + dz * dz)
	var desired := float(c["speed"]) * float(c["leg_speed"]) * multiplier \
		* (0.9 + 0.1 * sin(float(c["gait"]) * 0.17 + float(c["index"])))
	c["pace"] = lerpf(float(c["pace"]), desired, 1.0 - exp(-delta * 2.8))
	var step := minf(distance, float(c["pace"]) * delta)
	var moved := 0.0
	if distance > 0.001:
		var nx := x + dx / distance * step
		var nz := z + dz / distance * step
		var radius := 0.09 if c["chick"] else 0.15
		var resolved := world.resolve_body(Vector2(nx, nz), radius, c["body"])
		var moved_vec := resolved - Vector2(x, z)
		x = resolved.x
		z = resolved.y
		moved = moved_vec.length()
		c["x"] = x
		c["z"] = z
		c["body"]["x"] = x
		c["body"]["z"] = z
		c["stuck"] = (float(c["stuck"]) + delta) if moved < step * 0.3 else 0.0
		if float(c["stuck"]) > 1.5:
			c["stuck"] = 0.0
			route.pop_front()
		var group: Node3D = c["group"]
		group.rotation.y = lerp_angle(group.rotation.y, atan2(dx, dz),
			1.0 - exp(-delta * 5.0))
		c["gait"] = float(c["gait"]) + moved / (0.045 if c["chick"] else 0.085)
	if distance < 0.045:
		route.pop_front()
	return route.is_empty()
