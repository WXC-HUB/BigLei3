class_name DuelHud
extends Control
## 对战 HUD：左右镜像状态栏、对手迷雾棋盘位、流程说明、冻结遮罩、离开按钮。
##
## 和 main.gd 的 `_build_interface()` 一样走程序化搭建，不做 .tscn。

signal leave_pressed

const OfferCatalog := preload("res://scripts/ui/shop_overlay.gd")
const PlayerStatusView := preload("res://scenes/player_status.tscn")
const MONSTER_SMALL_TEXTURE := preload("res://my_asset/monster_small.png")

const COLOR_INK := Color("f4e8c1")
const COLOR_MUTED := Color("b7bf95")
const COLOR_DANGER := Color("e65a45")
const COLOR_SUCCESS := Color("8fd15b")
const COLOR_PANEL := Color("1c281b")
const DAMAGE_COLOR := Color("ff7864")

const UPGRADE_ICON_SIZE := Vector2(40, 40)
const UPGRADE_COLUMNS := 13
const SPLIT_CENTER_SHIFT := 480.0
const STATUS_SCALE := 0.72
const DIVIDER_HALF_WIDTH := 8.0
const DIVIDER_GLOW := Color(0.96, 0.91, 0.76, 0.42)
const DIVIDER_INK := Color("1a2418")
const DIVIDER_GOLD := Color("f4e8c1")
const DIVIDER_TRIM := Color("d4a84b")
const FLOW_TIP_PLAYING := "标出全部真雷即可清盘 · 每标一雷伤害对手并得金币 · 率先清盘进入中场商店"
const FLOW_TIP_LOBBY := "双方输入同一房间码才能连上 · 连接中可随时返回主界面"

var _opponent_status: Control
var _connection_label: Label
var _opponent_mark_panel: PanelContainer
var _opponent_mark_label: Label
var _opponent_upgrade_grid: GridContainer
var _round_label: Label
var _flow_tip: Label
var _leave_button: Button
var _opponent_slot: OpponentBoardSlot
var _divider: Control
var _damage_feed: Control
var _freeze_dimmer: ColorRect
var _freeze_label: Label
var _freeze_detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9
	_build_divider()
	_build_round_label()
	_build_opponent_board_slot()
	_build_opponent_status()
	_build_flow_tip()
	_build_leave_button()
	_build_damage_feed()
	_build_freeze_layer()
	visible = false


func show_duel(active: bool) -> void:
	visible = active
	if not active:
		set_frozen(false, "", "")
		_leave_button.visible = false
		return
	_leave_button.visible = true
	set_flow_tip(FLOW_TIP_LOBBY)


func set_connection(linked: bool) -> void:
	_connection_label.text = "● 已连接" if linked else "● 未连接"
	_connection_label.add_theme_color_override("font_color", COLOR_SUCCESS if linked else COLOR_DANGER)
	if _opponent_status != null:
		_opponent_status.modulate = Color.WHITE if linked else Color(0.65, 0.65, 0.65, 0.85)
	if linked:
		set_flow_tip(FLOW_TIP_PLAYING)


func set_round(round_index: int, board_width: int, board_height: int) -> void:
	_round_label.text = "第 %d 轮 · %d×%d" % [maxi(round_index, 1), board_width, board_height]
	set_flow_tip(FLOW_TIP_PLAYING)


func set_flow_tip(text: String) -> void:
	if _flow_tip != null:
		_flow_tip.text = text


func refresh_opponent(opponent: Dictionary, total_mines: int) -> void:
	if _opponent_status != null and _opponent_status.has_method("set_health"):
		_opponent_status.call(
			"set_health",
			int(opponent.get("hp", 0)),
			maxi(int(opponent.get("max_hp", 1)), 1)
		)
	if _opponent_status != null and _opponent_status.has_method("set_gold"):
		_opponent_status.call("set_gold", int(opponent.get("gold", 0)))
	_opponent_mark_label.text = "已标 %d / %d" % [
		int(opponent.get("marked_mines", 0)),
		maxi(total_mines, 0),
	]
	_rebuild_upgrades(opponent.get("upgrades", {}) as Dictionary)


func play_incoming_damage(amount: int, target: Vector2) -> void:
	var label := Label.new()
	label.text = "-%d" % maxi(amount, 1)
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", DAMAGE_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_feed.add_child(label)
	var start := (
		_opponent_slot.get_global_rect().get_center()
		if _opponent_slot != null
		else get_viewport_rect().size * Vector2(0.75, 0.5)
	)
	label.global_position = start
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", target, 0.46)
	tween.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func set_frozen(active: bool, message: String, detail: String = "") -> void:
	_freeze_dimmer.visible = active
	_freeze_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_freeze_label.text = message
	_freeze_detail.text = detail
	_freeze_detail.visible = not detail.is_empty()


