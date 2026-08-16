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

@onready var _sprite: TextureRect = $Sprite
@onready var _hit_area: Button = $HitArea
@onready var _action_sfx: AudioStreamPlayer = $ActionSFX
@onready var _trigger_sfx: AudioStreamPlayer = get_node_or_null("TriggerSFX") as AudioStreamPlayer

var _idle_step := 0
var _elapsed := 0.0
var _finding := false
var _acting := false
var _last_find_result := false
var _action_play_count := 0
var _sprite_home_position := Vector2.ZERO
var _perch_home_position := Vector2.ZERO
var _last_exit_global_position := Vector2.ZERO
var _has_exit_position := false
var _queued_departure_active := false


func _ready() -> void:
	assert(not idle_frames.is_empty(), "BirdPerch requires at least one idle frame")
	_perch_home_position = position
	_sprite_home_position = _sprite.position
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
	action_finished.emit()


func play_action() -> void:
	assert(not action_frames.is_empty(), "play_action requires at least one action frame")
	if _finding or _acting:
		await action_finished
	_acting = true
	_action_play_count += 1
	_elapsed = 0.0
	_action_sfx.stop()
	_action_sfx.play()
	action_started.emit()
	for frame_index in range(action_frames.size()):
		_sprite.texture = action_frames[frame_index]
		if frame_index == launch_frame_index:
			action_launched.emit()
			if hide_sprite_on_launch:
				_sprite.visible = false
		var hold := action_last_hold if frame_index == action_frames.size() - 1 else action_frame_time
		await get_tree().create_timer(hold).timeout
	_acting = false
	_idle_step = 0
	_elapsed = 0.0
	if not stay_hidden_after_action:
		_sprite.texture = idle_frames[0]
		_sprite.visible = true
	action_finished.emit()


func reset_to_idle() -> void:
	_finding = false
	_acting = false
	_idle_step = 0
	_elapsed = 0.0
	position = _perch_home_position
	visible = true
	_sprite.position = _sprite_home_position
	_sprite.texture = idle_frames[0]
	_sprite.visible = true
	_has_exit_position = false
	_queued_departure_active = false


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
	var draw_scale := get_global_transform().get_scale()
	return _sprite.global_position + _sprite.size * draw_scale * 0.5


func fly_sprite_offscreen_right(duration: float = 0.34) -> void:
	var destination_x := get_viewport_rect().size.x + _sprite.size.x
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(_sprite, "global_position:x", destination_x, duration)
	await departure.finished
	_sprite.visible = false
	_sprite.position = _sprite_home_position


func fly_sprite_offscreen_bottom(duration: float = 0.34) -> void:
	var destination_y := get_viewport_rect().size.y + _sprite.size.y
	var departure := create_tween()
	departure.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_property(_sprite, "global_position:y", destination_y, duration)
	await departure.finished
	_sprite.visible = false
	_sprite.position = _sprite_home_position


func begin_travel_action(frame_index: int = 0, play_sfx: bool = true) -> void:
	assert(not action_frames.is_empty(), "begin_travel_action requires action frames")
	if _finding or _acting:
		await action_finished
	_acting = true
	_action_play_count += 1
	_elapsed = 0.0
	if play_sfx:
		play_action_sfx()
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


func move_travel_sprite_to_global_center(target_center: Vector2, duration: float) -> void:
	var draw_scale := _sprite.get_global_transform().get_scale()
	var target_position := target_center - _sprite.size * draw_scale * 0.5
	var travel := create_tween()
	travel.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(_sprite, "global_position", target_position, duration)
	await travel.finished


func finish_travel_action(duration: float = 0.34) -> void:
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
	if _finding or _acting:
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
	if not _has_exit_position:
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
