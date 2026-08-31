class_name ComboScoreHud
extends Control
## 贴齐画面右缘的大型得分/连击柱。
## 「COMBO」字形本身就是能量槽；有连击时文字会摇摆、色相流转，并持续喷粒子。

const PIXEL_FONT := preload("res://assets/fonts/tianwangxing_pixel.ttf")

const COLOR_SCORE := Color("f4e8c1")
const COLOR_EMPTY_FILL := Color("1a160f")
const COLOR_EMPTY_STROKE := Color("5a4a32")
const COLOR_MUTED := Color("8a7a58")

const TIER_COLORS := [
	Color("e8c56a"), ## 1-4 暖金
	Color("ff9a3c"), ## 5-9 熔橙
	Color("ff5a3c"), ## 10-19 炽红
	Color("fff4d0"), ## 20+ 白热
]

const HUD_SIZE := Vector2(520, 640)
const EDGE_INSET := 8.0

const COMBO_HOME := Vector2(20, 150)
const WORD_HOME := Vector2(24, 360)
const CAPTION_HOME := Vector2(24, 300)


var _score_caption: Label
var _score_value: Label
var _combo_count: Label
var _combo_ghost_a: Label
var _combo_ghost_b: Label
var _combo_caption: Label
var _empty_word: Label
var _fill_clip: Control
var _fill_word: Label
var _glow_word: Label
var _outline_word_a: Label
var _outline_word_b: Label
var _word_box: Control
var _flash: ColorRect
var _edge_glow: ColorRect
var _spark_layer: Control
var _aura: _HeatAura

var _score := 0
var _combo := 0
var _meter := 0.0
var _display_score := 0.0
var _punch_tween: Tween
var _flash_tween: Tween
var _ghost_tween: Tween
var _shake_strength := 0.0
var _home := Vector2.ZERO
var _pulse := 0.0
var _ambient_accum := 0.0
var _hue_shift := 0.0
var _sway_boost := 0.0


func _ready() -> void:
	custom_minimum_size = HUD_SIZE
	size = HUD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_build()
	_home = position
	set_process(true)
	_refresh_visuals(true)


