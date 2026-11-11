extends CanvasLayer
class_name GameUI

signal time_changed(value: float)
signal wind_changed(value: float)
signal weather_changed(index: int)
signal season_changed(index: int)
signal auto_toggled(enabled: bool)
signal reset_requested

var time_slider: HSlider
var wind_slider: HSlider
var time_value: Label
var wind_value: Label
var auto_check: CheckBox
var weather_option: OptionButton
var season_option: OptionButton
var _syncing := false

func _ready() -> void:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Apple SD Gothic Neo", "Segoe UI", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", Color(1, 1, 1, 0.94))
	theme.set_color("font_color", "Button", Color(1, 1, 1, 0.94))
	theme.set_color("font_color", "CheckBox", Color(1, 1, 1, 0.9))
	theme.set_color("font_color", "OptionButton", Color(1, 1, 1, 0.94))

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	var credit := LinkButton.new()
	credit.text = "SD Unity-chan © Unity Technologies Japan/UCL"
	credit.uri = "https://unity-chan.com/contents/license_en/"
	credit.add_theme_font_size_override("font_size", 10)
	credit.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	credit.offset_left = 12
	credit.offset_top = 8
	root.add_child(credit)

	var bottom_box := VBoxContainer.new()
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.095, 0.115, 0.52)
	style.border_color = Color(1, 1, 1, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
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

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.visible = false
	outer.add_child(body)
	toggle.pressed.connect(func() -> void:
		body.visible = not body.visible
		toggle.text = "환경 설정  ▴" if body.visible else "환경 설정  ▾"
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

	# Weather / season row.
	var option_row := HBoxContainer.new()
	option_row.add_theme_constant_override("separation", 18)
	body.add_child(option_row)
	var weather_label := Label.new()
	weather_label.text = "날씨"
	weather_label.custom_minimum_size = Vector2(48, 0)
	option_row.add_child(weather_label)
	weather_option = OptionButton.new()
	for name in ["맑음", "흐림", "비", "안개", "눈", "눈보라"]:
		weather_option.add_item(name)
	weather_option.selected = 0
	weather_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(weather_option)

	var season_label := Label.new()
	season_label.text = "계절"
	season_label.custom_minimum_size = Vector2(48, 0)
	option_row.add_child(season_label)
	season_option = OptionButton.new()
	for name in ["봄", "여름", "가을", "겨울"]:
		season_option.add_item(name)
	season_option.selected = 1
	season_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_row.add_child(season_option)

	# Footer.
	var footer := HBoxContainer.new()
	body.add_child(footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var reset_button := Button.new()
	reset_button.text = "처음 시점"
	reset_button.pressed.connect(func() -> void: reset_requested.emit())
	footer.add_child(reset_button)

	time_slider.value_changed.connect(_on_time_changed)
	wind_slider.value_changed.connect(_on_wind_changed)
	auto_check.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	weather_option.item_selected.connect(func(index: int) -> void: weather_changed.emit(index))
	season_option.item_selected.connect(func(index: int) -> void: season_changed.emit(index))

func _on_time_changed(value: float) -> void:
	time_value.text = format_hour(value)
	if not _syncing:
		time_changed.emit(value)

func _on_wind_changed(value: float) -> void:
	wind_value.text = str(round(value * 10.0) / 10.0) + " m/s"
	if not _syncing:
		wind_changed.emit(value)

func set_time_value(value: float) -> void:
	_syncing = true
	time_slider.value = value
	_syncing = false
	time_value.text = format_hour(value)

func set_wind_value(value: float) -> void:
	_syncing = true
	wind_slider.value = value
	_syncing = false
	wind_value.text = str(round(value * 10.0) / 10.0) + " m/s"

func set_auto(enabled: bool) -> void:
	_syncing = true
	auto_check.button_pressed = enabled
	_syncing = false

func is_auto() -> bool:
	return auto_check.button_pressed

func get_time() -> float:
	return time_slider.value

func get_wind() -> float:
	return wind_slider.value

func set_weather(index: int) -> void:
	weather_option.selected = index

func set_season(index: int) -> void:
	season_option.selected = index

static func format_hour(hour: float) -> String:
	var minutes := int(round(hour * 60.0))
	minutes = ((minutes % 1440) + 1440) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]
