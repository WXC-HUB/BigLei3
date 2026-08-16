class_name AchievementToast
extends Control
## 全局成就提示队列。每条从右下角滑入，停留后滑出；连续解锁时顺序播放。

const HOLD_SECONDS := 2.8

@onready var toast_card: PanelContainer = %ToastCard
@onready var icon: TextureRect = %Icon
@onready var achievement_name: Label = %AchievementName
@onready var description: Label = %Description

var _queue: Array[Dictionary] = []
var _showing := false
var _resting_x := 0.0
var _resting_x_ready := false


func _ready() -> void:
	toast_card.visible = false


func show_achievement(title: String, body: String, texture: Texture2D) -> void:
	_queue.append({"title": title, "body": body, "icon": texture})
	if not _showing:
		_play_queue()


func _play_queue() -> void:
	_showing = true
	while not _queue.is_empty():
		var entry: Dictionary = _queue.pop_front()
		achievement_name.text = entry["title"]
		description.text = entry["body"]
		icon.texture = entry["icon"]
		await get_tree().process_frame
		toast_card.visible = true
		if not _resting_x_ready:
			_resting_x = toast_card.position.x
			_resting_x_ready = true
		var hidden_x := get_viewport_rect().size.x + 36.0
		toast_card.position.x = hidden_x
		toast_card.modulate.a = 0.0
		toast_card.scale = Vector2(0.96, 0.96)

		var intro := create_tween().set_parallel(true)
		intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		intro.tween_property(toast_card, "position:x", _resting_x, 0.42)
		intro.tween_property(toast_card, "modulate:a", 1.0, 0.2)
		intro.tween_property(toast_card, "scale", Vector2.ONE, 0.34)
		await intro.finished
		await get_tree().create_timer(HOLD_SECONDS, true, false, true).timeout

		var outro := create_tween().set_parallel(true)
		outro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		outro.tween_property(toast_card, "position:x", hidden_x, 0.32)
		outro.tween_property(toast_card, "modulate:a", 0.0, 0.22).set_delay(0.08)
		await outro.finished
		toast_card.visible = false
	_showing = false
