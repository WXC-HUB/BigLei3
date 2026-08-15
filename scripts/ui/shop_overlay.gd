class_name ShopOverlay
extends Control

signal offer_selected(offer: int)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

const OFFER_ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/generated/item_lantern.png"),
	preload("res://assets/sprites/generated/item_compass.png"),
	preload("res://my_asset/heart.png"),
]
const OFFER_NAMES := ["营地提灯", "探险罗盘", "安全踏勘"]
const OFFER_DESCRIPTIONS := ["后续每局 +1 盏灯", "后续每局 +1 个罗盘", "后续每局 -2 枚地雷"]
@onready var shopkeeper: TextureRect = $Center/ShopCard/Shopkeeper
@onready var dimmer: ColorRect = $Dimmer
@onready var shop_card: Control = $Center/ShopCard
@onready var item_grid: GridContainer = $Center/ShopCard/ItemGrid
@onready var item_slot_prototype: Control = $Center/ShopCard/ItemGrid/ItemSlot
@onready var item_prototype: Sprite2D = $Center/ShopCard/ItemGrid/ItemSlot/ItemBg
@onready var item_tip: PanelContainer = $ItemTip
@onready var item_tip_label: Label = $ItemTip/Margin/Description

var _item_nodes: Array[Sprite2D] = []
var _buy_buttons: Array[Button] = []
var _current_price := 5
var _transition: Tween
var _card_rest_position := Vector2.ZERO


func _ready() -> void:
	item_tip.hide()
	_build_offer_items()
	_play_shopkeeper_breathing()


func present(_result: String, _progress: String, gold: int, price: int) -> void:
	_current_price = price
	_update_cost_labels()
	_set_items_visible(true)
	_set_offers_enabled(gold >= price)
	visible = true
	_play_enter()


func show_insufficient_gold(_gold: int, _price: int) -> void:
	_set_offers_enabled(false)


func present_game_over() -> void:
	_set_items_visible(false)
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
		button.mouse_entered.connect(_on_item_mouse_entered.bind(item, offer_index))
		button.mouse_exited.connect(_on_item_mouse_exited.bind(item))
		_item_nodes.append(item)
		_buy_buttons.append(button)
	_update_cost_labels()


func _on_offer_pressed(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size() or _buy_buttons[offer_index].disabled:
		return
	_set_offers_enabled(false)
	await _play_exit()
	offer_selected.emit(offer_index)


func _on_item_mouse_entered(item: Sprite2D, offer_index: int) -> void:
	item_tip_label.text = OFFER_DESCRIPTIONS[offer_index]
	item_tip.reset_size()
	item_tip.show()
	await get_tree().process_frame
	var tip_position := item.global_position + Vector2(-item_tip.size.x * 0.5, 158.0)
	var viewport_size := get_viewport_rect().size
	tip_position.x = clampf(tip_position.x, 12.0, viewport_size.x - item_tip.size.x - 12.0)
	tip_position.y = clampf(tip_position.y, 12.0, viewport_size.y - item_tip.size.y - 12.0)
	item_tip.global_position = tip_position


func _on_item_mouse_exited(item: Sprite2D) -> void:
	item_tip.hide()


func _play_enter() -> void:
	_kill_transition()
	await get_tree().process_frame
	_card_rest_position = shop_card.position
	shop_card.pivot_offset = shop_card.size * 0.5
	dimmer.modulate.a = 0.0
	shop_card.position = _card_rest_position + Vector2(0, 54)
	shop_card.scale = Vector2(0.92, 0.92)
	shop_card.rotation = deg_to_rad(-0.8)
	shop_card.modulate.a = 0.0
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition.tween_property(dimmer, "modulate:a", 1.0, 0.24)
	_transition.tween_property(shop_card, "position", _card_rest_position, 0.34).set_trans(Tween.TRANS_BACK)
	_transition.tween_property(shop_card, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK)
	_transition.tween_property(shop_card, "rotation", 0.0, 0.28)
	_transition.tween_property(shop_card, "modulate:a", 1.0, 0.2)


func _play_exit() -> void:
	_kill_transition()
	item_tip.hide()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition.tween_property(dimmer, "modulate:a", 0.0, 0.22)
	_transition.tween_property(shop_card, "position", _card_rest_position + Vector2(0, 46), 0.22)
	_transition.tween_property(shop_card, "scale", Vector2(0.94, 0.94), 0.22)
	_transition.tween_property(shop_card, "rotation", deg_to_rad(0.65), 0.22)
	_transition.tween_property(shop_card, "modulate:a", 0.0, 0.17)
	await _transition.finished
	visible = false
	shop_card.position = _card_rest_position
	shop_card.scale = Vector2.ONE
	shop_card.rotation = 0.0
	shop_card.modulate = Color.WHITE
	dimmer.modulate = Color.WHITE


func _kill_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()


func _update_cost_labels() -> void:
	for item in _item_nodes:
		item.get_node("Label_Cost").text = "%dG" % _current_price


func _set_offers_enabled(enabled: bool) -> void:
	for item_index in range(_buy_buttons.size()):
		_buy_buttons[item_index].disabled = not enabled
		_item_nodes[item_index].modulate = Color.WHITE if enabled else Color(0.58, 0.58, 0.58, 0.72)


func _set_items_visible(value: bool) -> void:
	item_tip.hide()
	for item in _item_nodes:
		item.visible = value


func _play_shopkeeper_breathing() -> void:
	# Keep the sprite geometry fixed so the outlined raster does not shimmer.
	shopkeeper.modulate = Color.WHITE
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shopkeeper, "modulate", Color(1.012, 1.006, 0.992, 1.0), 3.0)
	tween.tween_property(shopkeeper, "modulate", Color.WHITE, 3.0)
