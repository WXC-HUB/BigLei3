class_name ShopOverlay
extends Control

signal offer_selected(offer: int)
signal refresh_requested
signal continue_pressed

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const GREETING_TEXT := "大酬宾哟！"
const GREETING_MAX_FONT_SIZE := 49
const GREETING_MIN_FONT_SIZE := 20

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
	"特殊标记，标记连线雷后中间全被翻开",
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
	_update_cost_labels()
	_set_offers_enabled(gold >= price)
	refresh_button.disabled = gold < price
	visible = true
	_play_enter()


func show_insufficient_gold(gold: int, _price: int) -> void:
	gold_label.text = "当前金币：%dG" % gold
	_set_offers_enabled(false)
	refresh_button.disabled = true


func update_gold(gold: int, price: int) -> void:
	_current_price = price
	gold_label.text = "当前金币：%dG" % gold
	_update_cost_labels()
	_set_offers_enabled(gold >= price)
	refresh_button.disabled = gold < price


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
	_set_offers_enabled(not refresh_button.disabled)


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
