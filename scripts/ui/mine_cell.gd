class_name MineCell
extends TextureButton

signal primary_pressed(cell_index: int)
signal secondary_pressed(cell_index: int)
signal mouse_button_changed(cell_index: int, button_index: int, pressed: bool)
signal hover_started(cell_index: int)
signal hover_ended(cell_index: int)

enum ContentKind { EMPTY, NUMBER, ITEM, MONSTER, CORPSE }

var cell_index := -1
var _cell_size := 86.0
var _base: TextureRect
var _surface: Panel
var _preview_overlay: Panel
var _shadow: Panel
var _content: TextureRect
var _number_label: Label
var _mud_front: Control
var _cover: TextureRect
var _marker: TextureRect
var _combat_label: Label
var _interactive := true
var _targeting_selected := false
var _effect_preview := false
var _preview_color := Color.WHITE
var _hovered := false
var _ground_texture: Texture2D
var _showing_corpse := false


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_normal = null

	_base = _texture_layer()
	add_child(_base)

	# The cell is a translucent ground treatment, not a raised tile.
	_surface = Panel.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_theme_stylebox_override("panel", _covered_surface_style())
	add_child(_surface)

	# Ground artwork lives in MapTileLayer, outside this control, so tinting this
	# node alone cannot highlight a covered cell. This overlay provides actual
	# visible pixels for inference/effect previews.
	_preview_overlay = Panel.new()
	_preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_overlay.z_index = 12
	_preview_overlay.visible = false
	add_child(_preview_overlay)

	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.add_theme_stylebox_override("panel", _shadow_style())
	add_child(_shadow)

	_content = _texture_layer()
	_content.z_index = 20
	add_child(_content)

	_number_label = Label.new()
	_number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.add_theme_color_override("font_outline_color", Color("f5e8bd"))
	_number_label.add_theme_constant_override("outline_size", 6)
	_number_label.add_theme_font_size_override("font_size", 38)
	_number_label.z_index = 18
	_number_label.visible = false
	add_child(_number_label)

	_mud_front = Control.new()
	_mud_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mud_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mud_front)
	_build_mud_blobs()

	_cover = _texture_layer()
	add_child(_cover)

	_marker = _texture_layer()
	_marker.z_index = 26
	add_child(_marker)

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
	add_child(_combat_label)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(index: int, cell_size: float) -> void:
	cell_index = index
	_cell_size = cell_size
	custom_minimum_size = Vector2(cell_size, cell_size)
	size = Vector2(cell_size, cell_size)


func set_ground_texture(texture: Texture2D) -> void:
	_ground_texture = texture
	if _base != null:
		_base.texture = texture
		_base.visible = texture != null


func display_covered(marker: Texture2D = null) -> void:
	# Keep the scenery visible through the board.  The old grass-card textures made
	# every cell read as a solid object floating above the clearing.
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
	_number_label.visible = false
	_combat_label.visible = false
	_showing_corpse = false
	_targeting_selected = false
	_effect_preview = false
	if _preview_overlay != null:
		_preview_overlay.visible = false
	self_modulate = Color.WHITE
	_targeting_selected = false
	_set_content(null, ContentKind.EMPTY)
	modulate = Color.WHITE


func display_revealed(
	content: Texture2D = null,
	kind: ContentKind = ContentKind.EMPTY,
	preserve_cover_for_animation: bool = false,
	content_span: int = 1,
	number_value: int = 0
) -> void:
	_base.texture = _ground_texture
	_base.visible = _ground_texture != null
	_surface.add_theme_stylebox_override("panel", _revealed_surface_style())
	_marker.visible = false
	_combat_label.visible = false
	_showing_corpse = kind == ContentKind.CORPSE
	_set_content(content, kind, content_span)
	if kind == ContentKind.NUMBER and number_value > 0:
		_set_number(number_value)
	if not preserve_cover_for_animation:
		_cover.visible = false
	modulate = Color.WHITE


func set_interactable(value: bool) -> void:
	_interactive = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func set_flag_marker(marker: Texture2D) -> void:
	_marker.texture = marker
	_marker.visible = marker != null


func play_reveal() -> void:
	_content.pivot_offset = _content.size * 0.5
	_content.scale = Vector2(0.58, 0.58)
	_content.modulate.a = 0.0
	_number_label.pivot_offset = _number_label.size * 0.5
	_number_label.scale = Vector2(0.58, 0.58)
	_number_label.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "scale", Vector2.ONE, 0.2).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_content, "modulate:a", 1.0, 0.14).set_delay(0.07)
	tween.tween_property(_number_label, "scale", Vector2.ONE, 0.2).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_number_label, "modulate:a", 1.0, 0.14).set_delay(0.07)
	tween.finished.connect(_finish_cover_animation)


func play_flag() -> void:
	_marker.pivot_offset = _marker.size * 0.5
	_marker.rotation = deg_to_rad(-5.0)
	_marker.scale = Vector2(0.72, 0.72)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_marker, "rotation", 0.0, 0.16)
	tween.tween_property(_marker, "scale", Vector2.ONE, 0.16)


func play_light(color: Color) -> void:
	var original := self_modulate
	var glow := color
	glow.a = 1.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "self_modulate", glow, 0.12)
	tween.tween_property(self, "self_modulate", original, 0.3)


func prepare_monster_emerge() -> void:
	_content.modulate.a = 0.0
	_shadow.modulate.a = 0.0
	_combat_label.visible = false


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


func set_combat_mine_status(hp: int, turns_until_attack: int) -> void:
	_combat_label.text = "%d HP · %d回" % [hp, turns_until_attack]
	_combat_label.visible = true


func is_showing_corpse() -> bool:
	return _showing_corpse


func set_targeting_selected(value: bool) -> void:
	_targeting_selected = value
	_update_interaction_tint()


func set_effect_preview(value: bool, color: Color = Color.WHITE) -> void:
	_effect_preview = value
	_preview_color = color
	_update_interaction_tint()


func _update_interaction_tint() -> void:
	_update_preview_overlay()
	if _targeting_selected:
		self_modulate = Color(1.25, 1.12, 0.72, 1.0)
	elif _effect_preview:
		self_modulate = _preview_color
	elif _hovered and _interactive:
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
	_content.z_index = 8 if kind == ContentKind.CORPSE else 20
	_shadow.visible = kind == ContentKind.ITEM or kind == ContentKind.MONSTER or kind == ContentKind.CORPSE
	_mud_front.visible = kind == ContentKind.ITEM or (kind == ContentKind.MONSTER and content_span == 1)
	var scale_ratio := 0.0
	var vertical_offset := 0.0
	match kind:
		ContentKind.NUMBER:
			scale_ratio = 0.54
			vertical_offset = -2.0
		ContentKind.ITEM:
			scale_ratio = 0.82
			vertical_offset = -4.0
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
	if (kind == ContentKind.MONSTER or kind == ContentKind.CORPSE) and content_span == 3:
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


func _shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.0, 0.38)
	style.set_corner_radius_all(30)
	return style


func _gui_input(event: InputEvent) -> void:
	# Mouse chords are tracked by the board's global input handler. Consuming the
	# event here keeps covered cells from activating TextureButton's built-in click.
	if event is InputEventMouseButton:
		accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	_update_interaction_tint()
	hover_started.emit(cell_index)


func _on_mouse_exited() -> void:
	_hovered = false
	_update_interaction_tint()
	hover_ended.emit(cell_index)
