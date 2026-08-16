extends SceneTree
## 覆盖 vfx/cell_fx.gd 的三类爆发特效：能生成、会发射、有上限、能自毁，
## 以及“正确标记 → 地格炸碎”在真实对局流程里的落地状态。

const CELL_FX := preload("res://vfx/cell_fx.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Each check returns true only if it ran to the end; an assert that trips
	# aborts its function and leaves null here, so failures cannot slip past.
	assert(await _test_bursts_spawn_and_expire())
	assert(await _test_burst_budget())
	assert(await _test_correct_flag_shatters_cell())
	assert(await _test_settlement_keeps_crater())
	assert(await _test_last_mine_still_costs_health())
	assert(await _test_wrong_mark_costs_health())
	print("Cell FX: burst, budget and flag-shatter checks passed")
	await process_frame
	quit()


func _test_bursts_spawn_and_expire() -> bool:
	var layer := _make_layer()
	CELL_FX.play_mine_alert(layer, Vector2(300, 200))
	CELL_FX.play_mine_explosion(layer, Vector2(300, 200))
	CELL_FX.play_flag_seal(layer, Vector2(420, 260))
	CELL_FX.play_flag_shatter(layer, Vector2(420, 260), 86.0)
	CELL_FX.play_impact_hit(layer, Vector2(120, 110))
	await process_frame
	assert(_burst_count() == 5, "Expected one root node per burst")

	var emitting := 0
	for root_node in get_nodes_in_group(CELL_FX.BURST_GROUP):
		for child in root_node.get_children():
			if child is CPUParticles2D:
				assert(child.emitting, "A particle system was left switched off")
				emitting += 1
	assert(emitting > 0, "No particle systems were created")

	await create_timer(2.2).timeout
	assert(_burst_count() == 0, "Bursts must free themselves")
	layer.queue_free()
	return true


func _test_burst_budget() -> bool:
	var layer := _make_layer()
	for _index in range(40):
		CELL_FX.play_mine_explosion(layer, Vector2(300, 200))
	await process_frame
	assert(
		_burst_count() <= CELL_FX.HARD_BURST_LIMIT,
		"Concurrent bursts exceeded the hard cap"
	)
	await create_timer(2.2).timeout
	assert(_burst_count() == 0)
	layer.queue_free()
	return true


func _test_correct_flag_shatters_cell() -> bool:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# Early levels hold so few mines that marking one would win the run and
	# reveal the board out from under the effect being tested.
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.reveal(center)

	var mine_index := -1
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			mine_index = index
			break
	assert(mine_index >= 0)

	var cells: Array = game.get("_cells")
	var cell: MineCell = cells[mine_index]
	game.call("_on_cell_flagged", mine_index)
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.FLAGGED)
	assert(not cell.is_flag_sealed(), "The card must survive until the flag pose lands")

	await create_timer(0.8).timeout
	assert(cell.is_flag_sealed(), "A confirmed mine's card should have shattered away")

	# A refresh must not rebuild the card that was just blown off the board.
	game.call("_refresh_cell", mine_index)
	assert(cell.is_flag_sealed(), "Refreshing a sealed cell restored its card")

	# Unmarking puts the board back the way it was.
	game.call("_on_cell_flagged", mine_index)
	assert(board.state_at(mine_index) == MinesweeperBoard.CellState.COVERED)
	assert(not cell.is_flag_sealed(), "Unmarking should restore the card")
	game.queue_free()
	await process_frame
	return true


## 结算横幅会把每个格子的内容摊开；已经炸碎的格子不能借这一步长回来。
func _test_settlement_keeps_crater() -> bool:
	var game := await _fresh_game()
	var board: MinesweeperBoard = game.get("_board")
	board.reveal(int(board.height / 2) * board.width + int(board.width / 2))

	var mine_index := _first_covered_mine(board)
	assert(mine_index >= 0)
	var cells: Array = game.get("_cells")
	var cell: MineCell = cells[mine_index]
	game.call("_on_cell_flagged", mine_index)
	await create_timer(0.8).timeout
	assert(cell.is_flag_sealed())

	game.call("_finish_game")
	await process_frame
	assert(cell.is_flag_sealed(), "Settlement rebuilt a card the mark burst destroyed")
	game.queue_free()
	await process_frame
	return true


