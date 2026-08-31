class_name LeaderboardNameDialog
extends CanvasLayer
## 上榜时输入名称。

const LeaderboardApi := preload("res://scripts/game/leaderboard_api.gd")

signal submitted(player_name: String)
signal cancelled

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: Label
var _input: LineEdit
var _confirm: Button
var _cancel: Button
var _closing := false


func _ready() -> void:
	layer = 120
	visible = false
	_build()


func present(stage_name: String, score: int, rank_hint: int, preset_name: String = "") -> void:
	_closing = false
	_title.text = "登上排行榜"
	var rank_text := "预计约第 %d 名" % rank_hint if rank_hint > 0 else "有机会进入 Top 100"
	_body.text = "「%s」得分 %s\n%s\n请输入上榜名称（最多 %d 字）" % [
		stage_name,
		_format_score(score),
		rank_text,
		LeaderboardApi.NAME_MAX,
	]
	_input.text = LeaderboardApi.normalize_name(preset_name)
	_input.caret_column = _input.text.length()
	visible = true
	_dim.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_dim, "modulate:a", 1.0, 0.16)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	_input.grab_focus()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.04, 0.03, 0.72)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_cancel()
	)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.pivot_offset = Vector2(260, 140)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c281be8")
	style.border_color = Color("d7c073")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	_panel.add_child(stack)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color("ffd768"))
	stack.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_color_override("font_color", Color("e8efd8"))
	stack.add_child(_body)

	_input = LineEdit.new()
	_input.max_length = LeaderboardApi.NAME_MAX
	_input.placeholder_text = "你的上榜名称"
	_input.add_theme_font_size_override("font_size", 22)
	_input.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	stack.add_child(_input)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)

	_cancel = Button.new()
	_cancel.text = "跳过"
	_cancel.custom_minimum_size = Vector2(120, 48)
	_cancel.pressed.connect(_on_cancel)
	row.add_child(_cancel)

	_confirm = Button.new()
	_confirm.text = "上榜"
	_confirm.custom_minimum_size = Vector2(140, 48)
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)


func _on_confirm() -> void:
	if _closing or not visible:
		return
	var player_name := LeaderboardApi.normalize_name(_input.text)
	if player_name.is_empty():
		_input.grab_focus()
		return
	_closing = true
	await _close()
	submitted.emit(player_name)


func _on_cancel() -> void:
	if _closing or not visible:
		return
	_closing = true
	await _close()
	cancelled.emit()


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(_dim, "modulate:a", 0.0, 0.12)
	await tween.finished
	visible = false


func _format_score(value: int) -> String:
	var text := str(maxi(value, 0))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = text[i] + out
		count += 1
	return out
