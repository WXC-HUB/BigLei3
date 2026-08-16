class_name GameOverOverlay
extends Control

signal return_requested

@onready var card: PanelContainer = $Center/Card
@onready var level_label: Label = $Center/Card/Margin/Stack/Level
@onready var hit_area: Button = $HitArea


func _ready() -> void:
	visible = false
	hit_area.pressed.connect(func() -> void:
		if visible:
			visible = false
			return_requested.emit()
	)


func present(level: int) -> void:
	level_label.text = "旅程止步于第 %d 关" % level
	visible = true
	await get_tree().process_frame
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.82, 0.82)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2.ONE, 0.34)
	tween.tween_property(card, "modulate:a", 1.0, 0.2)
