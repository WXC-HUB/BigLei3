class_name WorkshopPanel
extends CanvasLayer
## 创意工坊浏览页：按最新 / 最热列关卡包，能点赞、能直接开玩。
##
## 只做需求里点名的三件事——列表、点赞、按点赞或时间排序。没有排行榜、没有评论、
## 没有鉴权；下载下来的包走的是自定义模式那条既有路径，打完还能「返回编辑」接着改。
##
## 总开关是 `WorkshopApi.ENABLED`，关着时 main.gd 根本不会建这个面板。

const WorkshopApiScript := preload("res://scripts/game/workshop_api.gd")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

signal play_requested(pack: Dictionary, id: String)
signal closed

const FONT_TITLE := 44
const FONT_HEADING := 30
const FONT_BODY := 24
const FONT_NOTE := 20
const FONT_BUTTON := 24

const COLOR_BG := Color(0.07, 0.10, 0.07, 0.94)
const COLOR_PANEL := Color("1c281be8")
const COLOR_SLOT := Color("16200f")
const COLOR_SLOT_EDGE := Color("3d4a33")
const COLOR_BORDER := Color("d7c073")
const COLOR_INK := Color("e8efd8")
const COLOR_MUTED := Color("95a487")
const COLOR_TITLE := Color("ffd768")
const COLOR_DANGER := Color("ff8a6a")
const COLOR_SUCCESS := Color("a6e26b")
const COLOR_LIKE := Color("ff9aa2")

var _dim: ColorRect
var _page: Control
var _status: Label
var _list_box: VBoxContainer
var _new_button: Button
var _hot_button: Button
var _refresh_button: Button
var _close_button: Button
var _http: HTTPRequest

var _sort := WorkshopApiScript.SORT_NEW
var _items: Array = []
var _rows: Array = []
var _busy := false
var _session := 0
var _pending_motion: Array = []


func _ready() -> void:
	layer = 155
	add_to_group("modal_overlay")
	visible = false
	_http = HTTPRequest.new()
	_http.name = "WorkshopHttp"
	_http.timeout = WorkshopApiScript.REQUEST_TIMEOUT_SEC
	add_child(_http)
	_build()


## ---- 对外 ----

func present() -> void:
	visible = true
	_dim.modulate.a = 0.0
	_page.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.16)
	tween.tween_property(_page, "modulate:a", 1.0, 0.2)
	_reload()


func dismiss() -> void:
	_session += 1
	_busy = false
	if _http != null and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http.cancel_request()
	visible = false


func is_open() -> bool:
	return visible


## ---- 数据 ----

func _reload() -> void:
	if _busy:
		return
	_busy = true
	_session += 1
	var token := _session
	_status.text = "加载中…"
	_status.add_theme_color_override("font_color", COLOR_MUTED)
	var result := await WorkshopApiScript.fetch_list(_http, _sort)
	_busy = false
	if token != _session or not visible:
		return
	if not bool(result.get("ok", false)):
		_items = []
		_rebuild_rows()
		_status.text = "连不上创意工坊服务器。"
		_status.add_theme_color_override("font_color", COLOR_DANGER)
		return
	_items = result.get("items", [])
	_rebuild_rows()
	if _items.is_empty():
		_status.text = "还没有人发布关卡包。"
		_status.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		_status.text = "共 %d 个关卡包 · 按%s排列" % [
			int(result.get("total", _items.size())),
			"点赞" if _sort == WorkshopApiScript.SORT_LIKES else "时间",
		]
		_status.add_theme_color_override("font_color", COLOR_SUCCESS)


func _set_sort(sort: String) -> void:
	if _sort == sort:
		return
	_sort = sort
	_refresh_sort_buttons()
	_reload()


func _refresh_sort_buttons() -> void:
	var hot := _sort == WorkshopApiScript.SORT_LIKES
	_new_button.add_theme_color_override("font_color", COLOR_MUTED if hot else COLOR_TITLE)
	_hot_button.add_theme_color_override("font_color", COLOR_TITLE if hot else COLOR_MUTED)


