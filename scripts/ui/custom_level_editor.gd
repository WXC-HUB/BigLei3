class_name CustomLevelEditor
extends CanvasLayer
## 自定义关卡包的编辑界面，三栏：
##   左   地图列表——一个包可以放多张图，玩家按顺序连着打，图与图之间进商店
##   中   画当前这张图（左键拖矩形填、右键拖矩形擦）＋ 这张图的尺寸与雷数
##   右   整包共用的**初始道具**、导入导出、开局、发布到创意工坊
##
## 一局打完后同一层再弹结果卡：再来一局 / 返回编辑 / 回标题。棋盘本身不归这里管，
## 这里只发信号，GameFlow（main.gd）负责真正开盘和拆盘。

signal play_requested(level: Dictionary)
signal back_requested
signal replay_requested
signal edit_requested
signal exit_requested
signal publish_requested(pack: Dictionary, author: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const WorkshopApiScript := preload("res://scripts/game/workshop_api.gd")

const ITEM_TEXTURES := {
	"lantern": preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	"compass": preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	"orbital_strike": preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	"super_luck": preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
	"medical_kit": preload("res://assets/sprites/generated/bird_items/item_bird_dove.png"),
	"xray": preload("res://assets/sprites/generated/bird_items/item_bird_crow.png"),
	"chain": preload("res://assets/sprites/generated/bird_items/item_bird_magpie.png"),
	"enlarge": preload("res://assets/sprites/generated/bird_items/item_bird_tit.png"),
	"detect": preload("res://assets/sprites/generated/tool_metal_detector.png"),
}

## 字号统一从这里取：整屏是给 1920×1080 看的，小字在实机上会糊成一团。
const FONT_TITLE := 48
const FONT_HEADING := 32
const FONT_BODY := 26
const FONT_NOTE := 22
const FONT_BUTTON := 28
const FONT_STEPPER_VALUE := 30
const FONT_STEPPER_SIGN := 34
const STEPPER_BUTTON := Vector2(56, 52)
const STEPPER_VALUE_WIDTH := 84.0

const COLOR_BG := Color(0.07, 0.10, 0.07, 0.94)
const COLOR_RESULT_SHADE := Color(0.04, 0.05, 0.04, 0.5)
const COLOR_PANEL := Color("1c281be8")
const COLOR_BORDER := Color("d7c073")
const COLOR_INK := Color("e8efd8")
const COLOR_MUTED := Color("b7c4a8")
const COLOR_TITLE := Color("ffd768")
const COLOR_DANGER := Color("ff8a6a")
const COLOR_SUCCESS := Color("a6e26b")
const COLOR_SLOT := Color("16200f")
const COLOR_SLOT_EDGE := Color("3d4a33")
const COLOR_SLOT_ON := Color("2b3a1e")

const MAP_LIST_WIDTH := 268.0

## Web 端导入：让浏览器弹文件框，读到文本后挂在 window 上，GDScript 这边轮询取走。
## 不走 JS 回调是因为回调在导出后偶发丢包，轮询一个全局量最稳。
const WEB_IMPORT_JS := """
(function () {
	window.__biglei_custom_import = null;
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = '.json,application/json';
	input.style.display = 'none';
	input.onchange = function () {
		var file = input.files && input.files[0];
		if (!file) { return; }
		var reader = new FileReader();
		reader.onload = function () { window.__biglei_custom_import = String(reader.result); };
		reader.readAsText(file);
	};
	document.body.appendChild(input);
	input.click();
	setTimeout(function () { if (input.parentNode) { input.parentNode.removeChild(input); } }, 60000);
})();
"""
const WEB_IMPORT_POLL_SECONDS := 0.25

var _level: Dictionary = CustomLevel.make_default()
var _map_index := 0

var _dim: ColorRect
var _page: Control
var _grid: PaintGrid
var _name_input: LineEdit
var _width_spin: Stepper
var _height_spin: Stepper
var _mines_spin: Stepper
var _item_spins: Dictionary = {} ## key -> Stepper
var _summary_label: Label
var _error_label: Label
var _play_button: Button
var _export_button: Button
var _import_button: Button
var _publish_button: Button
var _back_button: Button
var _fill_button: Button
var _clear_button: Button

var _map_list_box: VBoxContainer
var _map_rows: Array = []
var _map_count_label: Label
var _add_map_button: Button
var _delete_map_button: Button
var _move_up_button: Button
var _move_down_button: Button

var _name_dialog: Control
var _name_dialog_input: LineEdit
var _name_dialog_confirm: Button
var _name_dialog_cancel: Button

var _publish_dialog: Control
var _publish_name_input: LineEdit
var _publish_author_input: LineEdit
var _publish_confirm: Button
var _publish_cancel: Button
var _publish_note: Label

var _result_card: Control
var _result_title: Label
var _result_body: Label
var _replay_button: Button
var _edit_button: Button
var _exit_button: Button

var _save_dialog: FileDialog
var _open_dialog: FileDialog
var _web_import_pending := false
var _web_import_clock := 0.0
var _syncing := false
var _pending_motion: Array = []


func _ready() -> void:
	layer = 160
	visible = false
	_build()
	_apply_level_to_controls()


func _process(delta: float) -> void:
	if not _web_import_pending or not visible:
		return
	_web_import_clock += delta
	if _web_import_clock < WEB_IMPORT_POLL_SECONDS:
		return
	_web_import_clock = 0.0
	var payload = JavaScriptBridge.eval("window.__biglei_custom_import", true)
	if payload is String and not (payload as String).is_empty():
		JavaScriptBridge.eval("window.__biglei_custom_import = null;", true)
		_web_import_pending = false
		import_text(payload)


## ---- 对外 ----

func present() -> void:
	_result_card.visible = false
	_name_dialog.visible = false
	_publish_dialog.visible = false
	_page.visible = true
	visible = true
	_apply_level_to_controls()
	_dim.color = COLOR_BG
	_dim.modulate.a = 0.0
	_page.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.16)
	tween.tween_property(_page, "modulate:a", 1.0, 0.2)


