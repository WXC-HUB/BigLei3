class_name NightHeronUnlock
extends Control

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const CELL_FX := preload("res://vfx/cell_fx.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")

## 撩到第几下夜鹭翻脸。页面本身不带鱼，所以这就是实打实被摸的次数。
const RAGE_HOVERS := 21
## 翻脸后的主文案。字比原来的两个字多一倍，得配一个能塞下的字号。
const RAGE_NAME_TEXT := "夜 鹭 死 苦"
const RAGE_NAME_FONT_SIZE := 290
const RAGE_NAME_TILT := -0.13
const RAGE_NAME_COLOR := Color(0.94, 0.11, 0.12)
const RAGE_NAME_OUTLINE := Color(0.16, 0.02, 0.02)
const HITSTOP_SECONDS := 0.08
const HITSTOP_TIME_SCALE := 0.05
const FISH_TEXTURES: Array[Texture2D] = [
	preload("res://my_asset/effects/fish/fish_silver.png"),
	preload("res://my_asset/effects/fish/fish_orange.png"),
	preload("res://my_asset/effects/fish/fish_teal.png"),
]

@onready var photo_stage: Control = $PhotoStage
@onready var finale: Control = $Finale
@onready var final_bird: TextureRect = $Finale/Bird
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var heron_call: AudioStreamPlayer = $HeronCall
@onready var impact_sfx: AudioStreamPlayer = $ImpactSFX
@onready var fish_rain: Control = $FishRain

var _photo_frames: Array[Control] = []
var _photo_home_positions: Array[Vector2] = []
var _photo_home_rotations: Array[float] = []
var _sway_tweens: Array[Tween] = []
var _hover_count := 0
var _raging := false
var _anger_mark: AngerMark
## 翻脸开始那一刻的立绘位姿。RevealMotion 是拿"当前位置"当归位点的，
## 不还原的话下次进这一页，鸟就把角落当成家了。
var _bird_home_pose := {}
var _name_home_text := ""
var _name_home_font_size := 0
var _name_home_color := Color.WHITE
var _name_home_outline := Color.BLACK


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
	ButtonMotion.bind(continue_button, continue_button, -1.0)
	ButtonMotion.bind_hover(final_bird, final_bird, -1.6)
	continue_button.mouse_entered.connect(_play_heron_call)
	final_bird.mouse_entered.connect(_on_bird_hovered)
	_name_home_text = name_label.text
	_name_home_font_size = name_label.get_theme_font_size("font_size")
	_name_home_color = name_label.get_theme_color("font_color")
	_name_home_outline = name_label.get_theme_color("font_outline_color")


func _play_heron_call() -> void:
	heron_call.play()


func _on_bird_hovered() -> void:
	if _raging:
		return
	_hover_count += 1
	if _hover_count >= RAGE_HOVERS:
		_play_rage()
		return
	_play_heron_call()
	_drop_random_fish()


# ---------------------------------------------------------------------------
# 翻脸
# ---------------------------------------------------------------------------


## 摸太多次了：夜鹭一跃跳到右下角、半个身子出画，头顶爆青筋，
## 主文案砸成倾斜的红色「夜 鹭 死 苦」。
func _play_rage() -> void:
	_raging = true
	easter_egg_triggered.emit(Catalog.HERON_YOROSHIKU)
	final_bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bird_home := final_bird.position
	var bird_home_scale := final_bird.scale
	var bird_home_rotation := final_bird.rotation
	_bird_home_pose = {
		"position": bird_home, "scale": bird_home_scale, "rotation": bird_home_rotation
	}
	final_bird.pivot_offset = final_bird.size * 0.5

	# 落点：右下角外侧，只留左上小半个身子在画面里。
	var landing := Vector2(
		size.x - final_bird.size.x * 0.7,
		size.y - final_bird.size.y * 0.62
	)

	# 1) 蹲身蓄力：压扁、低鸣，起跳前的那一顿。
	heron_call.pitch_scale = 0.68
	heron_call.play()
	var crouch := create_tween().set_parallel(true)
	crouch.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	crouch.tween_property(final_bird, "scale", bird_home_scale * Vector2(1.16, 0.8), 0.15)
	crouch.tween_property(final_bird, "position", bird_home + Vector2(-26.0, 52.0), 0.15)
	await crouch.finished

	# 2) 起跳：抛物线过去，途中拉长，落地前再压扁。
	await _leap_to(bird_home, landing, bird_home_scale, bird_home_rotation)

	# 3) 落地：卡帧 + 冲击 + 整块画面震一下
	await _play_landing_impact(landing)

	# 4) 头顶青筋
	_pop_anger_mark(landing)

	# 5) 隔一拍再砸文案，两记重音而不是一记
	await get_tree().create_timer(0.12).timeout
	await _slam_rage_name()