func _on_like_pressed(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	var id := String(item.get("id", ""))
	if id.is_empty():
		return
	var result := await WorkshopApiScript.toggle_like(_http, id)
	if not bool(result.get("ok", false)):
		_status.text = "点赞失败，检查一下网络。"
		_status.add_theme_color_override("font_color", COLOR_DANGER)
		return
	item["likes"] = int(result.get("likes", item.get("likes", 0)))
	if index < _rows.size():
		_apply_row(index)


func _on_play_pressed(index: int) -> void:
	if _busy or index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	var id := String(item.get("id", ""))
	_busy = true
	_status.text = "正在下载「%s」…" % String(item.get("name", ""))
	_status.add_theme_color_override("font_color", COLOR_MUTED)
	var result := await WorkshopApiScript.fetch_item(_http, id)
	_busy = false
	if not bool(result.get("ok", false)):
		_status.text = "下载失败，检查一下网络。"
		_status.add_theme_color_override("font_color", COLOR_DANGER)
		return
	var payload: Dictionary = result.get("item", {})
	var parsed := CustomLevel.from_json(JSON.stringify(payload.get("data", {})))
	if not bool(parsed["ok"]):
		_status.text = "这个关卡包读不出来：" + String(parsed["error"])
		_status.add_theme_color_override("font_color", COLOR_DANGER)
		return
	dismiss()
	play_requested.emit(parsed["level"], id)


## ---- 列表渲染 ----

func _rebuild_rows() -> void:
	for row in _rows:
		(row["panel"] as Node).queue_free()
	_rows.clear()
	for index in _items.size():
		_rows.append(_make_row(index))
		_apply_row(index)


func _apply_row(index: int) -> void:
	var item: Dictionary = _items[index]
	var row: Dictionary = _rows[index]
	(row["name"] as Label).text = String(item.get("name", "未命名"))
	(row["author"] as Label).text = "作者 %s" % String(item.get("author", "匿名"))
	var maps := int(item.get("maps", 1))
	(row["detail"] as Label).text = "%d 张图 · 共 %d 雷 · 玩过 %d 次" % [
		maps, int(item.get("mines_total", 0)), int(item.get("plays", 0))
	]
	var preview: Dictionary = item.get("preview", {})
	(row["thumb"] as Thumb).set_preview(
		String(preview.get("cells", "")), int(preview.get("w", 0)), int(preview.get("h", 0))
	)
	var liked := WorkshopApiScript.has_liked(String(item.get("id", "")))
	var like_button := row["like"] as Button
	like_button.text = "%s %d" % ["♥" if liked else "♡", int(item.get("likes", 0))]
	like_button.add_theme_color_override("font_color", COLOR_LIKE if liked else COLOR_MUTED)


func _make_row(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "WorkshopRow%d" % index
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT
	style.border_color = COLOR_SLOT_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	_list_box.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var thumb := Thumb.new()
	thumb.custom_minimum_size = Vector2(124, 92)
	row.add_child(thumb)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 2)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_column)
	var name_label := _make_label("", FONT_HEADING, COLOR_INK)
	text_column.add_child(name_label)
	var author_label := _make_label("", FONT_BODY, COLOR_MUTED)
	text_column.add_child(author_label)
	var detail_label := _make_label("", FONT_NOTE, COLOR_MUTED)
	text_column.add_child(detail_label)

	var captured := index
	var like_button := _make_button("Like%d" % index, "♡ 0", Vector2(128, 58), -0.5)
	like_button.pressed.connect(func() -> void: _on_like_pressed(captured))
	row.add_child(like_button)

	var play_button := _make_button("Play%d" % index, "开玩", Vector2(140, 58), 0.8)
	play_button.pressed.connect(func() -> void: _on_play_pressed(captured))
	row.add_child(play_button)

	for entry in _pending_motion:
		ButtonMotion.bind(entry[0] as Button, entry[0] as Button, float(entry[1]))
	_pending_motion.clear()

	return {
		"panel": panel,
		"thumb": thumb,
		"name": name_label,
		"author": author_label,
		"detail": detail_label,
		"like": like_button,
		"play": play_button,
	}


## ---- 搭界面 ----

func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = COLOR_BG
	add_child(_dim)

	_page = MarginContainer.new()
	_page.name = "Page"
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_page.add_theme_constant_override("margin_" + side, 120)
	_page.add_theme_constant_override("margin_top", 40)
	_page.add_theme_constant_override("margin_bottom", 40)
	add_child(_page)

	var panel := PanelContainer.new()
	panel.name = "Frame"
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	_page.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	stack.add_child(header)
	var title := _make_label("创意工坊", FONT_TITLE, COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", Color("2a1a08"))
	title.add_theme_constant_override("outline_size", 6)
	header.add_child(title)

	_new_button = _make_button("SortNew", "最新", Vector2(130, 54), 0.5)
	_new_button.pressed.connect(func() -> void: _set_sort(WorkshopApiScript.SORT_NEW))
	header.add_child(_new_button)
	_hot_button = _make_button("SortHot", "最热", Vector2(130, 54), -0.5)
	_hot_button.pressed.connect(func() -> void: _set_sort(WorkshopApiScript.SORT_LIKES))
	header.add_child(_hot_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_refresh_button = _make_button("RefreshButton", "刷新", Vector2(130, 54), 0.6)
	_refresh_button.pressed.connect(func() -> void: _reload())
	header.add_child(_refresh_button)
	_close_button = _make_button("CloseButton", "关闭", Vector2(150, 54), -0.8)
	_close_button.pressed.connect(func() -> void:
		dismiss()
		closed.emit()
	)
	header.add_child(_close_button)

	_status = _make_label("", FONT_BODY, COLOR_MUTED, true)
	stack.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "List"
	_list_box.add_theme_constant_override("separation", 10)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_box)

	for entry in _pending_motion:
		ButtonMotion.bind(entry[0] as Button, entry[0] as Button, float(entry[1]))
	_pending_motion.clear()
	_refresh_sort_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		dismiss()
		closed.emit()
		get_viewport().set_input_as_handled()


func _make_label(text: String, size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(node_name: String, text: String, minimum: Vector2, motion_bias: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pending_motion.append([button, motion_bias])
	return button


## 列表里的缩略图。服务端给的是第一张图的 `"0110…"` 字符串，和编辑器那份
## PackedByteArray 不同源，所以这里单独画，不去复用编辑器的内部类。
class Thumb:
	extends Control

	const COLOR_ON := Color("6f9a3c")
	const COLOR_OFF := Color("222a1d")

	var _cells := ""
	var _width := 0
	var _height := 0


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func set_preview(cells: String, width: int, height: int) -> void:
		_cells = cells
		_width = width
		_height = height
		queue_redraw()


	func _draw() -> void:
		if _width <= 0 or _height <= 0 or _cells.length() < _width * _height:
			return
		var px := minf(size.x / float(_width), size.y / float(_height))
		if px <= 0.0:
			return
		var origin := (size - Vector2(_width, _height) * px) * 0.5
		var inset := maxf(px * 0.08, 0.5)
		for y in _height:
			for x in _width:
				var rect := Rect2(origin + Vector2(x, y) * px, Vector2(px, px)).grow(-inset)
				draw_rect(rect, COLOR_ON if _cells[y * _width + x] == "1" else COLOR_OFF)
