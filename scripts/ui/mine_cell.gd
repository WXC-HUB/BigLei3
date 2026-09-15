class_name MineCell
extends TextureButton

signal primary_pressed(cell_index: int)
signal secondary_pressed(cell_index: int)
signal mouse_button_changed(cell_index: int, button_index: int, pressed: bool)
signal hover_started(cell_index: int)
signal hover_ended(cell_index: int)

enum ContentKind { EMPTY, NUMBER, ITEM, MONSTER, CORPSE, TRIGGERED, DESTROYED }

const ITEM_CONTENT_Z := 7
const NUMBER_CONTENT_Z := 6
const DEFAULT_CONTENT_Z := 20
const CORPSE_CONTENT_Z := 8
const USED_ITEM_SHADER := preload("res://shaders/used_item_grayscale.gdshader")
## Size the flag settles at once its card has been blown away.
const SEALED_MARKER_SCALE := 0.66
## 误标 / 已触发雷的底板红叉：放大一点、半透，才不压过雷图和数字。
const FAULT_PLATE_SCALE := 1.42
const FAULT_PLATE_ALPHA := 0.48
const CORRECT_MARK_PLATE := preload("res://my_asset/effects/marked_mine_green_check.png")
## 正确标记的绿勾比红叉小一圈、更实一点，避免盖住雷图。
const CORRECT_MARK_PLATE_SCALE := 1.08
const CORRECT_MARK_PLATE_ALPHA := 0.72
## 开局发牌：一张牌从牌堆飞到自己格子上要多久。
const DEAL_FLIGHT_TIME := 0.34


class MarchingDashedBorder extends Control:
	var border_color := Color("ffd36f")
	var phase := 0.0
	var speed := 18.0
	var dash_length := 12.0
	var gap_length := 8.0


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)


	func set_active(value: bool) -> void:
		visible = value
		set_process(value)
		if value:
			queue_redraw()


	func _process(delta: float) -> void:
		phase = fmod(phase + speed * delta, dash_length + gap_length)
		queue_redraw()


	func _draw() -> void:
		var bounds := Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0))
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			return
		var perimeter := (bounds.size.x + bounds.size.y) * 2.0
		var cursor := -phase
		while cursor < perimeter:
			var segment_start := maxf(cursor, 0.0)
			var segment_end := minf(cursor + dash_length, perimeter)
			if segment_end > segment_start:
				_draw_perimeter_range(bounds, segment_start, segment_end)
			cursor += dash_length + gap_length


	func _draw_perimeter_range(bounds: Rect2, start: float, finish: float) -> void:
		var width := bounds.size.x
		var height := bounds.size.y
		var corners := [width, width + height, width * 2.0 + height, width * 2.0 + height * 2.0]
		var cursor := start
		while cursor < finish - 0.001:
			var next_corner := finish
			for corner in corners:
				if corner > cursor + 0.001:
					next_corner = minf(next_corner, corner)
					break
			draw_line(
				_point_on_perimeter(bounds, cursor),
				_point_on_perimeter(bounds, next_corner),
				border_color,
				3.0,
				true
			)
			cursor = next_corner


	func _point_on_perimeter(bounds: Rect2, distance: float) -> Vector2:
		var width := bounds.size.x
		var height := bounds.size.y
		if distance <= width:
			return bounds.position + Vector2(distance, 0.0)
		distance -= width
		if distance <= height:
			return bounds.position + Vector2(width, distance)
		distance -= height
		if distance <= width:
			return bounds.position + Vector2(width - distance, height)
		distance -= width
		return bounds.position + Vector2(0.0, height - distance)


