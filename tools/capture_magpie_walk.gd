extends SceneTree
## 灰喜鹊验收截图：栖枝待机、连携雷组亮起、一颗雷一只分身同时飞、落地标完。
## 商店加成拉到 4 颗连携雷，好看清「每颗雷一只鸟」而不是只有孤零零一只。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --path . --script tools/capture_magpie_walk.gd
## 存档指到临时槽，不碰玩家真实存档。

const OUTPUT_DIR := "res://artifacts/magpie"
const CAPTURE_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://magpie_capture_save.json"
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
		"_lucky_bird_unlocked", "_tit_bird_unlocked", "_magpie_bird_unlocked", "_crow_bird_unlocked",
	]:
		game.set(flag, true)
	# 教学关数从 main.gd 读：每加一只鸟它都会 +1。
	var tutorial_levels := int(game.get("TUTORIAL_LEVEL_COUNT"))
	game.set("_chain_bonus", 2)
	for _level in range(tutorial_levels + 1):
		game.call("_start_game")
	await create_timer(1.0).timeout
	_save("01_perch_idle")

	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(int(board.height / 2) * board.width + int(board.width / 2))
	var chain: PackedInt32Array = board.covered_chain_mines()
	if chain.size() < 2:
		push_error("这一盘没分出连携雷组，重跑一次就好")
		quit(1)
		return
	game.call("_on_cell_flagged", chain[0])
	await create_timer(0.12).timeout
	_save("02_flock_launches")
	await create_timer(0.16).timeout
	_save("03_flock_mid_air")
	await create_timer(0.35).timeout
	_save("04_landed")
	await create_timer(1.6).timeout
	_save("05_all_marked")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved magpie screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
