class_name VictoryBanner
extends Control

@onready var banner: PanelContainer = $Center/Banner
@onready var title: Label = $Center/Banner/Margin/Stack/Title
@onready var subtitle: Label = $Center/Banner/Margin/Stack/Subtitle

var _presentation_count := 0


func _ready() -> void:
	visible = false


func present(level: int) -> void:
	_presentation_count += 1
	title.text = "关卡胜利"
	subtitle.text = "第 %d 关清扫完成" % level
	visible = true
	await get_tree().process_frame
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.55, 0.55)
	banner.modulate.a = 0.0
	var enter := create_tween().set_parallel(true)
	enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(banner, "scale", Vector2.ONE, 0.34)
	enter.tween_property(banner, "modulate:a", 1.0, 0.2)
	await enter.finished
	await get_tree().create_timer(0.75).timeout
	var exit := create_tween().set_parallel(true)
	exit.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(banner, "scale", Vector2(1.08, 1.08), 0.18)
	exit.tween_property(banner, "modulate:a", 0.0, 0.18)
	await exit.finished
	visible = false
	banner.scale = Vector2.ONE
	banner.modulate = Color.WHITE