var cell_index := -1
var _cell_size := 86.0
var _visual_root: Control
var _base: TextureRect
var _surface: Panel
var _preview_overlay: Panel
var _inference_border: MarchingDashedBorder
var _super_luck_border: MarchingDashedBorder
var _shadow: Panel
var _fault_plate: TextureRect
var _content: TextureRect
var _number_label: Label
var _mud_front: Control
var _cover: TextureRect
var _marker: TextureRect
var _combat_label: Label
var _monster_health_back: Panel
var _monster_health_fill: ColorRect
var _monster_health_value: Label
var _interactive := true
var _targeting_selected := false
var _effect_preview := false
var _preview_color := Color.WHITE
var _hovered := false
var _ground_texture: Texture2D
var _showing_corpse := false
var _border_flash_generation := 0
var _hover_tween: Tween
var _flip_tween: Tween
var _deal_tween: Tween
var _pending_ground_texture: Texture2D
var _flipping := false
var _revealed := false
var _destroyed := false
var _flag_sealed := false
var _last_reveal_delay := 0.0
var _xray_hint: TextureRect
var _xray_number: Label
var _xray_generation := 0
## 透视闪烁时草皮最淡能淡到原来的几成——越低越像看穿，太低又会让格子看着像被挖空。
const XRAY_COVER_FADE := 0.22


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_normal = null
	_visual_root = Control.new()
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual_root.pivot_offset = size * 0.5
	add_child(_visual_root)

	_base = _texture_layer()
	_visual_root.add_child(_base)

	# The cell is a translucent ground treatment, not a raised tile.
	_surface = Panel.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_theme_stylebox_override("panel", _covered_surface_style())
	_visual_root.add_child(_surface)

	# This overlay provides visible inference/effect feedback above the card face.
	_preview_overlay = Panel.new()
	_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_overlay.z_index = 12
	_preview_overlay.visible = false
	_visual_root.add_child(_preview_overlay)

	_inference_border = MarchingDashedBorder.new()
	_inference_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inference_border.z_index = 13
	_inference_border.visible = false
	_visual_root.add_child(_inference_border)

	_super_luck_border = MarchingDashedBorder.new()
	_super_luck_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_super_luck_border.z_index = 14
	_super_luck_border.border_color = Color("65ef78")
	_super_luck_border.speed = 30.0
	_super_luck_border.dash_length = 10.0
	_super_luck_border.gap_length = 7.0
	_super_luck_border.visible = false
	_visual_root.add_child(_super_luck_border)

	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.add_theme_stylebox_override("panel", _shadow_style())
	_visual_root.add_child(_shadow)

	# 误标红叉 / 已触发雷红叉 / 正确标记绿勾，压在地面上、内容（雷图或数字）之下。
	_fault_plate = _texture_layer()
	_fault_plate.z_index = 5
	_fault_plate.visible = false
	_visual_root.add_child(_fault_plate)

	_content = _texture_layer()
	_content.z_index = DEFAULT_CONTENT_Z
	_visual_root.add_child(_content)

	_number_label = Label.new()
	_number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.add_theme_color_override("font_outline_color", Color("f5e8bd"))
	_number_label.add_theme_constant_override("outline_size", 6)
	_number_label.add_theme_font_size_override("font_size", 38)
	_number_label.z_index = NUMBER_CONTENT_Z
	_number_label.visible = false
	_visual_root.add_child(_number_label)

	_mud_front = Control.new()
	_mud_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mud_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual_root.add_child(_mud_front)
	_build_mud_blobs()

	_cover = _texture_layer()
	_visual_root.add_child(_cover)

	_marker = _texture_layer()
	_marker.z_index = 26
	_visual_root.add_child(_marker)

	_combat_label = Label.new()
	_combat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_label.position = Vector2(6, 5)
	_combat_label.size = Vector2(_cell_size - 12, 28)
	_combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_label.add_theme_color_override("font_color", Color("fff0b0"))
	_combat_label.add_theme_color_override("font_outline_color", Color("3a1e12"))
	_combat_label.add_theme_constant_override("outline_size", 5)
	_combat_label.add_theme_font_size_override("font_size", 15)
	_combat_label.z_index = 30
	_combat_label.visible = false
	_targeting_selected = false
	_effect_preview = false
	_visual_root.add_child(_combat_label)

	_monster_health_back = Panel.new()
	_monster_health_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monster_health_back.position = Vector2(-42, -20)
	_monster_health_back.size = Vector2(_cell_size + 84, 20)
	_monster_health_back.z_index = 31
	_monster_health_back.add_theme_stylebox_override("panel", _monster_health_back_style())
	_monster_health_back.visible = false
	_visual_root.add_child(_monster_health_back)

	_monster_health_fill = ColorRect.new()
	_monster_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monster_health_fill.position = Vector2(4, 4)
	_monster_health_fill.size = Vector2(_monster_health_back.size.x - 8, 12)
	_monster_health_fill.color = Color("76c94f")
	_monster_health_back.add_child(_monster_health_fill)

	_monster_health_value = Label.new()
	_monster_health_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monster_health_value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monster_health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monster_health_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_monster_health_value.add_theme_color_override("font_color", Color.WHITE)
	_monster_health_value.add_theme_color_override("font_outline_color", Color("27150f"))
	_monster_health_value.add_theme_constant_override("outline_size", 3)
	_monster_health_value.add_theme_font_size_override("font_size", 12)
	_monster_health_value.z_index = 1
	_monster_health_back.add_child(_monster_health_value)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(index: int, cell_size: float) -> void:
	cell_index = index
	_cell_size = cell_size
	custom_minimum_size = Vector2(cell_size, cell_size)
	size = Vector2(cell_size, cell_size)
	if _visual_root != null:
		_visual_root.pivot_offset = size * 0.5


func set_ground_texture(texture: Texture2D) -> void:
	_ground_texture = texture
	if _base != null:
		_base.texture = texture
		_base.visible = texture != null and not _destroyed


