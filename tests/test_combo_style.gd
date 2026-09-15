extends SceneTree
## ComboStyle：档位边界、音高阶梯、热度曲线、里程碑口径。
## 这份口径是 HUD 和棋盘特效共读的，抽出来时必须和重构前逐位对上。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# 档位边界要和 HUD 原来那四段配色一一对上。
	assert(ComboStyle.tier_for(0) == 0)
	assert(ComboStyle.tier_for(4) == 0)
	assert(ComboStyle.tier_for(5) == 1)
	assert(ComboStyle.tier_for(9) == 1)
	assert(ComboStyle.tier_for(10) == 2)
	assert(ComboStyle.tier_for(19) == 2)
	assert(ComboStyle.tier_for(20) == 3)
	assert(ComboStyle.tier_for(99) == 3, "封顶档不该越界取色")
	assert(ComboStyle.tier_color(7) == ComboStyle.TIER_COLORS[1])
	assert(ComboStyle.tier_name(20) == ComboStyle.TIER_NAMES[3])
	# 档位名是直接摆到屏幕上的，必须是通用档位词：纯 ASCII 大写，且逐档不重样。
	var seen_names: Array[String] = []
	for combo in [1, 5, 10, 20]:
		var label := ComboStyle.tier_name(combo)
		assert(label.length() > 0, "档位名不能为空")
		assert(label == label.to_upper(), "档位名应当全大写：%s" % label)
		assert(label.is_valid_ascii_identifier(), "档位名应当是通用英文词，不要中文：%s" % label)
		assert(not seen_names.has(label), "各档的档位名不能重样：%s" % label)
		seen_names.append(label)

	# 音高：首刀原速，之后每连一次升一个半音，爬满一个八度封顶。
	assert(is_equal_approx(ComboStyle.pitch_for(0), 1.0), "没连击不该变调")
	assert(is_equal_approx(ComboStyle.pitch_for(1), 1.0), "首刀应为原速")
	assert(is_equal_approx(ComboStyle.pitch_for(2), pow(2.0, 1.0 / 12.0)), "第二刀应升一个半音")
	assert(is_equal_approx(ComboStyle.pitch_for(13), 2.0), "第 13 刀应正好爬满八度")
	assert(is_equal_approx(ComboStyle.pitch_for(80), 2.0), "封顶后不再升调")
	var previous := 0.0
	for combo in range(1, 14):
		var pitch := ComboStyle.pitch_for(combo)
		assert(pitch > previous, "音高必须单调上行：%d" % combo)
		previous = pitch

	# 热度：0 连无热度，爬到 HEAT_FULL_COMBO 满格并封顶。棋盘侧所有强度都乘它。
	assert(ComboStyle.heat(0) == 0.0)
	assert(ComboStyle.heat(10) > ComboStyle.heat(3))
	assert(is_equal_approx(ComboStyle.heat(int(ComboStyle.HEAT_FULL_COMBO)), 1.0))
	assert(is_equal_approx(ComboStyle.heat(60), 1.0), "热度必须封顶，否则棋盘会越晃越离谱")
	assert(is_equal_approx(ComboStyle.gain_db_for(0), 0.0))
	assert(ComboStyle.gain_db_for(60) <= ComboStyle.GAIN_MAX_DB + 0.001, "确认音不得盖过爆炸声")

	# 里程碑口径要和重构前的 5/10/15/20/25… 完全一致。
	for combo in range(0, 40):
		var legacy := (
			combo == 5
			or combo == 10
			or combo == 15
			or combo == 20
			or (combo > 20 and combo % 5 == 0)
		)
		assert(ComboStyle.is_milestone(combo) == legacy, "里程碑口径和重构前不一致：%d" % combo)

	# 流光色：相位要真的改变颜色，且任何相位都不能跑出色域。
	assert(ComboStyle.live_color(6, 0.0) != ComboStyle.live_color(6, 0.5), "色相相位应改变颜色")
	for step in range(24):
		var color := ComboStyle.live_color(12, float(step) / 24.0)
		for channel in [color.r, color.g, color.b, color.a]:
			assert(channel >= 0.0 and channel <= 1.0, "流光色越界：%s" % color)

	# 棋盘用色在任何相位下都得读得出是哪一档。烟花和光晕是大面积色块，
	# 色相一走满就变成随机变色——20 连画成一圈绿光就是这么来的。
	for combo in [3, 7, 14, 26]:
		var tier := ComboStyle.board_tier_color(combo)
		for step in range(32):
			var phase := float(step) / 32.0
			var drift := _drift(ComboStyle.board_color(combo, phase), tier)
			assert(drift < 0.30, "棋盘用色偏离档位色太远：%d 连 相位 %.2f 偏差 %.3f" % [combo, phase, drift])

	# 棋盘必须比 HUD 克制，否则这次把 flow 拆成两档就没有意义。
	var hud_drift := 0.0
	var board_drift := 0.0
	for step in range(32):
		var phase := float(step) / 32.0
		hud_drift = maxf(hud_drift, _drift(ComboStyle.live_color(20, phase), ComboStyle.tier_color(20)))
		board_drift = maxf(
			board_drift, _drift(ComboStyle.board_color(20, phase), ComboStyle.board_tier_color(20))
		)
	assert(board_drift < hud_drift, "棋盘流光必须比 HUD 克制：%.3f vs %.3f" % [board_drift, hud_drift])

	# 棋盘背景是浅羊皮纸，档位越高必须**离背景越远**，否则「连击越多越强」会反过来。
	# HUD 那边的白热档正是栽在这上面：近白色摊在浅底上，20 连比 10 连还不显眼。
	var parchment := Color("ece2ca")
	var previous_contrast := -1.0
	for combo in [3, 7, 14, 26]:
		var contrast := _drift(ComboStyle.board_tier_color(combo), parchment)
		assert(
			contrast > previous_contrast,
			"棋盘档位色与背景的对比必须逐档递增：%d 连 %.3f" % [combo, contrast]
		)
		previous_contrast = contrast

	# 里程碑进度：能量槽拆掉后，COMBO 字形的填充改读它。必须在每个里程碑上填满、
	# 过了立刻从头开始，否则那条填充会一直贴在满格上，看不出还差几刀。
	assert(ComboStyle.milestone_progress(0) == 0.0, "没连击时不该有填充")
	assert(is_equal_approx(ComboStyle.milestone_progress(5), 1.0), "里程碑上应当填满")
	assert(is_equal_approx(ComboStyle.milestone_progress(20), 1.0), "里程碑上应当填满")
	assert(
		ComboStyle.milestone_progress(6) < ComboStyle.milestone_progress(7),
		"跨过里程碑后应从头涨起"
	)
	for combo in range(1, 40):
		var progress := ComboStyle.milestone_progress(combo)
		assert(progress > 0.0 and progress <= 1.0, "进度越界：%d 连 %.3f" % [combo, progress])
		assert(
			is_equal_approx(progress, 1.0) == ComboStyle.is_milestone(combo),
			"填满与里程碑判定必须同步：%d" % combo
		)

	print("ComboStyle: tiers, pitch ladder, heat curve, milestones, and palette drift passed")
	quit()


## 两个颜色在 RGB 上的距离，用来量流光把档位色带偏了多少。
func _drift(color: Color, reference: Color) -> float:
	return Vector3(
		color.r - reference.r, color.g - reference.g, color.b - reference.b
	).length()
