extends SceneTree
## 无尽关的槽位制商店（鸟窝）：起手 4 / 6、空格直接住进去、窝满要点一格替换、
## 取消不扣钱、扩建三次封顶、鸟窝是数值位的唯一真相、存档往返、别的关卡看不到这套 UI。
## 跑法：godot --headless --path . --script tests/test_endless_slot_shop.gd

const ENDLESS := StageTable.ENDLESS_STAGE_ID
## 与 main.gd 的 ShopOffer 同序号。
const MAX_HEALTH := 0
const KESTREL := 2
const ORBITAL := 4
const LANTERN := 6
const COMPASS := 8
const CROW := 10
const MAGPIE := 11
const TIT := 12


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		push_error("Endless slot shop test timed out")
		quit(2)
	)
	var original_path := GameSave.save_path
	GameSave.save_path = "user://test_endless_slot_shop.json"
	GameSave.clear()

	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	_check_offer_tables(game)
	var shop := game.get("_shop_layer") as ShopOverlay

	await _check_seeded_nest(game, shop)
	await _check_buy_into_free_slot(game, shop)
	await _check_replacement(game, shop)
	await _check_expansion(game, shop)
	_check_save_round_trip(game)
	_check_other_stages_have_no_nest(game, shop)
	# 这一条会把内存里的进度整份读掉，所以放在最后。
	_check_v4_save_rescue(game)

	(game.get_node("BGM") as AudioStreamPlayer).stop()
	game.queue_free()
	await process_frame
	GameSave.clear()
	GameSave.save_path = original_path
	print("Endless slot shop: 起手鸟窝、空格入住、满窝替换、取消不扣钱、扩建封顶、存档往返、非无尽关无鸟窝全部通过")
	quit()


func _cleared_six() -> Array:
	var out: Array = []
	for stage in StageTable.STAGES:
		if not bool(stage.get("endless", false)):
			out.append(String(stage["id"]))
	return out


## 「有短名」和「占鸟窝格子」必须是同一批商品：枚举改了顺序而两张表没跟上，
## 鸟窝要么印错名字，要么把强化类商品也塞进格子里。
func _check_offer_tables(game: Node) -> void:
	assert(
		ShopOverlay.OFFER_SHORT_NAMES.size() == ShopOverlay.OFFER_NAMES.size(),
		"槽位短名表与商品名表长度不一致"
	)
	var bonus_map: Dictionary = (game.get_script() as GDScript).get_script_constant_map()["SLOT_OFFER_BONUS"]
	for offer in ShopOverlay.OFFER_SHORT_NAMES.size():
		var short_name := String(ShopOverlay.OFFER_SHORT_NAMES[offer])
		assert(
			(short_name != "") == bonus_map.has(offer),
			"第 %d 件商品（%s）的短名与「占不占格子」对不上" % [
				offer, String(ShopOverlay.OFFER_NAMES[offer])
			]
		)


## 进无尽关：起手只有 `ENDLESS_STARTER_BIRDS` 那几只住进 6 格窝，数值位与窝里的数一致。
func _check_seeded_nest(game: Node, shop: ShopOverlay) -> void:
	var starters: Array = (game.get_script() as GDScript).get_script_constant_map()["ENDLESS_STARTER_BIRDS"]
	game.set("_cleared_stages", _cleared_six())
	game.call("_enter_stage", ENDLESS, false)
	await process_frame
	assert(String(game.get("_stage_id")) == ENDLESS, "没进到无尽关")
	assert(bool(game.call("_is_slot_shop")), "无尽关的商店不是鸟窝制")
	var slots: Array = game.get("_endless_slots")
	assert(slots.size() == 6, "起手鸟窝不是 6 格：%d" % slots.size())
	assert(
		_filled(slots) == starters.size(),
		"起手应有 %d 只鸟住着，实际 %d" % [starters.size(), _filled(slots)]
	)
	for offer in starters:
		assert(slots.has(int(offer)), "起手鸟窝里缺了商品 %d" % int(offer))
	# 没住进窝的那几只，数值位必须跟着是 0——窝是唯一真相。
	assert(int(game.get("_orbital_strike_bonus")) == 0, "没住进窝的啄木鸟还留在数值位上")
	assert(int(game.get("_super_luck_bonus")) == 0, "没住进窝的红隼还留在数值位上")
	_assert_bonuses_match_slots(game, "起手")

	game.set("_gold", 999)
	game.call("_refresh_gold_display")
	game.call("_show_shop")
	await process_frame
	var panel := shop.nest_panel()
	assert(panel != null and panel.visible, "无尽关开店没有显示鸟窝面板")
	# 面板按鸟归类：起手四只鸟 = 四张牌，空格不单独列，总数写在左边。
	assert(
		shop.slot_chips().size() == starters.size(),
		"鸟牌数应是 %d 种，实际 %d" % [starters.size(), shop.slot_chips().size()]
	)
	var title := shop.get_node("Center/ShopCard/NestPanel/NestRow/NestTitleLabel") as Label
	assert(title.text == "总数 %d / 6" % starters.size(), "总数读数不对：%s" % title.text)
	var first_chip := shop.slot_chips()[0]
	assert(
		(first_chip.get_node("ChipStack/ChipIcon") as TextureRect).texture != null,
		"鸟牌上没有画出鸟"
	)
	assert(
		(first_chip.get_node("ChipStack/ChipNameLabel") as Label).text == "夜鹭×1",
		"第 1 张牌印的不是「夜鹭×1」：%s" % (first_chip.get_node("ChipStack/ChipNameLabel") as Label).text
	)
	assert(shop.get_node("Center/ShopCard/NestPanel/NestRow/NestDivider") != null, "总数与鸟牌之间缺分割块")