func prepare_reveal_face(texture: Texture2D) -> void:
	_pending_ground_texture = texture


func display_covered(marker: Texture2D = null) -> void:
	_revealed = false
	_destroyed = false
	# Keep the scenery visible through the board.  The old grass-card textures made
	# every cell read as a solid object floating above the clearing.
	_reset_card_layers()
	_base.texture = _ground_texture
	_base.visible = _ground_texture != null
	_cover.texture = null
	_cover.visible = false
	_surface.add_theme_stylebox_override("panel", _covered_surface_style())
	_cover.position = Vector2.ZERO
	_cover.rotation = 0.0
	_cover.scale = Vector2.ONE
	_cover.modulate = Color.WHITE
	_marker.texture = marker
	_marker.visible = marker != null
	_marker.modulate = Color.WHITE
	_marker.scale = Vector2.ONE
	_marker.position = Vector2.ZERO
	_marker.rotation = 0.0
	_number_label.visible = false
	_combat_label.visible = false
	_monster_health_back.visible = false
	_showing_corpse = false
	_targeting_selected = false
	_effect_preview = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	self_modulate = Color.WHITE
	_targeting_selected = false
	_set_fault_plate(null)
	_set_content(null, ContentKind.EMPTY)
	modulate = Color.WHITE
	# Unmarking puts the card back; any other refresh has to keep the crater the
	# confirmed-mine burst left behind.
	if marker == null:
		_flag_sealed = false
	elif _flag_sealed:
		_apply_sealed_look()


func display_revealed(
	content: Texture2D = null,
	kind: ContentKind = ContentKind.EMPTY,
	preserve_cover_for_animation: bool = false,
	content_span: int = 1,
	number_value: int = 0,
	fault_plate: Texture2D = null
) -> void:
	_revealed = true
	_destroyed = false
	_flag_sealed = false
	_animate_card_hover(false)
	_reset_card_layers()
	_base.texture = _ground_texture
	_base.visible = _ground_texture != null
	_surface.add_theme_stylebox_override("panel", _revealed_surface_style())
	_marker.visible = false
	_combat_label.visible = false
	_monster_health_back.visible = false
	_showing_corpse = kind == ContentKind.CORPSE
	_set_fault_plate(fault_plate)
	_set_content(content, kind, content_span)
	if kind == ContentKind.NUMBER and number_value > 0:
		_set_number(number_value)
	if not preserve_cover_for_animation:
		_cover.visible = false
	modulate = Color.WHITE


func display_destroyed(skull: Texture2D, preserve_cover_for_animation: bool = false) -> void:
	display_revealed(skull, ContentKind.DESTROYED, preserve_cover_for_animation)
	_destroyed = true
	_base.visible = false
	_surface.add_theme_stylebox_override("panel", _destroyed_surface_style())


func set_item_used_visual(used: bool) -> void:
	if not used:
		_content.material = null
		return
	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = USED_ITEM_SHADER
	_content.material = grayscale_material


func _set_fault_plate(texture: Texture2D) -> void:
	_fault_plate.texture = texture
	_fault_plate.visible = texture != null
	if texture == null:
		_fault_plate.scale = Vector2.ONE
		_fault_plate.modulate = Color.WHITE
		return
	# 用格子边长做轴心，避免刚显示时 size 还是 0 导致放大偏到一角。
	_fault_plate.pivot_offset = Vector2(_cell_size, _cell_size) * 0.5
	var plate_scale := _fault_plate_target_scale()
	_fault_plate.scale = plate_scale
	_fault_plate.modulate = Color(1.0, 1.0, 1.0, _fault_plate_target_alpha())
	_fault_plate.rotation = 0.0
	_fault_plate.material = null


func _fault_plate_target_scale() -> Vector2:
	var amount := (
		CORRECT_MARK_PLATE_SCALE
		if _fault_plate.texture == CORRECT_MARK_PLATE
		else FAULT_PLATE_SCALE
	)
	return Vector2(amount, amount)


func _fault_plate_target_alpha() -> float:
	return (
		CORRECT_MARK_PLATE_ALPHA
		if _fault_plate.texture == CORRECT_MARK_PLATE
		else FAULT_PLATE_ALPHA
	)


func set_interactable(value: bool) -> void:
	_interactive = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	if not value:
		_animate_card_hover(false)


func set_flag_marker(marker: Texture2D) -> void:
	_marker.texture = marker
	_marker.visible = marker != null
	if _flag_sealed:
		_apply_sealed_look()


