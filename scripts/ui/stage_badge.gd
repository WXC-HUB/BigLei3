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

const WIDTH := 184.0
const HEIGHT := 90.0
const TAIL_HEIGHT := 13.0

enum State {CLEARED, AVAILABLE, LOCKED, IN_PROGRESS}

const STATE_WORDS := {
	State.CLEARED: "已通关",
	State.AVAILABLE: "可挑战",
	State.LOCKED: "未解锁",
	State.IN_PROGRESS: "进行中",
}
const STATE_ACCENTS := {
	State.CLEARED: Color(0.294, 0.486, 0.180),
	State.AVAILABLE: Color(0.906, 0.588, 0.078),
	State.LOCKED: Color(0.435, 0.478, 0.529),
	State.IN_PROGRESS: Color(0.180, 0.408, 0.729),
}

const PAPER := Color(0.973, 0.961, 0.925)
const PAPER_EDGE := Color(0.784, 0.722, 0.604)
const INK := Color(0.184, 0.165, 0.125)
const INK_SOFT := Color(0.478, 0.427, 0.349)
const CHIP := Color(0.898, 0.863, 0.776)

var stage_id := ""

var _state := State.AVAILABLE
var _icon: StateIcon
var _tail: Tail
var _name_label: Label
var _round_label: Label
var _status_label: Label
var _dim: ColorRect
var _hover_lift := 0.0


func _init() -> void:
	name = "StageBadge"
	custom_minimum_size = Vector2(WIDTH, HEIGHT + TAIL_HEIGHT)
	size = custom_minimum_size
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


## 牌体的皮：纸底 + 棕描边 + 圆角。四个态共用同一张皮，只有描边色跟着状态走，
## 所以 hover/pressed 也一起 duplicate 出来改，免得悬停时描边跳回默认色。
func _build_styles() -> void:
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER
		box.border_color = PAPER_EDGE
		box.set_border_width_all(3)
		box.set_corner_radius_all(11)
		box.content_margin_bottom = TAIL_HEIGHT
		match state_name:
			"hover":
				box.bg_color = Color(1.0, 0.992, 0.965)
			"pressed":
				box.bg_color = Color(0.933, 0.914, 0.867)
			"disabled":
				box.bg_color = PAPER.darkened(0.08)
		add_theme_stylebox_override(state_name, box)


func _build_children() -> void:
	_tail = Tail.new()
	_tail.position = Vector2(WIDTH * 0.5 - 12.0, HEIGHT - 2.0)
	_tail.size = Vector2(24.0, TAIL_HEIGHT + 2.0)
	add_child(_tail)

	_icon = StateIcon.new()
	_icon.position = Vector2(11.0, 10.0)
	_icon.size = Vector2(34.0, 34.0)
	add_child(_icon)

	_name_label = Label.new()
	_name_label.name = "BadgeNameLabel"
	_name_label.position = Vector2(52.0, 7.0)
	_name_label.size = Vector2(124.0, 36.0)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 21)
	_name_label.add_theme_color_override("font_color", INK)
	add_child(_name_label)

	var chip := Panel.new()
	chip.name = "RoundChip"
	chip.position = Vector2(11.0, 48.0)
	chip.size = Vector2(74.0, 32.0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = CHIP
	chip_box.set_corner_radius_all(9)
	chip.add_theme_stylebox_override("panel", chip_box)
	add_child(chip)

	_round_label = Label.new()
	_round_label.name = "BadgeRoundLabel"
	_round_label.position = Vector2(11.0, 48.0)
	_round_label.size = Vector2(74.0, 32.0)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 20)
	_round_label.add_theme_color_override("font_color", INK)
	add_child(_round_label)

	_status_label = Label.new()
	_status_label.name = "BadgeStatusLabel"
	_status_label.position = Vector2(92.0, 48.0)
	_status_label.size = Vector2(84.0, 32.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", INK_SOFT)
	add_child(_status_label)

	_dim = ColorRect.new()
	_dim.name = "BadgeLockOverlay"
	_dim.color = Color(0.043, 0.071, 0.125, 0.58)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(WIDTH, HEIGHT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)


## 把关卡表里的一条记录贴到牌子上。名字与目标盘数只在这里写一次——它们不会在运行中变。
func bind(stage: Dictionary) -> void:
	stage_id = String(stage.get("id", ""))
	if _name_label == null:
		# 还没进场景树就被 bind 的情况：先记下来，_ready 之后再补。
		await ready
	_name_label.text = "%d · %s" % [int(stage.get("order", 0)), String(stage.get("name", ""))]
	_round_label.text = "%d 盘" % int(stage.get("target_round", 0))
	tooltip_text = "%s · 打通第 %d 盘即通关" % [
		String(stage.get("name", "")), int(stage.get("target_round", 0))
	]


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
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var box := get_theme_stylebox(state_name) as StyleBoxFlat
		if box != null:
			box.border_color = accent if state != State.LOCKED else PAPER_EDGE


func current_state() -> int:
	return _state


func _on_hover_changed(entered: bool) -> void:
	if disabled:
		return
	var target := -6.0 if entered else 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_hover_lift", target, 0.12)


func hover_lift() -> float:
	return _hover_lift


## 牌子底下那根指向地格的小尖角。单独一个节点是为了让它画到牌体矩形之外，
## 又不参与 Button 的点击区。
class Tail extends Control:
	func _init() -> void:
		name = "BadgeTail"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var tip := Vector2(size.x * 0.5, size.y)
		var left := Vector2(0.0, 0.0)
		var right := Vector2(size.x, 0.0)
		draw_colored_polygon([left, right, tip], StageBadge.PAPER)
		draw_line(left, tip, StageBadge.PAPER_EDGE, 4.0)
		draw_line(right, tip, StageBadge.PAPER_EDGE, 4.0)


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
