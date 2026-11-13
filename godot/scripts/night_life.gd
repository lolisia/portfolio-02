extends Node3D
class_name NightLife

## Night-time details ported from src/main.js and src/interior.js:
## a star dome, moths around the lanterns, fireflies over the summer grass,
## per-lamp flicker/halos, and the cottage window / TV light.

const MOTHS_PER_LAMP := 16
const FIREFLY_COUNT := 90
const TV_PALETTE := [
	Color(0.48, 0.64, 1.00), Color(0.87, 0.91, 1.00), Color(0.62, 0.90, 0.75),
	Color(1.00, 0.85, 0.66), Color(1.00, 0.56, 0.47), Color(0.72, 0.65, 1.00),
	Color(0.95, 0.96, 1.00),
]

var world: FarmWorld
var rng := RandomNumberGenerator.new()
var time := 0.0

var star_dome: MeshInstance3D
var star_material: ShaderMaterial
var moon: MeshInstance3D
var moon_material: StandardMaterial3D
var moon_halo: MeshInstance3D
var moon_halo_material: StandardMaterial3D
var moth_instance: MultiMeshInstance3D
var moth_material: StandardMaterial3D
var moth_states: Array = []
var moth_level := 0.0
var firefly_instance: MultiMeshInstance3D
var firefly_material: StandardMaterial3D
var lamp_states: Array = []
var lamp_glass_average := 1.0

# Cottage interior state.
var lamp_level := 1.0
var lamp_target := 1.0
var lamp_interval := 12.0
var lamp_tint := 0.0
var lamp_tint_target := 0.0
var tv_on := false
var tv_until := 8.0
var tv_cut := 0.0
var tv_color := Color(0.48, 0.64, 1.0)
var tv_target := Color(0.48, 0.64, 1.0)
var tv_brightness := 1.0
var tv_level := 0.0
var person := Vector2(-1.6, -2.4)
var person_target := Vector2(-1.6, -2.4)
var person_wait := 2.0
var person_shade := 0.62
var person_silhouette: MeshInstance3D

func setup() -> void:
	rng.seed = 88411
	_build_stars()
	_build_moon()
	_build_moths()
	_build_fireflies()
	_build_lamp_halos()
	_build_person_silhouette()

func _glow_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var r := sqrt(dx * dx + dy * dy)
			var a := pow(clampf(1.0 - r, 0.0, 1.0), 2.6)
			a += pow(clampf(1.0 - r * 2.4, 0.0, 1.0), 3.0) * 0.9
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)

func _billboard_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = texture
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat

func _quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return quad

func _build_stars() -> void:
	# The star field is generated in the shader from the dome direction (like
	# the web's screen-space star cells), so no texture resolution can turn a
	# star into a magnified square under the orthographic camera.
	star_material = ShaderMaterial.new()
	star_material.shader = preload("res://shaders/stars.gdshader")
	star_material.set_shader_parameter("amount", 0.0)
	star_material.set_shader_parameter("clock", 0.0)

	var sphere := SphereMesh.new()
	sphere.radius = 145.0
	sphere.height = 290.0
	sphere.radial_segments = 48
	sphere.rings = 24
	star_dome = MeshInstance3D.new()
	star_dome.name = "StarDome"
	star_dome.mesh = sphere
	star_dome.material_override = star_material
	star_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	star_dome.visible = false
	add_child(star_dome)

func _build_moon() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 2.6
	sphere.height = 5.2
	sphere.radial_segments = 24
	sphere.rings = 12
	moon_material = StandardMaterial3D.new()
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.albedo_color = Color(0.93, 0.96, 1.0)
	moon_material.emission_enabled = true
	moon_material.emission = Color(0.85, 0.92, 1.0)
	moon_material.emission_energy_multiplier = 4.0
	moon = MeshInstance3D.new()
	moon.name = "Moon"
	moon.mesh = sphere
	moon.material_override = moon_material
	moon.position = Vector3(-78.0, 96.0, -64.0)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	moon.visible = false
	add_child(moon)

	moon_halo_material = _billboard_material(_glow_texture(), Color(0.78, 0.88, 1.0, 0.0))
	moon_halo = MeshInstance3D.new()
	moon_halo.name = "MoonHalo"
	moon_halo.mesh = _quad()
	moon_halo.material_override = moon_halo_material
	moon_halo.position = moon.position
	moon_halo.scale = Vector3.ONE * 15.0
	moon_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_halo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	moon_halo.visible = false
	add_child(moon_halo)