func dismiss() -> void:
	visible = false
	_result_card.visible = false
	_name_dialog.visible = false
	_publish_dialog.visible = false
	_web_import_pending = false


func is_open() -> bool:
	return visible


func current_level() -> Dictionary:
	return _level.duplicate(true)


func load_level(level: Dictionary) -> void:
	_level = level.duplicate(true)
	_map_index = 0
	_apply_level_to_controls()


## 当前正在编辑的那张图（给测试和调用方看的）。
func current_map_index() -> int:
	return _map_index


## 一局结束：结果卡盖在棋盘上，编辑页不出现。
## `map_index` / `map_total` 是 1 基的进度，用来在多图包里说明打到第几张。
func present_result(
	won: bool, flagged: int, mines: int, map_index: int = 1, map_total: int = 1
) -> void:
	_page.visible = false
	_name_dialog.visible = false
	_publish_dialog.visible = false
	visible = true
	# 结果卡下面要能看见打完的棋盘，遮罩比编辑页浅得多。
	_dim.color = COLOR_RESULT_SHADE
	_dim.modulate.a = 1.0
	var all_clear := won and map_index >= map_total
	if all_clear:
		_result_title.text = "通关！" if map_total > 1 else "清扫完成！"
	else:
		_result_title.text = "踩雷了"
	_result_title.add_theme_color_override("font_color", COLOR_SUCCESS if all_clear else COLOR_DANGER)
	var progress := ""
	if map_total > 1:
		progress = " · 第 %d/%d 张" % [map_index, map_total]
	_result_body.text = "「%s」%s · 标出 %d / %d 枚雷" % [
		String(_level.get("name", CustomLevel.DEFAULT_NAME)), progress, flagged, mines
	]
	_result_card.visible = true
	_result_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_result_card, "modulate:a", 1.0, 0.2)


func import_text(text: String) -> bool:
	var result := CustomLevel.from_json(text)
	if not bool(result["ok"]):
		var level: Dictionary = result["level"]
		# 形状读得出来但数值不合法：还是装进编辑器，让玩家在原图上改，别把人家的图丢了。
		if not level.is_empty():
			load_level(level)
		_error_label.text = "导入失败：" + String(result["error"])
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return false
	load_level(result["level"])
	var count := CustomLevel.map_count(_level)
	_error_label.text = "已导入「%s」%s" % [
		String(_level["name"]), ("· %d 张图" % count) if count > 1 else ""
	]
	_error_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	return true


func export_text() -> String:
	return CustomLevel.to_json(_level)


## 发布结果由 main.gd 回填，编辑器只负责显示。
func set_publish_status(message: String, ok: bool) -> void:
	if _publish_note != null and _publish_dialog.visible:
		_publish_note.text = message
		_publish_note.add_theme_color_override("font_color", COLOR_SUCCESS if ok else COLOR_DANGER)
	_error_label.text = message
	_error_label.add_theme_color_override("font_color", COLOR_SUCCESS if ok else COLOR_DANGER)
	if ok:
		_publish_dialog.visible = false


## ---- 事件 ----

func _on_play_pressed() -> void:
	_pull_level_from_controls()
	var errors := CustomLevel.validate(_level)
	if not errors.is_empty():
		_show_errors(errors)
		return
	play_requested.emit(current_level())


func _on_export_pressed() -> void:
	_pull_level_from_controls()
	var errors := CustomLevel.validate(_level)
	if not errors.is_empty():
		_show_errors(errors)
		return
	_name_dialog_input.text = String(_level.get("name", CustomLevel.DEFAULT_NAME))
	_name_dialog.visible = true
	_name_dialog_input.grab_focus()
	_name_dialog_input.select_all()


func _on_name_dialog_confirmed() -> void:
	var name := CustomLevel.sanitize_name(_name_dialog_input.text)
	_level["name"] = name
	_name_input.text = name
	_name_dialog.visible = false
	_export_level(name)


func _on_name_dialog_cancelled() -> void:
	_name_dialog.visible = false


func _export_level(name: String) -> void:
	var text := export_text()
	var file_name := CustomLevel.sanitize_name(name) + ".json"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		_error_label.text = "已导出 %s" % file_name
		_error_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		return
	_save_dialog.current_file = file_name
	_save_dialog.popup_centered_ratio(0.7)


func _on_save_path_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error_label.text = "写不进 %s" % path
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return
	file.store_string(export_text())
	file.close()
	_error_label.text = "已导出到 %s" % path
	_error_label.add_theme_color_override("font_color", COLOR_SUCCESS)


func _on_import_pressed() -> void:
	if OS.has_feature("web"):
		_web_import_pending = true
		_web_import_clock = 0.0
		JavaScriptBridge.eval(WEB_IMPORT_JS, true)
		return
	_open_dialog.popup_centered_ratio(0.7)


func _on_open_path_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_error_label.text = "读不到 %s" % path
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return
	var text := file.get_as_text()
	file.close()
	import_text(text)


