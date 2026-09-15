extends SceneTree
## 奖励盘：一盘的雷被提前清空、结算队列却还压着牌时，自动展开一张同尺寸的空盘让
## 剩下的牌继续结算。盯四件事——什么时候该开、开出来的盘长什么样、队列能不能原样
## 跑完并收场、以及它绝不能反过来咬玩家。
## 跑法：godot --headless --path . --script tests/test_bonus_board.gd

const COMPASS := MinesweeperBoard.ItemType.COMPASS
const LANTERN := MinesweeperBoard.ItemType.LANTERN


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Bonus board test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_bonus_board.json"
	GameSave.clear()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await _start_normal_level(game)

	_check_guards(game)
	await _check_opens_and_replants(game)
	await _check_queue_drains_and_finishes(game)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("Bonus board: 触发条件、盘面构成、牌照原样续结、免伤与收场全部通过")
	quit()


## 跳过教学段，开一盘正式关。
func _start_normal_level(game: Node) -> void:
	var tutorial_count: int = (game.get_script() as GDScript).get_script_constant_map()["TUTORIAL_LEVEL_COUNT"]
	game.set("_run_number", tutorial_count)
	game.call("_start_game")
	for _i in 8:
		await process_frame
	assert(int(game.get("_run_number")) == tutorial_count + 1, "没能开到正式关")


## 把这一盘的雷全标出来：`_board.won` 随之成立，剩下的牌就无处可落了。
func _flag_every_mine(game: Node) -> int:
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var flagged := 0
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) != MinesweeperBoard.CellState.FLAGGED:
			board.toggle_flag(index)
			flagged += 1
	game.call("_update_round_completion")
	assert(board.won, "把雷全标出来之后本盘仍然没算赢")
	return flagged


## 在安全格上翻出几张牌，返回它们的格号——这就是待结算的队列。
func _plant_cards(game: Node, kinds: Array) -> Array[int]:
	var board: MinesweeperBoard = game.get("_board")
	var planted: Array[int] = []
	for index in range(board.width * board.height):
		if planted.size() >= kinds.size():
			break
		if not board.is_active(index) or board.is_monster_core(index):
			continue
		if board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			continue
		board.reveal_exact_forced_safe(index)
		assert(board.force_item_at(index, kinds[planted.size()], false), "没能在第 %d 格放下牌" % index)
		planted.append(index)
	assert(planted.size() == kinds.size(), "盘上放不下这么多张牌")
	return planted


## 什么时候不该开奖励盘：雷没清完、对战、自定义包、教学段、以及开够了上限之后。
func _check_guards(game: Node) -> void:
	var limit: int = (game.get_script() as GDScript).get_script_constant_map()["BONUS_BOARD_LIMIT"]
	var tutorial_count: int = (game.get_script() as GDScript).get_script_constant_map()["TUTORIAL_LEVEL_COUNT"]
	assert(not bool(game.call("_should_open_bonus_board")), "雷还没清完就要开奖励盘")
	_flag_every_mine(game)
	assert(bool(game.call("_should_open_bonus_board")), "雷清完了却不开奖励盘")

	game.set("_custom_level", {"name": "x"})
	assert(not bool(game.call("_should_open_bonus_board")), "自定义包里不该开奖励盘")
	game.set("_custom_level", {})

	game.set("_run_number", tutorial_count)
	assert(not bool(game.call("_should_open_bonus_board")), "教学段不该开奖励盘")
	game.set("_run_number", tutorial_count + 1)

	game.set("_bonus_boards_this_round", limit)
	assert(not bool(game.call("_should_open_bonus_board")), "开够上限之后还要再开")
	game.set("_bonus_boards_this_round", 0)