## 「连携」的标记点 A 落在已经翻开的道具牌上，所以标记画成右上角的一枚小角标，
## 不去盖住道具本身的图。display_revealed() 每次都会藏起 _marker，因此每次刷新
## 这张牌之后都要重新调一次。
func show_xray_hint(texture: Texture2D, number_value: int, duration: float = 3.0) -> void:
	_ensure_xray_nodes()
	_xray_generation += 1
	var generation := _xray_generation
	_xray_hint.texture = texture
	_xray_hint.visible = texture != null
	_xray_number.text = str(number_value)
	_xray_number.visible = texture == null
	play_border_flash(Color("c58cff"), maxi(1, ceili(duration / 0.2)), 0.1)
	# 透视得看着像「把这张牌看穿」：草皮自己淡下去、底下的内容同时亮起来，两边反相地
	# 一呼一吸。光在完好的牌面上飘一个小数字是看不出来的——牌面不动，就不像透视。
	var cover_alpha := _base.modulate.a
	var pulse := create_tween().set_loops(maxi(1, ceili(duration / 0.4)))
	pulse.tween_property(_xray_hint, "modulate:a", 0.5, 0.2)
	pulse.parallel().tween_property(_xray_number, "modulate:a", 0.5, 0.2)
	pulse.parallel().tween_property(_base, "modulate:a", cover_alpha, 0.2)
	pulse.tween_property(_xray_hint, "modulate:a", 1.0, 0.2)
	pulse.parallel().tween_property(_xray_number, "modulate:a", 1.0, 0.2)
	pulse.parallel().tween_property(_base, "modulate:a", cover_alpha * XRAY_COVER_FADE, 0.2)
	await get_tree().create_timer(duration).timeout
	if generation != _xray_generation:
		return
	pulse.kill()
	_xray_hint.visible = false
	_xray_number.visible = false
	_base.modulate.a = cover_alpha


func _ensure_xray_nodes() -> void:
	if _xray_hint != null:
		return
	_xray_hint = TextureRect.new()
	_xray_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xray_hint.position = Vector2(_cell_size * 0.08, _cell_size * 0.08)
	_xray_hint.size = Vector2.ONE * _cell_size * 0.84
	_xray_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_xray_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_xray_hint.z_index = 34
	_xray_hint.visible = false
	_visual_root.add_child(_xray_hint)
	_xray_number = Label.new()
	_xray_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xray_number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xray_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xray_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xray_number.add_theme_color_override("font_color", Color("f1d9ff"))
	_xray_number.add_theme_color_override("font_outline_color", Color("3a1748"))
	_xray_number.add_theme_constant_override("outline_size", 7)
	_xray_number.add_theme_font_size_override("font_size", 46)
	_xray_number.z_index = 35
	_xray_number.visible = false
	_visual_root.add_child(_xray_number)


## 开局洗牌：先把这张牌藏起来并叠到牌堆上，等 `play_deal_in()` 把它发出去。
## `offset` 是牌堆相对自己最终位置的偏移，由调用方按棋盘中心算好。
func prepare_deal(offset: Vector2, spin: float) -> void:
	if _deal_tween != null and _deal_tween.is_valid():
		_deal_tween.kill()
	_visual_root.pivot_offset = size * 0.5
	_visual_root.position = offset
	_visual_root.rotation = spin
	_visual_root.scale = Vector2(0.78, 0.78)
	_visual_root.modulate.a = 0.0


