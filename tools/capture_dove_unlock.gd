extends SceneTree
## 斑鸠解锁页验收截图：初始页、丢枝的一瞬、窝堆到一半、红隼俯冲、叼走后的「好吃」。
## 跑法（**不能加 --headless**）：
##   godot --resolution 1920x1080 --fixed-fps 60 --path . --script tools/capture_dove_unlock.gd

const OUTPUT_DIR := "res://artifacts/dove"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const DOVE := preload("res://scripts/ui/dove_unlock.gd")
const TWIG_CYCLE := DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME + DOVE.TWIG_RETURN_TIME + 0.14


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://dove_capture_save.json"
	GameSave.clear()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	for _i in 5:
		await process_frame

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.call("_start_game")
	await create_timer(0.4).timeout

	var unlock := game.get("_dove_unlock") as DoveUnlock
	unlock.present()
	await create_timer(3.0).timeout
	_save("20_unlock_page")

	# 第一根枝翻着往下落的那一瞬。
	unlock.bird.mouse_entered.emit()
	await create_timer(DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME * 0.55).timeout
	_save("21_dropping_twig")
	await create_timer(TWIG_CYCLE).timeout

	# 堆到一半：看得出是一摊柴火，不是窝。
	while unlock.twig_count() < DOVE.TWIGS_TO_NEST - 3:
		unlock.bird.mouse_entered.emit()
		await create_timer(TWIG_CYCLE).timeout
	_save("22_sloppy_nest")

	# 最后一根：红隼俯冲下来。
	while unlock.twig_count() < DOVE.TWIGS_TO_NEST - 1:
		unlock.bird.mouse_entered.emit()
		await create_timer(TWIG_CYCLE).timeout
	unlock.bird.mouse_entered.emit()
	await create_timer(DOVE.TWIG_LEAN_TIME + DOVE.TWIG_DROP_TIME + DOVE.SNATCH_DIVE_TIME * 0.85).timeout
	_save("23_kestrel_dives")
	await create_timer(DOVE.SNATCH_DIVE_TIME * 0.15 + DOVE.SNATCH_HOLD * 0.9).timeout
	_save("24_tastes_good")
	await create_timer(DOVE.SNATCH_EXIT_TIME + 0.2).timeout
	_save("25_carried_off")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved dove unlock screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
