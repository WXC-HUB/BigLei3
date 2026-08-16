class_name RedstartUnlock
extends Control

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const CELL_FX := preload("res://vfx/cell_fx.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")
const SHUIQU_TEXTURE := preload("res://my_asset/shuiqu.png")

## 撩到第几下水渠出场。
const RAGE_HOVERS := 21
## 立起来的全程时长。慢是重点：太快就成了弹出窗口，不是"轰然立起"。
const RISE_SECONDS := 2.4
## 立起过程中的震幅，从起步到落定一路加码。
const RISE_SHAKE_RANGE := Vector2(5.0, 30.0)
## 每一记闷响的时间点，越往后越密，听起来像越推越急。
const RISE_THUDS := [
	0.04, 0.17, 0.3, 0.42, 0.53, 0.63, 0.72, 0.79, 0.85, 0.9, 0.94, 0.97
]
## 震动时底板要外扩，否则整页一晃就会从边缘漏出后面的画面。
const SHAKE_OVERSCAN := 80.0
const HITSTOP_SECONDS := 0.09
const HITSTOP_TIME_SCALE := 0.05

@onready var photo_stage: Control = $PhotoStage
@onready var finale: Control = $Finale
@onready var final_bird: TextureRect = $Finale/Bird
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var dimmer: ColorRect = $Dimmer
@onready var icon_pattern: ColorRect = $IconPattern
@onready var redstart_call: AudioStreamPlayer = $RedstartCall
@onready var impact_sfx: AudioStreamPlayer = $ImpactSFX

var _photo_frames: Array[Control] = []
var _photo_home_positions: Array[Vector2] = []
var _photo_home_rotations: Array[float] = []
var _sway_tweens: Array[Tween] = []
var _name_home_position := Vector2.ZERO
var _tagline_home_position := Vector2.ZERO
var _name_home_center := Vector2.ZERO
var _tagline_home_center := Vector2.ZERO
var _name_home_font_size := 0
var _tagline_home_font_size := 0
var _name_home_text := ""
var _tagline_home_text := ""
var _label_layout_captured := false
var _labels_swapped := false
var _label_swap_tween: Tween
var _hover_count := 0
var _raging := false
var _aqueduct: TextureRect
var _page_home := Vector2.ZERO
var _thud_index := 0


func _ready() -> void:
	visible = false
	photo_stage.visible = false
	RevealMotion.prepare(finale, final_bird, [name_label, tagline_label, effect_label], continue_button)
	_photo_frames.assign([
		$PhotoStage/Photo01,
		$PhotoStage/Photo02,
		$PhotoStage/Photo03,
		$PhotoStage/Photo04,
	])
	ButtonMotion.bind(continue_button, continue_button, 1.0)
	ButtonMotion.bind_hover(final_bird, final_bird, 1.6)
	continue_button.mouse_entered.connect(_play_redstart_call)
	final_bird.mouse_entered.connect(_on_bird_hovered)


func _play_redstart_call() -> void:
	redstart_call.play()


func _on_bird_hovered() -> void:
	if _raging:
		return
	_hover_count += 1
	if _hover_count >= RAGE_HOVERS:
		_play_rage()
		return
	_play_redstart_call()
	_swap_name_and_tagline()


# ---------------------------------------------------------------------------
# 水渠出场
# ---------------------------------------------------------------------------


## 撩太多次了：小鸟原地消失，水渠从画面下方轰然立起，全程震到落定。
func _play_rage() -> void:
	_raging = true
	easter_egg_triggered.emit(Catalog.REDSTART_AQUEDUCT)
	final_bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_home = position
	_lock_title_to_aqueduct()
	# 整页要晃，底板得先外扩一圈，不然边缘会漏。
	_set_backdrop_overscan(SHAKE_OVERSCAN)
	await _vanish_bird()
	await _raise_aqueduct()


## 水渠上位：主标题换成副标题那句并停在大字位，之后不再跟着 hover 互换；
## 副标题这时收起来，免得和主标题重复。
func _lock_title_to_aqueduct() -> void:
	_reset_label_layout()
	name_label.text = _tagline_home_text
	tagline_label.visible = false


func _vanish_bird() -> void:
	redstart_call.pitch_scale = 0.62
	redstart_call.play()
	final_bird.pivot_offset = final_bird.size * 0.5
	CELL_FX.play_impact_hit(
		self,
		final_bird.position + final_bird.size * 0.5,
		Color(0.86, 0.92, 1.0)
	)
	var vanish := create_tween().set_parallel(true)
	vanish.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	vanish.tween_property(final_bird, "scale", Vector2(1.3, 0.15), 0.16)
	vanish.tween_property(final_bird, "modulate:a", 0.0, 0.14)
	await vanish.finished
	final_bird.visible = false


