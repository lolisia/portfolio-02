extends Node3D

## Port of the remaining cascade details from src/cascade.js:
## 900 soft droplets (300 shed from the curtain + 600 splashing at the foot),
## the churning foam disc, and 24 wind-blown vapour sprites. The curtain and
## rocks live in world.gd; this node only owns the animated extras.

const DROP_COUNT := 900
const CURTAIN_DROPS := 300
const VAPOR_COUNT := 24

var left := 4.25
var width := 3.1
var drop := 2.92
var floor_y := -2.48
var foot_y := -2.21
var path_fn: Callable

var freeze := 0.0
var flow := 1.0
var time := 0.0
var wind := 3.0
var light := 1.0
var rng := RandomNumberGenerator.new()

var drop_instance: MultiMeshInstance3D
var drop_multimesh: MultiMesh
var drop_states: Array = []
var drop_buffer := PackedFloat32Array()
var foam: MeshInstance3D
var foam_material: ShaderMaterial
var vapor: Array[Sprite3D] = []

func setup(p_left: float, p_width: float, p_drop: float, p_floor: float,
		p_path_fn: Callable) -> void:
	left = p_left
	width = p_width
	drop = p_drop
	floor_y = p_floor
	foot_y = floor_y + 0.27
	path_fn = p_path_fn
	rng.seed = 68113
	_build_drops()
	_build_foam()
	_build_vapor()

func _soft_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var a := pow(clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0), 2.4)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)

func _build_drops() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_texture()
	material.albedo_color = Color(0.82, 0.90, 0.92, 1.0)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = material

	drop_multimesh = MultiMesh.new()
	drop_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	drop_multimesh.use_colors = true
	drop_multimesh.mesh = quad
	var count := 360 if MobileProfile.enabled() else DROP_COUNT
	drop_multimesh.instance_count = count
	drop_buffer.resize(count * 16)
	drop_instance = MultiMeshInstance3D.new()
	drop_instance.name = "CascadeDroplets"
	drop_instance.multimesh = drop_multimesh
	drop_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	drop_instance.custom_aabb = AABB(Vector3(12.5, floor_y - 1.0, 2.0),
		Vector3(6.0, 6.0, 9.0))
	drop_instance.visible = false
	add_child(drop_instance)
	for i in range(count):
		drop_states.append({
			"life": 1.0, "max": 1.0, "x": 0.0, "y": -999.0, "z": 0.0,
			"vx": 0.0, "vy": 0.0, "vz": 0.0, "size": 0.02,
			"splash": i >= count / 3,
		})

func _build_foam() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width * 0.55 + 0.2, width * 0.5 + 0.18) * 2.0
	foam_material = ShaderMaterial.new()
	foam_material.shader = preload("res://shaders/cascade_foam.gdshader")
	foam_material.set_shader_parameter("clock", 0.0)
	foam_material.set_shader_parameter("freeze", 0.0)
	foam_material.set_shader_parameter("opacity", 0.6)
	foam = MeshInstance3D.new()
	foam.name = "CascadeFoam"
	foam.mesh = plane
	foam.material_override = foam_material
	# PlaneMesh already lies in XZ; rotating it made a vertical foam stripe.
	var foot: Vector3 = path_fn.call(0.5, 1.0, 0.0)
	foam.position = Vector3(foot.x, foot_y + 0.01, foot.z)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.visible = false
	add_child(foam)

func _build_vapor() -> void:
	var texture := _soft_texture()
	for i in range(VAPOR_COUNT):
		var sprite := Sprite3D.new()
		sprite.name = "CascadeVapor" + str(i)
		sprite.texture = texture
		sprite.pixel_size = 1.0 / 64.0
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.double_sided = true
		sprite.modulate = Color(0.71, 0.80, 0.83, 0.0)
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.visible = false
		add_child(sprite)
		vapor.append(sprite)

func set_freeze(value: float) -> void:
	freeze = clampf(value, 0.0, 1.0)