## 窝里还有空格：买鸟直接住进去，不弹替换。
func _check_buy_into_free_slot(game: Node, shop: ShopOverlay) -> void:
	var starters: Array = (game.get_script() as GDScript).get_script_constant_map()["ENDLESS_STARTER_BIRDS"]
	game.call("_choose_shop_offer", CROW)
	await process_frame
	var slots: Array = game.get("_endless_slots")
	assert(
		_filled(slots) == starters.size() + 1,
		"买下小嘴乌鸦后窝里应有 %d 只，实际 %d" % [starters.size() + 1, _filled(slots)]
	)
	assert(int(game.get("_xray_bonus")) == 1, "小嘴乌鸦没有记到数值位上")
	assert(int(game.get("_pending_slot_offer")) == -1, "还有空格却挂起了替换")
	assert(not shop.is_replacing(), "还有空格却进了替换态")
	_assert_bonuses_match_slots(game, "买进空格后")

	# 起手只有两只，得再买三只才填满六格；每只都不同，好让面板上正好六张牌。
	for offer in [ORBITAL, KESTREL, MAGPIE]:
		game.call("_choose_shop_offer", offer)
		await process_frame
	slots = game.get("_endless_slots")
	assert(_filled(slots) == 6, "买满之后窝应该满了，实际 %d" % _filled(slots))
	assert(int(game.call("_free_slot_index")) < 0, "窝满了还报得出空格")
	var title := shop.get_node("Center/ShopCard/NestPanel/NestRow/NestTitleLabel") as Label
	assert(title.text == "总数 6 / 6", "满窝的总数读数不对：%s" % title.text)
	# 同一种鸟归成一张牌：六只鸟六种，各 ×1。
	assert(shop.slot_chips().size() == 6, "六种鸟应是六张牌，实际 %d" % shop.slot_chips().size())


