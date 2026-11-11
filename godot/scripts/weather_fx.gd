extends Node3D
class_name WeatherFX

## Lightweight GPU rain/snow. The diorama is small, so an emitter box over the
## island is enough; no collision or splash simulation yet.

var rain: GPUParticles3D
var snow: GPUParticles3D

func _ready() -> void:
	rain = _make_particles("Rain", 1100, 1.15, 5.0, 9.0, Color(0.55, 0.66, 0.78, 0.30), Vector2(0.028, 0.52))
	snow = _make_particles("Snow", 2400, 9.0, 0.5, 1.4, Color(0.92, 0.95, 1.0, 0.75), Vector2(0.045, 0.045))
	rain.position = Vector3(0, 7, 0)
	snow.position = Vector3(0, 7, 0)
	rain.emitting = false
	snow.emitting = false

func _make_particles(label: String, amount: int, lifetime: float, vmin: float, vmax: float,
		color: Color, quad_size: Vector2) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = label
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.fixed_fps = 0
	particles.visibility_aabb = AABB(Vector3(-16, -8, -16), Vector3(32, 22, 32))

	var quad := QuadMesh.new()
	quad.size = quad_size
	particles.draw_pass_1 = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(15.0, 8.0, 15.0)
	process.direction = Vector3(0, -1, 0)
	process.spread = 4.0
	process.initial_velocity_min = vmin
	process.initial_velocity_max = vmax
	process.gravity = Vector3(0, -9.8 if label == "Rain" else -0.8, 0)
	process.lifetime_randomness = 0.25
	process.angular_velocity_min = -15.0
	process.angular_velocity_max = 15.0
	particles.process_material = process

	add_child(particles)
	return particles

func set_weather(weather: int) -> void:
	if rain == null or snow == null:
		return
	rain.emitting = weather == 2
	snow.emitting = weather >= 4
