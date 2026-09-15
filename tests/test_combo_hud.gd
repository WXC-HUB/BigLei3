extends SceneTree
## 连击柱：屏幕上那个大字是档位词，不是连击数字。
## 这条容易被「顺手把计数加回来」推翻，所以单独钉一次。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var hud := ComboScoreHud.new()
	root.add_child(hud)
	await process_frame

	var rank: Label = hud.get("_rank_label")
	assert(rank != null, "拿不到档位词那个标签")

	# —— 大字必须是档位词，而且一个数字都不许出现 ——
	for combo in [1, 4, 5, 9, 10, 19, 20, 37]:
		hud.play_hit(0, 0, combo)
		await process_frame
		var expected := ComboStyle.tier_name(combo)
		assert(rank.text == expected, "%d 连的大字应当是 %s，实际是 %s" % [combo, expected, rank.text])
		for character in rank.text:
			assert(not character.is_valid_int(), "大字里出现了数字：%s（连击数不该显示）" % rank.text)

	# 两道色差残影必须和本体同词同字号，否则残影会错位成两个词。
	for ghost_name in ["_rank_ghost_a", "_rank_ghost_b"]:
		var ghost: Label = hud.get(ghost_name)
		assert(ghost != null, "拿不到残影 %s" % ghost_name)
		assert(ghost.text == rank.text, "%s 和本体不是同一个词" % ghost_name)
		assert(
			ghost.get_theme_font_size("font_size") == rank.get_theme_font_size("font_size"),
			"%s 和本体字号不一致，残影会错位" % ghost_name
		)

	# —— 字号按词长反推：长词要缩到框内，短词不该跟着一起缩 ——
	var available: float = ComboScoreHud.HUD_SIZE.x - 40.0
	var font: Font = ComboScoreHud.PIXEL_FONT
	var sizes := {}
	for word in ComboStyle.TIER_NAMES:
		var size_px: int = hud.call("_rank_font_size", word)
		sizes[word] = size_px
		assert(
			size_px >= ComboScoreHud.RANK_FONT_MIN and size_px <= ComboScoreHud.RANK_FONT_MAX,
			"%s 的字号跑出上下限：%d" % [word, size_px]
		)
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
		assert(width <= available, "%s 在 %d 号字下撑出了框：%.1f > %.1f" % [word, size_px, width, available])
	var longest: String = ComboStyle.TIER_NAMES[2]  ## EXCELLENT，四个词里最长的
	var shortest: String = ComboStyle.TIER_NAMES[0]  ## GOOD
	assert(
		int(sizes[longest]) <= int(sizes[shortest]),
		"最长的词没有缩下来：%s %d vs %s %d" % [longest, sizes[longest], shortest, sizes[shortest]]
	)

	# —— 断连之后大字要收走，不能留在屏幕上 ——
	hud.play_combo_break()
	for _step in range(90):
		await process_frame
		if not rank.visible:
			break
	assert(not rank.visible, "断连之后档位词还挂在屏幕上")

	print("ComboScoreHud: rank word replaces the combo count, fits its box, and clears on break")
	quit()
