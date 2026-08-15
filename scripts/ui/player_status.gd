class_name PlayerStatus
extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var gold_label: Label = %GoldLabel


func set_health(value: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = clampi(value, 0, maximum)


func set_gold(value: int) -> void:
	gold_label.text = "%dG" % maxi(value, 0)


func play_hit_feedback() -> void:
	health_bar.pivot_offset = health_bar.size * 0.5
	var tween := create_tween()
	tween.tween_property(health_bar, "scale", Vector2(1.18, 0.88), 0.07)
	tween.tween_property(health_bar, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
