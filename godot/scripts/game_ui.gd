extends CanvasLayer
class_name GameUI

signal time_changed(value: float)
signal wind_changed(value: float)
signal weather_changed(index: int)
signal season_changed(index: int)
signal auto_toggled(enabled: bool)
signal reset_requested
signal quality_changed(index: int)
signal reduced_motion_changed(enabled: bool)

const MotionPreviewScript = preload("res://scripts/motion_preview.gd")
const WEATHER_NAMES := ["맑음", "흐림", "비", "안개", "눈", "눈보라"]
const SEASON_NAMES := ["봄", "여름", "가을", "겨울"]

var time_slider: HSlider
var wind_slider: HSlider
var time_thumb: Panel
var wind_thumb: Panel
var time_display := 8.5
var wind_display := 3.0
var time_value: Label
var wind_value: Label
var auto_check: CheckBox
var auto_hint: Label
var horizon_preview: MotionPreviewScript
var wind_preview: MotionPreviewScript
var weather_preview: MotionPreviewScript
var panel_control: PanelContainer
var body_control: VBoxContainer
var toggle_button: Button
var toggle_action: Label
var bottom_box: VBoxContainer
var credit_label: LinkButton
var reset_button: Button
var ui_theme: Theme
var panel_style: StyleBoxFlat
var weather_chips: Array[Button] = []
var season_chips: Array[Button] = []
var rows: Array[HBoxContainer] = []
var previews: Array[Control] = []
var reduced_motion := false
var quality_index := 0
var weather_index := 0
var season_index := 1
var _syncing := false
var _bold_font: FontVariation

func _ready() -> void:
	ui_theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Apple SD Gothic Neo", "Segoe UI", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 12
	_bold_font = FontVariation.new()
	_bold_font.base_font = font
	_bold_font.variation_embolden = 0.55
	var shadow := Color(0.06, 0.11, 0.15, 0.60)
	for type_name in ["Label", "Button", "CheckBox"]:
		ui_theme.set_color("font_color", type_name, Color(1, 1, 1, 0.94))
		ui_theme.set_color("font_shadow_color", type_name, shadow)
		ui_theme.set_constant("shadow_offset_x", type_name, 0)
		ui_theme.set_constant("shadow_offset_y", type_name, 1)
		ui_theme.set_constant("shadow_outline_size", type_name, 3)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ui_theme
	add_child(root)

	credit_label = LinkButton.new()
	credit_label.text = "SD Unity-chan © Unity Technologies Japan/UCL"
	credit_label.uri = "https://unity-chan.com/contents/license_en/"
	credit_label.add_theme_font_size_override("font_size", 11)
	credit_label.add_theme_color_override("font_color", Color(0.17, 0.23, 0.27, 1.0))
	credit_label.add_theme_color_override("font_hover_color", Color(0.10, 0.15, 0.18, 1.0))
	var credit_style := StyleBoxFlat.new()
	credit_style.bg_color = Color(1, 1, 1, 0.66)
	credit_style.set_corner_radius_all(6)
	credit_style.content_margin_left = 8
	credit_style.content_margin_right = 8
	credit_style.content_margin_top = 3
	credit_style.content_margin_bottom = 3
	credit_label.add_theme_stylebox_override("normal", credit_style)
	credit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit_label.offset_left = 12.0
	credit_label.offset_right = 300.0
	credit_label.offset_top = -28.0
	credit_label.offset_bottom = -8.0
	credit_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(credit_label)

	bottom_box = VBoxContainer.new()
	bottom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_box.offset_left = 14
	bottom_box.offset_right = -14
	bottom_box.offset_top = -640
	bottom_box.offset_bottom = -18
	bottom_box.alignment = BoxContainer.ALIGNMENT_END
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0)
	panel_style.border_color = Color(1, 1, 1, 0.45)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 0
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	panel_control = panel
	bottom_box.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	toggle_button = Button.new()
	toggle_button.text = "환경 설정"
	toggle_button.flat = true
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.custom_minimum_size = Vector2(0, 42)
	toggle_button.add_theme_font_size_override("font_size", 12)
	toggle_button.add_theme_font_override("font", _bold_font)
	toggle_button.pressed.connect(func() -> void:
		set_panel_open(not body_control.visible)
	)
	outer.add_child(toggle_button)
	toggle_action = Label.new()
	toggle_action.text = "펼치기  ▾"
	toggle_action.add_theme_font_size_override("font_size", 11)
	toggle_action.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	toggle_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle_action.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	toggle_action.offset_left = -110
	toggle_action.offset_right = -22
	toggle_button.add_child(toggle_action)

	body_control = VBoxContainer.new()
	body_control.add_theme_constant_override("separation", 0)
	body_control.visible = false
	outer.add_child(body_control)

	_build_time_row()
	_build_wind_row()
	_build_weather_row()
	_build_footer()

	weather_index = 0
	season_index = 1
	_refresh_chips(weather_chips, weather_index)
	_refresh_chips(season_chips, season_index)
	time_slider.value_changed.connect(_on_time_changed)
	wind_slider.value_changed.connect(_on_wind_changed)
	auto_check.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	horizon_preview.set_time(time_slider.value)
	wind_preview.set_wind(wind_slider.value)
	weather_preview.set_weather(weather_index)