func set_opponent_board(columns: int, rows: int, cell_size: float, gap: float, center_offset: Vector2) -> void:
	if _opponent_slot == null:
		return
	var panel_size := _opponent_slot.set_board(columns, rows, cell_size, gap)
	_opponent_slot.offset_left = -panel_size.x * 0.5 + SPLIT_CENTER_SHIFT
	_opponent_slot.offset_right = panel_size.x * 0.5 + SPLIT_CENTER_SHIFT
	_opponent_slot.offset_top = -panel_size.y * 0.5 + center_offset.y
	_opponent_slot.offset_bottom = panel_size.y * 0.5 + center_offset.y


func flash_opponent_board() -> void:
	if _opponent_slot != null:
		_opponent_slot.flash()


func _build_round_label() -> void:
	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.add_theme_font_size_override("font_size", 30)
	_round_label.add_theme_color_override("font_color", COLOR_INK)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_round_label.position = Vector2(-124, 18)
	_round_label.custom_minimum_size = Vector2(248, 48)
	add_child(_round_label)


## 右上角用同一套 PlayerStatus，和左上自己的状态栏镜像对称。
func _build_opponent_status() -> void:
	_opponent_status = PlayerStatusView.instantiate()
	_opponent_status.name = "OpponentStatus"
	_opponent_status.scale = Vector2.ONE * STATUS_SCALE
	_opponent_status.position = Vector2(1920.0 - 440.0 * STATUS_SCALE - 24.0, 18.0)
	_opponent_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_status.z_index = 2
	add_child(_opponent_status)
	if _opponent_status.has_method("set_compact_hearts"):
		_opponent_status.call("set_compact_hearts", true)
	if _opponent_status.has_method("set_health"):
		_opponent_status.call("set_health", DuelConfig.START_HP, DuelConfig.START_HP)
	if _opponent_status.has_method("set_gold"):
		_opponent_status.call("set_gold", DuelConfig.START_GOLD)

	_connection_label = _make_label("ConnectionLabel", "● 未连接", 20, COLOR_MUTED)
	_connection_label.position = Vector2(1040, 18)
	_connection_label.z_index = 3
	add_child(_connection_label)

	_opponent_mark_panel = PanelContainer.new()
	_opponent_mark_panel.name = "OpponentMarkPanel"
	_opponent_mark_panel.position = Vector2(1040, 120)
	_opponent_mark_panel.custom_minimum_size = Vector2(280, 56)
	_opponent_mark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opponent_mark_panel.add_theme_stylebox_override("panel", _panel_style())
	# 对战只展示自己的剩余雷/道具；对手标雷进度不再单独占一块。
	_opponent_mark_panel.visible = false
	add_child(_opponent_mark_panel)
	var mark_row := HBoxContainer.new()
	mark_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mark_row.add_theme_constant_override("separation", 10)
	_opponent_mark_panel.add_child(mark_row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.texture = MONSTER_SMALL_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark_row.add_child(icon)
	_opponent_mark_label = _make_label("OpponentMarkLabel", "已标 0 / 0", 22, COLOR_INK)
	mark_row.add_child(_opponent_mark_label)

	var upgrade_panel := PanelContainer.new()
	upgrade_panel.name = "OpponentUpgradePanel"
	upgrade_panel.position = Vector2(1040, 120)
	upgrade_panel.custom_minimum_size = Vector2(840, 64)
	upgrade_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(upgrade_panel)
	var upgrade_row := HBoxContainer.new()
	upgrade_row.add_theme_constant_override("separation", 8)
	upgrade_panel.add_child(upgrade_row)
	upgrade_row.add_child(_make_label("OpponentUpgradeCaption", "已购强化", 18, COLOR_MUTED))
	_opponent_upgrade_grid = GridContainer.new()
	_opponent_upgrade_grid.name = "OpponentUpgradeGrid"
	_opponent_upgrade_grid.columns = UPGRADE_COLUMNS
	upgrade_row.add_child(_opponent_upgrade_grid)


func _build_flow_tip() -> void:
	_flow_tip = _make_label("FlowTipLabel", FLOW_TIP_LOBBY, 22, COLOR_MUTED)
	_flow_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flow_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flow_tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_flow_tip.position = Vector2(-420, -52)
	_flow_tip.custom_minimum_size = Vector2(840, 40)
	_flow_tip.z_index = 3
	add_child(_flow_tip)


func _build_leave_button() -> void:
	_leave_button = Button.new()
	_leave_button.name = "LeaveDuelButton"
	_leave_button.text = "返回主界面"
	_leave_button.custom_minimum_size = Vector2(160, 48)
	_leave_button.position = Vector2(24, 1008)
	# 必须高于冻结遮罩（z=6），否则大厅卡住时点不到取消。
	_leave_button.z_index = 8
	_leave_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_leave_button.pressed.connect(func() -> void: leave_pressed.emit())
	add_child(_leave_button)
	_leave_button.visible = false


func _build_divider() -> void:
	_divider = Control.new()
	_divider.name = "SplitDivider"
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.anchor_left = 0.5
	_divider.anchor_right = 0.5
	_divider.anchor_top = 0.0
	_divider.anchor_bottom = 1.0
	_divider.offset_left = -DIVIDER_HALF_WIDTH
	_divider.offset_right = DIVIDER_HALF_WIDTH
	_divider.offset_top = 52.0
	_divider.offset_bottom = -8.0
	add_child(_divider)

	var glow := ColorRect.new()
	glow.name = "DividerGlow"
	glow.color = DIVIDER_GLOW
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -6.0
	glow.offset_right = 6.0
	_divider.add_child(glow)

	var backing := ColorRect.new()
	backing.name = "DividerBacking"
	backing.color = DIVIDER_INK
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_divider.add_child(backing)

	var gold := ColorRect.new()
	gold.name = "DividerGold"
	gold.color = DIVIDER_GOLD
	gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gold.offset_left = 3.0
	gold.offset_right = -3.0
	_divider.add_child(gold)

	var trim := ColorRect.new()
	trim.name = "DividerTrim"
	trim.color = DIVIDER_TRIM
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trim.offset_left = 6.0
	trim.offset_right = -6.0
	_divider.add_child(trim)


func _build_opponent_board_slot() -> void:
	_opponent_slot = OpponentBoardSlot.new()
	_opponent_slot.name = "OpponentBoardSlot"
	_opponent_slot.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_opponent_slot)


