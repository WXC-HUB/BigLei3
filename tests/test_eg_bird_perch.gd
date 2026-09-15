extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/birds/eg_bird_perch.tscn") as PackedScene
	var bird := packed.instantiate() as BirdPerch
	root.add_child(bird)
	await process_frame
	assert(bird.idle_frames.size() == 2)
	assert(bird.has_node("Tree"), "Every bird stands on a branch; the kestrel has none")
	assert((bird.get_node("Sprite") as TextureRect).visible)
	var trigger_sfx := bird.get_node("TriggerSFX") as AudioStreamPlayer
	assert(trigger_sfx.stream != null)
	bird.play_trigger_sfx()
	assert(trigger_sfx.playing)
	print("EgBirdPerch: two-frame idle and branch passed")
	quit()