func _leap_to(
	from_position: Vector2,
	landing: Vector2,
	bird_home_scale: Vector2,
	bird_home_rotation: float
) -> void:
	var apex := (from_position + landing) * 0.5 + Vector2(60.0, -size.y * 0.42)
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_LINEAR)
	flight.tween_method(
		func(progress: float) -> void:
			if not is_instance_valid(final_bird):
				return
			var inverse := 1.0 - progress
			final_bird.position = (
				from_position * inverse * inverse
				+ apex * 2.0 * inverse * progress
				+ landing * progress * progress
			)
			# 升空拉长、落地压扁，squash & stretch 全靠这条曲线。
			var stretch := sin(progress * PI)
			final_bird.scale = bird_home_scale * Vector2(
				1.0 - 0.16 * stretch, 1.0 + 0.2 * stretch
			),
		0.0,
		1.0,
		0.34
	)
	flight.tween_property(final_bird, "rotation", bird_home_rotation + 0.22, 0.34)
	await flight.finished
	var land_squash := create_tween()
	land_squash.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	land_squash.tween_property(final_bird, "scale", bird_home_scale * Vector2(1.24, 0.76), 0.06)
	land_squash.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land_squash.tween_property(final_bird, "scale", bird_home_scale, 0.24)


func _play_landing_impact(landing: Vector2) -> void:
	impact_sfx.pitch_scale = 0.9
	impact_sfx.play()
	heron_call.pitch_scale = 0.55
	heron_call.play()
	var contact := landing + Vector2(final_bird.size.x * 0.3, final_bird.size.y * 0.3)
	CELL_FX.play_impact_hit(self, contact, Color(1.0, 0.72, 0.4))
	_shake_finale(1.0)
	await _hit_stop()


## 卡帧要用不受时间缩放影响的计时器，否则它会被自己拉长、永远等不到。
func _hit_stop() -> void:
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(HITSTOP_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0


func _pop_anger_mark(landing: Vector2) -> void:
	if _anger_mark != null and is_instance_valid(_anger_mark):
		_anger_mark.queue_free()
	_anger_mark = AngerMark.new()
	_anger_mark.name = "AngerMark"
	# 贴在露在画面里的那半个身子的头顶上：鸟是右下角出画，露出来的是脑袋，
	# 所以锚点要按贴图里头部的位置算，不能拿整块矩形的左上角。
	_anger_mark.position = landing + Vector2(
		final_bird.size.x * 0.52, final_bird.size.y * 0.3 - 110.0
	)
	_anger_mark.scale = Vector2.ZERO
	finale.add_child(_anger_mark)
	# 补间挂在符号自己身上：符号被清掉时补间跟着消失。挂在页面上的话，
	# 循环补间会在目标失效后变成零长度循环，引擎会报无限循环。
	var pop := _anger_mark.create_tween()
	pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_anger_mark, "scale", Vector2(1.22, 1.22), 0.14)
	pop.set_trans(Tween.TRANS_QUAD)
	pop.tween_property(_anger_mark, "scale", Vector2.ONE, 0.1)
	# 落定后持续突突跳，青筋不会安静下来。
	var throb := _anger_mark.create_tween().set_loops()
	throb.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	throb.tween_property(_anger_mark, "scale", Vector2(1.12, 1.12), 0.32).set_delay(0.24)
	throb.tween_property(_anger_mark, "scale", Vector2.ONE, 0.32)


