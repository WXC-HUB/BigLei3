extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var player := game.get_node("BGM") as AudioStreamPlayer
	assert(player.stream is AudioStreamMP3)
	assert((player.stream as AudioStreamMP3).loop)
	assert(player.playing)
	print("BGM: loaded, looping, and playing")
	game.queue_free()
	await process_frame
	quit()
