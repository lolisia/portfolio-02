extends CanvasLayer
class_name GameUI

signal time_changed(value: float)
signal wind_changed(value: float)
signal weather_changed(index: int)
signal season_changed(index: int)
signal auto_toggled(enabled: bool)
signal reset_requested
signal quality_changed(index: int)

const MotionPreviewScript = preload("res://scripts/motion_preview.gd")

var time_slider: HSlider
var wind_slider: HSlider
var time_value: Label
var wind_value: Label
var auto_check: CheckBox
var weather_option: OptionButton
var season_option: OptionButton
var quality_option: OptionButton
var horizon_preview: MotionPreviewScript
var wind_preview: MotionPreviewScript
var weather_preview: MotionPreviewScript
var panel_control: PanelContainer
var body_control: VBoxContainer
var toggle_button: Button
var _syncing := false
var ui_theme: Theme
var panel_style: StyleBoxFlat
var bottom_box: VBoxContainer
var credit_label: LinkButton
var weather_label: Label
var season_label: Label
var option_box: BoxContainer
var reset_button: Button
var reset_spacer: Control
var auto_label_full := "시간 자동 진행 (120초 / 하루)"
var auto_label_compact := "시간 자동 진행"

func _ready() -> void:
	ui_theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Apple SD Gothic Neo", "Segoe UI", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color(1, 1, 1, 0.94))
	ui_theme.set_color("font_color", "Button", Color(1, 1, 1, 0.94))
	ui_theme.set_color("font_color", "CheckBox", Color(1, 1, 1, 0.9))
	ui_theme.set_color("font_color", "OptionButton", Color(1, 1, 1, 0.94))

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ui_theme
	add_child(root)

	credit_label = LinkButton.new()
	credit_label.text = "SD Unity-chan © Unity Technologies Japan/UCL"
	credit_label.uri = "https://unity-chan.com/contents/license_en/"
	credit_label.add_theme_font_size_override("font_size", 10)
	credit_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	credit_label.offset_left = 12
	credit_label.offset_top = 8
	root.add_child(credit_label)

	bottom_box = VBoxContainer.new()
	bottom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_box.offset_left = 14
	bottom_box.offset_right = -14
	bottom_box.offset_top = -640
	bottom_box.offset_bottom = -16
	bottom_box.alignment = BoxContainer.ALIGNMENT_END
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.085, 0.125, 0.075, 0.60)
	panel_style.border_color = Color(1, 1, 1, 0.24)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(16)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	panel_control = panel
	bottom_box.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var toggle := Button.new()
	toggle.text = "환경 설정  ▾"
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", 14)
	outer.add_child(toggle)
	toggle_button = toggle

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.visible = false
	outer.add_child(body)
	body_control = body
	toggle.pressed.connect(func() -> void:
		set_panel_open(not body.visible)
	)

	# Time row.
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 12)
	body.add_child(time_row)
	var time_label := Label.new()
	time_label.text = "시각"
	time_label.custom_minimum_size = Vector2(48, 0)
	time_row.add_child(time_label)
	time_slider = HSlider.new()
	time_slider.min_value = 0.0
	time_slider.max_value = 24.0
	time_slider.step = 1.0 / 60.0
	time_slider.value = 8.5
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(time_slider)
	time_value = Label.new()
	time_value.text = "08:30"
	time_value.custom_minimum_size = Vector2(48, 0)
	time_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_row.add_child(time_value)
	horizon_preview = MotionPreviewScript.new()
	horizon_preview.mode = 0
	horizon_preview.custom_minimum_size = Vector2(110, 58)
	horizon_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	time_row.add_child(horizon_preview)

	auto_check = CheckBox.new()
	auto_check.text = "시간 자동 진행 (120초 / 하루)"
	auto_check.button_pressed = false
	body.add_child(auto_check)

	# Wind row.
	var wind_row := HBoxContainer.new()
	wind_row.add_theme_constant_override("separation", 12)
	body.add_child(wind_row)
	var wind_label := Label.new()
	wind_label.text = "바람"
	wind_label.custom_minimum_size = Vector2(48, 0)
	wind_row.add_child(wind_label)
	wind_slider = HSlider.new()
	wind_slider.min_value = 0.0
	wind_slider.max_value = 16.0
	wind_slider.step = 0.5
	wind_slider.value = 3.0
	wind_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wind_row.add_child(wind_slider)
	wind_value = Label.new()
	wind_value.text = "3 m/s"
	wind_value.custom_minimum_size = Vector2(58, 0)
	wind_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wind_row.add_child(wind_value)
	wind_preview = MotionPreviewScript.new()
	wind_preview.mode = 1
	wind_preview.custom_minimum_size = Vector2(110, 58)
	wind_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wind_row.add_child(wind_preview)

	# Weather / season rows: side by side on desktop, stacked on phones.
	option_box = BoxContainer.new()
	option_box.vertical = false
	option_box.add_theme_constant_override("separation", 18)
	body.add_child(option_box)

	var weather_row := HBoxContainer.new()
	weather_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_row.add_theme_constant_override("separation", 12)
	option_box.add_child(weather_row)
	weather_label = Label.new()
	weather_label.text = "날씨"
	weather_label.custom_minimum_size = Vector2(48, 0)
	weather_row.add_child(weather_label)
	weather_option = OptionButton.new()
	for name in ["맑음", "흐림", "비", "안개", "눈", "눈보라"]:
		weather_option.add_item(name)
	weather_option.selected = 0
	weather_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_option.custom_minimum_size = Vector2(0, 34)
	weather_row.add_child(weather_option)
	weather_preview = MotionPreviewScript.new()
	weather_preview.mode = 2
	weather_preview.custom_minimum_size = Vector2(94, 54)
	weather_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weather_row.add_child(weather_preview)

	var season_row := HBoxContainer.new()
	season_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	season_row.add_theme_constant_override("separation", 12)
	option_box.add_child(season_row)
	season_label = Label.new()
	season_label.text = "계절"
	season_label.custom_minimum_size = Vector2(48, 0)
	season_row.add_child(season_label)
	season_option = OptionButton.new()
	for name in ["봄", "여름", "가을", "겨울"]:
		season_option.add_item(name)
	season_option.selected = 1
	season_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	season_option.custom_minimum_size = Vector2(0, 34)
	season_row.add_child(season_option)

	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 12)
	body.add_child(quality_row)
	var quality_label := Label.new()
	quality_label.text = "품질"
	quality_label.custom_minimum_size = Vector2(48, 0)
	quality_row.add_child(quality_label)
	quality_option = OptionButton.new()
	for name in ["높음", "보통", "낮음"]:
		quality_option.add_item(name)
	quality_option.selected = 0
	quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_option.custom_minimum_size = Vector2(0, 34)
	quality_row.add_child(quality_option)

	# Footer.
	var footer := HBoxContainer.new()
	body.add_child(footer)
	reset_spacer = Control.new()
	reset_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(reset_spacer)
	reset_button = Button.new()
	reset_button.text = "처음 시점"
	reset_button.custom_minimum_size = Vector2(0, 34)
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	footer.add_child(reset_button)

	time_slider.value_changed.connect(_on_time_changed)
	wind_slider.value_changed.connect(_on_wind_changed)
	auto_check.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	weather_option.item_selected.connect(func(index: int) -> void:
		weather_preview.set_weather(index)
		weather_changed.emit(index))
	season_option.item_selected.connect(func(index: int) -> void: season_changed.emit(index))
	quality_option.item_selected.connect(func(index: int) -> void: quality_changed.emit(index))

	time_slider.custom_minimum_size = Vector2(0, 28)
	wind_slider.custom_minimum_size = Vector2(0, 28)
	auto_check.custom_minimum_size = Vector2(0, 30)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	horizon_preview.set_time(time_slider.value)
	wind_preview.set_wind(wind_slider.value)
	weather_preview.set_weather(weather_option.selected)

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
	bottom_box.offset_top = -minf(640.0, maxf(viewport_size.y - 16.0, 160.0))
	bottom_box.offset_bottom = -16.0 - safe_bottom
	credit_label.offset_left = 12.0 + safe_left
	credit_label.offset_top = 8.0 + safe_top
	panel_control.custom_minimum_size = Vector2(minf(650.0, maxf(viewport_size.x - margin * 2.0, 220.0)), 0.0)
	panel_style.content_margin_left = 14.0 if compact else 20.0
	panel_style.content_margin_right = 14.0 if compact else 20.0
	panel_style.set_corner_radius_all(12 if compact else 16)
	ui_theme.default_font_size = 13 if compact else 14
	auto_check.text = auto_label_compact if compact else auto_label_full
	auto_check.tooltip_text = "120초에 하루가 지납니다"
	option_box.vertical = compact
	option_box.add_theme_constant_override("separation", 6 if compact else 18)
	reset_spacer.visible = not compact
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END
	var slider_height := 34.0 if compact else 28.0
	time_slider.custom_minimum_size.y = slider_height
	wind_slider.custom_minimum_size.y = slider_height
	auto_check.custom_minimum_size.y = 34.0 if compact else 30.0
	toggle_button.custom_minimum_size.y = 36.0 if compact else 30.0
	weather_label.custom_minimum_size.x = 40.0 if compact else 48.0
	season_label.custom_minimum_size.x = 40.0 if compact else 48.0
	var preview_width := 86.0 if compact else 110.0
	var preview_height := 50.0 if compact else 58.0
	if horizon_preview != null:
		horizon_preview.custom_minimum_size = Vector2(preview_width, preview_height)
	if wind_preview != null:
		wind_preview.custom_minimum_size = Vector2(preview_width, preview_height)
	if weather_preview != null:
		weather_preview.custom_minimum_size = Vector2(preview_width - 12.0, preview_height - 4.0)

