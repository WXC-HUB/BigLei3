class_name PlayerStatus
extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var gold_label: Label = %GoldLabel
@onready var invincible_label: Label = %InvincibleLabel

var _invincible := false


func set_health(value: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = clampi(value, 0, maximum)


func set_gold(value: int) -> void:
	gold_label.text = "%dG" % maxi(value, 0)


func set_invincible(active: bool, seconds_left: float = 0.0) -> void:
	invincible_label.visible = active
	if active:
		invincible_label.text = "无敌 %.1fs" % maxf(seconds_left, 0.0)
	if _invincible == active:
		return
	_invincible = active
	health_bar.add_theme_stylebox_override("background", _health_background_style(active))
	health_bar.add_theme_stylebox_override("fill", _health_fill_style(active))
	if active:
		health_bar.pivot_offset = health_bar.size * 0.5
		var tween := create_tween()
		tween.tween_property(health_bar, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(health_bar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func play_hit_feedback() -> void:
	health_bar.pivot_offset = health_bar.size * 0.5
	var tween := create_tween()
	tween.tween_property(health_bar, "scale", Vector2(1.18, 0.88), 0.07)
	tween.tween_property(health_bar, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)


func _health_background_style(invincible: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	style.bg_color = Color("e8d7a7") if invincible else Color("ead8c7")
	style.border_color = Color("8d7429") if invincible else Color("6f4438")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


func _health_fill_style(invincible: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7d34f") if invincible else Color("d1422f")
	style.border_color = Color("fff3a0") if invincible else Color("ff9690")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style