func _build_moths() -> void:
	moth_material = _billboard_material(_glow_texture(), Color(1.0, 0.96, 0.90, 0.0))
	var count := MOTHS_PER_LAMP * world.lamps.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _quad()
	multimesh.instance_count = count
	for i in range(count):
		var lamp_index := int(i / MOTHS_PER_LAMP)
		moth_states.append({
			"lamp": lamp_index,
			"angle": rng.randf() * TAU,
			"spin": (-1.0 if rng.randf() < 0.5 else 1.0) * (2.0 + rng.randf() * 4.0),
			"radius": 0.15 + rng.randf() * 0.35,
			"height": (rng.randf() - 0.5) * 0.4,
			"phase": rng.randf() * 50.0,
			"dart": 3.0 + rng.randf() * 5.0,
			"size": 0.075 + rng.randf() * 0.045,
		})
	moth_instance = MultiMeshInstance3D.new()
	moth_instance.name = "Moths"
	moth_instance.multimesh = multimesh
	moth_instance.material_override = moth_material
	moth_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moth_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	moth_instance.custom_aabb = AABB(Vector3(-20.0, -5.0, -20.0), Vector3(40.0, 30.0, 40.0))
	moth_instance.visible = false
	add_child(moth_instance)

func _build_fireflies() -> void:
	firefly_material = _billboard_material(_glow_texture(), Color(1.0, 0.90, 0.48, 0.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _quad()
	multimesh.instance_count = FIREFLY_COUNT
	for i in range(FIREFLY_COUNT):
		var x := rng.randf_range(-14.0, 14.0)
		var z := rng.randf_range(-14.0, 14.0)
		var y := world.height(x, z) + 0.35 + rng.randf() * 2.3
		var s := 0.17 + rng.randf() * 0.12
		multimesh.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(x, y, z)))
	firefly_instance = MultiMeshInstance3D.new()
	firefly_instance.name = "Fireflies"
	firefly_instance.multimesh = multimesh
	firefly_instance.material_override = firefly_material
	firefly_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	firefly_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	firefly_instance.custom_aabb = AABB(Vector3(-16.0, -4.0, -16.0), Vector3(32.0, 30.0, 32.0))
	firefly_instance.visible = false
	add_child(firefly_instance)

func _build_lamp_halos() -> void:
	var glow := _glow_texture()
	for i in range(world.lamps.size()):
		var lamp: Dictionary = world.lamps[i]
		var position: Vector3 = lamp["position"]
		var material := _billboard_material(glow, Color(1.0, 0.95, 0.86, 0.0))
		var halo := MeshInstance3D.new()
		halo.name = "LanternHalo-" + str(i)
		halo.mesh = _quad()
		halo.material_override = material
		halo.position = position
		halo.scale = Vector3.ONE * 3.2
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		halo.visible = false
		add_child(halo)
		lamp_states.append({
			"light": lamp["light"], "halo": halo, "material": material,
			"level": 1.0, "flicker": 0.0, "chunk": 0.0,
			"next": 6.0 + rng.randf() * 30.0,
		})

func _build_person_silhouette() -> void:
	var image := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(64):
			var dx := (float(x) - 31.5) / 31.5
			var head := sqrt(pow(dx / 0.42, 2.0) + pow((float(y) - 30.0) / 22.0, 2.0))
			var shoulders := sqrt(pow(dx / 0.88, 2.0) + pow((float(y) - 104.0) / 44.0, 2.0))
			var alpha := maxf(1.0 - head, 0.0) + maxf(1.0 - shoulders, 0.0)
			alpha = clampf(alpha, 0.0, 1.0)
			if alpha <= 0.01:
				continue
			image.set_pixel(x, y, Color(1, 1, 1, alpha * 0.72))
	var texture := ImageTexture.create_from_image(image)
	person_silhouette = MeshInstance3D.new()
	person_silhouette.name = "CottageWindowSilhouette"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.58)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color(0.07, 0.065, 0.06, 0.58)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 5
	person_silhouette.mesh = quad
	person_silhouette.material_override = material
	person_silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	person_silhouette.visible = false
	add_child(person_silhouette)

func update(delta: float, night: float, golden: float, clear: float,
		weather: int, season: int, wind: float, orbit_yaw: float) -> void:
	time += delta
	_update_stars(night, golden, clear, orbit_yaw)
	_update_lamps(delta, night)
	_update_interior(delta, night)
	_update_moths(delta, night, weather, season, wind)
	_update_fireflies(night, weather, season)