func _build_time_row() -> void:
	var row := _start_row()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	var caption := HBoxContainer.new()
	left.add_child(caption)
	var label := Label.new()
	label.text = "시각"
	label.add_theme_font_override("font", _bold_font)
	caption.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_child(spacer)
	time_value = Label.new()
	time_value.text = "08:30"
	time_value.add_theme_font_size_override("font_size", 12)
	caption.add_child(time_value)
	time_slider = _new_slider(0.0, 24.0, 1.0 / 60.0, 8.5)
	left.add_child(time_slider)
	time_thumb = _new_thumb()
	time_slider.add_child(time_thumb)
	time_slider.resized.connect(_update_time_thumb)
	auto_check = CheckBox.new()
	auto_check.text = "시간 자동 진행"
	auto_check.custom_minimum_size = Vector2(0, 22)
	auto_check.add_theme_font_size_override("font_size", 11)
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 4)
	auto_row.add_child(auto_check)
	auto_hint = Label.new()
	auto_hint.text = "120초 / 하루"
	auto_hint.add_theme_font_size_override("font_size", 9)
	auto_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	auto_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auto_row.add_child(auto_hint)
	left.add_child(auto_row)
	horizon_preview = MotionPreviewScript.new()
	horizon_preview.mode = 0
	_add_preview(row, horizon_preview)

func _build_wind_row() -> void:
	var row := _start_row()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	var caption := HBoxContainer.new()
	left.add_child(caption)
	var label := Label.new()
	label.text = "바람"
	label.add_theme_font_override("font", _bold_font)
	caption.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_child(spacer)
	wind_value = Label.new()
	wind_value.text = "3 m/s"
	wind_value.add_theme_font_size_override("font_size", 12)
	caption.add_child(wind_value)
	wind_slider = _new_slider(0.0, 16.0, 0.5, 3.0)
	left.add_child(wind_slider)
	wind_thumb = _new_thumb()
	wind_slider.add_child(wind_thumb)
	wind_slider.resized.connect(_update_wind_thumb)
	wind_preview = MotionPreviewScript.new()
	wind_preview.mode = 1
	_add_preview(row, wind_preview)

func _build_weather_row() -> void:
	var row := _start_row()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	var label := Label.new()
	label.text = "날씨"
	label.add_theme_font_override("font", _bold_font)
	left.add_child(label)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	left.add_child(flow)
	for i in range(WEATHER_NAMES.size()):
		var chip := _new_chip(WEATHER_NAMES[i], group)
		chip.pressed.connect(func() -> void: _on_weather_chip(i))
		flow.add_child(chip)
		weather_chips.append(chip)
	weather_preview = MotionPreviewScript.new()
	weather_preview.mode = 2
	_add_preview(row, weather_preview)

func _build_footer() -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.16)
	line.custom_minimum_size = Vector2(0, 1)
	body_control.add_child(line)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 11)
	body_control.add_child(margin)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	margin.add_child(footer)
	var label := Label.new()
	label.text = "계절"
	label.add_theme_font_override("font", _bold_font)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(label)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 2)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.custom_minimum_size = Vector2(210, 0)
	footer.add_child(flow)
	for i in range(SEASON_NAMES.size()):
		var chip := _new_chip(SEASON_NAMES[i], group)
		chip.pressed.connect(func() -> void: _on_season_chip(i))
		flow.add_child(chip)
		season_chips.append(chip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	reset_button = Button.new()
	reset_button.text = "처음 시점"
	reset_button.custom_minimum_size = Vector2(0, 26)
	reset_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_button.add_theme_font_size_override("font_size", 10)
	reset_button.add_theme_stylebox_override("normal", _border_style(Color(0, 0, 0, 0), Color(1, 1, 1, 0.28), 6, 5, 9))
	reset_button.add_theme_stylebox_override("hover", _border_style(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.40), 6, 5, 9))
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	footer.add_child(reset_button)

