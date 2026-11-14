extends Node3D
class_name UnityChan

## Unity-chan loader + a compact task AI:
## stroll, walk to a vegetable bed and gather, walk to the pond and fish,
## salute / kneel in front of the cottage. The imported GLB supplies all clips.

const MODEL_PATH := "res://assets/models/unitychan/sd_unitychan.glb"
const TARGET_HEIGHT := 1.02
const POND := Vector2(10.7, 6.3)
const TOON_SHADER = preload("res://shaders/toon_character.gdshader")
const TOON_DOUBLE_SHADER = preload("res://shaders/toon_character_double.gdshader")

var world: FarmWorld
var footprints: Footprints
var paths: FarmPaths
var body: Dictionary
var model: Node3D
var animation: AnimationPlayer
var blend_face: MeshInstance3D
var blink_index := -1
var blink := 2.0
var blink_t := 0.0
var weather := 0
var season := 1
var hour := 8.5
var wind := 3.0
var water_freeze := 0.0

var walk_speed := 0.62
var turn_rate := 6.0
var task_turn_rate := 4.0
var pace := 0.0
var state := "inside"
var intent := false
var reaction := 3.0
var door_wait := 0.0
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
var gather_spots: Array = []
var shore_spots: Array = []
var toon_materials: Array[ShaderMaterial] = []
var toon_double_count := 0
var _toon_white: ImageTexture
var time := 0.0
var stride_left := 0.0
var stuck := 0.0
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
		for clip_name in ["Standing", "Walking", "Running", "Gathering", "FishingLoop"]:
			if animation.has_animation(clip_name):
				animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		for clip_name in ["Salute", "KneelDown", "KneelDownToUp", "FishingBegin", "FishingStop"]:
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
	_apply_toon_materials()
	_build_fishing_gear()
	if world != null:
		paths = FarmPaths.new(world)
		body = world.add_body(position.x, position.z, 0.20, "unitychan")
		body["active"] = false
		_find_spots()
		position = Vector3(world.cottage_door.x,
			world.stand(world.cottage_door.x, world.cottage_door.y), world.cottage_door.y)
		model.visible = false
		state = "inside"
		reaction = 2.0 + randf() * 5.0
	else:
		position.y = 0.0
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

func _apply_toon_materials() -> void:
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_toon_white = ImageTexture.create_from_image(white)
	toon_materials.clear()
	toon_double_count = 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var source := mi.get_active_material(surface) as StandardMaterial3D
			var material_name := mi.name.to_lower()
			var doubles := false
			var texture: Texture2D = _toon_white
			var tint := Color.WHITE
			if source != null:
				material_name += " " + source.resource_name.to_lower()
				doubles = ("hair" in material_name or "nol" in material_name
					or source.cull_mode == BaseMaterial3D.CULL_DISABLED)
				if source.albedo_texture != null:
					texture = source.albedo_texture
				tint = source.albedo_color
			var toon := ShaderMaterial.new()
			toon.shader = TOON_DOUBLE_SHADER if doubles else TOON_SHADER
			toon.set_shader_parameter("albedo_tex", texture)
			toon.set_shader_parameter("albedo_color", tint)
			toon.set_shader_parameter("alpha_cut", 0.5)
			mi.set_surface_override_material(surface, toon)
			toon_materials.append(toon)
			if doubles:
				toon_double_count += 1