func _update_stars(night: float, golden: float, clear: float, orbit_yaw: float) -> void:
	var amount := clampf(night * night * clear * clear * (1.0 - golden), 0.0, 1.0)
	star_dome.visible = amount > 0.004
	if not star_dome.visible:
		moon.visible = false
		moon_halo.visible = false
		return
	star_material.set_shader_parameter("amount", amount)
	star_material.set_shader_parameter("clock", time)
	star_dome.rotation.y = -orbit_yaw * 0.9 + 0.15
	moon.visible = amount > 0.02
	moon_halo.visible = moon.visible
	moon_material.emission_energy_multiplier = 1.2 + 2.8 * amount
	var halo_tint := moon_halo_material.albedo_color
	halo_tint.a = amount * 0.50
	moon_halo_material.albedo_color = halo_tint

func _update_lamps(delta: float, night: float) -> void:
	var total := 0.0
	var count := 0
	for lamp in lamp_states:
		lamp["next"] = float(lamp["next"]) - delta
		if float(lamp["next"]) <= 0.0 and float(lamp["flicker"]) <= 0.0:
			lamp["flicker"] = 0.35 + rng.randf() * 1.4
			lamp["next"] = 10.0 + rng.randf() * 45.0
		if float(lamp["flicker"]) > 0.0:
			lamp["flicker"] = float(lamp["flicker"]) - delta
			lamp["chunk"] = float(lamp["chunk"]) - delta
			if float(lamp["chunk"]) <= 0.0:
				lamp["chunk"] = 0.03 + rng.randf() * 0.11
				var roll := rng.randf()
				if roll < 0.45:
					lamp["level"] = 0.05 + rng.randf() * 0.30
				elif roll < 0.72:
					lamp["level"] = 0.60 + rng.randf() * 0.25
				else:
					lamp["level"] = 1.0
			if float(lamp["flicker"]) <= 0.0:
				lamp["level"] = 1.0
		var light: OmniLight3D = lamp["light"]
		var hum := 1.0 + 0.025 * sin(time * 47.0 + light.position.x) * sin(time * 3.1)
		var level: float = float(lamp["level"]) * hum
		light.light_energy = night * 3.6 * level
		light.visible = night > 0.02
		var halo: MeshInstance3D = lamp["halo"]
		halo.visible = night > 0.01
		var material: StandardMaterial3D = lamp["material"]
		var tint := material.albedo_color
		tint.a = night * 0.85 * level
		material.albedo_color = tint
		total += level
		count += 1
	lamp_glass_average = total / maxf(float(count), 1.0)
	if world.lamp_glass_material != null:
		world.lamp_glass_material.emission_energy_multiplier = 0.03 + night * 3.0 * lamp_glass_average

func _update_moths(delta: float, night: float, weather: int, season: int, wind: float) -> void:
	var mild := season != 3 and weather in [0, 1, 3] and wind < 8.0
	var target := smoothstep(0.3, 0.7, night) if mild else 0.0
	moth_level = lerpf(moth_level, target, 1.0 - exp(-delta * 1.5))
	moth_instance.visible = moth_level > 0.01
	var tint := moth_material.albedo_color
	tint.a = moth_level * 0.85
	moth_material.albedo_color = tint
	if not moth_instance.visible:
		return
	var multimesh := moth_instance.multimesh
	for i in range(moth_states.size()):
		var moth: Dictionary = moth_states[i]
		var lamp_index: int = moth["lamp"]
		if lamp_index >= world.lamps.size():
			continue
		var center: Vector3 = world.lamps[lamp_index]["position"]
		if sin(time * 1.7 + float(moth["phase"]) * 3.0) > 0.97:
			moth["spin"] = -float(moth["spin"])
		var dart := maxf(0.0, sin(time * PI * 2.0 / float(moth["dart"]) + float(moth["phase"])))
		dart = pow(dart, 10.0)
		var angle: float = float(moth["angle"]) + float(moth["spin"]) * delta
		moth["angle"] = angle
		var radius: float = (float(moth["radius"]) + 0.08 * sin(time * 5.1 + float(moth["phase"]))) * (1.0 - 0.75 * dart) + 0.06
		var x := center.x + cos(angle) * radius
		var z := center.z + sin(angle) * radius
		var y := center.y + float(moth["height"]) + sin(time * 3.4 + float(moth["phase"])) * 0.05 - dart * 0.08
		var size: float = float(moth["size"])
		multimesh.set_instance_transform(i,
			Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3(x, y, z)))