func _build_damage_feed() -> void:
	_damage_feed = Control.new()
	_damage_feed.name = "DamageFeedLayer"
	_damage_feed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_feed.z_index = 4
	add_child(_damage_feed)


func _build_freeze_layer() -> void:
	_freeze_dimmer = ColorRect.new()
	_freeze_dimmer.name = "FreezeDimmer"
	_freeze_dimmer.color = Color(0.02, 0.05, 0.04, 0.62)
	_freeze_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_freeze_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_freeze_dimmer.visible = false
	_freeze_dimmer.z_index = 6
	add_child(_freeze_dimmer)

	var stack := VBoxContainer.new()
	stack.name = "FreezeStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	stack.set_anchors_preset(Control.PRESET_CENTER)
	stack.position = Vector2(-360, -60)
	stack.custom_minimum_size = Vector2(720, 120)
	_freeze_dimmer.add_child(stack)

	_freeze_label = _make_label("FreezeLabel", "", 42, COLOR_INK)
	_freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_freeze_label)

	_freeze_detail = _make_label("FreezeDetailLabel", "", 24, COLOR_MUTED)
	_freeze_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_freeze_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_freeze_detail.custom_minimum_size = Vector2(720, 40)
	stack.add_child(_freeze_detail)


func _rebuild_upgrades(upgrades: Dictionary) -> void:
	for child in _opponent_upgrade_grid.get_children():
		child.queue_free()
	var offers := upgrades.keys()
	offers.sort()
	for offer in offers:
		var offer_index := int(offer)
		if offer_index < 0 or offer_index >= OfferCatalog.OFFER_ICONS.size():
			continue
		var icon := TextureRect.new()
		icon.name = "OpponentUpgradeIcon_%d" % offer_index
		icon.texture = OfferCatalog.OFFER_ICONS[offer_index]
		icon.custom_minimum_size = UPGRADE_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.tooltip_text = OfferCatalog.OFFER_NAMES[offer_index]
		_opponent_upgrade_grid.add_child(icon)
		var count := int(upgrades[offer])
		if count <= 1:
			continue
		var count_label := _make_label("OpponentUpgradeCountLabel_%d" % offer_index, "×%d" % count, 18, COLOR_INK)
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.position = Vector2(-28, -24)
		icon.add_child(count_label)


func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.88)
	style.border_color = Color("3d5136")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	return style
