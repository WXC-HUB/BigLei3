class_name BirdPerch
extends Control

signal action_started
signal action_launched
signal action_finished

@export_group("Animation Assets")
@export var idle_frames: Array[Texture2D] = []
@export var find_frames: Array[Texture2D] = []
@export var find_yes_texture: Texture2D
@export var find_no_texture: Texture2D
@export var action_frames: Array[Texture2D] = []

@export_group("Timing")
@export var idle_sequence := PackedInt32Array([0, 1, 2, 3, 2, 1])
@export_range(0.05, 2.0, 0.01) var idle_frame_time := 0.22
@export_range(0.05, 2.0, 0.01) var find_frame_time := 0.2
@export_range(0.05, 2.0, 0.01) var find_result_hold := 0.48
@export_range(0.05, 2.0, 0.01) var action_frame_time := 0.18
@export_range(0.05, 2.0, 0.01) var action_last_hold := 0.28
@export var launch_frame_index := -1
@export var hide_sprite_on_launch := false
@export var stay_hidden_after_action := false
@export var click_preview_result := true
@export var click_enabled := true
## 这套帧本身朝向哪边。乌鸦的素材朝左，其余鸟朝右；set_travel_facing_right 按它翻面。
@export var art_faces_right := true
## 飞到棋盘上干活时缩到栖位尺寸的几成。栖位上的鸟有三格那么宽，照原样飞上棋盘会把
## 它正在作用的格子整个盖住，所以下棋盘的鸟都缩到一格左右。1.0 就是不缩。
@export_range(0.1, 1.0, 0.01) var board_travel_scale := 1.0

@onready var _sprite: TextureRect = $Sprite
@onready var _tree: TextureRect = get_node_or_null("Tree") as TextureRect
@onready var _hit_area: Button = $HitArea
@onready var _action_sfx: AudioStreamPlayer = $ActionSFX
@onready var _trigger_sfx: AudioStreamPlayer = get_node_or_null("TriggerSFX") as AudioStreamPlayer

## 对战分屏时收起树干和待机鸟，避免压住半屏。根节点保持可见，棋盘上的飞入特效才能定位。
var _stowed := false
var _idle_step := 0
var _elapsed := 0.0
var _finding := false
var _acting := false
var _last_find_result := false
var _action_play_count := 0
var _sprite_home_position := Vector2.ZERO
var _sprite_home_flip := false
var _perch_home_position := Vector2.ZERO
var _last_exit_global_position := Vector2.ZERO
var _has_exit_position := false
var _queued_departure_active := false


func _ready() -> void:
	assert(not idle_frames.is_empty(), "BirdPerch requires at least one idle frame")
	_perch_home_position = position
	_sprite_home_position = _sprite.position
	_sprite_home_flip = _sprite.flip_h
	_sprite.texture = idle_frames[0]
	_hit_area.disabled = not click_enabled
	_hit_area.pressed.connect(_play_preview_action)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _finding and not _acting:
		_update_idle()


func play_find(found_mine: bool) -> void:
	assert(find_frames.size() >= 2, "play_find requires two find frames")
	assert(find_yes_texture != null and find_no_texture != null, "play_find requires yes/no result frames")
	# Multiple non-blocking requests can wake on the same completion signal.
	# Re-check the state so their animations remain serialized.
	while _finding or _acting:
		await action_finished
	_finding = true
	_last_find_result = found_mine
	_elapsed = 0.0
	_action_sfx.stop()
	_action_sfx.play()
	_sprite.visible = not _stowed
	_sprite.texture = find_frames[0]
	action_started.emit()
	await get_tree().create_timer(find_frame_time).timeout
	_sprite.texture = find_frames[1]
	await get_tree().create_timer(find_frame_time).timeout
	_sprite.texture = find_yes_texture if found_mine else find_no_texture
	await get_tree().create_timer(find_result_hold).timeout
	_finding = false
	_idle_step = 0
	_elapsed = 0.0
	_sprite.texture = idle_frames[0]
	_sprite.visible = not _stowed
	action_finished.emit()