## 把这张牌从牌堆甩到自己的格子上。`delay` 让整盘牌一张张落下而不是一起砸下来。
func play_deal_in(delay: float = 0.0) -> void:
	if _deal_tween != null and _deal_tween.is_valid():
		_deal_tween.kill()
	_deal_tween = create_tween().set_parallel(true)
	if delay > 0.0:
		_deal_tween.tween_interval(delay)
		_deal_tween.chain().set_parallel(true)
	_deal_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_deal_tween.tween_property(_visual_root, "position", Vector2.ZERO, DEAL_FLIGHT_TIME)
	_deal_tween.tween_property(_visual_root, "rotation", 0.0, DEAL_FLIGHT_TIME)
	_deal_tween.tween_property(_visual_root, "modulate:a", 1.0, DEAL_FLIGHT_TIME * 0.55)
	_deal_tween.tween_property(_visual_root, "scale", Vector2.ONE, DEAL_FLIGHT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deal_tween.chain().tween_callback(_finish_deal)


## 发牌结束后把动画层彻底归位，免得残留的偏移/透明度影响后面的翻牌与悬停。
func _finish_deal() -> void:
	_visual_root.position = Vector2.ZERO
	_visual_root.rotation = 0.0
	_visual_root.scale = Vector2.ONE
	_visual_root.modulate.a = 1.0


func play_reveal(delay: float = 0.0) -> void:
	_last_reveal_delay = maxf(delay, 0.0)
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_flipping = true
	z_index = 1
	_visual_root.pivot_offset = size * 0.5
	_visual_root.scale = Vector2.ONE
	_visual_root.rotation = 0.0
	_content.pivot_offset = _content.size * 0.5
	_number_label.pivot_offset = _number_label.size * 0.5
	var content_final_scale := _content.scale
	var number_final_scale := _number_label.scale
	var shadow_final_alpha := _shadow.modulate.a
	_content.scale = content_final_scale * 0.28
	_number_label.scale = number_final_scale * 0.28
	_content.modulate.a = 0.0
	_number_label.modulate.a = 0.0
	_shadow.modulate.a = 0.0
	_flip_tween = create_tween()
	if _last_reveal_delay > 0.0:
		_flip_tween.tween_interval(_last_reveal_delay)
	_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(_visual_root, "scale", Vector2(0.07, 0.68), 0.13)
	_flip_tween.parallel().tween_property(_visual_root, "rotation", deg_to_rad(-12.0), 0.13)
	_flip_tween.tween_callback(_swap_reveal_face)
	_flip_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(_visual_root, "scale", Vector2(1.045, 0.985), 0.18)
	_flip_tween.parallel().tween_property(_visual_root, "rotation", deg_to_rad(2.5), 0.18)
	_flip_tween.set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_property(_visual_root, "scale", Vector2.ONE, 0.07)
	_flip_tween.parallel().tween_property(_visual_root, "rotation", 0.0, 0.07)
	# The face settles first; only then do numbers and icons punch through it.
	_flip_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(_content, "scale", content_final_scale * 1.2, 0.12)
	_flip_tween.parallel().tween_property(_content, "modulate:a", 1.0, 0.08)
	_flip_tween.parallel().tween_property(_number_label, "scale", number_final_scale * 1.2, 0.12)
	_flip_tween.parallel().tween_property(_number_label, "modulate:a", 1.0, 0.08)
	_flip_tween.parallel().tween_property(_shadow, "modulate:a", shadow_final_alpha, 0.1)
	_flip_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_property(_content, "scale", content_final_scale * 0.94, 0.065)
	_flip_tween.parallel().tween_property(_number_label, "scale", number_final_scale * 0.94, 0.065)
	_flip_tween.tween_property(_content, "scale", content_final_scale, 0.075)
	_flip_tween.parallel().tween_property(_number_label, "scale", number_final_scale, 0.075)
	_flip_tween.finished.connect(_finish_flip_animation)


func play_flag() -> void:
	var target := _content if _content.visible else _marker
	if not target.visible:
		return
	target.pivot_offset = target.size * 0.5
	target.rotation = deg_to_rad(-5.0)
	target.scale = Vector2(0.72, 0.72)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "rotation", 0.0, 0.16)
	tween.tween_property(target, "scale", Vector2.ONE, 0.16)
	if _fault_plate.visible and target == _content:
		_fault_plate.pivot_offset = Vector2(_cell_size, _cell_size) * 0.5
		var plate_scale := _fault_plate_target_scale()
		_fault_plate.scale = plate_scale * 0.72
		tween.tween_property(_fault_plate, "scale", plate_scale, 0.16)


## Blows the confirmed mine's card apart once the flag pose has landed. The tile
## art is gone for good; only the marker survives, so the board still shows
## where the mine is without leaving a card the player could try to flip.
func play_flag_shatter() -> void:
	if _flag_sealed or _destroyed or _revealed:
		return
	_flag_sealed = true
	_base.pivot_offset = _base.size * 0.5
	_mud_front.pivot_offset = _mud_front.size * 0.5
	var card := create_tween().set_parallel(true)
	card.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for layer in [_base, _mud_front]:
		card.tween_property(layer, "scale", Vector2(1.34, 1.34), 0.16)
		card.tween_property(layer, "modulate:a", 0.0, 0.13)

	# A short recoil on the whole cell sells the tile popping out of the board.
	_visual_root.pivot_offset = size * 0.5
	var recoil := create_tween()
	recoil.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil.tween_property(_visual_root, "scale", Vector2(1.16, 0.88), 0.07)
	recoil.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.tween_property(_visual_root, "scale", Vector2.ONE, 0.16)

	_marker.pivot_offset = _marker.size * 0.5
	var mark := create_tween()
	mark.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mark.tween_property(_marker, "scale", Vector2(1.34, 1.34), 0.08)
	mark.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mark.tween_property(_marker, "scale", Vector2.ONE * SEALED_MARKER_SCALE, 0.18)
	mark.parallel().tween_property(_marker, "position:y", _cell_size * 0.05, 0.18)
	mark.finished.connect(func() -> void:
		if _flag_sealed:
			_apply_sealed_look()
	)


