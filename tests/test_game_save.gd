extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_bird_minesweeper_save.json"
	GameSave.clear()
	var source := {
		"current_level": 7,
		"gold": 19,
		"player_hp": 2,
		"bird_unlocks": {"blue": true, "red": true},
		"achievements": ["start_game"],
	}
	assert(GameSave.write(source), "Could not write the single-slot save")
	assert(GameSave.exists(), "Save file was not created")
	assert(GameSave.load_data() == source, "Save data did not survive a round trip")
	assert(GameSave.clear(), "Could not clear the save")
	assert(not GameSave.exists(), "Clear left the save file behind")
	GameSave.save_path = original_path
	print("Single-slot JSON save round trip passed")
	quit()
