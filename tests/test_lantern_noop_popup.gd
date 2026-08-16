extends SceneTree

const FX_1 := preload("res://my_asset/birds/black_fly_fx_only_1.png")
const FX_2 := preload("res://my_asset/birds/black_fly_fx_only_2.png")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(6.0).timeout.connect(func() -> void:
		push_error("Lantern no-op popup test did not reach quit")
		quit(2)
	)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	game.set("_lantern_bonus", 2)
	game.call("_start_game")
	game.call("_start_game")
	var board: MinesweeperBoard = game.get("_board")
	var center := int(board.height / 2) * board.width + int(board.width / 2)
	board.ensure_mines_placed(center)
	var lantern_index := _find_lantern(board)
	assert(lantern_index >= 0, "Test board has no lantern")
	_open_or_correctly_mark_area(board, lantern_index)
	var before := _target_states(board, lantern_index)
	var empty_queue: Array[int] = []
	game.call("_resolve_lantern", lantern_index, empty_queue, {})
	await create_timer(0.68).timeout
	assert(bool(game.get("_last_lantern_noop")), "Lantern did not detect its no-op area")
	assert(int(game.get("_night_master_fish_count")) == 1, "Eaten fish was not recorded for the level bill")
	assert(bool(game.get("_unlocked_achievements").has("night_master_fish")), "Eaten fish did not unlock its achievement")
	var achievements := game.get("_achievements_screen") as AchievementsScreen
	assert(achievements.status_label("night_master_fish").text == "已获得", "Achievement page did not refresh")
	var fish_guide := game.get("_night_master_fish_guide_banner") as WrongFlagGuideBanner
	assert(bool(game.get("_night_master_fish_guide_shown")), "Night-master guide was not recorded")
	assert(fish_guide.banner.visible, "Night-master guide banner did not appear")
	assert(not fish_guide.icon.visible, "Night-master guide banner should not show an icon")
	assert(fish_guide.message.text == "夜鹭在没有可揭示格子时，会自己把鱼吃掉", "Night-master guide copy is wrong")
	game.call("_show_night_master_fish_guide_once")
	assert(fish_guide.presentation_count == 1, "Night-master guide repeated after its first trigger")
	var effects_layer := game.get("_effects_layer") as Control
	assert(effects_layer.has_node("NightMasterFishPopup"), "Independent night master popup did not appear")
	assert(not _has_black_flight(effects_layer), "No-op lantern continued into the flight animation")
	var black_sprite := game.get_node("BlackBirdPerch/Sprite") as TextureRect
	assert(not black_sprite.visible, "Night heron returned before the popup finished")
	await create_timer(1.45).timeout
	assert(not effects_layer.has_node("NightMasterFishPopup"), "Night master popup did not dismiss")
	assert(black_sprite.visible, "Night heron did not return directly to its perch")
	assert(_target_states(board, lantern_index) == before, "No-op lantern changed board state")
	print("Lantern no-op: departure, independent popup, skipped flight, and return passed")
	quit()


func _find_lantern(board: MinesweeperBoard) -> int:
	for index in range(board.width * board.height):
		if board.item_at(index) == MinesweeperBoard.ItemType.LANTERN:
			return index
	return -1


func _open_or_correctly_mark_area(board: MinesweeperBoard, center: int) -> void:
	var targets := board.neighbors_of(center)
	targets.append(center)
	for target in targets:
		if board.is_monster_core(target):
			board.mark_mine(target)
		else:
			board.reveal_exact_forced_safe(target)


func _target_states(board: MinesweeperBoard, center: int) -> Array[int]:
	var targets := board.neighbors_of(center)
	targets.append(center)
	targets.sort()
	var result: Array[int] = []
	for target in targets:
		result.append(int(board.state_at(target)))
	return result


func _has_black_flight(effects_layer: Control) -> bool:
	for child in effects_layer.get_children():
		if child is TextureRect and [FX_1, FX_2].has((child as TextureRect).texture):
			return true
	return false
