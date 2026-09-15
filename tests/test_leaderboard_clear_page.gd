extends SceneTree

const LeaderboardPanelScript := preload("res://scripts/ui/leaderboard_panel.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var panel = LeaderboardPanelScript.new()
	root.add_child(panel)
	await process_frame
	assert(panel.has_method("present_after_clear"))
	assert(panel.has_method("present"))
	assert(panel.has_method("present_all"))
	assert(panel.has_method("hide_immediately"))
	assert(panel.get("_stage_tabs") != null, "浏览页应有分关页签")
	# 教学关不进榜：页签少一个，而且少的就是它。
	var tabs := panel.get("_tab_buttons") as Dictionary
	assert(tabs.size() == StageTable.leaderboard_stages().size(), "页签数量应等于上榜关卡数")
	var teaching := ""
	for stage in StageTable.STAGES:
		if bool(stage.get("teaches", false)):
			teaching = String(stage["id"])
	assert(teaching != "", "关卡表里没有教学关，这个测试就失去意义了")
	assert(not StageTable.has_leaderboard(teaching), "教学关仍被当成上榜关卡")
	assert(not tabs.has(teaching), "榜页仍给教学关留了页签")
	# 「全部排行榜」的落点不能是教学关。
	panel.present_all()
	await process_frame
	assert(String(panel.get("_stage_id")) != teaching, "「全部排行榜」还是落在教学关上")
	assert(StageTable.has_leaderboard(String(panel.get("_stage_id"))), "「全部排行榜」落在了一个没有榜的关卡上")
	# 直接点名教学关也打不开。
	panel.hide_immediately()
	panel.present(teaching, "教学关")
	await process_frame
	assert(not panel.visible, "教学关的榜被直接打开了")
	print("LeaderboardPanel clear-page API smoke passed")
	quit()