func _build() -> void:
	_edge_glow = ColorRect.new()
	_edge_glow.name = "EdgeGlow"
	_edge_glow.color = Color(1.0, 0.55, 0.12, 0.0)
	_edge_glow.position = Vector2(HUD_SIZE.x - 18.0, 0.0)
	_edge_glow.size = Vector2(18.0, HUD_SIZE.y)
	_edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_edge_glow)

	_aura = _HeatAura.new()
	_aura.position = Vector2(40, 140)
	_aura.size = Vector2(HUD_SIZE.x - 40, 360)
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.visible = false
	add_child(_aura)

	_score_caption = _make_label("SCORE", 28, COLOR_MUTED)
	_score_caption.position = Vector2(24, 18)
	_score_caption.size = Vector2(HUD_SIZE.x - 48, 32)
	_score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score_caption)

	_score_value = _make_label("0", 72, COLOR_SCORE)
	_score_value.position = Vector2(24, 48)
	_score_value.size = Vector2(HUD_SIZE.x - 48, 84)
	_score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_value.add_theme_color_override("font_outline_color", Color("120c06"))
	_score_value.add_theme_constant_override("outline_size", 14)
	_score_value.add_theme_color_override("font_shadow_color", Color("d7a84a99"))
	_score_value.add_theme_constant_override("shadow_offset_x", 0)
	_score_value.add_theme_constant_override("shadow_offset_y", 4)
	add_child(_score_value)

	_combo_ghost_a = _make_label("", 148, Color(1.0, 0.2, 0.55, 0.0))
	_combo_ghost_a.position = COMBO_HOME
	_combo_ghost_a.size = Vector2(HUD_SIZE.x - 40, 160)
	_combo_ghost_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_ghost_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_combo_ghost_a)

	_combo_ghost_b = _make_label("", 148, Color(0.15, 0.9, 1.0, 0.0))
	_combo_ghost_b.position = COMBO_HOME
	_combo_ghost_b.size = Vector2(HUD_SIZE.x - 40, 160)
	_combo_ghost_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_ghost_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_combo_ghost_b)

	_combo_count = _make_label("", 148, TIER_COLORS[0])
	_combo_count.position = COMBO_HOME
	_combo_count.size = Vector2(HUD_SIZE.x - 40, 160)
	_combo_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_count.add_theme_color_override("font_outline_color", Color("140806"))
	_combo_count.add_theme_constant_override("outline_size", 18)
	_combo_count.visible = false
	add_child(_combo_count)

	_combo_caption = _make_label("连击", 36, COLOR_MUTED)
	_combo_caption.position = CAPTION_HOME
	_combo_caption.size = Vector2(HUD_SIZE.x - 48, 40)
	_combo_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_caption.visible = false
	add_child(_combo_caption)

	_word_box = Control.new()
	_word_box.name = "ComboWord"
	_word_box.position = WORD_HOME
	_word_box.size = Vector2(HUD_SIZE.x - 48, 96)
	_word_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_box.visible = false
	_word_box.pivot_offset = Vector2(_word_box.size.x, _word_box.size.y * 0.5)
	add_child(_word_box)

	_outline_word_a = _make_label("COMBO", 84, Color(1.0, 0.2, 0.7, 0.55))
	_outline_word_a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outline_word_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline_word_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline_word_a.add_theme_constant_override("outline_size", 0)
	_word_box.add_child(_outline_word_a)

	_outline_word_b = _make_label("COMBO", 84, Color(0.2, 0.95, 1.0, 0.55))
	_outline_word_b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outline_word_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_outline_word_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outline_word_b.add_theme_constant_override("outline_size", 0)
	_word_box.add_child(_outline_word_b)

	_glow_word = _make_label("COMBO", 84, Color(1, 0.7, 0.2, 0.0))
	_glow_word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_glow_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glow_word.add_theme_constant_override("outline_size", 22)
	_glow_word.add_theme_color_override("font_outline_color", Color(1.0, 0.45, 0.05, 0.45))
	_word_box.add_child(_glow_word)

	_empty_word = _make_label("COMBO", 84, COLOR_EMPTY_FILL)
	_empty_word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_empty_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_word.add_theme_color_override("font_outline_color", COLOR_EMPTY_STROKE)
	_empty_word.add_theme_constant_override("outline_size", 12)
	_word_box.add_child(_empty_word)

	_fill_clip = Control.new()
	_fill_clip.name = "FillClip"
	_fill_clip.position = Vector2.ZERO
	_fill_clip.size = Vector2(0, _word_box.size.y)
	_fill_clip.clip_contents = true
	_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word_box.add_child(_fill_clip)

	_fill_word = _make_label("COMBO", 84, TIER_COLORS[0])
	_fill_word.position = Vector2.ZERO
	_fill_word.size = _word_box.size
	_fill_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fill_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fill_word.add_theme_color_override("font_outline_color", Color("3a1808"))
	_fill_word.add_theme_constant_override("outline_size", 12)
	_fill_clip.add_child(_fill_word)

	_flash = ColorRect.new()
	_flash.color = Color(1, 0.85, 0.35, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_spark_layer = Control.new()
	_spark_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.z_index = 30
	add_child(_spark_layer)


func _make_label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


func _process(delta: float) -> void:
	_pulse += delta
	_hue_shift = fmod(_hue_shift + delta * (0.55 + float(_combo) * 0.04), 1.0)
	_sway_boost = lerpf(_sway_boost, 0.0, 1.0 - exp(-3.5 * delta))

	if absf(_display_score - float(_score)) > 0.5:
		_display_score = lerpf(_display_score, float(_score), 1.0 - exp(-16.0 * delta))
		_score_value.text = _format_score(int(round(_display_score)))

	if _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, 1.0 - exp(-9.0 * delta))
		position = _home + Vector2(
			randf_range(-1, 1) * _shake_strength,
			randf_range(-1, 1) * _shake_strength
		)
	elif position != _home:
		position = _home

	if _combo <= 0:
		return

	_update_live_colors()
	_update_sway(delta)
	_spawn_ambient_particles(delta)

	if _aura != null:
		_aura.intensity = _meter * (0.6 + 0.5 * absf(sin(_pulse * 5.0)))
		_aura.tint = _live_color(0.0)
		_aura.secondary = _live_color(0.33)
		_aura.queue_redraw()


