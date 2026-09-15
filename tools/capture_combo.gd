extends SceneTree
## 把连击的棋盘表现逐档截到 artifacts/combo/ 下，用来肉眼校对强度、配色和遮挡。
## 运行方式（需要渲染窗口，不能加 --headless）：
##   godot --fixed-fps 60 --script tools/capture_combo.gd
## --fixed-fps 必须带上：保存 PNG 会拖长真实帧间隔，不固定步长的话每张截图的
## 时间点都会漂移，光波经常已经扫过去了。
##
## 连击靠直接喂计分器堆起来，而不是真去标够 20 颗雷——盘上的雷不一定有那么多，
## 而要校对的是表现层，不是计分规则。落点封印照常播，画面里落点和全盘同框。

const CELL_FX := preload("res://vfx/cell_fx.gd")
const OUTPUT_DIR := "res://artifacts/combo"

var _game: Node
var _board: MinesweeperBoard


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	_isolate_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await process_frame
	await process_frame
	# 标题页在自己的 canvas layer 上，不掀掉它每一帧都是标题。
	_game.call("_on_start_game_requested")
	_game.call("_start_game")
	_game.call("_start_game")
	await process_frame
	_board = _game.get("_board")
	var centre := int(_board.height / 2) * _board.width + int(_board.width / 2)
	_game.call("_on_cell_revealed", centre)
	await create_timer(1.6).timeout
	print("board: %dx%d" % [_board.width, _board.height])

	await _shoot("combo_00_idle", 0.2)

	# 1-4 档：暖金，盘沿只炸一小束。
	await _build_to(3)
	await _shoot("combo_01_tier0_burst", 0.08)
	await _shoot("combo_02_tier0_trails", 0.26)

	# 5-9 档：熔橙。
	await _build_to(7)
	await _shoot("combo_03_tier1_burst", 0.09)

	# 10 连里程碑：绕盘一圈的齐射。
	await _build_to(10)
	await _shoot("combo_04_milestone_volley", 0.14)
	await _shoot("combo_05_milestone_rain", 0.34)

	# 20 连：白热档，一次点击炸满四束。
	await _build_to(20)
	await _shoot("combo_06_tier3_burst", 0.09)

	# 不再出手：连击不会自己掉，只剩盘后光晕在喘。
	await _shoot("combo_07_halo_held", 0.6)

	# 断连：烟花全灭，光晕转冷塌下去。
	_game.call("_break_score_combo")
	await _shoot("combo_08_break_wash", 0.12)
	await _shoot("combo_09_break_settled", 0.6)

	print("Saved combo frames to ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


## 这个工具会真的开一局并调 `_save_progress()` 写盘。不改 `GameSave.save_path` 的话，
## 它会把玩家真实存档里的关卡进度和六只鸟的解锁位整个覆盖掉——2026-09-12 就这么
## 干过一次。任何驱动 main.tscn 的工具都必须先把存档隔离出去。
##
## 顺带把隔离档预置成「教学已通关、六鸟全解锁」：教学第一盘只有两张牌，
## 拿它截连击毫无意义。
func _isolate_save() -> void:
	GameSave.save_path = "user://capture_combo_save.json"
	GameSave.write({
		"tutorial_completed": true,
		## 开场演出每份存档只放一次，靠这个标记记账。隔离档是全新的，不预置的话
		## 耳机提示和开场剧情会压在画面上，截出来整屏都是黑底字。
		"intro_played": true,
		"current_level": 7,  ## main.gd 的 TUTORIAL_LEVEL_COUNT 是 6，这里是教学后的第一盘
		"blue_bird_unlocked": true,
		"red_bird_unlocked": true,
		"night_heron_unlocked": true,
		"attacker_bird_unlocked": true,
		"lucky_bird_unlocked": true,
		"tit_bird_unlocked": true,
		"magpie_bird_unlocked": true,
	})


## 把连击堆到 `target`，每一刀都走真实的表现入口。
func _build_to(target: int) -> void:
	var tracker = _game.get("_score_combo")
	var cells: Array = _game.get("_cells")
	var layer: Control = _game.get("_effects_layer")
	while tracker.combo < target:
		var index := _pick_covered_cell()
		# 只喂这一下：hit 信号会自己把 HUD 和盘后烟花都带起来，
		# 再手动喊一次 _play_combo_board_hit 就会一刀炸两束。
		_game.call("_register_mine_score_hit")
		if index >= 0:
			var cell: Control = cells[index]
			CELL_FX.play_flag_seal(
				layer,
				cell.global_position + cell.size * 0.5,
				ComboStyle.tier_color(tracker.combo),
				ComboStyle.heat(tracker.combo)
			)
		await create_timer(0.09).timeout


## 随便挑一格还盖着的做落点，让每一刀的波心不一样。
func _pick_covered_cell() -> int:
	var total := _board.width * _board.height
	for _attempt in range(24):
		var index := randi() % total
		if _board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			return index
	return int(total / 2)


func _shoot(name: String, wait: float) -> void:
	await create_timer(wait).timeout
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, name])