func _start_row() -> HBoxContainer:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.16)
	line.custom_minimum_size = Vector2(0, 1)
	body_control.add_child(line)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	body_control.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	rows.append(row)
	return row

func _add_preview(row: HBoxContainer, preview: Control) -> void:
	preview.custom_minimum_size = Vector2(230, 98)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_END
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(preview)
	previews.append(preview)

func _new_slider(minimum: float, maximum: float, step: float, initial: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxLine.new()
	track.color = Color(1, 1, 1, 0.20)
	track.thickness = 2
	var fill := StyleBoxLine.new()
	fill.color = Color(1, 1, 1, 0.92)
	fill.thickness = 2
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	# The native grabber is hidden; a separate Panel glides over the track so
	# the thumb follows the shown value rather than the slider target (I8).
	slider.add_theme_icon_override("grabber", _empty_texture())
	slider.add_theme_icon_override("grabber_highlight", _empty_texture())
	return slider

func _empty_texture() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)

func _new_thumb() -> Panel:
	var thumb := Panel.new()
	thumb.custom_minimum_size = Vector2(11, 11)
	thumb.size = Vector2(11, 11)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.22)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	thumb.add_theme_stylebox_override("panel", style)
	return thumb

func _update_time_thumb() -> void:
	if time_thumb == null or time_slider == null:
		return
	var t := clampf(fposmod(time_display, 24.0) / 24.0, 0.0, 1.0)
	var span := maxf(time_slider.size.x - 14.0, 1.0)
	time_thumb.position = Vector2(7.0 + span * t - 5.5,
		time_slider.size.y * 0.5 - 5.5)

func _update_wind_thumb() -> void:
	if wind_thumb == null or wind_slider == null:
		return
	var t := clampf(wind_display / 16.0, 0.0, 1.0)
	var span := maxf(wind_slider.size.x - 14.0, 1.0)
	wind_thumb.position = Vector2(7.0 + span * t - 5.5,
		wind_slider.size.y * 0.5 - 5.5)

func _border_style(bg: Color, border: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style

func _new_chip(text: String, group: ButtonGroup) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.toggle_mode = true
	chip.button_group = group
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(0, 27)
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_stylebox_override("normal", _border_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 10, 3))
	chip.add_theme_stylebox_override("hover", _border_style(Color(1, 1, 1, 0.09), Color(0, 0, 0, 0), 6, 10, 3))
	chip.add_theme_stylebox_override("pressed", _border_style(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.65), 6, 10, 3))
	chip.add_theme_stylebox_override("hover_pressed", _border_style(Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.75), 6, 10, 3))
	chip.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	chip.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	chip.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	chip.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 1, 1))
	return chip

func _refresh_chips(chips: Array[Button], selected: int) -> void:
	for i in range(chips.size()):
		var chip: Button = chips[i]
		chip.set_pressed_no_signal(i == selected)
		if i == selected:
			chip.add_theme_font_override("font", _bold_font)
		else:
			chip.remove_theme_font_override("font")

func _on_weather_chip(index: int) -> void:
	weather_index = index
	_refresh_chips(weather_chips, index)
	weather_preview.set_weather(index)
	weather_changed.emit(index)

func _on_season_chip(index: int) -> void:
	season_index = index
	_refresh_chips(season_chips, index)
	season_changed.emit(index)