func _update_live_colors() -> void:
	var main := _live_color(0.0)
	var accent_a := _live_color(0.28)
	var accent_b := _live_color(0.62)
	_fill_word.add_theme_color_override("font_color", main)
	_combo_count.add_theme_color_override("font_color", main.lightened(0.12))
	_combo_caption.add_theme_color_override("font_color", accent_a.lightened(0.2))
	_glow_word.add_theme_color_override(
		"font_color", Color(main.r, main.g, main.b, 0.3 + 0.55 * _meter)
	)
	_glow_word.add_theme_color_override(
		"font_outline_color", Color(accent_a.r, accent_a.g, accent_a.b, 0.55)
	)
	_outline_word_a.add_theme_color_override("font_color", Color(accent_a.r, accent_a.g, accent_a.b, 0.55))
	_outline_word_b.add_theme_color_override("font_color", Color(accent_b.r, accent_b.g, accent_b.b, 0.55))
	_outline_word_a.position = Vector2(-3.0 - 2.0 * sin(_pulse * 7.0), 1.5 * cos(_pulse * 5.0))
	_outline_word_b.position = Vector2(3.0 + 2.0 * cos(_pulse * 6.0), -1.5 * sin(_pulse * 4.5))
	_edge_glow.color = Color(main.r, main.g, main.b, 0.1 + 0.45 * _meter * (0.7 + 0.3 * absf(sin(_pulse * 8.0))))


func _update_sway(_delta: float) -> void:
	var intensity := 0.55 + float(mini(_combo, 20)) * 0.04 + _sway_boost
	var sway_x := sin(_pulse * 3.2) * 6.0 * intensity
	var sway_y := cos(_pulse * 2.4) * 5.0 * intensity
	var sway_rot := sin(_pulse * 2.8) * 3.2 * intensity + cos(_pulse * 5.1) * 1.4 * intensity

	if _punch_tween == null or not _punch_tween.is_valid():
		var breathe := 1.0 + 0.045 * sin(_pulse * 5.5) * intensity
		_combo_count.scale = Vector2(breathe, breathe * (1.0 + 0.02 * sin(_pulse * 7.0)))
		_combo_count.rotation_degrees = sway_rot * 0.55
		_combo_count.position = COMBO_HOME + Vector2(sway_x * 0.35, sway_y)

	_combo_caption.position = CAPTION_HOME + Vector2(sway_x * 0.2, sway_y * 0.35)
	_combo_caption.rotation_degrees = -sway_rot * 0.25

	_word_box.position = WORD_HOME + Vector2(sway_x, sway_y * 0.6)
	_word_box.rotation_degrees = sway_rot
	var word_breathe := 1.0 + 0.035 * sin(_pulse * 4.2 + 1.2) * intensity
	_word_box.scale = Vector2(word_breathe, word_breathe)


func _spawn_ambient_particles(delta: float) -> void:
	_ambient_accum += delta * (10.0 + float(mini(_combo, 25)) * 1.6 + _meter * 8.0)
	while _ambient_accum >= 1.0:
		_ambient_accum -= 1.0
		_spawn_one_ambient()


func _spawn_one_ambient() -> void:
	var kind := randi() % 3
	var origin := Vector2(
		HUD_SIZE.x - randf_range(36.0, 220.0),
		randf_range(170.0, 460.0)
	)
	var color := _live_color(randf())
	if kind == 0:
		_spawn_ember(origin, color, randf_range(0.45, 0.9))
	elif kind == 1:
		_spawn_star(origin, color, randf_range(0.5, 1.0))
	else:
		_spawn_orbit_spark(origin, color)


