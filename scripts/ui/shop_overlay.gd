class_name ShopOverlay
extends Control

signal offer_selected(offer: int)
signal refresh_requested
signal continue_pressed
## 对战的中场休息里，「继续」按钮的语义变成「我准备好了」，走这条信号而不是
## `continue_pressed`——按下之后商店不关，要等对手或倒计时。
signal ready_pressed

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const GREETING_TEXT := "大酬宾哟！"
const GREETING_MAX_FONT_SIZE := 49
const GREETING_MIN_FONT_SIZE := 20
const SOLO_SHOP_COLUMNS := 5
const DUEL_SHOP_COLUMNS := 3
const SOLO_GRID_OFFSETS := Rect2(351.0, 301.0, 1148.0, 588.0)
const SOLO_SLOT_SIZE := Vector2(198, 230)
const SOLO_H_SEPARATION := 128
const SOLO_V_SEPARATION := 32
## ItemBg 是 Sprite2D，视觉大约 343×343，锚在格子偏右下；格子必须包住它，
## 否则 Grid 按 198×230 排版，卡片会裁切、上下叠在一起。
const DUEL_SLOT_SIZE := Vector2(348, 378)
const DUEL_H_SEPARATION := 52
const DUEL_V_SEPARATION := 72
const DUEL_SCROLL_POSITION := Vector2(180.0, 228.0)
const DUEL_SCROLL_SIZE := Vector2(1260.0, 660.0)