## Persistent look of a sealed cell. Any later refresh routes back through here
## so the crater survives flag/chain marker updates.
func _apply_sealed_look() -> void:
	_apply_sealed_surface()
	if _marker.texture == null:
		return
	_marker.visible = true
	_marker.pivot_offset = _marker.size * 0.5
	_marker.scale = Vector2(SEALED_MARKER_SCALE, SEALED_MARKER_SCALE)
	_marker.position = Vector2(0.0, _cell_size * 0.05)
	_marker.rotation = 0.0


## Undo whatever the shatter animation left on the card layers.
func _reset_card_layers() -> void:
	_base.scale = Vector2.ONE
	_base.modulate = Color.WHITE
	_mud_front.scale = Vector2.ONE
	_mud_front.modulate = Color.WHITE
	_shadow.modulate.a = 1.0
	if _visual_root != null:
		_visual_root.scale = Vector2.ONE


func _apply_sealed_surface() -> void:
	_base.visible = false
	_base.modulate.a = 0.0
	_mud_front.visible = false
	_shadow.visible = false
	_surface.add_theme_stylebox_override("panel", _sealed_surface_style())


func play_light(color: Color) -> void:
	var original := self_modulate
	var glow := color
	glow.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "self_modulate", glow, 0.12)
	tween.tween_property(self, "self_modulate", original, 0.3)


func play_border_flash(color: Color, flashes: int = 4, interval: float = 0.1) -> void:
	_border_flash_generation += 1
	var generation := _border_flash_generation
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.06)
	style.border_color = Color(color.r, color.g, color.b, 1.0)
	style.set_border_width_all(5)
	style.set_corner_radius_all(10)
	_preview_overlay.add_theme_stylebox_override("panel", style)
	_preview_overlay.visible = true
	_preview_overlay.modulate.a = 0.0
	var flash := create_tween()
	flash.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _step in range(flashes):
		flash.tween_property(_preview_overlay, "modulate:a", 1.0, interval)
		flash.tween_property(_preview_overlay, "modulate:a", 0.12, interval)
	flash.finished.connect(func() -> void:
		if generation != _border_flash_generation:
			return
		_preview_overlay.modulate.a = 1.0
		_update_preview_overlay()
	)


func prepare_monster_emerge() -> void:
	_content.modulate.a = 0.0
	_shadow.modulate.a = 0.0
	_combat_label.visible = false
	_monster_health_back.visible = false


func play_monster_emerge() -> void:
	var destination := _content.position
	_content.position = destination + Vector2(0, _cell_size * 0.28)
	_content.scale = Vector2(0.38, 0.38)
	_content.modulate = Color(1.12, 1.06, 0.88, 0.0)
	_shadow.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "position", destination, 0.42)
	tween.tween_property(_content, "scale", Vector2.ONE, 0.42)
	tween.tween_property(_content, "modulate", Color.WHITE, 0.24)
	tween.tween_property(_shadow, "modulate:a", 1.0, 0.32).set_delay(0.1)


func play_item_focus(color: Color) -> void:
	var original_position := _content.position
	var original_modulate := _content.modulate
	_content.pivot_offset = _content.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "position:y", original_position.y - _cell_size * 0.14, 0.14)
	tween.parallel().tween_property(_content, "scale", Vector2(1.2, 1.2), 0.14)
	tween.parallel().tween_property(_content, "modulate", color, 0.14)
	tween.tween_property(_content, "scale", Vector2(1.06, 1.06), 0.12)
	tween.parallel().tween_property(_content, "modulate", original_modulate, 0.12)
	tween.finished.connect(func() -> void: _content.position = original_position)


func play_rumble(delay: float = 0.0) -> void:
	var origin := position
	var tween := create_tween()
	tween.tween_interval(delay)
	for offset in [Vector2(-3, 1), Vector2(4, -2), Vector2(-2, -1), Vector2(2, 1)]:
		tween.tween_property(self, "position", origin + offset, 0.035)
	tween.tween_property(self, "position", origin, 0.05)


func play_hit() -> void:
	var origin := _content.position
	_content.pivot_offset = _content.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "position:x", origin.x + 10.0, 0.045)
	tween.parallel().tween_property(_content, "scale", Vector2(0.88, 1.08), 0.045)
	tween.parallel().tween_property(_content, "modulate", Color("ff8068"), 0.045)
	tween.tween_property(_content, "position:x", origin.x - 7.0, 0.055)
	tween.tween_property(_content, "position", origin, 0.09)
	tween.parallel().tween_property(_content, "scale", Vector2.ONE, 0.09)
	tween.parallel().tween_property(_content, "modulate", Color.WHITE, 0.09)


