class_name ShopOverlay
extends Control

signal offer_selected(offer: int)
signal refresh_requested
signal continue_pressed
## 对战的中场休息里，「继续」按钮的语义变成「我准备好了」，走这条信号而不是
## `continue_pressed`——按下之后商店不关，要等对手或倒计时。
signal ready_pressed
## --- 槽位制商店（无尽关的鸟窝）---
## 窝满了还要买鸟时，玩家点了第 slot_index 格：把那一格换成待定的那只。
signal slot_replace_chosen(slot_index: int)
## 玩家按了「算了」：这次购买作废，一分钱没扣。
signal slot_replace_cancelled
signal expand_slots_requested

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

## --- 槽位制商店 ---
## 鸟窝面板贴在货架下方那条空白纸带上（ShopCard 局部坐标，量过：货架底 ≈ 620、
## 「继续前进」按钮顶 ≈ 762，中间这一条正好空着）。左端从 340 起，是为了让开
## 店主手里那颗水晶（屏幕 x ≈ 520–690）。
const NEST_PANEL_RECT := Rect2(340.0, 638.0, 1170.0, 110.0)
const NEST_TITLE_WIDTH := 170.0
const NEST_ACTION_WIDTH := 190.0
const NEST_CHIP_HEIGHT := 84.0
const NEST_CHIP_MAX_WIDTH := 168.0
## 按鸟归类之后最多只有七种，不必再挤到 64 那么窄。
const NEST_CHIP_MIN_WIDTH := 88.0
## 「总数 X/Y」与鸟牌之间那道分割块。
const NEST_DIVIDER_SIZE := Vector2(3.0, 54.0)
## 空格子在 `set_slots()` 的数组里写成这个值。
const NEST_EMPTY := -1
const NEST_INK := Color("493722")
const NEST_INK_SOFT := Color(0.55, 0.47, 0.36)
const NEST_CREAM := Color(0.976, 0.941, 0.855)
const NEST_ACCENT := Color("d4a84b")

## --- 替换弹窗 ---
## 换鸟是这一局里少有的「要想一下」的决定，塞在货架下面那条窄带里做不了主；
## 压暗背景、把窝端到屏幕正中来选。
const REPLACE_COLUMNS := 6
const REPLACE_CHIP_SIZE := Vector2(126.0, 142.0)
const REPLACE_CHIP_GAP := 12.0
const REPLACE_DIM := Color(0.05, 0.04, 0.02, 0.66)
const REPLACE_ENTER_TIME := 0.24

