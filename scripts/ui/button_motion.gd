class_name UIButtonMotion
extends RefCounted

const HOVER_SCALE := 1.045
const PRESS_SCALE := 0.975
const HOVER_DURATION := 0.14
const RESET_DURATION := 0.16
const HOVER_FLIP_SFX := preload("res://assets/audio/card_reveal_crack.wav")
const HOVER_SFX_PLAYER_NAME := &"HoverFlipSFX"
const HOVER_SFX_VOLUME_DB := -9.0


static func bind(button: BaseButton, target: Node = null, hover_rotation_degrees: float = -1.6) -> void:
	var visual := target if target != null else button
	# Scene duplication also copies metadata. Compare the current button's
	# instance id so cloned shop offers still receive their own signal bindings.
	if button.get_meta(&"ui_button_motion_owner", 0) == button.get_instance_id():
		return
	button.set_meta(&"ui_button_motion_owner", button.get_instance_id())
	visual.set_meta(&"ui_button_base_scale", visual.get("scale"))
	visual.set_meta(&"ui_button_base_rotation", visual.get("rotation"))
	_ensure_hover_sfx_player(button)

	if visual is Control:
		var control := visual as Control
		_center_control_pivot(control)
		# Containers finish assigning button sizes at the end of the frame.
		# Refresh once afterwards so rotation stays centered on generated buttons.
		if control.get_tree() != null:
			control.get_tree().process_frame.connect(func() -> void:
				if is_instance_valid(control):
					_center_control_pivot(control)
			, CONNECT_ONE_SHOT)

	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_play_hover_sfx(button)
			_animate(visual, HOVER_SCALE, deg_to_rad(hover_rotation_degrees), HOVER_DURATION)
	)
	button.mouse_exited.connect(func() -> void:
		_animate(visual, 1.0, 0.0, RESET_DURATION)
	)
	button.button_down.connect(func() -> void:
		if not button.disabled:
			_animate(visual, PRESS_SCALE, 0.0, 0.07)
	)
	button.button_up.connect(func() -> void:
		var still_hovered := button.get_rect().has_point(button.get_local_mouse_position())
		_animate(
			visual,
			HOVER_SCALE if still_hovered and not button.disabled else 1.0,
			deg_to_rad(hover_rotation_degrees) if still_hovered and not button.disabled else 0.0,
			0.11
		)
	)


static func bind_hover(control: Control, target: Node = null, hover_rotation_degrees: float = -1.6) -> void:
	var visual := target if target != null else control
	if control.get_meta(&"ui_hover_motion_owner", 0) == control.get_instance_id():
		return
	control.set_meta(&"ui_hover_motion_owner", control.get_instance_id())
	visual.set_meta(&"ui_button_base_scale", visual.get("scale"))
	visual.set_meta(&"ui_button_base_rotation", visual.get("rotation"))
	if visual is Control:
		_center_control_pivot(visual as Control)
	control.mouse_entered.connect(func() -> void:
		_animate(visual, HOVER_SCALE, deg_to_rad(hover_rotation_degrees), HOVER_DURATION)
	)
	control.mouse_exited.connect(func() -> void:
		_animate(visual, 1.0, 0.0, RESET_DURATION)
	)


static func _center_control_pivot(control: Control) -> void:
	var pivot_size := control.size
	if pivot_size.x <= 0.0 or pivot_size.y <= 0.0:
		pivot_size = control.custom_minimum_size
	control.pivot_offset = pivot_size * 0.5


static func _ensure_hover_sfx_player(button: BaseButton) -> AudioStreamPlayer:
	var existing := button.get_node_or_null(NodePath(HOVER_SFX_PLAYER_NAME)) as AudioStreamPlayer
	if existing != null:
		return existing
	var player := AudioStreamPlayer.new()
	player.name = HOVER_SFX_PLAYER_NAME
	player.stream = HOVER_FLIP_SFX
	player.volume_db = HOVER_SFX_VOLUME_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_child(player)
	return player


static func _play_hover_sfx(button: BaseButton) -> void:
	var player := _ensure_hover_sfx_player(button)
	# Re-entering a button restarts the very short flip transient cleanly.
	player.stop()
	player.play()
	button.set_meta(
		&"ui_button_hover_sfx_count",
		int(button.get_meta(&"ui_button_hover_sfx_count", 0)) + 1
	)


## 立刻中止正在跑的悬停动效并回到基准姿态。页面复位时必须走这一步：
## 只改属性的话，一个还没跑完的 hover 补间会在下一帧把复位覆盖回去。
static func reset(visual: Node, base_scale: Vector2 = Vector2.ONE, base_rotation: float = 0.0) -> void:
	var previous: Tween = (
		visual.get_meta(&"ui_button_motion_tween")
		if visual.has_meta(&"ui_button_motion_tween")
		else null
	)
	if previous != null and previous.is_valid():
		previous.kill()
	visual.set_meta(&"ui_button_base_scale", base_scale)
	visual.set_meta(&"ui_button_base_rotation", base_rotation)
	visual.set("scale", base_scale)
	visual.set("rotation", base_rotation)


static func _animate(visual: Node, scale_factor: float, rotation_offset: float, duration: float) -> void:
	var previous: Tween = (
		visual.get_meta(&"ui_button_motion_tween")
		if visual.has_meta(&"ui_button_motion_tween")
		else null
	)
	if previous != null and previous.is_valid():
		previous.kill()
	var base_scale: Vector2 = visual.get_meta(&"ui_button_base_scale", Vector2.ONE)
	var base_rotation: float = visual.get_meta(&"ui_button_base_rotation", 0.0)
	var tween := visual.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", base_scale * scale_factor, duration)
	tween.tween_property(visual, "rotation", base_rotation + rotation_offset, duration)
	visual.set_meta(&"ui_button_motion_tween", tween)
