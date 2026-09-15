extends SceneTree
## 商店经济：同一件商品重复买会涨价（×1.2 向上取整），红隼买满 3 只、长尾山雀买满 2 张
## 之后彻底下架——既不能再买，刷新也抽不到。

const MAX_HEALTH := 0
const SUPER_LUCK_CACHE := 2
const ORBITAL_STRIKE_CACHE := 4
const ENLARGE_CACHE := 12


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# 自己一格存档，并且每次从空档起跑：涨价次数是存进档里的，留着上一轮的记录会让
	# 「基础价 5G」这条断言在第二次运行时就挂掉。
	GameSave.save_path = "user://test_shop_economy.json"
	GameSave.clear()
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Shop economy test timed out")
		quit(2)
	)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var shop := game.get("_shop_layer") as ShopOverlay
	_refill(game, shop, 999)

	if not _require(int(game.call("_offer_price", MAX_HEALTH)) == 5, "基础价不是 5G"): return
	game.call("_choose_shop_offer", MAX_HEALTH)
	if not _require(int(game.call("_offer_price", MAX_HEALTH)) == 6, "第二次购买没有涨到 6G"): return
	game.call("_choose_shop_offer", MAX_HEALTH)
	if not _require(int(game.call("_offer_price", MAX_HEALTH)) == 8, "第三次购买没有涨到 8G"): return
	if not _require(
		int(game.call("_offer_price", ORBITAL_STRIKE_CACHE)) == 5, "涨价串到了别的商品上"
	): return
	if not _require(
		shop.price_for(MAX_HEALTH) == 8 and shop.price_for(ORBITAL_STRIKE_CACHE) == 5,
		"商店没有按件显示涨价后的单价"
	): return

	# 买贵了就买不起：金币刚好卡在两件商品之间时，便宜的那件还得能买。
	var forced: Array[int] = [MAX_HEALTH, ORBITAL_STRIKE_CACHE, SUPER_LUCK_CACHE]
	shop.set("_current_offers", forced)
	shop.update_gold(6, 5)
	var buttons: Array[Button] = shop.get("_buy_buttons")
	if not _require(buttons[MAX_HEALTH].disabled, "8G 的商品在只有 6G 时仍然可买"): return
	if not _require(
		not buttons[ORBITAL_STRIKE_CACHE].disabled, "同一排里 5G 的商品被贵货连坐禁用了"
	): return

	# 红隼：连买到 3 只封顶。
	_refill(game, shop, 999)
	game.set("_super_luck_bonus", 0)
	game.call("_sync_shop_offer_limits")
	for index in range(3):
		game.call("_choose_shop_offer", SUPER_LUCK_CACHE)
	if not _require(int(game.get("_super_luck_bonus")) == 3, "红隼没有买到 3 只"): return
	if not _require(
		(shop.get("_exhausted_offers") as Dictionary).has(SUPER_LUCK_CACHE), "红隼买满后没有下架"
	): return
	game.call("_choose_shop_offer", SUPER_LUCK_CACHE)
	if not _require(int(game.get("_super_luck_bonus")) == 3, "红隼买满之后还能继续买"): return

	# 长尾山雀：每关自带 1 张，所以只能再买 1 张。
	game.set("_enlarge_bonus", 0)
	game.call("_sync_shop_offer_limits")
	if not _require(
		not (shop.get("_exhausted_offers") as Dictionary).has(ENLARGE_CACHE), "长尾山雀一开始就下架了"
	): return
	game.call("_choose_shop_offer", ENLARGE_CACHE)
	if not _require(int(game.get("_enlarge_bonus")) == 1, "长尾山雀第一次没买上"): return
	if not _require(
		(shop.get("_exhausted_offers") as Dictionary).has(ENLARGE_CACHE), "长尾山雀买满后没有下架"
	): return
	game.call("_choose_shop_offer", ENLARGE_CACHE)
	if not _require(int(game.get("_enlarge_bonus")) == 1, "长尾山雀买满之后还能继续买"): return

	# 下架的两件永远抽不到。
	for round_index in range(30):
		game.set("_gold", 999)
		game.call("_on_shop_refresh_requested")
		var drawn := shop.current_offers()
		if not _require(
			not drawn.has(SUPER_LUCK_CACHE) and not drawn.has(ENLARGE_CACHE),
			"刷新把买满的商品又摆回货架了"
		): return
		if not _require(drawn.size() == 3, "刷新没有摆满三件"): return

	# 新的一局要把涨价和上限一起清零。
	game.call("_reset_run_state")
	if not _require(int(game.call("_offer_price", MAX_HEALTH)) == 5, "新一局没有把价格打回基础价"): return
	if not _require(
		(shop.get("_exhausted_offers") as Dictionary).is_empty(), "新一局没有把下架的商品放回来"
	): return
	print("Shop economy: repeat-purchase pricing and per-item caps passed")
	quit()


func _refill(game: Node, shop: ShopOverlay, gold: int) -> void:
	game.set("_gold", gold)
	shop.set_offer_prices(game.call("_offer_price_table"))
	shop.present("", "", gold, 5)


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false