func _raise_aqueduct() -> void:
	_aqueduct = TextureRect.new()
	_aqueduct.name = "Aqueduct"
	_aqueduct.texture = SHUIQU_TEXTURE
	_aqueduct.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aqueduct.stretch_mode = TextureRect.STRETCH_SCALE
	_aqueduct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aqueduct.size = size
	_aqueduct.pivot_offset = size * 0.5
	finale.add_child(_aqueduct)
	# 沉到 Finale 的最底层：标题、副标题、效果说明和按钮都压在水渠上面。
	finale.move_child(_aqueduct, 0)

	var start := Vector2(0.0, size.y)
	_aqueduct.position = start
	_aqueduct.rotation = 0.055
	_thud_index = 0

	var rise := create_tween()
	rise.set_trans(Tween.TRANS_LINEAR)
	rise.tween_method(_advance_rise, 0.0, 1.0, RISE_SECONDS)
	await rise.finished

	await _play_lock_impact()


## 位置、倾角和整页抖动共用同一个进度，三者必须同拍。
func _advance_rise(progress: float) -> void:
	if not is_instance_valid(_aqueduct):
		return
	# smoothstep：起步沉、中段稳、临落定再收，重物被顶上来的手感。
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_aqueduct.position = Vector2(0.0, size.y * (1.0 - eased))
	_aqueduct.rotation = 0.055 * (1.0 - eased)
	# 高频伪随机比真随机好用：同一进度永远抖到同一处，回放可复现。
	var amplitude := lerpf(RISE_SHAKE_RANGE.x, RISE_SHAKE_RANGE.y, progress * progress)
	position = _page_home + Vector2(
		sin(progress * 391.0) * amplitude,
		cos(progress * 277.0) * amplitude * 0.7
	)
	while _thud_index < RISE_THUDS.size() and progress >= float(RISE_THUDS[_thud_index]):
		_play_thud(float(_thud_index) / float(RISE_THUDS.size()))
		_thud_index += 1


func _play_thud(ramp: float) -> void:
	impact_sfx.pitch_scale = lerpf(0.52, 0.86, ramp)
	impact_sfx.volume_db = lerpf(-6.0, 2.0, ramp)
	impact_sfx.play()
	# 每一记闷响都从底边扬起一蓬碎屑，位置错开才不像同一个特效在重播。
	CELL_FX.play_impact_hit(
		self,
		Vector2(size.x * (0.18 + 0.64 * fmod(ramp * 3.7, 1.0)), size.y - 40.0),
		Color(0.82, 0.76, 0.62)
	)


func _play_lock_impact() -> void:
	impact_sfx.pitch_scale = 0.44
	impact_sfx.volume_db = 4.0
	impact_sfx.play()
	CELL_FX.play_impact_hit(self, Vector2(size.x * 0.5, size.y * 0.62), Color(1.0, 0.88, 0.6))
	# 落定不是急停：先冲过头一点再压回去，才有砸实的分量。
	var settle := create_tween()
	settle.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	settle.tween_property(_aqueduct, "position", Vector2(0.0, -22.0), 0.07)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(_aqueduct, "position", Vector2.ZERO, 0.26)
	_slam_shake()
	await _hit_stop()
	await get_tree().create_timer(0.3).timeout
	position = _page_home
	_set_backdrop_overscan(0.0)
	_lift_continue_button()


## 水渠的画面很花，按钮原本的半透明底板会糊在里面看不见，给它加个实底。
func _lift_continue_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	style.border_color = Color(1.0, 0.85, 0.45, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12.0)
	for state in ["normal", "hover", "pressed"]:
		continue_button.add_theme_stylebox_override(state, style)
	continue_button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	continue_button.pivot_offset = continue_button.size * 0.5
	var pop := create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(continue_button, "scale", Vector2(1.16, 1.16), 0.14)
	pop.tween_property(continue_button, "scale", Vector2.ONE, 0.2)


func _slam_shake() -> void:
	var shake := create_tween()
	for offset in [Vector2(0, 34), Vector2(-24, -20), Vector2(17, 13), Vector2(-9, -7)]:
		shake.tween_property(self, "position", _page_home + offset, 0.04)
	shake.tween_property(self, "position", _page_home, 0.06)


