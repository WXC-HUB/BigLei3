class_name UnlockRevealMotion
extends RefCounted

const SILHOUETTE_SHADER := preload("res://shaders/unlock_bird_silhouette.gdshader")
const ORIGINAL_MOUSE_FILTER_META := &"unlock_reveal_original_mouse_filter"


static func prepare(
	stage: Control,
	bird: TextureRect,
	labels: Array[Label],
	continue_button: Button
) -> void:
	stage.visible = true
	if not bird.has_meta(ORIGINAL_MOUSE_FILTER_META):
		bird.set_meta(ORIGINAL_MOUSE_FILTER_META, bird.mouse_filter)
	bird.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bird.modulate.a = 0.0
	for label in labels:
		label.modulate.a = 0.0
	continue_button.visible = false
	continue_button.disabled = true


static func play(
	host: Control,
	stage: Control,
	bird: TextureRect,
	labels: Array[Label],
	continue_button: Button
) -> void:
	prepare(stage, bird, labels, continue_button)
	await host.get_tree().process_frame

	var bird_home := bird.position
	var bird_home_rotation := bird.rotation
	var center_position := (stage.size - bird.size) * 0.5 + Vector2(0.0, -34.0)
	var label_homes: Array[Vector2] = []
	for label in labels:
		label_homes.append(label.position)
		label.position += Vector2(0.0, 34.0)
		label.modulate.a = 0.0

	var silhouette_material := ShaderMaterial.new()
	silhouette_material.shader = SILHOUETTE_SHADER
	bird.material = silhouette_material
	bird.position = center_position
	bird.rotation = 0.0
	bird.pivot_offset = bird.size * 0.5
	bird.scale = Vector2(0.82, 0.82)
	bird.modulate.a = 0.0
	host.set_meta(&"unlock_reveal_phase", "silhouette")

	var silhouette_enter := host.create_tween().set_parallel(true)
	silhouette_enter.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	silhouette_enter.tween_property(bird, "scale", Vector2.ONE, 0.28)
	silhouette_enter.tween_property(bird, "modulate:a", 1.0, 0.18)
	await silhouette_enter.finished

	var shake_offsets := [
		Vector2(-18.0, 5.0), Vector2(16.0, -5.0),
		Vector2(-13.0, -3.0), Vector2(11.0, 4.0),
		Vector2(-7.0, 2.0), Vector2(6.0, -2.0),
		Vector2(-3.0, 1.0), Vector2.ZERO,
	]
	var shake := host.create_tween()
	for offset in shake_offsets:
		shake.tween_property(bird, "position", center_position + offset, 0.055)
	await shake.finished

	host.set_meta(&"unlock_reveal_phase", "flip")
	var flip_close := host.create_tween()
	flip_close.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flip_close.tween_property(bird, "scale:x", 0.03, 0.15)
	await flip_close.finished
	bird.material = null
	var flip_open := host.create_tween()
	flip_open.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_open.tween_property(bird, "scale:x", 1.0, 0.2)
	await flip_open.finished
	host.set_meta(&"unlock_reveal_phase", "color")
	bird.mouse_filter = int(bird.get_meta(ORIGINAL_MOUSE_FILTER_META, Control.MOUSE_FILTER_STOP))

	var settle := host.create_tween().set_parallel(true)
	settle.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	settle.tween_property(bird, "position", bird_home, 0.42)
	settle.tween_property(bird, "rotation", bird_home_rotation, 0.42)
	for index in range(labels.size()):
		settle.tween_property(labels[index], "position", label_homes[index], 0.32).set_delay(0.05 + index * 0.08)
		settle.tween_property(labels[index], "modulate:a", 1.0, 0.2).set_delay(0.05 + index * 0.08)
	await settle.finished

	continue_button.modulate.a = 0.0
	continue_button.visible = true
	var button_enter := host.create_tween()
	button_enter.tween_property(continue_button, "modulate:a", 1.0, 0.2)
	await button_enter.finished
