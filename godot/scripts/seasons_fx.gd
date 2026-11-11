extends Node3D
class_name SeasonsFX

## Spring cherry petals and autumn leaves. The original uses instanced petal
## meshes spawned around the trees; this port uses a GPU particle box over the
## island, which keeps the diorama small and the particle count GPU-cheap.

var world: FarmWorld
var petals: GPUParticles3D
var leaves: GPUParticles3D
var petal_material: StandardMaterial3D
var leaf_material: StandardMaterial3D
var petal_level := 0.0
var leaf_level := 0.0
var petal_process: ParticleProcessMaterial
var leaf_process: ParticleProcessMaterial

func setup() -> void:
	var petal_tex := _petal_texture(false)
	var leaf_tex := _petal_texture(true)
	petals = _make_system("SpringPetals", 240, 0.11, petal_tex, Color(1.0, 0.72, 0.80, 1.0))
	leaves = _make_system("AutumnLeaves", 280, 0.13, leaf_tex, Color(0.92, 0.52, 0.22, 1.0))
	petal_process = petals.process_material as ParticleProcessMaterial
	leaf_process = leaves.process_material as ParticleProcessMaterial
	petals.emitting = false
	leaves.emitting = false
	petals.amount_ratio = 0.0
	leaves.amount_ratio = 0.0

func _make_system(label: String, amount: int, size: float, texture: Texture2D,
		tint: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-18, -4, -18), Vector3(36, 26, 36))
	particles.position = Vector3(0, 7.0, 0)
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD

	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 1.25)
	particles.draw_pass_1 = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = 0.86
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(14.2, 1.5, 14.2)
	process.direction = Vector3(0.25, -1.0, 0.1)
	process.spread = 38.0
	process.initial_velocity_min = 0.18
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.18, -0.55, 0.05)
	process.lifetime_randomness = 0.32
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	process.scale_min = 0.72
	process.scale_max = 1.25
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.08, Color(1, 1, 1, 1))
	fade.add_point(0.82, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	add_child(particles)
	return particles

func _petal_texture(leaf: bool) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var tint := Color(1.0, 0.82, 0.88) if not leaf else Color(0.94, 0.62, 0.30)
	for y in range(32):
		for x in range(32):
			var u := (float(x) - 15.5) / 14.0
			var v := (float(y) - 15.5) / 15.0
			var d := 0.0
			if leaf:
				# A pointed oval leaf.
				d = sqrt(pow(u / 0.82, 2.0) + pow(v / 1.0, 2.0))
				d += absf(u) * 0.22
			else:
				# A soft cherry petal with a small notch at the top.
				d = sqrt(pow(u / 0.72, 2.0) + pow(v / 1.0, 2.0))
				d += maxf(0.0, -v - 0.45) * absf(u) * 0.35
			var alpha := clampf((1.0 - d) / 0.16, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var color := tint
			color.a = alpha
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func update(delta: float, season: int, wind: float) -> void:
	var petal_target := 1.0 if season == 0 else 0.0
	var leaf_target := 1.0 if season == 2 else 0.0
	petal_level = lerpf(petal_level, petal_target, 1.0 - exp(-delta * 0.9))
	leaf_level = lerpf(leaf_level, leaf_target, 1.0 - exp(-delta * 0.9))
	petals.emitting = petal_level > 0.01
	leaves.emitting = leaf_level > 0.01
	petals.amount_ratio = clampf(petal_level, 0.0, 1.0)
	leaves.amount_ratio = clampf(leaf_level, 0.0, 1.0)
	var drift := wind * 0.055
	if petal_process != null:
		petal_process.gravity = Vector3(drift * 0.8, -0.52, drift * 0.35)
	if leaf_process != null:
		leaf_process.gravity = Vector3(drift, -0.72, drift * 0.4)
