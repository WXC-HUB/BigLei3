extends SceneTree
## ScoreComboTracker：正确标雷加分、充能、衰减断连击。


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var tracker := ScoreComboTracker.new()
	assert(tracker.score == 0 and tracker.combo == 0)

	var first := tracker.register_mine_cleared()
	assert(first == ScoreComboTracker.BASE_POINTS, "首刀应为基础分")
	assert(tracker.combo == 1)
	assert(tracker.meter > 0.0)
	assert(tracker.score == first)

	var second := tracker.register_mine_cleared()
	assert(second > first, "连击分应上涨")
	assert(tracker.combo == 2)
	assert(tracker.score == first + second)

	tracker.meter = 0.05
	tracker.tick(1.0)
	assert(tracker.combo == 0, "能量耗尽后连击应归零")
	assert(tracker.score == first + second, "断连击不得扣已得分数")

	tracker.register_mine_cleared()
	tracker.reset_combo_keep_score()
	assert(tracker.combo == 0 and tracker.meter == 0.0)
	assert(tracker.score == first + second + ScoreComboTracker.BASE_POINTS)

	tracker.break_combo()
	tracker.reset()
	assert(tracker.score == 0)

	print("ScoreComboTracker: scoring, meter decay, and keep-score reset passed")
	quit()
