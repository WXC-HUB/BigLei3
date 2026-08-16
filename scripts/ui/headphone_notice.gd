class_name HeadphoneNotice
extends Control
## 开始游戏与第一关之间的黑屏提示：五行字逐行砸下来，最后一行落定后进关。
##
## 每行都是「先慢后快地缩小落地 → 命中冲击 → 回弹」，命中那一刻复用棋盘的
## 打击特效，保证和局内的打击语汇是同一套。

const CELL_FX := preload("res://vfx/cell_fx.gd")

## 行与行之间的节奏，最后一行留得更久一点当作重音。
const LINE_INTERVAL := 0.2
const FINAL_LINE_INTERVAL := 0.34
const HOLD_SECONDS := 0.9
## 命中冲击的暖色，和标题、金币的金色同族。
const IMPACT_TINT := Color(1.0, 0.78, 0.36)
## 前四行逐行升调把情绪推上去，最后一行反过来压低、加响，落成一记重音——
## 一路升上去收不住尾。
const HIT_PITCH_RANGE := Vector2(0.94, 1.18)
const HIT_VOLUME_RANGE := Vector2(-4.0, 0.0)
const FINAL_HIT_PITCH := 0.78
const FINAL_HIT_VOLUME := 3.0

@onready var shade: ColorRect = $Shade
@onready var hit_sfx: AudioStreamPlayer = %HitSFX
@onready var fx_layer: Control = %Fx
@onready var lines_box: VBoxContainer = %Lines

var _lines: Array[Label] = []
var _lines_home := Vector2.ZERO
var _skipped := false
var _presenting := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in lines_box.get_children():
		if child is Label:
			_lines.append(child)


## 播完整段提示后返回；调用方 await 它再开局。
func present() -> void:
	if _presenting:
		return
	_presenting = true
	_skipped = false
	visible = true
	shade.color = Color(0.0, 0.0, 0.0, 0.0)
	# Let the container lay the lines out before any of their sizes get read;
	# pivots taken from a zero-sized label would scale from the wrong corner.
	await get_tree().process_frame
	_lines_home = lines_box.position
	for line in _lines:
		line.modulate.a = 0.0
	var open := create_tween()
	open.tween_property(shade, "color:a", 1.0, 0.22)
	await open.finished

	for index in _lines.size():
		if _skipped:
			break
		# 越往后砸得越重，最后一行是重音。
		var power := 0.55 + 0.45 * (float(index) / maxf(float(_lines.size() - 1), 1.0))
		await _slam_line(_lines[index], power, index == _lines.size() - 1)
		if _skipped:
			break
		var gap := FINAL_LINE_INTERVAL if index == _lines.size() - 2 else LINE_INTERVAL
		await get_tree().create_timer(gap).timeout

	if _skipped:
		_settle_all_lines()
	await get_tree().create_timer(HOLD_SECONDS if not _skipped else 0.3).timeout
	var close := create_tween().set_parallel(true)
	close.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close.tween_property(lines_box, "modulate:a", 0.0, 0.24)
	close.tween_property(shade, "color:a", 0.0, 0.34).set_delay(0.14)
	await close.finished
	visible = false
	lines_box.modulate.a = 1.0
	lines_box.position = _lines_home
	_presenting = false


## 慢起快落：EASE_IN 让这一行在最后几帧才真正砸下来，落点才有重量。
func _slam_line(line: Label, power: float, is_final: bool) -> void:
	line.pivot_offset = line.size * 0.5
	line.scale = Vector2.ONE * _entry_scale(line, power)
	line.rotation = deg_to_rad(randf_range(-2.6, 2.6))
	line.modulate.a = 0.0
	var drop := create_tween().set_parallel(true)
	drop.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	drop.tween_property(line, "scale", Vector2.ONE, 0.17)
	drop.tween_property(line, "rotation", 0.0, 0.17)
	drop.tween_property(line, "modulate:a", 1.0, 0.1)
	await drop.finished
	if _skipped:
		return
	_play_impact(line, power, is_final)


## The wide final line would run off both edges at a flat 2.8x, so the entry
## scale is clamped to whatever still fits across the viewport.
func _entry_scale(line: Label, power: float) -> float:
	var wanted := 1.0 + 1.8 * power
	var text_width := line.get_theme_font("font").get_string_size(
		line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line.get_theme_font_size("font_size")
	).x
	if text_width <= 1.0:
		return wanted
	var room := size.x * 0.98 / text_width
	return clampf(wanted, 1.05, maxf(room, 1.05))


func _play_impact(line: Label, power: float, is_final: bool) -> void:
	_play_hit_sfx(power, is_final)
	CELL_FX.play_impact_hit(fx_layer, line.global_position + line.size * 0.5, IMPACT_TINT)
	# 落地后的挤压回弹，比单纯停住更有肉感。
	var rebound := create_tween()
	rebound.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rebound.tween_property(line, "scale", Vector2(1.0 + 0.1 * power, 1.0 - 0.09 * power), 0.05)
	rebound.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rebound.tween_property(line, "scale", Vector2.ONE, 0.2)
	_shake(power)
	_flash(power)


func _play_hit_sfx(power: float, is_final: bool) -> void:
	if hit_sfx == null or hit_sfx.stream == null:
		return
	if is_final:
		hit_sfx.pitch_scale = FINAL_HIT_PITCH
		hit_sfx.volume_db = FINAL_HIT_VOLUME
	else:
		hit_sfx.pitch_scale = lerpf(HIT_PITCH_RANGE.x, HIT_PITCH_RANGE.y, power)
		hit_sfx.volume_db = lerpf(HIT_VOLUME_RANGE.x, HIT_VOLUME_RANGE.y, power)
	hit_sfx.play()


## 只晃文字，不晃底板：底板是全屏黑，一旦移动就会从边缘漏出背后的画面。
func _shake(power: float) -> void:
	var shake := create_tween()
	var offsets := [
		Vector2(0.0, 13.0), Vector2(-7.0, -8.0), Vector2(5.0, 6.0), Vector2(-3.0, -3.0)
	]
	for offset in offsets:
		shake.tween_property(lines_box, "position", _lines_home + offset * power, 0.035)
	shake.tween_property(lines_box, "position", _lines_home, 0.05)


func _flash(power: float) -> void:
	var flash := create_tween()
	var peak := 0.1 * power
	flash.tween_property(shade, "color", Color(peak, peak * 0.92, peak * 0.8, 1.0), 0.04)
	flash.tween_property(shade, "color", Color(0.0, 0.0, 0.0, 1.0), 0.22)


func _settle_all_lines() -> void:
	for line in _lines:
		line.scale = Vector2.ONE
		line.rotation = 0.0
		line.modulate.a = 1.0
	lines_box.position = _lines_home
	shade.color = Color(0.0, 0.0, 0.0, 1.0)


## Skipping is handled in _input rather than _gui_input so a key press works
## without the notice holding focus, and so the click never reaches the board.
func _input(event: InputEvent) -> void:
	if not _presenting or _skipped:
		return
	var pressed_mouse: bool = event is InputEventMouseButton and event.pressed
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	if pressed_mouse or pressed_key:
		_skipped = true
		get_viewport().set_input_as_handled()
