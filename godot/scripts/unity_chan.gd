extends Node3D
class_name UnityChan

## Unity-chan loader + a compact task AI:
## stroll, walk to a vegetable bed and gather, walk to the pond and fish,
## salute / kneel in front of the cottage. The imported GLB supplies all clips.

const MODEL_PATH := "res://assets/models/unitychan/sd_unitychan.glb"
const TARGET_HEIGHT := 1.02
const POND := Vector2(10.7, 6.3)

var world: FarmWorld
var footprints: Footprints
var paths: FarmPaths
var model: Node3D
var animation: AnimationPlayer
var blend_face: MeshInstance3D
var blink_index := -1
var blink := 2.0
var blink_t := 0.0
var weather := 0
var season := 1

var walk_speed := 0.48
var waypoints := [
	Vector2(-0.2, 2.2), Vector2(2.2, 2.8), Vector2(4.2, 2.2),
	Vector2(4.6, 4.2), Vector2(2.4, 5.2), Vector2(0.0, 4.8),
	Vector2(-1.8, 3.4), Vector2(-1.4, 1.8),
]
var waypoint_index := 0
var wait := 2.0
var current_clip := ""
var mode := "stroll"
var route: Array[Vector2] = []
var task_type := ""
var task_phase := 0
var task_timer := 0.0
var task_face := 0.0
var time := 0.0
var stride_left := 0.0
var foot := 1.0

var rod: Node3D
var line: MeshInstance3D
var line_mesh: ImmediateMesh
var bobber: MeshInstance3D

func _ready() -> void:
	var packed := load(MODEL_PATH)
	if packed == null:
		push_warning("Unity-chan failed to import")
		return
	model = packed.instantiate()
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		for clip_name in ["Standing", "Walking", "Running", "FishingLoop"]:
			if animation.has_animation(clip_name):
				animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		for clip_name in ["Salute", "Gathering", "KneelDown", "KneelDownToUp", "FishingBegin", "FishingStop"]:
			if animation.has_animation(clip_name):
				animation.get_animation(clip_name).loop_mode = Animation.LOOP_NONE
		animation.play("Standing")
		animation.seek(0.0, true)
		animation.advance(0.0)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()
	_fit_model()
	_find_face()
	_build_fishing_gear()
	position.y = world.stand(position.x, position.z) if world != null else 0.0
	if world != null:
		paths = FarmPaths.new(world)
	_play("Standing", 0.0)

func _fit_model() -> void:
	var box := _model_aabb()
	if box.size.y > 0.001:
		model.scale *= TARGET_HEIGHT / box.size.y
	box = _model_aabb()
	model.position.y -= box.position.y

func _model_aabb() -> AABB:
	var result := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _find_face() -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_blend_shape_count()):
			if mi.mesh.get_blend_shape_name(i).contains("EYE"):
				blend_face = mi
				blink_index = i
				return

func _build_fishing_gear() -> void:
	rod = Node3D.new()
	rod.name = "FishingRod"
	rod.position = Vector3(0.16, 0.72, 0.18)
	rod.rotation.x = 0.55
	rod.visible = false
	add_child(rod)
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.008
	rod_mesh.bottom_radius = 0.018
	rod_mesh.height = 1.15
	rod_mesh.radial_segments = 6
	rod_mesh.rings = 1
	var rod_instance := MeshInstance3D.new()
	rod_instance.mesh = rod_mesh
	var rod_material := StandardMaterial3D.new()
	rod_material.albedo_color = Color(0.42, 0.29, 0.17)
	rod_material.roughness = 0.7
	rod_instance.material_override = rod_material
	rod_instance.position.y = 0.575
	rod_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rod.add_child(rod_instance)

	line_mesh = ImmediateMesh.new()
	line = MeshInstance3D.new()
	line.name = "FishingLine"
	line.mesh = line_mesh
	line.top_level = true
	line.visible = false
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.90, 0.89, 0.82, 0.75)
	line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material_override = line_material
	add_child(line)

	bobber = MeshInstance3D.new()
	bobber.name = "Bobber"
	var bobber_mesh := SphereMesh.new()
	bobber_mesh.radius = 0.035
	bobber_mesh.height = 0.07
	bobber_mesh.radial_segments = 8
	bobber_mesh.rings = 6
	bobber.mesh = bobber_mesh
	bobber.top_level = true
	bobber.visible = false
	var bobber_material := StandardMaterial3D.new()
	bobber_material.albedo_color = Color(0.85, 0.29, 0.20)
	bobber_material.roughness = 0.5
	bobber.material_override = bobber_material
	add_child(bobber)

