extends SceneTree
## 宣传截图：1920×1080，五张真实游戏画面（自定义编辑器 / 关卡玩法两张 / 商店 / 世界地图）。
## 跑法（**不能加 --headless**，否则渲不出东西）：
##   godot --resolution 1920x1080 --fixed-fps 60 --script tools/capture_promo.gd
## 存档指到临时槽，不碰玩家真实存档。

const OUTPUT_DIR := "res://artifacts/promo"
const CAPTURE_SIZE := Vector2i(1920, 1080)


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var original_save := GameSave.save_path
	GameSave.save_path = "user://promo_capture_save.json"
	GameSave.clear()
	DisplayServer.window_set_size(CAPTURE_SIZE)
	root.size = CAPTURE_SIZE
	for _i in 5:
		await process_frame

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout

	# ---- 1. 自定义编辑器 ----
	game.call("_on_custom_requested")
	await create_timer(0.6).timeout
	var editor = game.get("_custom_editor")
	var level := CustomLevel.make_default()
	level["name"] = "环形试炼"
	level["width"] = 9
	level["height"] = 7
	level["mask"] = PackedByteArray([
		0, 0, 1, 1, 1, 1, 1, 0, 0,
		0, 1, 1, 1, 1, 1, 1, 1, 0,
		1, 1, 1, 0, 0, 0, 1, 1, 1,
		1, 1, 0, 0, 0, 0, 0, 1, 1,
		1, 1, 1, 0, 0, 0, 1, 1, 1,
		0, 1, 1, 1, 1, 1, 1, 1, 0,
		0, 0, 1, 1, 1, 1, 1, 0, 0,
	])
	level["mines"] = 7
	level["items"] = {
		"lantern": 2, "compass": 1, "orbital_strike": 1, "super_luck": 1,
		"medical_kit": 1, "xray": 1, "chain": 1, "enlarge": 0, "detect": 1,
	}
	editor.load_level(level)
	await process_frame
	await process_frame
	_save("05_custom_editor")

	# 回标题，再把标题页收掉，直接进关。
	game.call("_on_custom_back_requested")
	await create_timer(0.5).timeout
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	await process_frame

	# ---- 2/3. 关卡玩法：第 4 关「双桥」，异形棋盘 ----
	game.set("_cleared_stages", ["grass_1", "grass_2", "grass_3"])
	game.call("_enter_stage", "river_1", false)
	# 开盘横幅要放完（约 4 秒）。
	await create_timer(5.0).timeout
	var board: MinesweeperBoard = game.get("_board")
	var center := _first_active_near_center(board)
	game.call("_on_cell_revealed", center)
	await create_timer(1.6).timeout
	# 插一面正确的旗。
	for index in board.width * board.height:
		if board.is_active(index) and board.is_monster_core(index) and board.state_at(index) == board.CellState.COVERED:
			game.call("_on_cell_flagged", index)
			break
	await create_timer(1.4).timeout
	# 翻一张道具卡，鸟会飞出来结算。
	for index in board.width * board.height:
		if (
			board.is_active(index)
			and board.item_at(index) != board.ItemType.NONE
			and board.state_at(index) == board.CellState.COVERED
			and not board.is_monster_core(index)
		):
			game.call("_on_cell_revealed", index)
			break
	await create_timer(0.75).timeout
	_save("02_gameplay_bird")
	await create_timer(2.6).timeout
	await process_frame
	_save("01_gameplay")

	# ---- 4. 局间商店 ----
	game.set("_gold", 14)
	game.call("_refresh_gold_display")
	game.call("_show_shop")
	await create_timer(1.2).timeout
	_save("04_shop")
	(game.get("_shop_layer") as CanvasLayer).visible = false

	# ---- 5. 世界地图 ----
	game.call("_return_to_world_map")
	for _i in 50:
		await process_frame
	_save("03_world_map")

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	GameSave.clear()
	GameSave.save_path = original_save
	print("Saved promo screenshots to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _first_active_near_center(board: MinesweeperBoard) -> int:
	var cx := int(board.width / 2)
	var cy := int(board.height / 2)
	var best := -1
	var best_distance := 1 << 30
	for index in board.width * board.height:
		if not board.is_active(index):
			continue
		var x := index % board.width
		var y := int(index / board.width)
		var distance := (x - cx) * (x - cx) + (y - cy) * (y - cy)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("保存失败 %s: %s" % [path, error_string(error)])
	else:
		print("已保存 ", path, " ", image.get_size())
