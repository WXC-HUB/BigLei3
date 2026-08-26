class_name DuelHud
extends Control
## 对战 HUD：右上角的对手面板、受击飘字、回合冻结遮罩、轮次标签。
##
## 和 main.gd 的 `_build_interface()` 一样走程序化搭建，不做 .tscn —— 这个项目的
## UI 惯例就是代码里搭，混两套反而更难找。节点名与 FEAT-001 的 DuelHud 线框一一对应。

signal ready_pressed

const OfferCatalog := preload("res://scripts/ui/shop_overlay.gd")

const COLOR_INK := Color("f4e8c1")
const COLOR_MUTED := Color("b7bf95")
const COLOR_DANGER := Color("e65a45")
const COLOR_SUCCESS := Color("8fd15b")
const COLOR_PANEL := Color("1c281b")
const DAMAGE_COLOR := Color("ff7864")

## 分屏后对手面板从右上角的竖排卡片压成横跨右半屏顶部的一条。宽度取半屏减两边
## 留白；13 个强化图标塞不进同一行，所以拆成上下两行。
const PANEL_SIZE := Vector2(880, 120)
const PANEL_MARGIN := Vector2(40, 24)
const UPGRADE_ICON_SIZE := Vector2(44, 44)
const UPGRADE_COLUMNS := 13
const SPLIT_CENTER_SHIFT := 480.0

var _opponent_panel: PanelContainer
var _connection_label: Label
var _opponent_health_bar: ProgressBar
var _opponent_health_label: Label
var _opponent_mine_label: Label
var _opponent_gold_label: Label
var _opponent_upgrade_grid: GridContainer
var _round_label: Label
var _opponent_slot: OpponentBoardSlot
var _divider: ColorRect
var _damage_feed: Control
var _freeze_dimmer: ColorRect
var _freeze_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 9
	_build_divider()
	_build_round_label()
	_build_opponent_board_slot()
	_build_opponent_panel()
	_build_damage_feed()
	_build_freeze_layer()
	visible = false


## 整个对战 HUD 的总开关。单机路径下它一直是 false，一个像素都不该露出来。
func show_duel(active: bool) -> void:
	visible = active
	if not active:
		set_frozen(false, "")


func set_connection(linked: bool) -> void:
	_connection_label.text = "● 已连接" if linked else "● 已断开"
	_connection_label.add_theme_color_override("font_color", COLOR_SUCCESS if linked else COLOR_DANGER)
	_opponent_panel.modulate = Color.WHITE if linked else Color(0.6, 0.6, 0.6, 0.8)


func set_round(round_index: int, board_width: int, board_height: int) -> void:
	_round_label.text = "第 %d 轮 · %d×%d" % [maxi(round_index, 1), board_width, board_height]


## 对手快照刷新。`total_mines` 用本地棋盘的雷数 —— 双方同盘，雷数必然相同。
func refresh_opponent(opponent: Dictionary, total_mines: int) -> void:
	var hp := int(opponent.get("hp", 0))
	var max_hp := maxi(int(opponent.get("max_hp", 1)), 1)
	_opponent_health_bar.max_value = max_hp
	_opponent_health_bar.value = hp
	_opponent_health_label.text = "%d / %d" % [hp, max_hp]
	_opponent_mine_label.text = "已标 %d / %d" % [int(opponent.get("marked_mines", 0)), maxi(total_mines, 0)]
	_opponent_gold_label.text = "%dG" % int(opponent.get("gold", 0))
	_rebuild_upgrades(opponent.get("upgrades", {}))


## 一条受击飘字。Q10 定了逐个结算，所以调用方收到 N 条伤害就调 N 次。
func play_incoming_damage(amount: int, target: Vector2) -> void:
	var label := Label.new()
	label.text = "-%d" % maxi(amount, 1)
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", DAMAGE_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_feed.add_child(label)
	# 起点在右屏对手棋盘位的中心，终点在传进来的血条位置 —— 飘字横跨中缝飞过来，
	# 自己就说明了「这一下是对面打的」。
	var origin: Control = _opponent_slot if _opponent_slot != null else _opponent_panel
	var start := origin.get_global_rect().get_center()
	label.global_position = start
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position", target, 0.46)
	tween.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func set_frozen(active: bool, message: String) -> void:
	_freeze_dimmer.visible = active
	# 冻结时必须真的吃掉输入，否则玩家还能继续点格子往对面送伤害。
	_freeze_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_freeze_label.text = message


func _build_round_label() -> void:
	_round_label = Label.new()
	_round_label.name = "RoundLabel"
	_round_label.add_theme_font_size_override("font_size", 30)
	_round_label.add_theme_color_override("font_color", COLOR_INK)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_round_label.position = Vector2(-124, 24)
	_round_label.custom_minimum_size = Vector2(248, 56)
	add_child(_round_label)


