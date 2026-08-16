class_name AttackerUnlock
extends Control

## 页面里的彩蛋被触发，带上对应的成就 id。
signal easter_egg_triggered(achievement_id: String)

const ButtonMotion := preload("res://scripts/ui/button_motion.gd")
const RevealMotion := preload("res://scripts/ui/unlock_reveal_motion.gd")
const CELL_FX := preload("res://vfx/cell_fx.gd")
const Catalog := preload("res://scripts/game/achievement_catalog.gd")

## 逗到第几下，啄木鸟不干了。页面自带一句，之后每次 hover 再加一句，
## 所以爆发时屏幕上正好堆着这么多句「笃笃笃！」。
const RAGE_PECKS := 21
## 屏幕碎成几块楔形；块数太少不像玻璃，太多每片就看不清画面了。
const SHARD_WEDGES := 15
const HITSTOP_SECONDS := 0.085
const HITSTOP_TIME_SCALE := 0.05

@onready var dimmer: ColorRect = $Dimmer
@onready var icon_pattern: ColorRect = $IconPattern
@onready var photo_stage: Control = $PhotoStage
@onready var finale: Control = $Finale
@onready var bird: TextureRect = $Finale/Bird
@onready var name_label: Label = $Finale/Name
@onready var tagline_label: Label = $Finale/Tagline
@onready var effect_label: Label = $Finale/Effect
@onready var continue_button: Button = $Finale/Continue
@onready var bird_call: AudioStreamPlayer = $BirdCall
@onready var shatter_sfx: AudioStreamPlayer = $ShatterSFX

var _photo_frames: Array[Control] = []
var _photo_home_positions: Array[Vector2] = []
var _photo_home_rotations: Array[float] = []
var _sway_tweens: Array[Tween] = []
var _base_tagline := ""
var _tagline_punch_tween: Tween
var _peck_count := 0
var _raging := false
var _shard_layer: Node2D
## 破屏开始那一刻的立绘位姿；演出中途被收起时靠它兜底还原。
var _bird_home_pose := {}


func _ready() -> void:
	visible = false
	photo_stage.visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	_photo_frames.assign([
		$PhotoStage/Photo01,
		$PhotoStage/Photo02,
		$PhotoStage/Photo03,
		$PhotoStage/Photo04,
	])
	ButtonMotion.bind(continue_button, continue_button, -1.0)
	ButtonMotion.bind_hover(bird, bird, -1.6)
	continue_button.mouse_entered.connect(_play_bird_call)
	bird.mouse_entered.connect(_on_bird_hovered)
	_base_tagline = tagline_label.text


func _play_bird_call() -> void:
	bird_call.pitch_scale = 1.0
	bird_call.play()


func _on_bird_hovered() -> void:
	if _raging:
		return
	_peck_count += 1
	if _peck_count >= RAGE_PECKS:
		_play_screen_break()
		return
	# 每被撩一次叫得更急、字更多也更挤，为最后的爆发攒情绪。
	bird_call.pitch_scale = minf(1.0 + 0.03 * float(_peck_count), 1.6)
	bird_call.play()
	# 字号不动：标签本身开了自动换行，堆多了就顺着往下排。
	tagline_label.text += "笃笃笃！"
	tagline_label.pivot_offset = tagline_label.size * 0.5
	if _tagline_punch_tween != null and _tagline_punch_tween.is_valid():
		_tagline_punch_tween.kill()
	var punch := 1.1
	_tagline_punch_tween = create_tween()
	_tagline_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tagline_punch_tween.tween_property(tagline_label, "scale", Vector2(punch, punch), 0.1)
	_tagline_punch_tween.tween_property(tagline_label, "scale", Vector2.ONE, 0.18)


# ---------------------------------------------------------------------------
# 啄碎屏幕
# ---------------------------------------------------------------------------