func _on_publish_pressed() -> void:
	_pull_level_from_controls()
	var errors := CustomLevel.validate(_level)
	if not errors.is_empty():
		_show_errors(errors)
		return
	_publish_name_input.text = WorkshopApiScript.normalize_name(
		String(_level.get("name", CustomLevel.DEFAULT_NAME))
	)
	_publish_note.text = "发布后所有人都能看到并下载这个关卡包。"
	_publish_note.add_theme_color_override("font_color", COLOR_MUTED)
	_publish_dialog.visible = true
	_publish_author_input.grab_focus()


func _on_publish_confirmed() -> void:
	var pack_name := WorkshopApiScript.normalize_name(_publish_name_input.text)
	if pack_name.is_empty():
		_publish_note.text = "请先填写关卡包名称。"
		_publish_note.add_theme_color_override("font_color", COLOR_DANGER)
		return
	_level["name"] = pack_name
	_name_input.text = pack_name
	_publish_note.text = "正在发布…"
	_publish_note.add_theme_color_override("font_color", COLOR_TITLE)
	publish_requested.emit(current_level(), WorkshopApiScript.normalize_author(_publish_author_input.text))


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_size_changed(_value: float) -> void:
	if _syncing:
		return
	_grid.set_dimensions(int(_width_spin.value), int(_height_spin.value))
	_pull_level_from_controls()
	_refresh_summary()
	_refresh_map_list()


func _on_mask_changed() -> void:
	if _syncing:
		return
	_pull_level_from_controls()
	_refresh_summary()
	_refresh_map_list()


func _on_number_changed(_value: float) -> void:
	if _syncing:
		return
	_pull_level_from_controls()
	_refresh_summary()
	_refresh_map_list()


## ---- 地图列表 ----

func _select_map(index: int) -> void:
	var count := CustomLevel.map_count(_level)
	if count <= 0:
		return
	var next := clampi(index, 0, count - 1)
	if next == _map_index:
		return
	_pull_level_from_controls()
	_map_index = next
	_apply_level_to_controls()


func _on_add_map_pressed() -> void:
	_pull_level_from_controls()
	var maps: Array = CustomLevel.maps_of(_level)
	if maps.size() >= CustomLevel.MAX_MAPS:
		_error_label.text = "一个关卡包最多 %d 张图" % CustomLevel.MAX_MAPS
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return
	# 新图照抄当前这张的尺寸：作者多半在做同一套盘面的变体，从零开始反而费事。
	var current := CustomLevel.map_at(_level, _map_index)
	var width := int(current.get("width", 8)) if not current.is_empty() else 8
	var height := int(current.get("height", 6)) if not current.is_empty() else 6
	maps.insert(_map_index + 1, CustomLevel.make_map(width, height, 1))
	_level["maps"] = maps
	_map_index += 1
	_apply_level_to_controls()


func _on_delete_map_pressed() -> void:
	var maps: Array = CustomLevel.maps_of(_level)
	if maps.size() <= 1:
		_error_label.text = "至少要留 1 张图"
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return
	maps.remove_at(_map_index)
	_level["maps"] = maps
	_map_index = clampi(_map_index, 0, maps.size() - 1)
	_apply_level_to_controls()


func _on_move_map(delta: int) -> void:
	_pull_level_from_controls()
	var maps: Array = CustomLevel.maps_of(_level)
	var target := _map_index + delta
	if target < 0 or target >= maps.size():
		return
	var moved = maps[_map_index]
	maps[_map_index] = maps[target]
	maps[target] = moved
	_level["maps"] = maps
	_map_index = target
	_apply_level_to_controls()


func _refresh_map_list() -> void:
	if _map_list_box == null:
		return
	var maps := CustomLevel.maps_of(_level)
	# 数量对不上就整列重建；只是内容变了就地刷新，免得每次落笔都重搭一串节点。
	if _map_rows.size() != maps.size():
		for row in _map_rows:
			(row["panel"] as Node).queue_free()
		_map_rows.clear()
		for index in maps.size():
			_map_rows.append(_make_map_row(index))
	for index in maps.size():
		var map_data: Dictionary = maps[index]
		var row: Dictionary = _map_rows[index]
		var selected := index == _map_index
		(row["index"] as Label).text = str(index + 1)
		(row["index"] as Label).add_theme_color_override(
			"font_color", COLOR_TITLE if selected else COLOR_MUTED
		)
		(row["size"] as Label).text = "%d×%d" % [
			int(map_data.get("width", 0)), int(map_data.get("height", 0))
		]
		(row["detail"] as Label).text = "%d 雷 · %d 格" % [
			int(map_data.get("mines", 0)), CustomLevel.active_count(map_data)
		]
		var mini := row["mini"] as MiniMap
		mini.set_map(
			map_data.get("mask", PackedByteArray()),
			int(map_data.get("width", 0)),
			int(map_data.get("height", 0))
		)
		var style := (row["panel"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = COLOR_SLOT_ON if selected else COLOR_SLOT
		style.border_color = COLOR_BORDER if selected else COLOR_SLOT_EDGE
		(row["panel"] as PanelContainer).queue_redraw()
	_map_count_label.text = "共 %d 张 · 上限 %d" % [maps.size(), CustomLevel.MAX_MAPS]
	_delete_map_button.disabled = maps.size() <= 1
	_add_map_button.disabled = maps.size() >= CustomLevel.MAX_MAPS
	_move_up_button.disabled = _map_index <= 0
	_move_down_button.disabled = _map_index >= maps.size() - 1


func _make_map_row(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "MapRow%d" % index
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT
	style.border_color = COLOR_SLOT_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var captured := index
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_select_map(captured)
	)
	_map_list_box.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var index_label := _make_label(str(index + 1), FONT_HEADING, COLOR_MUTED)
	index_label.custom_minimum_size = Vector2(30, 0)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(index_label)

	var mini := MiniMap.new()
	mini.custom_minimum_size = Vector2(76, 58)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mini)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 0)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)
	var size_label := _make_label("", FONT_BODY, COLOR_INK)
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(size_label)
	var detail_label := _make_label("", FONT_NOTE, COLOR_MUTED)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(detail_label)

	return {
		"panel": panel,
		"index": index_label,
		"mini": mini,
		"size": size_label,
		"detail": detail_label,
	}


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _publish_dialog.visible:
			_publish_dialog.visible = false
			get_viewport().set_input_as_handled()
		elif _name_dialog.visible:
			_on_name_dialog_cancelled()
			get_viewport().set_input_as_handled()