func pose_for_shot(at: Vector3, clip: String) -> void:
	state = "strolling"
	intent = true
	position = at
	model.visible = true
	if clip == "Standing":
		mode = "stroll"
		route.clear()
		wait = 999.0
		_play("Standing", 0.2)
	else:
		_start_task(clip)

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
	_update_schedule(delta)

	if state == "inside":
		model.visible = false
		pace = 0.0
		if world != null:
			world.set_door_open(false)
		if intent:
			state = "opening"
			door_wait = 0.0
			if world != null:
				world.set_door_open(true)
	elif state == "opening":
		model.visible = false
		door_wait += delta
		if not intent:
			state = "inside"
			if world != null:
				world.set_door_open(false)
		elif world != null and world.door_open_amount() > 0.55:
			# Step out once the door is most of the way open, exactly like
			# unitychan.js.
			state = "exiting"
			position = Vector3(world.cottage_threshold.x,
				world.stand(world.cottage_threshold.x, world.cottage_threshold.y),
				world.cottage_threshold.y)
			rotation.y = 0.0
			route = [
				Vector2(world.cottage_door.x, world.cottage_door.y),
				world.cottage_apron,
			]
			pace = 0.0
			model.visible = true
			_play("Walking", 0.0)
	else:
		if not intent and state != "returning":
			_start_return()
		if state == "exiting":
			_walk_route(delta, walk_speed)
			if world != null and Vector2(position.x, position.z).distance_to(
					world.cottage_threshold) > 0.62:
				world.set_door_open(false)
			if route.is_empty():
				state = "strolling"
				mode = "stroll"
				wait = 1.0 + randf() * 2.0
				_choose_next()
		elif state == "returning":
			var return_speed := 1.45 if weather >= 2 else 0.75
			if world != null and route.size() <= 2 \
					and Vector2(position.x, position.z).distance_to(world.cottage_door) < 1.15:
				world.set_door_open(true)
			_walk_route(delta, return_speed)
			if route.is_empty():
				state = "inside"
				model.visible = false
				pace = 0.0
				_play("Standing", 0.0)
				if world != null:
					world.set_door_open(false)
		elif state == "strolling":
			_update_stroll(delta)

	if world != null:
		position.y = world.stand(position.x, position.z)
		if not body.is_empty():
			body["active"] = model.visible
			body["x"] = position.x
			body["z"] = position.z
			body["ignore"] = "house" if _in_doorway() else ""
	_update_fishing_gear()

	if blend_face != null and blink_index >= 0:
		blink -= delta
		if blink <= 0.0:
			blink = 2.2 + randf() * 3.5
			blink_t = 0.16
		blink_t = maxf(0.0, blink_t - delta)
		blend_face.set_blend_shape_value(blink_index, sin(PI * blink_t / 0.16))

func _update_schedule(delta: float) -> void:
	# unitychan.js: 07–19, clear/cloudy/light snow, wind under 11; a 2–7 s
	# reaction delay keeps the switch from looking mechanical.
	var outside := hour >= 7.0 and hour < 19.0 \
		and (weather <= 1 or weather == 4) and wind < 11.0
	if intent != outside and reaction <= 0.0:
		reaction = 2.0 + randf() * 5.0
	reaction = maxf(0.0, reaction - delta)
	intent = outside if reaction <= 0.0 else intent

func _update_stroll(delta: float) -> void:
	if mode == "task":
		_update_task(delta)
	elif wait > 0.0:
		wait -= delta
		pace = lerpf(pace, 0.0, 1.0 - exp(-delta * 6.0))
		_play("Standing", 0.3)
		if animation != null:
			animation.speed_scale = 1.0
		if wait <= 0.0:
			_choose_next()
	elif route.is_empty():
		_choose_next()
	else:
		_walk_route(delta, walk_speed)

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
	if roll < 0.30:
		_begin_journey("gather")
	elif roll < 0.55 and can_fish():
		_begin_journey("fish")
	elif roll < 0.75:
		if randf() < 0.45:
			_start_task("kneel")
		else:
			task_face = rotation.y
			_start_task("salute")
	else:
		wait = 2.0 + randf() * 5.0
		_stroll_next()

func can_fish() -> bool:
	# The web only blocks fishing while the pond is frozen; weather does not
	# matter (unitychan.js checks water.userData.freeze > .3).
	return season != 3 and water_freeze <= 0.3

func _nearest_waypoint() -> int:
	var best := 0
	var best_distance := INF
	for i in range(waypoints.size()):
		var distance := Vector2(position.x, position.z).distance_squared_to(waypoints[i])
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _start_return() -> void:
	state = "returning"
	mode = "stroll"
	task_type = ""
	wait = 0.0
	route = _home_route()
	_play("Walking", 0.25)

func _home_route() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if world == null:
		return result
	var current := Vector2(position.x, position.z)
	if paths != null:
		result = paths.route(world, current, world.cottage_apron)
		if result.size() > 1 and result[0].distance_to(current) < 0.35:
			result.pop_front()
	result.append(world.cottage_door)
	result.append(world.cottage_threshold)
	return result

func _begin_journey(type: String) -> void:
	# Dev presets and the schedule can both call this: make sure she is out of
	# the cottage before starting a task route.
	if state != "strolling":
		if world != null and Vector2(position.x, position.z).distance_to(
				world.cottage_door) < 0.6:
			position = Vector3(world.cottage_apron.x,
				world.stand(world.cottage_apron.x, world.cottage_apron.y),
				world.cottage_apron.y)
		state = "strolling"
		model.visible = true
		if world != null:
			world.set_door_open(false)
	task_type = type
	mode = "to_task"
	route = _task_route(type)
	wait = 0.0
	_play("Walking", 0.3)

