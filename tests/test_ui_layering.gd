extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_game")
	await process_frame
	await process_frame
	await process_frame

	var cells: Array[MineCell] = game.get("_cells")
	var grid := game.get("_grid") as Control
	var item_texture: Texture2D = load("res://assets/sprites/generated/item_lantern.png")
	cells[0].display_revealed(item_texture, MineCell.ContentKind.ITEM)
	var item_icon := cells[0].get("_content") as TextureRect
	var number_label := cells[0].get("_number_label") as Label
	var face_0 := cells[0].get("_base") as TextureRect
	var face_1 := cells[1].get("_base") as TextureRect
	var face_next_row := cells[10].get("_base") as TextureRect
	var tooltip := game.get("_item_tooltip") as Control
	var player_status := game.get("_player_status") as Control
	var blue_bird := game.get_node("BlueBirdPerch") as Control
	var attacker_bird := game.get_node("AttackerBirdPerch") as Control
	var targets: Array[int] = [1]
	game.call("_play_target_lock", 0, targets, Color.WHITE, 0.5)
	var guide := game.find_child("DashedTargetLine", true, false) as Node2D

	if not _require(item_icon.z_index == MineCell.ITEM_CONTENT_Z, "Unexpected item layer"): return
	if not _require(item_icon.z_index < blue_bird.z_index, "Board item icon is above bird UI"): return
	if not _require(number_label.z_index == MineCell.NUMBER_CONTENT_Z, "Unexpected number layer"): return
	if not _require(number_label.z_index < blue_bird.z_index, "Board number is above bird UI"): return
	if not _require(game.find_child("BirdHud", true, false) == null, "Removed nest/time HUD still exists"): return
	if not _require(cells[1].position.x - cells[0].position.x > cells[0].size.x, "Mine cards have no horizontal gap"): return
	if not _require(cells[10].position.y - cells[0].position.y > cells[0].size.y, "Mine cards have no vertical gap"): return
	var board_panel := grid.get_parent() as Control
	var board_stage := board_panel.get_parent() as Control
	var board_center_y := board_panel.position.y + board_panel.size.y * 0.5
	if not _require(is_equal_approx(board_center_y, board_stage.size.y * 0.5 - 32.0), "Mine card grid did not keep its downward-adjusted offset"): return
	if not _require(face_0.texture != face_1.texture, "Horizontal card faces are not evenly alternated"): return
	if not _require(face_0.texture != face_next_row.texture, "Vertical card faces are not evenly alternated"): return
	if not _require(tooltip.z_index > item_icon.z_index, "Tooltip is below board item icon"): return
	if not _require(player_status.visible, "Player health HUD is hidden"): return
	if not _require(player_status.z_index > item_icon.z_index, "Player health HUD is below board item icon"): return
	if not _require(player_status.z_index < blue_bird.z_index, "Player health HUD is above bird UI"): return
	if not _require(guide != null, "Target guide was not created"): return
	if not _require(guide.z_index < blue_bird.z_index, "Target guide crosses the perched bird layer"): return
	if not _require(guide.z_index < attacker_bird.z_index, "Target guide crosses the moving attacker layer"): return
	print("UI layering: test passed")
	quit()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
