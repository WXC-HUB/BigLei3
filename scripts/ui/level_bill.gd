class_name LevelBill
extends Control
## 关卡结算单。它长得就是一张小票：锯齿撕边的纸、抬头是店名、中间一栏「品名／数量／
## 金额」用点线连起来、底下小计与余额之间压一道双实线，右下角盖一个「已结清」的章。
##
## 条目行是运行时拼的（`_make_line()`），因为有几行取决于这一盘打成什么样——连击奖励
## 没拿到就不印那一行，空行会让小票看起来像没结算完。

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")

const INK := Color(0.25, 0.14, 0.07)
const INK_FADED := Color(0.45, 0.33, 0.2)
const INK_DOTS := Color(0.55, 0.44, 0.3, 0.65)
const INK_GOLD := Color(0.68, 0.4, 0.05)
## 得分那一行用一个和金币明显不同的色：这张小票上「G」和「分」是两本账，
## 同色印出来玩家会把用时奖励当成又发了一笔钱。
const INK_SCORE := Color(0.16, 0.38, 0.52)
const PAPER := Color(0.97, 0.94, 0.85)
const EDGE := Color(0.38, 0.24, 0.12)
## 撕边的一颗齿：宽 24、高 11，从纸的上下两条边往外戳。
const TOOTH_WIDTH := 24.0
const TOOTH_HEIGHT := 11.0
const QTY_COLUMN_WIDTH := 96.0
const AMOUNT_COLUMN_WIDTH := 124.0
const LINE_FONT_SIZE := 25

@onready var panel: PanelContainer = $Center/Panel
@onready var torn_edges: Control = $Center/Panel/TornEdges
@onready var shop_label: Label = $Center/Panel/Margin/Stack/Shop
@onready var serial_label: Label = $Center/Panel/Margin/Stack/Meta/Serial
@onready var counter_label: Label = $Center/Panel/Margin/Stack/Meta/Counter
@onready var columns_row: HBoxContainer = $Center/Panel/Margin/Stack/Columns
@onready var lines: VBoxContainer = $Center/Panel/Margin/Stack/Lines
@onready var subtotal_row: HBoxContainer = $Center/Panel/Margin/Stack/Subtotal
@onready var total_row: HBoxContainer = $Center/Panel/Margin/Stack/Total
@onready var continue_button: Button = $Center/Panel/Margin/Stack/Continue

## 得分行是运行时插进 Stack 的，位置在「账户余额」和「继续」之间。
var _score_row: HBoxContainer


func _ready() -> void:
	visible = false
	ButtonMotion.bind(continue_button, continue_button, -1.0)
	_build_header_row()
	_build_summary_rows()
	_build_score_row()
	torn_edges.draw.connect(_draw_torn_edges)
	torn_edges.resized.connect(torn_edges.queue_redraw)
	for rule_name in ["RuleTop", "RuleHead", "RuleSum", "RuleTotal"]:
		var rule := $Center/Panel/Margin/Stack.get_node(rule_name) as Control
		rule.draw.connect(_draw_rule.bind(rule, rule_name))
		rule.resized.connect(rule.queue_redraw)