func _apply_responsive_layout() -> void:
	if panel_control == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 560.0
	var margin := 8.0 if compact else 14.0
	var safe_left := 0.0
	var safe_top := 0.0
	var safe_right := 0.0
	var safe_bottom := 0.0
	if DisplayServer.get_name() in ["android", "ios"]:
		var safe := DisplayServer.get_display_safe_area()
		var window_size := DisplayServer.window_get_size()
		var sx := viewport_size.x / maxf(float(window_size.x), 1.0)
		var sy := viewport_size.y / maxf(float(window_size.y), 1.0)
		safe_left = float(safe.position.x) * sx
		safe_top = float(safe.position.y) * sy
		safe_right = float(window_size.x - safe.end.x) * sx
		safe_bottom = float(window_size.y - safe.end.y) * sy
	bottom_box.offset_left = margin + safe_left
	bottom_box.offset_right = -margin - safe_right
	bottom_box.offset_top = -minf(640.0, maxf(viewport_size.y - 16.0, 180.0))
	bottom_box.offset_bottom = -18.0 - safe_bottom
	panel_control.custom_minimum_size = Vector2(
		minf(650.0, maxf(viewport_size.x - margin * 2.0, 240.0)), 0.0)
	panel_style.content_margin_left = 14.0 if compact else 22.0
	panel_style.content_margin_right = 14.0 if compact else 22.0
	panel_style.content_margin_bottom = 10.0 if compact else 14.0
	panel_style.set_corner_radius_all(14 if compact else 16)
	ui_theme.default_font_size = 11 if compact else 12
	toggle_button.custom_minimum_size.y = 38.0 if compact else 42.0
	auto_hint.visible = not compact
	var preview_size := Vector2(100, 43) if compact else Vector2(230, 98)
	for preview in previews:
		preview.custom_minimum_size = preview_size
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	for row in rows:
		row.add_theme_constant_override("separation", 14 if compact else 28)
	for chip in weather_chips + season_chips:
		chip.add_theme_constant_override("h_separation", 0)
		chip.add_theme_font_size_override("font_size", 10 if compact else 11)
		chip.custom_minimum_size.y = 24.0 if compact else 27.0
		chip.add_theme_stylebox_override("normal", _border_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 7 if compact else 10, 3))
		chip.add_theme_stylebox_override("pressed", _border_style(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.65), 6, 7 if compact else 10, 3))
	time_slider.custom_minimum_size.y = 24
	wind_slider.custom_minimum_size.y = 24
	if compact:
		credit_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		credit_label.offset_left = 10.0 + safe_left
		credit_label.offset_top = 8.0 + safe_top
		credit_label.offset_right = 300.0
		credit_label.offset_bottom = 30.0
		credit_label.grow_vertical = Control.GROW_DIRECTION_END
	else:
		credit_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		credit_label.offset_left = 12.0 + safe_left
		credit_label.offset_right = 320.0
		credit_label.offset_top = -28.0
		credit_label.offset_bottom = -8.0
		credit_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_update_time_thumb()
	_update_wind_thumb()

func _on_time_changed(value: float) -> void:
	if not _syncing:
		time_changed.emit(value)

func _on_wind_changed(value: float) -> void:
	if not _syncing:
		wind_changed.emit(value)

func set_time_target(value: float) -> void:
	_syncing = true
	time_slider.value = value
	_syncing = false

func set_time_display(value: float) -> void:
	time_display = fposmod(value, 24.0)
	time_value.text = format_hour(value)
	if horizon_preview != null:
		horizon_preview.set_time(value)
	_update_time_thumb()

func set_time_value(value: float) -> void:
	set_time_target(value)
	set_time_display(value)

func set_wind_target(value: float) -> void:
	_syncing = true
	wind_slider.value = value
	_syncing = false

func set_wind_display(value: float) -> void:
	wind_display = value
	wind_value.text = str(round(value * 10.0) / 10.0) + " m/s"
	if wind_preview != null:
		wind_preview.set_wind(value)
	_update_wind_thumb()

func set_wind_value(value: float) -> void:
	set_wind_target(value)
	set_wind_display(value)

func set_auto(enabled: bool) -> void:
	_syncing = true
	auto_check.set_pressed_no_signal(enabled)
	_syncing = false

func is_auto() -> bool:
	return auto_check.button_pressed

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for preview in [horizon_preview, wind_preview, weather_preview]:
		if preview != null:
			preview.reduced_motion = enabled
	reduced_motion_changed.emit(enabled)

func is_reduced_motion() -> bool:
	return reduced_motion

func is_panel_open() -> bool:
	return body_control != null and body_control.visible

func get_time() -> float:
	return time_slider.value

func get_wind() -> float:
	return wind_slider.value

func set_weather(index: int) -> void:
	weather_index = clampi(index, 0, WEATHER_NAMES.size() - 1)
	_refresh_chips(weather_chips, weather_index)
	if weather_preview != null:
		weather_preview.set_weather(weather_index)

func set_season(index: int) -> void:
	season_index = clampi(index, 0, SEASON_NAMES.size() - 1)
	_refresh_chips(season_chips, season_index)

func set_quality(index: int) -> void:
	quality_index = index

func get_quality() -> int:
	return quality_index

func set_panel_open(open: bool) -> void:
	if body_control == null:
		return
	body_control.visible = open
	toggle_action.text = "접기  ▴" if open else "펼치기  ▾"
	if open:
		body_control.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(body_control, "modulate:a", 1.0, 0.30)
	else:
		body_control.modulate.a = 1.0

func get_panel_rect() -> Rect2:
	if panel_control == null:
		return Rect2()
	return panel_control.get_global_rect()

static func format_hour(hour: float) -> String:
	var minutes := int(round(hour * 60.0))
	minutes = ((minutes % 1440) + 1440) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]
