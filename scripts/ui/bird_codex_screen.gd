class_name BirdCodexScreen
extends Control
## 鸟类图鉴：整屏一张奶油色大卡，把 [BirdCatalog] 里的伙伴按解锁顺序摆成 4×2 的小卡。
## 每张小卡上图下文——头像在上，名字、外号、能力在下，右下角一枚「已加入 / 未解锁」的牌子。
##
## 头像不是静态图，是栖枝上那一套 220×220 待机帧，照 BirdPerch 的节奏循环播；
## 每张卡的相位错开一点，八只鸟才不会整整齐齐地一起抬头。
##
## 和成就页一样，这一页是纯展示：解锁状态由 Main 通过 [method set_unlocked] 喂进来，
## 存档读写仍然归 Main。没解锁的鸟只露一个黑剪影，名字打码、能力换成解锁条件——
## 图鉴因此也是一张「还差谁」的清单。

signal back_requested

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const Catalog := preload("res://scripts/game/bird_catalog.gd")
const CODEX_FONT := preload("res://assets/fonts/eva_ming_sc.otf")
const BACKGROUND := preload("res://assets/backgrounds/birdwatch-tree-stage.png")

## 图鉴永远铺成两行：列数按鸟数算，多一只鸟就把卡片挤窄一点，而不是往下再加一行。
## 1080 的高度只装得下两行这么高的卡，第三行会被切掉。
const ROWS := 2
const MAX_ROW_WIDTH := 1660.0
const CARD_WIDTH_MAX := 344.0
const CARD_HEIGHT := 384.0
const CARD_GAP := 20
const PORTRAIT_HEIGHT := 150.0
const ABILITY_HEIGHT := 84.0

## 待机帧的播放顺序和节奏抄 [BirdPerch]：0→3 再走回来，尾帧不重复，所以看着是
## 来回摆头而不是每轮"啪"地跳回第一帧。红隼只有两帧，取模之后自动变成来回切。
const IDLE_SEQUENCE := [0, 1, 2, 3, 2, 1]
const IDLE_FRAME_TIME := 0.22
## 相邻两张卡的起播相位差（秒）。八只鸟同步扇翅膀像一排复制粘贴。
const IDLE_STAGGER := 0.17

const COLOR_SHADE := Color(0.04, 0.08, 0.035, 0.56)
const COLOR_CARD := Color(0.956863, 0.890196, 0.717647, 0.97)
const COLOR_CARD_BORDER := Color(0.458824, 0.317647, 0.14902, 1.0)
const COLOR_CONTENT := Color(0.294118, 0.227451, 0.129412, 0.2)
const COLOR_CONTENT_BORDER := Color(0.458824, 0.317647, 0.14902, 0.55)
const COLOR_ENTRY := Color(0.992157, 0.945098, 0.803922, 0.86)
const COLOR_ENTRY_BORDER := Color(0.588235, 0.419608, 0.196078, 0.72)
const COLOR_ENTRY_LOCKED := Color(0.84, 0.796, 0.686, 0.72)
const COLOR_ENTRY_LOCKED_BORDER := Color(0.478, 0.42, 0.325, 0.55)
const COLOR_INK := Color(0.239216, 0.168627, 0.0901961, 1.0)
const COLOR_MUTED := Color(0.407843, 0.337255, 0.235294, 1.0)
const COLOR_UNLOCKED := Color("6f8f3d")
const COLOR_LOCKED := Color("846e50")
## 没解锁的鸟只留一个剪影：贴图本身的 alpha 还在，所以形状认得出，细节全压掉。
const SILHOUETTE_TINT := Color(0.1, 0.11, 0.09, 0.92)
## 没解锁的鸟连名字都打码：图鉴顺带就是一张「还差谁」的清单。
const LOCKED_NAME := "？ ？ ？"

var back_button: Button
var _card_panel: PanelContainer
var _grid: GridContainer
var _progress: Label
var _elapsed := 0.0
var _transitioning := false
## id -> {"card": PanelContainer, "portrait": TextureRect, "name": Label,
##        "alias": Label, "ability": Label, "status": Label, "phase": float}
var _entries: Dictionary = {}
var _unlocked: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_background()
	_build_card()
	_refresh_progress()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	for bird_id in _entries:
		_animate_portrait(_entries[bird_id])