## ---- 数据 <-> 控件 ----

func _apply_level_to_controls() -> void:
	if _grid == null:
		return
	if CustomLevel.map_count(_level) <= 0:
		_level["maps"] = [CustomLevel.make_map()]
		_map_index = 0
	_map_index = clampi(_map_index, 0, CustomLevel.map_count(_level) - 1)
	var map_data := CustomLevel.map_at(_level, _map_index)
	_syncing = true
	_name_input.text = String(_level.get("name", CustomLevel.DEFAULT_NAME))
	_width_spin.value = int(map_data.get("width", 8))
	_height_spin.value = int(map_data.get("height", 6))
	_grid.set_dimensions(int(map_data.get("width", 8)), int(map_data.get("height", 6)))
	_grid.set_mask(map_data.get("mask", PackedByteArray()))
	_mines_spin.value = int(map_data.get("mines", 1))
	for key in CustomLevel.ITEM_KEYS:
		(_item_spins[key] as Stepper).value = CustomLevel.item_count(_level, key)
	_syncing = false
	_refresh_map_list()
	_refresh_summary()


func _pull_level_from_controls() -> void:
	_level["name"] = _name_input.text.strip_edges() if not _name_input.text.strip_edges().is_empty() else CustomLevel.DEFAULT_NAME
	var maps: Array = CustomLevel.maps_of(_level)
	if maps.is_empty():
		maps = [CustomLevel.make_map()]
		_map_index = 0
	_map_index = clampi(_map_index, 0, maps.size() - 1)
	maps[_map_index] = {
		"width": _grid.width,
		"height": _grid.height,
		"mask": _grid.mask.duplicate(),
		"mines": int(_mines_spin.value),
	}
	_level["maps"] = maps
	var items := {}
	for key in CustomLevel.ITEM_KEYS:
		items[key] = int((_item_spins[key] as Stepper).value)
	_level["items"] = items


func _refresh_summary() -> void:
	var map_data := CustomLevel.map_at(_level, _map_index)
	var active := CustomLevel.active_count(map_data)
	var ceiling := CustomLevel.max_mines(map_data)
	var total_maps := CustomLevel.map_count(_level)
	_summary_label.text = "第 %d/%d 张 · 可玩格 %d · 雷上限 %d" % [
		_map_index + 1, total_maps, active, ceiling
	]
	var errors := CustomLevel.validate(_level)
	if not errors.is_empty():
		_error_label.text = errors[0]
		_error_label.add_theme_color_override("font_color", COLOR_DANGER)
		return
	var notes := CustomLevel.warnings(_level)
	if notes.is_empty():
		var suffix := "，共 %d 张图" % total_maps if total_maps > 1 else ""
		_error_label.text = "配置合法，可以开局" + suffix
		_error_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	else:
		_error_label.text = "可以开局；" + notes[0]
		_error_label.add_theme_color_override("font_color", COLOR_TITLE)


func _show_errors(errors: PackedStringArray) -> void:
	_error_label.text = "\n".join(errors)
	_error_label.add_theme_color_override("font_color", COLOR_DANGER)


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
		_page.add_theme_constant_override("margin_" + side, 36)
	_page.add_theme_constant_override("margin_top", 24)
	_page.add_theme_constant_override("margin_bottom", 24)
	add_child(_page)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_page.add_child(column)

	column.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_map_list_panel())
	body.add_child(_build_map_panel())
	body.add_child(_build_config_panel())

	_build_name_dialog()
	_build_publish_dialog()
	_build_result_card()
	_build_file_dialogs()
	for entry in _pending_motion:
		ButtonMotion.bind(entry[0] as Button, entry[0] as Button, float(entry[1]))
	_pending_motion.clear()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var title := _make_label("自定义关卡", FONT_TITLE, COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", Color("2a1a08"))
	title.add_theme_constant_override("outline_size", 6)
	row.add_child(title)

	var name_caption := _make_label("关卡包名", FONT_BODY, COLOR_MUTED)
	name_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_caption)
	_name_input = LineEdit.new()
	_name_input.name = "NameInput"
	_name_input.placeholder_text = CustomLevel.DEFAULT_NAME
	_name_input.max_length = 40
	_name_input.custom_minimum_size = Vector2(360, 56)
	_name_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_input.add_theme_font_size_override("font_size", FONT_BODY)
	_name_input.text_changed.connect(func(_t: String) -> void: _pull_level_from_controls())
	row.add_child(_name_input)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_back_button = _make_button("BackButton", "返回标题", Vector2(200, 58), -0.8)
	_back_button.pressed.connect(_on_back_pressed)
	row.add_child(_back_button)
	return row


