class_name StageBadge
extends Button
## 悬浮牌（Stage Badge）——关卡头顶那张卡片。
##
## 根节点直接用 Button：点击进关、悬停高亮、未解锁 disabled 全部由 Button 原生提供，
## 不用自己写 gui_input，也不用自己管"按下算不算点"。
##
## 四态图标是**程序化画出来的几何形状**（对勾 / 三角 / 锁 / 时钟），不是四张纹理。这样
## 「不得仅依赖颜色传达」这条项目约束由形状本身兑现——把屏幕转成灰度，四个态照样分得
## 清。颜色只是加强。

signal hover_changed(entered: bool)
signal leaderboard_requested(stage_id: String)

const WIDTH := 168.0
const HEIGHT := 100.0
const TAIL_HEIGHT := 12.0
const HOVER_SCALE := 1.14
const HOVER_ROTATION_DEG := -3.4
const HOVER_DURATION := 0.14

enum State {CLEARED, AVAILABLE, LOCKED, IN_PROGRESS}

const STATE_WORDS := {
	State.CLEARED: "已通关",
	State.AVAILABLE: "可挑战",
	State.LOCKED: "未解锁",
	State.IN_PROGRESS: "进行中",
}
## 四态强调色：都往灰里收一档，白卡上只作小圆徽与描边，不铺大面。
const STATE_ACCENTS := {
	State.CLEARED: Color(0.36, 0.55, 0.30),
	State.AVAILABLE: Color(0.85, 0.58, 0.16),
	State.LOCKED: Color(0.64, 0.63, 0.60),
	State.IN_PROGRESS: Color(0.30, 0.48, 0.70),
}

## 和 world_map.gd 同一套「陈列柜」纸色：白卡、暖灰细边、墨字。
const PAPER := Color(1.0, 0.996, 0.988)
const PAPER_EDGE := Color(0.820, 0.792, 0.735)
const INK := Color(0.184, 0.165, 0.125)
const INK_SOFT := Color(0.478, 0.427, 0.349)
const CHIP := Color(0.945, 0.935, 0.910)
const SCORE_INK := Color(0.545, 0.365, 0.090)
const CARD_SHADOW := Color(0.18, 0.16, 0.12, 0.12)

var stage_id := ""

var _state := State.AVAILABLE
var _icon: StateIcon
var _tail: Tail
var _name_label: Label
var _round_label: Label
var _status_label: Label
var _score_label: Label
var _dim: ColorRect
var _hover_tween: Tween
var _hovering := false
var _high_score := 0
## 无尽关的牌子：盘数芯片写「无尽」，记录行写「最远 N 盘」。
var _best_round := 0
var _endless := false
## 教学关没有榜：记录行不写「右键看榜」，右键也不发信号。
var _ranked := true


func _init() -> void:
	name = "StageBadge"
	custom_minimum_size = Vector2(WIDTH, HEIGHT + TAIL_HEIGHT)
	size = custom_minimum_size
	# 旋转/放大绕尖角，悬停时牌子往上长、尖角仍钉在地格上。
	pivot_offset = Vector2(WIDTH * 0.5, HEIGHT + TAIL_HEIGHT)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 牌子自己是按钮，但它下面那根小尖角不该吃点击——尖角画在牌体之外，
	# clip_contents 关掉才画得出来。
	clip_contents = false


func _ready() -> void:
	_build_styles()
	_build_children()
	set_stage_state(_state)
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if stage_id != "" and _ranked:
			leaderboard_requested.emit(stage_id)
		accept_event()


## 牌体的皮：纸底 + 棕描边 + 圆角。四个态共用同一张皮，只有描边色跟着状态走，
## 所以 hover/pressed 也一起 duplicate 出来改，免得悬停时描边跳回默认色。
func _build_styles() -> void:
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER
		box.border_color = PAPER_EDGE
		box.set_border_width_all(2)
		box.set_corner_radius_all(14)
		box.content_margin_bottom = TAIL_HEIGHT
		box.shadow_color = CARD_SHADOW
		box.shadow_size = 10
		box.shadow_offset = Vector2(0.0, 4.0)
		match state_name:
			"hover":
				box.bg_color = Color(1.0, 1.0, 1.0)
				box.shadow_size = 16
				box.shadow_offset = Vector2(0.0, 7.0)
			"pressed":
				box.bg_color = Color(0.955, 0.945, 0.920)
				box.shadow_size = 4
				box.shadow_offset = Vector2(0.0, 2.0)
			"disabled":
				box.bg_color = Color(0.965, 0.958, 0.940)
				box.shadow_size = 4
		add_theme_stylebox_override(state_name, box)