func sync_state(score: int, combo: int, meter: float, animate_score: bool = true) -> void:
	_score = maxi(score, 0)
	_combo = maxi(combo, 0)
	_meter = clampf(meter, 0.0, 1.0)
	if not animate_score:
		_display_score = float(_score)
		_score_value.text = _format_score(_score)
	_refresh_visuals(true)


func play_hit(total_score: int, points: int, combo: int, meter: float) -> void:
	_score = maxi(total_score, 0)
	_combo = maxi(combo, 0)
	_meter = clampf(meter, 0.0, 1.0)
	_sway_boost = minf(2.2, 0.8 + float(combo) * 0.06)
	_refresh_visuals(false)
	_punch_combo(combo)
	_chromatic_ghost(combo)
	_flash_burst(combo)
	_edge_strike(combo)
	_spawn_point_popup(points, combo)
	_spawn_sparks(combo)
	_spawn_star_burst(combo)
	_spawn_slash(combo)
	_shake_strength = minf(18.0, 4.0 + float(combo) * 0.55)
	if combo == 5 or combo == 10 or combo == 15 or combo == 20 or (combo > 20 and combo % 5 == 0):
		_milestone_pulse(combo)


func play_combo_break() -> void:
	_combo = 0
	_meter = 0.0
	_sway_boost = 0.0
	_edge_glow.color.a = 0.0
	if _aura != null:
		_aura.visible = false
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_combo_count.modulate = Color(0.55, 0.45, 0.4, 1)
	var tween := create_tween()
	tween.tween_property(_combo_count, "modulate:a", 0.0, 0.32)
	tween.parallel().tween_property(_combo_count, "scale", Vector2(0.6, 1.4), 0.32)
	if _word_box != null:
		tween.parallel().tween_property(_word_box, "modulate:a", 0.0, 0.28)
	tween.tween_callback(func() -> void:
		_combo_count.visible = false
		_combo_caption.visible = false
		_combo_count.modulate = Color.WHITE
		_combo_count.scale = Vector2.ONE
		_combo_count.rotation_degrees = 0.0
		_combo_count.position = COMBO_HOME
		if _word_box != null:
			_word_box.visible = false
			_word_box.modulate.a = 1.0
			_word_box.rotation_degrees = 0.0
			_word_box.scale = Vector2.ONE
			_word_box.position = WORD_HOME
		_refresh_visuals(true)
	)