## 左栏：地图列表。多图时玩家按顺序连着打，中间进商店。
func _build_map_list_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MapListPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(MAP_LIST_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)

	stack.add_child(_make_label("地图列表", FONT_HEADING, COLOR_TITLE))
	_map_count_label = _make_label("", FONT_NOTE, COLOR_MUTED)
	stack.add_child(_map_count_label)

	var scroll := ScrollContainer.new()
	scroll.name = "MapScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)

	_map_list_box = VBoxContainer.new()
	_map_list_box.name = "MapList"
	_map_list_box.add_theme_constant_override("separation", 8)
	_map_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_list_box)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	stack.add_child(add_row)
	_add_map_button = _make_button("AddMapButton", "添加", Vector2(0, 54), 0.7, FONT_BODY)
	_add_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_map_button.pressed.connect(_on_add_map_pressed)
	add_row.add_child(_add_map_button)
	_delete_map_button = _make_button("DeleteMapButton", "删除", Vector2(0, 54), -0.7, FONT_BODY)
	_delete_map_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_map_button.pressed.connect(_on_delete_map_pressed)
	add_row.add_child(_delete_map_button)

	var move_row := HBoxContainer.new()
	move_row.add_theme_constant_override("separation", 8)
	stack.add_child(move_row)
	_move_up_button = _make_button("MoveUpButton", "上移", Vector2(0, 50), 0.5, FONT_NOTE)
	_move_up_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_up_button.pressed.connect(func() -> void: _on_move_map(-1))
	move_row.add_child(_move_up_button)
	_move_down_button = _make_button("MoveDownButton", "下移", Vector2(0, 50), -0.5, FONT_NOTE)
	_move_down_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_down_button.pressed.connect(func() -> void: _on_move_map(1))
	move_row.add_child(_move_down_button)

	var hint := _make_label("多张图会按顺序连着打，每打完一张进一次商店。", FONT_NOTE, COLOR_MUTED, true)
	stack.add_child(hint)
	return panel


func _build_map_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "MapPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 12)
	stack.add_child(size_row)
	size_row.add_child(_make_label("宽", FONT_BODY, COLOR_MUTED))
	_width_spin = _make_spin("WidthSpin", CustomLevel.MIN_SIZE, CustomLevel.MAX_WIDTH)
	_width_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(_width_spin)
	var size_gap := Control.new()
	size_gap.custom_minimum_size = Vector2(10, 0)
	size_row.add_child(size_gap)
	size_row.add_child(_make_label("高", FONT_BODY, COLOR_MUTED))
	_height_spin = _make_spin("HeightSpin", CustomLevel.MIN_SIZE, CustomLevel.MAX_HEIGHT)
	_height_spin.value_changed.connect(_on_size_changed)
	size_row.add_child(_height_spin)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(gap)
	_fill_button = _make_button("FillButton", "全部填满", Vector2(150, 52), 0.6)
	_fill_button.pressed.connect(func() -> void:
		_grid.fill_all(1)
	)
	size_row.add_child(_fill_button)
	_clear_button = _make_button("ClearButton", "全部清空", Vector2(150, 52), -0.6)
	_clear_button.pressed.connect(func() -> void:
		_grid.fill_all(0)
	)
	size_row.add_child(_clear_button)

	# 雷数单独一行：和宽高挤在一行会把中栏撑到 1100 多，右栏就被推出 1920 之外。
	var mines_row := HBoxContainer.new()
	mines_row.add_theme_constant_override("separation", 12)
	stack.add_child(mines_row)
	var mine_icon := TextureRect.new()
	mine_icon.texture = preload("res://my_asset/monster_small.png")
	mine_icon.custom_minimum_size = Vector2(46, 46)
	mine_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mine_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mine_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mines_row.add_child(mine_icon)
	mines_row.add_child(_make_label("雷数", FONT_BODY, COLOR_MUTED))
	_mines_spin = _make_spin("MinesSpin", 1, CustomLevel.MAX_WIDTH * CustomLevel.MAX_HEIGHT)
	_mines_spin.value_changed.connect(_on_number_changed)
	mines_row.add_child(_mines_spin)
	_summary_label = _make_label("", FONT_NOTE, COLOR_MUTED, true)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mines_row.add_child(_summary_label)

	_grid = PaintGrid.new()
	_grid.name = "PaintGrid"
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.custom_minimum_size = Vector2(620, 480)
	_grid.mask_changed.connect(_on_mask_changed)
	stack.add_child(_grid)

	var hint := _make_label("左键点击/拖出矩形 = 画可玩格　右键 = 擦掉　点在已画的格子上再拖 = 擦", FONT_NOTE, COLOR_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)
	return panel