func _process(delta: float) -> void:
	if model == null:
		return
	time += delta
	if mode == "task":
		_update_task(delta)
	elif wait > 0.0:
		wait -= delta
		_play("Standing", 0.3)
		if animation != null:
			animation.speed_scale = 1.0
		if wait <= 0.0:
			_choose_next()
	elif route.is_empty():
		_choose_next()
	else:
		_walk_route(delta)

	if world != null:
		position.y = world.stand(position.x, position.z)
	_update_fishing_gear()

	if blend_face != null and blink_index >= 0:
		blink -= delta
		if blink <= 0.0:
			blink = 2.2 + randf() * 3.5
			blink_t = 0.16
		blink_t = maxf(0.0, blink_t - delta)
		blend_face.set_blend_shape_value(blink_index, sin(PI * blink_t / 0.16))

func _play(clip_name: String, fade: float) -> void:
	if animation == null or current_clip == clip_name:
		return
	if not animation.has_animation(clip_name):
		return
	animation.play(clip_name, fade)
	current_clip = clip_name

func _clip_length(clip_name: String) -> float:
	if animation != null and animation.has_animation(clip_name):
		return animation.get_animation(clip_name).length
	return 2.0

func _choose_next() -> void:
	mode = "stroll"
	var roll := randf()
	if roll < 0.26:
		_begin_journey("gather")
	elif roll < 0.50 and can_fish():
		_begin_journey("fish")
	elif roll < 0.68:
		_begin_journey("salute")
	elif roll < 0.78:
		_start_task("kneel")
	else:
		_stroll_next()

func can_fish() -> bool:
	return season != 3 and weather != 2 and weather != 3 and weather != 5

func _nearest_waypoint() -> int:
	var best := 0
	var best_distance := INF
	for i in range(waypoints.size()):
		var distance := Vector2(position.x, position.z).distance_squared_to(waypoints[i])
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _begin_journey(type: String) -> void:
	task_type = type
	mode = "to_task"
	route = _task_route(type)
	wait = 0.0
	_play("Walking", 0.3)

func _task_route(type: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var current := Vector2(position.x, position.z)
	var target := current
	if type == "gather" and world != null and not world.veg_beds.is_empty():
		var bed: Vector2 = world.veg_beds[randi() % world.veg_beds.size()]
		target = bed + Vector2(0, -1.05)
		task_face = atan2(bed.x - target.x, bed.y - target.y)
	elif type == "fish" and world != null:
		target = world.pond_shore
		task_face = atan2(POND.x - target.x, POND.y - target.y)
	elif type == "salute":
		target = Vector2(-0.35, 1.0)
		task_face = atan2(-1.0 - target.x, -2.5 - target.y)
	if target != current and paths != null and world != null:
		var path: Array[Vector2] = paths.route(world, current, target)
		if not path.is_empty():
			if path.size() > 1 and path[0].distance_to(current) < 0.35:
				path.pop_front()
			return path
	return [target] if target != current else result

func _stroll_next() -> void:
	mode = "stroll"
	waypoint_index = (waypoint_index + 1) % waypoints.size()
	var target: Vector2 = waypoints[waypoint_index]
	route.clear()
	var current := Vector2(position.x, position.z)
	if paths != null and world != null:
		route = paths.route(world, current, target)
		if route.size() > 1 and route[0].distance_to(current) < 0.35:
			route.pop_front()
	if route.is_empty():
		route.append(target)
	_play("Walking", 0.3)

func _walk_route(delta: float) -> void:
	if route.is_empty():
		if mode == "to_task":
			_start_task(task_type)
		else:
			wait = 1.0 + randf() * 2.0
		return
	var target: Vector2 = route[0]
	var flat := target - Vector2(position.x, position.z)
	if flat.length() < 0.10:
		route.pop_front()
		if route.is_empty():
			if mode == "to_task":
				_start_task(task_type)
			else:
				wait = 0.8 + randf() * 2.0
		return
	var direction := flat.normalized()
	var step := minf(walk_speed * delta, flat.length())
	var moved := false
	var start := Vector2(position.x, position.z)
	var candidates := [
		Vector2(position.x + direction.x * step, position.z + direction.y * step),
		Vector2(position.x + direction.x * step, position.z),
		Vector2(position.x, position.z + direction.y * step),
	]
	for candidate in candidates:
		var point: Vector2 = candidate
		if _can_stand(point):
			position.x = point.x
			position.z = point.y
			moved = true
			break
	if not moved:
		route.pop_front()
		return
	_track_feet(start.distance_to(Vector2(position.x, position.z)))
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.y), 1.0 - exp(-delta * 7.0))
	_play("Walking", 0.3)
	if animation != null:
		animation.speed_scale = clampf(walk_speed / 0.62, 0.75, 1.2)

