class_name BonusBoardAura
extends Control
## 奖励盘的环绕特效：贴着棋盘外框跑一圈的流光、边上飘的星火，外加顶上那块
## 「奖 励 盘」的标题牌。纯代码绘制（不加素材），整层不吃鼠标。
##
## 只管演出。什么时候展开、什么时候收走，由 `main.gd` 的奖励盘流程决定；
## 这里既不碰棋盘数据，也不知道队列里还剩几张牌。

## 光环比棋盘外扩多少。
const PAD := 26.0
## 由内向外几圈描边，越外越淡。
const RING_COUNT := 4
const RING_STEP := 9.0
const SPARK_COUNT := 16
## 流光绕棋盘一圈要几秒。
const TRAVEL_PERIOD := 2.6
## 流光尾巴上再画几个渐隐的亮点。
const COMET_TAIL := 7
const INTRO_TIME := 0.44
const OUTRO_TIME := 0.26

const GOLD := Color("ffd76a")
const GOLD_DEEP := Color("f0a83a")
const CREAM := Color("fff3cf")
const PLATE := Color(0.16, 0.11, 0.05, 0.92)

var _title_plate: Panel
var _title_label: Label
var _subtitle_label: Label
var _title_box: Control
## 每颗星火：沿边走的位置 t、往外飘的距离、大小、闪烁相位、速度。
var _sparks: Array[Dictionary] = []
var _pulse := 0.0
var _travel := 0.0
var _tween: Tween
var _showing := false


func _init() -> void:
	name = "BonusBoardAura"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	set_process(false)


func _ready() -> void:
	_build_title()
	_seed_sparks()


func is_showing() -> bool:
	return _showing


func title_box() -> Control:
	return _title_box


## 把光环套到棋盘外框上（`board_rect` 走全局坐标）。标题牌默认摆在棋盘正上方，
## 顶上挤不下就翻到下方去。
func present(board_rect: Rect2, title_text: String = "奖 励 盘", subtitle: String = "道具继续结算") -> void:
	_showing = true
	position = board_rect.position - Vector2(PAD, PAD)
	size = board_rect.size + Vector2(PAD, PAD) * 2.0
	_title_label.text = title_text
	_subtitle_label.text = subtitle
	visible = true
	set_process(true)
	_place_title()
	_kill_tween()
	modulate.a = 0.0
	_title_box.scale = Vector2(0.72, 0.72)
	_title_box.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, INTRO_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_title_box, "modulate:a", 1.0, INTRO_TIME * 0.8)
	_tween.tween_property(_title_box, "scale", Vector2.ONE, INTRO_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func dismiss(immediate: bool = false) -> void:
	if not _showing and not visible:
		return
	_showing = false
	_kill_tween()
	if immediate:
		visible = false
		modulate.a = 0.0
		set_process(false)
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, OUTRO_TIME)
	_tween.tween_callback(func() -> void:
		visible = false
		set_process(false))


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _build_title() -> void:
	_title_box = Control.new()
	_title_box.name = "BonusTitleBox"
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.size = Vector2(286.0, 96.0)
	_title_box.pivot_offset = _title_box.size * 0.5
	add_child(_title_box)

	_title_plate = Panel.new()
	_title_plate.name = "BonusTitlePlate"
	_title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_plate.size = _title_box.size
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 12
	_title_plate.add_theme_stylebox_override("panel", style)
	_title_box.add_child(_title_plate)

	_title_label = Label.new()
	_title_label.name = "BonusTitleLabel"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.position = Vector2(0.0, 8.0)
	_title_label.size = Vector2(_title_box.size.x, 54.0)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", CREAM)
	_title_label.add_theme_color_override("font_outline_color", GOLD_DEEP)
	_title_label.add_theme_constant_override("outline_size", 8)
	_title_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "BonusSubtitleLabel"
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.position = Vector2(0.0, 58.0)
	_subtitle_label.size = Vector2(_title_box.size.x, 30.0)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 19)
	_subtitle_label.add_theme_color_override("font_color", GOLD)
	_title_box.add_child(_subtitle_label)


