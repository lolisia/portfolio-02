extends CanvasLayer
class_name PostProcess

## Screen-space glass lens around the UI panel, plus a restrained grade.
## Kept as a canvas pass so it works on Forward+ and Mobile without a
## RenderingDevice compositor.

var screen: ColorRect
var material: ShaderMaterial
var ui: GameUI
var _last_panel := Rect2()
var _last_size := Vector2.ZERO

func _ready() -> void:
	layer = 1
	screen = ColorRect.new()
	screen.name = "PostScreen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.color = Color.WHITE
	add_child(screen)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/post_process.gdshader")
	screen.material = material
	_update_panel(true)

func setup(game_ui: GameUI) -> void:
	ui = game_ui
	_update_panel(true)

func _process(_delta: float) -> void:
	_update_panel(false)

func _update_panel(force: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_rect := Rect2()
	if ui != null:
		panel_rect = ui.get_panel_rect()
	if not force and panel_rect == _last_panel and viewport_size == _last_size:
		return
	_last_panel = panel_rect
	_last_size = viewport_size
	material.set_shader_parameter("viewport_size", viewport_size)
	var center := panel_rect.position + panel_rect.size * 0.5
	var half := panel_rect.size * 0.5
	material.set_shader_parameter("panel_rect", Color(
		center.x / maxf(viewport_size.x, 1.0),
		center.y / maxf(viewport_size.y, 1.0),
		half.x / maxf(viewport_size.x, 1.0),
		half.y / maxf(viewport_size.y, 1.0)))

func set_grade(tint_value: Color, saturation_value: float, contrast_value: float, vignette_value: float) -> void:
	material.set_shader_parameter("tint", tint_value)
	material.set_shader_parameter("saturation", saturation_value)
	material.set_shader_parameter("contrast", contrast_value)
	material.set_shader_parameter("vignette", vignette_value)

func set_sun(uv: Vector2, strength: float, color: Color) -> void:
	material.set_shader_parameter("sun_uv", uv)
	material.set_shader_parameter("sun_strength", strength)
	material.set_shader_parameter("sun_color", Vector3(color.r, color.g, color.b))
