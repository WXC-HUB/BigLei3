class_name LeaderboardPanel
extends CanvasLayer
## 分关 Top100。
## - present：地图右键浏览（非阻塞）
## - present_after_clear：通关后阻塞页；可随时跳过，榜加载完才能上榜

const LeaderboardApi := preload("res://scripts/game/leaderboard_api.gd")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

signal closed
## 浏览页里二次上传成功后发出，让 main.gd 把昵称记进存档、下次预填。
signal name_remembered(player_name: String)

enum Mode { BROWSE, CLEAR }

const COLOR_TITLE := Color("ffd768")
const COLOR_BODY := Color("e8efd8")
const COLOR_MUTED := Color("b7c4a8")
const COLOR_RANK_1 := Color("ffd768")
const COLOR_RANK_2 := Color("d5deea")
const COLOR_RANK_3 := Color("e0b07a")
const COLOR_SCORE := Color("f3e7b0")

var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _stage_tabs: HBoxContainer
var _tab_buttons: Dictionary = {}
var _score_label: Label
var _status: Label
var _rows: VBoxContainer
var _empty_label: Label
var _name_caption: Label
var _name_row: HBoxContainer
var _name_input: LineEdit
var _submit_button: Button
var _skip_button: Button
var _close_button: Button
var _browse_actions: HBoxContainer
var _upload_button: Button
var _upload_dialog: Control
var _upload_title: Label
var _upload_body: Label
var _upload_input: LineEdit
var _upload_note: Label
var _upload_confirm: Button
var _upload_cancel: Button
var _http: HTTPRequest

var _mode := Mode.BROWSE
var _closing := false
var _loading := false
var _list_ready := false
var _stage_id := ""
var _stage_name := ""
var _score := 0
var _session := 0
var _result: Dictionary = {}
## 本地每关最高分（stage_id → int）和记住的昵称，由 main.gd 在 present 前灌进来。
## 浏览页的「上传我的最高分」就是拿这份数据去补传，不依赖当前是否正在打这一关。
var _local_scores: Dictionary = {}
var _preset_name := ""
var _uploading := false
func _ready() -> void:
	layer = 118
	add_to_group("modal_overlay")
	visible = false
	_http = HTTPRequest.new()
	_http.timeout = LeaderboardApi.REQUEST_TIMEOUT_SEC
	add_child(_http)
	_build()
	_apply_mode_ui()


## 地图浏览：打开即返回，点关闭结束。
func present(stage_id: String, stage_name: String) -> void:
	if not StageTable.has_leaderboard(stage_id):
		return
	_session += 1
	var token := _session
	_mode = Mode.BROWSE
	_stage_id = stage_id
	_stage_name = stage_name
	_score = 0
	_result.clear()
	_closing = false
	_list_ready = false
	_apply_mode_ui()
	_title.text = "「%s」排行榜" % stage_name
	_status.text = "Top %d · 加载中…" % LeaderboardApi.TOP_LIMIT
	_clear_rows()
	_refresh_stage_tabs()
	_show_open()
	await _load_top(token)


## 选关图「全部排行榜」：从第一个上榜关打开浏览页，顶上可以切到任意上榜关。
## 落点不能写死 `STAGES[0]`——那是教学关，它没有榜。
## main.gd 在每次 present 之前调用：把本地最高分和记住的昵称交给面板。
func set_local_context(scores: Dictionary, player_name: String) -> void:
	_local_scores = scores.duplicate()
	_preset_name = LeaderboardApi.normalize_name(player_name)
	_refresh_upload_button()


## 当前这一关本地记录的最高分；没有记录返回 0。
func local_best() -> int:
	return maxi(int(_local_scores.get(_stage_id, 0)), 0)


func present_all() -> void:
	var ranked := StageTable.leaderboard_stages()
	if ranked.is_empty():
		return
	var first: Dictionary = ranked[0]
	present(String(first["id"]), String(first.get("name", "")))