func _build_opponent_panel() -> void:
	_opponent_panel = PanelContainer.new()
	_opponent_panel.name = "OpponentPanel"
	_opponent_panel.add_theme_stylebox_override("panel", _panel_style())
	# 锚在右上：右半屏本来就贴着视口右缘，用锚点比用绝对坐标更抗视口拉伸。
	_opponent_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_opponent_panel.offset_left = -PANEL_SIZE.x - PANEL_MARGIN.x
	_opponent_panel.offset_right = -PANEL_MARGIN.x
	_opponent_panel.offset_top = PANEL_MARGIN.y
	_opponent_panel.offset_bottom = PANEL_MARGIN.y + PANEL_SIZE.y
	_opponent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_opponent_panel)

	var column := VBoxContainer.new()
	column.name = "OpponentColumn"
	column.add_theme_constant_override("separation", 6)
	_opponent_panel.add_child(column)

	# 第一行：身份 + 连接 + 血量 + 标雷进度 + 金币。全是 HUD 级聚合量，不含任何
	# 棋盘空间信息 —— 右屏的棋盘位是全遮的，两者并不矛盾。
	var header := HBoxContainer.new()
	header.name = "OpponentHeader"
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	header.add_child(_make_label("OpponentNameLabel", "对手", 24, COLOR_INK))
	_connection_label = _make_label("ConnectionLabel", "● 未连接", 20, COLOR_MUTED)
	header.add_child(_connection_label)

	_opponent_health_bar = ProgressBar.new()
	_opponent_health_bar.name = "OpponentHealthBar"
	_opponent_health_bar.custom_minimum_size = Vector2(180, 24)
	_opponent_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_opponent_health_bar.max_value = DuelConfig.START_HP
	_opponent_health_bar.value = DuelConfig.START_HP
	_opponent_health_bar.show_percentage = false
	header.add_child(_opponent_health_bar)

	_opponent_health_label = _make_label("OpponentHealthLabel", "—", 22, COLOR_INK)
	header.add_child(_opponent_health_label)
	_opponent_mine_label = _make_label("OpponentMineLabel", "已标 0 / 0", 22, COLOR_INK)
	header.add_child(_opponent_mine_label)
	_opponent_gold_label = _make_label("OpponentGoldLabel", "0G", 22, COLOR_INK)
	_opponent_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_opponent_gold_label)

	# 第二行：已购强化。13 个图标即便缩到 44px 也占 572px，和第一行挤不进同一条。
	var upgrade_row := HBoxContainer.new()
	upgrade_row.name = "OpponentUpgradeRow"
	upgrade_row.add_theme_constant_override("separation", 10)
	column.add_child(upgrade_row)
	upgrade_row.add_child(_make_label("OpponentUpgradeCaption", "已购强化", 18, COLOR_MUTED))
	_opponent_upgrade_grid = GridContainer.new()
	_opponent_upgrade_grid.name = "OpponentUpgradeGrid"
	_opponent_upgrade_grid.columns = UPGRADE_COLUMNS
	upgrade_row.add_child(_opponent_upgrade_grid)


## 两屏之间的分隔线。纯装饰，但没有它两块半屏会糊成一片。
func _build_divider() -> void:
	_divider = ColorRect.new()
	_divider.name = "SplitDivider"
	_divider.color = Color("3d5136")
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.anchor_left = 0.5
	_divider.anchor_right = 0.5
	_divider.anchor_top = 0.0
	_divider.anchor_bottom = 1.0
	_divider.offset_left = -2.0
	_divider.offset_right = 2.0
	_divider.offset_top = 60.0
	_divider.offset_bottom = -12.0
	add_child(_divider)


func _build_opponent_board_slot() -> void:
	_opponent_slot = OpponentBoardSlot.new()
	_opponent_slot.name = "OpponentBoardSlot"
	# 与左屏棋盘用同一套锚点约定：中心锚 + 对称 offset，只是水平位移取 +480。
	_opponent_slot.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_opponent_slot)


## 按对手棋盘的行列与格子边长重排右屏那块位。参数全部来自**本地**棋盘 —— 双方同
## 种子同曲线，尺寸必然相同，所以这里一个网络字节都不需要。
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

	_freeze_label = _make_label("FreezeLabel", "", 42, COLOR_INK)
	_freeze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_freeze_label.set_anchors_preset(Control.PRESET_CENTER)
	_freeze_label.position = Vector2(-320, -30)
	_freeze_label.custom_minimum_size = Vector2(640, 60)
	_freeze_dimmer.add_child(_freeze_label)


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
			# 每个图标都挂个「×1」纯属噪音，只有叠了才值得标。
			continue
		var count_label := _make_label("OpponentUpgradeCountLabel_%d" % offer_index, "×%d" % count, 20, COLOR_INK)
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.position = Vector2(-30, -26)
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
	style.set_content_margin_all(16)
	return style