## 撩过头了：鸟骤然放大、一嘴啄碎画面、从碎片里飞走，直接结束这一页。
func _play_screen_break() -> void:
	_raging = true
	easter_egg_triggered.emit(Catalog.WOODPECKER_SCREEN_BREAK)
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	continue_button.disabled = true
	if _tagline_punch_tween != null and _tagline_punch_tween.is_valid():
		_tagline_punch_tween.kill()

	var impact := size * 0.5
	# 先把"完好的画面"拍下来，之后碎片放的就是这张，切换时看不出接缝。
	# 拍的时候把鸟藏掉，否则碎片里会多一只鸟。
	var snapshot := await _capture_screen_without_bird()

	var bird_home := bird.position
	var bird_home_scale := bird.scale
	var bird_home_rotation := bird.rotation
	_bird_home_pose = {
		"position": bird_home, "scale": bird_home_scale, "rotation": bird_home_rotation
	}
	bird.pivot_offset = bird.size * 0.5

	# 1) 蓄力：向后一缩、压扁，声音也压低，给下一拍腾出落差。
	bird_call.pitch_scale = 0.62
	bird_call.play()
	var wind_up := create_tween().set_parallel(true)
	wind_up.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wind_up.tween_property(bird, "scale", bird_home_scale * Vector2(0.78, 1.16), 0.16)
	wind_up.tween_property(bird, "position", bird_home + Vector2(56.0, 34.0), 0.16)
	wind_up.tween_property(bird, "rotation", bird_home_rotation - 0.16, 0.16)
	_shake_labels()
	await wind_up.finished

	# 2) 暴涨扑面：EASE_IN，最后几帧才真正冲到脸上。
	var lunge := create_tween().set_parallel(true)
	lunge.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lunge.tween_property(bird, "scale", bird_home_scale * 3.6, 0.19)
	lunge.tween_property(bird, "position", impact - bird.size * 0.5, 0.19)
	lunge.tween_property(bird, "rotation", bird_home_rotation + 0.1, 0.19)
	await lunge.finished

	# 3) 命中
	await _play_impact(impact, snapshot)

	# 4) 从碎掉的画面里飞走
	await _fly_away(bird_home_scale)

	_restore_after_break(bird_home, bird_home_scale, bird_home_rotation)
	# 破屏就是这一页的结束：走按钮那条既有的收尾路径，不另开一套。
	continue_button.pressed.emit()


func _play_impact(impact: Vector2, snapshot: Texture2D) -> void:
	shatter_sfx.play()
	bird_call.pitch_scale = 0.5
	bird_call.play()
	CELL_FX.play_impact_hit(self, impact, Color(1.0, 0.86, 0.62))
	_flash_white()
	# 画面在这一帧被换成碎片，本体同时熄掉，两者一模一样所以看不出替换。
	_shard_layer = _build_shards(impact, snapshot)
	dimmer.visible = false
	icon_pattern.visible = false
	name_label.visible = false
	tagline_label.visible = false
	effect_label.visible = false
	continue_button.visible = false
	await _hit_stop()
	_shake_shards()


## 卡帧要用不受时间缩放影响的计时器，否则它会被自己拉长、永远等不到。
func _hit_stop() -> void:
	Engine.time_scale = HITSTOP_TIME_SCALE
	await get_tree().create_timer(HITSTOP_SECONDS, true, false, true).timeout
	Engine.time_scale = 1.0


func _fly_away(bird_home_scale: Vector2) -> void:
	var exit_position := bird.position + Vector2(size.x * 0.85, -size.y * 0.95)
	var away := create_tween().set_parallel(true)
	away.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_property(bird, "position", exit_position, 0.46)
	away.tween_property(bird, "scale", bird_home_scale * 0.9, 0.46)
	away.tween_property(bird, "rotation", -0.7, 0.46)
	away.tween_property(bird, "modulate:a", 0.0, 0.3).set_delay(0.16)
	await away.finished


