extends SceneTree
## 开局演出验收截图：洗牌发牌途中、发完、道具横幅，以及连携雷被灰喜鹊连起来的过程。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_round_intro.gd
## 存档指到临时槽，不碰玩家真实存档。

const OUTPUT_DIR := "res://artifacts/round_intro"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const TUTORIAL_LEVEL_COUNT := 6


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://round_intro_capture_save.json"
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
	]:
		game.set(flag, true)

	# 先无声推到第一盘正式关，再重来一盘把开局演出拍全。
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	await create_timer(4.0).timeout

	game.set("_run_number", TUTORIAL_LEVEL_COUNT)
	game.call("_start_game")
	await create_timer(0.1).timeout
	_save("01_dealing_early")
	await create_timer(0.22).timeout
	_save("02_dealing_late")
	await create_timer(1.3).timeout
	_save("03_intro_banner")
	await create_timer(2.6).timeout
	_save("04_ready")

	# 连携：找出这一盘的连携组，手动标出其中一颗，看灰喜鹊把剩下的连起来。
	var board: MinesweeperBoard = game.get("_board")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)
	var chain: PackedInt32Array = board.covered_chain_mines()
	print("连携组 = ", chain, " / 共 ", board.chain_mine_total(), " 颗")
	if chain.size() >= 2:
		game.call("_on_cell_flagged", chain[0])
		await create_timer(0.55).timeout
		_save("05_chain_flying")
		await create_timer(0.9).timeout
		_save("06_chain_linked")
		await create_timer(2.0).timeout
		_save("07_chain_done")
		print("连携后仍未标出的 = ", board.covered_chain_mines())

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved round intro screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
