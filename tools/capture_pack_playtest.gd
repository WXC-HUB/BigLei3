extends SceneTree
## 真机验证：把 custom_packs/群岛地图.json 装进游戏开一局，翻一格，截图。
## 跑法：godot --fixed-fps 60 --path . --script tools/capture_pack_playtest.gd

const PACK_PATH := "res://custom_packs/群岛地图.json"
const OUTPUT_PATH := "res://artifacts/pack_playtest.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open(PACK_PATH, FileAccess.READ)
	if file == null:
		push_error("读不到 " + PACK_PATH)
		quit(1)
		return
	var parsed := CustomLevel.from_json(file.get_as_text())
	file.close()
	if not bool(parsed["ok"]):
		push_error("关卡包不合法：" + String(parsed["error"]))
		quit(1)
		return
	var pack: Dictionary = parsed["level"]

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.4).timeout

	# 拆掉标题页，直接走自定义开局那条路。
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()

	game.call("_on_custom_play_requested", pack)
	await create_timer(0.6).timeout

	var board: MinesweeperBoard = game.get("_board")
	var first_map := CustomLevel.map_at(pack, 0)
	var ok := (
		board != null
		and board.width == int(first_map["width"])
		and board.height == int(first_map["height"])
		and board.mine_count == int(first_map["mines"])
		and board.lantern_count == CustomLevel.item_count(pack, "lantern")
	)
	print("开局核对：%dx%d %d雷 灯%d 罗盘%d  期望 %dx%d %d雷 灯%d  → %s" % [
		board.width, board.height, board.mine_count, board.lantern_count, board.compass_count,
		int(first_map["width"]), int(first_map["height"]), int(first_map["mines"]),
		CustomLevel.item_count(pack, "lantern"),
		"一致" if ok else "不一致",
	])
	print("棋盘标题：", String((game.get("_stage_board_label") as Label).text))

	# 翻开一格中心区域的可玩格，把雷布下去，画面上就有数字可看。
	var target := -1
	for index in range(board.width * board.height):
		if board.is_active(index):
			target = index
	if target >= 0:
		game.call("_on_cell_revealed", target)
	await create_timer(1.4).timeout

	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("saved ", OUTPUT_PATH)
	(game.get_node("BGM") as AudioStreamPlayer).stop()
	if not ok:
		quit(1)
		return
	quit()
