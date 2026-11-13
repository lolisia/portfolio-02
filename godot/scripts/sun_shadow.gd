extends Node
class_name SunShadow

## Renders a small orthographic depth map from the sun. Godot does not expose
## the directional light's shadow atlas to CompositorEffects, so this pass
## gives the fog raymarch a true sun-occlusion source instead of only the
## screen-space depth proxy.

const ShadowCaptureEffectScript = preload("res://scripts/shadow_capture.gd")

const SHADOW_SIZE := 1024
const SHADOW_EXTENT := 40.0
const CAMERA_DISTANCE := 60.0
const CAMERA_FAR := 120.0

var viewport: SubViewport
var camera: Camera3D
var compositor: Compositor
var capture: ShadowCaptureEffectScript
var active := true
var _last_direction := Vector3.ZERO
var _has_direction := false
var _post_draw_connected := false

func setup(world: World3D) -> void:
	viewport = SubViewport.new()
	viewport.name = "SunShadowViewport"
	viewport.size = Vector2i(SHADOW_SIZE, SHADOW_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.use_hdr_2d = true
	viewport.transparent_bg = false
	add_child(viewport)
	if world != null:
		viewport.world_3d = world

	camera = Camera3D.new()
	camera.name = "SunShadowCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SHADOW_EXTENT
	camera.near = 0.1
	camera.far = CAMERA_FAR
	camera.current = true
	var shadow_env := Environment.new()
	shadow_env.background_mode = Environment.BG_COLOR
	shadow_env.background_color = Color.BLACK
	shadow_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	shadow_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	shadow_env.glow_enabled = false
	shadow_env.fog_enabled = false
	shadow_env.volumetric_fog_enabled = false
	camera.environment = shadow_env
	capture = ShadowCaptureEffectScript.new()
	capture.near_plane = camera.near
	capture.far_plane = camera.far
	compositor = Compositor.new()
	compositor.compositor_effects = [capture]
	camera.compositor = compositor
	viewport.add_child(camera)

	set_sun(Vector3(0.55, 0.75, 0.36))

func set_sun(direction: Vector3) -> void:
	if camera == null:
		return
	var dir := direction.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	var target := Vector3(0.0, 1.0, 0.0)
	camera.position = target + dir * CAMERA_DISTANCE
	camera.look_at(target, Vector3.UP)
	# The shadow map only depends on the sun direction, not the orbit camera.
	# Refresh it only when the sun has moved enough to matter.
	if not _has_direction or _last_direction.dot(dir) < 0.999998:
		_last_direction = dir
		_has_direction = true
		_request_update()

func _request_update() -> void:
	if not active or viewport == null:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not _post_draw_connected:
		_post_draw_connected = true
		RenderingServer.frame_post_draw.connect(_on_post_draw)

func _on_post_draw() -> void:
	_post_draw_connected = false
	RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func capture_rid() -> RID:
	return capture.capture_rid if capture != null else RID()

func set_active(enabled: bool) -> void:
	active = enabled
	if viewport == null:
		return
	if enabled:
		_has_direction = false
		_request_update()
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func shutdown() -> void:
	if capture != null:
		capture.shutdown()