const OFFER_ICONS: Array[Texture2D] = [
	preload("res://my_asset/heart.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_dove.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_super_luck.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_orbital.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_lantern.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_compass.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_crow.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_magpie.png"),
	preload("res://assets/sprites/generated/bird_items/item_bird_tit.png"),
]
const OFFER_NAMES := [
	"血量上限 +1",
	"斑鸠回血 +1",
	"红隼 +1",
	"无敌步数 +1",
	"啄木鸟 +1",
	"十字啄击",
	"夜鹭 +1",
	"随机格数 +1",
	"红尾水鸲 +1",
	"标记格数 +1",
	"小嘴乌鸦 +1",
	"连携雷 +1",
	"长尾山雀 +1",
]
## 槽位牌上印的短名，与 OFFER_NAMES 同序号。占鸟窝格子的只有伙伴类商品，
## 强化类（血量上限、无敌步数……）不占格子，这里留空串。
const OFFER_SHORT_NAMES := [
	"",
	"",
	"红隼",
	"",
	"啄木鸟",
	"",
	"夜鹭",
	"",
	"红尾水鸲",
	"",
	"小嘴乌鸦",
	"灰喜鹊",
	"长尾山雀",
]
const OFFER_DESCRIPTIONS := [
	"生命上限增加 1，并立即恢复 1 点生命",
	"斑鸠每次衔枝回来，多补 1 点生命",
	"1步内无敌，踩中雷不掉血",
	"每只红隼触发时，无敌时间额外 +1 步",
	"清横线上的格子/清竖线上的格子",
	"永久升级：啄木鸟同时清理所在的整行与整列（仅可购买一次）",
	"翻开后随机在周围翻开1个格子（必没有雷）",
	"每只夜鹭触发时，额外在周围翻开1个格子（必没有雷）",
	"自动标出1个雷",
	"每只红尾水鸲额外标记 1 个有雷格子",
	"小嘴乌鸦飞去随机一格掀开偷看，那一格的内容亮 3 秒但不翻开",
	"本盘多一颗连携雷：标中同组任意一颗，灰喜鹊会把整组一并标出",
	"无敌，下一步长尾山雀摔到选中格子上，周围 3×3 一起砸开，踩到的雷直接标出来",
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
## 每件商品的单价：重复购买会把它顶上去（`main.gd` 的 `_offer_price()` 算），这里只
## 负责显示和「买不买得起」。没登记的商品沿用 `_current_price` 这个基础价。
var _offer_prices: Dictionary = {}
var _current_gold := 0
var _transition: Tween
var _owned_offers: Dictionary = {}
var _sold_out_offers: Dictionary = {}
## 买到上限的商品（红隼 3 只、长尾山雀 2 只）：整轮 run 里不再上架，也不参与抽取。
var _exhausted_offers: Dictionary = {}
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
## --- 槽位制商店 ---
var _nest_mode := false
## 每格存一个商品序号，NEST_EMPTY = 空格。调用方（main.gd）是唯一真相，这里只画。
var _nest_slots: Array[int] = []
## 正等着玩家点格子替换的那件商品；-1 = 不在替换态。
var _replacing_offer := -1
var _nest_expand_cost := 0
var _nest_expansions_left := 0
## 一次扩几格。数值在 main.gd，这里拿来印按钮上的字。
var _nest_expand_step := 2
var _nest_panel: PanelContainer
var _nest_title: Label
var _nest_chip_row: HBoxContainer
var _nest_expand_button: Button
var _nest_cancel_button: Button
var _nest_chips: Array[Button] = []
## 鸟窝按鸟归类之后的表，和 `_nest_chips` 一一对应（每种鸟一张牌，不再一格一张）。
var _nest_tally_cache: Array = []
var _replace_modal: Control
var _replace_card: Panel
var _replace_title: Label
var _replace_incoming: Label
var _replace_incoming_icon: TextureRect
var _replace_grid: GridContainer
var _replace_cancel: Button
var _replace_chips: Array[Button] = []
var _replace_tween: Tween


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
	# 上一次开店可能停在「选一只换掉」那一步（玩家直接死了或退了），这里一律清掉。
	_replacing_offer = -1
	_close_replace_modal()
	refresh_button.visible = true
	_current_price = price
	_current_gold = gold
	gold_label.text = "当前金币：%dG" % gold
	_sold_out_offers.clear()
	_roll_offers()
	_can_afford = gold >= price
	_update_cost_labels()
	_set_offers_enabled(true)
	refresh_button.disabled = not _can_afford
	visible = true
	_play_enter()


## 大全商店：13 项一次全摆出来，不刷新。关键在于 `_build_offer_items()` 本来就把
## 13 个槽位都建好了，`_roll_offers()` 只是把没抽中的藏起来——所以「大全」不是新
## 界面，只是跳过那次抽取。
func present_full(gold: int, price: int) -> void:
	_duel_mode = true
	# 对战永远不是无尽关：把鸟窝收起来，免得上一局单机的面板留在画面上。
	set_nest_shop(false)
	_apply_duel_shop_layout()
	_set_greeting_text(GREETING_TEXT)
	_current_price = price
	_current_gold = gold
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
	_set_offers_enabled(true)
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
	_current_gold = gold
	gold_label.text = "当前金币：%dG" % gold
	_can_afford = false
	_set_offers_enabled(true)
	refresh_button.disabled = true


func update_gold(gold: int, price: int) -> void:
	_current_price = price
	_current_gold = gold
	gold_label.text = "当前金币：%dG" % gold
	_can_afford = gold >= price
	_update_cost_labels()
	_set_offers_enabled(true)
	refresh_button.disabled = not _can_afford


func refresh_offers(gold: int, price: int) -> void:
	_current_price = price
	_sold_out_offers.clear()
	_roll_offers()
	update_gold(gold, price)


## 逐件商品的单价表（offer → 价格）。缺席的商品按基础价卖。调用方（`main.gd`）在每次
## present / update_gold 之前灌进来，商店本身不记「买过几次」。
func set_offer_prices(prices: Dictionary) -> void:
	_offer_prices = prices.duplicate()
	_update_cost_labels()
	_set_offers_enabled(true)


func price_for(offer_index: int) -> int:
	return int(_offer_prices.get(offer_index, _current_price))


## 上限商品：买满之后彻底下架——不再被抽中，大全商店里也只剩一个「已满」的牌子。
func set_offer_exhausted(offer_index: int, exhausted: bool) -> void:
	if offer_index < 0:
		return
	if exhausted:
		_exhausted_offers[offer_index] = true
	else:
		_exhausted_offers.erase(offer_index)
	_update_cost_labels()
	_set_offers_enabled(true)


func mark_offer_sold_out(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size() or _owned_offers.has(offer_index):
		return
	_sold_out_offers[offer_index] = true
	_update_cost_labels()
	# 别拿 refresh_button.disabled 当「买得起吗」的替身：大全商店把刷新按钮整个
	# 关了，那样一买完东西整排货就会被连坐禁用。
	_set_offers_enabled(true)


func current_offers() -> Array[int]:
	return _current_offers.duplicate()


func set_offer_owned(offer_index: int, owned: bool) -> void:
	if owned:
		_owned_offers[offer_index] = true
	else:
		_owned_offers.erase(offer_index)
	if offer_index >= 0 and offer_index < _buy_buttons.size():
		_buy_buttons[offer_index].disabled = owned
		_item_nodes[offer_index].get_node("Label_Cost").text = (
			"已购" if owned else "%dG" % price_for(offer_index)
		)
		_item_nodes[offer_index].modulate = Color(0.78, 0.78, 0.78, 0.88) if owned else Color.WHITE


# --- 槽位制商店（鸟窝）---


## 开/关鸟窝面板。无尽关开、其余一律关——关掉之后这套 UI 对别的模式完全不存在。
func set_nest_shop(enabled: bool) -> void:
	_nest_mode = enabled
	if not enabled:
		_replacing_offer = -1
		_close_replace_modal()
		if _nest_panel != null:
			_nest_panel.visible = false
		return
	_build_nest_panel()
	_nest_panel.visible = true
	_apply_nest_visuals()


## 灌一份鸟窝现状：`slots` 每格是商品序号或 NEST_EMPTY，`expand_cost` 是下一次扩建
## 的价钱，`expansions_left` 是还能扩几次（0 就把扩建按钮收起来）。
func set_slots(slots: Array, expand_cost: int, expansions_left: int, per_expansion: int = 2) -> void:
	_nest_slots.clear()
	for entry in slots:
		_nest_slots.append(int(entry))
	_nest_expand_cost = maxi(expand_cost, 0)
	_nest_expansions_left = maxi(expansions_left, 0)
	_nest_expand_step = maxi(per_expansion, 1)
	if not _nest_mode:
		return
	_build_nest_panel()
	_rebuild_nest_chips()
	_apply_nest_visuals()


## 窝满了还要买 `offer_index`：进入替换态。这一步**不扣钱**，扣钱在玩家点了格子之后。
func begin_slot_replacement(offer_index: int) -> void:
	if not _nest_mode:
		return
	_replacing_offer = offer_index
	_build_nest_panel()
	_set_offers_enabled(true)
	_apply_nest_visuals()
	_open_replace_modal()
	_set_greeting_text("鸟窝满了！想让「%s」住进来，得先请走一只。" % _offer_short_name(offer_index))


## 退出替换态（换完了、取消了、或者钱不够）。不发信号，调用方自己知道结果。
func end_slot_replacement() -> void:
	_replacing_offer = -1
	_close_replace_modal()
	_set_greeting_text(GREETING_TEXT)
	continue_button.disabled = false
	refresh_button.disabled = not _can_afford
	_set_offers_enabled(true)
	_apply_nest_visuals()


func is_replacing() -> bool:
	return _replacing_offer >= 0


func replacing_offer() -> int:
	return _replacing_offer


## 替换时能点的是弹窗里那排（下面那条窄带被压暗盖住了）。
func slot_chips() -> Array[Button]:
	return _replace_chips.duplicate() if is_replacing() else _nest_chips.duplicate()


func replace_modal() -> Control:
	return _replace_modal


func nest_panel() -> Control:
	return _nest_panel


func expand_button() -> Button:
	return _nest_expand_button


func _offer_short_name(offer_index: int) -> String:
	if offer_index < 0 or offer_index >= OFFER_SHORT_NAMES.size():
		return ""
	var short_name := String(OFFER_SHORT_NAMES[offer_index])
	return short_name if short_name != "" else String(OFFER_NAMES[offer_index])


func _build_nest_panel() -> void:
	if _nest_panel != null:
		return
	var card := shop_stage.get_node("ShopCard") as Control
	_nest_panel = PanelContainer.new()
	_nest_panel.name = "NestPanel"
	_nest_panel.add_theme_stylebox_override("panel", _nest_panel_style())
	_nest_panel.position = NEST_PANEL_RECT.position
	_nest_panel.custom_minimum_size = NEST_PANEL_RECT.size
	_nest_panel.size = NEST_PANEL_RECT.size
	card.add_child(_nest_panel)

	var row := HBoxContainer.new()
	row.name = "NestRow"
	row.add_theme_constant_override("separation", 14)
	_nest_panel.add_child(row)

	_nest_title = Label.new()
	_nest_title.name = "NestTitleLabel"
	_nest_title.custom_minimum_size = Vector2(NEST_TITLE_WIDTH, 0.0)
	_nest_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nest_title.add_theme_font_size_override("font_size", 26)
	_nest_title.add_theme_color_override("font_color", NEST_CREAM)
	row.add_child(_nest_title)

	var divider := ColorRect.new()
	divider.name = "NestDivider"
	divider.color = Color(NEST_CREAM.r, NEST_CREAM.g, NEST_CREAM.b, 0.32)
	divider.custom_minimum_size = NEST_DIVIDER_SIZE
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

	_nest_chip_row = HBoxContainer.new()
	_nest_chip_row.name = "NestSlotRow"
	_nest_chip_row.add_theme_constant_override("separation", 8)
	_nest_chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_nest_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_nest_chip_row)

	_nest_expand_button = Button.new()
	_nest_expand_button.name = "NestExpandButton"
	_nest_expand_button.custom_minimum_size = Vector2(NEST_ACTION_WIDTH, 62.0)
	_nest_expand_button.focus_mode = Control.FOCUS_NONE
	_nest_expand_button.add_theme_font_size_override("font_size", 22)
	_nest_expand_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nest_expand_button.pressed.connect(func() -> void: expand_slots_requested.emit())
	_nest_expand_button.mouse_entered.connect(_on_expand_hover)
	_nest_expand_button.mouse_exited.connect(_on_item_mouse_exited)
	row.add_child(_nest_expand_button)

	_nest_cancel_button = Button.new()
	_nest_cancel_button.name = "NestCancelButton"
	_nest_cancel_button.text = "算了"
	_nest_cancel_button.custom_minimum_size = Vector2(120.0, 62.0)
	_nest_cancel_button.focus_mode = Control.FOCUS_NONE
	_nest_cancel_button.add_theme_font_size_override("font_size", 22)
	_nest_cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nest_cancel_button.visible = false
	_nest_cancel_button.pressed.connect(_on_nest_cancel_pressed)
	row.add_child(_nest_cancel_button)
	_rebuild_nest_chips()


func _nest_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.06, 0.84)
	style.border_color = Color("8a6a3a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	return style


## 鸟窝按鸟归类：每种一条 {offer, count, slot}。`slot` 是它在窝里的第一格——替换时
## 拿它当落点，因为同一种鸟占哪一格都一样。顺序按第一次出现，于是起手那几只一直排在前面。
func _nest_tally() -> Array:
	var order: Array[int] = []
	var counts := {}
	var first := {}
	for index in _nest_slots.size():
		var offer_index: int = _nest_slots[index]
		if offer_index == NEST_EMPTY:
			continue
		if not counts.has(offer_index):
			counts[offer_index] = 0
			first[offer_index] = index
			order.append(offer_index)
		counts[offer_index] = int(counts[offer_index]) + 1
	var tally := []
	for offer_index in order:
		tally.append({
			"offer": offer_index,
			"count": int(counts[offer_index]),
			"slot": int(first[offer_index]),
		})
	return tally


func nest_tally() -> Array:
	return _nest_tally_cache.duplicate(true)


## 一种鸟一张小牌：头像 + 「名字×几只」。窝能扩到 15 格，一格一张就挤没了；
## 按鸟归类之后最多七张，读起来也直接——玩家关心的是「我有几只夜鹭」。
func _rebuild_nest_chips() -> void:
	if _nest_chip_row == null:
		return
	for chip in _nest_chips:
		_nest_chip_row.remove_child(chip)
		chip.queue_free()
	_nest_chips.clear()
	_nest_tally_cache = _nest_tally()
	var count := maxi(_nest_tally_cache.size(), 1)
	# 扩建按钮扩到头就收起来了，它那块宽度要还给鸟牌。
	var action_room := NEST_ACTION_WIDTH if _nest_expansions_left > 0 else 0.0
	var room := NEST_PANEL_RECT.size.x - NEST_TITLE_WIDTH - NEST_DIVIDER_SIZE.x - action_room - 70.0
	var chip_width := clampf(room / float(count) - 8.0, NEST_CHIP_MIN_WIDTH, NEST_CHIP_MAX_WIDTH)
	var name_font := 18 if chip_width >= 112.0 else 16
	for entry in _nest_tally_cache:
		var slot := int(entry["slot"])
		var chip := Button.new()
		chip.name = "NestBird_%d" % int(entry["offer"])
		chip.custom_minimum_size = Vector2(chip_width, NEST_CHIP_HEIGHT)
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.pressed.connect(_on_nest_chip_pressed.bind(slot))
		chip.mouse_entered.connect(_on_nest_chip_hover.bind(slot))
		chip.mouse_exited.connect(_on_item_mouse_exited)
		_nest_chip_row.add_child(chip)

		var stack := VBoxContainer.new()
		stack.name = "ChipStack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_theme_constant_override("separation", 0)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 5.0
		stack.offset_bottom = -5.0
		chip.add_child(stack)

		var icon := TextureRect.new()
		icon.name = "ChipIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0.0, 44.0)
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)

		var label := Label.new()
		label.name = "ChipNameLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", name_font)
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(label)

		_nest_chips.append(chip)


