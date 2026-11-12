@tool
extends CompositorEffect
class_name AtmosphereEffect

## Half-resolution depth-aware light-shaft CompositorEffect for Forward+.
## A compute pass produces a half-res shaft texture from the scene color and
## depth; a second pass adds it to a full-res output texture, which is copied
## back into the HDR scene color. The depth buffer masks foreground occluders
## (screen-space depth masking, since the sun shadow map is not exposed here).

var sun_uv := Vector2(-10.0, -10.0)
var sun_strength := 0.0
var sun_color := Color(1.0, 0.85, 0.62)
var depth_sign := -1.0
var gain := 2.5
var active := true

var rd: RenderingDevice
var initialized := false
var working := false
var supported := false
var logged := false

var shaft_shader: RID
var composite_shader: RID
var shaft_pipeline: RID
var composite_pipeline: RID
var sampler: RID
var params_buffer: RID

var shaft_texture: RID
var output_texture: RID
var shaft_set: RID
var composite_set: RID
var cached_size := Vector2i.ZERO
var cached_color := RID()
var cached_depth := RID()

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	RenderingServer.call_on_render_thread(_initialize_compute)

func shutdown() -> void:
	# Called by the scene before quitting while the RenderingServer is still alive.
	if initialized:
		initialized = false
		RenderingServer.call_on_render_thread(_shutdown)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_warning("AtmosphereEffect: no RenderingDevice (Forward+ required)")
		return
	var shaft_source := RDShaderSource.new()
	shaft_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shaft_source.source_compute = FileAccess.get_file_as_string("res://shaders/atmosphere_shafts.glsl").replace("#[compute]\n", "")
	var composite_source := RDShaderSource.new()
	composite_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	composite_source.source_compute = FileAccess.get_file_as_string("res://shaders/atmosphere_composite.glsl").replace("#[compute]\n", "")
	var shaft_spirv := rd.shader_compile_spirv_from_source(shaft_source)
	var composite_spirv := rd.shader_compile_spirv_from_source(composite_source)
	if shaft_spirv.compile_error_compute != "":
		push_error("AtmosphereEffect shafts: " + shaft_spirv.compile_error_compute)
		return
	if composite_spirv.compile_error_compute != "":
		push_error("AtmosphereEffect composite: " + composite_spirv.compile_error_compute)
		return
	shaft_shader = rd.shader_create_from_spirv(shaft_spirv, "atmosphere_shafts")
	composite_shader = rd.shader_create_from_spirv(composite_spirv, "atmosphere_composite")
	shaft_pipeline = rd.compute_pipeline_create(shaft_shader, [])
	composite_pipeline = rd.compute_pipeline_create(composite_shader, [])
	var sampler_state := RDSamplerState.new()
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(sampler_state)
	params_buffer = rd.uniform_buffer_create(64, PackedByteArray())
	initialized = true
	working = true