## `seconds_used` / `time_bonus` 是这一盘的用时和它换来的分，其余各行仍然是金币。
##
## 无尽关走另一套口径：分数全来自排雷，用时不结算。那时 `mines_mode` 为真，得分行
## 改印 `scored_mines` 枚雷换来的 `mine_points` 分——照旧只有这一行和「分」有关。
func present(
	level: int,
	flagged_mines: int,
	night_master_fish: int,
	combo_bonus_gold: int,
	clear_bonus_gold: int,
	total_gold: int,
	seconds_used: int = 0,
	time_bonus: int = 0,
	scored_mines: int = 0,
	mine_points: int = 0,
	mines_mode: bool = false
) -> void:
	serial_label.text = "单号 No.%04d" % level
	counter_label.text = "第 %d 关" % level
	for child in lines.get_children():
		child.queue_free()
		lines.remove_child(child)
	_add_line("Mines", "正确标记雷", flagged_mines, flagged_mines)
	if night_master_fish > 0:
		_add_line("NightMasterFish", "夜师傅吃掉的鱼", night_master_fish, night_master_fish)
	if combo_bonus_gold > 0:
		_add_line("ComboBonus", "连击奖励", 1, combo_bonus_gold)
	_add_line("ClearBonus", "通关奖励", 1, clear_bonus_gold)
	var subtotal := flagged_mines + night_master_fish + maxi(combo_bonus_gold, 0) + clear_bonus_gold
	_set_row_amount(subtotal_row, "+%dG" % subtotal)
	_set_row_amount(total_row, "%dG" % total_gold)
	if mines_mode:
		_set_mine_score_row(scored_mines, mine_points)
	else:
		_set_score_row(seconds_used, time_bonus)
	continue_button.disabled = true
	visible = true
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var enter := create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(panel, "scale", Vector2.ONE, 0.3)
	enter.tween_property(panel, "modulate:a", 1.0, 0.18)
	await enter.finished
	continue_button.disabled = false
	await continue_button.pressed
	continue_button.disabled = true
	var exit := create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(panel, "scale", Vector2(0.92, 0.92), 0.18)
	exit.tween_property(panel, "modulate:a", 0.0, 0.16)
	await exit.finished
	visible = false
	continue_button.disabled = false
	panel.scale = Vector2.ONE
	panel.modulate = Color.WHITE


## 一条账目：品名靠左，点线把它和右边的「数量／金额」两栏连起来。两栏宽度写死，所以
## 无论几行，金额的个位数都对得齐——小票就是靠这个对齐看起来才像小票。
func _make_line(row_name: String, title: String, ink: Color, font_size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 10)
	# 小计和余额那两行是直接塞进 HBox 里的，不撑满就会缩成一团、金额跑到栏位左边去。
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = title
	name_label.add_theme_color_override("font_color", ink)
	name_label.add_theme_font_size_override("font_size", font_size)
	row.add_child(name_label)

	var dots := Label.new()
	dots.name = "Dots"
	dots.text = "·".repeat(80)
	dots.clip_text = true
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.add_theme_color_override("font_color", INK_DOTS)
	dots.add_theme_font_size_override("font_size", font_size)
	row.add_child(dots)

	var qty := Label.new()
	qty.name = "Qty"
	qty.custom_minimum_size.x = QTY_COLUMN_WIDTH
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty.add_theme_color_override("font_color", ink)
	qty.add_theme_font_size_override("font_size", font_size)
	row.add_child(qty)

	var amount := Label.new()
	amount.name = "Amount"
	amount.custom_minimum_size.x = AMOUNT_COLUMN_WIDTH
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_color_override("font_color", ink)
	amount.add_theme_font_size_override("font_size", font_size)
	row.add_child(amount)
	return row


func _add_line(row_name: String, title: String, quantity: int, gold: int) -> void:
	var row := _make_line(row_name, title, INK, LINE_FONT_SIZE)
	(row.get_node("Qty") as Label).text = "× %d" % quantity
	(row.get_node("Amount") as Label).text = "+%dG" % gold
	lines.add_child(row)


## 表头和小计/余额这三行不是账目，但要用同一套栏宽，所以照样走 `_make_line()`，只是把
## 点线抹掉、字色字号换掉。
func _build_header_row() -> void:
	var header := _make_line("Header", "品名", INK_FADED, 20)
	(header.get_node("Dots") as Label).text = ""
	(header.get_node("Qty") as Label).text = "数量"
	(header.get_node("Amount") as Label).text = "金额"
	columns_row.add_child(header)


func _build_summary_rows() -> void:
	var subtotal := _make_line("SubtotalLine", "本关小计", INK, LINE_FONT_SIZE)
	(subtotal.get_node("Qty") as Label).text = ""
	subtotal_row.add_child(subtotal)

	var total := _make_line("TotalLine", "账户余额", INK_GOLD, 32)
	(total.get_node("Dots") as Label).text = ""
	(total.get_node("Qty") as Label).text = ""
	total_row.add_child(total)