## 连击收束发钱时的飘字。
func play_gold_bonus(amount: int) -> void:
	if amount <= 0:
		return
	var popup := _make_label("+%dG" % amount, 48, Color("9dff7a"))
	popup.add_theme_color_override("font_outline_color", Color("102010"))
	popup.add_theme_constant_override("outline_size", 10)
	popup.position = Vector2(HUD_SIZE.x - 240, 250)
	popup.z_index = 45
	add_child(popup)
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.4, 1.6)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.2)
	tween.tween_property(popup, "position", popup.position + Vector2(-30, -80), 0.75)
	tween.tween_property(popup, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.chain().tween_callback(popup.queue_free)


func reset_visuals() -> void:
	_score = 0
	_combo = 0
	_meter = 0.0
	_display_score = 0.0
	_sway_boost = 0.0
	_score_value.text = "0"
	_refresh_visuals(true)


func set_home(pos: Vector2) -> void:
	_home = pos
	position = pos


func _refresh_visuals(instant: bool) -> void:
	var fill_color := _live_color(0.0) if _combo > 0 else TIER_COLORS[0]
	_fill_word.add_theme_color_override("font_color", fill_color)
	_combo_count.add_theme_color_override("font_color", fill_color)

	var word_width := _word_box.size.x if _word_box != null else HUD_SIZE.x - 48.0
	var target_w := word_width * _meter
	var target_x := word_width - target_w
	if instant or _fill_clip == null:
		_set_fill_clip(target_x, target_w)
	else:
		var from_x := _fill_clip.position.x
		var from_w := _fill_clip.size.x
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(
			func(t: float) -> void:
				_set_fill_clip(lerpf(from_x, target_x, t), lerpf(from_w, target_w, t)),
			0.0,
			1.0,
			0.22
		)

	var show_combo := _combo > 0
	_combo_count.visible = show_combo
	_combo_caption.visible = show_combo
	if _word_box != null:
		_word_box.visible = show_combo
	if _aura != null:
		_aura.visible = show_combo
	if not show_combo:
		_edge_glow.color.a = 0.0
		_combo_ghost_a.modulate.a = 0.0
		_combo_ghost_b.modulate.a = 0.0
		return
	_combo_count.text = "×%d" % _combo
	_combo_ghost_a.text = _combo_count.text
	_combo_ghost_b.text = _combo_count.text
	_empty_word.modulate.a = 0.35 + 0.55 * (1.0 - _meter)
	_word_box.modulate = Color(1, 1, 1, 0.7 + 0.3 * maxf(_meter, 0.2))


func _set_fill_clip(clip_x: float, clip_w: float) -> void:
	if _fill_clip == null or _fill_word == null:
		return
	_fill_clip.position.x = clip_x
	_fill_clip.size.x = maxf(clip_w, 0.0)
	_fill_clip.size.y = _word_box.size.y if _word_box != null else _fill_clip.size.y
	_fill_word.position = Vector2(-clip_x, 0.0)
	_fill_word.size = _word_box.size if _word_box != null else _fill_word.size


func _tier_for(combo: int) -> int:
	if combo >= 20:
		return 3
	if combo >= 10:
		return 2
	if combo >= 5:
		return 1
	return 0


## 以档位色为底，叠一段流光色相，让文字一直在变色。
func _live_color(phase_offset: float) -> Color:
	var base: Color = TIER_COLORS[_tier_for(_combo)]
	var hue := fmod(_hue_shift + phase_offset, 1.0)
	var shift := Color.from_hsv(hue, 0.75, 1.0)
	return base.lerp(shift, 0.55).lightened(0.08)


func _punch_combo(combo: int) -> void:
	_combo_count.visible = true
	_combo_caption.visible = true
	_combo_count.text = "×%d" % combo
	_combo_count.pivot_offset = Vector2(_combo_count.size.x, _combo_count.size.y * 0.5)
	_combo_caption.pivot_offset = Vector2(_combo_caption.size.x, _combo_caption.size.y * 0.5)
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_combo_count.scale = Vector2(2.5, 0.3)
	_combo_count.rotation_degrees = randf_range(-14, 14)
	_combo_count.modulate = Color(2.2, 2.0, 1.5, 1.0)
	_punch_tween = create_tween()
	var peak := 1.6 + minf(0.6, float(combo) * 0.028)
	_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(_combo_count, "scale", Vector2(peak, peak * 0.78), 0.08)
	_punch_tween.parallel().tween_property(_combo_count, "modulate", Color.WHITE, 0.12)
	_punch_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(_combo_count, "scale", Vector2.ONE, 0.42)
	_punch_tween.parallel().tween_property(_combo_count, "rotation_degrees", 0.0, 0.35)
	_combo_caption.scale = Vector2(0.65, 0.65)
	var cap := create_tween()
	cap.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cap.tween_property(_combo_caption, "scale", Vector2.ONE, 0.28)


func _chromatic_ghost(combo: int) -> void:
	_combo_ghost_a.text = "×%d" % combo
	_combo_ghost_b.text = "×%d" % combo
	var c_a := _live_color(0.2)
	var c_b := _live_color(0.7)
	_combo_ghost_a.add_theme_color_override("font_color", c_a)
	_combo_ghost_b.add_theme_color_override("font_color", c_b)
	_combo_ghost_a.modulate.a = 0.9
	_combo_ghost_b.modulate.a = 0.9
	var spread := 22.0 + float(mini(combo, 16))
	_combo_ghost_a.position = COMBO_HOME + Vector2(-spread, -8)
	_combo_ghost_b.position = COMBO_HOME + Vector2(spread, 8)
	if _ghost_tween != null and _ghost_tween.is_valid():
		_ghost_tween.kill()
	_ghost_tween = create_tween().set_parallel(true)
	_ghost_tween.tween_property(_combo_ghost_a, "position", COMBO_HOME, 0.32)
	_ghost_tween.tween_property(_combo_ghost_b, "position", COMBO_HOME, 0.32)
	_ghost_tween.tween_property(_combo_ghost_a, "modulate:a", 0.0, 0.32)
	_ghost_tween.tween_property(_combo_ghost_b, "modulate:a", 0.0, 0.32)


func _flash_burst(combo: int) -> void:
	var c := _live_color(randf())
	c.a = 0.75
	_flash.color = c
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD)