func play_action() -> void:
	assert(not action_frames.is_empty(), "play_action requires at least one action frame")
	# `action_finished` 是广播信号：一次 emit 会把所有排队的协程同时叫醒，所以醒来
	# 必须重新看一眼闸，用 if 的话第二、第三个会一起冲进来驱动同一个精灵。
	while _finding or _acting:
		await action_finished
	_acting = true
	_action_play_count += 1
	_elapsed = 0.0
	_action_sfx.stop()
	_action_sfx.play()
	_sprite.visible = not _stowed
	action_started.emit()
	for frame_index in range(action_frames.size()):
		_sprite.texture = action_frames[frame_index]
		if frame_index == launch_frame_index:
			action_launched.emit()
			if hide_sprite_on_launch or _stowed:
				_sprite.visible = false
		var hold := action_last_hold if frame_index == action_frames.size() - 1 else action_frame_time
		await get_tree().create_timer(hold).timeout
	_acting = false
	_idle_step = 0
	_elapsed = 0.0
	if not stay_hidden_after_action:
		_sprite.texture = idle_frames[0]
		_sprite.visible = not _stowed
	action_finished.emit()


func set_stowed(stowed: bool) -> void:
	_stowed = stowed
	_apply_stow_visuals()


func is_stowed() -> bool:
	return _stowed


func _apply_stow_visuals() -> void:
	if _tree != null:
		_tree.visible = not _stowed
	if _hit_area != null:
		_hit_area.visible = not _stowed
		_hit_area.disabled = _stowed or not click_enabled
	if _stowed and not _acting and not _finding:
		_sprite.visible = false
	elif not _stowed:
		_sprite.visible = true


func reset_to_idle() -> void:
	# 闸是被这一手强行清掉的，必须补一次 `action_finished`：同一只鸟的下一张牌正
	# `await` 在这个信号上，漏发一次它就永远醒不过来——那张牌的结算协程不返回，
	# `_active_item_settlements` 减不回 0，整局就停在「正在结算……」再也点不动。
	var was_busy := _finding or _acting
	_finding = false
	_acting = false
	_idle_step = 0
	_elapsed = 0.0
	position = _perch_home_position
	_sprite.position = _sprite_home_position
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_sprite.flip_h = _sprite_home_flip
	_sprite.modulate.a = 1.0
	_sprite.texture = idle_frames[0]
	_has_exit_position = false
	_queued_departure_active = false
	if _stowed:
		visible = true
		_apply_stow_visuals()
		if was_busy:
			action_finished.emit()
		return
	visible = true
	_sprite.visible = true
	if was_busy:
		action_finished.emit()


func depart_for_queued_action(exit_direction := Vector2.RIGHT, duration: float = 0.24) -> void:
	# Queue feedback must be immediate and must not hold up the settlement
	# dispatcher.  Only the bird sprite leaves; its branch stays in place.
	if _queued_departure_active or not _sprite.visible:
		return
	_queued_departure_active = true
	_acting = true
	_action_play_count += 1
	_elapsed = 0.0
	if not action_frames.is_empty():
		var departure_frame := launch_frame_index if launch_frame_index >= 0 else 0
		_sprite.texture = action_frames[clampi(departure_frame, 0, action_frames.size() - 1)]
	play_action_sfx()
	action_started.emit()
	action_launched.emit()
	var viewport_size := get_viewport_rect().size
	var destination := _sprite.global_position
	if absf(exit_direction.x) >= absf(exit_direction.y):
		destination.x = viewport_size.x + _sprite.size.x if exit_direction.x >= 0.0 else -_sprite.size.x * 2.0
	else:
		destination.y = viewport_size.y + _sprite.size.y if exit_direction.y >= 0.0 else -_sprite.size.y * 2.0
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(_sprite, "global_position", destination, duration)
	await departure.finished
	_sprite.visible = false
	_sprite.position = _sprite_home_position
	_acting = false
	action_finished.emit()


func get_launch_global_position() -> Vector2:
	return _sprite.global_position + _sprite_draw_half()


## 从精灵左上角到它画出来的中心有多远。缩放绕中心走，所以这里只算栖位这一层的缩放。
func _sprite_draw_half() -> Vector2:
	return _sprite.size * get_global_transform().get_scale() * 0.5


func fly_sprite_offscreen_right(duration: float = 0.34) -> void:
	if _stowed:
		_sprite.visible = false
		_sprite.position = _sprite_home_position
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
		return
	var destination_x := get_viewport_rect().size.x + _sprite.size.x
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(_sprite, "global_position:x", destination_x, duration)
	await departure.finished
	_sprite.visible = false
	_sprite.position = _sprite_home_position


func fly_sprite_offscreen_bottom(duration: float = 0.34) -> void:
	if _stowed:
		_sprite.visible = false
		_sprite.position = _sprite_home_position
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
		return
	var destination_y := get_viewport_rect().size.y + _sprite.size.y
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(_sprite, "global_position:y", destination_y, duration)
	await departure.finished
	_sprite.visible = false
	_sprite.position = _sprite_home_position