## 右栏：整包共用的初始道具 + 出入口。雷数跟着地图走，所以留在中栏。
func _build_config_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ConfigPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)

	stack.add_child(_make_label("初始道具", FONT_HEADING, COLOR_TITLE))
	stack.add_child(_make_label(
		"整包共用：每一张图上都会埋这么多张牌。地图之间的商店买到的加成会叠在上面。",
		FONT_NOTE, COLOR_MUTED, true
	))
	stack.add_child(HSeparator.new())

	for key in CustomLevel.ITEM_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := TextureRect.new()
		icon.texture = ITEM_TEXTURES[key]
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var caption := _make_label(String(CustomLevel.ITEM_NAMES[key]), FONT_BODY, COLOR_INK)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(caption)
		var spin := _make_spin("Spin_" + key, 0, CustomLevel.MAX_ITEM_COUNT)
		spin.value_changed.connect(_on_number_changed)
		row.add_child(spin)
		_item_spins[key] = spin
		stack.add_child(row)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(filler)

	_error_label = _make_label("", FONT_NOTE, COLOR_SUCCESS, true)
	_error_label.custom_minimum_size = Vector2(0, 60)
	stack.add_child(_error_label)

	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 12)
	stack.add_child(io_row)
	_import_button = _make_button("ImportButton", "导入 JSON", Vector2(0, 56), -0.6)
	_import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_button.pressed.connect(_on_import_pressed)
	io_row.add_child(_import_button)
	_export_button = _make_button("ExportButton", "导出 JSON", Vector2(0, 56), 0.6)
	_export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_button.pressed.connect(_on_export_pressed)
	io_row.add_child(_export_button)

	# 创意工坊没开时整颗按钮不出现，免得玩家点了发现没反应。
	_publish_button = _make_button("PublishButton", "发布到创意工坊", Vector2(0, 56), 0.8)
	_publish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_publish_button.visible = WorkshopApiScript.ENABLED
	_publish_button.pressed.connect(_on_publish_pressed)
	stack.add_child(_publish_button)

	_play_button = _make_button("PlayButton", "开局", Vector2(0, 72), 1.0, 38)
	_play_button.pressed.connect(_on_play_pressed)
	stack.add_child(_play_button)
	return panel


func _build_name_dialog() -> void:
	_name_dialog = Control.new()
	_name_dialog.name = "NameDialog"
	_name_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_dialog.visible = false
	add_child(_name_dialog)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.02, 0.6)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_on_name_dialog_cancelled()
	)
	_name_dialog.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_dialog.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	card.add_child(stack)
	stack.add_child(_make_label("导出关卡包", FONT_NOTE, COLOR_MUTED))
	stack.add_child(_make_label("给这个关卡包起个名字", 36, COLOR_TITLE))
	stack.add_child(_make_label("这个名字也是导出的文件名（.json）。", FONT_BODY, COLOR_INK, true))
	_name_dialog_input = LineEdit.new()
	_name_dialog_input.name = "NameDialogInput"
	_name_dialog_input.max_length = 40
	_name_dialog_input.custom_minimum_size = Vector2(0, 60)
	_name_dialog_input.add_theme_font_size_override("font_size", FONT_HEADING)
	_name_dialog_input.text_submitted.connect(func(_t: String) -> void: _on_name_dialog_confirmed())
	stack.add_child(_name_dialog_input)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	_name_dialog_cancel = _make_button("NameDialogCancel", "取消", Vector2(150, 56), -0.8)
	_name_dialog_cancel.pressed.connect(_on_name_dialog_cancelled)
	row.add_child(_name_dialog_cancel)
	_name_dialog_confirm = _make_button("NameDialogConfirm", "导出", Vector2(170, 56), 0.8)
	_name_dialog_confirm.pressed.connect(_on_name_dialog_confirmed)
	row.add_child(_name_dialog_confirm)