func _update_fireflies(night: float, weather: int, season: int) -> void:
	var active := night > 0.6 and weather < 2 and season == 1
	firefly_instance.visible = active
	var tint := firefly_material.albedo_color
	tint.a = (0.72 + 0.25 * sin(time * 2.5)) * 0.85 if active else 0.0
	firefly_material.albedo_color = tint
	if not active:
		return
	firefly_instance.position.y = sin(time * 0.9) * 0.14
	firefly_instance.rotation.y = sin(time * 0.35) * 0.025

func _update_interior(delta: float, night: float) -> void:
	var cottage: Dictionary = world.COTTAGE
	var hx := -1.0
	var hz := -2.5
	lamp_interval -= delta
	if lamp_interval <= 0.0:
		lamp_interval = 14.0 + rng.randf() * 30.0
		var choices := [0.62, 0.85, 1.0, 1.0, 1.18]
		lamp_target = choices[rng.randi() % choices.size()]
		lamp_tint_target = 1.0 if rng.randf() < 0.3 else 0.0
	lamp_level = lerpf(lamp_level, lamp_target, 1.0 - exp(-delta * 4.0))
	lamp_tint = lerpf(lamp_tint, lamp_tint_target, 1.0 - exp(-delta * 3.0))

	tv_until -= delta
	if tv_until <= 0.0:
		tv_on = not tv_on
		tv_until = (25.0 + rng.randf() * 50.0) if tv_on else (12.0 + rng.randf() * 35.0)
	tv_cut -= delta
	if tv_cut <= 0.0:
		tv_cut = 0.6 + pow(rng.randf(), 2.0) * 3.6
		tv_target = TV_PALETTE[rng.randi() % TV_PALETTE.size()]
		tv_brightness = 0.45 + rng.randf() * 0.55
	tv_color = tv_color.lerp(tv_target, 1.0 - exp(-delta * 22.0))
	var tv_wanted := tv_brightness * (0.86 + 0.14 * sin(time * 31.0) * sin(time * 7.3)) if tv_on else 0.0
	tv_level = lerpf(tv_level, tv_wanted, 1.0 - exp(-delta * 18.0))

	if person_wait > 0.0:
		person_wait -= delta
	else:
		var to_target := person_target - person
		if to_target.length() < 0.02:
			person_wait = 2.0 + rng.randf() * 9.0
			person_target = Vector2(
				hx + (rng.randf() - 0.5) * (float(cottage.W) - 0.5),
				hz + (rng.randf() - 0.5) * (float(cottage.D) - 0.5))
		else:
			person += to_target.normalized() * minf(0.45 * delta, to_target.length())
	person_shade = lerpf(person_shade, 0.62, 1.0 - exp(-delta * 2.0))
	if person_silhouette != null:
		var window_x_a := hx - 0.95
		var window_x_b := hx + 0.95
		var distance_a := absf(person.x - window_x_a)
		var distance_b := absf(person.x - window_x_b)
		var near_window := distance_a < 0.48 or distance_b < 0.48
		var window_x := window_x_a if distance_a < distance_b else window_x_b
		person_silhouette.position = Vector3(window_x, world.cottage_window.y - 0.15,
			world.cottage_window.z - 0.62)
		person_silhouette.visible = night > 0.25 and near_window

	var warm := Color(1.0, 0.67, 0.27)
	var reading := Color(1.0, 0.82, 0.60)
	var glow := warm.lerp(reading, lamp_tint * 0.5)
	var near := 1.0 - smoothstep(0.2, 0.8, absf(person.y - (hz + float(cottage.D) * 0.5)))
	if world.window_glass_material != null:
		var glass := world.window_glass_material
		glass.set_shader_parameter("night", night)
		glass.set_shader_parameter("lamp_color", Vector3(glow.r, glow.g, glow.b))
		glass.set_shader_parameter("lamp_level", lamp_level)
		glass.set_shader_parameter("tv_color", Vector3(tv_color.r, tv_color.g, tv_color.b))
		glass.set_shader_parameter("tv_level", tv_level)
	if world.window_light != null:
		var light := Color(1.0, 0.70, 0.34) * lamp_level
		light += tv_color * (tv_level * 0.35)
		var strength := maxf(maxf(light.r, light.g), maxf(light.b, 0.001))
		light /= strength
		world.window_light.light_color = light
		world.window_light.light_energy = night * 2.4 * strength * (1.0 - 0.45 * near * person_shade)