## 通关阻塞页：await 直到玩家跳过或上榜结束并关闭。
## 返回 { skipped, submitted, name, rank }
func present_after_clear(
	stage_id: String,
	stage_name: String,
	score: int,
	preset_name: String = "",
	title: String = ""
) -> Dictionary:
	_session += 1
	var token := _session
	_mode = Mode.CLEAR
	_stage_id = stage_id
	_stage_name = stage_name
	_score = maxi(score, 0)
	_result.clear()
	_closing = false
	_list_ready = false
	_loading = false
	_apply_mode_ui()
	_skip_button.disabled = false
	# 无尽关没有「通关」，倒下时由调用方传「止步第 N 盘」之类的标题。
	_title.text = title if title != "" else "「%s」通关结算" % stage_name
	_score_label.text = "本关得分    %s" % _format_score(_score)
	_name_input.text = LeaderboardApi.normalize_name(preset_name)
	_name_input.caret_column = _name_input.text.length()
	_status.text = "Top %d · 排行榜加载中…" % LeaderboardApi.TOP_LIMIT
	_clear_rows()
	_set_submit_enabled(false)
	_show_open()
	_load_top(token)
	while _result.is_empty() and visible:
		await get_tree().process_frame
	return _result.duplicate(true)


func hide_immediately() -> void:
	_session += 1
	_loading = false
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	if _mode == Mode.CLEAR and _result.is_empty():
		_result = {"skipped": true, "submitted": false, "name": "", "rank": 0}
	visible = false
	_closing = false
	closed.emit()


func _show_open() -> void:
	visible = true
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.86, 0.86)
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.32)


func _load_top(token: int) -> void:
	_loading = true
	_set_submit_enabled(false)
	var result := await LeaderboardApi.fetch_top(_http, _stage_id, LeaderboardApi.TOP_LIMIT)
	_loading = false
	if token != _session or not visible:
		return
	_fill_list(result)
	_list_ready = true
	if (
		_mode == Mode.CLEAR
		and _score > 0
		and not _closing
		and _result.is_empty()
		and not _submit_button.text.begins_with("提交")
	):
		_set_submit_enabled(true)
		_name_input.grab_focus()


func _fill_list(result: Dictionary) -> void:
	_clear_rows()
	if not bool(result.get("ok", false)):
		var err := String(result.get("error", ""))
		if err == "http_result" or int(result.get("result", -1)) == HTTPRequest.RESULT_TIMEOUT:
			_status.text = "连不上服务器。可跳过，或仍尝试上榜。"
		else:
			_status.text = "加载失败。可跳过，或仍尝试上榜。"
		_empty_label.text = "暂时看不到榜单"
		_empty_label.visible = true
		return
	var entries: Array = result.get("entries", [])
	if entries.is_empty():
		_status.text = "Top %d · 还没有人上榜" % LeaderboardApi.TOP_LIMIT
		_empty_label.text = "还没有人上榜"
		_empty_label.visible = true
		return
	_status.text = "Top %d · 共 %d 名" % [LeaderboardApi.TOP_LIMIT, entries.size()]
	_empty_label.visible = false
	var shown := 0
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		_add_row(
			int(row.get("rank", 0)),
			String(row.get("name", "")),
			int(row.get("score", 0)),
			shown
		)
		shown += 1


func _clear_rows() -> void:
	for child in _rows.get_children():
		if child == _empty_label:
			continue
		child.queue_free()
	_empty_label.visible = false