func _build_publish_dialog() -> void:
	_publish_dialog = Control.new()
	_publish_dialog.name = "PublishDialog"
	_publish_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_publish_dialog.visible = false
	add_child(_publish_dialog)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.02, 0.6)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_publish_dialog.visible = false
	)
	_publish_dialog.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_publish_dialog.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 0)
	card.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)
	stack.add_child(_make_label("创意工坊", FONT_NOTE, COLOR_MUTED))
	stack.add_child(_make_label("发布这个关卡包", 36, COLOR_TITLE))

	stack.add_child(_make_label("关卡包名称", FONT_BODY, COLOR_MUTED))
	_publish_name_input = LineEdit.new()
	_publish_name_input.name = "PublishNameInput"
	_publish_name_input.max_length = WorkshopApiScript.NAME_MAX
	_publish_name_input.custom_minimum_size = Vector2(0, 56)
	_publish_name_input.add_theme_font_size_override("font_size", FONT_BODY)
	stack.add_child(_publish_name_input)

	stack.add_child(_make_label("作者名（可留空）", FONT_BODY, COLOR_MUTED))
	_publish_author_input = LineEdit.new()
	_publish_author_input.name = "PublishAuthorInput"
	_publish_author_input.max_length = WorkshopApiScript.AUTHOR_MAX
	_publish_author_input.placeholder_text = "匿名"
	_publish_author_input.custom_minimum_size = Vector2(0, 56)
	_publish_author_input.add_theme_font_size_override("font_size", FONT_BODY)
	_publish_author_input.text_submitted.connect(func(_t: String) -> void: _on_publish_confirmed())
	stack.add_child(_publish_author_input)

	_publish_note = _make_label("", FONT_NOTE, COLOR_MUTED, true)
	_publish_note.custom_minimum_size = Vector2(0, 52)
	stack.add_child(_publish_note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	_publish_cancel = _make_button("PublishCancel", "取消", Vector2(150, 56), -0.8)
	_publish_cancel.pressed.connect(func() -> void: _publish_dialog.visible = false)
	row.add_child(_publish_cancel)
	_publish_confirm = _make_button("PublishConfirm", "发布", Vector2(170, 56), 0.8)
	_publish_confirm.pressed.connect(_on_publish_confirmed)
	row.add_child(_publish_confirm)


func _build_result_card() -> void:
	_result_card = CenterContainer.new()
	_result_card.name = "ResultCard"
	_result_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_card.visible = false
	add_child(_result_card)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 0)
	card.add_theme_stylebox_override("panel", _panel_style())
	_result_card.add_child(card)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	card.add_child(stack)
	stack.add_child(_make_label("自定义关卡", FONT_NOTE, COLOR_MUTED))
	_result_title = _make_label("", 48, COLOR_TITLE)
	stack.add_child(_result_title)
	_result_body = _make_label("", FONT_BODY, COLOR_INK, true)
	stack.add_child(_result_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	_replay_button = _make_button("ReplayButton", "再来一局", Vector2(190, 62), 0.9)
	_replay_button.pressed.connect(func() -> void:
		_result_card.visible = false
		replay_requested.emit()
	)
	row.add_child(_replay_button)
	_edit_button = _make_button("EditButton", "返回编辑", Vector2(190, 62), 0.6)
	_edit_button.pressed.connect(func() -> void:
		_result_card.visible = false
		edit_requested.emit()
	)
	row.add_child(_edit_button)
	_exit_button = _make_button("ExitButton", "回标题", Vector2(170, 62), -0.8)
	_exit_button.pressed.connect(func() -> void:
		_result_card.visible = false
		exit_requested.emit()
	)
	row.add_child(_exit_button)


func _build_file_dialogs() -> void:
	_save_dialog = FileDialog.new()
	_save_dialog.name = "SaveDialog"
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.filters = PackedStringArray(["*.json ; 自定义关卡"])
	_save_dialog.use_native_dialog = true
	_save_dialog.title = "导出自定义关卡"
	_save_dialog.file_selected.connect(_on_save_path_selected)
	add_child(_save_dialog)

	_open_dialog = FileDialog.new()
	_open_dialog.name = "OpenDialog"
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.filters = PackedStringArray(["*.json ; 自定义关卡"])
	_open_dialog.use_native_dialog = true
	_open_dialog.title = "导入自定义关卡"
	_open_dialog.file_selected.connect(_on_open_path_selected)
	add_child(_open_dialog)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	return style


## 默认单行不换行：HBox 里带自动换行的标签会被压成一列竖字。只有长句才开 `wrap`。
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


## 「− 数值 +」步进器：两颗大按钮夹着数字，比 SpinBox 那对小箭头好点得多。
## 减号/加号也挂悬停动效，统一在 _build 末尾绑。
func _make_spin(node_name: String, minimum: int, maximum: int) -> Stepper:
	var stepper := Stepper.new(minimum, maximum)
	stepper.name = node_name
	_pending_motion.append([stepper.minus_button, -0.6])
	_pending_motion.append([stepper.plus_button, 0.6])
	return stepper


func _make_button(node_name: String, text: String, minimum: Vector2, motion_bias: float, font_size: int = FONT_BUTTON) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = minimum
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	# 悬停动效要等按钮进了场景树才能挂（它会去拿 get_tree），所以先记下、_build 末尾统一挂。
	_pending_motion.append([button, motion_bias])
	return button


## 地图列表里的缩略图：只画形状，不接鼠标。
class MiniMap:
	extends Control

	const COLOR_ON := Color("6f9a3c")
	const COLOR_OFF := Color("222a1d")

	var _mask := PackedByteArray()
	var _width := 0
	var _height := 0


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func set_map(mask: PackedByteArray, width: int, height: int) -> void:
		_mask = mask.duplicate()
		_width = width
		_height = height
		queue_redraw()


	func _draw() -> void:
		if _width <= 0 or _height <= 0 or _mask.size() < _width * _height:
			return
		var px := minf(size.x / float(_width), size.y / float(_height))
		if px <= 0.0:
			return
		var origin := (size - Vector2(_width, _height) * px) * 0.5
		var inset := maxf(px * 0.08, 0.5)
		for y in _height:
			for x in _width:
				var rect := Rect2(origin + Vector2(x, y) * px, Vector2(px, px)).grow(-inset)
				draw_rect(rect, COLOR_ON if _mask[y * _width + x] == 1 else COLOR_OFF)


## 整数步进器：[ − ] 数值 [ + ]。对外接口对齐 SpinBox 的 `value` / `min_value` /
## `max_value` / `value_changed`，好让编辑器那边不用改读写方式。
class Stepper:
	extends HBoxContainer

	signal value_changed(value: float)

	var min_value: int = 0
	var max_value: int = 99
	var value: int = 0:
		set(next):
			var clamped := clampi(next, min_value, max_value)
			var changed := clamped != value
			value = clamped
			_refresh()
			if changed:
				value_changed.emit(float(value))
	var minus_button: Button
	var plus_button: Button
	var value_label: Label


	func _init(minimum: int, maximum: int) -> void:
		min_value = minimum
		max_value = maximum
		value = clampi(0, min_value, max_value)
		add_theme_constant_override("separation", 4)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus_button = _make_sign_button("Minus", "−")
		minus_button.pressed.connect(func() -> void: value -= 1)
		add_child(minus_button)
		value_label = Label.new()
		value_label.name = "Value"
		value_label.custom_minimum_size = Vector2(STEPPER_VALUE_WIDTH, STEPPER_BUTTON.y)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_font_size_override("font_size", FONT_STEPPER_VALUE)
		value_label.add_theme_color_override("font_color", Color("fff0b0"))
		add_child(value_label)
		plus_button = _make_sign_button("Plus", "+")
		plus_button.pressed.connect(func() -> void: value += 1)
		add_child(plus_button)
		_refresh()


	func _make_sign_button(node_name: String, sign: String) -> Button:
		var button := Button.new()
		button.name = node_name
		button.text = sign
		button.custom_minimum_size = STEPPER_BUTTON
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", FONT_STEPPER_SIGN)
		return button


	func _refresh() -> void:
		if value_label == null:
			return
		value_label.text = str(value)
		minus_button.disabled = value <= min_value
		plus_button.disabled = value >= max_value


## 画地图的格子面板。自己持有一份掩码，每次矩形落笔后发 `mask_changed`。
class PaintGrid:
	extends Control

	signal mask_changed

	const MAX_CELL_PX := 72.0
	const MIN_CELL_PX := 18.0
	const COLOR_ACTIVE := Color("6f9a3c")
	const COLOR_ACTIVE_EDGE := Color("a6d36b")
	const COLOR_HOLE := Color("2a2f26")
	const COLOR_HOLE_EDGE := Color("3b433a")
	const COLOR_PAINT_PREVIEW := Color(1.0, 0.86, 0.35, 0.45)
	const COLOR_ERASE_PREVIEW := Color(1.0, 0.35, 0.25, 0.45)

	var width := 1
	var height := 1
	var mask := PackedByteArray([1])

	var _dragging := false
	var _drag_value := 1
	var _drag_start := Vector2i.ZERO
	var _drag_current := Vector2i.ZERO


	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE


	func set_dimensions(new_width: int, new_height: int) -> void:
		new_width = maxi(new_width, 1)
		new_height = maxi(new_height, 1)
		if new_width == width and new_height == height:
			return
		# 改尺寸保留左上角重叠部分；新长出来的格子默认可玩，少画一步。
		var next := PackedByteArray()
		next.resize(new_width * new_height)
		next.fill(1)
		for y in mini(height, new_height):
			for x in mini(width, new_width):
				next[y * new_width + x] = mask[y * width + x]
		width = new_width
		height = new_height
		mask = next
		_dragging = false
		queue_redraw()
		mask_changed.emit()


	func set_mask(new_mask: PackedByteArray) -> void:
		if new_mask.size() != width * height:
			return
		mask = new_mask.duplicate()
		queue_redraw()


	func fill_all(value: int) -> void:
		mask.fill(1 if value != 0 else 0)
		queue_redraw()
		mask_changed.emit()


	func bit_at(x: int, y: int) -> int:
		return int(mask[y * width + x])


	func apply_rect(a: Vector2i, b: Vector2i, value: int) -> void:
		var x0 := clampi(mini(a.x, b.x), 0, width - 1)
		var x1 := clampi(maxi(a.x, b.x), 0, width - 1)
		var y0 := clampi(mini(a.y, b.y), 0, height - 1)
		var y1 := clampi(maxi(a.y, b.y), 0, height - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				mask[y * width + x] = 1 if value != 0 else 0
		queue_redraw()
		mask_changed.emit()


	func cell_px() -> float:
		var fit := minf(size.x / float(width), size.y / float(height))
		return clampf(floorf(fit), MIN_CELL_PX, MAX_CELL_PX)


	func grid_origin() -> Vector2:
		var px := cell_px()
		return (size - Vector2(width, height) * px) * 0.5


	## 把面板内坐标换成格子坐标；落在格子外就夹到最近的边格，拖出去也能选到边。
	func cell_at(local: Vector2) -> Vector2i:
		var px := cell_px()
		var relative := (local - grid_origin()) / px
		return Vector2i(
			clampi(int(floorf(relative.x)), 0, width - 1),
			clampi(int(floorf(relative.y)), 0, height - 1)
		)


	func cell_center(cell: Vector2i) -> Vector2:
		var px := cell_px()
		return grid_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * px


	func is_inside_grid(local: Vector2) -> bool:
		var px := cell_px()
		var origin := grid_origin()
		return Rect2(origin, Vector2(width, height) * px).has_point(local)


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button := event as InputEventMouseButton
			if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
				return
			if button.pressed:
				if _dragging or not is_inside_grid(button.position):
					return
				_dragging = true
				_drag_start = cell_at(button.position)
				_drag_current = _drag_start
				if button.button_index == MOUSE_BUTTON_RIGHT:
					_drag_value = 0
				else:
					# 左键从已画的格子起手就是擦：单击一格等于切换。
					_drag_value = 0 if bit_at(_drag_start.x, _drag_start.y) == 1 else 1
				queue_redraw()
				accept_event()
			elif _dragging:
				_dragging = false
				_drag_current = cell_at(button.position)
				apply_rect(_drag_start, _drag_current, _drag_value)
				accept_event()
		elif event is InputEventMouseMotion and _dragging:
			var next := cell_at((event as InputEventMouseMotion).position)
			if next != _drag_current:
				_drag_current = next
				queue_redraw()


	func _draw() -> void:
		var px := cell_px()
		var origin := grid_origin()
		var inset := maxf(px * 0.06, 1.5)
		for y in height:
			for x in width:
				var rect := Rect2(origin + Vector2(x, y) * px, Vector2(px, px)).grow(-inset)
				var on := mask[y * width + x] == 1
				draw_rect(rect, COLOR_ACTIVE if on else COLOR_HOLE)
				draw_rect(rect, COLOR_ACTIVE_EDGE if on else COLOR_HOLE_EDGE, false, 1.5)
		if _dragging:
			var x0 := mini(_drag_start.x, _drag_current.x)
			var x1 := maxi(_drag_start.x, _drag_current.x)
			var y0 := mini(_drag_start.y, _drag_current.y)
			var y1 := maxi(_drag_start.y, _drag_current.y)
			var preview := Rect2(
				origin + Vector2(x0, y0) * px,
				Vector2(x1 - x0 + 1, y1 - y0 + 1) * px
			)
			draw_rect(preview, COLOR_PAINT_PREVIEW if _drag_value == 1 else COLOR_ERASE_PREVIEW)
			draw_rect(preview, Color.WHITE, false, 2.0)
