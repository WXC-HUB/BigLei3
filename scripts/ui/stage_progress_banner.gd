class_name StageProgressBanner
extends Control
## 每一盘开局前的进度横幅：遮罩 + 关卡名 + 盘序 + 进度条/分段点。

const COLOR_PIP_DONE := Color(0.86, 0.7, 0.28, 1)
const COLOR_PIP_CURRENT := Color(1, 0.9, 0.45, 1)
const COLOR_PIP_TODO := Color(0.28, 0.36, 0.28, 0.95)
const COLOR_FILL := Color(0.93, 0.74, 0.28, 1)
const COLOR_FILL_END := Color(1, 0.88, 0.48, 1)

@onready var dim: ColorRect = %Dim
@onready var banner: PanelContainer = %Banner
@onready var accent_top: ColorRect = %AccentTop
@onready var eyebrow: Label = %Eyebrow
@onready var title: Label = %Title
@onready var rule: ColorRect = %Rule
@onready var round_row: HBoxContainer = %RoundRow
@onready var round_index: Label = %RoundIndex
@onready var round_suffix: Label = %RoundSuffix
@onready var track: Control = %Track
@onready var track_fill: ColorRect = %TrackFill
@onready var segments: HBoxContainer = %Segments

## 兼容测试：合成「第 n / m 盘」。
var subtitle: Label

var _presentation_count := 0
var _pip_nodes: Array[ColorRect] = []
var _pulse_tween: Tween
var _banner_rest_offset := Vector2.ZERO
var _banner_rest_height := 236.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	subtitle = Label.new()
	subtitle.visible = false


