extends SceneTree
## 奖励盘的过目截图：把一盘的雷全标掉、留几张没结算的牌，然后逼出奖励盘。
## 跑法（**不能加 --headless**）：
##   godot --fixed-fps 60 --path . --script tools/capture_bonus_board.gd
## 输出 artifacts/bonus_board_intro.png（牌正在落下）与 artifacts/bonus_board.png（落定）。

const COMPASS := MinesweeperBoard.ItemType.COMPASS
const LANTERN := MinesweeperBoard.ItemType.LANTERN
const ORBITAL := MinesweeperBoard.ItemType.ORBITAL_STRIKE


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
	# 标题页在自己的 canvas layer 上，不掀掉它每一帧都是标题。
	game.call("_on_start_game_requested")
	await process_frame
	var tutorial_count: int = (game.get_script() as GDScript).get_script_constant_map()["TUTORIAL_LEVEL_COUNT"]
	game.set("_run_number", tutorial_count)
	game.call("_start_game")
	# 「开始」永远先进选关柜；直接发盘的话柜子还盖在后面，截出来背景是两层。
	game.call("_hide_world_map")
	game.call("_set_scenery_visible", true)
	for _i in 150:
		await process_frame

	var board: MinesweeperBoard = game.get("_board")
	board.ensure_mines_placed(int(board.height / 2) * board.width + int(board.width / 2))
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) != MinesweeperBoard.CellState.FLAGGED:
			board.toggle_flag(index)
	game.call("_update_round_completion")

	var queue: Array[int] = []
	var kinds := [COMPASS, LANTERN, ORBITAL]
	for index in range(board.width * board.height):
		if queue.size() >= kinds.size():
			break
		if not board.is_active(index) or board.is_monster_core(index):
			continue
		if board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			continue
		board.reveal_exact_forced_safe(index)
		board.force_item_at(index, kinds[queue.size()], false)
		queue.append(index)

	var queued_items := {}
	for index in queue:
		queued_items[index] = true
	game.call("_open_bonus_board", queue, queued_items)
	# 光环与标题已经亮起、牌正一张张往下落的那一刻。
	for _i in 46:
		await process_frame
	_shot("res://artifacts/bonus_board_intro.png")
	for _i in 80:
		await process_frame
	_shot("res://artifacts/bonus_board.png")
	GameSave.clear()
	quit()


## 隔离档：教学已过、开场演出跳过，不然整屏都是黑底字。
func _isolate_save() -> void:
	GameSave.save_path = "user://capture_bonus_board.json"
	GameSave.write({
		"tutorial_completed": true,
		"intro_played": true,
		"current_level": 9,
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
