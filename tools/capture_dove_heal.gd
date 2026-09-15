extends SceneTree
## 斑鸠验收截图：栖位待机、起飞、飞向血条、爱心回来、飘字、回栖位。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --path . --script tools/capture_dove_heal.gd
## 存档指到临时槽，不碰玩家真实存档。

const OUTPUT_DIR := "res://artifacts/dove"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const TUTORIAL_LEVEL_COUNT := 8


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
	await process_frame

	for flag in [
		"_red_bird_unlocked", "_night_heron_unlocked", "_attacker_bird_unlocked",
		"_lucky_bird_unlocked", "_tit_bird_unlocked", "_magpie_bird_unlocked",
		"_crow_bird_unlocked", "_dove_bird_unlocked",
	]:
		game.set(flag, true)
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	await create_timer(1.0).timeout
	_save("01_perch_idle")

	# 先掉一颗爱心，不然满血时看不出它把血补回来了。
	game.set("_player_hp", 1)
	game.call("_refresh_health_bar")

	var board: MinesweeperBoard = game.get("_board")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)
	var card := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == MinesweeperBoard.ItemType.MEDICAL_KIT:
			card = index
			break
	board.reveal_exact_forced_safe(card)
	game.call("_refresh_cell", card)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_resolve_queued_item", card, MinesweeperBoard.ItemType.MEDICAL_KIT, queue, queued)
	await create_timer(0.25).timeout
	_save("02_fly_out")
	await create_timer(0.25).timeout
	_save("03_carrying_to_bar")
	await create_timer(0.25).timeout
	_save("04_heart_back")
	await create_timer(0.35).timeout
	_save("05_float_text")
	await create_timer(1.2).timeout
	_save("06_back_home")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved dove screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
