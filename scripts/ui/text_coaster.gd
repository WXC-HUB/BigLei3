class_name TextCoaster
extends Control
## 文字过山车：把一行字拆成一个字一个 Label，让一列相位递减的正弦波沿着这行字往后
## 跑，同时从队尾两个字上不断冒出「9」粒子。标题界面和开场剧情共用这一套实现，
## 所以两处的字永远是同一个动法。
##
## 用法：把它挂到想要覆盖的控件下面（自己会撑成全屏矩形），再 bind 一个 Label。
## 被 bind 的 Label 会被 self_modulate 涂透明但保留在原地，容器照旧按它排版；真正
## 画出来的是这里生成的一份份单字拷贝，这样每个字才能各走各的。换文本会自动重排。

## 队尾冒粒子的字数。
const DIGIT_TEXT := "9"
const DIGIT_INTERVAL_RANGE := Vector2(0.18, 0.34)
## 色相收在标题的金色一带，只在这个窄区间里取值，避免整片彩虹。
const DIGIT_HUE_RANGE := Vector2(0.07, 0.19)
const DIGIT_HUE_TRAVEL_RANGE := Vector2(0.04, 0.13)
const DIGIT_SATURATION := 0.72
## 同屏上限：粒子必须封顶而不是无限累积。
const DIGIT_LIMIT := 16
const DIGIT_SPOUTS := 2

const COASTER_AMPLITUDE := 30.0
const COASTER_SPEED := 2.3
## 相邻两个字的相位差。太小整排一起跳，太大就散成各跳各的。
const COASTER_PHASE_STEP := 0.9
## 车头随坡度倾斜；用余弦是因为它正好是正弦位移的导数。
const COASTER_TILT := 0.12
## 上坡时略微拉长、下坡时略微压扁，补出一点重量感。
const COASTER_SQUASH := 0.055
## 打字机刚露出一个字时的额外放大，衰减完就并入正常的过山车运动。
const REVEAL_POP := 0.55
const REVEAL_POP_DECAY := 5.5

## 停下来之后波形和粒子都冻住，但字还留在画面上。
var running := true
## 冒不冒「9」。逐字打出来的正文可以关掉，只留波形。
var digits_enabled := true

var _source: Label
var _glyph_layer: Control
var _digit_layer: Control
var _glyphs: Array[Label] = []
var _glyph_bases := PackedVector2Array()
var _glyph_pops := PackedFloat32Array()
var _glyph_layout_key := ""
var _coaster_time := 0.0
var _digit_cooldown := 0.0
var _digit_slot := 0
## -1 表示整行都露出来；打字机把它从 0 一路加到字数。
var _visible_glyphs := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 字层在前、数字层在后，「9」才会从字的前面飘过去。
	_glyph_layer = _make_layer("Glyphs")
	_digit_layer = _make_layer("Digits")


## 接管一个 Label 的绘制。同一个 Label 换了文本会自动重建。
func bind(label: Label) -> void:
	_source = label
	_glyph_layout_key = ""


## 打字机用：只显示前 count 个字，-1 表示全部。
func set_visible_glyph_count(count: int) -> void:
	if count == _visible_glyphs:
		return
	for index in range(maxi(_visible_glyphs, 0), mini(count, _glyphs.size())):
		# 新露出来的字给一记弹跳，打字才有颗粒感。
		_glyph_pops[index] = 1.0
	_visible_glyphs = count
	_apply_glyph_visibility()


func glyph_count() -> int:
	return _glyphs.size()


## 立刻按当前 Label 的文本重排，别等下一帧的 _process。
func rebuild_now() -> void:
	_glyph_layout_key = ""
	_ensure_glyphs()


func _process(delta: float) -> void:
	_ensure_glyphs()
	if not running:
		return
	_advance_coaster(delta)
	_decay_pops(delta)
	if not digits_enabled:
		return
	_digit_cooldown -= delta
	if _digit_cooldown > 0.0:
		return
	_digit_cooldown = randf_range(DIGIT_INTERVAL_RANGE.x, DIGIT_INTERVAL_RANGE.y)
	var origins := _tail_centers()
	if origins.is_empty() or _digit_layer.get_child_count() >= DIGIT_LIMIT:
		return
	# Alternate between the spouts so neither one starves.
	_digit_slot = (_digit_slot + 1) % origins.size()
	_spawn_digit(origins[_digit_slot])