func _capture_screen_without_bird() -> Texture2D:
	var viewport := get_viewport()
	# 无头运行不存在真正的绘制帧，等 frame_post_draw 会一直挂住整段演出。
	# 这种情况下跳过截图，碎片退化成暗色块，时序不变。
	if viewport == null or DisplayServer.get_name() == "headless":
		return null
	bird.visible = false
	await RenderingServer.frame_post_draw
	bird.visible = true
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## 从命中点切出楔形，再与屏幕矩形求交，得到贴合边框的碎片。
func _build_shards(impact: Vector2, snapshot: Texture2D) -> Node2D:
	var layer := Node2D.new()
	layer.name = "ScreenShards"
	add_child(layer)
	# 放在 Finale 下面一层，鸟才能压在碎片上面飞走。
	move_child(layer, finale.get_index())

	var screen := PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)
	])
	# UV 用的是截图的像素坐标，窗口尺寸和设计分辨率不一定一致，得换算。
	var uv_scale := Vector2.ONE
	if snapshot != null and size.x > 0.0 and size.y > 0.0:
		uv_scale = Vector2(snapshot.get_width(), snapshot.get_height()) / size

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var reach := size.length() * 1.3
	var angles: Array[float] = []
	for index in SHARD_WEDGES:
		angles.append(TAU * float(index) / float(SHARD_WEDGES) + rng.randf_range(-0.1, 0.1))
	var seams := PackedVector2Array()
	for index in SHARD_WEDGES:
		var from_angle := angles[index]
		var to_angle := angles[(index + 1) % SHARD_WEDGES]
		if to_angle <= from_angle:
			to_angle += TAU
		seams.append(impact + Vector2(cos(from_angle), sin(from_angle)) * reach)
		var wedge := PackedVector2Array([
			impact,
			impact + Vector2(cos(from_angle), sin(from_angle)) * reach,
			impact + Vector2(cos(to_angle), sin(to_angle)) * reach,
		])
		for piece in Geometry2D.intersect_polygons(wedge, screen):
			_add_shard(layer, piece, impact, snapshot, uv_scale, rng)

	var cracks := CrackLines.new()
	cracks.origin = impact
	cracks.endpoints = seams
	layer.add_child(cracks)
	var crack_fade := create_tween()
	crack_fade.tween_property(cracks, "modulate:a", 0.0, 0.3).set_delay(0.12)
	return layer


func _add_shard(
	layer: Node2D,
	piece: PackedVector2Array,
	impact: Vector2,
	snapshot: Texture2D,
	uv_scale: Vector2,
	rng: RandomNumberGenerator
) -> void:
	if piece.size() < 3:
		return
	var centroid := Vector2.ZERO
	for point in piece:
		centroid += point
	centroid /= float(piece.size())
	var local := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in piece:
		# 顶点放在质心坐标系里，碎片才会绕自己旋转；UV 仍用绝对屏幕坐标。
		local.append(point - centroid)
		uv.append(point * uv_scale)

	var shard := Polygon2D.new()
	shard.polygon = local
	shard.position = centroid
	if snapshot != null:
		shard.texture = snapshot
		shard.uv = uv
	else:
		# 截图拿不到时（无头运行）退化成暗色碎片，动作照旧。
		shard.color = Color(0.07, 0.06, 0.05, 0.95)
	layer.add_child(shard)

	var direction := (centroid - impact).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var hold := 0.1 + rng.randf_range(0.0, 0.05)
	var distance := rng.randf_range(220.0, 640.0)
	var fall := Vector2(0.0, rng.randf_range(180.0, 420.0))
	var fly := create_tween().set_parallel(true)
	fly.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(shard, "position", centroid + direction * distance + fall, 0.72).set_delay(hold)
	fly.tween_property(shard, "rotation", rng.randf_range(-1.3, 1.3), 0.72).set_delay(hold)
	fly.tween_property(shard, "modulate:a", 0.0, 0.34).set_delay(hold + 0.34)


func _flash_white() -> void:
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.97, 0.9)
	flash.modulate.a = 0.0
	flash.z_index = 60
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.8, 0.03)
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.finished.connect(flash.queue_free)


