extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# 从干净存档起跑：真实存档里有进度的话，第一盘就不会是全局第 1 盘。
	GameSave.save_path = "user://test_roguelite_progression_save.json"
	GameSave.clear()
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var start_screen := game.get("_start_screen") as Control
	start_screen.get_parent().queue_free()
	game.set("_start_screen", null)

	game.call("_start_game")
	await process_frame
	var board: MinesweeperBoard = game.get("_board")
	if not _require(board.width == GuidedTutorial.WIDTH and board.height == GuidedTutorial.HEIGHT, "Tutorial level is not the guided 5x4 board"): return
	if not _require(_has_no_non_bird_items(board), "First tutorial configured non-bird items"): return
	if not _require((game.get("_cells") as Array[MineCell]).size() == GuidedTutorial.WIDTH * GuidedTutorial.HEIGHT, "Tutorial card count is incorrect"): return
	if not _require((game.get_node("BlueBirdPerch") as BirdPerch).visible, "Blue bird was not unlocked by default"): return
	if not _require((game.get_node("BlueBirdPerch/Tree") as TextureRect).is_visible_in_tree(), "Blue-bird branch was hidden by default"): return
	for perch_name in ["RedBirdPerch", "BlackBirdPerch", "AttackerBirdPerch", "EgBirdPerch"]:
		if not _require(not (game.get_node(perch_name) as BirdPerch).visible, "%s was visible before unlocking" % perch_name): return
	var locked_branch := game.get_node("BlackBirdPerch/Tree") as TextureRect
	if not _require(not locked_branch.is_visible_in_tree(), "Night-heron branch was visible before unlocking"): return
	if not _require(GuidedTutorial.layout_matches(board), "Tutorial level does not use the fixed guided layout"): return
	if not _require(board.mine_count == GuidedTutorial.MINES.size(), "Tutorial level does not contain exactly three mines"): return
	for item_type in range(1, MinesweeperBoard.ItemType.size()):
		if not _require(board.item_count(item_type as MinesweeperBoard.ItemType) == 0, "Tutorial level contains an item"): return
	if not _require(_board_is_centered(game), "Tutorial board is not centered onscreen: %s" % _board_geometry(game)): return
	# 走完六步强引导：翻格 → 认数字 → 踩雷 → 看血条 → 右键标雷 → 点数字推理通关。
	var overlay := game.get("_guided_overlay") as GuidedTutorialOverlay
	if not await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 0, 2000, "Guided tutorial did not start"): return
	game.call("_on_cell_mouse_button_changed", 6, MOUSE_BUTTON_LEFT, true)
	if not await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 1, 4000, "Guided tutorial did not advance after the first reveal"): return
	overlay.next_button().pressed.emit()
	game.call("_on_cell_mouse_button_changed", 9, MOUSE_BUTTON_LEFT, true)
	if not await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 3, 6000, "Guided tutorial did not advance after stepping on the mine"): return
	if not _require(int(game.get("_player_hp")) == 2, "Stepping on the tutorial mine did not cost one heart"): return
	overlay.next_button().pressed.emit()
	game.call("_on_cell_mouse_button_changed", 18, MOUSE_BUTTON_RIGHT, true)
	if not await _wait_until(func() -> bool: return int(game.get("_guided_step")) == 5, 4000, "Guided tutorial did not advance after flagging"): return
	game.call("_on_cell_mouse_button_changed", 3, MOUSE_BUTTON_LEFT, true)
	var unlock: NightHeronUnlock = game.get("_night_heron_unlock")
	var unlock_continue := unlock.get_node("Finale/Continue") as Button
	if not await _wait_until(func() -> bool: return unlock.visible and not unlock_continue.disabled, 6000, "Night-heron silhouette reveal did not finish"): return
	if not _require(int((game.get("_victory_banner") as VictoryBanner).get("_presentation_count")) == 1, "First tutorial did not show the victory banner"): return
	if not _require((unlock.get_node("Dimmer") as ColorRect).get_global_rect().encloses(root.get_visible_rect()), "Night-heron unlock plate is not fullscreen"): return
	var night_pattern := (unlock.get_node("IconPattern") as ColorRect).material as ShaderMaterial
	if not _require(night_pattern != null and night_pattern.get_shader_parameter("icon_texture") != null, "Night-heron unlock has no moving icon pattern"): return
	if not _require(not (unlock.get_node("PhotoStage") as Control).visible, "Night-heron photo montage was still visible"): return
	if not _require((unlock.get_node("Finale/Name") as Label).text.replace(" ", "") == "夜鹭", "Night-heron name line is incorrect"): return
	if not _require(not (unlock.get_node("Finale/Tagline") as Label).text.is_empty(), "Night-heron tagline is missing"): return
	if not _require((unlock.get_node("Finale/Effect") as Label).text == "翻开后随机在周围翻开1个格子（必没有雷）", "Night-heron effect line is incorrect"): return
	if not _require(unlock_continue.text == "呱~", "Night-heron continue button text is incorrect"): return
	if not _require((unlock.get_node("HeronCall") as AudioStreamPlayer).stream != null, "Night-heron hover call is missing"): return
	var fish_rain := unlock.get_node("FishRain") as Control
	var fish_count_before := fish_rain.get_child_count()
	(unlock.get_node("Finale/Bird") as TextureRect).mouse_entered.emit()
	await process_frame
	if not _require(fish_rain.get_child_count() == fish_count_before + 1, "Night-heron hover did not drop a fish"): return
	if not _require(not (game.get("_shop_layer") as ShopOverlay).visible, "Tutorial opened the shop"): return
	if not _require((game.get_node("BlackBirdPerch") as BirdPerch).visible, "Night heron was not unlocked"): return
	if not _require(locked_branch.is_visible_in_tree(), "Night-heron branch did not appear with the bird"): return
	for perch_name in ["RedBirdPerch", "AttackerBirdPerch", "EgBirdPerch"]:
		if not _require(not (game.get_node(perch_name) as BirdPerch).visible, "%s appeared without being unlocked" % perch_name): return
	if not _require(int(game.get("_lantern_bonus")) == 1, "Night-heron unlock did not grant one partner"): return
	unlock_continue.pressed.emit()
	if not await _wait_until(func() -> bool: return int(game.get("_run_number")) == 2, 1200, "Tutorial unlock did not continue to level two"): return

	board = game.get("_board")
	if not _require(board.width == 4 and board.height == 4, "Second tutorial is not 4x4"): return
	if not _require(_has_no_non_bird_items(board), "Second tutorial configured non-bird items"): return
	if not _require(board.lantern_count == 1 and board.compass_count == 0, "Unlocked night heron was not carried into level two"): return
	if not _require(board.orbital_strike_count == 0 and board.super_luck_count == 0 and board.medical_kit_count == 0, "Item stock did not start at zero"): return
	if not _require(_board_is_centered(game), "Expanded board is not centered onscreen"): return
	if not _require(not (game.get_node("RedBirdPerch") as BirdPerch).visible, "Redstart was visible before unlocking"): return
	var first_reveal := 5
	game.call("_prepare_tutorial_first_reveal", first_reveal)
	var first_region := board.reveal(first_reveal)
	game.call("_place_tutorial_night_heron_on_reveal_edge", first_region, first_reveal)
	var night_heron_edge: int = game.get("_tutorial_night_heron_edge_index")
	if not _require(first_region.has(night_heron_edge), "Night heron was not placed inside the first revealed region"): return
	if not _require(board.item_at(night_heron_edge) == MinesweeperBoard.ItemType.LANTERN, "First revealed region has no night heron"): return
	var has_covered_neighbor := false
	for neighbor in board.neighbors_of(night_heron_edge):
		if board.state_at(neighbor) == MinesweeperBoard.CellState.COVERED:
			has_covered_neighbor = true
			break
	if not _require(has_covered_neighbor, "Night heron was not placed on the reveal edge"): return
	if not _require(board.item_count(MinesweeperBoard.ItemType.LANTERN) == 1, "Forced night heron duplicated inventory"): return
	board.won = true
	board.game_over = true
	game.call("_finish_game")
	var redstart_unlock: RedstartUnlock = game.get("_redstart_unlock")
	var redstart_continue := redstart_unlock.get_node("Finale/Continue") as Button
	if not await _wait_until(func() -> bool: return redstart_unlock.visible and not redstart_continue.disabled, 6000, "Redstart photo montage or finale did not finish"): return
	if not _require(int((game.get("_victory_banner") as VictoryBanner).get("_presentation_count")) == 2, "Second tutorial did not show the victory banner"): return
	if not _require((redstart_unlock.get_node("Dimmer") as ColorRect).get_global_rect().encloses(root.get_visible_rect()), "Redstart unlock plate is not fullscreen"): return
	var redstart_pattern := (redstart_unlock.get_node("IconPattern") as ColorRect).material as ShaderMaterial
	if not _require(redstart_pattern != null and redstart_pattern.get_shader_parameter("icon_texture") != null, "Redstart unlock has no moving icon pattern"): return
	if not _require(not (redstart_unlock.get_node("PhotoStage") as Control).visible, "Redstart photo montage was still visible"): return
	if not _require((redstart_unlock.get_node("Finale/Name") as Label).text.replace(" ", "") == "红尾水鸲", "Redstart name line is incorrect"): return
	if not _require(not (redstart_unlock.get_node("Finale/Tagline") as Label).text.is_empty(), "Redstart tagline is missing"): return
	if not _require((redstart_unlock.get_node("Finale/Effect") as Label).text == "自动标出1个雷", "Redstart effect line is incorrect"): return
	if not _require(redstart_continue.text == "于 一！", "Redstart continue button text is incorrect"): return
	if not _require((redstart_unlock.get_node("RedstartCall") as AudioStreamPlayer).stream != null, "Redstart hover call is missing"): return
	var red_name := redstart_unlock.get_node("Finale/Name") as Label
	var red_tagline := redstart_unlock.get_node("Finale/Tagline") as Label
	var original_name_center := red_name.position + red_name.size * 0.5
	var original_tagline_center := red_tagline.position + red_tagline.size * 0.5
	var original_name_font_size := red_name.get_theme_font_size("font_size")
	var original_tagline_font_size := red_tagline.get_theme_font_size("font_size")
	(redstart_unlock.get_node("Finale/Bird") as TextureRect).mouse_entered.emit()
	await root.get_tree().create_timer(0.5).timeout
	if not _require((red_name.position + red_name.size * 0.5).distance_to(original_tagline_center) < 2.0, "Redstart name did not animate to the tagline position"): return
	if not _require((red_tagline.position + red_tagline.size * 0.5).distance_to(original_name_center) < 2.0, "Redstart tagline did not animate to the name position"): return
	if not _require(red_name.get_theme_font_size("font_size") == original_tagline_font_size, "Redstart name did not adopt the tagline font size"): return
	if not _require(red_tagline.get_theme_font_size("font_size") == original_name_font_size, "Redstart tagline did not adopt the name font size"): return
	if not _require(not (game.get("_shop_layer") as ShopOverlay).visible, "Second tutorial opened the shop"): return
	if not _require((game.get_node("RedBirdPerch") as BirdPerch).visible, "Redstart was not unlocked"): return
	if not _require((game.get_node("RedBirdPerch/Tree") as TextureRect).is_visible_in_tree(), "Redstart branch did not appear"): return
	if not _require(int(game.get("_compass_bonus")) == 1, "Redstart unlock did not grant one partner"): return
	redstart_continue.pressed.emit()
	if not await _wait_until(func() -> bool: return int(game.get("_run_number")) == 3, 1200, "Second tutorial did not continue to level three"): return
	board = game.get("_board")
	if not _require(board.width == 5 and board.height == 5, "Level three is not 5x5"): return
	if not _require(_has_no_non_bird_items(board), "Third tutorial configured non-bird items"): return
	if not _require(not (game.get_node("AttackerBirdPerch") as BirdPerch).visible, "Woodpecker was visible before unlocking"): return

	board.won = true
	board.game_over = true
	game.call("_finish_game")
	var attacker_unlock: AttackerUnlock = game.get("_attacker_unlock")
	var attacker_continue := attacker_unlock.get_node("Finale/Continue") as Button
	if not await _wait_until(func() -> bool: return attacker_unlock.visible and not attacker_continue.disabled, 6000, "Woodpecker silhouette reveal did not finish"): return
	if not _require(int((game.get("_victory_banner") as VictoryBanner).get("_presentation_count")) == 3, "Third tutorial did not show the victory banner"): return
	if not _require(not (attacker_unlock.get_node("PhotoStage") as Control).visible, "Woodpecker photo montage was still visible"): return
	if not _require((attacker_unlock.get_node("Finale/Name") as Label).text == "啄木鸟", "Woodpecker name line is incorrect"): return
	if not _require((attacker_unlock.get_node("Finale/Effect") as Label).text == "清横线上的格子/清竖线上的格子", "Woodpecker effect line is incorrect"): return
	if not _require((attacker_unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Woodpecker hover sound is missing"): return
	var woodpecker_tagline := attacker_unlock.get_node("Finale/Tagline") as Label
	if not _require(woodpecker_tagline.autowrap_mode != TextServer.AUTOWRAP_OFF, "Woodpecker tagline cannot wrap downward"): return
	var woodpecker_tagline_before := woodpecker_tagline.text
	(attacker_unlock.get_node("Finale/Bird") as TextureRect).mouse_entered.emit()
	await process_frame
	if not _require(woodpecker_tagline.text == woodpecker_tagline_before + "笃笃笃！", "Woodpecker hover did not extend its tagline"): return
	if not _require((game.get_node("AttackerBirdPerch") as BirdPerch).visible, "Woodpecker was not unlocked"): return
	if not _require((game.get_node("AttackerBirdPerch/Tree") as TextureRect).is_visible_in_tree(), "Woodpecker branch did not appear"): return
	if not _require(int(game.get("_orbital_strike_bonus")) == 1, "Woodpecker unlock did not grant one partner"): return
	if not _require(not (game.get("_shop_layer") as ShopOverlay).visible, "Third tutorial opened the shop"): return
	attacker_continue.pressed.emit()
	if not await _wait_until(func() -> bool: return int(game.get("_run_number")) == 4, 1200, "Third tutorial did not continue to level four"): return
	board = game.get("_board")
	if not _require(board.width == 5 and board.height == 5, "Level four is not 5x5"): return
	if not _require(_has_no_non_bird_items(board), "Fourth tutorial configured non-bird items"): return
	if not _require((game.get_node("AttackerBirdPerch") as BirdPerch).visible, "Woodpecker perch disappeared in the level after unlocking"): return

	var woodpecker_first_reveal: PackedInt32Array = board.reveal(24)
	game.call("_place_unlocked_woodpecker_in_first_reveal", woodpecker_first_reveal, 24)
	var woodpecker_demo_index: int = game.get("_woodpecker_demo_index")
	if not _require(woodpecker_demo_index >= 0, "The level after unlocking did not guarantee a woodpecker"): return
	if not _require(board.item_at(woodpecker_demo_index) == MinesweeperBoard.ItemType.ORBITAL_STRIKE, "Guaranteed woodpecker card is missing from the first reveal"): return
	if not _require(board.item_count(MinesweeperBoard.ItemType.ORBITAL_STRIKE) == 1, "Woodpecker guarantee changed the unlocked stock count"): return
	board.won = true
	board.game_over = true
	game.call("_finish_game")
	var kestrel_unlock: KestrelUnlock = game.get("_kestrel_unlock")
	var kestrel_continue := kestrel_unlock.get_node("Finale/Continue") as Button
	if not await _wait_until(func() -> bool: return kestrel_unlock.visible and not kestrel_continue.disabled, 4000, "Kestrel unlock prefab did not appear"): return
	if not _require(int((game.get("_victory_banner") as VictoryBanner).get("_presentation_count")) == 4, "Fourth tutorial did not show the victory banner"): return
	if not _require((kestrel_unlock.get_node("Finale/Name") as Label).text.replace(" ", "") == "红隼", "Kestrel name line is incorrect"): return
	if not _require((kestrel_unlock.get_node("Finale/Effect") as Label).text == "1步内无敌，踩中雷不掉血", "Kestrel effect line is incorrect"): return
	if not _require(not (kestrel_unlock.get_node("Finale/Tagline") as Label).text.is_empty(), "Kestrel tagline is missing"): return
	if not _require((kestrel_unlock.get_node("BirdCall") as AudioStreamPlayer).stream != null, "Kestrel hover sound is missing"): return
	var kestrel_flight_layer := kestrel_unlock.get_node("FlightLayer") as Control
	(kestrel_unlock.get_node("Finale/Bird") as TextureRect).mouse_entered.emit()
	await process_frame
	if not _require(kestrel_flight_layer.get_child_count() >= 1 and int(kestrel_unlock.get("_flyover_count")) == 1, "Kestrel hover did not trigger the level flyover"): return
	if not _require((kestrel_flight_layer.get_child(0) as TextureRect).size == Vector2(720.0, 720.0), "Kestrel hover used the small flyover instead of the large activation flyover"): return
	await root.get_tree().create_timer(0.12).timeout
	var found_gu_particle := false
	for trail_child in kestrel_flight_layer.get_children():
		if trail_child is Label and (trail_child as Label).text == "咕":
			found_gu_particle = true
			break
	if not _require(found_gu_particle, "Kestrel flyover did not emit gu text particles"): return
	var gu_particle_count := 0
	var found_changing_color := false
	for trail_child in kestrel_flight_layer.get_children():
		if trail_child is Label and (trail_child as Label).text == "咕":
			gu_particle_count += 1
			var gu_label := trail_child as Label
			if gu_label.get_theme_color("font_color") != gu_label.get_meta(&"gu_start_color", Color.TRANSPARENT):
				found_changing_color = true
	if not _require(gu_particle_count >= 3, "Kestrel gu trail is not dense enough"): return
	if not _require(found_changing_color, "Kestrel gu particles do not change color over time"): return
	if not _require((game.get_node("EgBirdPerch") as BirdPerch).visible, "Kestrel was not unlocked"): return
	if not _require(int(game.get("_super_luck_bonus")) == 1, "Kestrel unlock did not grant one partner"): return
	if not _require(not (game.get("_shop_layer") as ShopOverlay).visible, "Fourth tutorial opened the shop"): return
	kestrel_continue.pressed.emit()
	if not await _wait_until(func() -> bool: return int(game.get("_run_number")) == 5, 1200, "Fourth tutorial did not continue to level five"): return
	board = game.get("_board")
	if not _require(board.width == 6 and board.height == 6, "Level five is not 6x6"): return
	if not _require(board.xray_count == 1 and board.chain_count == 0 and board.enlarge_count == 0 and board.detect_count == 0, "Normal levels did not start with one xray and no other tactical items"): return
	if not _require(board.super_luck_count == 1, "The level after unlocking has no kestrel card"): return

	var kestrel_first_reveal: PackedInt32Array = board.reveal(21)
	game.call("_place_unlocked_kestrel_in_first_reveal", kestrel_first_reveal, 21)
	var kestrel_demo_index: int = game.get("_kestrel_demo_index")
	if not _require(kestrel_demo_index >= 0 and board.item_at(kestrel_demo_index) == MinesweeperBoard.ItemType.SUPER_LUCK, "The level after unlocking did not guarantee a kestrel"): return
	if not _require(board.item_count(MinesweeperBoard.ItemType.SUPER_LUCK) == 1, "Kestrel guarantee changed the unlocked stock count"): return
	var flagged := 0
	for index in range(board.width * board.height):
		if board.is_monster_core(index) and board.state_at(index) == MinesweeperBoard.CellState.COVERED:
			if board.mark_mine(index):
				flagged += 1
			if flagged == 2:
				break
	if not _require(flagged == 2, "Could not prepare two flagged mines"): return
	board.won = true
	board.game_over = true
	game.set("_night_master_fish_count", 2)
	game.call("_finish_game")
	var bill: LevelBill = game.get("_level_bill")
	var bill_continue := bill.get_node("Center/Panel/Margin/Stack/Continue") as Button
	if not await _wait_until(func() -> bool: return bill.visible and not bill_continue.disabled, 4000, "Level bill did not appear after victory banner"): return
	if not _require(int(game.get("_gold")) == 7, "Mine, eaten-fish and level-clear rewards were not all added"): return
	var fish_row := bill.get_node("Center/Panel/Margin/Stack/Lines/NightMasterFish") as HBoxContainer
	var fish_qty := fish_row.get_node("Qty") as Label
	var fish_amount := fish_row.get_node("Amount") as Label
	if not _require(fish_qty.text.contains("2") and fish_amount.text == "+2G", "Bill has no separate eaten-fish entry"): return
	var clear_row := bill.get_node("Center/Panel/Margin/Stack/Lines/ClearBonus") as HBoxContainer
	if not _require((clear_row.get_node("Amount") as Label).text == "+3G", "Bill has no level-clear reward entry"): return
	bill_continue.pressed.emit()
	var shop: ShopOverlay = game.get("_shop_layer")
	if not await _wait_until(func() -> bool: return shop.visible, 1200, "Shop did not appear after the level bill"): return
	var shop_gold := shop.get_node("ShopGold") as Label
	if not _require(shop_gold.text.contains("7G"), "Shop did not display current gold"): return
	game.set("_gold", 100)
	shop.update_gold(100, 5)
	for offer in range(10):
		game.call("_choose_shop_offer", offer)
	if not _require(int(game.get("_player_max_hp")) == 4, "Maximum-health purchase was not applied"): return
	if not _require(int(game.get("_player_hp")) == 4, "Maximum-health purchase did not heal the new heart"): return
	(shop.get_node("ContinueButton") as Button).pressed.emit()
	if not await _wait_until(func() -> bool: return int(game.get("_run_number")) == 6, 1200, "Shop continue did not start the next level"): return
	board = game.get("_board")
	if not _require(board.width == 6 and board.height == 6, "Second normal level did not remain 6x6"): return
	if not _require(board.lantern_count == 2 and board.compass_count == 2, "Night-heron or redstart purchase was not applied"): return
	if not _require(board.orbital_strike_count == 2 and board.super_luck_count == 2, "Woodpecker or kestrel unlock/shop purchase was not applied"): return
	if not _require(board.medical_kit_count == 1 and board.detect_count == 0, "Normal-level medical kit or removed detect item stock is incorrect"): return
	if not _require(int(game.get("_healing_power_bonus")) == 1 and int(game.get("_super_luck_click_bonus")) == 1, "Healing or kestrel-strength upgrade was not applied"): return
	if not _require(int(game.call("_super_luck_clicks_for_items", 2)) == 4, "Kestrel invincibility upgrade did not scale every triggered kestrel"): return
	if not _require(int(game.get("_lantern_target_bonus")) == 1 and int(game.get("_compass_mark_bonus")) == 1, "Night-heron or redstart strength upgrade was not applied"): return
	if not _require(bool(game.get("_orbital_cross_unlocked")), "Woodpecker cross upgrade was not applied"): return

	game.set("_game_finish_started", false)
	game.set("_player_hp", 0)
	board.won = false
	board.game_over = true
	game.call("_finish_game")
	var game_over: GameOverOverlay = game.get("_game_over_overlay")
	if not await _wait_until(func() -> bool: return game_over.visible, 1400, "Game-over prefab did not appear"): return
	(game_over.get_node("HitArea") as Button).pressed.emit()
	await process_frame
	if not _require(game.get("_start_screen") != null, "Game over did not return to the main screen"): return
	if not _require(int(game.get("_run_number")) == 0, "Run state was not reset on return"): return

	print("Roguelite progression: test passed")
	quit()


func _wait_until(predicate: Callable, timeout_msec: int, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_msec
	while not predicate.call():
		if Time.get_ticks_msec() >= deadline:
			return _require(false, message)
		await create_timer(0.05).timeout
	return true


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false


func _has_no_non_bird_items(board: MinesweeperBoard) -> bool:
	return board.xray_count == 0 and board.chain_count == 0 and board.enlarge_count == 0 and board.detect_count == 0


func _board_is_centered(game: Node) -> bool:
	var panel := game.get("_board_panel") as Control
	# 棋盘锚在视口中心，再按 main.gd 的常量往上提、往下挪（BOARD_VERTICAL_LIFT / SHIFT）。
	var vertical_offset := float(game.get("BOARD_VERTICAL_SHIFT")) - float(game.get("BOARD_VERTICAL_LIFT"))
	var viewport_center := root.get_visible_rect().get_center() + Vector2(0, vertical_offset)
	var panel_center := panel.get_global_rect().get_center()
	return panel_center.distance_to(viewport_center) < 2.0 and root.get_visible_rect().encloses(panel.get_global_rect())


func _board_geometry(game: Node) -> String:
	var panel := game.get("_board_panel") as Control
	return "viewport=%s panel=%s" % [root.get_visible_rect(), panel.get_global_rect()]