func _build_children() -> void:
	_tail = Tail.new()
	_tail.position = Vector2(WIDTH * 0.5 - 11.0, HEIGHT - 2.0)
	_tail.size = Vector2(22.0, TAIL_HEIGHT + 2.0)
	add_child(_tail)

	_icon = StateIcon.new()
	_icon.position = Vector2(11.0, 9.0)
	_icon.size = Vector2(30.0, 30.0)
	add_child(_icon)

	_name_label = Label.new()
	_name_label.name = "BadgeNameLabel"
	_name_label.position = Vector2(48.0, 6.0)
	_name_label.size = Vector2(112.0, 34.0)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", INK)
	add_child(_name_label)

	var chip := Panel.new()
	chip.name = "RoundChip"
	chip.position = Vector2(11.0, 44.0)
	chip.size = Vector2(80.0, 28.0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = CHIP
	chip_box.set_corner_radius_all(9)
	chip.add_theme_stylebox_override("panel", chip_box)
	add_child(chip)

	_round_label = Label.new()
	_round_label.name = "BadgeRoundLabel"
	_round_label.position = Vector2(11.0, 44.0)
	_round_label.size = Vector2(80.0, 28.0)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.add_theme_color_override("font_color", INK)
	add_child(_round_label)

	_status_label = Label.new()
	_status_label.name = "BadgeStatusLabel"
	_status_label.position = Vector2(98.0, 44.0)
	_status_label.size = Vector2(64.0, 28.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", INK_SOFT)
	add_child(_status_label)

	_score_label = Label.new()
	_score_label.name = "BadgeHighScoreLabel"
	_score_label.position = Vector2(11.0, 74.0)
	_score_label.size = Vector2(150.0, 20.0)
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", SCORE_INK)
	add_child(_score_label)
	_refresh_score_label()

	# 锁定态不压黑：罩一层台面色的毛玻璃，牌子退成"未开封"的浅印，灰度下也能分辨。
	_dim = ColorRect.new()
	_dim.name = "BadgeLockOverlay"
	_dim.color = Color(0.929, 0.918, 0.886, 0.52)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(WIDTH, HEIGHT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)


## 把关卡表里的一条记录贴到牌子上。名字与目标盘数只在这里写一次——它们不会在运行中变。
func bind(stage: Dictionary) -> void:
	stage_id = String(stage.get("id", ""))
	_endless = bool(stage.get("endless", false))
	_ranked = StageTable.has_leaderboard(stage_id)
	if _name_label == null:
		# 还没进场景树就被 bind 的情况：先记下来，_ready 之后再补。
		await ready
	_name_label.text = "%d · %s" % [int(stage.get("order", 0)), String(stage.get("name", ""))]
	if _endless:
		# 无尽关没有目标盘数：芯片写「无尽」，右键看榜的提示挪进 tooltip（记录行要腾给最远盘数）。
		_round_label.text = "无尽"
		tooltip_text = "%s · 盘面随机、越打越难，没有终点；右键看榜" % String(stage.get("name", ""))
	else:
		_round_label.text = "%d 盘" % int(stage.get("target_round", 0))
		tooltip_text = "%s · 打完全部 %d 盘即通关" % [
			String(stage.get("name", "")), int(stage.get("target_round", 0))
		]
	_refresh_score_label()


func set_high_score(value: int) -> void:
	_high_score = maxi(value, 0)
	_refresh_score_label()


## 无尽关专用：最远打到第几盘。其他关忽略。
func set_best_round(value: int) -> void:
	_best_round = maxi(value, 0)
	_refresh_score_label()


func _refresh_score_label() -> void:
	if _score_label == null:
		return
	if _endless:
		var round_text := ("最远 %d 盘" % _best_round) if _best_round > 0 else "最远 —"
		var best_text := ("最高 %s" % _format_score(_high_score)) if _high_score > 0 else "最高 —"
		_score_label.add_theme_font_size_override("font_size", 13)
		_score_label.text = "%s · %s" % [round_text, best_text]
		_score_label.add_theme_color_override(
			"font_color", SCORE_INK if (_best_round > 0 or _high_score > 0) else INK_SOFT
		)
		return
	_score_label.add_theme_font_size_override("font_size", 14)
	var hint := " · 右键看榜" if _ranked else ""
	if _high_score > 0:
		_score_label.text = "最高 %s%s" % [_format_score(_high_score), hint]
		_score_label.add_theme_color_override("font_color", SCORE_INK)
	else:
		_score_label.text = "最高 —%s" % hint
		_score_label.add_theme_color_override("font_color", INK_SOFT)


func _format_score(value: int) -> String:
	var raw := str(maxi(value, 0))
	var out := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = raw[i] + out
		count += 1
	return out


func set_stage_state(state: int) -> void:
	_state = state
	if _icon == null:
		return
	var accent: Color = STATE_ACCENTS[state]
	_icon.set_shape(state, accent)
	_status_label.text = String(STATE_WORDS[state])
	_dim.visible = state == State.LOCKED
	# 未解锁的牌子交给 Button 自己吃掉点击，不用在回调里再判一次。
	disabled = state == State.LOCKED
	# 描边只在「等你来点」的两态上色（可挑战 / 进行中）；已通关、未解锁都退回暖灰细边，
	# 一屏六张牌里只有该动手的那几张在说话。
	var loud := state == State.AVAILABLE or state == State.IN_PROGRESS
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := get_theme_stylebox(state_name) as StyleBoxFlat
		if box != null:
			box.border_color = accent if loud else PAPER_EDGE
	if _tail != null:
		_tail.edge = accent if loud else PAPER_EDGE
		_tail.queue_redraw()


func current_state() -> int:
	return _state


func _on_hover_changed(entered: bool) -> void:
	if disabled and entered:
		return
	set_hover_visual(entered)
	hover_changed.emit(entered)


## 由世界地图统一驱动：悬停牌子或绑定地格时都会走到这里。
func set_hover_visual(active: bool) -> void:
	if disabled:
		active = false
	if _hovering == active:
		return
	_hovering = active
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_scale := Vector2(HOVER_SCALE, HOVER_SCALE) if active else Vector2.ONE
	var target_rot := deg_to_rad(HOVER_ROTATION_DEG) if active else 0.0
	var duration := HOVER_DURATION if active else 0.16
	_hover_tween.tween_property(self, "scale", target_scale, duration)
	_hover_tween.tween_property(self, "rotation", target_rot, duration)


func is_hovering() -> bool:
	return _hovering

## 牌子底下那根指向地格的小尖角。单独一个节点是为了让它画到牌体矩形之外，
## 又不参与 Button 的点击区。
class Tail extends Control:
	var edge := StageBadge.PAPER_EDGE

	func _init() -> void:
		name = "BadgeTail"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tip := Vector2(size.x * 0.5, size.y)
		var left := Vector2(0.0, 0.0)
		var right := Vector2(size.x, 0.0)
		draw_colored_polygon([left, right, tip], StageBadge.PAPER)
		draw_line(left, tip, edge, 2.5)
		draw_line(right, tip, edge, 2.5)


## 四态图标。全部用几何图形画：对勾两笔、实心三角、锁（方块+半环）、时钟（圆环+两针）。
## 灰度下也能分辨，满足"不得仅依赖颜色传达"。
class StateIcon extends Control:
	var _shape := StageBadge.State.AVAILABLE
	var _accent := Color.WHITE

	func _init() -> void:
		name = "BadgeStateIcon"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_shape(shape: int, accent: Color) -> void:
		_shape = shape
		_accent = accent
		queue_redraw()

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		var c := size * 0.5
		draw_circle(c, r, _accent)
		match _shape:
			StageBadge.State.CLEARED:
				# 对勾：短笔下行 + 长笔上行。
				var a := c + Vector2(-r * 0.44, r * 0.02)
				var b := c + Vector2(-r * 0.10, r * 0.38)
				var d := c + Vector2(r * 0.48, -r * 0.40)
				draw_line(a, b, Color.WHITE, r * 0.24)
				draw_line(b, d, Color.WHITE, r * 0.24)
			StageBadge.State.AVAILABLE:
				# 实心三角，指向右——"可以进"。
				draw_colored_polygon([
					c + Vector2(-r * 0.26, -r * 0.46),
					c + Vector2(-r * 0.26, r * 0.46),
					c + Vector2(r * 0.50, 0.0),
				], Color.WHITE)
			StageBadge.State.LOCKED:
				# 锁：锁体方块 + 上方半环。
				var body := Rect2(c + Vector2(-r * 0.40, -r * 0.04), Vector2(r * 0.80, r * 0.62))
				draw_rect(body, Color.WHITE, true)
				draw_arc(
					c + Vector2(0.0, -r * 0.06), r * 0.30, PI, TAU, 14, Color.WHITE, r * 0.16
				)
			StageBadge.State.IN_PROGRESS:
				# 时钟：圆环 + 时针分针。
				draw_arc(c, r * 0.50, 0.0, TAU, 28, Color.WHITE, r * 0.14)
				draw_line(c, c + Vector2(0.0, -r * 0.38), Color.WHITE, r * 0.13)
				draw_line(c, c + Vector2(r * 0.30, 0.0), Color.WHITE, r * 0.13)
