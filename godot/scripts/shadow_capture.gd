@tool
extends CompositorEffect
class_name ShadowCaptureEffect

## Runs on the sun's shadow camera. Converts the camera's depth buffer into a
## linear-distance texture (stored in the camera's color buffer) that the main
## atmosphere compositor can sample as a true sun shadow map.

var rd: RenderingDevice
var initialized := false
var working := false
var shader: RID
var pipeline: RID
var sampler: RID
var params_buffer: RID
var uniform_set: RID
var cached_size := Vector2i.ZERO
var cached_color := RID()
var cached_depth := RID()
var capture_rid := RID()
var near_plane := 0.1
var far_plane := 120.0

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	RenderingServer.call_on_render_thread(_initialize)

func _initialize() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("ShadowCaptureEffect: no RenderingDevice")
		return
	var source := RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_compute = FileAccess.get_file_as_string("res://shaders/shadow_capture.glsl").replace("#[compute]\n", "")
	var spirv := rd.shader_compile_spirv_from_source(source)
	if spirv.compile_error_compute != "":
		push_error("ShadowCaptureEffect: " + spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv, "shadow_capture")
	pipeline = rd.compute_pipeline_create(shader, [])
	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(sampler_state)
	params_buffer = rd.uniform_buffer_create(16, PackedByteArray())
	initialized = true

func _render_callback(_callback_type: int, render_data: RenderData) -> void:
	if not initialized:
		return
	var buffers := render_data.get_render_scene_buffers()
	if buffers == null:
		return
	var size: Vector2i = buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	var color_rid: RID = buffers.get_color_layer(0)
	var depth_rid: RID = buffers.get_depth_layer(0)
	if size != cached_size or color_rid != cached_color or depth_rid != cached_depth:
		_build(size, color_rid, depth_rid)
		if not working:
			return

	var params := PackedFloat32Array()
	params.resize(4)
	params[0] = near_plane
	params[1] = far_plane
	params[2] = 0.0
	params[3] = 0.0
	rd.buffer_update(params_buffer, 0, 16, params.to_byte_array())

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	rd.compute_list_end()
	capture_rid = color_rid

func _build(size: Vector2i, color_rid: RID, depth_rid: RID) -> void:
	working = false
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
		uniform_set = RID()
	var color_format := rd.texture_get_format(color_rid)
	var depth_format := rd.texture_get_format(depth_rid)
	if color_format.format != RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT:
		push_warning("ShadowCaptureEffect: unexpected color format " + str(color_format.format))
		return
	if color_format.samples != RenderingDevice.TEXTURE_SAMPLES_1:
		push_warning("ShadowCaptureEffect: multisampled color")
		return
	if depth_format.samples != RenderingDevice.TEXTURE_SAMPLES_1:
		push_warning("ShadowCaptureEffect: multisampled depth")
		return

	var uniforms: Array[RDUniform] = []
	var u_depth := RDUniform.new()
	u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_depth.binding = 0
	u_depth.add_id(sampler)
	u_depth.add_id(depth_rid)
	uniforms.append(u_depth)
	var u_color := RDUniform.new()
	u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_color.binding = 1
	u_color.add_id(color_rid)
	uniforms.append(u_color)
	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u_params.binding = 2
	u_params.add_id(params_buffer)
	uniforms.append(u_params)
	uniform_set = rd.uniform_set_create(uniforms, shader, 0)
	cached_size = size
	cached_color = color_rid
	cached_depth = depth_rid
	working = true

func shutdown() -> void:
	if initialized:
		initialized = false
		RenderingServer.call_on_render_thread(_shutdown)

func _shutdown() -> void:
	if rd == null:
		return
	if uniform_set.is_valid():
		rd.free_rid(uniform_set)
	if params_buffer.is_valid():
		rd.free_rid(params_buffer)
	if sampler.is_valid():
		rd.free_rid(sampler)
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	if shader.is_valid():
		rd.free_rid(shader)
	uniform_set = RID()
	params_buffer = RID()
	sampler = RID()
	pipeline = RID()
	shader = RID()
	working = false