func _shake_labels() -> void:
	var labels: Array[Label] = [name_label, tagline_label, effect_label]
	for label in labels:
		var home := label.position
		var shake := create_tween()
		for offset in [Vector2(-9, 3), Vector2(8, -4), Vector2(-5, -2), Vector2(3, 2)]:
			shake.tween_property(label, "position", home + offset, 0.035)
		shake.tween_property(label, "position", home, 0.05)


func _shake_shards() -> void:
	if _shard_layer == null or not is_instance_valid(_shard_layer):
		return
	var shake := create_tween()
	for offset in [Vector2(0, 22), Vector2(-16, -12), Vector2(11, 9), Vector2(-6, -4)]:
		shake.tween_property(_shard_layer, "position", offset, 0.035)
	shake.tween_property(_shard_layer, "position", Vector2.ZERO, 0.05)


## 这一页在一次运行里可能被复用，破屏留下的状态必须全部还原。
func _restore_after_break(home: Vector2, home_scale: Vector2, home_rotation: float) -> void:
	Engine.time_scale = 1.0
	# 先把整页透明掉再复原各节点：屏幕已经碎光了，复原不能让完好的页面闪回一帧。
	modulate.a = 0.0
	if _shard_layer != null and is_instance_valid(_shard_layer):
		_shard_layer.queue_free()
	_shard_layer = null
	dimmer.visible = true
	icon_pattern.visible = true
	name_label.visible = true
	tagline_label.visible = true
	effect_label.visible = true
	continue_button.visible = true
	bird.position = home
	bird.scale = home_scale
	bird.rotation = home_rotation
	bird.modulate.a = 1.0
	bird.mouse_filter = Control.MOUSE_FILTER_STOP
	_peck_count = 0
	_raging = false
	_bird_home_pose = {}


func present() -> void:
	# 破屏演出中途被收起时，那一步还原跑不到，这里兜底把页面搬回原样。
	if not _bird_home_pose.is_empty():
		_restore_after_break(
			_bird_home_pose["position"],
			_bird_home_pose["scale"],
			_bird_home_pose["rotation"]
		)
		modulate = Color.WHITE
	tagline_label.text = _base_tagline
	tagline_label.scale = Vector2.ONE
	_peck_count = 0
	_raging = false
	photo_stage.visible = false
	RevealMotion.prepare(finale, bird, [name_label, tagline_label, effect_label], continue_button)
	visible = true
	await RevealMotion.play(self, finale, bird, [name_label, tagline_label, effect_label], continue_button)
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
	var bird_home := bird.position
	bird.position = bird_home + Vector2(-220.0, 520.0)
	bird.scale = Vector2(0.72, 0.72)
	bird.modulate.a = 0.0
	var labels: Array[Label] = [name_label, tagline_label, effect_label]
	var label_homes: Array[Vector2] = []
	for label in labels:
		label_homes.append(label.position)
		label.position += Vector2(220.0, 0.0)
		label.modulate.a = 0.0
	var bird_enter := create_tween().set_parallel(true)
	bird_enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bird_enter.tween_property(bird, "position", bird_home, 0.5)
	bird_enter.tween_property(bird, "scale", Vector2.ONE, 0.5)
	bird_enter.tween_property(bird, "modulate:a", 1.0, 0.24)
	for index in range(labels.size()):
		_animate_text(labels[index], label_homes[index], 0.08 + index * 0.1)
	await get_tree().create_timer(0.52).timeout
	continue_button.modulate.a = 0.0
	continue_button.visible = true
	var button_enter := create_tween()
	button_enter.tween_property(continue_button, "modulate:a", 1.0, 0.2)


func _animate_text(label: Label, target_position: Vector2, delay: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", target_position, 0.34).set_delay(delay)
	tween.tween_property(label, "modulate:a", 1.0, 0.2).set_delay(delay)


## 命中瞬间沿着碎片缝隙亮起的裂纹，只闪一下就淡掉。
class CrackLines extends Node2D:
	var origin := Vector2.ZERO
	var endpoints := PackedVector2Array()


	func _draw() -> void:
		for point in endpoints:
			draw_line(origin, point, Color(1.0, 0.95, 0.85, 0.9), 3.0, true)
