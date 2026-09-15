class_name GuidedTutorialOverlay
extends CanvasLayer
## 新手强引导的演出层：整屏压暗的遮罩在目标处挖一个圆角洞（洞内可点、洞外全拦）、
## 一只从右下方指向目标的小手指（带「左键 / 右键」小牌）、一块带强调色文字的引导
## 文本卡，以及说明类步骤用的「知道了」按钮。
##
## 只管画面与输入拦截，不知道扫雷规则；每一步该圈哪里、说什么由 main.gd 喂进来。

signal next_pressed
signal blocked_click(position: Vector2)

const SPOTLIGHT_SHADER := preload("res://shaders/tutorial_spotlight.gdshader")
const POINTER_TEXTURE := preload("res://assets/ui/pointer_hand.svg")
const GUIDE_FONT := preload("res://assets/fonts/eva_ming_sc.otf")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

const LAYER_INDEX := 85
const PANEL_WIDTH := 720.0
const PANEL_GAP := 30.0
const SCREEN_MARGIN := 24.0
const POINTER_SIZE := Vector2(84, 100)
## 指尖在贴图里的相对位置（pointer_hand.svg 食指顶端）。
const POINTER_TIP := Vector2(0.44, 0.06)
## 指尖相对目标点的偏移：手从目标右下方伸过来，指尖压在目标中心偏右下一点。
const POINTER_TIP_OFFSET := Vector2(14.0, 20.0)
const POINTER_BOB := Vector2(-11.0, -13.0)
const HOLE_TWEEN_SECONDS := 0.34
const PANEL_TWEEN_SECONDS := 0.26

const COLOR_CARD := Color(0.976, 0.914, 0.741, 0.98)
const COLOR_CARD_BORDER := Color(0.875, 0.482, 0.243, 1.0)
const COLOR_INK := Color(0.278, 0.184, 0.102, 1.0)
const COLOR_CHIP := Color(0.875, 0.482, 0.243, 1.0)
const COLOR_CHIP_INK := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_BADGE := Color(0.075, 0.145, 0.098, 0.96)
const COLOR_BADGE_INK := Color(1.0, 0.9, 0.58, 1.0)


## 挖了洞的遮罩：洞内的点不算自己的（让给底下的格子），洞外全部吃掉并上报。
class SpotlightMask:
	extends ColorRect

	signal pressed_outside(position: Vector2)

	var hole := Rect2()
	var hole_interactive := true

	func _has_point(point: Vector2) -> bool:
		if hole_interactive and hole.size.x > 0.0 and hole.size.y > 0.0 and hole.has_point(point):
			return false
		return true

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			pressed_outside.emit((event as InputEventMouseButton).global_position)


var _mask: SpotlightMask
var _mask_material: ShaderMaterial
var _pointer: Control
var _pointer_hand: TextureRect
var _pointer_badge: PanelContainer
var _pointer_badge_label: Label
var _panel: PanelContainer
var _step_chip: Label
var _message: RichTextLabel
var _next_button: Button
var _hole_current := Rect2()
var _hole_tween: Tween
var _pointer_tween: Tween
var _panel_tween: Tween
var _nudge_tween: Tween
var _pointer_home := Vector2.ZERO
var _presenting := false
var _step_token := 0


func _ready() -> void:
	layer = LAYER_INDEX
	visible = false
	_build_mask()
	_build_pointer()
	_build_panel()


func _build_mask() -> void:
	_mask = SpotlightMask.new()
	_mask.name = "SpotlightMask"
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	_mask.color = Color.WHITE
	_mask_material = ShaderMaterial.new()
	_mask_material.shader = SPOTLIGHT_SHADER
	_mask.material = _mask_material
	_mask.pressed_outside.connect(_on_mask_pressed_outside)
	_mask.resized.connect(_sync_mask_size)
	add_child(_mask)
	_sync_mask_size()