func _add_row(rank: int, player_name: String, score: int, index: int) -> void:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 56)
	wrap.add_theme_stylebox_override("panel", _row_highlight(index))
	wrap.modulate.a = 0.0
	_rows.add_child(wrap)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	wrap.add_child(inner)

	var rank_label := _make_label("%d" % rank, 28, _rank_color(rank))
	rank_label.custom_minimum_size = Vector2(72, 0)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(rank_label)

	var name_label := _make_label(player_name, 28, COLOR_BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(name_label)

	var score_label := _make_label(_format_score(score), 28, COLOR_SCORE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.custom_minimum_size = Vector2(180, 0)
	inner.add_child(score_label)

	if index < 12:
		var tween := create_tween()
		tween.tween_interval(0.03 * float(index))
		tween.tween_property(wrap, "modulate:a", 1.0, 0.18)
	else:
		wrap.modulate.a = 1.0


func _apply_mode_ui() -> void:
	var is_clear := _mode == Mode.CLEAR
	_score_label.visible = is_clear
	_name_row.visible = is_clear
	_skip_button.visible = is_clear
	_submit_button.visible = is_clear
	_close_button.visible = not is_clear
	if _browse_actions != null:
		_browse_actions.visible = not is_clear
	if _upload_dialog != null and is_clear:
		_upload_dialog.visible = false
	if _stage_tabs != null:
		_stage_tabs.visible = not is_clear
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_upload_button()


func _set_submit_enabled(enabled: bool) -> void:
	_submit_button.disabled = not enabled
	_name_input.editable = enabled or _mode != Mode.CLEAR
	if _mode == Mode.CLEAR and not _list_ready:
		_submit_button.disabled = true
		_name_input.editable = false
		_submit_button.text = "加载中…"
	elif _mode == Mode.CLEAR:
		_submit_button.text = "上榜"
		_name_input.editable = true


func _on_skip_pressed() -> void:
	if _closing or _mode != Mode.CLEAR:
		return
	_session += 1
	_loading = false
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	_finish_clear({"skipped": true, "submitted": false, "name": "", "rank": 0})


func _on_submit_pressed() -> void:
	if _closing or _mode != Mode.CLEAR or not _list_ready or _loading:
		return
	if _score <= 0:
		_status.text = "本关没有得分，无法上榜。"
		return
	var player_name := LeaderboardApi.normalize_name(_name_input.text)
	if player_name.is_empty():
		_status.text = "请先填写上榜名称。"
		_name_input.grab_focus()
		return
	var token := _session
	_set_submit_enabled(false)
	_submit_button.text = "提交中…"
	_status.text = "正在上榜…"
	_loading = true
	var result := await LeaderboardApi.submit(_http, _stage_id, player_name, _score)
	_loading = false
	if token != _session or not visible or _mode != Mode.CLEAR or _closing:
		return
	if bool(result.get("ok", false)) and bool(result.get("accepted", false)):
		var rank := int(result.get("rank", 0))
		_status.text = "上榜成功：%s · 第 %d 名" % [player_name, rank]
		_submit_button.text = "已上榜"
		_submit_button.disabled = true
		_name_input.editable = false
		await _load_top(token)
		if token != _session or not visible or _closing:
			return
		_submit_button.disabled = true
		_name_input.editable = false
		await get_tree().create_timer(0.7).timeout
		if token != _session or not visible or _closing:
			return
		_finish_clear({
			"skipped": false,
			"submitted": true,
			"name": player_name,
			"rank": rank,
		})
		return
	if bool(result.get("ok", false)):
		_status.text = "分数未刷新个人最佳，榜单未改动。"
		await get_tree().create_timer(0.55).timeout
		if token != _session or not visible or _closing:
			return
		_finish_clear({
			"skipped": false,
			"submitted": false,
			"name": player_name,
			"rank": int(result.get("rank", 0)),
		})
		return
	var detail := _submit_error_text(result)
	_status.text = detail if detail != "" else "上榜失败（网络不通）。可重试或跳过。"
	_set_submit_enabled(true)
	_submit_button.text = "上榜"


## 没有本地记录就不显示这颗按钮：没分可传，摆在那儿只会让人点了发现没反应。
func _refresh_upload_button() -> void:
	if _upload_button == null:
		return
	var best := local_best()
	_upload_button.visible = _mode == Mode.BROWSE and best > 0
	_upload_button.disabled = _uploading
	if best > 0:
		_upload_button.text = "上传我的最高分 %s" % _format_score(best)


func _on_upload_pressed() -> void:
	if _mode != Mode.BROWSE or _closing or _uploading:
		return
	var best := local_best()
	if best <= 0:
		return
	_upload_title.text = "上传到「%s」" % _stage_name
	_upload_body.text = "本地最高分 %s\n同名只保留更高的一次；分数没刷新就不会改动榜单。" % _format_score(best)
	_upload_input.text = _preset_name
	_upload_input.caret_column = _upload_input.text.length()
	_upload_input.editable = true
	_upload_note.text = ""
	_upload_confirm.disabled = false
	_upload_confirm.text = "上传"
	_upload_dialog.visible = true
	_upload_input.grab_focus()


func _on_upload_cancelled() -> void:
	if _uploading:
		return
	_upload_dialog.visible = false


func _on_upload_confirmed() -> void:
	if _uploading or _mode != Mode.BROWSE:
		return
	var best := local_best()
	if best <= 0:
		_upload_note.text = "这一关本地还没有成绩。"
		_upload_note.add_theme_color_override("font_color", COLOR_MUTED)
		return
	var player_name := LeaderboardApi.normalize_name(_upload_input.text)
	if player_name.is_empty():
		_upload_note.text = "请先填写上榜名称。"
		_upload_note.add_theme_color_override("font_color", Color("ff8a6a"))
		_upload_input.grab_focus()
		return
	var token := _session
	var stage := _stage_id
	_uploading = true
	_upload_confirm.disabled = true
	_upload_confirm.text = "上传中…"
	_upload_input.editable = false
	_upload_note.text = "正在上传…"
	_upload_note.add_theme_color_override("font_color", COLOR_TITLE)
	_refresh_upload_button()

	var result := await LeaderboardApi.submit(_http, stage, player_name, best)
	_uploading = false
	_upload_confirm.disabled = false
	_upload_confirm.text = "上传"
	_upload_input.editable = true
	_refresh_upload_button()
	# 传的过程中玩家可能切了关或者把榜关了：那就别再动 UI，结果也不作数。
	if token != _session or not visible or _closing or _mode != Mode.BROWSE:
		return

	if not bool(result.get("ok", false)):
		var detail := _submit_error_text(result)
		_upload_note.text = detail if detail != "" else "上传失败（网络不通），可以再试一次。"
		_upload_note.add_theme_color_override("font_color", Color("ff8a6a"))
		return

	_preset_name = player_name
	name_remembered.emit(player_name)
	var rank := int(result.get("rank", 0))
	if bool(result.get("accepted", false)):
		_status.text = "已上传：%s · 第 %d 名" % [player_name, rank]
	elif String(result.get("reason", "")) == "below_cutoff":
		_status.text = "分数没进前 %d 名，榜单未改动。" % LeaderboardApi.TOP_LIMIT
	else:
		_status.text = "「%s」榜上已有更高的成绩，榜单未改动。" % player_name
	_status.add_theme_color_override("font_color", COLOR_BODY)
	_upload_dialog.visible = false
	await _load_top(token)


## 服务端 2026-09-16 起会按关卡上限和计分粒度退回不可能的分。退回时给的是
## 400 + 具体原因，和网络不通是两回事，文案要分开，不然玩家会一直重试。
func _submit_error_text(result: Dictionary) -> String:
	var reason := String(result.get("error", ""))
	if reason == "score_too_high":
		return "这个分数超出本关上限（%s），服务器没有收。可能是游戏版本太旧。" % _format_score(int(result.get("max", 0)))
	if reason == "score_not_aligned":
		return "这个分数不符合本关的计分口径，服务器没有收。可能是游戏版本太旧。"
	if reason == "bad_name":
		return "名称不合法，换一个再试。"
	if reason == "bad_score" or reason == "bad_stage":
		return "提交的数据不合法，服务器没有收。"
	return ""


func _on_close_pressed() -> void:
	if _mode == Mode.CLEAR:
		_on_skip_pressed()
		return
	_request_close_browse()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# 上传弹窗开着时，点外面只关弹窗，不该顺手把整张榜也关了。
		if _upload_dialog != null and _upload_dialog.visible:
			_on_upload_cancelled()
			return
		if _mode == Mode.BROWSE:
			_request_close_browse()


func _finish_clear(payload: Dictionary) -> void:
	if _closing:
		return
	_closing = true
	_result = payload
	await _play_close()
	visible = false
	_closing = false
	closed.emit()


func _request_close_browse() -> void:
	if _closing or not visible or _mode != Mode.BROWSE:
		return
	_closing = true
	_session += 1
	await _play_close()
	visible = false
	_closing = false
	closed.emit()


func _play_close() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.16)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.14)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.16)
	await tween.finished
	_panel.scale = Vector2.ONE