## 从当前位置直接掉出屏幕底：先小小弹起，再带着翻滚加速坠落。掉出去后隐藏并归位，
## 但不结束动作——调用方决定何时用 reappear_on_perch() 让鸟回到枝头。
func tumble_sprite_offscreen_bottom(duration: float = 0.5, hop_frame: int = -1, fall_frame: int = -1) -> void:
	if _stowed:
		_sprite.visible = false
		_sprite.position = _sprite_home_position
		return
	_sprite.pivot_offset = _sprite.size * 0.5
	if hop_frame >= 0:
		set_travel_frame(hop_frame)
	var start_y := _sprite.global_position.y
	var hop := create_tween()
	hop.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(_sprite, "global_position:y", start_y - 44.0, duration * 0.3)
	await hop.finished
	if fall_frame >= 0:
		set_travel_frame(fall_frame)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(_sprite, "global_position:y", get_viewport_rect().size.y + _sprite.size.y, duration * 0.7) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_sprite, "rotation", 0.6, duration * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fall.finished
	_sprite.visible = false
	_sprite.rotation = 0.0
	_sprite.position = _sprite_home_position


## 掉出屏幕的鸟悄悄回到枝头：原位淡入待机帧，并结束这次动作。
func reappear_on_perch(fade: float = 0.25) -> void:
	_sprite.position = _sprite_home_position
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	_sprite.flip_h = _sprite_home_flip
	_sprite.texture = idle_frames[0]
	_idle_step = 0
	_elapsed = 0.0
	if _stowed:
		_sprite.visible = false
	else:
		_sprite.modulate.a = 0.0
		_sprite.visible = true
		var fade_in := create_tween()
		fade_in.tween_property(_sprite, "modulate:a", 1.0, fade)
		await fade_in.finished
		_sprite.modulate.a = 1.0
	_acting = false
	action_finished.emit()


## 半路收手：飞行演出被打断（重开、换关、换盘）时收掉精灵并放开闸。
## `begin_travel_action()` 只有走到 `finish_travel_action()` / `reappear_on_perch()`
## 才会解闸，中途 return 的那几条路必须改走这里，否则这只鸟的闸永远关着。
func abort_travel_action() -> void:
	reset_to_idle()


## 走路时面朝哪边：和素材本身的朝向一比，不一致就水平翻转。归位时恢复场景里原本的朝向。
func set_travel_facing_right(face_right: bool) -> void:
	_sprite.flip_h = face_right != art_faces_right


## 一边飞一边扇翅膀：`cycle` 是 action_frames 里参与轮播的下标，帧号按**真实走过的时间**
## 算，所以这条 tween 必须是线性的——一挂缓动，翅膀就会在起飞和落地两头卡住不动。
## `lift` 让航线中段微微拱起来，比一条直线像飞。
func flap_travel_sprite_to_global_center(
	target_center: Vector2, duration: float, cycle: Array[int], flap_time: float, lift: float = 0.0
) -> void:
	assert(not cycle.is_empty(), "flap_travel_sprite_to_global_center needs at least one frame")
	var half := _sprite_draw_half()
	var start := _sprite.global_position + half
	var flight := create_tween()
	flight.tween_method(func(progress: float) -> void:
		var point := start.lerp(target_center, progress) + Vector2(0.0, -lift * sin(progress * PI))
		_sprite.global_position = point - half
		set_travel_frame(cycle[int(progress * duration / flap_time) % cycle.size()])
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)
	await flight.finished


## 一小跳跳到某个全局中心点：中途抬起 hop_height 像素再落下，给一格一格走用。
func hop_travel_sprite_to_global_center(target_center: Vector2, duration: float, hop_height: float = 16.0) -> void:
	var half := _sprite_draw_half()
	var start := _sprite.global_position + half
	var hop := create_tween()
	hop.tween_method(func(progress: float) -> void:
		var point := start.lerp(target_center, progress) + Vector2(0.0, -hop_height * sin(progress * PI))
		_sprite.global_position = point - half
	, 0.0, 1.0, duration)
	await hop.finished


## 就地淡出并藏起来，不结束动作——之后由 reappear_on_perch() 收尾。
func fade_out_travel_sprite(duration: float = 0.25) -> void:
	var fade := create_tween()
	fade.tween_property(_sprite, "modulate:a", 0.0, duration)
	await fade.finished
	_sprite.visible = false
	_sprite.modulate.a = 1.0
	_sprite.scale = Vector2.ONE
	_sprite.position = _sprite_home_position


