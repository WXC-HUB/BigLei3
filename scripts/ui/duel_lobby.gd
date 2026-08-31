class_name DuelLobby
extends CanvasLayer
## 对战大厅：创建后亮房间码，加入时填房间码。连接中也能立刻返回主界面。

signal cancelled
signal join_submitted(room_code: String, address: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

enum Mode { HIDDEN, HOST, JOIN, JOINING }

var _mode := Mode.HIDDEN
var _dim: ColorRect
var _panel: PanelContainer
var _eyebrow: Label
var _title: Label
var _body: Label
var _code_label: Label
var _code_input: LineEdit
var _address_input: LineEdit
var _status: Label
var _join_button: Button
var _cancel_button: Button


func _ready() -> void:
	layer = 210
	visible = false
	_build()


func present_host(room_code: String) -> void:
	_mode = Mode.HOST
	_eyebrow.text = "创建对战"
	_title.text = "把房间码告诉对手"
	_body.text = "对方输入这一串才能连上。你可以随时返回主界面，不必干等。"
	_code_label.text = room_code
	_code_label.visible = true
	_code_input.visible = false
	_address_input.visible = false
	_join_button.visible = false
	_cancel_button.disabled = false
	_cancel_button.text = "返回主界面"
	_status.text = "等待对手加入…"
	_show()


func present_join() -> void:
	_mode = Mode.JOIN
	_eyebrow.text = "加入对战"
	_title.text = "输入房主的房间码"
	_body.text = "房间码必须与房主完全一致。本机对打地址用 127.0.0.1。"
	_code_label.visible = false
	_code_input.visible = true
	_code_input.editable = true
	_code_input.text = ""
	_address_input.visible = true
	_address_input.editable = true
	if _address_input.text.strip_edges().is_empty():
		_address_input.text = DuelConfig.DEFAULT_ADDRESS
	_join_button.visible = true
	_join_button.disabled = false
	_join_button.text = "连接"
	_cancel_button.disabled = false
	_cancel_button.text = "返回主界面"
	_status.text = ""
	_show()
	await get_tree().process_frame
	_code_input.grab_focus()


func set_joining(room_code: String) -> void:
	_mode = Mode.JOINING
	_eyebrow.text = "加入对战"
	_title.text = "正在连接"
	_body.text = "房间码 %s。可以随时终止，不会卡在这一页。" % room_code
	_code_label.text = room_code
	_code_label.visible = true
	_code_input.visible = false
	_address_input.visible = false
	_join_button.visible = false
	_cancel_button.disabled = false
	_cancel_button.text = "终止连接"
	_status.text = "连接中…"


func set_status(text: String) -> void:
	_status.text = text


func set_error(text: String) -> void:
	_status.text = text
	if _mode == Mode.JOINING:
		present_join()
		_status.text = text


func dismiss() -> void:
	_mode = Mode.HIDDEN
	visible = false


func is_open() -> bool:
	return visible and _mode != Mode.HIDDEN


func _show() -> void:
	visible = true
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_join_pressed() -> void:
	if _mode != Mode.JOIN:
		return
	var code := DuelConfig.normalize_room_code(_code_input.text)
	if code.length() != DuelConfig.ROOM_CODE_LENGTH:
		_status.text = "房间码是 %d 位，请再核对。" % DuelConfig.ROOM_CODE_LENGTH
		_code_input.grab_focus()
		return
	var address := _address_input.text.strip_edges()
	if address.is_empty():
		address = DuelConfig.DEFAULT_ADDRESS
	join_submitted.emit(code, address)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _mode == Mode.HIDDEN:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _on_cancel_pressed() -> void:
	if _mode == Mode.HIDDEN:
		return
	cancelled.emit()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.05, 0.04, 0.72)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_cancel_pressed()
	)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.pivot_offset = Vector2(310, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c281be8")
	style.border_color = Color("d7c073")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(26)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	_panel.add_child(stack)

	_eyebrow = _make_label(18, Color("b7c4a8"))
	stack.add_child(_eyebrow)
	_title = _make_label(30, Color("ffd768"))
	stack.add_child(_title)
	_body = _make_label(18, Color("e8efd8"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_body)

	_code_label = _make_label(56, Color("fff0b0"))
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_color_override("font_outline_color", Color("2a1a08"))
	_code_label.add_theme_constant_override("outline_size", 6)
	stack.add_child(_code_label)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "房主的房间码"
	_code_input.max_length = DuelConfig.ROOM_CODE_LENGTH
	_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_input.add_theme_font_size_override("font_size", 32)
	_code_input.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	stack.add_child(_code_input)

	_address_input = LineEdit.new()
	_address_input.placeholder_text = "房主地址（本机对打填 127.0.0.1）"
	_address_input.add_theme_font_size_override("font_size", 20)
	stack.add_child(_address_input)

	_status = _make_label(16, Color("b7c4a8"))
	stack.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)

	_cancel_button = Button.new()
	_cancel_button.text = "返回主界面"
	_cancel_button.custom_minimum_size = Vector2(160, 52)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel_button)

	_join_button = Button.new()
	_join_button.text = "连接"
	_join_button.custom_minimum_size = Vector2(140, 52)
	_join_button.pressed.connect(_on_join_pressed)
	row.add_child(_join_button)

	ButtonMotion.bind(_cancel_button, _cancel_button, -0.8)
	ButtonMotion.bind(_join_button, _join_button, 0.8)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