const OFFER_ICONS: Array[Texture2D] = [
	preload("res://my_asset/heart.png"),
	preload("res://assets/sprites/generated/potion_heal_green.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	preload("res://assets/sprites/generated/item_treasure_map.png"),
	preload("res://assets/sprites/generated/item_rope.png"),
	preload("res://assets/sprites/generated/potion_star_purple.png"),
]
const OFFER_NAMES := [
	"血量上限 +1",
	"回血量 +1",
	"红隼 +1",
	"无敌步数 +1",
	"啄木鸟 +1",
	"十字啄击",
	"夜鹭 +1",
	"随机格数 +1",
	"红尾水鸲 +1",
	"标记格数 +1",
	"透视 +1",
	"连携 +1",
	"变大 +1",
]
const OFFER_DESCRIPTIONS := [
	"生命上限增加 1，并立即恢复 1 点生命",
	"每次触发加血时，额外恢复 1 点生命",
	"1步内无敌，踩中雷不掉血",
	"每只红隼触发时，无敌时间额外 +1 步",
	"清横线上的格子/清竖线上的格子",
	"永久升级：啄木鸟同时清理所在的整行与整列（仅可购买一次）",
	"翻开后随机在周围翻开1个格子（必没有雷）",
	"每只夜鹭触发时，额外在周围翻开1个格子（必没有雷）",
	"自动标出1个雷",
	"每只红尾水鸲额外标记 1 个有雷格子",
	"随机1个格子出现内容（不翻开）3s后消失",
	"道具那格与下一颗标出的雷之间，格子全被翻开（可转弯）",
	"无敌，下一步选中的格子周围会被一起翻开",
]
@onready var shopkeeper: TextureRect = $Center/ShopCard/Shopkeeper
@onready var dimmer: ColorRect = $Dimmer
@onready var shop_stage: CenterContainer = $Center
@onready var item_grid: GridContainer = $Center/ShopCard/ItemGrid
@onready var item_slot_prototype: Control = $Center/ShopCard/ItemGrid/ItemSlot
@onready var item_prototype: Sprite2D = $Center/ShopCard/ItemGrid/ItemSlot/ItemBg
@onready var greeting_label: Label = $Center/ShopCard/Greeting
@onready var continue_button: Button = $ContinueButton
@onready var refresh_button: Button = $RefreshButton
@onready var gold_label: Label = $ShopGold

var _item_nodes: Array[Sprite2D] = []
var _item_slots: Array[Control] = []
var _buy_buttons: Array[Button] = []
var _current_price := 5
var _transition: Tween
var _owned_offers: Dictionary = {}
var _sold_out_offers: Dictionary = {}
var _current_offers: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _can_afford := false
var _duel_mode := false
var _duel_bar: PanelContainer
var _duel_result_label: Label
var _duel_countdown_label: Label
var _duel_opponent_ready_label: Label
var _duel_opponent_label: Label
var _duel_opponent_upgrades: GridContainer
var _item_scroll: ScrollContainer
var _item_scroll_margin: MarginContainer
var _solo_grid_index := 0


func _ready() -> void:
	_rng.randomize()
	_build_offer_items()
	_set_greeting_text(GREETING_TEXT)
	continue_button.pressed.connect(_on_continue_pressed)
	refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind(refresh_button, refresh_button, -1.0)
	_play_shopkeeper_breathing()


func present(_result: String, _progress: String, gold: int, price: int) -> void:
	_set_greeting_text(GREETING_TEXT)
	refresh_button.visible = true
	_current_price = price
	gold_label.text = "当前金币：%dG" % gold
	_sold_out_offers.clear()
	_roll_offers()
	_can_afford = gold >= price
	_update_cost_labels()
	_set_offers_enabled(_can_afford)
	refresh_button.disabled = not _can_afford
	visible = true
	_play_enter()


## 大全商店：13 项一次全摆出来，不刷新。关键在于 `_build_offer_items()` 本来就把
## 13 个槽位都建好了，`_roll_offers()` 只是把没抽中的藏起来——所以「大全」不是新
## 界面，只是跳过那次抽取。
func present_full(gold: int, price: int) -> void:
	_duel_mode = true
	_apply_duel_shop_layout()
	_set_greeting_text(GREETING_TEXT)
	_current_price = price
	gold_label.text = "当前金币：%dG" % gold
	_sold_out_offers.clear()
	_current_offers.clear()
	for offer_index in range(OFFER_NAMES.size()):
		_current_offers.append(offer_index)
		_item_slots[offer_index].visible = true
		_item_nodes[offer_index].visible = true
	# 大全商店不刷新，刷新按钮整个收起来（`present_game_over()` 已经是同一手法）。
	refresh_button.visible = false
	refresh_button.disabled = true
	_build_duel_bar()
	_duel_bar.visible = true
	set_duel_self_ready(false)
	set_duel_opponent_ready(false)
	_can_afford = gold >= price
	_update_cost_labels()
	_set_offers_enabled(_can_afford)
	visible = true
	_play_enter()


func set_duel_round_result(text: String) -> void:
	if _duel_result_label != null:
		_duel_result_label.text = text


func set_duel_countdown(seconds: float) -> void:
	if _duel_countdown_label != null:
		_duel_countdown_label.text = "%ds 后自动开始" % maxi(ceili(seconds), 0)


func set_duel_opponent(hp: int, max_hp: int, gold: int, upgrades: Dictionary) -> void:
	if _duel_opponent_label != null:
		_duel_opponent_label.text = "对手　血量 %d / %d　金币 %dG" % [hp, max_hp, gold]
	if _duel_opponent_upgrades == null:
		return
	for child in _duel_opponent_upgrades.get_children():
		child.queue_free()
	var offers := upgrades.keys()
	offers.sort()
	for offer in offers:
		var offer_index := int(offer)
		if offer_index < 0 or offer_index >= OFFER_ICONS.size():
			continue
		var icon := TextureRect.new()
		icon.texture = OFFER_ICONS[offer_index]
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = "%s ×%d" % [OFFER_NAMES[offer_index], int(upgrades[offer])]
		_duel_opponent_upgrades.add_child(icon)


func set_duel_opponent_ready(is_ready: bool) -> void:
	if _duel_opponent_ready_label != null:
		_duel_opponent_ready_label.text = "对手：已准备 ✓" if is_ready else "对手：选购中…"


func set_duel_self_ready(is_ready: bool) -> void:
	continue_button.disabled = is_ready
	continue_button.text = "等待对手…" if is_ready else "准备好了"


## 对战结束时把商店还原成单机形态，免得下一次单机开局继承了大全模式。
func exit_duel_mode() -> void:
	_duel_mode = false
	_restore_solo_shop_layout()
	if _duel_bar != null:
		_duel_bar.visible = false
	refresh_button.visible = true
	continue_button.disabled = false
	continue_button.text = "继续"


func _build_duel_bar() -> void:
	if _duel_bar != null:
		return
	_duel_bar = PanelContainer.new()
	_duel_bar.name = "IntermissionBar"
	_duel_bar.add_theme_stylebox_override("panel", _duel_bar_style())
	_duel_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_duel_bar.custom_minimum_size = Vector2(1180, 150)
	_duel_bar.position = Vector2(-590, -170)
	add_child(_duel_bar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_duel_bar.add_child(column)

	_duel_result_label = _make_duel_label("RoundResultLabel", "", 28)
	column.add_child(_duel_result_label)
	_duel_opponent_label = _make_duel_label("OpponentShopStatusLabel", "对手　血量 —　金币 —", 24)
	column.add_child(_duel_opponent_label)

	_duel_opponent_upgrades = GridContainer.new()
	_duel_opponent_upgrades.name = "OpponentShopUpgradeGrid"
	_duel_opponent_upgrades.columns = 13
	column.add_child(_duel_opponent_upgrades)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	_duel_countdown_label = _make_duel_label("CountdownLabel", "", 24)
	row.add_child(_duel_countdown_label)
	_duel_opponent_ready_label = _make_duel_label("OpponentReadyLabel", "对手：选购中…", 24)
	_duel_opponent_ready_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_duel_opponent_ready_label)


func _make_duel_label(node_name: String, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4e8c1"))
	return label


func _duel_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.16, 0.11, 0.9)
	style.border_color = Color("3d5136")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	return style


func _apply_duel_shop_layout() -> void:
	item_grid.columns = DUEL_SHOP_COLUMNS
	item_grid.add_theme_constant_override("h_separation", DUEL_H_SEPARATION)
	item_grid.add_theme_constant_override("v_separation", DUEL_V_SEPARATION)
	for slot in _item_slots:
		slot.custom_minimum_size = DUEL_SLOT_SIZE
	if item_grid.get_parent() != _item_scroll_margin:
		var shop_card := item_grid.get_parent() as Control
		_solo_grid_index = item_grid.get_index()
		if _item_scroll == null:
			_item_scroll = ScrollContainer.new()
			_item_scroll.name = "ItemScroll"
			_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
			_item_scroll.follow_focus = true
			_item_scroll.clip_contents = true
			_item_scroll_margin = MarginContainer.new()
			_item_scroll_margin.name = "ItemScrollMargin"
			_item_scroll_margin.add_theme_constant_override("margin_left", 16)
			_item_scroll_margin.add_theme_constant_override("margin_top", 20)
			_item_scroll_margin.add_theme_constant_override("margin_right", 28)
			_item_scroll_margin.add_theme_constant_override("margin_bottom", 24)
			_item_scroll_margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_item_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			shop_card.add_child(_item_scroll)
			shop_card.move_child(_item_scroll, _solo_grid_index)
			_item_scroll.add_child(_item_scroll_margin)
		item_grid.reparent(_item_scroll_margin, false)
	_item_scroll.position = DUEL_SCROLL_POSITION
	_item_scroll.size = DUEL_SCROLL_SIZE
	_item_scroll.custom_minimum_size = DUEL_SCROLL_SIZE
	item_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	item_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_duel_scrollbar()
	_item_scroll.visible = true


func _restore_solo_shop_layout() -> void:
	item_grid.columns = SOLO_SHOP_COLUMNS
	item_grid.add_theme_constant_override("h_separation", SOLO_H_SEPARATION)
	item_grid.add_theme_constant_override("v_separation", SOLO_V_SEPARATION)
	item_grid.size_flags_horizontal = Control.SIZE_FILL
	item_grid.size_flags_vertical = Control.SIZE_FILL
	for slot in _item_slots:
		slot.custom_minimum_size = SOLO_SLOT_SIZE
	if _item_scroll == null or item_grid.get_parent() != _item_scroll_margin:
		return
	var shop_card := _item_scroll.get_parent()
	item_grid.reparent(shop_card, false)
	shop_card.move_child(item_grid, _solo_grid_index)
	item_grid.offset_left = SOLO_GRID_OFFSETS.position.x
	item_grid.offset_top = SOLO_GRID_OFFSETS.position.y
	item_grid.offset_right = SOLO_GRID_OFFSETS.end.x
	item_grid.offset_bottom = SOLO_GRID_OFFSETS.end.y
	_item_scroll.visible = false


func _style_duel_scrollbar() -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("d4a84b")
	grabber.set_corner_radius_all(6)
	grabber.set_content_margin_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.16, 0.12, 0.06, 0.72)
	track.set_corner_radius_all(6)
	_item_scroll.add_theme_stylebox_override("grabber", grabber)
	_item_scroll.add_theme_stylebox_override("scroll", track)
	var vbar := _item_scroll.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.custom_minimum_size.x = 16.0
	vbar.add_theme_stylebox_override("grabber", grabber)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber)
	vbar.add_theme_stylebox_override("scroll", track)


