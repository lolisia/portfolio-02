extends Node3D
class_name FarmLife

## Chickens and the roof weather vane/anemometer. The chicken behaviour is a
## compact version of src/farm-life.js: wander around the coop, pause, peck.

var world: FarmWorld
var chickens: Array = []
var vane_root: Node3D
var vane_arrow: Node3D
var vane_rotor: Node3D
var smoke: GPUParticles3D
var smoke_process: ParticleProcessMaterial
var rotor_speed := 0.0
var time := 0.0
var wind := 3.0
var hour := 8.5
var weather := 0

var sphere: SphereMesh
var leg_mesh: CylinderMesh
var materials: Dictionary = {}

const WIND_HEADING := 1.22
const COOP_CENTER := Vector2(2.25, -0.35)

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
	smoke.amount = 70
	smoke.lifetime = 9.0
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 18, 24))
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
	smoke_process.lifetime_randomness = 0.3
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
	add_child(smoke)

func _build_flock() -> void:
	var positions := [
		Vector2(2.1, -0.25), Vector2(2.7, -0.1), Vector2(1.5, 0.4),
		Vector2(3.0, 0.5), Vector2(2.2, 1.15), Vector2(3.5, 1.2),
	]
	for i in range(positions.size()):
		var chick := i >= 2
		var chicken := _chicken(chick, i)
		chicken["x"] = positions[i].x
		chicken["z"] = positions[i].y
		chicken["target"] = Vector2(positions[i].x, positions[i].y)
		chicken["wait"] = randf() * 2.0
		chicken["group"].position = Vector3(positions[i].x, world.height(positions[i].x, positions[i].y), positions[i].y)
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
	return {
		"group": group, "head": head, "legs": legs, "chick": chick, "index": index,
		"x": 0.0, "z": 0.0, "target": Vector2.ZERO, "wait": 0.0,
		"gait": randf() * 4.0, "speed": (0.31 if chick else 0.27) + randf() * 0.12,
		"state": "foraging",
	}

func _pick_target(c: Dictionary) -> Vector2:
	for i in range(8):
		var x := COOP_CENTER.x + randf_range(-1.9, 1.9)
		var z := COOP_CENTER.y + randf_range(-0.2, 3.2)
		if world.is_free(x, z, 0.18):
			return Vector2(x, z)
	return COOP_CENTER

func _process(delta: float) -> void:
	if world == null:
		return
	time += delta
	var outside := hour >= 6.0 and hour < 19.0 and (weather <= 1 or weather == 4) and wind < 11.0
	var gust := sin(time * 1.37) + 0.42 * sin(time * 2.31)
	var target_heading := WIND_HEADING + gust * 0.11 * minf(1.0, wind / 8.0)
	vane_arrow.rotation.y = lerp_angle(vane_arrow.rotation.y, target_heading, 1.0 - exp(-delta * (1.0 + wind * 0.35)))
	rotor_speed = lerp(rotor_speed, wind * 0.7, 1.0 - exp(-delta * 1.8))
	vane_rotor.rotation.y += delta * rotor_speed
	if smoke_process != null:
		smoke_process.gravity = Vector3(wind * 0.055, 0.22, wind * 0.028)

	for c in chickens:
		var group: Node3D = c["group"]
		group.visible = outside
		if not outside:
			continue
		if c.wait > 0.0:
			c.wait = maxf(0.0, c.wait - delta)
			c.state = "pecking"
			var head: Node3D = c["head"]
			var peck := 0.2 + maxf(0.0, sin(time * (2.1 + c.index * 0.19))) * 0.95
			head.rotation.x = lerp(head.rotation.x, peck, 1.0 - exp(-delta * 5.0))
		else:
			var target: Vector2 = c.target
			var flat := target - Vector2(c.x, c.z)
			if flat.length() < 0.07:
				c.target = _pick_target(c)
				c.wait = 1.8 + randf() * 5.0
				c.state = "pecking"
				continue
			c.state = "foraging"
			var direction := flat.normalized()
			var step := minf(c.speed * delta, flat.length())
			c.x += direction.x * step
			c.z += direction.y * step
			c.gait += step / (0.045 if c.chick else 0.085)
			group.position = Vector3(c.x, world.height(c.x, c.z), c.z)
			group.rotation.y = lerp_angle(group.rotation.y, atan2(direction.x, direction.y), 1.0 - exp(-delta * 5.0))
			group.rotation.z = sin(c.gait) * 0.017
			var head2: Node3D = c["head"]
			head2.rotation.x = lerp(head2.rotation.x, 0.08, 1.0 - exp(-delta * 5.0))
			var legs: Array = c["legs"]
			for i in range(legs.size()):
				var leg: MeshInstance3D = legs[i]
				leg.rotation.x = sin(c.gait + i * PI) * 0.28
