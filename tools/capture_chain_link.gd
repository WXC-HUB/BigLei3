extends SceneTree

const ANCHOR_OUTPUT_PATH := "res://artifacts/chain_anchor_review.png"
const LINK_OUTPUT_PATH := "res://artifacts/chain_link_review.png"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	# The title page lives on its own CanvasLayer above everything. Drop it so the
	# board is what the screenshot shows.
	var screen := game.get("_start_screen") as Control
	if screen != null:
		game.set("_start_screen", null)
		screen.get_parent().queue_free()
	game.set("_chain_bonus", 1)
	game.set("_run_number", 6)
	game.call("_start_game")
	await process_frame

	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var chain_index := -1
	for index in range(board.width * board.height):
		if board.item_at(index) == MinesweeperBoard.ItemType.CHAIN:
			chain_index = index
			break
	if chain_index < 0:
		push_error("No chain item on the board")
		quit(1)
		return
	board.reveal_exact_forced_safe(chain_index)
	game.call("_refresh_cell", chain_index)
	var queue: Array[int] = []
	var queued: Dictionary = {}
	game.call("_resolve_queued_item", chain_index, MinesweeperBoard.ItemType.CHAIN, queue, queued)
	await create_timer(0.8).timeout
	await process_frame
	_save(ANCHOR_OUTPUT_PATH, "chain anchor")

	var partner := _find_turning_partner(game, board, chain_index)
	if partner < 0:
		push_error("No mine with a clear turning path")
		quit(1)
		return
	game.call("_on_cell_flagged", partner)
	await create_timer(2.2).timeout
	await process_frame
	_save(LINK_OUTPUT_PATH, "chain link")
	quit()


func _find_turning_partner(game: Node, board: MinesweeperBoard, anchor: int) -> int:
	var fallback := -1
	for index in range(board.width * board.height):
		if not board.is_monster_core(index) or board.state_at(index) != MinesweeperBoard.CellState.COVERED:
			continue
		var path: Array[int] = game.call("_chain_path_targets", anchor, index)
		if path.size() < 3:
			continue
		var clear := true
		for target in path:
			if board.is_monster_core(target):
				clear = false
				break
		if not clear:
			continue
		if anchor / board.width != index / board.width and anchor % board.width != index % board.width:
			return index
		if fallback < 0:
			fallback = index
	return fallback


func _save(path: String, label: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s screenshot: %s" % [label, error_string(error)])
		return
	print("Saved %s screenshot to %s" % [label, ProjectSettings.globalize_path(path)])