## 窝满了再买：先挂起不扣钱；取消 → 一分没花；点格子 → 扣钱并换人。
func _check_replacement(game: Node, shop: ShopOverlay) -> void:
	# 把货架钉死：没被抽中的商品本来就是灰的，拿它验「替换期间禁用」什么也证明不了。
	shop.set("_current_offers", [MAX_HEALTH, CROW, MAGPIE] as Array[int])
	shop.update_gold(int(game.get("_gold")), 5)
	var buy_buttons: Array[Button] = shop.get("_buy_buttons")
	assert(not buy_buttons[MAX_HEALTH].disabled, "前置：货架上的商品应当可买")
	var gold_before := int(game.get("_gold"))
	var price := int(game.call("_offer_price", TIT))
	game.call("_choose_shop_offer", TIT)
	await process_frame
	assert(int(game.get("_pending_slot_offer")) == TIT, "窝满买鸟没有挂起替换")
	assert(shop.is_replacing() and shop.replacing_offer() == TIT, "商店没有进入替换态")
	assert(int(game.get("_gold")) == gold_before, "替换还没落定就扣钱了")
	assert(int(game.get("_enlarge_bonus")) == 0, "替换还没落定就把鸟塞进来了")
	assert(buy_buttons[MAX_HEALTH].disabled, "替换期间别的商品还能买")
	assert((shop.get_node("ContinueButton") as Button).disabled, "替换期间还能按继续前进")
	var modal := shop.replace_modal()
	assert(modal != null and modal.visible, "换鸟弹窗没有弹出来")
	var modal_title := shop.get_node("ReplaceModal/ReplaceCard/ReplaceColumn/ReplaceTitleLabel") as Label
	assert(modal_title.text.contains("换掉哪一只"), "弹窗标题不对：%s" % modal_title.text)
	assert(
		(shop.get_node("ReplaceModal/ReplaceCard/ReplaceColumn/ReplaceIncomingRow/ReplaceIncomingLabel") as Label)
			.text.contains("长尾山雀"),
		"弹窗没写清楚要请谁住进来"
	)
	assert(not (shop.get_node("Center/ShopCard/NestPanel") as Control).visible, "弹窗开着时底下那条带子应收起")

	# 取消：一分钱不花，窝一个不动。
	(shop.get_node("Center/ShopCard/NestPanel/NestRow/NestCancelButton") as Button).pressed.emit()
	await process_frame
	assert(int(game.get("_pending_slot_offer")) == -1, "取消后替换还挂着")
	assert(not shop.is_replacing(), "取消后商店还在替换态")
	assert(int(game.get("_gold")) == gold_before, "取消替换居然扣了钱")
	assert(int(game.get("_enlarge_bonus")) == 0, "取消替换居然还是买了")
	assert(not buy_buttons[MAX_HEALTH].disabled, "取消后别的商品没有解禁")

	# 再来一次，这回点第 1 格：夜鹭搬走、长尾山雀住进来。
	game.call("_choose_shop_offer", TIT)
	await process_frame
	assert(shop.is_replacing(), "第二次窝满买鸟没有进替换态")
	shop.slot_chips()[0].pressed.emit()
	await process_frame
	var slots: Array = game.get("_endless_slots")
	assert(int(slots[0]) == TIT, "第 1 格没有换成长尾山雀")
	assert(int(game.get("_gold")) == gold_before - price, "替换后扣的钱不对")
	assert(int(game.get("_enlarge_bonus")) == 1, "换进来的长尾山雀没有记到数值位")
	assert(int(game.get("_lantern_bonus")) == 0, "被换走的夜鹭还留在数值位上")
	assert(_filled(slots) == 6, "替换之后窝应该还是满的")
	assert(not shop.is_replacing(), "换完了还停在替换态")
	assert(int(game.get("_pending_slot_offer")) == -1, "换完了挂起没清掉")
	_assert_bonuses_match_slots(game, "替换后")


## 扩建：一次 +2 格，最多三次，扩到头按钮收起。
func _check_expansion(game: Node, shop: ShopOverlay) -> void:
	game.set("_gold", 999)
	game.call("_refresh_gold_display")
	game.call("_sync_shop_slots")
	await process_frame
	var expand := shop.expand_button()
	assert(expand != null and expand.visible, "还能扩建时扩建按钮却没出现")
	var expected := 6
	for step in main_expansion_costs().size():
		var cost := int(main_expansion_costs()[step])
		var gold_before := int(game.get("_gold"))
		assert(expand.text.contains("%dG" % cost), "扩建按钮没写出这一次的价钱：%s" % expand.text)
		expand.pressed.emit()
		await process_frame
		expected += 3
		var slots: Array = game.get("_endless_slots")
		assert(slots.size() == expected, "第 %d 次扩建后不是 %d 格：%d" % [step + 1, expected, slots.size()])
		assert(int(game.get("_gold")) == gold_before - cost, "第 %d 次扩建扣的钱不对" % (step + 1))
		assert(
			(shop.get_node("Center/ShopCard/NestPanel/NestRow/NestTitleLabel") as Label).text.ends_with(
				"/ %d" % expected
			),
			"扩建后总数读数没跟上：%s" % (shop.get_node("Center/ShopCard/NestPanel/NestRow/NestTitleLabel") as Label).text
		)
	assert(expected == 15, "三次扩建后应是 15 格")
	assert(not expand.visible, "扩到头了扩建按钮还留在面板上")
	var gold_before_extra := int(game.get("_gold"))
	game.call("_on_shop_expand_slots")
	await process_frame
	assert((game.get("_endless_slots") as Array).size() == 15, "扩到头还能继续扩")
	assert(int(game.get("_gold")) == gold_before_extra, "扩到头的那一次还扣了钱")

	# 扩出来的空格照样能直接住进去。
	game.call("_choose_shop_offer", LANTERN)
	await process_frame
	assert(not shop.is_replacing(), "窝里有空格却要求替换")
	assert(
		int(game.get("_lantern_bonus")) == 1,
		"夜鹭没住进扩出来的空格：数值位 %d，窝 %s" % [
			int(game.get("_lantern_bonus")), str(game.get("_endless_slots"))
		]
	)
	_assert_bonuses_match_slots(game, "扩建后")


