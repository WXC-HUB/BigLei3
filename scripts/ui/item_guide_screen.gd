class_name ItemGuideScreen
extends CanvasLayer
## 伙伴图鉴：整屏压暗，中间一块奶油色卡片，把全部伙伴牌按「上图下文」摆成一排排小卡：
## 图标在上、名字居中、作用说明在下（关键词强调色）。底部一个「开始排雷」关掉。
##
## 内容来自 GuidedItemLesson.ITEM_ENTRIES，这里只负责摆和动效；谁来打开、关掉之后
## 干什么由 main.gd 决定（新手第 2 盘强引导的最后一步会打开它）。

signal closed

const GUIDE_FONT := preload("res://assets/fonts/eva_ming_sc.otf")
const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

const LAYER_INDEX := 86
const COLUMNS := 4
const CARD_WIDTH := 292.0
const ICON_SIZE := Vector2(128, 128)
const CARD_GAP := 18
const FADE_SECONDS := 0.24

const COLOR_BACKDROP := Color(0.05, 0.08, 0.05, 0.66)
const COLOR_SHEET := Color(0.976, 0.914, 0.741, 0.99)
const COLOR_SHEET_BORDER := Color(0.875, 0.482, 0.243, 1.0)
const COLOR_CARD := Color(1.0, 0.975, 0.92, 1.0)
const COLOR_CARD_BORDER := Color(0.83, 0.68, 0.45, 1.0)
const COLOR_INK := Color(0.278, 0.184, 0.102, 1.0)
const COLOR_MUTED := Color(0.47, 0.37, 0.25, 1.0)
const COLOR_BUTTON := Color(0.075, 0.145, 0.098, 0.96)
const COLOR_BUTTON_INK := Color(1.0, 0.9, 0.58, 1.0)

var _backdrop: ColorRect
var _sheet: PanelContainer
var _grid: GridContainer
var _close_button: Button
var _cards: Array[Control] = []
var _fade_tween: Tween
var _open := false


func _ready() -> void:
	layer = LAYER_INDEX
	visible = false
	_build_backdrop()
	_build_sheet()


func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = COLOR_BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_theme_stylebox_override("panel", _rounded_style(COLOR_SHEET, COLOR_SHEET_BORDER, 4, 22, 36, 26, true))
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_sheet)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	_sheet.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "伙 伴 图 鉴"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", GUIDE_FONT)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", COLOR_INK)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "翻出伙伴的牌就会自动生效，不用你操心。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_font_override("font", GUIDE_FONT)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	column.add_child(subtitle)

	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.columns = COLUMNS
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	column.add_child(_grid)
	for entry in GuidedItemLesson.ITEM_ENTRIES:
		var card := _build_card(entry)
		_grid.add_child(card)
		_cards.append(card)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(footer)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "开始排雷  »"
	_close_button.custom_minimum_size = Vector2(240, 58)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_button.add_theme_font_override("font", GUIDE_FONT)
	_close_button.add_theme_font_size_override("font_size", 26)
	_close_button.add_theme_color_override("font_color", COLOR_BUTTON_INK)
	_close_button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.84))
	_close_button.add_theme_color_override("font_pressed_color", Color(0.9, 0.8, 0.55))
	_close_button.add_theme_stylebox_override("normal", _rounded_style(COLOR_BUTTON, Color(0.86, 0.73, 0.38, 0.95), 2, 15, 22, 9))
	_close_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.12, 0.245, 0.145, 0.98), Color(1, 0.86, 0.48), 3, 15, 22, 9))
	_close_button.add_theme_stylebox_override("pressed", _rounded_style(Color(0.045, 0.095, 0.06, 1), Color(0.74, 0.62, 0.3), 2, 15, 22, 9))
	_close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_close_button.pressed.connect(dismiss)
	footer.add_child(_close_button)
	ButtonMotion.bind(_close_button, _close_button, 1.2)


## 一张小卡：图标在上、名字居中、说明在下。
func _build_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_%s" % String(entry["name"])
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _rounded_style(COLOR_CARD, COLOR_CARD_BORDER, 2, 16, 16, 16))

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var icon_slot := CenterContainer.new()
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_slot)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = entry["texture"]
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.add_child(icon)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = String(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("font", GUIDE_FONT)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", COLOR_INK)
	column.add_child(name_label)

	var text := RichTextLabel.new()
	text.name = "Text"
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size = Vector2(CARD_WIDTH - 32.0, 0)
	text.add_theme_font_override("normal_font", GUIDE_FONT)
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_color_override("default_color", COLOR_INK)
	text.add_theme_constant_override("line_separation", 4)
	text.text = GuidedItemLesson.format_bbcode(entry)
	column.add_child(text)
	return card


func present() -> void:
	if _open:
		return
	_open = true
	visible = true
	_sheet.reset_size()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_backdrop.modulate.a = 0.0
	_sheet.modulate.a = 0.0
	_sheet.pivot_offset = _sheet.size * 0.5
	_sheet.scale = Vector2(0.94, 0.94)
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_backdrop, "modulate:a", 1.0, FADE_SECONDS)
	_fade_tween.tween_property(_sheet, "modulate:a", 1.0, FADE_SECONDS)
	_fade_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_sheet, "scale", Vector2.ONE, FADE_SECONDS * 1.4)


func dismiss() -> void:
	if not _open:
		visible = false
		return
	_open = false
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func cards() -> Array[Control]:
	return _cards


func close_button() -> Button:
	return _close_button


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
		style.shadow_color = Color(0.078, 0.047, 0.024, 0.55)
		style.shadow_size = 16
		style.shadow_offset = Vector2(0, 8)
	return style
