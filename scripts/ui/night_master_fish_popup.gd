class_name NightMasterFishPopup
extends Control

signal finished

@onready var _bg1: Sprite2D = $Bg1
@onready var _bg2: Sprite2D = $Bg2
@onready var _bg3: Sprite2D = $Bg3
@onready var _bird: Sprite2D = $BlackIdle1
@onready var _message: Label = $Message
@onready var _fish_bone: Sprite2D = $Sp1
@onready var _exclamation: Sprite2D = $Sp2


func play() -> void:
	visible = true
	modulate = Color.WHITE
	var bg1_home := _snapshot(_bg1)
	var bg2_home := _snapshot(_bg2)
	var bg3_home := _snapshot(_bg3)
	var bird_home := _snapshot(_bird)
	var message_home := _snapshot(_message)
	var fish_home := _snapshot(_fish_bone)
	var exclamation_home := _snapshot(_exclamation)

	_message.pivot_offset = _message.size * 0.5
	_prepare_pop(_bg2, bg2_home, 0.34, -0.1)
	_prepare_pop(_bg1, bg1_home, 0.24, 0.09)
	_prepare_pop(_bg3, bg3_home, 0.2, -0.08)
	_bg3.position = bg3_home["position"] + Vector2(-42.0, 30.0)
	_bird.position = bird_home["position"] + Vector2(-190.0, 42.0)
	_bird.scale = bird_home["scale"] * 0.72
	_bird.rotation = -0.12
	_bird.modulate.a = 0.0
	_message.scale = Vector2(0.56, 0.56)
	_message.rotation = float(message_home["rotation"]) - 0.1
	_message.modulate.a = 0.0
	_fish_bone.position = fish_home["position"] + Vector2(-190.0, 42.0)
	_fish_bone.scale = fish_home["scale"] * 0.22
	_fish_bone.rotation = float(fish_home["rotation"]) - 0.7
	_fish_bone.modulate.a = 0.0
	_prepare_pop(_exclamation, exclamation_home, 0.08, -0.18)

	var enter := create_tween().set_parallel(true)
	_pop_to_home(enter, _bg2, bg2_home, 0.18, 0.0)
	_pop_to_home(enter, _bg1, bg1_home, 0.2, 0.04)
	_pop_to_home(enter, _bg3, bg3_home, 0.22, 0.08)
	_move_to_home(enter, _bird, bird_home, 0.3, 0.1)
	_move_to_home(enter, _message, message_home, 0.22, 0.23)
	_move_to_home(enter, _fish_bone, fish_home, 0.25, 0.29)
	_pop_to_home(enter, _exclamation, exclamation_home, 0.18, 0.36)
	await enter.finished
	await get_tree().create_timer(0.62).timeout

	var leave := create_tween().set_parallel(true)
	leave.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leave.tween_property(self, "modulate:a", 0.0, 0.22)
	leave.tween_property(_bird, "position:x", _bird.position.x - 34.0, 0.22)
	leave.tween_property(_fish_bone, "position:x", _fish_bone.position.x + 58.0, 0.22)
	leave.tween_property(_fish_bone, "rotation", _fish_bone.rotation + 0.28, 0.22)
	leave.tween_property(_exclamation, "position:y", _exclamation.position.y - 26.0, 0.22)
	await leave.finished
	finished.emit()
	queue_free()


func _snapshot(node: CanvasItem) -> Dictionary:
	return {
		"position": node.position,
		"scale": node.scale,
		"rotation": node.rotation,
	}


func _prepare_pop(node: CanvasItem, home: Dictionary, scale_factor: float, rotation_offset: float) -> void:
	node.scale = home["scale"] * scale_factor
	node.rotation = float(home["rotation"]) + rotation_offset
	node.modulate.a = 0.0


func _pop_to_home(
	tween: Tween,
	node: CanvasItem,
	home: Dictionary,
	duration: float,
	delay: float
) -> void:
	tween.tween_property(node, "scale", home["scale"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation", home["rotation"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, minf(duration, 0.12)).set_delay(delay)
	if node.position != home["position"]:
		tween.tween_property(node, "position", home["position"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _move_to_home(
	tween: Tween,
	node: CanvasItem,
	home: Dictionary,
	duration: float,
	delay: float
) -> void:
	tween.tween_property(node, "position", home["position"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", home["scale"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation", home["rotation"], duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, minf(duration, 0.14)).set_delay(delay)
