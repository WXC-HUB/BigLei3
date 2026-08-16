extends SceneTree

const BoardModel := preload("res://scripts/game/minesweeper_board.gd")
const RED_CROSS := preload("res://my_asset/effects/triggered_mine_red_cross.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var mine_index := _find_small_mine(board)
	assert(mine_index >= 0, "Test board has no small mine")
	board.resolve_monster_core(mine_index)
	var defeated: Dictionary = game.get("_defeated_mines")
	defeated[mine_index] = true
	game.set("_defeated_mines", defeated)
	game.call("_refresh_cell", mine_index)
	var cells: Array = game.get("_cells")
	var content := cells[mine_index].get("_content") as TextureRect
	assert(content.visible, "Triggered mine marker is hidden")
	assert(content.texture == RED_CROSS, "Triggered mine still displays the monster corpse")
	assert(content.rotation == 0.0, "Triggered mine red cross inherited corpse rotation")
	assert(content.modulate.is_equal_approx(Color.WHITE), "Triggered mine red cross inherited corpse tint")
	print("Triggered mine display: red cross replacement passed")
	quit()


func _find_small_mine(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.monster_peripheral_count(index) == 0:
			return index
	return -1