func _slam_rage_name() -> void:
	impact_sfx.pitch_scale = 0.72
	impact_sfx.play()
	name_label.text = RAGE_NAME_TEXT
	name_label.add_theme_font_size_override("font_size", RAGE_NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", RAGE_NAME_COLOR)
	name_label.add_theme_color_override("font_outline_color", RAGE_NAME_OUTLINE)
	name_label.pivot_offset = name_label.size * 0.5
	name_label.scale = Vector2(1.7, 1.7)
	name_label.rotation = RAGE_NAME_TILT * 2.4
	CELL_FX.play_impact_hit(
		self,
		name_label.position + name_label.size * 0.5,
		Color(1.0, 0.3, 0.28)
	)
	# 慢起快落收到最终姿态：EASE_IN 让它在最后几帧砸实。
	var slam := create_tween().set_parallel(true)
	slam.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	slam.tween_property(name_label, "scale", Vector2.ONE, 0.16)
	slam.tween_property(name_label, "rotation", RAGE_NAME_TILT, 0.16)
	await slam.finished
	_shake_finale(1.25)
	await _hit_stop()


func _shake_finale(power: float) -> void:
	# 只晃 Finale：底板是全屏色块，跟着晃会从边缘漏出后面的画面。
	var home := finale.position
	var shake := create_tween()
	for offset in [Vector2(0, 20), Vector2(-15, -12), Vector2(11, 8), Vector2(-6, -4)]:
		shake.tween_property(finale, "position", home + offset * power, 0.035)
	shake.tween_property(finale, "position", home, 0.05)


## 这一页在一次运行里可能被再次 present，翻脸留下的状态必须全部还原。
func _reset_rage() -> void:
	Engine.time_scale = 1.0
	_hover_count = 0
	_raging = false
	if _anger_mark != null and is_instance_valid(_anger_mark):
		_anger_mark.queue_free()
	_anger_mark = null
	name_label.text = _name_home_text
	name_label.add_theme_font_size_override("font_size", _name_home_font_size)
	name_label.add_theme_color_override("font_color", _name_home_color)
	name_label.add_theme_color_override("font_outline_color", _name_home_outline)
	name_label.rotation = 0.0
	name_label.scale = Vector2.ONE
	if not _bird_home_pose.is_empty():
		final_bird.position = _bird_home_pose["position"]
		final_bird.scale = _bird_home_pose["scale"]
		final_bird.rotation = _bird_home_pose["rotation"]
		_bird_home_pose = {}
	final_bird.mouse_filter = Control.MOUSE_FILTER_STOP


func _drop_random_fish() -> void:
	var fish := TextureRect.new()
	fish.texture = FISH_TEXTURES.pick_random()
	fish.size = Vector2(112.0, 112.0)
	fish.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish.pivot_offset = Vector2(56.0, 56.0)
	var rain_width := maxf(fish_rain.size.x, 320.0)
	fish.position = Vector2(randf_range(72.0, rain_width - 144.0), -140.0)
	fish.rotation = randf_range(-0.35, 0.35)
	fish_rain.add_child(fish)
	var target := Vector2(
		fish.position.x + randf_range(-130.0, 130.0),
		maxf(fish_rain.size.y, 1080.0) + 150.0
	)
	var fall := create_tween().set_parallel(true)
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(fish, "position", target, randf_range(1.5, 2.1))
	fall.tween_property(fish, "rotation", fish.rotation + randf_range(-2.5, 2.5), randf_range(1.5, 2.1))
	await fall.finished
	if is_instance_valid(fish):
		fish.queue_free()


func present() -> void:
	_reset_rage()
	photo_stage.visible = false
	RevealMotion.prepare(finale, final_bird, [name_label, tagline_label, effect_label], continue_button)
	visible = true
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


## 头顶的青筋：四个直角，折角朝内、两条边向外撇，中间留出十字形的空。
## 折角朝外就成了取景框的四个角标，不是怒气符号。
class AngerMark extends Node2D:
	const ARM := 62.0
	## 折角到中心的距离占臂长的比例。四个折角之间要留得够开，
	## 中间的十字形空隙才不会被描边糊死。
	const BEND := 0.42
	var color := Color(0.95, 0.13, 0.14)
	var outline := Color(0.14, 0.02, 0.02)


	func _draw() -> void:
		# 先描一圈深色边，青筋压在深色鸟身上才立得住。
		_stroke(outline, 15.0)
		_stroke(color, 9.0)


	func _stroke(stroke_color: Color, width: float) -> void:
		var corners: Array[Vector2] = [
			Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)
		]
		for corner in corners:
			var bend := corner * (ARM * BEND)
			draw_polyline(
				PackedVector2Array([
					Vector2(corner.x * ARM, bend.y),
					bend,
					Vector2(bend.x, corner.y * ARM),
				]),
				stroke_color,
				width,
				true
			)