func _find_spots() -> void:
	gather_spots.clear()
	shore_spots.clear()
	if world == null or paths == null:
		return
	# Web findSpots(): only the two front-yard beds, each with the three
	# nearest graph nodes and a step toward the bed until her body touches it.
	for bed_value in [Vector2(1.1, 3.3), Vector2(2.7, 3.3)]:
		var bed: Vector2 = bed_value
		var nearest: Array = []
		for node in paths.nodes:
			if node.has("porch"):
				continue
			var p := Vector2(float(node["x"]), float(node["z"]))
			nearest.append([p.distance_to(bed), p])
		nearest.sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0])
		)
		for i in range(mini(3, nearest.size())):
			var node: Vector2 = nearest[i][1]
			var distance := node.distance_to(bed)
			if distance < 0.001:
				continue
			var t := 0.0
			while t < distance:
				var u := (t + 0.02) / distance
				var px := node.x + (bed.x - node.x) * u
				var pz := node.y + (bed.y - node.y) * u
				if not world.is_free_for_walker(px, pz, 0.20):
					break
				t += 0.02
			var u2 := minf(t / distance, 1.0)
			var sx := node.x + (bed.x - node.x) * u2
			var sz := node.y + (bed.y - node.y) * u2
			gather_spots.append({
				"node": node, "x": sx, "z": sz,
				"face": atan2(bed.x - sx, bed.y - sz),
			})
	# Five north-bank fishing spots (165°..225°), walked out to the water's
	# edge and then 0.15 into the grass.
	for degrees in [165, 180, 195, 210, 225]:
		var angle := float(degrees) * PI / 180.0
		var dx := sin(angle)
		var dz := cos(angle)
		var t := 0.5
		while t < 7.0 and world.height(POND.x + dx * t, POND.y + dz * t) \
				< world.water.position.y + 0.1:
			t += 0.05
		var sx := POND.x + dx * (t + 0.15)
		var sz := POND.y + dz * (t + 0.15)
		var index := paths.closest(world, Vector2(sx, sz))
		if index < 0:
			continue
		var node: Dictionary = paths.nodes[index]
		shore_spots.append({
			"node": Vector2(float(node["x"]), float(node["z"])),
			"x": sx, "z": sz, "face": atan2(-dx, -dz),
		})

