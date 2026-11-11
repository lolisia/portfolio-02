extends Node3D
class_name UnityChan

## Basic port of the character loader. The imported GLB contains the skinned
## body, blend shapes for the eyes, and all ten animation clips.

const MODEL_PATH := "res://assets/models/unitychan/sd_unitychan.glb"
const TARGET_HEIGHT := 1.02

var world: FarmWorld
var model: Node3D
var animation: AnimationPlayer
var blend_face: MeshInstance3D
var blink_index := -1
var blink := 2.0
var blink_t := 0.0

func _ready() -> void:
	var packed := load(MODEL_PATH)
	if packed == null:
		push_warning("Unity-chan failed to import")
		return
	model = packed.instantiate()
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		for clip_name in ["Standing", "Walking", "Running"]:
			if animation.has_animation(clip_name):
				animation.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		animation.play("Standing")
		animation.seek(0.0, true)
		animation.advance(0.0)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		skeleton.force_update_all_bone_transforms()
	_fit_model()
	_find_face()
	position.y = world.height(position.x, position.z) if world != null else 0.0

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

func _process(delta: float) -> void:
	if model == null:
		return
	if world != null:
		position.y = world.height(position.x, position.z)
	if blend_face != null and blink_index >= 0:
		blink -= delta
		if blink <= 0.0:
			blink = 2.2 + randf() * 3.5
			blink_t = 0.16
		blink_t = maxf(0.0, blink_t - delta)
		blend_face.set_blend_shape_value(blink_index, sin(PI * blink_t / 0.16))

func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)
