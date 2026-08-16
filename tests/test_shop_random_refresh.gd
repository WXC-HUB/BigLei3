extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(6.0).timeout.connect(func() -> void:
		push_error("Random shop refresh test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var shop := game.get("_shop_layer") as ShopOverlay
	game.set("_gold", 20)
	shop.present("", "", 20, 5)
	await process_frame
	var first_draw := shop.current_offers()
	assert(first_draw.size() == 3, "Shop did not initially draw three offers")
	var repeatable_offer := first_draw[0]
	if repeatable_offer == 5:
		repeatable_offer = first_draw[1]
	game.call("_choose_shop_offer", repeatable_offer)
	assert(int(game.get("_gold")) == 15, "Purchase did not charge its price")
	assert((shop.get("_sold_out_offers") as Dictionary).has(repeatable_offer), "Purchased offer was not sold out")

	game.call("_on_shop_refresh_requested")
	assert(int(game.get("_gold")) == 10, "Refresh did not charge its price")
	assert(shop.current_offers().size() == 3, "Refresh did not retain three offers")
	assert((shop.get("_sold_out_offers") as Dictionary).is_empty(), "Refresh did not replenish sold-out stock")
	var visible_slots := 0
	var slots: Array[Control] = shop.get("_item_slots")
	for slot in slots:
		if slot.visible:
			visible_slots += 1
	assert(visible_slots == 3, "Shop displayed more than three offer slots")

	game.call("_choose_shop_offer", 5)
	assert(bool(game.get("_orbital_cross_unlocked")), "Permanent offer purchase did not apply")
	game.call("_on_shop_refresh_requested")
	assert(not shop.current_offers().has(5), "Refresh restocked a permanent one-time offer")
	print("Random shop draw, paid refresh, and restock passed")
	quit()