func _spawn(drop_state: Dictionary) -> void:
	var across := rng.randf()
	if not bool(drop_state["splash"]):
		var t := 0.25 + 0.7 * rng.randf()
		var p: Vector3 = path_fn.call(across, t, 0.0)
		drop_state["x"] = p.x
		drop_state["y"] = p.y
		drop_state["z"] = p.z
		drop_state["vx"] = 0.7 + 0.5 * rng.randf() + wind * 0.04
		drop_state["vy"] = -2.0 * drop * t * 0.55 - rng.randf() * 0.5
		drop_state["vz"] = (across - 0.5) * 0.6 + (rng.randf() - 0.5) * 0.3
		drop_state["life"] = 0.0
		drop_state["max"] = 0.35 + rng.randf() * 0.5
		drop_state["size"] = 0.018 + rng.randf() * 0.03
	else:
		var p2: Vector3 = path_fn.call(across, 1.0, 0.0)
		var speed := 0.6 + rng.randf() * 1.5
		var angle := rng.randf() * TAU
		drop_state["x"] = p2.x + (rng.randf() - 0.4) * 0.25
		drop_state["y"] = foot_y
		drop_state["z"] = p2.z + (rng.randf() - 0.5) * 0.25
		drop_state["vx"] = cos(angle) * speed * 0.55 + 0.25
		drop_state["vy"] = 0.8 + rng.randf() * 1.7
		drop_state["vz"] = sin(angle) * speed * 0.55
		drop_state["life"] = 0.0
		drop_state["max"] = 0.45 + rng.randf() * 0.55
		drop_state["size"] = 0.02 + rng.randf() * 0.045

func update(delta: float, p_wind: float, p_light: float) -> void:
	time += delta
	wind = p_wind
	light = p_light
	flow = 1.0 - smoothstep(0.08, 0.92, freeze)
	if flow <= 0.002:
		drop_instance.visible = false
		foam.visible = false
		for sprite in vapor:
			sprite.visible = false
		return
	drop_instance.visible = true
	foam.visible = true
	foam_material.set_shader_parameter("clock", time)
	foam_material.set_shader_parameter("freeze", freeze)
	var dt := minf(delta, 0.05)
	for i in range(drop_states.size()):
		var d: Dictionary = drop_states[i]
		d["life"] = float(d["life"]) + dt
		if float(d["life"]) >= float(d["max"]) or float(d["y"]) < floor_y - 0.1:
			_spawn(d)
		d["vy"] = float(d["vy"]) - 9.8 * 0.55 * dt
		d["x"] = float(d["x"]) + float(d["vx"]) * dt
		d["y"] = float(d["y"]) + float(d["vy"]) * dt
		d["z"] = float(d["z"]) + float(d["vz"]) * dt
		if bool(d["splash"]) and float(d["y"]) < foot_y - 0.02:
			d["life"] = d["max"]
		var fade := sin(minf(1.0, float(d["life"]) / maxf(float(d["max"]), 0.001)) * PI)
		var alpha := (0.75 if bool(d["splash"]) else 0.60) * fade * flow
		# The web clamps gl_PointSize to one pixel; keep the quad at a
		# comparable on-screen size instead of letting it vanish.
		var size := maxf(float(d["size"]), 0.020)
		# Billboard orientation is already supplied by the material. Upload
		# the identical positions/scales/colours in one MultiMesh buffer.
		var k := i * 16
		drop_buffer[k] = size
		drop_buffer[k + 3] = float(d["x"])
		drop_buffer[k + 5] = size
		drop_buffer[k + 7] = float(d["y"])
		drop_buffer[k + 10] = size
		drop_buffer[k + 11] = float(d["z"])
		drop_buffer[k + 12] = light
		drop_buffer[k + 13] = light
		drop_buffer[k + 14] = light
		drop_buffer[k + 15] = alpha
	drop_multimesh.buffer = drop_buffer
	for i in range(vapor.size()):
		var sprite: Sprite3D = vapor[i]
		sprite.visible = true
		var age := fmod(float(i) * 0.618 + time * (0.44 + float(i % 5) * 0.05), 1.0)
		var p: Vector3 = path_fn.call(fmod(float(i) * 0.618, 1.0),
			0.9 + 0.07 * sin(float(i) * 3.51), 0.0)
		sprite.position = Vector3(
			p.x + 0.09 + age * (0.24 + 0.08 * wind),
			p.y + 0.23 * age,
			p.z + sin(float(i) * 1.7) * age * 0.41)
		sprite.scale = Vector3.ONE * (0.4 + age * 0.8)
		var tint := sprite.modulate
		tint.a = 0.20 * sin(age * PI) * light * flow
		sprite.modulate = tint