func show_insufficient_gold(gold: int, _price: int) -> void:
	gold_label.text = "当前金币：%dG" % gold
	_can_afford = false
	_set_offers_enabled(false)
	refresh_button.disabled = true


func update_gold(gold: int, price: int) -> void:
	_current_price = price
	gold_label.text = "当前金币：%dG" % gold
	_can_afford = gold >= price
	_update_cost_labels()
	_set_offers_enabled(_can_afford)
	refresh_button.disabled = not _can_afford


func refresh_offers(gold: int, price: int) -> void:
	_current_price = price
	_sold_out_offers.clear()
	_roll_offers()
	update_gold(gold, price)


func mark_offer_sold_out(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size() or _owned_offers.has(offer_index):
		return
	_sold_out_offers[offer_index] = true
	_update_cost_labels()
	# 别拿 refresh_button.disabled 当「买得起吗」的替身：大全商店把刷新按钮整个
	# 关了，那样一买完东西整排货就会被连坐禁用。
	_set_offers_enabled(_can_afford)


func current_offers() -> Array[int]:
	return _current_offers.duplicate()


func set_offer_owned(offer_index: int, owned: bool) -> void:
	if owned:
		_owned_offers[offer_index] = true
	else:
		_owned_offers.erase(offer_index)
	if offer_index >= 0 and offer_index < _buy_buttons.size():
		_buy_buttons[offer_index].disabled = owned
		_item_nodes[offer_index].get_node("Label_Cost").text = "已购" if owned else "%dG" % _current_price
		_item_nodes[offer_index].modulate = Color(0.78, 0.78, 0.78, 0.88) if owned else Color.WHITE


func present_game_over() -> void:
	_set_items_visible(false)
	refresh_button.visible = false
	refresh_button.disabled = true
	visible = true
	_play_enter()


func _build_offer_items() -> void:
	for offer_index in range(OFFER_NAMES.size()):
		var slot := item_slot_prototype if offer_index == 0 else item_slot_prototype.duplicate() as Control
		if offer_index > 0:
			item_grid.add_child(slot)
		slot.name = "ItemSlot_%d" % offer_index
		var item := slot.get_node("ItemBg") as Sprite2D
		item.get_node("Item_Icon").texture = OFFER_ICONS[offer_index]
		item.get_node("Label_Name").text = OFFER_NAMES[offer_index]
		var button := item.get_node("BuyButton") as Button
		button.pressed.connect(_on_offer_pressed.bind(offer_index))
		button.mouse_entered.connect(_on_item_mouse_entered.bind(offer_index))
		button.mouse_exited.connect(_on_item_mouse_exited)
		ButtonMotion.bind(button, item, -1.5 if offer_index % 2 == 0 else 1.5)
		_item_slots.append(slot)
		_item_nodes.append(item)
		_buy_buttons.append(button)
	_update_cost_labels()


func _on_offer_pressed(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size() or _buy_buttons[offer_index].disabled:
		return
	offer_selected.emit(offer_index)


func _on_continue_pressed() -> void:
	if _duel_mode:
		# 对战里按下的是「我准备好了」：商店不关，继续等对手或等倒计时归零。
		set_duel_self_ready(true)
		ready_pressed.emit()
		return
	continue_button.disabled = true
	refresh_button.disabled = true
	_set_offers_enabled(false)
	await _play_exit()
	continue_button.disabled = false
	continue_pressed.emit()


func _on_item_mouse_entered(offer_index: int) -> void:
	_set_greeting_text(OFFER_DESCRIPTIONS[offer_index])


func _on_item_mouse_exited() -> void:
	_set_greeting_text(GREETING_TEXT)


func _set_greeting_text(value: String) -> void:
	greeting_label.text = value
	var font := greeting_label.get_theme_font("font")
	var available_size := Vector2(
		maxf(greeting_label.size.x - 20.0, 1.0),
		maxf(greeting_label.size.y - 12.0, 1.0)
	)
	var fitted_size := GREETING_MIN_FONT_SIZE
	for font_size in range(GREETING_MAX_FONT_SIZE, GREETING_MIN_FONT_SIZE - 1, -1):
		var measured := font.get_multiline_string_size(
			value,
			HORIZONTAL_ALIGNMENT_CENTER,
			available_size.x,
			font_size
		)
		if measured.x <= available_size.x and measured.y <= available_size.y:
			fitted_size = font_size
			break
	greeting_label.add_theme_font_size_override("font_size", fitted_size)


func _play_enter() -> void:
	_kill_transition()
	await get_tree().process_frame
	shop_stage.pivot_offset = shop_stage.size * 0.5
	dimmer.modulate.a = 0.0
	shop_stage.scale = Vector2(0.92, 0.92)
	shop_stage.rotation = deg_to_rad(-0.8)
	shop_stage.modulate.a = 0.0
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(dimmer, "modulate:a", 1.0, 0.24)
	_transition.tween_property(shop_stage, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK)
	_transition.tween_property(shop_stage, "rotation", 0.0, 0.28)
	_transition.tween_property(shop_stage, "modulate:a", 1.0, 0.2)


func _play_exit() -> void:
	_kill_transition()
	_set_greeting_text(GREETING_TEXT)
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(dimmer, "modulate:a", 0.0, 0.22)
	_transition.tween_property(shop_stage, "scale", Vector2(0.94, 0.94), 0.22)
	_transition.tween_property(shop_stage, "rotation", deg_to_rad(0.65), 0.22)
	_transition.tween_property(shop_stage, "modulate:a", 0.0, 0.17)
	await _transition.finished
	visible = false
	shop_stage.scale = Vector2.ONE
	shop_stage.rotation = 0.0
	shop_stage.modulate = Color.WHITE
	dimmer.modulate = Color.WHITE


func _kill_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()


func _update_cost_labels() -> void:
	for item_index in range(_item_nodes.size()):
		var cost_label := _item_nodes[item_index].get_node("Label_Cost") as Label
		if _owned_offers.has(item_index):
			cost_label.text = "已购"
		elif _sold_out_offers.has(item_index):
			cost_label.text = "售罄"
		else:
			cost_label.text = "%dG" % _current_price
	refresh_button.text = "刷新并补货  %dG" % _current_price


func _set_offers_enabled(enabled: bool) -> void:
	for item_index in range(_buy_buttons.size()):
		var available := (
			enabled
			and _current_offers.has(item_index)
			and not _owned_offers.has(item_index)
			and not _sold_out_offers.has(item_index)
		)
		_buy_buttons[item_index].disabled = not available
		_item_nodes[item_index].modulate = Color.WHITE if available else Color(0.58, 0.58, 0.58, 0.72)


func _set_items_visible(value: bool) -> void:
	_set_greeting_text(GREETING_TEXT)
	for item_index in range(_item_slots.size()):
		_item_slots[item_index].visible = value
		_item_nodes[item_index].visible = value


func _roll_offers() -> void:
	var candidates: Array[int] = []
	for offer_index in range(OFFER_NAMES.size()):
		if not _owned_offers.has(offer_index):
			candidates.append(offer_index)
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var held := candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = held
	_current_offers.clear()
	for index in range(mini(3, candidates.size())):
		_current_offers.append(candidates[index])
	for offer_index in range(_item_slots.size()):
		var offered := _current_offers.has(offer_index)
		_item_slots[offer_index].visible = offered
		_item_nodes[offer_index].visible = offered


func _play_shopkeeper_breathing() -> void:
	# Keep the sprite geometry fixed so the outlined raster does not shimmer.
	shopkeeper.modulate = Color.WHITE
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shopkeeper, "modulate", Color(1.012, 1.006, 0.992, 1.0), 3.0)
	tween.tween_property(shopkeeper, "modulate", Color.WHITE, 3.0)
