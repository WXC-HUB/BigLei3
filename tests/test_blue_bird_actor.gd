extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/blue_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate()
	root.add_child(bird)
	await process_frame
	assert(not bool(bird.get("_finding")))
	var find_sfx := bird.get_node("ActionSFX") as AudioStreamPlayer
	assert(not find_sfx.playing)
	bird.call("play_find", true)
	assert(bool(bird.get("_finding")))
	assert(find_sfx.playing)
	await create_timer(1.05).timeout
	assert(not bool(bird.get("_finding")))
	print("BirdPerch: idle, find result, and SFX passed")
	quit()