func _build_pointer() -> void:
	_pointer = Control.new()
	_pointer.name = "Pointer"
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.size = POINTER_SIZE
	_pointer.pivot_offset = POINTER_SIZE * POINTER_TIP
	_pointer.visible = false
	add_child(_pointer)

	_pointer_hand = TextureRect.new()
	_pointer_hand.name = "Hand"
	_pointer_hand.texture = POINTER_TEXTURE
	_pointer_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pointer_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pointer_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_hand.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pointer_hand.size = POINTER_SIZE
	_pointer.add_child(_pointer_hand)

	_pointer_badge = PanelContainer.new()
	_pointer_badge.name = "Badge"
	_pointer_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_badge.add_theme_stylebox_override("panel", _rounded_style(COLOR_BADGE, COLOR_BADGE_INK, 2, 12, 12, 5))
	_pointer_badge.position = Vector2(POINTER_SIZE.x - 6.0, POINTER_SIZE.y * 0.46)
	_pointer.add_child(_pointer_badge)
	_pointer_badge_label = Label.new()
	_pointer_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_badge_label.add_theme_font_override("font", GUIDE_FONT)
	_pointer_badge_label.add_theme_font_size_override("font_size", 22)
	_pointer_badge_label.add_theme_color_override("font_color", COLOR_BADGE_INK)
	_pointer_badge.add_child(_pointer_badge_label)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GuidePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", _rounded_style(COLOR_CARD, COLOR_CARD_BORDER, 4, 18, 26, 18, true))
	_panel.visible = false
	add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _rounded_style(COLOR_CHIP, COLOR_CHIP, 0, 10, 12, 3))
	header.add_child(chip)
	_step_chip = Label.new()
	_step_chip.name = "StepChip"
	_step_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_chip.add_theme_font_override("font", GUIDE_FONT)
	_step_chip.add_theme_font_size_override("font_size", 20)
	_step_chip.add_theme_color_override("font_color", COLOR_CHIP_INK)
	chip.add_child(_step_chip)

	_message = RichTextLabel.new()
	_message.name = "Message"
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.bbcode_enabled = true
	_message.fit_content = true
	_message.scroll_active = false
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(PANEL_WIDTH - 52.0, 0)
	_message.add_theme_font_override("normal_font", GUIDE_FONT)
	_message.add_theme_font_size_override("normal_font_size", 30)
	_message.add_theme_color_override("default_color", COLOR_INK)
	_message.add_theme_constant_override("line_separation", 6)
	column.add_child(_message)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	_next_button = Button.new()
	_next_button.name = "NextButton"
	_next_button.text = "知道了  »"
	_next_button.custom_minimum_size = Vector2(190, 54)
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_next_button.add_theme_font_override("font", GUIDE_FONT)
	_next_button.add_theme_font_size_override("font_size", 24)
	_next_button.add_theme_color_override("font_color", COLOR_BADGE_INK)
	_next_button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.84))
	_next_button.add_theme_color_override("font_pressed_color", Color(0.9, 0.8, 0.55))
	_next_button.add_theme_stylebox_override("normal", _rounded_style(COLOR_BADGE, Color(0.86, 0.73, 0.38, 0.95), 2, 14, 18, 8))
	_next_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.12, 0.245, 0.145, 0.98), Color(1, 0.86, 0.48), 3, 14, 18, 8))
	_next_button.add_theme_stylebox_override("pressed", _rounded_style(Color(0.045, 0.095, 0.06, 1), Color(0.74, 0.62, 0.3), 2, 14, 18, 8))
	_next_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_next_button.pressed.connect(_on_next_pressed)
	footer.add_child(_next_button)
	# 悬停动效要拿场景树，得等按钮真的挂上去再绑。
	ButtonMotion.bind(_next_button, _next_button, 1.2)