func _spot_route(spot: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var current := Vector2(position.x, position.z)
	var node: Vector2 = spot["node"]
	if paths != null and world != null:
		result = paths.route(world, current, node)
		if result.size() > 1 and result[0].distance_to(current) < 0.35:
			result.pop_front()
	result.append(Vector2(float(spot["x"]), float(spot["z"])))
	return result

func _task_route(type: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var current := Vector2(position.x, position.z)
	var target := current
	if type == "gather" and not gather_spots.is_empty():
		var spot: Dictionary = gather_spots[randi() % gather_spots.size()]
		task_face = float(spot["face"])
		return _spot_route(spot)
	elif type == "fish" and not shore_spots.is_empty():
		var spot2: Dictionary = shore_spots[randi() % shore_spots.size()]
		task_face = float(spot2["face"])
		return _spot_route(spot2)
	elif type == "gather" and world != null and not world.veg_beds.is_empty():
		var bed: Vector2 = world.veg_beds[randi() % world.veg_beds.size()]
		target = bed + Vector2(0, -1.05)
		task_face = atan2(bed.x - target.x, bed.y - target.y)
	elif type == "fish" and world != null:
		target = world.pond_shore
		task_face = atan2(POND.x - target.x, POND.y - target.y)
	elif type == "salute":
		target = Vector2(-1.0, -0.35)
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
	var current := Vector2(position.x, position.z)
	var target: Vector2 = waypoints[waypoint_index]
	if world != null and paths != null:
		var apron := world.cottage_apron
		var far := randf() > 0.5
		var candidates: Array[Vector2] = []
		for node in paths.nodes:
			if node.has("porch"):
				continue
			var p := Vector2(float(node["x"]), float(node["z"]))
			var radius := p.distance_to(apron)
			if radius > (3.5 if far else 1.2) and radius < (8.5 if far else 4.0) \
					and p.distance_to(current) > 1.2:
				candidates.append(p)
		if not candidates.is_empty():
			target = candidates[randi() % candidates.size()]
	waypoint_index = (waypoint_index + 1) % waypoints.size()
	route.clear()
	if paths != null and world != null:
		route = paths.route(world, current, target)
		if route.size() > 1 and route[0].distance_to(current) < 0.35:
			route.pop_front()
	if route.is_empty():
		route.append(target)
	_play("Walking", 0.3)

func _walk_route(delta: float, speed: float = 0.62) -> void:
	if route.is_empty():
		pace = lerpf(pace, 0.0, 1.0 - exp(-delta * 6.0))
		if mode == "to_task":
			_start_task(task_type)
		else:
			wait = 1.0 + randf() * 2.0
		return
	var target: Vector2 = route[0]
	var flat := target - Vector2(position.x, position.z)
	if flat.length() < 0.10:
		route.pop_front()
		pace = lerpf(pace, 0.0, 1.0 - exp(-delta * 6.0))
		if route.is_empty():
			if mode == "to_task":
				_start_task(task_type)
			else:
				wait = 0.8 + randf() * 2.0
		return
	var direction := flat.normalized()
	pace = lerpf(pace, speed, 1.0 - exp(-delta * 3.0))
	var step := minf(pace * delta, flat.length())
	var start := Vector2(position.x, position.z)
	# Web walk(): step toward the waypoint and let the collision world slide
	# her along whatever is in the way. Water is the only hard stop.
	var point := start + direction * step
	if _can_stand(point):
		if world != null and not body.is_empty():
			point = world.resolve_body(point, 0.20, body)
		position.x = point.x
		position.z = point.y
	var moved := start.distance_to(Vector2(position.x, position.z))
	# Blocked (another walker parked on the waypoint, a post in the way):
	# give up on that waypoint after 1.2 s, exactly like unitychan.js.
	stuck = stuck + delta if moved < step * 0.3 else 0.0
	if stuck > 1.2:
		stuck = 0.0
		route.pop_front()
	var running := pace > 1.1
	_track_feet(start.distance_to(Vector2(position.x, position.z)), running)
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.y), 1.0 - exp(-delta * turn_rate))
	_play("Running" if running else "Walking", 0.25)
	if animation != null:
		animation.speed_scale = pace / (1.7 if running else 0.62)

func _can_stand(p: Vector2) -> bool:
	if world == null:
		return true
	# Colliders are resolved by resolve_body(); only keep her out of the pond.
	if world.is_on_porch(p.x, p.y):
		return true
	return world.wet(p.x, p.y) <= -0.10

func _in_doorway() -> bool:
	if world == null:
		return false
	return absf(position.x - world.cottage_threshold.x) < 0.45 \
		and position.z < world.cottage_door.y + 0.08

## One print per stride, alternating feet either side of her path.
func _track_feet(moved: float, running: bool = false) -> void:
	if footprints == null or moved <= 0.0001:
		return
	stride_left -= moved
	if stride_left > 0.0:
		return
	stride_left = 0.3 if running else 0.19
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
			task_timer = 5.0 + randf() * 5.0
		"fish":
			_play("FishingBegin", 0.3)
			task_timer = _clip_length("FishingBegin") + 0.2
			rod.visible = true
		"salute":
			_play("Salute", 0.3)
			task_timer = _clip_length("Salute") + 0.4
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
		rotation.y = lerp_angle(rotation.y, task_face, 1.0 - exp(-delta * task_turn_rate))
	if task_timer > 0.0:
		if task_type == "fish" and task_phase >= 1:
			_update_fishing_gear()
		return
	if task_type == "fish":
		if task_phase == 0:
			_play("FishingLoop", 0.2)
			task_phase = 1
			task_timer = 12.0 + randf() * 12.0
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
	mode = "stroll"
	task_type = ""
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
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	# unitychan.js draws 10 points with a sine sag of 0.18 between the rod tip
	# and the bobber.
	for i in range(10):
		var u := float(i) / 9.0
		var point := tip.lerp(bobber_position, u)
		point.y -= sin(PI * u) * 0.18
		line_mesh.surface_add_vertex(point)
	line_mesh.surface_end()
	line.global_position = Vector3.ZERO
	line.visible = task_phase == 1
	bobber.visible = task_phase == 1

func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)

