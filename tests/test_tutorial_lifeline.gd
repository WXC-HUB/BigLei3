extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(8.0).timeout.connect(func() -> void:
		push_error("Tutorial lifeline test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	await process_frame

	game.set("_player_hp", 1)
	var rescued := bool(game.call("_apply_player_damage", 1))
	game.call("_refresh_health_bar")
	assert(rescued, "Tutorial damage did not trigger the lifeline")
	assert(int(game.get("_player_hp")) == 1, "Tutorial lifeline did not restore one heart")
	assert(not bool(game.get("_game_finish_started")), "Tutorial lifeline triggered death settlement")
	var run_before := int(game.get("_run_number"))
	await create_timer(0.45).timeout
	assert(int(game.get("_run_number")) == run_before, "Tutorial lifeline advanced the level")

	game.set("_run_number", 5)
	game.set("_player_hp", 1)
	rescued = bool(game.call("_apply_player_damage", 1))
	assert(not rescued, "Normal level incorrectly received tutorial protection")
	assert(int(game.get("_player_hp")) == 0, "Normal-level lethal damage was changed")

	print("Tutorial lifeline: 0 HP restores to 1 without death or level advance")
	quit()