## 展示一步。config：
##  hole: Rect2（视口坐标；空矩形 = 只压暗不挖洞）
##  interactive: bool（洞内能不能点到底下的东西）
##  pointer: Vector2（小手指尖要点的位置；Vector2.INF = 不显示）
##  pointer_side: "right"（缺省，手从右下方伸来）或 "left"（镜像，从左下方伸来，
##    免得手掌盖住目标右下方要给玩家看的格子）
##  hint: String（小手旁边的「左键 / 右键」小牌，空串不显示）
##  text: String（bbcode）
##  show_next: bool
##  next_text: String（下一步按钮文案，缺省「知道了  »」）
##  step_index / step_count: int（步骤角标）
func present_step(config: Dictionary) -> void:
	_step_token += 1
	var first_show := not _presenting
	_presenting = true
	visible = true
	_sync_mask_size()

	var hole: Rect2 = config.get("hole", Rect2())
	_mask.hole = hole
	_mask.hole_interactive = bool(config.get("interactive", true))
	if first_show:
		_apply_hole(hole)
		_mask.modulate.a = 0.0
		create_tween().tween_property(_mask, "modulate:a", 1.0, 0.28)
	else:
		_animate_hole(hole)

	var pointer_at: Vector2 = config.get("pointer", Vector2.INF)
	_show_pointer(pointer_at, String(config.get("hint", "")), String(config.get("pointer_side", "right")) == "left")

	_step_chip.text = "第 %d 步 / 共 %d 步" % [int(config.get("step_index", 0)) + 1, int(config.get("step_count", 1))]
	_message.text = String(config.get("text", ""))
	_next_button.text = String(config.get("next_text", "知道了  »"))
	_next_button.visible = bool(config.get("show_next", false))
	_next_button.disabled = not _next_button.visible
	_place_panel(hole, pointer_at)


func dismiss() -> void:
	if not _presenting:
		visible = false
		return
	_presenting = false
	_step_token += 1
	_kill_tweens()
	visible = false
	_panel.visible = false
	_pointer.visible = false
	_mask.hole = Rect2()
	_apply_hole(Rect2())


func is_presenting() -> bool:
	return _presenting


func current_hole() -> Rect2:
	return _mask.hole


func next_button() -> Button:
	return _next_button


func pointer() -> Control:
	return _pointer


func message_label() -> RichTextLabel:
	return _message


## 玩家点到了不该点的地方：小手和文本卡一起弹一下，把注意力拽回来。
func play_nudge() -> void:
	if not _presenting:
		return
	if _nudge_tween != null and _nudge_tween.is_valid():
		_nudge_tween.kill()
	_nudge_tween = create_tween().set_parallel(true)
	_nudge_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _pointer.visible:
		_pointer.scale = Vector2(1.32, 1.32)
		_nudge_tween.tween_property(_pointer, "scale", Vector2.ONE, 0.36)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(1.04, 1.04)
	_nudge_tween.tween_property(_panel, "scale", Vector2.ONE, 0.36)


func _on_next_pressed() -> void:
	if not _presenting or not _next_button.visible:
		return
	next_pressed.emit()


func _on_mask_pressed_outside(position: Vector2) -> void:
	if not _presenting:
		return
	play_nudge()
	blocked_click.emit(position)


func _sync_mask_size() -> void:
	if _mask_material != null and _mask != null:
		_mask_material.set_shader_parameter("rect_size", _mask.size)


func _apply_hole(hole: Rect2) -> void:
	_hole_current = hole
	if _mask_material != null:
		_mask_material.set_shader_parameter(
			"hole_rect", Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y)
		)


func _animate_hole(target: Rect2) -> void:
	if _hole_tween != null and _hole_tween.is_valid():
		_hole_tween.kill()
	var from := _hole_current
	if from.size.x <= 0.0 or from.size.y <= 0.0:
		# 从「没有洞」过渡到「有洞」：从目标中心张开，而不是从左上角飞过来。
		from = Rect2(target.get_center(), Vector2.ZERO)
	if target.size.x <= 0.0 or target.size.y <= 0.0:
		target = Rect2(from.get_center(), Vector2.ZERO)
	_hole_tween = create_tween()
	_hole_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hole_tween.tween_method(func(progress: float) -> void:
		_apply_hole(Rect2(
			from.position.lerp(target.position, progress),
			from.size.lerp(target.size, progress)
		))
	, 0.0, 1.0, HOLE_TWEEN_SECONDS)


