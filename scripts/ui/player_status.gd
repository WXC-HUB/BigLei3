class_name PlayerStatus
extends Control

const HEART_TEXTURE := preload("res://my_asset/heart.png")

@onready var health_bar: HBoxContainer = %HealthHearts
@onready var gold_label: Label = %GoldLabel
@onready var invincible_label: Label = %InvincibleLabel
@onready var hero_head: Sprite2D = $HeroHeadBg

var _invincible := false
var _health := 0
var _maximum_health := 0
var _hearts: Array[TextureRect] = []
var _head_home := Vector2.ZERO
var _head_scale := Vector2.ONE
var _head_flash_tween: Tween
var _head_shake_tween: Tween
var _head_punch_tween: Tween


func _ready() -> void:
	if hero_head != null:
		_head_home = hero_head.position
		_head_scale = hero_head.scale


func set_health(value: int, maximum: int) -> void:
	_health = clampi(value, 0, maximum)
	if _maximum_health != maximum or _hearts.size() != maximum:
		_rebuild_hearts(maximum)
	_maximum_health = maximum
	_refresh_hearts()


func heart_count() -> int:
	return _health


func maximum_heart_count() -> int:
	return _maximum_health


func set_gold(value: int) -> void:
	gold_label.text = "%dG" % maxi(value, 0)


func set_invincible(active: bool, amount_left: float = 0.0, count_clicks: bool = false) -> void:
	invincible_label.visible = active
	if active:
		if count_clicks:
			invincible_label.text = "幸运鸟 %d 次" % maxi(int(amount_left), 0)
		else:
			invincible_label.text = "无敌 %.1fs" % maxf(amount_left, 0.0)
	if _invincible == active:
		_refresh_hearts()
		return
	_invincible = active
	_refresh_hearts()
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
	play_hero_head_hit()


## Global centre of the portrait, so the board can aim impact VFX at it.
func hero_head_center() -> Vector2:
	if hero_head == null:
		return global_position + size * 0.5
	return hero_head.global_position


## Damage reads on the portrait first: it flashes red, takes a squash, and
## shakes itself back to rest. Re-hits restart from the resting pose instead of
## drifting, because overlapping tweens would leave the head off its anchor.
func play_hero_head_hit() -> void:
	if hero_head == null:
		return
	for running in [_head_flash_tween, _head_shake_tween, _head_punch_tween]:
		if running != null and running.is_valid():
			running.kill()
	hero_head.position = _head_home
	hero_head.scale = _head_scale
	hero_head.modulate = Color.WHITE

	_head_flash_tween = create_tween()
	_head_flash_tween.tween_property(hero_head, "modulate", Color(1.0, 0.3, 0.24), 0.05)
	_head_flash_tween.tween_property(hero_head, "modulate", Color(1.0, 0.72, 0.66), 0.09)
	_head_flash_tween.tween_property(hero_head, "modulate", Color.WHITE, 0.26)

	_head_shake_tween = create_tween()
	for offset in [Vector2(-10, 4), Vector2(9, -5), Vector2(-7, -2), Vector2(5, 4), Vector2(-3, -1)]:
		_head_shake_tween.tween_property(hero_head, "position", _head_home + offset, 0.036)
	_head_shake_tween.tween_property(hero_head, "position", _head_home, 0.06)

	_head_punch_tween = create_tween()
	_head_punch_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_head_punch_tween.tween_property(hero_head, "scale", _head_scale * Vector2(1.2, 0.84), 0.06)
	_head_punch_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_head_punch_tween.tween_property(hero_head, "scale", _head_scale, 0.2)


func play_heal_feedback() -> void:
	health_bar.pivot_offset = health_bar.size * 0.5
	var tween := create_tween()
	tween.tween_property(health_bar, "modulate", Color("9dff9d"), 0.1)
	tween.parallel().tween_property(health_bar, "scale", Vector2(1.16, 1.16), 0.1)
	tween.tween_property(health_bar, "modulate", Color.WHITE, 0.22)
	tween.parallel().tween_property(health_bar, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


func _rebuild_hearts(maximum: int) -> void:
	for child in health_bar.get_children():
		child.queue_free()
	_hearts.clear()
	for index in range(maxi(maximum, 0)):
		var heart := TextureRect.new()
		heart.custom_minimum_size = Vector2(48, 48)
		heart.texture = HEART_TEXTURE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar.add_child(heart)
		_hearts.append(heart)


func _refresh_hearts() -> void:
	for index in range(_hearts.size()):
		if index < _health:
			_hearts[index].modulate = Color("fff370") if _invincible else Color.WHITE
		else:
			_hearts[index].modulate = Color(0.22, 0.22, 0.22, 0.34)