## 一格牌的皮：住着鸟的是奶油底，空格是浅描边的虚位；替换态整排换成琥珀描边。
func _nest_chip_style(filled: bool, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = NEST_CREAM if filled else Color(0.30, 0.25, 0.17, 0.55)
	style.border_color = NEST_ACCENT if highlighted else (Color("8a6a3a") if filled else Color(0.45, 0.38, 0.27))
	style.set_border_width_all(3 if highlighted else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	return style


func _apply_nest_visuals() -> void:
	if _nest_panel == null:
		return
	var replacing := is_replacing()
	# 替换时底下这条带子收起来：弹窗里已经把同一排鸟端到中央了，留着是重复。
	_nest_panel.visible = _nest_mode and not replacing
	var filled := 0
	for offer_index in _nest_slots:
		if offer_index != NEST_EMPTY:
			filled += 1
	# 归类表随窝变，牌数对不上就说明还没重建过。
	if _nest_chips.size() != _nest_tally().size():
		_rebuild_nest_chips()
	if replacing:
		_nest_title.text = "换掉哪一只？"
		_nest_title.add_theme_color_override("font_color", NEST_ACCENT)
	else:
		_nest_title.text = "总数 %d / %d" % [filled, _nest_slots.size()]
		_nest_title.add_theme_color_override("font_color", NEST_CREAM)
	for index in _nest_chips.size():
		if index >= _nest_tally_cache.size():
			break
		var entry: Dictionary = _nest_tally_cache[index]
		var offer_index := int(entry["offer"])
		var chip := _nest_chips[index]
		var icon := chip.get_node("ChipStack/ChipIcon") as TextureRect
		var label := chip.get_node("ChipStack/ChipNameLabel") as Label
		icon.texture = OFFER_ICONS[offer_index] if offer_index < OFFER_ICONS.size() else null
		label.text = "%s×%d" % [_offer_short_name(offer_index), int(entry["count"])]
		label.add_theme_color_override("font_color", NEST_INK)
		var style := _nest_chip_style(true, replacing)
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			chip.add_theme_stylebox_override(state_name, style)
		chip.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if replacing else Control.CURSOR_ARROW
		)
	if _nest_expand_button != null:
		_nest_expand_button.visible = not replacing and _nest_expansions_left > 0
		_nest_expand_button.text = "扩建 +%d格  %dG" % [
			_nest_expand_step, _nest_expand_cost
		]
		_nest_expand_button.disabled = _current_gold < _nest_expand_cost
	if _nest_cancel_button != null:
		_nest_cancel_button.visible = replacing
	if replacing:
		# 替换没结之前别让玩家溜走：继续和刷新都锁住，只剩「换」或「算了」。
		continue_button.disabled = true
		refresh_button.disabled = true


## 压暗背景 + 屏幕正中的换鸟卡。懒建一次，之后只填内容。
func _build_replace_modal() -> void:
	if _replace_modal != null:
		return
	_replace_modal = Control.new()
	_replace_modal.name = "ReplaceModal"
	_replace_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 整层吃掉点击：替换没落定之前，底下的货架和按钮都不该还能按。
	_replace_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_replace_modal.visible = false
	# 挂在最后：商店自己的元素都在它下面。
	add_child(_replace_modal)

	var dim := ColorRect.new()
	dim.name = "ReplaceDim"
	dim.color = REPLACE_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_replace_modal.add_child(dim)

	_replace_card = Panel.new()
	_replace_card.name = "ReplaceCard"
	_replace_card.add_theme_stylebox_override("panel", _replace_card_style())
	_replace_modal.add_child(_replace_card)

	var column := VBoxContainer.new()
	column.name = "ReplaceColumn"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 28.0
	column.offset_top = 22.0
	column.offset_right = -28.0
	column.offset_bottom = -22.0
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replace_card.add_child(column)

	_replace_title = Label.new()
	_replace_title.name = "ReplaceTitleLabel"
	_replace_title.text = "鸟窝满了，换掉哪一只？"
	_replace_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_replace_title.add_theme_font_size_override("font_size", 38)
	_replace_title.add_theme_color_override("font_color", NEST_CREAM)
	_replace_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_replace_title)

	var incoming_row := HBoxContainer.new()
	incoming_row.name = "ReplaceIncomingRow"
	incoming_row.alignment = BoxContainer.ALIGNMENT_CENTER
	incoming_row.add_theme_constant_override("separation", 10)
	incoming_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(incoming_row)

	_replace_incoming_icon = TextureRect.new()
	_replace_incoming_icon.name = "ReplaceIncomingIcon"
	_replace_incoming_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_replace_incoming_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_replace_incoming_icon.custom_minimum_size = Vector2(56.0, 56.0)
	_replace_incoming_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming_row.add_child(_replace_incoming_icon)

	_replace_incoming = Label.new()
	_replace_incoming.name = "ReplaceIncomingLabel"
	_replace_incoming.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_replace_incoming.add_theme_font_size_override("font_size", 24)
	_replace_incoming.add_theme_color_override("font_color", NEST_ACCENT)
	_replace_incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming_row.add_child(_replace_incoming)

	_replace_grid = GridContainer.new()
	_replace_grid.name = "ReplaceSlotGrid"
	_replace_grid.columns = REPLACE_COLUMNS
	_replace_grid.add_theme_constant_override("h_separation", int(REPLACE_CHIP_GAP))
	_replace_grid.add_theme_constant_override("v_separation", int(REPLACE_CHIP_GAP))
	var grid_center := CenterContainer.new()
	grid_center.name = "ReplaceGridCenter"
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_center.add_child(_replace_grid)
	column.add_child(grid_center)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(button_row)
	_replace_cancel = Button.new()
	_replace_cancel.name = "ReplaceCancelButton"
	_replace_cancel.text = "算了，不换"
	_replace_cancel.custom_minimum_size = Vector2(220.0, 62.0)
	_replace_cancel.focus_mode = Control.FOCUS_NONE
	_replace_cancel.add_theme_font_size_override("font_size", 24)
	_replace_cancel.pressed.connect(_on_nest_cancel_pressed)
	button_row.add_child(_replace_cancel)