func present(stage_name: String, round_index_value: int, total_rounds: int) -> void:
	_presentation_count += 1
	var token := _presentation_count
	# total_rounds <= 0 = 无尽关：没有目标盘数，只报第几盘，进度条改画难度爬升、不摆分段点。
	var endless := total_rounds <= 0
	var current := maxi(round_index_value, 1) if endless else clampi(round_index_value, 1, maxi(total_rounds, 1))
	var total := 0 if endless else maxi(total_rounds, 1)
	var name_text := stage_name.strip_edges()
	if name_text == "":
		name_text = "本关"

	title.text = name_text
	round_index.text = str(current)
	if endless:
		round_suffix.text = "/ ∞ 盘"
		subtitle.text = "第 %d 盘 · 无尽" % current
		eyebrow.text = "无尽 · 越打越难"
	else:
		round_suffix.text = "/ %d 盘" % total
		subtitle.text = "第 %d / %d 盘" % [current, total]
		eyebrow.text = "本关进度"
	_rebuild_segments(total)
	_stop_pulse()

	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	_apply_rest_layout()
	await get_tree().process_frame
	if token != _presentation_count:
		return
	_apply_rest_layout()
	_prepare_enter_pose()

	await get_tree().process_frame
	if token != _presentation_count:
		return

	banner.pivot_offset = banner.size * 0.5
	track_fill.offset_right = 0.0
	track_fill.color = COLOR_FILL

	var rest_top := _banner_rest_offset.y
	var rest_bottom := rest_top + _banner_rest_height

	# 1) 遮罩 + 横幅从上方落位
	var enter := create_tween()
	enter.set_parallel(true)
	enter.tween_property(dim, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "offset_top", rest_top, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "offset_bottom", rest_bottom, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(accent_top, "modulate:a", 1.0, 0.28).set_delay(0.06)
	await enter.finished
	if token != _presentation_count:
		return

	# 2) 文案错落淡入
	await _reveal_copy_stack(token, [eyebrow, title, rule, round_row])
	if token != _presentation_count:
		return

	# 3) 进度条 + 分段点
	track.modulate.a = 1.0
	segments.modulate.a = 1.0
	var fill_ratio := maxf(StageTable.endless_difficulty_fraction(current), 0.04) if endless else float(current) / float(total)
	var target_w := track.size.x * fill_ratio
	var bar := create_tween()
	bar.set_parallel(true)
	bar.tween_property(track_fill, "offset_right", target_w, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.tween_method(_lerp_fill_color, 0.0, 1.0, 0.4)
	await _animate_pips(token, current)
	if token != _presentation_count:
		return
	# 分段点逐个亮起要过 total 个 SceneTreeTimer，每个都会被帧长向上取整；帧率一低
	# （约 50 fps 打 11～12 盘、30 fps 打 8 盘以内），进度条那 0.4 秒的 tween 会先跑完。
	# Godot 里 await 一个已经结束的 tween 永远不会返回——横幅就此盖在棋盘上再也不收，
	# 玩家看到的就是"卡在开始界面"。所以只在它还活着时才等。
	if bar.is_valid() and bar.is_running():
		await bar.finished
	if token != _presentation_count:
		return

	_start_current_pulse(current)
	await get_tree().create_timer(0.58).timeout
	if token != _presentation_count:
		return
	_stop_pulse()

	# 4) 上收淡出
	var exit_top := rest_top - 36.0
	var exit := create_tween()
	exit.set_parallel(true)
	exit.tween_property(banner, "offset_top", exit_top, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(banner, "offset_bottom", exit_top + _banner_rest_height * 0.92, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(banner, "scale", Vector2(1.03, 0.9), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(banner, "modulate:a", 0.0, 0.2).set_delay(0.04)
	exit.tween_property(dim, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit.finished
	if token != _presentation_count:
		return

	_reset_visual_state()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_immediately() -> void:
	_presentation_count += 1
	_stop_pulse()
	_reset_visual_state()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_rest_layout() -> void:
	var width := 720.0
	_banner_rest_height = maxf(banner.get_combined_minimum_size().y, 200.0)
	_banner_rest_offset = Vector2(-width * 0.5, -_banner_rest_height * 0.5 - 36.0)
	banner.offset_left = _banner_rest_offset.x
	banner.offset_right = -_banner_rest_offset.x
	banner.offset_top = _banner_rest_offset.y
	banner.offset_bottom = _banner_rest_offset.y + _banner_rest_height


func _prepare_enter_pose() -> void:
	dim.modulate.a = 0.0
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.0, 0.86)
	banner.offset_left = _banner_rest_offset.x
	banner.offset_right = -_banner_rest_offset.x
	banner.offset_top = _banner_rest_offset.y - 64.0
	banner.offset_bottom = banner.offset_top + _banner_rest_height
	accent_top.modulate.a = 0.0
	for node in [eyebrow, title, rule, round_row, track, segments]:
		node.modulate.a = 0.0


func _reset_visual_state() -> void:
	if dim != null:
		dim.modulate.a = 0.0
	if banner != null:
		banner.scale = Vector2.ONE
		banner.modulate = Color.WHITE
		_apply_rest_layout()
	if accent_top != null:
		accent_top.modulate = Color.WHITE
	for node in [eyebrow, title, rule, round_row, track, segments]:
		if node != null:
			node.modulate = Color.WHITE
	if track_fill != null:
		track_fill.offset_right = 0.0
		track_fill.color = COLOR_FILL


func _reveal_copy_stack(token: int, nodes: Array) -> void:
	for i in range(nodes.size()):
		if token != _presentation_count:
			return
		var node: CanvasItem = nodes[i]
		node.modulate.a = 0.0
		node.scale = Vector2(0.96, 0.96)
		if node is Control:
			(node as Control).pivot_offset = (node as Control).size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(node, "modulate:a", 1.0, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.045).timeout


func _rebuild_segments(total: int) -> void:
	for child in segments.get_children():
		child.queue_free()
	_pip_nodes.clear()
	var pip_w := 18.0 if total <= 10 else (14.0 if total <= 14 else 10.0)
	var pip_h := 10.0 if total <= 10 else 8.0
	segments.add_theme_constant_override("separation", 4 if total <= 12 else 3)
	for _i in range(total):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(pip_w, pip_h)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.color = COLOR_PIP_TODO
		pip.modulate.a = 0.0
		pip.pivot_offset = Vector2(pip_w * 0.5, pip_h * 0.5)
		segments.add_child(pip)
		_pip_nodes.append(pip)


func _animate_pips(token: int, current: int) -> void:
	var step := 0.034 if _pip_nodes.size() <= 8 else (0.024 if _pip_nodes.size() <= 12 else 0.016)
	for i in range(_pip_nodes.size()):
		if token != _presentation_count:
			return
		var pip := _pip_nodes[i]
		var target := COLOR_PIP_TODO
		if i + 1 < current:
			target = COLOR_PIP_DONE
		elif i + 1 == current:
			target = COLOR_PIP_CURRENT
		pip.color = target
		pip.scale = Vector2(0.5, 0.5)
		var tw := create_tween()
		tw.tween_property(pip, "modulate:a", 1.0, 0.11)
		tw.parallel().tween_property(pip, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i + 1 == current:
			tw.tween_property(pip, "scale", Vector2(1.28, 1.28), 0.1)
			tw.tween_property(pip, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(step).timeout


func _start_current_pulse(current: int) -> void:
	if current < 1 or current > _pip_nodes.size():
		return
	var pip := _pip_nodes[current - 1]
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(pip, "modulate", Color(1.2, 1.12, 0.92, 1.0), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(pip, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	for pip in _pip_nodes:
		if is_instance_valid(pip):
			pip.modulate = Color.WHITE


func _lerp_fill_color(weight: float) -> void:
	track_fill.color = COLOR_FILL.lerp(COLOR_FILL_END, weight)