func set_combat_mine_status(hp: int, max_hp: int, turns_until_attack: int) -> void:
	_combat_label.text = "攻击倒计时 %d" % turns_until_attack
	_combat_label.visible = true
	var safe_max_hp := maxi(max_hp, 1)
	var ratio := clampf(float(hp) / float(safe_max_hp), 0.0, 1.0)
	_monster_health_fill.size.x = (_monster_health_back.size.x - 8.0) * ratio
	_monster_health_fill.color = Color("76c94f") if ratio > 0.5 else (Color("e2b94c") if ratio > 0.25 else Color("e65a45"))
	_monster_health_value.text = "%d / %d" % [maxi(hp, 0), safe_max_hp]
	_monster_health_back.visible = true


func is_flag_sealed() -> bool:
	return _flag_sealed


## Settlement reveal for a cell whose card was already blown apart by a
## confirmed mark: the content shows up sitting in the crater, and the tile art
## the burst destroyed stays destroyed.
func display_revealed_in_crater(
	content: Texture2D,
	kind: ContentKind,
	content_span: int = 1,
	number_value: int = 0,
	fault_plate: Texture2D = null
) -> void:
	display_revealed(content, kind, false, content_span, number_value, fault_plate)
	_flag_sealed = true
	_apply_sealed_surface()


func is_showing_corpse() -> bool:
	return _showing_corpse


func set_targeting_selected(value: bool) -> void:
	_targeting_selected = value
	_update_interaction_tint()


func set_effect_preview(value: bool, color: Color = Color.WHITE) -> void:
	_effect_preview = value
	_preview_color = color
	_update_interaction_tint()


func set_inference_area_preview(value: bool) -> void:
	if _inference_border != null:
		_inference_border.set_active(value)


func set_super_luck_pending(value: bool) -> void:
	if _super_luck_border != null:
		_super_luck_border.set_active(value)


func _update_interaction_tint() -> void:
	_update_preview_overlay()
	if _targeting_selected:
		self_modulate = Color(1.25, 1.12, 0.72, 1.0)
	elif _effect_preview:
		self_modulate = _preview_color
	elif _hovered and _interactive and not _revealed:
		self_modulate = Color(1.1, 1.1, 1.04, 1.0)
	else:
		self_modulate = Color.WHITE


func _update_preview_overlay() -> void:
	if _preview_overlay == null:
		return
	if not _targeting_selected and not _effect_preview:
		_preview_overlay.visible = false
		return
	var color := Color(1.0, 0.72, 0.22, 1.0) if _targeting_selected else _preview_color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.42)
	style.border_color = Color(color.r, color.g, color.b, 0.95)
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0.0)
	_preview_overlay.add_theme_stylebox_override("panel", style)
	_preview_overlay.visible = true


func _set_content(texture: Texture2D, kind: ContentKind, content_span: int = 1) -> void:
	_number_label.visible = false
	_number_label.modulate = Color.WHITE
	_number_label.scale = Vector2.ONE
	_content.texture = texture
	_content.visible = texture != null
	_content.modulate = Color.WHITE
	_content.scale = Vector2.ONE
	_content.rotation = 0.0
	_content.material = null
	match kind:
		ContentKind.ITEM:
			_content.z_index = ITEM_CONTENT_Z
		ContentKind.CORPSE, ContentKind.TRIGGERED:
			_content.z_index = CORPSE_CONTENT_Z
		ContentKind.NUMBER:
			_content.z_index = NUMBER_CONTENT_Z
		_:
			_content.z_index = DEFAULT_CONTENT_Z
	_shadow.visible = (
		kind == ContentKind.ITEM
		or kind == ContentKind.MONSTER
		or kind == ContentKind.CORPSE
		or kind == ContentKind.TRIGGERED
	)
	_mud_front.visible = (
		kind == ContentKind.ITEM
		or (kind == ContentKind.MONSTER and content_span == 1)
		or (kind == ContentKind.TRIGGERED and content_span == 1)
	)
	var scale_ratio := 0.0
	var vertical_offset := 0.0
	match kind:
		ContentKind.NUMBER:
			scale_ratio = 0.54
			vertical_offset = -2.0
		ContentKind.ITEM:
			scale_ratio = 0.82
			vertical_offset = -4.0
		ContentKind.TRIGGERED:
			# 已触发雷 / 正确标记：内容是雷图，底板另铺红叉或绿勾，尺寸与小雷一致。
			scale_ratio = 2.82 if content_span == 3 else 0.82
			vertical_offset = -12.0 if content_span == 3 else -3.0
		ContentKind.DESTROYED:
			scale_ratio = 0.70
			vertical_offset = 0.0
		ContentKind.MONSTER, ContentKind.CORPSE:
			scale_ratio = 2.82 if content_span == 3 else 0.82
			vertical_offset = 7.0 if kind == ContentKind.CORPSE else (-12.0 if content_span == 3 else -3.0)
	if scale_ratio > 0.0:
		var content_size := _cell_size * scale_ratio
		_content.position = Vector2(
			(_cell_size - content_size) * 0.5,
			(_cell_size - content_size) * 0.5 + vertical_offset
		)
		_content.size = Vector2(content_size, content_size)
	if (
		(kind == ContentKind.MONSTER or kind == ContentKind.CORPSE or kind == ContentKind.TRIGGERED)
		and content_span == 3
	):
		_shadow.position = Vector2(-_cell_size * 0.72, _cell_size * 1.02)
		_shadow.size = Vector2(_cell_size * 2.44, _cell_size * 0.32)
	else:
		_shadow.position = Vector2(_cell_size * 0.25, _cell_size * 0.66)
		_shadow.size = Vector2(_cell_size * 0.5, _cell_size * 0.15)
	if kind == ContentKind.CORPSE:
		_content.pivot_offset = _content.size * 0.5
		_content.rotation = 0.10 if content_span == 3 else 0.24
		_content.scale = Vector2(1.0, 0.62)
		_content.modulate = Color(0.48, 0.44, 0.40, 0.86)
		_shadow.modulate = Color(0.35, 0.28, 0.24, 0.72)
	else:
		_shadow.modulate = Color.WHITE