func _replace_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.06, 0.97)
	style.border_color = NEST_ACCENT
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 24
	return style


func _open_replace_modal() -> void:
	_build_replace_modal()
	_replace_incoming_icon.texture = (
		OFFER_ICONS[_replacing_offer]
		if _replacing_offer >= 0 and _replacing_offer < OFFER_ICONS.size()
		else null
	)
	_replace_incoming.text = "请「%s」住进来" % _offer_short_name(_replacing_offer)
	_rebuild_replace_chips()
	_layout_replace_card()
	_replace_modal.visible = true
	if _replace_tween != null and _replace_tween.is_valid():
		_replace_tween.kill()
	_replace_modal.modulate.a = 0.0
	_replace_card.pivot_offset = _replace_card.size * 0.5
	_replace_card.scale = Vector2(0.86, 0.86)
	_replace_tween = create_tween().set_parallel(true)
	_replace_tween.tween_property(_replace_modal, "modulate:a", 1.0, REPLACE_ENTER_TIME)
	_replace_tween.tween_property(_replace_card, "scale", Vector2.ONE, REPLACE_ENTER_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_replace_modal() -> void:
	if _replace_tween != null and _replace_tween.is_valid():
		_replace_tween.kill()
	if _replace_modal != null:
		_replace_modal.visible = false


## 卡片按格子数算大小，然后在屏幕上居中。
func _layout_replace_card() -> void:
	var count := maxi(_replace_chips.size(), 1)
	var columns := mini(count, REPLACE_COLUMNS)
	var rows := ceili(float(count) / float(REPLACE_COLUMNS))
	_replace_grid.columns = columns
	var card_size := Vector2(
		float(columns) * REPLACE_CHIP_SIZE.x + float(columns - 1) * REPLACE_CHIP_GAP + 120.0,
		float(rows) * REPLACE_CHIP_SIZE.y + float(rows - 1) * REPLACE_CHIP_GAP + 250.0
	)
	_replace_card.size = card_size
	_replace_card.position = (_replace_modal.size - card_size) * 0.5
	_replace_card.pivot_offset = card_size * 0.5


func _rebuild_replace_chips() -> void:
	for chip in _replace_chips:
		_replace_grid.remove_child(chip)
		chip.queue_free()
	_replace_chips.clear()
	_nest_tally_cache = _nest_tally()
	# 同一种鸟占哪一格都一样，所以弹窗里也按鸟归类：点一种就请走它当中的一只。
	for entry in _nest_tally_cache:
		var offer_index := int(entry["offer"])
		var chip := Button.new()
		chip.name = "ReplaceBird_%d" % offer_index
		chip.custom_minimum_size = REPLACE_CHIP_SIZE
		chip.focus_mode = Control.FOCUS_NONE
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var style := _nest_chip_style(true, true)
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			chip.add_theme_stylebox_override(state_name, style)
		chip.pressed.connect(_on_nest_chip_pressed.bind(int(entry["slot"])))
		_replace_grid.add_child(chip)

		var stack := VBoxContainer.new()
		stack.name = "ChipStack"
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 8.0
		stack.offset_bottom = -8.0
		chip.add_child(stack)

		var icon := TextureRect.new()
		icon.name = "ChipIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = OFFER_ICONS[offer_index] if offer_index < OFFER_ICONS.size() else null
		stack.add_child(icon)

		var label := Label.new()
		label.name = "ChipNameLabel"
		label.text = "%s×%d" % [_offer_short_name(offer_index), int(entry["count"])]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", NEST_INK)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(label)

		_replace_chips.append(chip)


func _on_nest_chip_pressed(slot_index: int) -> void:
	if not is_replacing():
		return
	slot_replace_chosen.emit(slot_index)


func _on_nest_chip_hover(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _nest_slots.size():
		return
	var offer_index := _nest_slots[slot_index]
	if offer_index == NEST_EMPTY:
		_set_greeting_text("空着的窝，买只鸟就住进来啦。")
		return
	if is_replacing():
		_set_greeting_text("点一下：请走「%s」，换「%s」住进来。" % [
			_offer_short_name(offer_index), _offer_short_name(_replacing_offer)
		])
		return
	_set_greeting_text("%s：%s" % [_offer_short_name(offer_index), OFFER_DESCRIPTIONS[offer_index]])


func _on_expand_hover() -> void:
	_set_greeting_text("花 %dG 把鸟窝加 %d 格，还能扩 %d 次。" % [
		_nest_expand_cost, _nest_expand_step, _nest_expansions_left
	])


func _on_nest_cancel_pressed() -> void:
	end_slot_replacement()
	slot_replace_cancelled.emit()


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
	var text := String(OFFER_DESCRIPTIONS[offer_index])
	if _nest_mode and _is_nest_offer(offer_index) and not _nest_slots.has(NEST_EMPTY):
		text += "（鸟窝满了，买下要换走一只）"
	_set_greeting_text(text)


## 这件商品占不占鸟窝格子：有短名的就是伙伴，强化类没有。
func _is_nest_offer(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= OFFER_SHORT_NAMES.size():
		return false
	return String(OFFER_SHORT_NAMES[offer_index]) != ""


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
		elif _exhausted_offers.has(item_index):
			cost_label.text = "已满"
		elif _sold_out_offers.has(item_index):
			cost_label.text = "售罄"
		else:
			cost_label.text = "%dG" % price_for(item_index)
	refresh_button.text = "刷新并补货  %dG" % _current_price


## `enabled` 只是「现在允许交易吗」（退场动画里会整排关掉）；买得起买不起是逐件算的
## ——涨价之后同一排货里便宜的还能买、贵的先灰掉，不能再一刀切。
func _set_offers_enabled(enabled: bool) -> void:
	for item_index in range(_buy_buttons.size()):
		var available := (
			enabled
			# 替换没落定之前，整排货都不接单——不然会同时挂着两笔待定购买。
			and not is_replacing()
			and _current_gold >= price_for(item_index)
			and _current_offers.has(item_index)
			and not _owned_offers.has(item_index)
			and not _exhausted_offers.has(item_index)
			and not _sold_out_offers.has(item_index)
		)
		_buy_buttons[item_index].disabled = not available
		_item_nodes[item_index].modulate = Color.WHITE if available else Color(0.58, 0.58, 0.58, 0.72)
	if _nest_mode:
		_apply_nest_visuals()


func _set_items_visible(value: bool) -> void:
	_set_greeting_text(GREETING_TEXT)
	for item_index in range(_item_slots.size()):
		_item_slots[item_index].visible = value
		_item_nodes[item_index].visible = value


func _roll_offers() -> void:
	var candidates: Array[int] = []
	for offer_index in range(OFFER_NAMES.size()):
		if not _owned_offers.has(offer_index) and not _exhausted_offers.has(offer_index):
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