## 用时奖励：品名写清楚衰减到保底要多久，省得玩家以为「越慢越好」或者「拖到 0 分」。
func _build_score_row() -> void:
	var stack := $Center/Panel/Margin/Stack as VBoxContainer
	_score_row = _make_line("ScoreLine", "用时奖励", INK_SCORE, 28)
	(_score_row.get_node("Dots") as Label).add_theme_color_override("font_color", INK_DOTS)
	stack.add_child(_score_row)
	# 紧跟「账户余额」、排在收尾语之前：它不属于金币小计，但仍是本关结算的一部分。
	# 插到 Footer 前面而不是 Continue 前面——「谢谢惠顾」是小票的落款，
	# 落款后面再挂一行账，读起来就是没结算完。
	var footer := stack.get_node_or_null("Footer") as Control
	var anchor := footer.get_index() if footer != null else continue_button.get_index()
	stack.move_child(_score_row, anchor)


func _set_score_row(seconds_used: int, time_bonus: int) -> void:
	if _score_row == null:
		return
	(_score_row.get_node("Name") as Label).text = "用时奖励"
	(_score_row.get_node("Qty") as Label).text = "%d 秒" % maxi(seconds_used, 0)
	(_score_row.get_node("Amount") as Label).text = "+%d 分" % maxi(time_bonus, 0)


## 无尽关的得分行：品名、数量、金额三格全换成排雷口径，别让玩家在一张只按排雷
## 计分的小票上读到「用时奖励 +0 分」。
func _set_mine_score_row(scored_mines: int, mine_points: int) -> void:
	if _score_row == null:
		return
	(_score_row.get_node("Name") as Label).text = "排雷得分"
	(_score_row.get_node("Qty") as Label).text = "%d 枚" % maxi(scored_mines, 0)
	(_score_row.get_node("Amount") as Label).text = "+%d 分" % maxi(mine_points, 0)


func _set_row_amount(row: HBoxContainer, text: String) -> void:
	if row.get_child_count() == 0:
		return
	((row.get_child(0) as HBoxContainer).get_node("Amount") as Label).text = text


## 四道横线：抬头下面一道实线，表头和小计前后各一道点线，余额上面压一道双实线——账单
## 的「合计」永远是双线，这一笔比多写一行字管用。
func _draw_rule(rule: Control, rule_name: String) -> void:
	var width := rule.size.x
	var middle := rule.size.y * 0.5
	match rule_name:
		"RuleTop":
			rule.draw_line(Vector2(0, middle), Vector2(width, middle), EDGE, 3.0)
		"RuleTotal":
			rule.draw_line(Vector2(0, middle - 4.0), Vector2(width, middle - 4.0), EDGE, 2.0)
			rule.draw_line(Vector2(0, middle + 4.0), Vector2(width, middle + 4.0), EDGE, 2.0)
		_:
			var dash := 9.0
			var gap := 7.0
			var x := 0.0
			while x < width:
				rule.draw_line(
					Vector2(x, middle), Vector2(minf(x + dash, width), middle), INK_DOTS, 2.0
				)
				x += dash + gap


## 纸的上下两条边是撕开的：一排三角齿顶在外面，齿尖用纸色填、再沿折线描一道边。左右
## 两条边由 StyleBox 的边框画，所以这里只管上下。
func _draw_torn_edges() -> void:
	var width := torn_edges.size.x
	var height := torn_edges.size.y
	var teeth := maxi(ceili(width / TOOTH_WIDTH), 1)
	for is_bottom in [false, true]:
		var direction := 1.0 if is_bottom else -1.0
		var baseline := height - 4.0 if is_bottom else 4.0
		var edge_line := PackedVector2Array()
		for index in range(teeth + 1):
			var x := minf(index * TOOTH_WIDTH, width)
			edge_line.append(Vector2(x, baseline - direction * 4.0))
			if index < teeth:
				var peak_x := minf(index * TOOTH_WIDTH + TOOTH_WIDTH * 0.5, width)
				edge_line.append(Vector2(peak_x, baseline + direction * TOOTH_HEIGHT))
		var band := PackedVector2Array(edge_line)
		band.append(Vector2(width, baseline - direction * 6.0))
		band.append(Vector2(0.0, baseline - direction * 6.0))
		torn_edges.draw_colored_polygon(band, PAPER)
		torn_edges.draw_polyline(edge_line, EDGE, 3.0)
