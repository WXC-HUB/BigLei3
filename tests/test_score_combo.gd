extends SceneTree
## ScoreComboTracker：分数的唯一来源是每盘的用时奖励，连击和排雷一分都不进账。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# —— 用时曲线：1000 起步、每秒衰减、最低 100 ——
	assert(
		ScoreComboTracker.time_bonus_for(0.0) == ScoreComboTracker.TIME_BONUS_MAX,
		"开盘即结算应当拿满分"
	)
	assert(
		ScoreComboTracker.time_bonus_for(1.0)
		== ScoreComboTracker.TIME_BONUS_MAX - ScoreComboTracker.TIME_BONUS_DECAY_PER_SECOND,
		"每秒应当正好扣一档"
	)
	var floor_seconds := ScoreComboTracker.time_bonus_floor_seconds()
	assert(
		ScoreComboTracker.time_bonus_for(float(floor_seconds)) == ScoreComboTracker.TIME_BONUS_MIN,
		"走到 %d 秒时应当正好落到保底" % floor_seconds
	)
	assert(
		ScoreComboTracker.time_bonus_for(9999.0) == ScoreComboTracker.TIME_BONUS_MIN,
		"再慢也不得低于保底，更不能出负分"
	)
	assert(ScoreComboTracker.time_bonus_for(-5.0) == ScoreComboTracker.TIME_BONUS_MAX, "负数用时要当 0 处理")
	# 秒数取整：同一秒内的零头不该抖动分数。
	assert(
		ScoreComboTracker.time_bonus_for(3.0) == ScoreComboTracker.time_bonus_for(3.9),
		"同一秒内用时奖励应当稳定"
	)
	# 单调不增：越拖只会越少，绝不会因为多花时间反而涨分。
	var previous := ScoreComboTracker.TIME_BONUS_MAX + 1
	for second in range(0, floor_seconds + 20):
		var bonus := ScoreComboTracker.time_bonus_for(float(second))
		assert(bonus <= previous, "用时奖励在第 %d 秒反弹了" % second)
		previous = bonus

	var tracker := ScoreComboTracker.new()
	assert(tracker.score == 0 and tracker.combo == 0 and tracker.boards_scored == 0)

	# —— 盘中一切动作都不计分 ——
	# 点击、推理、认雷全都走 register_combo_hit()，连一百下也还是 0 分。
	for _step in range(100):
		tracker.register_combo_hit()
	assert(tracker.combo == 100, "连击应当照涨")
	assert(tracker.score == 0, "盘中动作不得产生任何分数")
	tracker.break_combo()
	assert(tracker.score == 0, "断连击也不该动分数")

	# —— 分数只在每盘结算时进账 ——
	var fast := tracker.register_time_bonus(5.0)
	assert(fast == ScoreComboTracker.time_bonus_for(5.0))
	assert(tracker.score == fast and tracker.boards_scored == 1)
	assert(tracker.last_time_bonus == fast, "账单要印最近这一笔")
	var slow := tracker.register_time_bonus(9999.0)
	assert(slow == ScoreComboTracker.TIME_BONUS_MIN)
	assert(tracker.score == fast + slow, "多盘的用时奖励应当累加")
	assert(tracker.boards_scored == 2)

	# 同样的用时，连击高低不该有任何差别——这是这次改版要钉死的那一条。
	var lean := ScoreComboTracker.new()
	var hyped := ScoreComboTracker.new()
	for _step in range(50):
		hyped.register_combo_hit()
	assert(
		lean.register_time_bonus(12.0) == hyped.register_time_bonus(12.0),
		"用时相同而连击不同，得分却不一样——连击又渗进计分了"
	)

	# —— 换盘留分、整关清零 ——
	tracker.register_combo_hit()
	var banked := tracker.score
	tracker.reset_combo_keep_score()
	assert(tracker.combo == 0 and tracker.score == banked, "换盘不该抹掉已结算的分")
	assert(tracker.boards_scored == 2, "换盘不该抹掉已结算的盘数")
	tracker.reset()
	assert(tracker.score == 0 and tracker.combo == 0)
	assert(tracker.boards_scored == 0 and tracker.last_time_bonus == 0, "整关重置要把账清干净")

	# 旧口径必须彻底拆掉，别留着让人以为还能用。
	for gone in ["tick", "resume_decay", "register_mine_cleared", "register_mine_triggered"]:
		assert(not tracker.has_method(gone), "旧计分接口 %s 应当已经拆掉" % gone)
	for gone_field in ["meter", "mines_cleared", "mines_triggered"]:
		assert(not (gone_field in tracker), "旧计分字段 %s 应当已经拆掉" % gone_field)

	print("ScoreComboTracker: time-only scoring, decay curve, floor, and combo independence passed")
	quit()
