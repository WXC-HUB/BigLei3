class_name WrongFlagGuideBanner
extends Control
## 可带图标或纯文字的非阻塞提示横幅。

const HOLD_SECONDS := 3.4

@onready var banner: PanelContainer = %Banner
@onready var icon: TextureRect = %Icon
@onready var message: Label = %Message

var presentation_count := 0
var _showing := false


func _ready() -> void:
	banner.visible = false


func configure(copy: String, texture: Texture2D = null) -> void:
	message.text = copy
	icon.texture = texture
	icon.visible = texture != null
	message.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if texture != null
		else HORIZONTAL_ALIGNMENT_CENTER
	)


func present() -> void:
	if _showing:
		return
	_showing = true
	presentation_count += 1
	banner.modulate.a = 0.0
	banner.visible = true
	await get_tree().process_frame
	var resting_y := banner.position.y
	var hidden_y := -banner.size.y - 30.0
	banner.position.y = hidden_y
	banner.scale = Vector2(0.97, 0.97)

	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(banner, "position:y", resting_y, 0.42)
	intro.tween_property(banner, "modulate:a", 1.0, 0.2)
	intro.tween_property(banner, "scale", Vector2.ONE, 0.32)
	await intro.finished
	await get_tree().create_timer(HOLD_SECONDS, true, false, true).timeout

	var outro := create_tween().set_parallel(true)
	outro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(banner, "position:y", hidden_y, 0.3)
	outro.tween_property(banner, "modulate:a", 0.0, 0.2).set_delay(0.08)
	await outro.finished
	banner.visible = false
	_showing = false


func hide_immediately() -> void:
	banner.visible = false
	_showing = false