func _build() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.03, 0.04, 0.03, 0.78)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(920, 920)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_center.add_child(_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	_panel.add_child(stack)

	_title = _make_label("", 40, COLOR_TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_title)

	_stage_tabs = HBoxContainer.new()
	_stage_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_tabs.add_theme_constant_override("separation", 8)
	stack.add_child(_stage_tabs)
	_build_stage_tabs()

	_score_label = _make_label("", 32, COLOR_SCORE)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_score_label)

	_status = _make_label("", 22, COLOR_MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_status)

	var header := _make_header()
	stack.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)

	_empty_label = _make_label("还没有人上榜", 28, COLOR_MUTED)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.custom_minimum_size = Vector2(0, 160)
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.visible = false
	_rows.add_child(_empty_label)

	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 14)
	stack.add_child(_name_row)

	_name_caption = _make_label("名称", 26, COLOR_BODY)
	_name_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_row.add_child(_name_caption)

	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.custom_minimum_size = Vector2(0, 58)
	_name_input.max_length = LeaderboardApi.NAME_MAX
	_name_input.placeholder_text = "上榜名称（最多 %d 字）" % LeaderboardApi.NAME_MAX
	_name_input.add_theme_font_size_override("font_size", 26)
	_name_input.add_theme_color_override("font_color", COLOR_BODY)
	_name_input.add_theme_color_override("font_placeholder_color", Color("b7c4a8a0"))
	_name_input.add_theme_stylebox_override("normal", _input_style())
	_name_input.add_theme_stylebox_override("focus", _input_style(true))
	_name_input.text_submitted.connect(func(_t: String) -> void: _on_submit_pressed())
	_name_row.add_child(_name_input)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 16)
	stack.add_child(actions)

	_skip_button = _make_button("跳过", Vector2(168, 64), false)
	_skip_button.pressed.connect(_on_skip_pressed)
	actions.add_child(_skip_button)

	_submit_button = _make_button("上榜", Vector2(220, 64), true)
	_submit_button.pressed.connect(_on_submit_pressed)
	actions.add_child(_submit_button)

	# 浏览页底部是「上传我的最高分」＋「关闭」两颗；通关页只用上面那排跳过/上榜。
	_browse_actions = HBoxContainer.new()
	_browse_actions.add_theme_constant_override("separation", 16)
	stack.add_child(_browse_actions)

	_upload_button = _make_button("上传我的最高分", Vector2(360, 64), false)
	_upload_button.pressed.connect(_on_upload_pressed)
	_browse_actions.add_child(_upload_button)

	_close_button = _make_button("关闭", Vector2(0, 64), true)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(_on_close_pressed)
	_browse_actions.add_child(_close_button)

	_build_upload_dialog()

	ButtonMotion.bind(_skip_button)
	ButtonMotion.bind(_submit_button)
	ButtonMotion.bind(_close_button)
	ButtonMotion.bind(_upload_button)
	ButtonMotion.bind(_upload_confirm)
	ButtonMotion.bind(_upload_cancel)


