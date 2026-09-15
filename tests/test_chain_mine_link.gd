extends SceneTree
## 连携雷：普通关开局就从雷里挑出一组（默认 2 颗，商店可加）。玩家标中组里任意一颗，
## 同组剩下的每颗雷都会派出一只灰喜鹊分身，从刚标出的那格飞过去把它标出来——是标记，不是引爆。
## 栖枝上那只自己不动，只负责叫一声。
## 连携不再是埋在草地下的道具牌，盘上不该再出现 CHAIN 卡。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		push_error("Chain mine link test timed out")
		quit(2)
	)
	GameSave.save_path = "user://test_chain_mine_link_save.json"
	GameSave.clear()
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# 教学关数直接从 main.gd 读：每加一只鸟它就会 +1，写死在这里的话下次加鸟就假失败。
	var tutorial_levels := int(game.get("TUTORIAL_LEVEL_COUNT"))
	var magpie := game.get_node("MagpieBirdPerch") as BirdPerch
	var sprite := magpie.get_node("Sprite") as TextureRect

	game.call("_start_game")
	assert(not magpie.visible, "Magpie perch showed up before it was unlocked")
	game.set("_magpie_bird_unlocked", true)
	for _level in range(tutorial_levels):
		game.call("_start_game")
	assert(magpie.visible, "Magpie perch stayed hidden after unlocking")

	var board: MinesweeperBoard = game.get("_board")
	assert(board.chain_count == 2, "Normal level did not configure a two-mine chain group")
	assert(board.chain_mine_total() == 2, "Chain group size was wrong before the mines were placed")
	var centre := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(centre)

	# 连携改成了雷的属性：盘上不能再埋灰喜鹊的道具牌。
	assert(
		board.item_count(MinesweeperBoard.ItemType.CHAIN) == 0,
		"Chain is still being dealt as an item card"
	)
	var chain := board.covered_chain_mines()
	assert(chain.size() == 2, "Board did not designate exactly two chain mines")
	for index in chain:
		assert(board.is_chain_mine(index), "covered_chain_mines() returned a cell outside the group")
		assert(board.is_monster_core(index), "A chain mine was not placed on an actual mine")
	assert(board.chain_mine_total() == 2, "Chain group size changed after the mines were placed")

	# 组外的雷不该带连携标志。
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and not chain.has(index):
			assert(not board.is_chain_mine(index), "A mine outside the group was marked as a chain mine")

	var trigger: int = chain[0]
	var partner: int = chain[1]
	var flags_before := board.flag_count()
	var home := sprite.position

	await _wait_until_not_resolving(game)
	game.call("_on_cell_flagged", trigger)
	# 飞过去的这一段：同组每颗雷各有一只分身在半空，栖枝上那只留在原地。
	await create_timer(0.2).timeout
	assert(bool(game.get("_resolving")), "Board was not locked while the chain was resolving")
	var flock := _count_chain_magpies(game, magpie)
	assert(flock == chain.size() - 1, "Expected one magpie per chained mine, found %d for %d" % [flock, chain.size() - 1])
	assert(sprite.position.is_equal_approx(home), "The perch magpie flew off; the flock should be doing that")

	await _wait_until_not_resolving(game)
	assert(
		board.state_at(trigger) == MinesweeperBoard.CellState.FLAGGED,
		"The chain mine the player marked did not stay marked"
	)
	assert(
		board.state_at(partner) == MinesweeperBoard.CellState.FLAGGED,
		"The rest of the chain group was not marked"
	)
	assert(
		board.state_at(partner) != MinesweeperBoard.CellState.REVEALED,
		"The chain detonated its partner instead of marking it"
	)
	assert(board.covered_chain_mines().is_empty(), "Some chain mines were left covered")
	assert(board.flag_count() == flags_before + 2, "Flag count did not pick up both chain mines")

	await create_timer(1.6).timeout
	assert(_count_chain_magpies(game, magpie) == 0, "The chain magpies were not cleaned up after landing")
	assert(sprite.visible and sprite.position.is_equal_approx(home), "Magpie did not stay on its perch")
	assert(magpie.idle_frames.has(sprite.texture), "Magpie did not resume idling")
	assert(sprite.flip_h, "Magpie did not get its perch facing back")
	GameSave.clear()
	print("Chain mines: group designated, one mark brings out the rest, magpie flies the link")
	quit()


func _wait_until_not_resolving(game: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while bool(game.get("_resolving")) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not bool(game.get("_resolving")), "Board stayed locked")


## 连携分身是加在特效层上的独立 TextureRect，靠「用的是灰喜鹊的动作帧」把它们认出来。
func _count_chain_magpies(game: Node, magpie: BirdPerch) -> int:
	var layer := game.get("_effects_layer") as Control
	if layer == null:
		return 0
	var total := 0
	for child in layer.get_children():
		var flyer := child as TextureRect
		if flyer != null and magpie.action_frames.has(flyer.texture):
			total += 1
	return total
