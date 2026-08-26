extends SceneTree
## FEAT-001 的整局验收：在同一个进程里跑两份完整的 main.tscn，一份当房主一份当客
## 人，走真实 WebSocket 连起来，然后核对验收标准里最要命的几条——
## 棋盘逐格一致、标雷互伤、PVE 伤害不外溢、清盘冻结、大全商店。

const ConfigScript := preload("res://scripts/net/duel_config.gd")
const OfferCatalog := preload("res://scripts/ui/shop_overlay.gd")

const TIMEOUT_MSEC := 15000

var _host_game: Node
var _guest_game: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_host_game = packed.instantiate()
	_guest_game = packed.instantiate()
	root.add_child(_host_game)
	root.add_child(_guest_game)
	await process_frame
	await process_frame

	_host_game.call("_on_duel_host_requested")
	_guest_game.call("_on_duel_join_requested")
	assert(await _wait(func() -> bool:
		return _host_game.get("_board") != null and _guest_game.get("_board") != null
	))

	await _check_boards_are_identical()
	await _check_mark_damages_opponent()
	await _check_pve_damage_stays_local()
	await _check_clearing_freezes_and_opens_full_shop()
	await _check_single_player_path_untouched()

	print("DuelIntegration: all tests passed")
	quit()


## 验收 2：两端棋盘逐格一致，且开局时同一片区域已被翻开。
func _check_boards_are_identical() -> void:
	var host_board = _host_game.get("_board")
	var guest_board = _guest_game.get("_board")
	assert(host_board.width == guest_board.width)
	assert(host_board.mine_count == guest_board.mine_count)
	var revealed := 0
	for index in range(host_board.width * host_board.height):
		assert(host_board.has_mine(index) == guest_board.has_mine(index))
		assert(host_board.adjacent_mines(index) == guest_board.adjacent_mines(index))
		assert(host_board.item_at(index) == guest_board.item_at(index))
		assert(host_board.state_at(index) == guest_board.state_at(index))
		if host_board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			revealed += 1
	# 开局格必须真的翻开了，否则「起跑线一致」只是嘴上说说。
	assert(revealed > 0)
	# 对战跳过整段教程，起手血量金币走 DuelConfig。
	assert(int(_host_game.get("_player_hp")) == ConfigScript.START_HP)
	assert(int(_guest_game.get("_gold")) == ConfigScript.START_GOLD)


## 验收 3 + 4：标 1 个雷 → 对手掉 1 血、自己 +1 金。
func _check_mark_damages_opponent() -> void:
	assert(await _wait_idle(_host_game))
	var mine := _first_covered_mine(_host_game.get("_board"))
	assert(mine >= 0)
	var guest_hp_before := int(_guest_game.get("_player_hp"))
	var host_gold_before := int(_host_game.get("_gold"))
	_host_game.call("_on_cell_flagged", mine)
	assert(await _wait(func() -> bool:
		return int(_guest_game.get("_player_hp")) == guest_hp_before - ConfigScript.MARK_DAMAGE
	))
	assert(int(_host_game.get("_gold")) == host_gold_before + ConfigScript.MARK_GOLD)
	# 标雷不该反伤自己。
	assert(int(_host_game.get("_player_hp")) == ConfigScript.START_HP)


## 验收 5：错旗按单机规则扣自己的血，且一点都不该漏到对面去。
func _check_pve_damage_stays_local() -> void:
	assert(await _wait_idle(_host_game))
	var host_board = _host_game.get("_board")
	var safe := _first_covered_safe_cell(host_board)
	assert(safe >= 0)
	var host_hp_before := int(_host_game.get("_player_hp"))
	var guest_hp_before := int(_guest_game.get("_player_hp"))
	var host_gold_before := int(_host_game.get("_gold"))
	_host_game.call("_on_cell_flagged", safe)
	assert(await _wait(func() -> bool:
		return int(_host_game.get("_player_hp")) < host_hp_before
	))
	# 关键：错旗既不伤对手，也不给自己发钱。
	assert(int(_guest_game.get("_player_hp")) == guest_hp_before)
	assert(int(_host_game.get("_gold")) == host_gold_before)


## 验收 6 + 7：房主清盘 → 两端冻结 → 中场休息弹出大全商店（13 项全在、无刷新按钮）。
func _check_clearing_freezes_and_opens_full_shop() -> void:
	var host_board = _host_game.get("_board")
	while true:
		var mine := _first_covered_mine(host_board)
		if mine < 0:
			break
		_host_game.call("_on_cell_flagged", mine)
		assert(await _wait_idle(_host_game))
	assert(host_board.won)
	assert(await _wait(func() -> bool: return bool(_guest_game.get("_duel_frozen"))))
	assert(bool(_host_game.get("_duel_frozen")))

	var host_shop = _host_game.get("_shop_layer")
	assert(await _wait(func() -> bool: return host_shop.visible))
	# 大全商店：13 项全部可见，且不给刷新。
	var visible_offers := 0
	for offer_index in range(OfferCatalog.OFFER_NAMES.size()):
		if host_shop.get_node("Center/ShopCard/ItemGrid/ItemSlot_%d" % offer_index).visible:
			visible_offers += 1
	assert(visible_offers == OfferCatalog.OFFER_NAMES.size())
	assert(not host_shop.refresh_button.visible)
	# 落后方剩下的雷不再结算：冻结之后对手的血不能再掉。
	var guest_hp := int(_guest_game.get("_player_hp"))
	await _wait(func() -> bool: return false, 2000)
	assert(int(_guest_game.get("_player_hp")) == guest_hp)


## 验收 13：单机那条路一点没被动到 —— 第 1 关仍是 2×1 的教程盘，商店仍是三选一。
func _check_single_player_path_untouched() -> void:
	var solo: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	await process_frame
	solo.call("_start_game")
	await process_frame
	var board = solo.get("_board")
	assert(board.width == 2 and board.height == 1)
	assert(not bool(solo.call("_is_duel")))
	var solo_shop = solo.get("_shop_layer")
	solo_shop.call("present", "", "", 20, 5)
	await process_frame
	var offered := 0
	for offer_index in range(OfferCatalog.OFFER_NAMES.size()):
		if solo_shop.get_node("Center/ShopCard/ItemGrid/ItemSlot_%d" % offer_index).visible:
			offered += 1
	assert(offered == 3)
	assert(solo_shop.refresh_button.visible)
	solo.queue_free()


## 等棋盘交还给玩家。开局格的自动翻开会先把 `_resolving` 锁上，这期间任何点击/插旗
## 都会被入口直接挡掉——不等它，测试打出去的操作全是空的。
func _wait_idle(game: Node) -> bool:
	return await _wait(func() -> bool: return not bool(game.get("_resolving")))


func _first_covered_mine(board) -> int:
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			return index
	return -1


func _first_covered_safe_cell(board) -> int:
	for index in range(board.width * board.height):
		if not board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			return index
	return -1


## 按真实时间等条件成立。不能只数帧：冻结演出用的是 `create_timer`，走的是墙钟。
func _wait(condition: Callable, timeout_msec: int = TIMEOUT_MSEC) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if condition.call():
			return true
	return false