## 二次上传的确认弹窗：盖在榜上面，问一个名字就发。
func _build_upload_dialog() -> void:
	_upload_dialog = Control.new()
	_upload_dialog.name = "UploadDialog"
	_upload_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upload_dialog.visible = false
	add_child(_upload_dialog)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.02, 0.62)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_upload_cancelled()
	)
	_upload_dialog.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upload_dialog.add_child(center)

	var card := PanelContainer.new()
	card.name = "UploadCard"
	card.custom_minimum_size = Vector2(660, 0)
	card.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	card.add_child(stack)

	stack.add_child(_make_label("补传成绩", 22, COLOR_MUTED))
	_upload_title = _make_label("", 34, COLOR_TITLE)
	stack.add_child(_upload_title)
	_upload_body = _make_label("", 26, COLOR_BODY)
	_upload_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_upload_body)

	_upload_input = LineEdit.new()
	_upload_input.name = "UploadNameInput"
	_upload_input.custom_minimum_size = Vector2(0, 58)
	_upload_input.max_length = LeaderboardApi.NAME_MAX
	_upload_input.placeholder_text = "上榜名称（最多 %d 字）" % LeaderboardApi.NAME_MAX
	_upload_input.add_theme_font_size_override("font_size", 26)
	_upload_input.add_theme_color_override("font_color", COLOR_BODY)
	_upload_input.add_theme_color_override("font_placeholder_color", Color("b7c4a8a0"))
	_upload_input.add_theme_stylebox_override("normal", _input_style())
	_upload_input.add_theme_stylebox_override("focus", _input_style(true))
	_upload_input.text_submitted.connect(func(_t: String) -> void: _on_upload_confirmed())
	stack.add_child(_upload_input)

	_upload_note = _make_label("", 22, COLOR_MUTED)
	_upload_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upload_note.custom_minimum_size = Vector2(0, 52)
	stack.add_child(_upload_note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	_upload_cancel = _make_button("取消", Vector2(160, 60), false)
	_upload_cancel.pressed.connect(_on_upload_cancelled)
	row.add_child(_upload_cancel)
	_upload_confirm = _make_button("上传", Vector2(200, 60), true)
	_upload_confirm.pressed.connect(_on_upload_confirmed)
	row.add_child(_upload_confirm)


func _build_stage_tabs() -> void:
	for child in _stage_tabs.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for stage in StageTable.leaderboard_stages():
		var id := String(stage["id"])
		var button := _make_button(String(stage.get("name", id)), Vector2(0, 44), false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_stage_tab_pressed.bind(id))
		_stage_tabs.add_child(button)
		_tab_buttons[id] = button
		ButtonMotion.bind(button)
	_refresh_stage_tabs()


func _refresh_stage_tabs() -> void:
	for id in _tab_buttons.keys():
		var button: Button = _tab_buttons[id]
		var selected := String(id) == _stage_id
		button.add_theme_stylebox_override("normal", _button_style(selected, false))
		button.add_theme_stylebox_override("hover", _button_style(selected, true))
		button.add_theme_stylebox_override("pressed", _button_style(true, true))
		button.add_theme_color_override("font_color", Color("1a2016") if selected else COLOR_TITLE)
		button.add_theme_color_override("font_hover_color", Color("1a2016") if selected else COLOR_BODY)
		button.add_theme_color_override("font_pressed_color", Color("1a2016"))


func _on_stage_tab_pressed(stage_id: String) -> void:
	if _mode != Mode.BROWSE or _closing or not visible:
		return
	if stage_id == _stage_id:
		return
	var stage := StageTable.stage(stage_id)
	if stage.is_empty():
		return
	_session += 1
	var token := _session
	_stage_id = stage_id
	_stage_name = String(stage.get("name", stage_id))
	_list_ready = false
	_title.text = "「%s」排行榜" % _stage_name
	_status.text = "Top %d · 加载中…" % LeaderboardApi.TOP_LIMIT
	_clear_rows()
	_refresh_stage_tabs()
	_refresh_upload_button()
	_load_top(token)


func _make_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	var rank := _make_label("名次", 20, COLOR_MUTED)
	rank.custom_minimum_size = Vector2(84, 0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(rank)
	var who := _make_label("名称", 20, COLOR_MUTED)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(who)
	var score := _make_label("分数", 20, COLOR_MUTED)
	score.custom_minimum_size = Vector2(180, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(score)
	return header


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, min_size: Vector2, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("1a2016") if filled else COLOR_TITLE)
	button.add_theme_color_override("font_hover_color", Color("1a2016") if filled else COLOR_BODY)
	button.add_theme_color_override("font_pressed_color", Color("1a2016") if filled else COLOR_BODY)
	button.add_theme_color_override("font_disabled_color", Color("1a2016a8") if filled else Color("b7c4a888"))
	button.add_theme_stylebox_override("normal", _button_style(filled, false))
	button.add_theme_stylebox_override("hover", _button_style(filled, true))
	button.add_theme_stylebox_override("pressed", _button_style(filled, true))
	button.add_theme_stylebox_override("disabled", _button_style(filled, false))
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("121a14f5")
	style.border_color = Color("d7c073")
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(28)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 18
	return style


func _input_style(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0e1510")
	style.border_color = Color("d7c073") if focused else Color("6d7a58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _button_style(filled: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if filled:
		style.bg_color = Color("f0d36a") if hover else Color("d7c073")
	else:
		style.bg_color = Color("1c2818")
		style.border_color = Color("d7c073")
		style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _row_highlight(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match index:
		0:
			style.bg_color = Color("3a3014cc")
			style.border_color = Color("d7c073")
			style.set_border_width_all(2)
		1:
			style.bg_color = Color("2a3238cc")
		2:
			style.bg_color = Color("33281ccc")
		_:
			style.bg_color = Color("1a2218aa")
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _rank_color(rank: int) -> Color:
	match rank:
		1:
			return COLOR_RANK_1
		2:
			return COLOR_RANK_2
		3:
			return COLOR_RANK_3
		_:
			return COLOR_MUTED


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