## 鸟窝要随存档往返，续局才接得上。
func _check_save_round_trip(game: Node) -> void:
	game.call("_save_progress")
	var data := GameSave.load_data()
	assert(data.has("endless_slots"), "存档里没有鸟窝")
	assert(
		int(data.get("endless_slot_expansions", 0)) == 3,
		"扩建次数没落盘：%d" % int(data.get("endless_slot_expansions", 0))
	)
	var saved: Array = data["endless_slots"]
	var live: Array = game.get("_endless_slots")
	assert(saved.size() == live.size(), "落盘的格子数与内存里的不一致")
	for index in saved.size():
		assert(int(saved[index]) == int(live[index]), "第 %d 格落盘的内容不对" % index)


## 别的关卡完全看不到这套 UI，数值位也不再被鸟窝接管。
func _check_other_stages_have_no_nest(game: Node, shop: ShopOverlay) -> void:
	game.set("_stage_id", "grass_2")
	assert(not bool(game.call("_is_slot_shop")), "普通关卡被当成了鸟窝制商店")
	game.call("_sync_shop_slots")
	assert(not shop.nest_panel().visible, "普通关卡还显示着鸟窝面板")
	var before := int(game.get("_lantern_bonus"))
	game.call("_sync_bonuses_from_slots")
	assert(int(game.get("_lantern_bonus")) == before, "普通关卡的数值位被鸟窝改写了")


## v4 老档（没有鸟窝那两项）续无尽局：照七个数值位把鸟摆回窝里，窝不够大就补扩建。
## 少了这一步，续局时 `_sync_bonuses_from_slots()` 会照着空窝把数值位清零，白丢一窝鸟。
func _check_v4_save_rescue(game: Node) -> void:
	var file := FileAccess.open(GameSave.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 4,
		"data": {
			"current_level": 12,
			"tutorial_completed": true,
			"achievements": [],
			"cleared_stages": _cleared_six(),
			"resume_stage_id": ENDLESS,
			"stage_round": 12,
			# 当年的真相：3 只红隼 + 2 只夜鹭 + 1 只啄木鸟 + 1 只灰喜鹊 = 7 只，
			# 起手 6 格装不下，必须自动补一次扩建。
			"super_luck_bonus": 3,
			"lantern_bonus": 2,
			"orbital_strike_bonus": 1,
			"chain_bonus": 1,
		},
	}))
	file.close()
	assert(bool(game.call("_load_saved_progress")), "v4 老档没能读进来")
	var slots: Array = game.get("_endless_slots")
	assert(slots.size() == 9, "没有为 7 只鸟补出第一次扩建，窝是 %d 格" % slots.size())
	assert(int(game.get("_endless_slot_expansions")) == 1, "补的扩建次数不对")
	assert(_count(slots, KESTREL) == 3, "3 只红隼没摆回窝里")
	assert(_count(slots, LANTERN) == 2, "2 只夜鹭没摆回窝里")
	assert(_count(slots, ORBITAL) == 1, "啄木鸟没摆回窝里")
	assert(_count(slots, MAGPIE) == 1, "灰喜鹊没摆回窝里")
	assert(_filled(slots) == 7, "摆回窝里的不是 7 只：%d" % _filled(slots))
	# 续局那一步会照窝重算数值位，重算完必须还是这 7 只。
	game.set("_stage_id", ENDLESS)
	game.call("_sync_bonuses_from_slots")
	assert(int(game.get("_super_luck_bonus")) == 3, "照窝重算之后红隼少了")
	assert(int(game.get("_lantern_bonus")) == 2, "照窝重算之后夜鹭少了")
	_assert_bonuses_match_slots(game, "v4 老档还原后")


func _count(slots: Array, offer: int) -> int:
	var total := 0
	for entry in slots:
		if int(entry) == offer:
			total += 1
	return total


func main_expansion_costs() -> Array:
	return [12, 22, 36]


func _filled(slots: Array) -> int:
	var total := 0
	for offer in slots:
		if int(offer) != -1:
			total += 1
	return total


## 七个数值位必须恒等于窝里那只鸟的个数——这是整套机制的不变量。
func _assert_bonuses_match_slots(game: Node, when: String) -> void:
	var expected := {
		LANTERN: "_lantern_bonus",
		COMPASS: "_compass_bonus",
		ORBITAL: "_orbital_strike_bonus",
		KESTREL: "_super_luck_bonus",
		CROW: "_xray_bonus",
		MAGPIE: "_chain_bonus",
		TIT: "_enlarge_bonus",
	}
	var slots: Array = game.get("_endless_slots")
	for offer in expected:
		var count := 0
		for entry in slots:
			if int(entry) == offer:
				count += 1
		assert(
			int(game.get(String(expected[offer]))) == count,
			"%s：商品 %d 的数值位是 %d，窝里却有 %d 只" % [
				when, offer, int(game.get(String(expected[offer]))), count
			]
		)
