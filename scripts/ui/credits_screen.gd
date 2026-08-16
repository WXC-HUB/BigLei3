class_name CreditsScreen
extends Control
## 星战式制作人名单：文字从画面下方向着地平线退去，越远越小越暗。
##
## 透视是真的按 1/z 算的，不是简单的等比缩小——缩放和行距共用同一个深度，
## 所以行与行之间会自然挤在一起，这才是"往远处跑"而不是"整块往上飘"。

signal back_requested
## 只在中途插播的「换首音乐」环节里发出：玩家按【继续玩】回到棋盘。
signal continue_requested

const GOLD := Color(1.0, 0.827, 0.361)
const GOLD_DIM := Color(0.82, 0.66, 0.31)
const CREAM := Color(1.0, 0.945, 0.82)

## 近平面在画面下缘之外，远平面就是地平线。
const Z_NEAR := 1.0
const Z_FAR := 6.0
const CRAWL_SPEED := 1.05
## 地平线与近平面在屏幕上的位置，按画面高度取比例。
const HORIZON_RATIO := 0.17
const NEAR_RATIO := 1.06
## 快要抵达地平线时淡出的深度区间。
const FADE_Z := 1.7

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const BirdSwarm := preload("res://scripts/ui/credits_bird_swarm.gd")

## 【继续玩】的呼吸节奏。名单在慢慢往地平线退，按钮必须一直在动才抢得回注意力。
const CONTINUE_PULSE := 0.055
const CONTINUE_PULSE_TIME := 0.62
## 光晕从按钮尺寸涨到这个倍数再淡掉，一圈一圈往外推。
const HALO_SPREAD := 1.28

## BGM 切换按钮的外发光。选中的那颗一直在呼吸，没选中的只留一圈暗底光，两颗并排
## 时一眼就知道现在放的是哪首。发光本身是 StyleBoxFlat 的无偏移阴影。
const TRACK_GLOW_ON := Color(1.0, 0.855, 0.42, 0.7)
const TRACK_GLOW_OFF := Color(1.0, 0.831, 0.376, 0.18)
const TRACK_GLOW_SIZE := Vector2(18.0, 36.0)
const TRACK_GLOW_BREATH := 0.85
const TRACK_BORDER_ON := Color(1.0, 0.937, 0.678, 1.0)
const TRACK_BORDER_OFF := Color(1.0, 0.827, 0.361, 0.55)

const TENDER_STREAM := preload("res://assets/audio/credits_tender.ogg")
const HYPE_STREAM := preload("res://assets/audio/credits_hype.ogg")

