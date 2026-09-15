extends SceneTree
## 长尾山雀验收截图：栖枝待机、半空、落地趴格、掉出屏幕、回到枝头。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_tit_bird.gd
## 存档指到临时槽，不碰玩家真实存档。

const OUTPUT_DIR := "res://artifacts/tit_bird"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const TUTORIAL_LEVEL_COUNT := 8


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://tit_capture_save.json"
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

	for flag in ["_red_bird_unlocked", "_night_heron_unlocked", "_attacker_bird_unlocked", "_lucky_bird_unlocked", "_tit_bird_unlocked"]:
		game.set(flag, true)
	for _level in range(TUTORIAL_LEVEL_COUNT + 1):
		game.call("_start_game")
	await create_timer(1.0).timeout
	_save("01_perch_idle")

	var board: MinesweeperBoard = game.get("_board")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)
	var target := _find_safe_area_center(board)
	game.set("_enlarge_mark_charges", 1)
	game.call("_on_cell_hover_started", target)
	await create_timer(0.3).timeout
	_save("02_armed_hover")
	game.call("_on_cell_revealed", target)
	await create_timer(0.36).timeout
	_save("03_mid_air")
	await create_timer(0.38).timeout
	_save("04_crash_landing")
	await create_timer(0.55).timeout
	_save("05_tumble_off")
	await create_timer(1.6).timeout
	_save("06_back_on_perch")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved tit bird screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _find_safe_area_center(board: MinesweeperBoard) -> int:
	var best := -1
	var best_distance := 1 << 30
	var cx := int(board.width / 2)
	var cy := int(board.height / 2)
	for centre in range(board.width * board.height):
		if board.state_at(centre) != MinesweeperBoard.CellState.COVERED or board.is_monster_core(centre):
			continue
		if board.item_at(centre) != MinesweeperBoard.ItemType.NONE:
			continue
		var safe := true
		var targets := board.neighbors_of(centre)
		targets.append(centre)
		for target in targets:
			if board.is_monster_core(target) or board.item_at(target) != MinesweeperBoard.ItemType.NONE:
				safe = false
				break
		if not safe:
			continue
		var x := centre % board.width
		var y := int(centre / board.width)
		var distance := (x - cx) * (x - cx) + (y - cy) * (y - cy)
		if distance < best_distance:
			best_distance = distance
			best = centre
	return best


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
