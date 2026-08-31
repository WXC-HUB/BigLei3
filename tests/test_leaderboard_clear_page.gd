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
	assert((panel.get("_tab_buttons") as Dictionary).size() == StageTable.STAGES.size(), "页签数量应等于关卡数")
	print("LeaderboardPanel clear-page API smoke passed")
	quit()