## 翻出最后一颗雷同样要扣血，胜利结算不能抢在伤害之前。
func _test_last_mine_still_costs_health() -> bool:
	var game := await _fresh_game()
	var board: MinesweeperBoard = game.get("_board")
	var cell_count := board.width * board.height

	# Clear the board down to a single untouched mine: every safe cell open and
	# every other mine marked.
	var last_mine := _first_covered_mine(board)
	if last_mine < 0:
		board.reveal(int(board.height / 2) * board.width + int(board.width / 2))
		last_mine = _first_covered_mine(board)
	assert(last_mine >= 0)
	for index in range(cell_count):
		if index == last_mine:
			continue
		if board.has_mine(index):
			board.mark_mine(index)
		elif board.state_at(index) != MinesweeperBoard.CellState.REVEALED:
			board.reveal_exact_forced_safe(index)
		game.call("_refresh_cell", index)
	assert(not board.won, "Board was already finished before the last mine")

	var hp_before: int = game.get("_player_hp")
	game.call("_on_cell_revealed", last_mine)
	var deadline := Time.get_ticks_msec() + 12000
	while not bool(game.get("_game_finish_started")):
		assert(Time.get_ticks_msec() < deadline, "Victory never settled")
		await create_timer(0.05).timeout
	assert(
		int(game.get("_player_hp")) == hp_before - 1,
		"Triggering the last mine must still cost a heart"
	)
	assert(board.won, "Clearing the last mine should win the board")
	game.queue_free()
	await process_frame
	return true


## 标错雷和踩雷一样要扣血；无敌状态下只挡伤害，不挡揭示。
func _test_wrong_mark_costs_health() -> bool:
	var game := await _fresh_game()
	var board: MinesweeperBoard = game.get("_board")
	board.reveal(int(board.height / 2) * board.width + int(board.width / 2))

	var safe_index := -1
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and not board.has_mine(index):
			safe_index = index
			break
	assert(safe_index >= 0)

	var hp_before: int = game.get("_player_hp")
	game.call("_on_cell_flagged", safe_index)
	await create_timer(0.6).timeout
	assert(board.state_at(safe_index) == MinesweeperBoard.CellState.REVEALED)
	assert(
		int(game.get("_player_hp")) == hp_before - 1,
		"A wrong mark should cost a heart"
	)

	# The shield has to cover wrong marks too, exactly like it covers mines.
	var shielded_index := -1
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and not board.has_mine(index):
			shielded_index = index
			break
	assert(shielded_index >= 0)
	game.set("_invincible_until_msec", Time.get_ticks_msec() + 30000)
	var shielded_hp: int = game.get("_player_hp")
	game.call("_on_cell_flagged", shielded_index)
	await create_timer(0.6).timeout
	assert(board.state_at(shielded_index) == MinesweeperBoard.CellState.REVEALED)
	assert(
		int(game.get("_player_hp")) == shielded_hp,
		"Invincibility should block wrong-mark damage"
	)
	game.queue_free()
	await process_frame
	return true


func _fresh_game() -> Node:
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# Early levels hold so few mines that the run ends before the effects run.
	game.call("_start_game")
	game.call("_start_game")
	game.call("_start_game")
	await process_frame
	return game


func _first_covered_mine(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.state_at(index) == MinesweeperBoard.CellState.COVERED and board.has_mine(index):
			return index
	return -1


func _make_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	return layer


func _burst_count() -> int:
	return get_node_count_in_group(CELL_FX.BURST_GROUP)