func _edge_strike(combo: int) -> void:
	var c := _live_color(0.1)
	_edge_glow.color = Color(c.r, c.g, c.b, 0.98)
	var tween := create_tween()
	tween.tween_property(_edge_glow, "color:a", 0.14 + 0.4 * _meter, 0.38)


func _milestone_pulse(combo: int) -> void:
	_glow_word.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_glow_word, "modulate:a", 0.0, 0.55)
	_spawn_ring(_live_color(0.0))
	_spawn_ring(_live_color(0.33), 0.1)
	_spawn_ring(_live_color(0.66), 0.2)
	_spawn_star_burst(combo + 8)


func _spawn_point_popup(points: int, combo: int) -> void:
	var popup := _make_label("+%d" % points, 42 + mini(combo * 2, 30), _live_color(0.15))
	popup.add_theme_color_override("font_outline_color", Color("1a1008"))
	popup.add_theme_constant_override("outline_size", 10)
	popup.position = Vector2(HUD_SIZE.x - 230, 280)
	popup.z_index = 40
	add_child(popup)
	popup.pivot_offset = popup.size * 0.5
	popup.scale = Vector2(0.35, 1.9)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.18)
	tween.tween_property(popup, "position", popup.position + Vector2(-48, -100), 0.72)
	tween.tween_property(popup, "rotation_degrees", randf_range(-12, 12), 0.72)
	tween.tween_property(popup, "modulate:a", 0.0, 0.4).set_delay(0.35)
	tween.chain().tween_callback(popup.queue_free)


func _spawn_sparks(combo: int) -> void:
	var origin := Vector2(HUD_SIZE.x - 40.0, 400.0)
	var count := 18 + mini(combo * 2, 28)
	for i in range(count):
		_spawn_ember(
			origin + Vector2(randf_range(-36, 16), randf_range(-28, 28)),
			_live_color(float(i) * 0.07),
			randf_range(0.35, 0.7)
		)


func _spawn_star_burst(combo: int) -> void:
	var origin := Vector2(HUD_SIZE.x - 120.0, 230.0)
	var count := 10 + mini(combo, 14)
	for i in range(count):
		_spawn_star(origin, _live_color(float(i) * 0.09), randf_range(0.4, 0.85))


func _spawn_ember(origin: Vector2, color: Color, life: float) -> void:
	var spark := ColorRect.new()
	var side := randf_range(3.0, 11.0)
	spark.size = Vector2(side, side * randf_range(0.3, 1.3))
	spark.color = color.lightened(randf_range(0.0, 0.4))
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.pivot_offset = spark.size * 0.5
	spark.position = origin
	_spark_layer.add_child(spark)
	var angle := randf_range(-PI * 1.1, PI * 0.15)
	var dist := randf_range(50.0, 170.0)
	var end := origin + Vector2(cos(angle), sin(angle)) * dist
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "position", end, life)
	tween.tween_property(spark, "modulate:a", 0.0, life)
	tween.tween_property(spark, "rotation", randf_range(-4.0, 4.0), life)
	tween.tween_property(spark, "size", spark.size * randf_range(0.15, 0.45), life)
	tween.chain().tween_callback(spark.queue_free)