func _show_pointer(target: Vector2, hint: String, from_left: bool = false) -> void:
	if _pointer_tween != null and _pointer_tween.is_valid():
		_pointer_tween.kill()
	if target == Vector2.INF or not target.is_finite():
		_pointer.visible = false
		return
	_pointer.visible = true
	_pointer.scale = Vector2.ONE
	var mirror := Vector2(-1.0 if from_left else 1.0, 1.0)
	var tip := Vector2(1.0 - POINTER_TIP.x if from_left else POINTER_TIP.x, POINTER_TIP.y)
	_pointer_hand.flip_h = from_left
	_pointer.pivot_offset = POINTER_SIZE * tip
	_pointer_home = target + POINTER_TIP_OFFSET * mirror - POINTER_SIZE * tip
	_pointer.position = _pointer_home
	_pointer_badge.visible = not hint.is_empty()
	_pointer_badge_label.text = hint
	_pointer_badge.reset_size()
	_pointer_badge.position = Vector2(
		-_pointer_badge.size.x + 6.0 if from_left else POINTER_SIZE.x - 6.0,
		POINTER_SIZE.y * 0.46
	)
	# 指尖朝目标一戳一戳地点，循环到这一步结束。
	_pointer_tween = create_tween().set_loops()
	_pointer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pointer_tween.tween_property(_pointer, "position", _pointer_home + POINTER_BOB * mirror, 0.42)
	_pointer_tween.tween_property(_pointer, "position", _pointer_home, 0.42)


## 文本卡贴着洞放：洞在上半屏就放洞下面（让开小手），否则放洞上面；水平跟洞居中，
## 再整体夹回屏幕里。没有洞时放屏幕中央偏下。
func _place_panel(hole: Rect2, pointer_at: Vector2) -> void:
	var viewport_size := _mask.size
	_panel.visible = true
	_panel.scale = Vector2.ONE
	_panel.reset_size()
	var panel_size := _panel.size
	var target := Vector2.ZERO
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		target = Vector2((viewport_size.x - panel_size.x) * 0.5, viewport_size.y * 0.62 - panel_size.y * 0.5)
	else:
		var occupied_bottom := hole.end.y
		if pointer_at != Vector2.INF and pointer_at.is_finite():
			occupied_bottom = maxf(occupied_bottom, pointer_at.y + POINTER_TIP_OFFSET.y + POINTER_SIZE.y * (1.0 - POINTER_TIP.y))
			# 说明步的小手不指点击位置，文本卡放洞下面时也别压着它。
		var below_y := occupied_bottom + PANEL_GAP
		var above_y := hole.position.y - PANEL_GAP - panel_size.y
		var prefer_below := hole.get_center().y < viewport_size.y * 0.5
		var fits_below := below_y + panel_size.y <= viewport_size.y - SCREEN_MARGIN
		var fits_above := above_y >= SCREEN_MARGIN
		var y := below_y
		if prefer_below and fits_below:
			y = below_y
		elif fits_above:
			y = above_y
		elif fits_below:
			y = below_y
		target = Vector2(hole.get_center().x - panel_size.x * 0.5, y)
	target.x = clampf(target.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - panel_size.x - SCREEN_MARGIN))
	target.y = clampf(target.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.y - panel_size.y - SCREEN_MARGIN))

	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel.position = target + Vector2(0, 18)
	_panel.modulate.a = 0.0
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_panel, "position", target, PANEL_TWEEN_SECONDS)
	_panel_tween.set_trans(Tween.TRANS_QUAD)
	_panel_tween.tween_property(_panel, "modulate:a", 1.0, PANEL_TWEEN_SECONDS * 0.7)


func _kill_tweens() -> void:
	for tween in [_hole_tween, _pointer_tween, _panel_tween, _nudge_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


func _rounded_style(
	background: Color,
	border: Color,
	border_width: int,
	radius: int,
	margin_horizontal: int,
	margin_vertical: int,
	shadow: bool = false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_horizontal
	style.content_margin_right = margin_horizontal
	style.content_margin_top = margin_vertical
	style.content_margin_bottom = margin_vertical
	if shadow:
		style.shadow_color = Color(0.078, 0.047, 0.024, 0.55)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 7)
	return style
