extends SceneTree

const CACHE_EFFECT_DESCRIPTIONS := {
	2: "1步内无敌，踩中雷不掉血",
	4: "清横线上的格子/清竖线上的格子",
	6: "翻开后随机在周围翻开1个格子（必没有雷）",
	8: "自动标出1个雷",
	10: "随机1个格子出现内容（不翻开）3s后消失",
	11: "道具那格与下一颗标出的雷之间，格子全被翻开（可转弯）",
	12: "无敌，下一步选中的格子周围会被一起翻开",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for offer_index in CACHE_EFFECT_DESCRIPTIONS:
		assert(
			ShopOverlay.OFFER_DESCRIPTIONS[offer_index] == CACHE_EFFECT_DESCRIPTIONS[offer_index],
			"Cache offer %d did not describe its item effect" % offer_index
		)
	var packed_scene: PackedScene = load("res://scenes/shop_overlay.tscn")
	var shop: ShopOverlay = packed_scene.instantiate()
	root.add_child(shop)
	await process_frame
	await process_frame

	shop.present("", "", 100, 5)
	await create_timer(0.4).timeout
	var stage := shop.get_node("Center") as Control
	if not _require(shop.visible, "Shop did not become visible"):
		return
	if not _require(stage.scale.is_equal_approx(Vector2.ONE), "Shop entrance did not settle"):
		return
	if not _require(is_zero_approx(stage.rotation), "Shop entrance rotation did not settle"):
		return
	if not _require((shop.get_node("ShopGold") as Label).text.contains("100G"), "Shop gold display is not current"):
		return
	if not _require(not shop.has_node("DebugGoldButton"), "Shop still contains its debug gold button"):
		return
	if not _require(not shop.has_node("ItemTip"), "Shop still contains the floating item tips panel"):
		return
	var greeting := shop.get_node("Center/ShopCard/Greeting") as Label

	var items: Array[Sprite2D] = shop.get("_item_nodes")
	var buttons: Array[Button] = shop.get("_buy_buttons")
	if not _require(items.size() == 13 and buttons.size() == 13, "Complete thirteen-offer shop pool was not built"):
		return
	var current_offers := shop.current_offers()
	if not _require(current_offers.size() == 3, "Shop did not draw exactly three offers"):
		return
	var unique_offers := {}
	for offer_index in current_offers:
		unique_offers[offer_index] = true
	if not _require(unique_offers.size() == 3, "Shop draw contained duplicate offers"):
		return
	for offer_index in current_offers:
		buttons[offer_index].mouse_entered.emit()
		await create_timer(0.18).timeout
		if not _require(greeting.text == ShopOverlay.OFFER_DESCRIPTIONS[offer_index], "Shop description did not use the Greeting label"):
			return
		var base_scale: Vector2 = items[offer_index].get_meta(&"ui_button_base_scale", Vector2.ONE)
		if not _require(items[offer_index].scale.x > base_scale.x * 1.03, "Shop offer %d did not enlarge on hover" % offer_index):
			return
		if not _require(absf(items[offer_index].rotation) > deg_to_rad(1.0), "Shop offer %d did not rotate on hover" % offer_index):
			return
		buttons[offer_index].mouse_exited.emit()
		await create_timer(0.18).timeout
		if not _require(greeting.text == ShopOverlay.GREETING_TEXT, "Greeting text was not restored after hover"):
			return

	shop.call("_on_item_mouse_entered", 5)
	if not _require(greeting.get_theme_font_size("font_size") < ShopOverlay.GREETING_MAX_FONT_SIZE, "Long Greeting description did not shrink its font"):
		return
	shop.call("_on_item_mouse_exited")

	var selected_offers: Array[int] = []
	shop.offer_selected.connect(func(offer: int) -> void: selected_offers.append(offer))
	buttons[current_offers[0]].pressed.emit()
	buttons[current_offers[1]].pressed.emit()
	await process_frame
	if not _require(shop.visible, "Shop closed after purchasing an offer"):
		return
	if not _require(selected_offers == [current_offers[0], current_offers[1]], "Shop did not allow purchases from the current draw"):
		return
	shop.mark_offer_sold_out(current_offers[0])
	shop.update_gold(95, 5)
	if not _require(buttons[current_offers[0]].disabled, "Purchased offer was not sold out"):
		return
	var refreshed := [false]
	shop.refresh_requested.connect(func() -> void:
		refreshed[0] = true
		shop.refresh_offers(90, 5)
	)
	(shop.get_node("RefreshButton") as Button).pressed.emit()
	await process_frame
	if not _require(refreshed[0], "Shop refresh signal was not emitted"):
		return
	if not _require(shop.current_offers().size() == 3, "Refresh did not draw three offers"):
		return
	if not _require(not (shop.get("_sold_out_offers") as Dictionary).has(current_offers[0]), "Refresh did not restock repeatable offers"):
		return

	var continued := [false]
	shop.continue_pressed.connect(func() -> void: continued[0] = true)
	(shop.get_node("ContinueButton") as Button).pressed.emit()
	await create_timer(0.3).timeout
	if not _require(not shop.visible, "Shop exit did not finish after continue"):
		return
	if not _require(continued[0], "Shop continue signal was not emitted"):
		return

	print("Shop motion: test passed")
	quit()


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