func _spawn_star(origin: Vector2, color: Color, life: float) -> void:
	var star := _StarParticle.new()
	star.color = color
	star.radius = randf_range(4.0, 9.0)
	star.size = Vector2(star.radius * 2.4, star.radius * 2.4)
	star.position = origin
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.add_child(star)
	var angle := randf_range(-PI, PI)
	var dist := randf_range(40.0, 140.0)
	var end := origin + Vector2(cos(angle), sin(angle)) * dist
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "position", end, life)
	tween.tween_property(star, "modulate:a", 0.0, life)
	tween.tween_property(star, "rotation", randf_range(-6.0, 6.0), life)
	tween.tween_method(func(v: float) -> void:
		star.radius = v
		star.queue_redraw()
	, star.radius, star.radius * 0.2, life)
	tween.chain().tween_callback(star.queue_free)


func _spawn_orbit_spark(origin: Vector2, color: Color) -> void:
	var spark := ColorRect.new()
	spark.size = Vector2(4, 4)
	spark.color = color
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.pivot_offset = spark.size * 0.5
	_spark_layer.add_child(spark)
	var radius := randf_range(18.0, 48.0)
	var start_angle := randf() * TAU
	var duration := randf_range(0.45, 0.85)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var a := start_angle + t * TAU * 1.25
		spark.position = origin + Vector2(cos(a), sin(a) * 0.65) * radius
		spark.modulate.a = 1.0 - t
	, 0.0, 1.0, duration)
	tween.tween_callback(spark.queue_free)


func _spawn_slash(combo: int) -> void:
	for i in range(2):
		var slash := ColorRect.new()
		var color := _live_color(0.15 * float(i))
		color.a = 0.85
		slash.color = color
		slash.size = Vector2(260 + i * 30, 5 + mini(combo, 10) + i * 2)
		slash.pivot_offset = slash.size * 0.5
		slash.position = Vector2(HUD_SIZE.x - 310, 210 + i * 18)
		slash.rotation = deg_to_rad(randf_range(-32, -8) + i * 8)
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spark_layer.add_child(slash)
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "position:x", slash.position.x - 90, 0.2)
		tween.tween_property(slash, "size:x", 36.0, 0.24)
		tween.tween_property(slash, "modulate:a", 0.0, 0.24)
		tween.chain().tween_callback(slash.queue_free)


func _spawn_ring(color: Color, delay: float = 0.0) -> void:
	var ring := _RingBurst.new()
	ring.color = color
	ring.position = Vector2(HUD_SIZE.x - 280, 170)
	ring.size = Vector2(250, 250)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.add_child(ring)
	var tween := create_tween().set_parallel(true)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(v: float) -> void:
		ring.radius = v
		ring.queue_redraw()
	, 10.0, 118.0, 0.44)
	tween.tween_property(ring, "modulate:a", 0.0, 0.44)
	tween.chain().tween_callback(ring.queue_free)


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


class _RingBurst extends Control:
	var color := Color.WHITE
	var radius := 8.0

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, radius, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.9), 5.0)
		draw_arc(c, radius * 0.7, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.35), 3.0)


class _HeatAura extends Control:
	var intensity := 0.0
	var tint := Color("e8c56a")
	var secondary := Color("ff6a3c")

	func _draw() -> void:
		if intensity <= 0.02:
			return
		var c := Vector2(size.x * 0.72, size.y * 0.42)
		for i in range(5):
			var r := 36.0 + float(i) * 34.0
			var a := intensity * (0.2 - float(i) * 0.03)
			var col := tint if i % 2 == 0 else secondary
			draw_circle(c, r, Color(col.r, col.g, col.b, a))


class _StarParticle extends Control:
	var color := Color.WHITE
	var radius := 6.0

	func _draw() -> void:
		var c := size * 0.5
		var tips: PackedVector2Array = PackedVector2Array()
		for i in range(8):
			var ang := -PI * 0.5 + float(i) * PI * 0.25
			var r := radius if i % 2 == 0 else radius * 0.4
			tips.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(tips, Color(color.r, color.g, color.b, 0.95))
