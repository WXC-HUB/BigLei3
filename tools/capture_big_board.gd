extends SceneTree
## 最大盘（10×10）的过目截图：验「剩余雷 / 分列道具 / 关卡名」那叠读数没被顶出屏幕。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --path . --script tools/capture_big_board.gd
## 输出 artifacts/big_board_fit.png。


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_isolate_save()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_on_start_game_requested")
	await process_frame
	# 尺寸曲线：教学之后每关涨一格，第 7 个正式关封顶在 10×10。
	var consts := (game.get_script() as GDScript).get_script_constant_map()
	game.set("_run_number", int(consts["TUTORIAL_LEVEL_COUNT"]) + 6)
	game.call("_start_game")
	game.call("_hide_world_map")
	game.call("_set_scenery_visible", true)
	for _i in 200:
		await process_frame

	var board: MinesweeperBoard = game.get("_board")
	print("盘 %d×%d，格子 %.1f，位移 %s" % [
		board.width, board.height, float(game.get("_cell_size")),
		str(game.get("_board_center_offset")),
	])
	var mine_panel := game.get("_mine_counter_panel") as Control
	print("剩余雷读数 global_rect=", mine_panel.get_global_rect())
	_shot("res://artifacts/big_board_fit.png")
	GameSave.clear()
	quit()


func _isolate_save() -> void:
	GameSave.save_path = "user://capture_big_board.json"
	GameSave.write({
		"tutorial_completed": true,
		"intro_played": true,
		"current_level": 14,
		"blue_bird_unlocked": true,
		"red_bird_unlocked": true,
		"night_heron_unlocked": true,
		"attacker_bird_unlocked": true,
		"lucky_bird_unlocked": true,
		"tit_bird_unlocked": true,
		"magpie_bird_unlocked": true,
		"crow_bird_unlocked": true,
		"dove_bird_unlocked": true,
	})


func _shot(path: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("已保存 ", path)