## 开出来的盘：同尺寸同掩码、有雷、**一张新牌都不发**（否则队列会自己养自己），
## 队列里那几张原样种回去并翻开，旧盘的战果记在账上，而且盘上翻出雷不掉血。
func _check_opens_and_replants(game: Node) -> void:
	var previous: MinesweeperBoard = game.get("_board")
	var banked := int(game.call("_correctly_flagged_mines"))
	assert(banked > 0, "前置：旧盘应当已经标出了雷")
	var queue := _plant_cards(game, [COMPASS, LANTERN])
	var kinds := [previous.item_at(queue[0]), previous.item_at(queue[1])]
	var queued_items := {queue[0]: true, queue[1]: true}

	var tint: Color = (game.get_script() as GDScript).get_script_constant_map()["BONUS_BOARD_TINT"]
	game.call("_open_bonus_board", queue, queued_items)
	var opened: bool = await _wait_until(func() -> bool: return game.get("_board") != previous, 2400)
	assert(opened, "奖励盘迟迟没有展开")
	assert(bool(game.get("_bonus_board_active")), "奖励盘没有标成正在展着")
	assert(int(game.get("_bonus_boards_this_round")) == 1, "本盘开过的奖励盘数不对")

	var bonus: MinesweeperBoard = game.get("_board")
	assert(bonus.width == previous.width and bonus.height == previous.height, "奖励盘和原盘不等大")
	assert(bonus.mine_count == previous.mine_count, "奖励盘的雷数和原盘不一致")
	for index in range(bonus.width * bonus.height):
		assert(bonus.is_active(index) == previous.is_active(index), "第 %d 格的可玩性和原盘不一致" % index)
	assert(bonus.mines_placed, "奖励盘没有立刻布雷，牌落下来就没雷可标了")
	assert(not bonus.won, "奖励盘一展开就被判成打完了")
	# 这是整套机制不塌掉的关键：奖励盘自己不发牌，队列只会越结越短。
	assert(bonus.hidden_item_count() == 0, "奖励盘上还埋着新牌，队列会自己养自己")

	# 那两张牌：原样种回奖励盘、已经翻开、类型没变。去重表跟着改写，所以它的键
	# 就是牌在新盘上的落点。
	assert(queued_items.size() == 2, "去重表里的牌数不对：%d（原格 %s，类型 %s，表 %s）" % [
		queued_items.size(), str(queue), str(kinds), str(queued_items.keys())
	])
	var replanted := []
	for slot in queued_items.keys():
		var kind: MinesweeperBoard.ItemType = bonus.item_at(int(slot))
		assert(kind != MinesweeperBoard.ItemType.NONE, "第 %s 格没有种回牌" % str(slot))
		assert(
			bonus.state_at(int(slot)) == MinesweeperBoard.CellState.REVEALED,
			"第 %s 格的牌在奖励盘上没有翻开" % str(slot)
		)
		assert(not bonus.is_monster_core(int(slot)), "牌被种到了雷上")
		replanted.append(kind)
	for kind in kinds:
		assert(replanted.has(kind), "有一张牌没能跟着换到奖励盘上")

	assert(int(game.get("_banked_flagged_mines")) == banked, "旧盘标出的雷没有记进账里")
	assert(
		int(game.call("_correctly_flagged_mines")) >= banked,
		"换盘之后旧盘的战果被抹掉了"
	)
	assert(bool(game.call("_is_invincible")), "奖励盘上居然还会掉血")

	# 演出：整盘变色 + 光环与标题亮起来。变色是补间，等它落到位再量。
	var grid := game.get("_grid") as Control
	var tinted: bool = await _wait_until(
		func() -> bool: return grid.modulate.is_equal_approx(tint), 2400
	)
	assert(tinted, "奖励盘没有变色，棋盘仍是 %s" % str(grid.modulate))
	var aura := game.get("_bonus_aura") as BonusBoardAura
	assert(aura != null and aura.is_showing(), "奖励盘没有光环")
	assert(
		(aura.title_box().get_node("BonusTitleLabel") as Label).text.replace(" ", "") == "奖励盘",
		"光环上没有写出「奖励盘」"
	)


## 端到端：重开一盘，把雷标完、留着牌，然后走真正的入口 `_resolve_item_queue`。
## 奖励盘该自己开出来，牌该在新盘上结算掉，走完这一盘按赢收场。
func _check_queue_drains_and_finishes(game: Node) -> void:
	await _start_normal_level(game)
	assert(int(game.get("_bonus_boards_this_round")) == 0, "新一盘没有把奖励盘计数清零")
	_flag_every_mine(game)
	var original: MinesweeperBoard = game.get("_board")
	var queue := _plant_cards(game, [COMPASS, LANTERN])
	var queued_items := {queue[0]: true, queue[1]: true}
	assert(not bool(game.get("_game_finish_started")), "前置：这一盘还不该收场")

	game.call("_resolve_item_queue", queue, queued_items)
	var finished: bool = await _wait_until(
		func() -> bool: return bool(game.get("_game_finish_started")), 6000
	)
	assert(finished, "队列结算完之后这一盘没有收场")
	assert(int(game.get("_bonus_boards_this_round")) == 1, "没有正好开出一张奖励盘")
	var bonus: MinesweeperBoard = game.get("_board")
	assert(bonus != original, "盘没有换成奖励盘")
	assert(bool(game.call("_round_is_won")), "开过奖励盘的这一盘没有按赢结算")
	# 牌确实是在新盘上结算掉的。队列若没跟着改写，这些牌会指向新盘上根本不存在的
	# 东西，一张也消耗不掉。
	var used := 0
	for index in range(bonus.width * bonus.height):
		if bonus.item_at(index) != MinesweeperBoard.ItemType.NONE and bonus.is_item_used(index):
			used += 1
	assert(used == 2, "奖励盘上被结算掉的牌是 %d 张，应为 2 张" % used)
	# 牌不是「悄悄生效」：红尾水鸲得真飞到奖励盘的雷上把它标出来。这一条盯的正是
	# 玩家报的「不播鸟动画、直接显示雷」——效果空转的话一颗都标不出来。
	var marked := 0
	for index in range(bonus.width * bonus.height):
		if bonus.is_monster_core(index) and bonus.state_at(index) == MinesweeperBoard.CellState.FLAGGED:
			marked += 1
	assert(marked > 0, "奖励盘上一颗雷都没被标出来，牌是空转的")
	assert(int(game.get("_last_compass_flyover_count")) > 0, "红尾水鸲没有在奖励盘上飞过")


func _wait_until(predicate: Callable, cap_frames: int) -> bool:
	for _i in cap_frames:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()