func _set_number(value: int) -> void:
	_number_label.text = str(value)
	_number_label.add_theme_color_override("font_color", _number_color(value))
	_number_label.visible = true


func _number_color(value: int) -> Color:
	match value:
		1:
			return Color("4f8638")
		2:
			return Color("397d9f")
		3:
			return Color("c16b32")
		4:
			return Color("a34b5d")
		5:
			return Color("7952a0")
		_:
			return Color("c13f36")


func _finish_cover_animation() -> void:
	_cover.visible = false
	_cover.position = Vector2.ZERO
	_cover.rotation = 0.0
	_cover.scale = Vector2.ONE
	_cover.modulate = Color.WHITE


func _swap_reveal_face() -> void:
	if _pending_ground_texture != null:
		set_ground_texture(_pending_ground_texture)
		_pending_ground_texture = null


func _finish_flip_animation() -> void:
	_flipping = false
	_visual_root.scale = Vector2.ONE
	_visual_root.rotation = 0.0
	z_index = 0
	_finish_cover_animation()
	if _hovered and _interactive and not _revealed:
		_animate_card_hover(true)


func _animate_card_hover(hovering: bool) -> void:
	if _visual_root == null or _flipping:
		return
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	var active := hovering and _interactive and not _revealed
	z_index = 1 if active else 0
	var direction := -1.0 if cell_index % 2 == 0 else 1.0
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_visual_root, "scale", Vector2(1.12, 1.12) if active else Vector2.ONE, 0.14 if active else 0.16)
	_hover_tween.tween_property(_visual_root, "rotation", deg_to_rad(2.4 * direction) if active else 0.0, 0.14 if active else 0.16)


func _texture_layer() -> TextureRect:
	var layer := TextureRect.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return layer


func _build_mud_blobs() -> void:
	var blobs := [
		[0.25, 0.69, 0.18, 0.1, Color("6f4225")],
		[0.39, 0.73, 0.22, 0.11, Color("8a552d")],
		[0.57, 0.7, 0.19, 0.105, Color("704126")],
	]
	for definition in blobs:
		var blob := Panel.new()
		blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blob.position = Vector2(_cell_size * definition[0], _cell_size * definition[1])
		blob.size = Vector2(_cell_size * definition[2], _cell_size * definition[3])
		var style := StyleBoxFlat.new()
		style.bg_color = definition[4]
		style.border_color = Color("3e291c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		blob.add_theme_stylebox_override("panel", style)
		_mud_front.add_child(blob)


func _covered_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# The shared map layer owns the quadrilateral silhouette.  A rectangular
	# panel here would bring the stepped outline back.
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	return style


func _revealed_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	return style


func _destroyed_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("090b0a")
	style.border_color = Color("322c23")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


## A confirmed mine leaves a shallow crater instead of a card, so the slot still
## reads as handled rather than as an unflipped tile.
func _sealed_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.24)
	style.border_color = Color(1.0, 0.84, 0.42, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	return style


func _shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.0, 0.38)
	style.set_corner_radius_all(30)
	return style


func _monster_health_back_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2b1714e8")
	style.border_color = Color("f1d69a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color("160b08aa")
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _gui_input(event: InputEvent) -> void:
	# The board handles left/right actions globally. Consuming the event here keeps
	# covered cells from activating TextureButton's built-in click a second time.
	if event is InputEventMouseButton:
		accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	_animate_card_hover(true)
	_update_interaction_tint()
	hover_started.emit(cell_index)


func _on_mouse_exited() -> void:
	_hovered = false
	_animate_card_hover(false)
	_update_interaction_tint()
	hover_ended.emit(cell_index)