func begin_travel_action(frame_index: int = 0, play_sfx: bool = true) -> void:
	assert(not action_frames.is_empty(), "begin_travel_action requires action frames")
	while _finding or _acting:
		await action_finished
	_acting = true
	_action_play_count += 1
	_elapsed = 0.0
	if play_sfx:
		play_action_sfx()
	if _stowed:
		# 栖枝已收起：从屏幕外飞入棋盘，不要在外围树位冒出来。
		var viewport_size := get_viewport_rect().size
		_sprite.global_position = Vector2(-_sprite.size.x * 1.5, viewport_size.y * 0.22)
	_sprite.pivot_offset = _sprite.size * 0.5
	_sprite.scale = Vector2.ONE * board_travel_scale
	_sprite.visible = true
	set_travel_frame(frame_index)
	action_started.emit()


func play_action_sfx() -> void:
	_action_sfx.stop()
	_action_sfx.play()


func play_trigger_sfx() -> void:
	if _trigger_sfx == null or _trigger_sfx.stream == null:
		return
	_trigger_sfx.stop()
	_trigger_sfx.play()


func set_travel_frame(frame_index: int) -> void:
	assert(frame_index >= 0 and frame_index < action_frames.size(), "Travel frame index is out of range")
	_sprite.texture = action_frames[frame_index]


## 直接把飞行中的鸟摆到某个全局中心点，给 tween_method 逐帧驱动用。
func set_travel_sprite_global_center(target_center: Vector2) -> void:
	_sprite.global_position = target_center - _sprite_draw_half()


func move_travel_sprite_to_global_center(target_center: Vector2, duration: float) -> void:
	var target_position := target_center - _sprite_draw_half()
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(_sprite, "global_position", target_position, duration)
	await travel.finished


func finish_travel_action(duration: float = 0.34) -> void:
	if _stowed:
		_sprite.visible = false
		_sprite.position = _sprite_home_position
		if duration > 0.0:
			await get_tree().create_timer(duration).timeout
		_acting = false
		_idle_step = 0
		_elapsed = 0.0
		_sprite.texture = idle_frames[0]
		action_finished.emit()
		return
	var return_trip := create_tween()
	return_trip.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return_trip.tween_property(_sprite, "position", _sprite_home_position, duration)
	await return_trip.finished
	_acting = false
	_idle_step = 0
	_elapsed = 0.0
	_sprite.texture = idle_frames[0]
	_sprite.visible = true
	action_finished.emit()


func slide_sprite_offscreen_nearest(duration: float = 0.36) -> void:
	if _stowed:
		_apply_stow_visuals()
		return
	while _finding or _acting:
		await action_finished
	var viewport_size := get_viewport_rect().size
	var draw_scale := get_global_transform().get_scale()
	var draw_size := size * draw_scale
	var start_position := global_position
	var center := start_position + draw_size * 0.5
	var distances := [center.x, viewport_size.x - center.x, center.y, viewport_size.y - center.y]
	var nearest_edge := 0
	for edge_index in range(1, distances.size()):
		if distances[edge_index] < distances[nearest_edge]:
			nearest_edge = edge_index
	var destination := start_position
	match nearest_edge:
		0:
			destination.x = -draw_size.x - 24.0
		1:
			destination.x = viewport_size.x + 24.0
		2:
			destination.y = -draw_size.y - 24.0
		3:
			destination.y = viewport_size.y + 24.0
	_last_exit_global_position = destination
	_has_exit_position = true
	var exit_tween := create_tween()
	exit_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(self, "global_position", destination, duration)
	await exit_tween.finished
	visible = false
	position = _perch_home_position


func return_sprite_from_last_exit(duration: float = 0.36) -> void:
	if _stowed or not _has_exit_position:
		reset_to_idle()
		return
	position = _perch_home_position
	var home_global_position := global_position
	global_position = _last_exit_global_position
	_sprite.texture = idle_frames[0]
	_sprite.visible = true
	visible = true
	var return_tween := create_tween()
	return_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(self, "global_position", home_global_position, duration)
	await return_tween.finished
	position = _perch_home_position
	_sprite.position = _sprite_home_position
	_sprite.texture = idle_frames[0]
	_has_exit_position = false


func _play_preview_action() -> void:
	if not find_frames.is_empty():
		play_find(click_preview_result)
	elif not action_frames.is_empty():
		play_action()


func _update_idle() -> void:
	if _elapsed < idle_frame_time:
		return
	_elapsed = fmod(_elapsed, idle_frame_time)
	_idle_step = (_idle_step + 1) % idle_sequence.size()
	var frame_index := idle_sequence[_idle_step]
	_sprite.texture = idle_frames[frame_index % idle_frames.size()]