func _on_time_changed(value: float) -> void:
	time_value.text = format_hour(value)
	if horizon_preview != null:
		horizon_preview.set_time(value)
	if not _syncing:
		time_changed.emit(value)

func _on_wind_changed(value: float) -> void:
	wind_value.text = str(round(value * 10.0) / 10.0) + " m/s"
	if wind_preview != null:
		wind_preview.set_wind(value)
	if not _syncing:
		wind_changed.emit(value)

func set_time_value(value: float) -> void:
	_syncing = true
	time_slider.value = value
	_syncing = false
	time_value.text = format_hour(value)
	if horizon_preview != null:
		horizon_preview.set_time(value)

func set_wind_value(value: float) -> void:
	_syncing = true
	wind_slider.value = value
	_syncing = false
	wind_value.text = str(round(value * 10.0) / 10.0) + " m/s"
	if wind_preview != null:
		wind_preview.set_wind(value)

func set_auto(enabled: bool) -> void:
	_syncing = true
	auto_check.button_pressed = enabled
	_syncing = false

func is_auto() -> bool:
	return auto_check.button_pressed

func is_panel_open() -> bool:
	return body_control != null and body_control.visible

func get_time() -> float:
	return time_slider.value

func get_wind() -> float:
	return wind_slider.value

func set_weather(index: int) -> void:
	weather_option.selected = index
	if weather_preview != null:
		weather_preview.set_weather(index)

func set_season(index: int) -> void:
	season_option.selected = index

func set_quality(index: int) -> void:
	quality_option.selected = index

func get_quality() -> int:
	return quality_option.selected

func set_panel_open(open: bool) -> void:
	if body_control == null:
		return
	body_control.visible = open
	toggle_button.text = "환경 설정  ▴" if open else "환경 설정  ▾"

func get_panel_rect() -> Rect2:
	if panel_control == null:
		return Rect2()
	return panel_control.get_global_rect()

static func format_hour(hour: float) -> String:
	var minutes := int(round(hour * 60.0))
	minutes = ((minutes % 1440) + 1440) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]