## 标题牌摆棋盘正上方；上面挤不下（屏幕顶或者盘子太高）就翻到下方。
func _place_title() -> void:
	var gap := 18.0
	var above := -_title_box.size.y - gap
	var below := size.y + gap
	var top_on_screen := global_position.y + above
	_title_box.position = Vector2(
		(size.x - _title_box.size.x) * 0.5,
		below if top_on_screen < 12.0 else above
	)


func _seed_sparks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A17B0
	_sparks.clear()
	for index in SPARK_COUNT:
		_sparks.append({
			"t": rng.randf(),
			"speed": rng.randf_range(0.03, 0.10) * (1.0 if index % 2 == 0 else -1.0),
			"out": rng.randf_range(2.0, 16.0),
			"size": rng.randf_range(3.0, 6.5),
			"phase": rng.randf() * TAU,
			"blink": rng.randf_range(1.6, 3.4),
		})


func _process(delta: float) -> void:
	_pulse += delta
	_travel = fposmod(_travel + delta / TRAVEL_PERIOD, 1.0)
	for spark in _sparks:
		spark["t"] = fposmod(float(spark["t"]) + float(spark["speed"]) * delta, 1.0)
	queue_redraw()


func _draw() -> void:
	var breathe := 0.5 + 0.5 * sin(_pulse * 2.1)
	_draw_rings(breathe)
	_draw_comet()
	_draw_sparks()


## 由内向外几圈圆角描边，越外越淡，整体随呼吸明暗。
func _draw_rings(breathe: float) -> void:
	for ring in RING_COUNT:
		var grow := float(ring) * RING_STEP
		var fade := 1.0 - float(ring) / float(RING_COUNT)
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.border_color = GOLD.lerp(GOLD_DEEP, float(ring) / float(RING_COUNT))
		style.border_color.a = (0.10 + 0.55 * fade) * (0.62 + 0.38 * breathe)
		style.set_border_width_all(maxi(int(4.0 - float(ring)), 1))
		style.set_corner_radius_all(int(18.0 + grow))
		draw_style_box(style, Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0))


## 一颗亮点绕着棋盘外框跑，后面拖一小串渐隐的尾巴。
func _draw_comet() -> void:
	for tail in COMET_TAIL:
		var back := float(tail) * 0.012
		var point := _perimeter_point(_travel - back)
		var fade := 1.0 - float(tail) / float(COMET_TAIL)
		var radius := 3.0 + 7.0 * fade
		draw_circle(point, radius * 2.1, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 * fade))
		draw_circle(point, radius, Color(CREAM.r, CREAM.g, CREAM.b, 0.85 * fade))


func _draw_sparks() -> void:
	for spark in _sparks:
		var point := _perimeter_point(float(spark["t"]))
		var outward := _outward_normal(float(spark["t"])) * float(spark["out"])
		var twinkle := 0.35 + 0.65 * absf(sin(_pulse * float(spark["blink"]) + float(spark["phase"])))
		_draw_diamond(point + outward, float(spark["size"]) * twinkle, Color(GOLD.r, GOLD.g, GOLD.b, twinkle))


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.62, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.62, 0.0),
		]),
		color
	)


## 沿外框走一圈：t 从 0 到 1 依次走上、右、下、左四条边。
func _perimeter_point(t: float) -> Vector2:
	var walked := fposmod(t, 1.0) * (2.0 * (size.x + size.y))
	if walked < size.x:
		return Vector2(walked, 0.0)
	walked -= size.x
	if walked < size.y:
		return Vector2(size.x, walked)
	walked -= size.y
	if walked < size.x:
		return Vector2(size.x - walked, size.y)
	walked -= size.x
	return Vector2(0.0, size.y - walked)


func _outward_normal(t: float) -> Vector2:
	var walked := fposmod(t, 1.0) * (2.0 * (size.x + size.y))
	if walked < size.x:
		return Vector2(0.0, -1.0)
	walked -= size.x
	if walked < size.y:
		return Vector2(1.0, 0.0)
	walked -= size.y
	if walked < size.x:
		return Vector2(0.0, 1.0)
	return Vector2(-1.0, 0.0)