func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "Background"
	background.texture = BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = COLOR_SHADE
	# 挡住底下的标题页：图鉴开着的时候那些按钮不该还能点。
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _build_card() -> void:
	_card_panel = PanelContainer.new()
	_card_panel.name = "Card"
	_card_panel.add_theme_stylebox_override(
		"panel", _rounded_style(COLOR_CARD, COLOR_CARD_BORDER, 5, 24, 34, 30, true)
	)
	_card_panel.set_anchors_preset(Control.PRESET_CENTER)
	_card_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_card_panel)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 20)
	_card_panel.add_child(layout)
	layout.add_child(_build_header())

	var content := PanelContainer.new()
	content.name = "ContentPanel"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_stylebox_override(
		"panel", _rounded_style(COLOR_CONTENT, COLOR_CONTENT_BORDER, 2, 18, 24, 24)
	)
	layout.add_child(content)

	_grid = GridContainer.new()
	_grid.name = "BirdGrid"
	_grid.columns = _column_count()
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	content.add_child(_grid)
	for index in Catalog.ENTRIES.size():
		_build_entry(Catalog.ENTRIES[index], index)
	# 悬停动效要等按钮真的进了场景树再挂：ButtonMotion 会问 get_tree() 拿下一帧来
	# 重算支点，树外调用虽然被它挡住了，Node.get_tree() 本身照样打一行报错。
	ButtonMotion.bind(back_button, back_button, -1.0)


## 两行铺满：奇数只鸟时上面那行多一张，剩下的往下挪。
func _column_count() -> int:
	return maxi(1, ceili(float(Catalog.ENTRIES.size()) / float(ROWS)))


## 一整行加上列间距不能超过 MAX_ROW_WIDTH；鸟少的时候卡片也不无限长，
## 到 CARD_WIDTH_MAX 就停住。
func _card_width() -> float:
	var columns := _column_count()
	var available := MAX_ROW_WIDTH - float(CARD_GAP * (columns - 1))
	return minf(CARD_WIDTH_MAX, floorf(available / float(columns)))


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 18)

	var title := Label.new()
	title.name = "Title"
	title.text = "鸟 类 图 鉴"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", CODEX_FONT)
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", COLOR_INK)
	title.add_theme_color_override("font_outline_color", Color(1, 0.917647, 0.709804, 0.65))
	title.add_theme_constant_override("outline_size", 5)
	header.add_child(title)

	_progress = Label.new()
	_progress.name = "Progress"
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress.add_theme_font_override("font", CODEX_FONT)
	_progress.add_theme_font_size_override("font_size", 28)
	_progress.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(_progress)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "返回"
	back_button.custom_minimum_size = Vector2(142, 58)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.add_theme_font_override("font", CODEX_FONT)
	back_button.add_theme_font_size_override("font_size", 25)
	back_button.add_theme_color_override("font_color", COLOR_INK)
	back_button.add_theme_color_override("font_hover_color", Color(0.164706, 0.113725, 0.0627451, 1))
	back_button.add_theme_stylebox_override(
		"normal", _rounded_style(Color(0.85098, 0.678431, 0.262745, 1), COLOR_CARD_BORDER, 3, 15, 22, 10)
	)
	back_button.add_theme_stylebox_override(
		"hover", _rounded_style(Color(0.941176, 0.788235, 0.352941, 1), COLOR_CARD_BORDER, 3, 15, 22, 10)
	)
	back_button.add_theme_stylebox_override(
		"pressed", _rounded_style(Color(0.72549, 0.541176, 0.196078, 1), Color(0.329412, 0.215686, 0.0980392, 1), 3, 15, 22, 10)
	)
	back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	return header


func _build_entry(data: Dictionary, index: int) -> void:
	var bird_id := String(data["id"])
	var card_width := _card_width()
	var portrait_size := Vector2(card_width - 44.0, PORTRAIT_HEIGHT)
	var card := PanelContainer.new()
	card.name = "Bird_%s" % bird_id
	card.custom_minimum_size = Vector2(card_width, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(card)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var portrait_slot := CenterContainer.new()
	portrait_slot.custom_minimum_size = portrait_size
	portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait_slot)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.texture = data["frames"][0]
	portrait.custom_minimum_size = portrait_size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 乌鸦那套图朝左画，翻个面，八只鸟在图鉴里才朝同一个方向。
	portrait.flip_h = not bool(data.get("faces_right", true))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_slot.add_child(portrait)

	var name_label := _build_label(String(data["name"]), 32, COLOR_INK)
	column.add_child(name_label)
	var alias_label := _build_label(String(data["alias"]), 20, COLOR_MUTED)
	column.add_child(alias_label)

	var ability := _build_label(String(data["ability"]), 19, COLOR_INK)
	ability.custom_minimum_size = Vector2(card_width - 56.0, ABILITY_HEIGHT)
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ability.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(ability)

	var status := _build_label("未解锁", 22, COLOR_LOCKED)
	column.add_child(status)

	_entries[bird_id] = {
		"card": card,
		"portrait": portrait,
		"name": name_label,
		"alias": alias_label,
		"ability": ability,
		"status": status,
		"frames": data["frames"],
		"phase": float(index) * IDLE_STAGGER,
	}
	_refresh_entry(bird_id)


