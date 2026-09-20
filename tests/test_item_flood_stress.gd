extends SceneTree
## 压力复现：一盘里同时翻出大量伙伴牌时，结算队列会不会卡死 / 特效节点会不会爆掉。
## 玩家反馈「卡住然后闪退」，现场截图是后期关的大异形盘、盘上铺满伙伴牌，所以这里
## 按「商店买满」的极端配置真打几盘（自动点格子），盯住卡死与节点增长。
## 跑法：godot --headless --path . --script tests/test_item_flood_stress.gd

const STAGE_ID := "coast_1"
## 一步（点一下之后等结算）最多等这么多帧，超了就当卡死。
const STEP_FRAME_CAP := 3600

var _game: Node = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		push_error("FLOOD STRESS TIMED OUT (hard)")
		_dump("hard timeout")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_item_flood_stress.json"
	GameSave.clear()

	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await process_frame

	await _enter_late_stage()
	for round_index in 4:
		var ok := await _play_one_board(round_index)
		if not ok:
			return
		if bool(_game.get("_game_finish_started")):
			await _leave_settlement()

	(_game.get_node("BGM") as AudioStreamPlayer).stop()
	_game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("FLOOD STRESS: 极端道具配置下连打四盘，没有卡死")
	quit()


## 进后期关的后段盘，并把道具数量全部推到商店能买到的上限之上。
func _enter_late_stage() -> void:
	var stage := StageTable.stage(STAGE_ID)
	assert(not stage.is_empty(), "找不到关卡 %s" % STAGE_ID)
	_game.call("_prepare_stage_run", stage)
	_game.set("_stage_round", 8)
	_game.set("_run_number", 20)
	_game.set("_lantern_bonus", 4)
	_game.set("_compass_bonus", 4)
	_game.set("_orbital_strike_bonus", 3)
	_game.set("_super_luck_bonus", 3)
	_game.set("_medical_kit_bonus", 2)
	_game.set("_xray_bonus", 2)
	_game.set("_enlarge_bonus", 2)
	_game.set("_chain_bonus", 3)
	_game.set("_super_luck_click_bonus", 2)
	_game.set("_player_max_hp", 30)
	_game.set("_player_hp", 30)
	_game.call("_start_game")
	for _i in 30:
		await process_frame


func _play_one_board(round_index: int) -> bool:
	var board: MinesweeperBoard = _game.get("_board")
	print("[flood] 第 %d 盘 %dx%d 雷 %d 埋牌 %d" % [
		round_index, board.width, board.height, board.mine_count, board.hidden_item_count()
	])
	var peak_effects := 0
	var clicks := 0
	while clicks < 400:
		if bool(_game.get("_game_finish_started")) or board != _game.get("_board"):
			break
		var settled := await _wait_settled(peak_effects)
		peak_effects = maxi(peak_effects, int(settled["peak"]))
		if not bool(settled["ok"]):
			_dump("STUCK: 点了 %d 下之后结算不回来" % clicks)
			push_error("FLOOD STRESS: settlement never released the board")
			quit(3)
			return false
		if bool(_game.get("_game_finish_started")) or board != _game.get("_board"):
			break
		var target := _next_click(board)
		if target < 0:
			_dump("没有可点的格子了（点了 %d 下）" % clicks)
			push_error("FLOOD STRESS: no clickable cell but the round never ended")
			quit(4)
			return false
		clicks += 1
		if board.has_mine(target):
			_game.call("_on_cell_flagged", target)
		else:
			_game.call("_on_cell_revealed", target)
		await process_frame
	print("[flood] 第 %d 盘走完：点 %d 下，特效节点峰值 %d，收场=%s，奖励盘 %s 张" % [
		round_index, clicks, peak_effects,
		str(_game.get("_game_finish_started")), str(_game.get("_bonus_boards_this_round"))
	])
	return true


## 等这一手的结算跑完，把棋盘交还玩家。红隼模式不算「没交还」——它本来就等玩家点。
func _wait_settled(peak_in: int) -> Dictionary:
	var peak := peak_in
	for frame in STEP_FRAME_CAP:
		peak = maxi(peak, _effects_count())
		if bool(_game.get("_game_finish_started")):
			return {"ok": true, "peak": peak}
		if not bool(_game.get("_resolving")):
			return {"ok": true, "peak": peak}
		if frame > 0 and frame % 900 == 0:
			_dump("still resolving @%d" % frame)
		await process_frame
	return {"ok": false, "peak": peak}


## 下一手点哪：优先翻没盖开的安全格，没有了就标还盖着的雷。
func _next_click(board: MinesweeperBoard) -> int:
	var mine := -1
	for index in range(board.width * board.height):
		if not board.is_active(index):
			continue
		if board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			continue
		if board.has_mine(index):
			if mine < 0:
				mine = index
			continue
		return index
	return mine


func _leave_settlement() -> void:
	for _i in 120:
		await process_frame


func _effects_count() -> int:
	var layer := _game.get("_effects_layer") as Node
	return layer.get_child_count() if layer != null else -1


func _dump(label: String) -> void:
	var board: MinesweeperBoard = _game.get("_board")
	var covered := 0
	if board != null:
		for index in range(board.width * board.height):
			if board.is_active(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
				covered += 1
	print("[dump] %s | dispatching=%s active=%s waiters=%s opening=%s bonus=%s finish=%s resolving=%s chain_flush=%s super_luck=%s clicks=%s covered=%d effects=%d" % [
		label,
		str(_game.get("_item_queue_dispatching")),
		str(_game.get("_active_item_settlements")),
		str(_game.get("_bonus_board_waiters")),
		str(_game.get("_bonus_board_opening")),
		str(_game.get("_bonus_boards_this_round")),
		str(_game.get("_game_finish_started")),
		str(_game.get("_resolving")),
		str(_game.get("_chain_flush_active")),
		str(_game.get("_super_luck_mode_active")),
		str(_game.get("_super_luck_clicks_remaining")),
		covered,
		_effects_count(),
	])
