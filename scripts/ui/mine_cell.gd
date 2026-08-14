class_name MineCell
extends TextureButton

signal primary_pressed(cell_index: int)
signal secondary_pressed(cell_index: int)

enum ContentKind { EMPTY, NUMBER, ITEM, MINE }

var cell_index := -1
var _cell_size := 86.0
var _base: TextureRect
var _pit_rim: Panel
var _shadow: Panel
var _content: TextureRect
var _mud_front: Control
var _cover: TextureRect
var _marker: TextureRect
var _interactive := true


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_normal = null

	_base = _texture_layer()
	add_child(_base)

	_pit_rim = Panel.new()
	_pit_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pit_rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pit_rim.offset_left = 7.0
	_pit_rim.offset_top = 7.0
	_pit_rim.offset_right = -7.0
	_pit_rim.offset_bottom = -7.0
	_pit_rim.add_theme_stylebox_override("panel", _pit_rim_style())
	add_child(_pit_rim)

	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.add_theme_stylebox_override("panel", _shadow_style())
	add_child(_shadow)

	_content = _texture_layer()
	add_child(_content)

	_mud_front = Control.new()
	_mud_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mud_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_mud_front)
	_build_mud_blobs()

	_cover = _texture_layer()
	add_child(_cover)

	_marker = _texture_layer()
	add_child(_marker)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(index: int, cell_size: float) -> void:
	cell_index = index
	_cell_size = cell_size
	custom_minimum_size = Vector2(cell_size, cell_size)


func display_covered(cover: Texture2D, base: Texture2D, marker: Texture2D = null) -> void:
	_base.texture = base
	_cover.texture = cover
	_cover.visible = true
	_cover.position = Vector2.ZERO
	_cover.rotation = 0.0
	_cover.scale = Vector2.ONE
	_cover.modulate = Color.WHITE
	_marker.texture = marker
	_marker.visible = marker != null
	_set_content(null, ContentKind.EMPTY)
	_pit_rim.visible = false
	modulate = Color.WHITE


func display_revealed(
	base: Texture2D,
	content: Texture2D = null,
	kind: ContentKind = ContentKind.EMPTY,
	preserve_cover_for_animation: bool = false
) -> void:
	_base.texture = base
	_pit_rim.visible = true
	_marker.visible = false
	_set_content(content, kind)
	if not preserve_cover_for_animation:
		_cover.visible = false
	modulate = Color.WHITE


func set_interactable(value: bool) -> void:
	_interactive = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func play_reveal() -> void:
	var direction := -1.0 if cell_index % 2 == 0 else 1.0
	_cover.pivot_offset = _cover.size * Vector2(0.5, 0.8)
	_content.pivot_offset = _content.size * 0.5
	_content.scale = Vector2(0.58, 0.58)
	_content.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_cover, "position", Vector2(direction * 10.0, -30.0), 0.24)
	tween.tween_property(_cover, "rotation", direction * 0.18, 0.24)
	tween.tween_property(_cover, "scale", Vector2(1.04, 0.9), 0.24)
	tween.tween_property(_cover, "modulate:a", 0.0, 0.22)
	tween.tween_property(_content, "scale", Vector2.ONE, 0.2).set_delay(0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_content, "modulate:a", 1.0, 0.14).set_delay(0.07)
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


func _set_content(texture: Texture2D, kind: ContentKind) -> void:
	_content.texture = texture
	_content.visible = texture != null
	_content.modulate = Color.WHITE
	_content.scale = Vector2.ONE
	_shadow.visible = kind == ContentKind.ITEM or kind == ContentKind.MINE
	_mud_front.visible = kind == ContentKind.ITEM or kind == ContentKind.MINE
	var scale_ratio := 0.0
	var vertical_offset := 0.0
	match kind:
		ContentKind.NUMBER:
			scale_ratio = 0.54
			vertical_offset = -2.0
		ContentKind.ITEM:
			scale_ratio = 0.82
			vertical_offset = -4.0
		ContentKind.MINE:
			scale_ratio = 0.82
			vertical_offset = -3.0
	if scale_ratio > 0.0:
		var content_size := _cell_size * scale_ratio
		_content.position = Vector2(
			(_cell_size - content_size) * 0.5,
			(_cell_size - content_size) * 0.5 + vertical_offset
		)
		_content.size = Vector2(content_size, content_size)
	_shadow.position = Vector2(_cell_size * 0.25, _cell_size * 0.66)
	_shadow.size = Vector2(_cell_size * 0.5, _cell_size * 0.15)


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


func _pit_rim_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.025, 0.01, 0.08)
	style.border_color = Color(0.04, 0.02, 0.01, 0.34)
	style.set_border_width_all(5)
	style.set_corner_radius_all(12)
	return style


func _shadow_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.0, 0.38)
	style.set_corner_radius_all(30)
	return style


func _gui_input(event: InputEvent) -> void:
	if not _interactive or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		primary_pressed.emit(cell_index)
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		secondary_pressed.emit(cell_index)


func _on_mouse_entered() -> void:
	if _interactive:
		self_modulate = Color(1.1, 1.1, 1.04, 1.0)


func _on_mouse_exited() -> void:
	self_modulate = Color.WHITE