func _can_stand(p: Vector2) -> bool:
	if world == null:
		return true
	return world.is_free_for_walker(p.x, p.y, 0.16)

## One print per stride, alternating feet either side of her path.
func _track_feet(moved: float) -> void:
	if footprints == null or moved <= 0.0001:
		return
	stride_left -= moved
	if stride_left > 0.0:
		return
	stride_left = 0.19
	foot = -foot
	var heading := rotation.y
	footprints.press("boot",
		position.x + cos(heading) * foot * 0.055 + sin(heading) * 0.04,
		position.z - sin(heading) * foot * 0.055 + cos(heading) * 0.04,
		heading)

func _start_task(type: String) -> void:
	mode = "task"
	task_type = type
	task_phase = 0
	task_timer = 0.0
	rod.visible = false
	line.visible = false
	bobber.visible = false
	match type:
		"gather":
			_play("Gathering", 0.3)
			task_timer = _clip_length("Gathering") + 0.5
		"fish":
			_play("FishingBegin", 0.3)
			task_timer = _clip_length("FishingBegin") + 0.2
			rod.visible = true
		"salute":
			_play("Salute", 0.3)
			task_timer = _clip_length("Salute") + 0.4
			if world != null:
				world.set_door_open(true)
		"kneel":
			_play("KneelDown", 0.25)
			task_timer = _clip_length("KneelDown") + 0.2
		_:
			task_timer = 1.5
	if animation != null:
		animation.speed_scale = 1.0

func _update_task(delta: float) -> void:
	task_timer -= delta
	if task_type in ["gather", "fish", "salute"]:
		rotation.y = lerp_angle(rotation.y, task_face, 1.0 - exp(-delta * 4.0))
	if task_timer > 0.0:
		if task_type == "fish" and task_phase >= 1:
			_update_fishing_gear()
		return
	if task_type == "salute" and task_phase == 0:
		# Step through the open door and stay inside for a moment.
		task_phase = 1
		task_timer = 4.5
		if world != null:
			world.set_door_open(true)
		position = Vector3(-1.0, position.y, -1.15)
		model.visible = false
		return
	if task_type == "fish":
		if task_phase == 0:
			_play("FishingLoop", 0.2)
			task_phase = 1
			task_timer = 9.0 + randf() * 4.0
			line.visible = true
			bobber.visible = true
			return
		elif task_phase == 1:
			_play("FishingStop", 0.2)
			task_phase = 2
			task_timer = _clip_length("FishingStop") + 0.6
			line.visible = false
			bobber.visible = false
			return
	elif task_type == "kneel" and task_phase == 0:
		_play("KneelDownToUp", 0.15)
		task_phase = 1
		task_timer = _clip_length("KneelDownToUp") + 0.3
		return
	_finish_task()

func _finish_task() -> void:
	if task_type == "salute" and task_phase == 1:
		position = Vector3(-0.35, position.y, 1.0)
		model.visible = true
	mode = "stroll"
	task_type = ""
	if world != null:
		world.set_door_open(false)
	rod.visible = false
	line.visible = false
	bobber.visible = false
	waypoint_index = _nearest_waypoint()
	route.clear()
	wait = 1.2 + randf() * 2.0
	_play("Standing", 0.35)

func _update_fishing_gear() -> void:
	if task_type != "fish" or not rod.visible:
		line.visible = false
		bobber.visible = false
		return
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var origin := global_position + Vector3(0.0, 0.90, 0.0) + forward * 0.18
	var tip := origin + forward * 0.62 + Vector3(0.0, 0.98, 0.0)
	var bobber_position := global_position + forward * 2.2
	bobber_position.y = (world.water.position.y + 0.02) if world != null else 0.0
	bobber_position.y += sin(time * 2.3) * 0.006
	bobber.global_position = bobber_position

	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_add_vertex(tip)
	line_mesh.surface_add_vertex(bobber_position)
	line_mesh.surface_end()
	line.global_position = Vector3.ZERO
	line.visible = task_phase == 1
	bobber.visible = task_phase == 1

func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)

