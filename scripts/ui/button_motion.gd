class_name UIButtonMotion
extends RefCounted

const HOVER_SCALE := 1.045
const PRESS_SCALE := 0.975
const HOVER_DURATION := 0.14
const RESET_DURATION := 0.16


static func bind(button: BaseButton, target: Node = null, hover_rotation_degrees: float = -1.6) -> void:
	var visual := target if target != null else button
	if visual.has_meta(&"ui_button_motion_bound"):
		return
	visual.set_meta(&"ui_button_motion_bound", true)
	visual.set_meta(&"ui_button_base_scale", visual.get("scale"))
	visual.set_meta(&"ui_button_base_rotation", visual.get("rotation"))

	if visual is Control:
		var control := visual as Control
		_center_control_pivot(control)

	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
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


static func _center_control_pivot(control: Control) -> void:
	var pivot_size := control.size
	if pivot_size.x <= 0.0 or pivot_size.y <= 0.0:
		pivot_size = control.custom_minimum_size
	control.pivot_offset = pivot_size * 0.5


static func _animate(visual: Node, scale_factor: float, rotation_offset: float, duration: float) -> void:
	var previous: Tween = visual.get_meta(&"ui_button_motion_tween", null)
	if previous != null and previous.is_valid():
		previous.kill()
	var base_scale: Vector2 = visual.get_meta(&"ui_button_base_scale", Vector2.ONE)
	var base_rotation: float = visual.get_meta(&"ui_button_base_rotation", 0.0)
	var tween := visual.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", base_scale * scale_factor, duration)
	tween.tween_property(visual, "rotation", base_rotation + rotation_offset, duration)
	visual.set_meta(&"ui_button_motion_tween", tween)