func _make_layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


# ---------------------------------------------------------------------------
# 单字拆分
# ---------------------------------------------------------------------------


## The source Label stays where it is so its container keeps sizing around it,
## but it stops painting: one Label per character takes over the drawing so each
## one can move on its own.
func _ensure_glyphs() -> void:
	if _source == null or not _source.is_inside_tree() or _source.size.x <= 0.0:
		return
	if _glyph_layer == null:
		return
	var layout_key := "%s|%d|%s|%s" % [
		_source.text,
		_source.get_theme_font_size("font_size"),
		_source.size,
		_source.global_position,
	]
	if layout_key == _glyph_layout_key:
		return
	_glyph_layout_key = layout_key
	for glyph in _glyphs:
		glyph.queue_free()
	_glyphs.clear()
	_glyph_bases = PackedVector2Array()
	_glyph_pops = PackedFloat32Array()

	var font := _source.get_theme_font("font")
	var font_size := _source.get_theme_font_size("font_size")
	if font == null:
		return
	# Read the look before blanking the source label, so the copies inherit it.
	var font_color := _source.get_theme_color("font_color")
	var outline_color := _source.get_theme_color("font_outline_color")
	var outline_size := _source.get_theme_constant("outline_size")
	# Hide the original through self_modulate rather than transparent theme
	# overrides: the copies read their look back off this label on every rebuild,
	# and a blanked override would hand the next rebuild a transparent colour.
	_source.self_modulate.a = 0.0

	var text := _source.text
	var full_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Both layers are full-rect, but resolve the origin anyway so the copies
	# cannot drift if the screen ever gets nested under an offset parent.
	var layer_origin := _glyph_layer.global_position
	var left := _source.global_position.x - layer_origin.x + (_source.size.x - full_width) * 0.5
	for index in text.length():
		if text[index] == " ":
			continue
		var glyph := Label.new()
		glyph.text = text[index]
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.add_theme_font_override("font", font)
		glyph.add_theme_font_size_override("font_size", font_size)
		glyph.add_theme_color_override("font_color", font_color)
		glyph.add_theme_color_override("font_outline_color", outline_color)
		glyph.add_theme_constant_override("outline_size", outline_size)
		_glyph_layer.add_child(glyph)
		glyph.reset_size()
		glyph.pivot_offset = glyph.size * 0.5
		var advance := font.get_string_size(
			text.substr(0, index), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		# Centre each copy on the advance slot the full-string layout gave it;
		# a single glyph measures slightly narrower than its advance.
		var slot_width := font.get_string_size(
			text[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		var base := Vector2(
			left + advance + (slot_width - glyph.size.x) * 0.5,
			_source.global_position.y - layer_origin.y
		)
		glyph.position = base
		_glyphs.append(glyph)
		_glyph_bases.append(base)
		_glyph_pops.append(0.0)
	_apply_glyph_visibility()


func _apply_glyph_visibility() -> void:
	for index in _glyphs.size():
		_glyphs[index].visible = _visible_glyphs < 0 or index < _visible_glyphs


# ---------------------------------------------------------------------------
# 过山车
# ---------------------------------------------------------------------------


func _advance_coaster(delta: float) -> void:
	if _glyphs.is_empty():
		return
	_coaster_time += delta * COASTER_SPEED
	for index in _glyphs.size():
		var glyph := _glyphs[index]
		if not is_instance_valid(glyph):
			continue
		var phase := _coaster_time - float(index) * COASTER_PHASE_STEP
		var lift := sin(phase)
		var slope := cos(phase)
		var pop := 1.0 + REVEAL_POP * _glyph_pops[index]
		glyph.position = _glyph_bases[index] + Vector2(0.0, -lift * COASTER_AMPLITUDE)
		glyph.rotation = slope * COASTER_TILT
		glyph.scale = Vector2(
			(1.0 - slope * COASTER_SQUASH) * pop, (1.0 + slope * COASTER_SQUASH) * pop
		)


func _decay_pops(delta: float) -> void:
	for index in _glyph_pops.size():
		if _glyph_pops[index] > 0.0:
			_glyph_pops[index] = maxf(_glyph_pops[index] - delta * REVEAL_POP_DECAY, 0.0)


# ---------------------------------------------------------------------------
# 「9」粒子
# ---------------------------------------------------------------------------


## Live centres of the last two visible glyphs, so the spouts ride the coaster
## instead of staying pinned to where the characters rest.
func _tail_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var shown := _glyphs.size() if _visible_glyphs < 0 else mini(_visible_glyphs, _glyphs.size())
	if shown < DIGIT_SPOUTS:
		return centers
	for glyph in _glyphs.slice(shown - DIGIT_SPOUTS, shown):
		if is_instance_valid(glyph):
			centers.append(glyph.position + glyph.size * 0.5)
	return centers


func _spawn_digit(origin: Vector2) -> void:
	var digit := Label.new()
	digit.text = DIGIT_TEXT
	digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The glyph carries its own colour through modulate, so the theme colour stays
	# white and the outline stays dark enough to read over the bright title.
	digit.add_theme_color_override("font_color", Color.WHITE)
	digit.add_theme_color_override("font_outline_color", Color(0.16, 0.1, 0.05, 0.9))
	digit.add_theme_constant_override("outline_size", 6)
	digit.add_theme_font_size_override("font_size", int(randf_range(44.0, 86.0)))
	_digit_layer.add_child(digit)
	digit.reset_size()
	digit.pivot_offset = digit.size * 0.5

	var spread := maxf(_source.get_theme_font_size("font_size") * 0.32, 24.0)
	var start := origin + Vector2(randf_range(-spread, spread), randf_range(-6.0, 62.0))
	var rise := randf_range(210.0, 330.0)
	var sway := randf_range(26.0, 68.0) * (1.0 if randf() < 0.5 else -1.0)
	var wobbles := randf_range(1.1, 2.0)
	var hue := randf_range(DIGIT_HUE_RANGE.x, DIGIT_HUE_RANGE.y)
	var hue_travel := randf_range(
		DIGIT_HUE_TRAVEL_RANGE.x, DIGIT_HUE_TRAVEL_RANGE.y
	) * (1.0 if randf() < 0.5 else -1.0)
	var life := randf_range(1.15, 1.85)
	var spin := randf_range(-0.6, 0.6)

	var flight := create_tween().set_parallel(true)
	flight.tween_method(
		func(progress: float) -> void:
			_advance_digit(digit, start, progress, rise, sway, wobbles, hue, hue_travel),
		0.0,
		1.0,
		life
	)
	flight.tween_property(digit, "rotation", spin, life)
	flight.finished.connect(digit.queue_free)


## One method drives position, colour and alpha together: splitting them across
## tweens would need two writers on `modulate`, and they would overwrite each
## other's channels.
func _advance_digit(
	digit: Label,
	start: Vector2,
	progress: float,
	rise: float,
	sway: float,
	wobbles: float,
	hue: float,
	hue_travel: float
) -> void:
	if not is_instance_valid(digit):
		return
	var climb := 1.0 - pow(1.0 - progress, 1.7)
	digit.position = (
		start
		+ Vector2(sin(progress * TAU * wobbles) * sway, -rise * climb)
		- digit.size * 0.5
	)
	var fade_in := clampf(progress / 0.16, 0.0, 1.0)
	var fade_out := clampf((1.0 - progress) / 0.34, 0.0, 1.0)
	digit.modulate = Color.from_hsv(
		fposmod(hue + progress * hue_travel, 1.0),
		DIGIT_SATURATION,
		1.0,
		minf(fade_in, fade_out)
	)
	var pop := 0.6 + 0.5 * clampf(progress / 0.22, 0.0, 1.0)
	digit.scale = Vector2(pop, pop)