## 名单内容。gap 是这一行之后额外留的深度，用来分段。
##
## 三段式的笑点是有顺序的，别打乱：两位主创先领一堆无厘头要职（点外卖、吃火锅、
## 思考人生……），然后「剩 下 的 活」整块砸给夜鹭，最后演员表里进了游戏的鸟全是
## 夜鹭饰，没进游戏的那几只（含只存在于设定里的疗愈鸟）一律「鸽子 饰」——被放了
## 鸽子，所以观众一只也没见着。测试 test_credits_screen 就是按这几段分界校验的。
const CRAWL_LINES := [
	{"text": "咕 咕 啾 啾", "size": 104, "color": GOLD, "gap": 0.49},
	{"text": "制 作 人 名 单", "size": 78, "color": GOLD_DIM, "gap": 0.77},
	{"text": "主创", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 108, "color": CREAM, "gap": 0.32},
	{"text": "Claude.Wu", "size": 108, "color": CREAM, "gap": 0.77},
	{"text": "另 有 要 职", "size": 92, "color": GOLD, "gap": 0.7},
	{"text": "点外卖", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "吃火锅", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "思考人生", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "思考完继续吃火锅", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "反复修改需求", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "假装没听见", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "摸鱼", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "摸鱼监理", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "熬夜", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Ago.Pang", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "第二天补觉", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "给鸟起名", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.46},
	{"text": "放弃给鸟起名", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "Claude.Wu", "size": 100, "color": CREAM, "gap": 0.77},
	{"text": "剩 下 的 活", "size": 92, "color": GOLD, "gap": 0.7},
	{"text": "策划", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "程序", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "美术", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "关卡设计", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "UI 与动效", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "音乐与音效", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.59},
	{"text": "测试", "size": 72, "color": GOLD_DIM, "gap": 0.29},
	{"text": "夜鹭", "size": 104, "color": CREAM, "gap": 0.77},
	{"text": "演 员 表", "size": 92, "color": GOLD, "gap": 0.7},
	{"text": "小蓝鸟 —— 夜鹭 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "夜鹭 —— 夜鹭 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "红尾水鸲 —— 夜鹭 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "啄木鸟 —— 夜鹭 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "红隼 —— 夜鹭 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "疗愈鸟 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "戴胜 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "翠鸟 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "麻雀 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "寿带 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.42},
	{"text": "丹顶鹤 —— 鸽子 饰", "size": 84, "color": CREAM, "gap": 0.77},
	{"text": "特 别 鸣 谢", "size": 92, "color": GOLD, "gap": 0.36},
	{"text": "AAAAAA工作室（排名不分先后）", "size": 56, "color": GOLD_DIM, "gap": 0.62},
	{"text": "Chat GPT", "size": 96, "color": CREAM, "gap": 0.4},
	{"text": "Claude", "size": 96, "color": CREAM, "gap": 0.4},
	{"text": "Gemini", "size": 96, "color": CREAM, "gap": 0.4},
	{"text": "FLUX生图", "size": 96, "color": CREAM, "gap": 0.4},
	{"text": "豆包", "size": 96, "color": CREAM, "gap": 0.4},
	{"text": "DeepSeek", "size": 96, "color": CREAM, "gap": 0.77},
	{"text": "感谢游玩", "size": 108, "color": GOLD, "gap": 0.7},
]

@onready var crawl_root: Control = %Crawl
@onready var bgm: AudioStreamPlayer = %CreditsBGM
@onready var tender_button: Button = %TenderButton
@onready var hype_button: Button = %HypeButton
@onready var back_button: Button = %BackButton
@onready var continue_root: Control = %Continue
@onready var continue_button: Button = %ContinueButton
@onready var continue_halo: Panel = %Halo

var _lines: Array[Label] = []
var _line_depths: PackedFloat32Array = PackedFloat32Array()
var _crawl_length := 0.0
var _travel := 0.0
var _stars: StarField
var _swarm: CreditsBirdSwarm
## 默认劲爆男声；玩家切过之后这个选择会在本次运行内保留。
var _tender_selected := false
var _continue_pulse: Tween
## 两颗按钮各自持有一份 normal 样式的副本：共用同一个资源的话，给选中的那颗调发光
## 会把另一颗一起点亮。
var _track_boxes := {}
var _track_glow: Tween


func _ready() -> void:
	visible = false
	tender_button.pressed.connect(_on_tender_pressed)
	hype_button.pressed.connect(_on_hype_pressed)
	back_button.pressed.connect(_on_back_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	ButtonMotion.bind(continue_button, continue_button, 1.4)
	continue_root.visible = false
	for button in [tender_button, hype_button]:
		var box := (button.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
		button.add_theme_stylebox_override("normal", box)
		_track_boxes[button] = box
	_stars = StarField.new()
	_stars.name = "StarField"
	# Behind the crawl but above the flat backdrop.
	add_child(_stars)
	move_child(_stars, 1)
	# 鸟群压在名单上面、按钮下面：飞过名单时要看得见，但不能挡住上面那排按钮的点击。
	_swarm = BirdSwarm.new()
	_swarm.name = "BirdSwarm"
	_swarm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_swarm)
	move_child(_swarm, crawl_root.get_index() + 1)
	set_process(false)


## continue_mode 是中途插播用的：右边换成一个大得离谱的【继续玩】，同时收掉「返回」
## ——这时候没有可以返回的地方。
func present(continue_mode: bool = false) -> void:
	visible = true
	modulate.a = 0.0
	_travel = 0.0
	_build_lines()
	_stars.regenerate(size)
	_swarm.scatter()
	_swarm.set_process(true)
	_apply_track(_tender_selected, true)
	set_process(true)
	back_button.visible = not continue_mode
	continue_root.visible = continue_mode
	if continue_mode:
		_start_continue_pulse()
	else:
		_stop_continue_pulse()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.3)


func dismiss() -> void:
	set_process(false)
	_stop_continue_pulse()
	_stop_track_glow()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	var quiet := create_tween()
	quiet.tween_property(bgm, "volume_db", -40.0, 0.25)
	await fade.finished
	bgm.stop()
	_swarm.set_process(false)
	_swarm.clear_notes()
	visible = false


func _process(delta: float) -> void:
	_travel += delta * CRAWL_SPEED
	# 整段跑完就从头再来，名单不会停在空屏上。
	if _travel - _crawl_length > Z_FAR - Z_NEAR:
		_travel = 0.0
	var horizon := size.y * HORIZON_RATIO
	var span := size.y * NEAR_RATIO - horizon
	var center_x := size.x * 0.5
	for index in _lines.size():
		var line := _lines[index]
		var depth := Z_NEAR + _travel - _line_depths[index]
		if depth < Z_NEAR or depth >= Z_FAR:
			line.visible = false
			continue
		# 1/z 投影：缩放和纵向位置共用同一个系数，行距才会跟着一起收。
		var perspective := Z_NEAR / depth
		line.visible = true
		line.scale = Vector2(perspective, perspective)
		line.position = Vector2(
			center_x - line.size.x * 0.5,
			horizon + span * perspective - line.size.y * 0.5
		)
		var fade := clampf((Z_FAR - depth) / FADE_Z, 0.0, 1.0)
		line.modulate.a = fade * fade


func _build_lines() -> void:
	for line in _lines:
		line.queue_free()
	_lines.clear()
	_line_depths = PackedFloat32Array()
	var font := get_theme_font("font", "Label")
	var depth := 0.0
	for entry in CRAWL_LINES:
		var line := Label.new()
		line.text = entry["text"]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if font != null:
			line.add_theme_font_override("font", font)
		line.add_theme_font_size_override("font_size", entry["size"])
		line.add_theme_color_override("font_color", entry["color"])
		line.visible = false
		crawl_root.add_child(line)
		line.reset_size()
		line.pivot_offset = line.size * 0.5
		_lines.append(line)
		_line_depths.append(depth)
		depth += float(entry.get("gap", 0.5))
	_crawl_length = depth


# ---------------------------------------------------------------------------
# BGM 切换
# ---------------------------------------------------------------------------


func _on_tender_pressed() -> void:
	_apply_track(true, false)


func _on_hype_pressed() -> void:
	_apply_track(false, false)


func _apply_track(tender: bool, force: bool) -> void:
	if not force and tender == _tender_selected and bgm.playing:
		return
	_tender_selected = tender
	var stream: AudioStream = TENDER_STREAM if tender else HYPE_STREAM
	# 两段素材都不长，尤其劲爆男声只有半分钟，必须循环。
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	bgm.stream = stream
	bgm.volume_db = -6.0
	bgm.play()
	_refresh_track_buttons()


func _refresh_track_buttons() -> void:
	tender_button.modulate = Color.WHITE if _tender_selected else Color(0.72, 0.72, 0.76)
	hype_button.modulate = Color(0.72, 0.72, 0.76) if _tender_selected else Color.WHITE
	_stop_track_glow()
	var selected: Button = tender_button if _tender_selected else hype_button
	for button in _track_boxes:
		var box: StyleBoxFlat = _track_boxes[button]
		var on: bool = button == selected
		box.shadow_color = TRACK_GLOW_ON if on else TRACK_GLOW_OFF
		box.border_color = TRACK_BORDER_ON if on else TRACK_BORDER_OFF
		box.shadow_size = int(TRACK_GLOW_SIZE.x) if on else 10
	var lit: StyleBoxFlat = _track_boxes[selected]
	_track_glow = create_tween().set_loops()
	_track_glow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_track_glow.tween_property(lit, "shadow_size", TRACK_GLOW_SIZE.y, TRACK_GLOW_BREATH)
	_track_glow.tween_property(lit, "shadow_size", TRACK_GLOW_SIZE.x, TRACK_GLOW_BREATH)


func _stop_track_glow() -> void:
	if _track_glow != null and _track_glow.is_valid():
		_track_glow.kill()
	_track_glow = null


func _on_back_pressed() -> void:
	back_requested.emit()


func _on_continue_pressed() -> void:
	continue_button.disabled = true
	_stop_continue_pulse()
	continue_requested.emit()


## 按钮本体一涨一缩，光晕一圈圈往外推——两条不同周期的循环叠在一起，看着就停不下来。
func _start_continue_pulse() -> void:
	_stop_continue_pulse()
	continue_button.disabled = false
	# 等一帧拿到真实尺寸，否则轴心落在左上角，脉动会变成往右下角甩。
	await get_tree().process_frame
	continue_root.pivot_offset = continue_root.size * 0.5
	continue_halo.pivot_offset = continue_halo.size * 0.5
	_continue_pulse = create_tween().set_loops().set_parallel(true)
	_continue_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_continue_pulse.tween_property(
		continue_root, "scale", Vector2.ONE * (1.0 + CONTINUE_PULSE), CONTINUE_PULSE_TIME
	)
	_continue_pulse.tween_property(
		continue_root, "scale", Vector2.ONE, CONTINUE_PULSE_TIME
	).set_delay(CONTINUE_PULSE_TIME)
	_continue_pulse.tween_property(
		continue_halo, "scale", Vector2.ONE * HALO_SPREAD, CONTINUE_PULSE_TIME * 2.0
	)
	_continue_pulse.tween_property(continue_halo, "modulate:a", 0.0, CONTINUE_PULSE_TIME * 2.0)
	_continue_pulse.tween_callback(func() -> void:
		continue_halo.scale = Vector2.ONE
		continue_halo.modulate.a = 1.0
	).set_delay(CONTINUE_PULSE_TIME * 2.0)


func _stop_continue_pulse() -> void:
	if _continue_pulse != null and _continue_pulse.is_valid():
		_continue_pulse.kill()
	_continue_pulse = null
	continue_root.scale = Vector2.ONE
	continue_halo.scale = Vector2.ONE
	continue_halo.modulate.a = 1.0


## 程序化星空：一次画完就不再重绘，静态星野比闪烁更接近片头的质感。
class StarField extends Node2D:
	var _positions: PackedVector2Array = PackedVector2Array()
	var _radii: PackedFloat32Array = PackedFloat32Array()
	var _alphas: PackedFloat32Array = PackedFloat32Array()


	func regenerate(area: Vector2) -> void:
		_positions = PackedVector2Array()
		_radii = PackedFloat32Array()
		_alphas = PackedFloat32Array()
		if area.x <= 0.0 or area.y <= 0.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260816
		for _index in range(190):
			_positions.append(Vector2(rng.randf() * area.x, rng.randf() * area.y))
			_radii.append(rng.randf_range(0.8, 2.3))
			_alphas.append(rng.randf_range(0.18, 0.85))
		queue_redraw()


	func _draw() -> void:
		for index in _positions.size():
			draw_circle(_positions[index], _radii[index], Color(1.0, 0.98, 0.92, _alphas[index]))