## 卡帧要用不受时间缩放影响的计时器，否则它会被自己拉长、永远等不到。
func _hit_stop() -> void:
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(HITSTOP_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0


func _set_backdrop_overscan(margin: float) -> void:
	for backdrop in [dimmer, icon_pattern]:
		backdrop.offset_left = -margin
		backdrop.offset_top = -margin
		backdrop.offset_right = margin
		backdrop.offset_bottom = margin


## 这一页在一次运行里可能被再次 present，水渠留下的状态必须全部还原。
func _reset_rage() -> void:
	Engine.time_scale = 1.0
	_hover_count = 0
	_raging = false
	_thud_index = 0
	if _aqueduct != null and is_instance_valid(_aqueduct):
		_aqueduct.queue_free()
	_aqueduct = null
	if _page_home != Vector2.ZERO or position != Vector2.ZERO:
		position = _page_home
	_set_backdrop_overscan(0.0)
	if _label_layout_captured:
		name_label.text = _name_home_text
		tagline_label.text = _tagline_home_text
	tagline_label.visible = true
	final_bird.visible = true
	final_bird.scale = Vector2.ONE
	final_bird.modulate.a = 1.0
	final_bird.mouse_filter = Control.MOUSE_FILTER_STOP
	for state in ["normal", "hover", "pressed"]:
		continue_button.remove_theme_stylebox_override(state)
	continue_button.remove_theme_color_override("font_color")
	continue_button.scale = Vector2.ONE


func _capture_label_layout() -> void:
	if _label_layout_captured:
		return
	_name_home_position = name_label.position
	_tagline_home_position = tagline_label.position
	_name_home_center = name_label.position + name_label.size * 0.5
	_tagline_home_center = tagline_label.position + tagline_label.size * 0.5
	_name_home_font_size = name_label.get_theme_font_size("font_size")
	_tagline_home_font_size = tagline_label.get_theme_font_size("font_size")
	_name_home_text = name_label.text
	_tagline_home_text = tagline_label.text
	_label_layout_captured = true


func _reset_label_layout() -> void:
	if _label_swap_tween != null and _label_swap_tween.is_valid():
		_label_swap_tween.kill()
	name_label.position = _name_home_position
	tagline_label.position = _tagline_home_position
	name_label.add_theme_font_size_override("font_size", _name_home_font_size)
	tagline_label.add_theme_font_size_override("font_size", _tagline_home_font_size)
	_labels_swapped = false


func _swap_name_and_tagline() -> void:
	var name_center_start := name_label.position + name_label.size * 0.5
	var tagline_center_start := tagline_label.position + tagline_label.size * 0.5
	var name_center_target := _name_home_center if _labels_swapped else _tagline_home_center
	var tagline_center_target := _tagline_home_center if _labels_swapped else _name_home_center
	var name_font_target := _name_home_font_size if _labels_swapped else _tagline_home_font_size
	var tagline_font_target := _tagline_home_font_size if _labels_swapped else _name_home_font_size
	var name_font_start := name_label.get_theme_font_size("font_size")
	var tagline_font_start := tagline_label.get_theme_font_size("font_size")
	_labels_swapped = not _labels_swapped
	if _label_swap_tween != null and _label_swap_tween.is_valid():
		_label_swap_tween.kill()
	_label_swap_tween = create_tween()
	_label_swap_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_label_swap_tween.tween_method(
		func(progress: float) -> void:
			name_label.add_theme_font_size_override("font_size", roundi(lerpf(name_font_start, name_font_target, progress)))
			tagline_label.add_theme_font_size_override("font_size", roundi(lerpf(tagline_font_start, tagline_font_target, progress)))
			name_label.position = name_center_start.lerp(name_center_target, progress) - name_label.size * 0.5
			tagline_label.position = tagline_center_start.lerp(tagline_center_target, progress) - tagline_label.size * 0.5,
		0.0,
		1.0,
		0.42
	)


func present() -> void:
	_reset_rage()
	continue_button.disabled = true
	continue_button.visible = false
	photo_stage.visible = false
	RevealMotion.prepare(finale, final_bird, [name_label, tagline_label, effect_label], continue_button)
	visible = true
	await get_tree().process_frame
	_capture_label_layout()
	_reset_label_layout()
	await RevealMotion.play(self, finale, final_bird, [name_label, tagline_label, effect_label], continue_button)
	continue_button.disabled = false
	await continue_button.pressed
	continue_button.disabled = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fade.finished
	visible = false
	modulate = Color.WHITE


func _capture_photo_layout() -> void:
	if _photo_home_positions.size() == _photo_frames.size():
		return
	_photo_home_positions.clear()
	_photo_home_rotations.clear()
	for frame in _photo_frames:
		frame.pivot_offset = frame.size * 0.5
		_photo_home_positions.append(frame.position)
		_photo_home_rotations.append(frame.rotation)


func _play_photo_montage() -> void:
	for frame in _photo_frames:
		frame.visible = false
	for index in range(_photo_frames.size()):
		var frame := _photo_frames[index]
		var horizontal_entry := -260.0 if index % 2 == 0 else 260.0
		frame.position = _photo_home_positions[index] + Vector2(horizontal_entry, 90.0)
		frame.rotation = _photo_home_rotations[index] + deg_to_rad(-8.0 if index % 2 == 0 else 8.0)
		frame.scale = Vector2(0.62, 0.62)
		frame.modulate.a = 0.0
		frame.visible = true
		var enter := create_tween().set_parallel(true)
		enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		enter.tween_property(frame, "position", _photo_home_positions[index], 0.38)
		enter.tween_property(frame, "rotation", _photo_home_rotations[index], 0.34)
		enter.tween_property(frame, "scale", Vector2.ONE, 0.38)
		enter.tween_property(frame, "modulate:a", 1.0, 0.2)
		await get_tree().create_timer(0.18).timeout
	_start_photo_sway()
	await get_tree().create_timer(1.25).timeout
	_stop_photo_sway()
	for index in range(_photo_frames.size()):
		var frame := _photo_frames[index]
		var direction := Vector2(-1.0 if index % 2 == 0 else 1.0, -0.35 if index < 2 else 0.55)
		var scatter := create_tween().set_parallel(true)
		scatter.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		scatter.tween_property(frame, "position", frame.position + direction * 360.0, 0.32)
		scatter.tween_property(frame, "rotation", frame.rotation + deg_to_rad(13.0 * direction.x), 0.32)
		scatter.tween_property(frame, "scale", Vector2(0.8, 0.8), 0.32)
		scatter.tween_property(frame, "modulate:a", 0.0, 0.24)
		await get_tree().create_timer(0.045).timeout
	await get_tree().create_timer(0.34).timeout
	photo_stage.visible = false


func _start_photo_sway() -> void:
	_sway_tweens.clear()
	for index in range(_photo_frames.size()):
		var frame := _photo_frames[index]
		var sign_value := -1.0 if index % 2 == 0 else 1.0
		var sway := create_tween().set_loops()
		sway.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(frame, "rotation", _photo_home_rotations[index] + deg_to_rad(2.2 * sign_value), 0.7 + index * 0.08)
		sway.tween_property(frame, "rotation", _photo_home_rotations[index] - deg_to_rad(1.6 * sign_value), 0.7 + index * 0.08)
		_sway_tweens.append(sway)


func _stop_photo_sway() -> void:
	for sway in _sway_tweens:
		if sway != null and sway.is_valid():
			sway.kill()
	_sway_tweens.clear()


func _play_finale_reveal() -> void:
	finale.visible = true
	await get_tree().process_frame
	var bird_home := final_bird.position
	final_bird.position = bird_home + Vector2(-220.0, 520.0)
	final_bird.scale = Vector2(0.72, 0.72)
	final_bird.modulate.a = 0.0
	for label in [name_label, tagline_label, effect_label]:
		label.modulate.a = 0.0
		label.position += Vector2(220.0, 0.0)
	var name_home := name_label.position - Vector2(220.0, 0.0)
	var tagline_home := tagline_label.position - Vector2(220.0, 0.0)
	var effect_home := effect_label.position - Vector2(220.0, 0.0)
	var bird_enter := create_tween().set_parallel(true)
	bird_enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bird_enter.tween_property(final_bird, "position", bird_home, 0.5)
	bird_enter.tween_property(final_bird, "scale", Vector2.ONE, 0.5)
	bird_enter.tween_property(final_bird, "modulate:a", 1.0, 0.24)
	_animate_final_text(name_label, name_home, 0.08)
	_animate_final_text(tagline_label, tagline_home, 0.18)
	_animate_final_text(effect_label, effect_home, 0.28)
	await get_tree().create_timer(0.52).timeout
	continue_button.modulate.a = 0.0
	continue_button.visible = true
	var button_enter := create_tween()
	button_enter.tween_property(continue_button, "modulate:a", 1.0, 0.2)


func _animate_final_text(label: Label, target_position: Vector2, delay: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", target_position, 0.34).set_delay(delay)
	tween.tween_property(label, "modulate:a", 1.0, 0.2).set_delay(delay)
