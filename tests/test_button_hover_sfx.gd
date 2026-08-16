extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var button := Button.new()
	button.text = "Hover test"
	root.add_child(button)
	UIButtonMotion.bind(button)
	await process_frame

	button.mouse_entered.emit()
	var player := button.get_node("HoverFlipSFX") as AudioStreamPlayer
	assert(player.stream == load("res://assets/audio/card_reveal_crack.wav"), "Button hover uses the wrong sound")
	assert(player.playing, "Entering an enabled button did not play the flip sound")
	assert(int(button.get_meta("ui_button_hover_sfx_count", 0)) == 1, "Button hover sound played an unexpected number of times")

	button.mouse_exited.emit()
	assert(int(button.get_meta("ui_button_hover_sfx_count", 0)) == 1, "Leaving a button played the hover sound")
	button.disabled = true
	button.mouse_entered.emit()
	assert(int(button.get_meta("ui_button_hover_sfx_count", 0)) == 1, "A disabled button played the hover sound")

	button.queue_free()
	await process_frame
	print("Button hover flip sound passed")
	quit()