func _build_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CODEX_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Main 把存档里的解锁位喂进来；图鉴不自己记账。
func set_unlocked(bird_id: String, value: bool = true) -> void:
	if not _entries.has(bird_id):
		push_warning("Unknown bird id: %s" % bird_id)
		return
	_unlocked[bird_id] = value
	_refresh_entry(bird_id)
	_refresh_progress()


func is_unlocked(bird_id: String) -> bool:
	return bool(_unlocked.get(bird_id, false))


func unlocked_count() -> int:
	var total := 0
	for bird_id in _entries:
		if is_unlocked(bird_id):
			total += 1
	return total


## 给测试和调试用：拿到某一只鸟的卡片零件。
func entry_parts(bird_id: String) -> Dictionary:
	return _entries.get(bird_id, {})


func _refresh_entry(bird_id: String) -> void:
	var parts: Dictionary = _entries[bird_id]
	var data := Catalog.entry(bird_id)
	var unlocked := is_unlocked(bird_id)
	var portrait := parts["portrait"] as TextureRect
	portrait.self_modulate = Color.WHITE if unlocked else SILHOUETTE_TINT
	(parts["name"] as Label).text = String(data["name"]) if unlocked else LOCKED_NAME
	# 锁着的时候三行文案整体换成「还差什么」，行数不变，卡片高度才不会跳。
	(parts["alias"] as Label).text = String(data["alias"]) if unlocked else "还没加入队伍"
	(parts["ability"] as Label).text = (
		String(data["ability"]) if unlocked else String(data["unlock"])
	)
	var status := parts["status"] as Label
	status.text = "已加入" if unlocked else "未解锁"
	status.add_theme_color_override("font_color", COLOR_UNLOCKED if unlocked else COLOR_LOCKED)
	var card := parts["card"] as PanelContainer
	card.add_theme_stylebox_override("panel", _rounded_style(
		COLOR_ENTRY if unlocked else COLOR_ENTRY_LOCKED,
		COLOR_ENTRY_BORDER if unlocked else COLOR_ENTRY_LOCKED_BORDER,
		2, 16, 18, 16
	))


func _refresh_progress() -> void:
	if _progress == null:
		return
	_progress.text = "已收录 %d/%d" % [unlocked_count(), Catalog.ENTRIES.size()]


func _animate_portrait(parts: Dictionary) -> void:
	var frames: Array = parts["frames"]
	if frames.size() <= 1:
		return
	var tick := int((_elapsed + float(parts["phase"])) / IDLE_FRAME_TIME)
	var step: int = IDLE_SEQUENCE[tick % IDLE_SEQUENCE.size()]
	(parts["portrait"] as TextureRect).texture = frames[step % frames.size()]


func present() -> void:
	if _transitioning:
		return
	visible = true
	modulate.a = 0.0
	_card_panel.pivot_offset = _card_panel.size * 0.5
	_card_panel.scale = Vector2(0.96, 0.96)
	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(self, "modulate:a", 1.0, 0.24)
	intro.tween_property(_card_panel, "scale", Vector2.ONE, 0.3)


func dismiss() -> void:
	if _transitioning or not visible:
		return
	_transitioning = true
	var outro := create_tween().set_parallel(true)
	outro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(self, "modulate:a", 0.0, 0.2)
	outro.tween_property(_card_panel, "scale", Vector2(0.97, 0.97), 0.2)
	await outro.finished
	visible = false
	_transitioning = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _transitioning:
		return
	back_requested.emit()


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
		style.shadow_color = Color(0.145098, 0.0901961, 0.0470588, 0.62)
		style.shadow_size = 18
		style.shadow_offset = Vector2(0, 9)
	return style
