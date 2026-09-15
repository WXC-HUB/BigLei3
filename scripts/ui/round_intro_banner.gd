class_name RoundIntroBanner
extends Control
## 每一盘洗完牌之后的「这盘埋了什么」横幅：雷、连携雷，以及各类埋在草地下的伙伴牌。
##
## 只报数量、不报位置——它是开局的信息条，不是作弊器。棋盘上方那排常驻读数照旧
## 负责局中的「剩余 / 总数」，这里只在开局亮一次就收走。
##
## 用法：`await present(entries)`，entries 里每项是
## `{ "icon": Texture2D, "name": String, "count": int, "accent": Color }`。
## await 到期时横幅已经收干净，调用方可以直接把棋盘交还给玩家。

const PANEL_BG := Color("172719f2")
const PANEL_BORDER := Color("d7c073")
const TITLE_COLOR := Color("ffe6a6")
const COUNT_COLOR := Color("ffd768")
const OUTLINE_COLOR := Color("241a0f")
const CHIP_BG := Color("0f1b1199")

## 进场 / 停留 / 退场。停留时间按条目数量略微加长，东西多的时候也看得完。
const RISE_TIME := 0.28
const HOLD_TIME := 1.15
const HOLD_PER_ENTRY := 0.12
const FADE_TIME := 0.24
## 每个条目依次弹出来的间隔。
const ENTRY_STAGGER := 0.06

var _panel: PanelContainer
var _title: Label
var _row: HBoxContainer
var _presentation_count := 0
var _entry_nodes: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(18.0)
	style.shadow_color = Color("0b120880")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 7)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	_title.text = "这一盘的草地下"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_title.add_theme_constant_override("outline_size", 4)
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)

	_row = HBoxContainer.new()
	_row.name = "EntryRow"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_row)


## 亮一次横幅并等它收干净。重复调用会打断上一次演出，以最后一次为准。
## `top_y` 是面板顶边的屏幕纵坐标；传负数就用默认位置（屏幕上方）。调用方一般
## 把它指到棋盘下沿之下那条空带，这样读数行和刚发完的牌都不会被压住。
func present(entries: Array[Dictionary], title: String = "", top_y: float = -1.0) -> void:
	_presentation_count += 1
	var token := _presentation_count
	if entries.is_empty():
		return
	if _panel == null:
		_build()
	if title != "":
		_title.text = title
	_rebuild_entries(entries)
	visible = true
	modulate.a = 0.0
	# 先量一次，拿到面板真实高度才能把它推到棋盘上方那条空带里。
	await get_tree().process_frame
	if token != _presentation_count:
		return
	_place_panel(top_y)

	var rise := create_tween().set_parallel(true)
	rise.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(self, "modulate:a", 1.0, RISE_TIME)
	rise.tween_property(_panel, "position:y", _panel.position.y, RISE_TIME).from(_panel.position.y - 42.0)
	_pop_entries(token)
	await rise.finished
	if token != _presentation_count:
		return

	var hold := HOLD_TIME + HOLD_PER_ENTRY * float(entries.size())
	await get_tree().create_timer(hold).timeout
	if token != _presentation_count:
		return

	var fade := create_tween().set_parallel(true)
	fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade.tween_property(_panel, "position:y", _panel.position.y - 26.0, FADE_TIME)
	await fade.finished
	if token != _presentation_count:
		return
	hide_immediately()


func hide_immediately() -> void:
	_presentation_count += 1
	visible = false
	modulate.a = 1.0


func entry_count() -> int:
	return _entry_nodes.size()


func _place_panel(top_y: float) -> void:
	var viewport := get_viewport_rect().size
	var target := top_y if top_y >= 0.0 else viewport.y * 0.11
	# 再低也不能掉出屏幕：贴到底边为止。
	target = clampf(target, 24.0, maxf(viewport.y - _panel.size.y - 16.0, 24.0))
	_panel.position = Vector2((viewport.x - _panel.size.x) * 0.5, target)


func _rebuild_entries(entries: Array[Dictionary]) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_entry_nodes.clear()
	for entry in entries:
		var chip := _make_chip(entry)
		_row.add_child(chip)
		_entry_nodes.append(chip)


## 条目一个一个弹出来，比整块一起亮更容易看清「都有些什么」。
func _pop_entries(token: int) -> void:
	for slot in range(_entry_nodes.size()):
		var chip := _entry_nodes[slot]
		chip.pivot_offset = chip.size * 0.5
		chip.scale = Vector2(0.6, 0.6)
		chip.modulate.a = 0.0
		var pop := create_tween().set_parallel(true)
		pop.tween_interval(float(slot) * ENTRY_STAGGER)
		pop.chain().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(chip, "scale", Vector2.ONE, 0.22)
		pop.tween_property(chip, "modulate:a", 1.0, 0.16)


func _make_chip(entry: Dictionary) -> Control:
	var chip := PanelContainer.new()
	chip.name = "Entry_%s" % String(entry.get("name", "?"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_BG
	style.border_color = Color(entry.get("accent", PANEL_BORDER))
	style.border_color.a = 0.72
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(9.0)
	chip.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(column)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = entry.get("icon", null)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var count := Label.new()
	count.name = "Count"
	count.text = "×%d" % int(entry.get("count", 0))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_color_override("font_color", COUNT_COLOR)
	count.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	count.add_theme_constant_override("outline_size", 3)
	count.add_theme_font_size_override("font_size", 21)
	column.add_child(count)

	var label := Label.new()
	label.name = "Name"
	label.text = String(entry.get("name", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("e8dcbe"))
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 15)
	column.add_child(label)
	return chip