func _render_callback(_callback_type: int, render_data: RenderData) -> void:
	if not initialized or not active:
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
		_build(buffers, size, color_rid, depth_rid)
		if not supported:
			return

	var params := PackedFloat32Array()
	params.resize(16)
	params[0] = sun_uv.x
	params[1] = sun_uv.y
	params[2] = 0.0
	params[3] = 0.0
	params[4] = sun_color.r
	params[5] = sun_color.g
	params[6] = sun_color.b
	params[7] = sun_strength * gain
	params[8] = float(size.x)
	params[9] = float(size.y)
	params[10] = float(Time.get_ticks_msec()) * 0.001
	params[11] = depth_sign
	params[12] = 0.0
	params[13] = 0.0
	params[14] = 0.0
	params[15] = 0.0
	rd.buffer_update(params_buffer, 0, 64, params.to_byte_array())

	var shaft_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(shaft_list, shaft_pipeline)
	rd.compute_list_bind_uniform_set(shaft_list, shaft_set, 0)
	var half_w := maxi(1, (size.x + 1) / 2)
	var half_h := maxi(1, (size.y + 1) / 2)
	rd.compute_list_dispatch(shaft_list, (half_w + 7) / 8, (half_h + 7) / 8, 1)
	rd.compute_list_end()

	var composite_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(composite_list, composite_pipeline)
	rd.compute_list_bind_uniform_set(composite_list, composite_set, 0)
	rd.compute_list_dispatch(composite_list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	rd.compute_list_end()

	rd.texture_copy(output_texture, color_rid, Vector3.ZERO, Vector3.ZERO,
		Vector3(size.x, size.y, 1), 0, 0, 0, 0)

func _build(buffers: RenderSceneBuffersRD, size: Vector2i, color_rid: RID, depth_rid: RID) -> void:
	supported = false
	working = false
	_free_resources()
	var color_format: RDTextureFormat = rd.texture_get_format(color_rid)
	var depth_format: RDTextureFormat = rd.texture_get_format(depth_rid)
	if color_format.format != RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT:
		push_warning("AtmosphereEffect: expected RGBA16F scene color, got " + str(color_format.format))
		return
	if (color_format.usage_bits & RenderingDevice.TEXTURE_USAGE_STORAGE_BIT) == 0:
		push_warning("AtmosphereEffect: scene color has no storage usage")
		return
	if color_format.samples != RenderingDevice.TEXTURE_SAMPLES_1:
		push_warning("AtmosphereEffect: scene color is multisampled")
		return
	if depth_format.samples != RenderingDevice.TEXTURE_SAMPLES_1:
		push_warning("AtmosphereEffect: depth is multisampled")
		return

	var shaft_format := RDTextureFormat.new()
	shaft_format.width = maxi(1, (size.x + 1) / 2)
	shaft_format.height = maxi(1, (size.y + 1) / 2)
	shaft_format.depth = 1
	shaft_format.array_layers = 1
	shaft_format.mipmaps = 1
	shaft_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	shaft_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	shaft_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	shaft_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	shaft_texture = rd.texture_create(shaft_format, RDTextureView.new(), [])

	var output_format := RDTextureFormat.new()
	output_format.width = size.x
	output_format.height = size.y
	output_format.depth = 1
	output_format.array_layers = 1
	output_format.mipmaps = 1
	output_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	output_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	output_format.format = color_format.format
	output_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	output_texture = rd.texture_create(output_format, RDTextureView.new(), [])

	var shaft_uniforms: Array[RDUniform] = []
	var u_color := RDUniform.new()
	u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_color.binding = 0
	u_color.add_id(sampler)
	u_color.add_id(color_rid)
	shaft_uniforms.append(u_color)
	var u_depth := RDUniform.new()
	u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_depth.binding = 1
	u_depth.add_id(sampler)
	u_depth.add_id(depth_rid)
	shaft_uniforms.append(u_depth)
	var u_shaft := RDUniform.new()
	u_shaft.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_shaft.binding = 2
	u_shaft.add_id(shaft_texture)
	shaft_uniforms.append(u_shaft)
	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	u_params.binding = 3
	u_params.add_id(params_buffer)
	shaft_uniforms.append(u_params)
	shaft_set = rd.uniform_set_create(shaft_uniforms, shaft_shader, 0)

	var composite_uniforms: Array[RDUniform] = []
	var u_copy := RDUniform.new()
	u_copy.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_copy.binding = 0
	u_copy.add_id(sampler)
	u_copy.add_id(color_rid)
	composite_uniforms.append(u_copy)
	var u_shaft_tex := RDUniform.new()
	u_shaft_tex.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_shaft_tex.binding = 1
	u_shaft_tex.add_id(sampler)
	u_shaft_tex.add_id(shaft_texture)
	composite_uniforms.append(u_shaft_tex)
	var u_output := RDUniform.new()
	u_output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_output.binding = 2
	u_output.add_id(output_texture)
	composite_uniforms.append(u_output)
	composite_set = rd.uniform_set_create(composite_uniforms, composite_shader, 0)

	cached_size = size
	cached_color = color_rid
	cached_depth = depth_rid
	supported = true
	working = true
	if not logged:
		logged = true
		print("ATMOSPHERE ready ", size, " shaft=", shaft_format.width, "x", shaft_format.height,
			" color_fmt=", color_format.format)

func _shutdown() -> void:
	if rd == null:
		return
	_free_resources()
	if params_buffer.is_valid():
		rd.free_rid(params_buffer)
	if sampler.is_valid():
		rd.free_rid(sampler)
	if shaft_pipeline.is_valid():
		rd.free_rid(shaft_pipeline)
	if composite_pipeline.is_valid():
		rd.free_rid(composite_pipeline)
	if shaft_shader.is_valid():
		rd.free_rid(shaft_shader)
	if composite_shader.is_valid():
		rd.free_rid(composite_shader)
	params_buffer = RID()
	sampler = RID()
	shaft_pipeline = RID()
	composite_pipeline = RID()
	shaft_shader = RID()
	composite_shader = RID()
	working = false

func _free_resources() -> void:
	if shaft_set.is_valid():
		rd.free_rid(shaft_set)
	if composite_set.is_valid():
		rd.free_rid(composite_set)
	if shaft_texture.is_valid():
		rd.free_rid(shaft_texture)
	if output_texture.is_valid():
		rd.free_rid(output_texture)
	shaft_set = RID()
	composite_set = RID()
	shaft_texture = RID()
	output_texture = RID()
