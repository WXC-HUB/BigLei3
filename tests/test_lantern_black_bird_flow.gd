extends SceneTree

const FX_1 := preload("res://my_asset/birds/black_fly_fx_only_1.png")
const FX_2 := preload("res://my_asset/birds/black_fly_fx_only_2.png")
const FISH_TEXTURES := [
	preload("res://my_asset/effects/fish/fish_silver.png"),
	preload("res://my_asset/effects/fish/fish_orange.png"),
	preload("res://my_asset/effects/fish/fish_teal.png"),
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(10.0).timeout.connect(func() -> void:
		push_error("Lantern multi-fish flow timed out")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_run_number", 4)
	game.set("_night_heron_unlocked", true)
	game.set("_lantern_bonus", 1)
	game.set("_lantern_target_bonus", 2)
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var target := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(target)
	var before := _target_states(board, target)
	var empty_queue: Array[int] = []
	game.call("_resolve_lantern", target, empty_queue, {})
	await process_frame
	assert(int(game.get("_last_dashed_line_target_count")) > 0, "Lantern lock did not appear as the bird left its perch")
	var cells: Array = game.get("_cells")
	var lock_indices: Array[int] = game.get("_last_target_lock_indices")
	assert(not lock_indices.is_empty(), "Lantern did not retain its locked target list")
	var target_overlay := cells[lock_indices[0]].get("_preview_overlay") as Panel
	assert(target_overlay.visible, "Lantern border did not flash as the bird left its perch")
	var saw_cruise := false
	var saw_dive := false
	var saw_fish := false
	var deadline := Time.get_ticks_msec() + 6000
	while _target_states(board, target) == before and Time.get_ticks_msec() < deadline:
		saw_cruise = saw_cruise or _has_flyer(game, FX_1)
		saw_dive = saw_dive or _has_flyer(game, FX_2)
		saw_fish = saw_fish or _has_any_fish(game)
		await process_frame
	assert(saw_cruise, "First black bird FX did not cross the screen")
	assert(saw_dive, "Second black bird FX did not switch into the dive")
	assert(saw_fish, "Black bird did not drop fish over its targets")
	assert(int(game.get("_last_lantern_fish_count")) == 3, "Night heron did not drop one fish per target")
	assert(int(game.get("_last_dashed_line_target_count")) > 0, "Lantern did not draw dashed lines to surrounding targets")
	assert(_target_states(board, target) != before, "Lantern did not resolve after the target flyover")
	assert(_changed_target_count(before, _target_states(board, target)) == 3, "Night heron did not affect all three fish targets")
	await create_timer(1.4).timeout
	var black_bird := game.get_node("BlackBirdPerch") as BirdPerch
	assert((black_bird.get_node("Sprite") as TextureRect).visible, "Black bird did not return to its perch")
	print("Lantern black bird flow: cruise FX, dive FX, resolve, and return passed")
	quit()


func _has_flyer(game: Node, texture: Texture2D) -> bool:
	var effects_layer := game.get("_effects_layer") as Control
	for child in effects_layer.get_children():
		if child is TextureRect and (child as TextureRect).texture == texture:
			return true
	return false


func _has_any_fish(game: Node) -> bool:
	var effects_layer := game.get("_effects_layer") as Control
	for child in effects_layer.get_children():
		if child is TextureRect and FISH_TEXTURES.has((child as TextureRect).texture):
			return true
	return false


func _target_states(board: MinesweeperBoard, target: int) -> Array[int]:
	var indices := board.neighbors_of(target)
	indices.append(target)
	indices.sort()
	var states: Array[int] = []
	for index in indices:
		states.append(int(board.state_at(index)))
	return states


func _changed_target_count(before: Array[int], after: Array[int]) -> int:
	var changed := 0
	for index in range(mini(before.size(), after.size())):
		if before[index] != after[index]:
			changed += 1
	return changed
