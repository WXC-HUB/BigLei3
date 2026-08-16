extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("First normal-level heal test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame

	game.set("_run_number", 4)
	game.set("_player_hp", 1)
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == 5, "Test did not enter the first normal level")
	assert(
		int(game.get("_player_hp")) == int(game.get("_player_max_hp")),
		"Finishing the tutorial did not restore full health"
	)

	game.set("_player_hp", 1)
	game.call("_start_game")
	await process_frame
	assert(int(game.get("_run_number")) == 6, "Test did not enter the second normal level")
	assert(int(game.get("_player_hp")) == 1, "Later normal levels incorrectly restored health")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	print("First normal level restores health exactly once")
	quit()
